"""Process launch, judging, checkpoints, and the report."""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys

from walk import proc
import time
import traceback
from pathlib import Path

from sxdrive import SxDrive, SxError
from walk.expect import State, gate as gate_reasons

class RowAbort(Exception):
    """A clause already failed; the rest of the row cannot run."""

class Walk:
    def __init__(self, out: Path, port: int, godot: Path, display: str, run_a15: bool, checkpoint: bool,
                 app: Path | None = None, resolution: str = "1280x800", rung=None) -> None:
        self.out = out
        self.port = port
        self.godot = godot
        self.app = app
        self.resolution = resolution
        self.display = display
        self.run_a15 = run_a15
        self.checkpoint = checkpoint
        self.repo = Path(__file__).resolve().parents[2]
        self.rung = rung
        self.d = SxDrive(port=port, timeout=180.0)
        self.proc: subprocess.Popen | None = None
        self.log_fp = None
        self.rows: list[dict] = []
        self.clauses: list[dict] = []
        self.cursor = 0
        self.st: dict = {}
        self.ctx: dict = {}
        self.t0 = time.monotonic()
        self.shot_n = 0

    # --- process ----------------------------------------------------------

    def launch(self) -> None:
        self.out.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env["SX_AUTOMATION"] = "1"
        env["SX_INPUT_TRACE"] = "1"
        env["SX_AUTOMATION_PORT"] = str(self.port)
        env["DISPLAY"] = self.display
        prefix = os.environ.get("OCCT_PREFIX", str(Path.home() / "occt-8.0.1"))
        lib = str(Path(prefix) / "lib")
        if Path(lib).is_dir():
            env["LD_LIBRARY_PATH"] = lib + (":" + env["LD_LIBRARY_PATH"] if env.get("LD_LIBRARY_PATH") else "")
        self.log_fp = open(self.out / "input-trace.log", "w", buffering=1)
        if self.app is not None:
            # Exported binary: cwd is the bundle so libsxcore.so beside it loads.
            cmd = [str(self.app), "--resolution", self.resolution]
            cwd = str(self.app.parent)
        else:
            cmd = [str(self.godot), "--path", str(self.repo / "game"), "--resolution", self.resolution]
            cwd = str(self.repo)
        self.proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            env=env,
            stdout=self.log_fp,
            stderr=subprocess.STDOUT,
        )
        self.d.connect(attempts=240, delay=0.25)
        self.d.call("ping")
        self.d.wait_idle(frames=4)

    def shutdown(self) -> None:
        self.d.close()
        if self.proc is not None and self.proc.poll() is None:
            self.proc.send_signal(signal.SIGTERM)
            try:
                self.proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        if self.log_fp is not None:
            self.log_fp.close()

    # --- judging ----------------------------------------------------------

    def clause(self, name: str, ok, evidence: str = "", needs_visual: bool = False, kind: str = "") -> None:
        stored = None if needs_visual or kind == "headless-only" else bool(ok)
        self.clauses.append({
            "name": name,
            "ok": stored,
            "needs_visual": needs_visual,
            "evidence": evidence,
            "kind": kind,
        })

    def _clause_mark(self, clause: dict) -> str:
        if clause.get("kind") == "headless-only":
            return "headless-only"
        if clause.get("needs_visual"):
            return "VIS"
        return "ok" if clause.get("ok") else "FAIL"

    def need(self, ok: bool, name: str, evidence: str = "") -> None:
        self.clause(name, ok, evidence)
        if not ok:
            raise RowAbort()

    def _gap_clause(self, clause: dict) -> bool:
        if clause.get("kind") == "product":
            return False
        if clause.get("kind") == "runner-gap":
            return True
        ev = str(clause.get("evidence", ""))
        return "popup item not found" in ev or "control not found" in ev or "not on screen" in ev

    def _all_runner_gaps(self) -> bool:
        fails = [c for c in self.clauses if c["ok"] is False]
        return bool(fails) and all(self._gap_clause(c) for c in fails)

    def verdict_of(self, clauses: list[dict]) -> str:
        judged = [c for c in clauses if c.get("kind") != "headless-only"]
        if not judged:
            return "BLOCKED"
        if any("BLOCKED-by-flag" in str(c.get("evidence", "")) for c in judged):
            return "BLOCKED-by-flag"
        if any(c["ok"] is False for c in judged):
            return "FAIL"
        if any(c["needs_visual"] or c["ok"] is None for c in judged):
            return "PARTIAL"
        return "PASS"

    def _expect(self, rid: str | None):
        if not rid or self.rung is None:
            return None
        return self.rung.expectations.get(rid)

    def _row_fn(self, rid: str):
        handler = None
        if self.rung is not None:
            handler = self.rung.handlers.get(rid) or self.rung.variants.get(rid)
        if handler is None:
            raise AttributeError(f"no walk row {rid}")
        return handler

    def modal_open(self) -> bool:
        snap = self.d.state(filter="dialogs")
        dialogs = snap.get("dialogs") or {}
        self.st["dialogs"] = dialogs
        return bool(
            dialogs.get("file_visible")
            or dialogs.get("overwrite_visible")
            or dialogs.get("discard_visible")
        )

    def dismiss_modals(self) -> None:
        if not self.modal_open():
            return
        self.d.call("dialog_dismiss")
        self.d.wait_idle(frames=2)
        self.refresh("status", "popups")

    def dismiss_menus(self) -> None:
        self.refresh("popups")
        if self.st.get("popups"):
            self.esc()
            self.refresh("popups", "status")

    def resume_from(self, start_rid: str) -> None:
        from walk.checkpoint import resume_walk

        resume_walk(self, start_rid)

    def _snapshot_row(self, rid: str) -> None:
        """Save the document after a PASS row so `--from` the next row can restore it."""
        dest = self.out / "ckpts" / f"{rid}.sxp"
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.d.call("save_path", path=str(dest))
        except SxError as exc:
            print(f"snapshot: {rid} {exc}", flush=True)

    def run_row(self, rid: str, nxt: str | None = None, *, record: bool = True) -> str:
        self.clauses = []
        started = time.monotonic()
        wants_dialog = bool(self._expect(rid) and self._expect(rid).popup)
        if not wants_dialog:
            try:
                self.dismiss_modals()
                self.dismiss_menus()
            except SxError as exc:
                self.clause("close stray dialog", False, str(exc), kind="runner-gap")
        blocked = self.gate(rid)
        if blocked:
            blocker, why = blocked
            self.clause("precondition", False, why, kind="blocked")
            rec = {
                "row": rid,
                "verdict": f"BLOCKED-by-{blocker}",
                "seconds": round(time.monotonic() - started, 2),
                "clauses": self.clauses,
                "evidence": f"BLOCKED-by-{blocker}: {why}",
                "status": self.st.get("status", ""),
            }
            if record:
                self.rows.append(rec)
            prefix = "resume-replay " if not record else ""
            print(f"{prefix}{rid:5} {rec['verdict']:16} {rec['seconds']:6.1f}s  {rec['evidence'][:220]}", flush=True)
            return rec["verdict"]
        bodies_before = [str(b.get("name", "")) for b in (self.refresh("bodies").get("bodies") or [])]
        try:
            self._row_fn(rid)(self)
        except RowAbort:
            pass
        except SxError as exc:
            self.clause("command", False, str(exc), kind="runner-gap")
        except Exception:
            self.clause("runner", False, traceback.format_exc(limit=6), kind="runner-gap")
        try:
            self._note_bodies(rid, bodies_before)
        except SxError:
            pass
        next_wants = bool(nxt and self._expect(nxt) and self._expect(nxt).popup)
        if not next_wants:
            try:
                if self.modal_open():
                    dialogs = self.st.get("dialogs") or {}
                    self.clause(
                        "dialog closed",
                        False,
                        f"modal still open status={self.S()!r} dialogs={dialogs}",
                        kind="runner-gap",
                    )
                    self.dismiss_modals()
            except SxError as exc:
                self.clause("dialog closed", False, str(exc), kind="runner-gap")
        verdict = self.verdict_of(self.clauses)
        if verdict == "FAIL":
            verdict = "FAIL runner-gap" if self._all_runner_gaps() else "FAIL"
        evidence = "; ".join(
            f"{c['name']}={self._clause_mark(c)}: {c['evidence']}"
            for c in self.clauses
        )
        rec = {
            "row": rid,
            "verdict": verdict,
            "seconds": round(time.monotonic() - started, 2),
            "clauses": self.clauses,
            "evidence": evidence,
            "status": self.st.get("status", ""),
        }
        if record:
            self.rows.append(rec)
        prefix = "resume-replay " if not record else ""
        print(f"{prefix}{rid:5} {verdict:8} {rec['seconds']:6.1f}s  {evidence[:220]}", flush=True)
        if str(verdict).startswith("PASS"):
            self._snapshot_row(rid)
        return verdict

    # --- bridge sugar -----------------------------------------------------

    def _gate_state(self) -> State:
        st = self.refresh("sketch", "bodies", "finish", "popups", "timeline", "status", "dims")
        sk = st.get("sketch") or {}
        ents = list(sk.get("entities") or [])
        texts = " ".join(str(d.get("text", "")) for d in (st.get("dims") or []) if d.get("visible", True))
        names = " ".join(str(r.get("name", "")) for r in (st.get("timeline") or []))
        return State(
            status=self.S(),
            sketch_active=bool(sk.get("active")),
            n_circles=sum(1 for e in ents if e.get("type") == "circle"),
            n_lines=sum(1 for e in ents if e.get("type") == "line"),
            circle_span=self._circle_span(ents),
            n_bodies=len(st.get("bodies") or []),
            bbox_x=self._bbox_x(list(st.get("bodies") or [])),
            finish_op=self.field("finish:Op"),
            finish_end=self.field("finish:End"),
            popup_text=self.popup_text(),
            timeline=names,
            dim_texts=texts,
        )

    def gate(self, rid: str) -> tuple[str, str] | None:
        spec = self._expect(rid)
        if spec is None:
            return None
        reasons = gate_reasons(self._gate_state(), spec)
        if not reasons:
            return None
        return spec.blocker or "previous", "; ".join(reasons)

    def checker(self, kind: str, name: str, extra: str | list | None = None) -> tuple[int, str]:
        script = self.rung.checker
        cmd = [sys.executable, str(self.repo / "tools" / script), kind, str(self.out / name)]
        if isinstance(extra, (list, tuple)):
            cmd.extend(str(part) for part in extra)
        elif extra:
            cmd.append(extra)
        result = proc.run(cmd, cwd=self.repo)
        text = (result.stdout or "") + (result.stderr or "")
        (self.out / f"check-{kind}-{Path(name).stem}.txt").write_text(text)
        return result.returncode, text

    def trace_from(self, cursor: int) -> list[str]:
        reply = self.d.trace(since=cursor)
        self.cursor = int(reply.get("cursor", self.cursor))
        return list(reply.get("lines") or [])

    def mark(self) -> int:
        reply = self.d.trace(since=10**9)
        self.cursor = int(reply.get("cursor", 0))
        return self.cursor

    def _trace_text(self, line: str) -> str:
        key = " text="
        idx = line.find(key)
        return line[idx + len(key):] if idx >= 0 else line

    def _trace_time(self, line: str) -> float | None:
        match = re.search(r"\bt=([0-9]+(?:\.[0-9]+)?)", line)
        return float(match.group(1)) if match else None

    def status_since(self, mark: int, kind: str | None = None) -> list[str]:
        """`[status-trace]` lines since `mark`. Status clauses read these, not the live label."""
        lines = [ln for ln in self.trace_from(mark) if "status-trace" in ln]
        if kind is None:
            return lines
        return [ln for ln in lines if f"kind={kind}" in ln]

    def result_texts(self, mark: int) -> list[str]:
        return [self._trace_text(ln) for ln in self.status_since(mark, "result")]

    def _body_snapshot(self) -> list[str]:
        self.refresh("bodies", "timeline")
        names = [str(b.get("name", "")) for b in (self.st.get("bodies") or [])]
        timeline = [str(r.get("name", "")) for r in (self.st.get("timeline") or []) if r.get("name")]
        return names, timeline

    def _fmt_volume(self, body: dict) -> str:
        vol = body.get("volume")
        if vol is None:
            mn = body.get("min") or [0, 0, 0]
            mx = body.get("max") or [0, 0, 0]
            vol = abs((float(mx[0]) - float(mn[0])) * (float(mx[1]) - float(mn[1])) * (float(mx[2]) - float(mn[2])))
        return f"{float(vol):.1f}"

    def _bbox_size(self, body: dict) -> tuple[float, float, float]:
        mn = body.get("min") or [0, 0, 0]
        mx = body.get("max") or [0, 0, 0]
        return tuple(abs(float(mx[i]) - float(mn[i])) for i in range(3))

    def _note_bodies(self, rid: str, before: list[str]) -> None:
        after = [str(b.get("name", "")) for b in (self.refresh("bodies").get("bodies") or [])]
        if after != before:
            self.ctx["bodies_left_by"] = rid

    # --- rows -------------------------------------------------------------

    def _sketch_active(self) -> bool:
        return bool((self.refresh("sketch").get("sketch") or {}).get("active"))

    def _reload_checkpoint(self, name: str) -> None:
        self.dismiss_modals()
        self.open_file(name)
        self.refresh("status", "sketch", "bodies")
        print(f"checkpoint-reload {name}", flush=True)
        self.ctx["checkpoint"] = name

    def ensure_chunk_start(self, chunk: int, force: bool = False) -> None:
        self.rung.chunk_start(self, chunk, force)

    def chunk_failed(self, chunk: int) -> bool:
        rows = set(self.rung.chunks[chunk])
        return any(r["row"] in rows and not str(r["verdict"]).startswith("PASS") for r in self.rows)

    def write_report(self) -> None:
        counts: dict[str, int] = {}
        for rec in self.rows:
            counts[rec["verdict"]] = counts.get(rec["verdict"], 0) + 1
        wall = time.monotonic() - self.t0
        lines = [
            "# " + self.rung.report_title,
            "",
            f"Rows {len(self.rows)}  " + "  ".join(f"{k} {v}" for k, v in sorted(counts.items())),
            f"Wall {wall:.1f}s",
            "",
        ]
        for rec in self.rows:
            lines.append(f"## {rec['row']} — {rec['verdict']} ({rec['seconds']}s)")
            lines.append("")
            lines.append(rec["evidence"] or "(no clauses)")
            lines.append("")
        (self.out / "WALK_LOG.md").write_text("\n".join(lines))
        (self.out / "walk_report.json").write_text(json.dumps({
            "counts": counts,
            "wall_s": round(wall, 2),
            "rows": self.rows,
        }, indent=2))
        summary = f"{len(self.rows)} rows  " + "  ".join(f"{k} {v}" for k, v in sorted(counts.items())) + f"  wall {wall:.1f}s"
        notable = [
            f"{r['row']} {r['verdict']}: {r['evidence'][:180].replace(chr(10), ' ')}"
            for r in self.rows
            if r["verdict"] not in ("PASS",)
        ]
        (self.out / "SUMMARY.txt").write_text(summary + "\n" + "\n".join(notable) + "\n")
        print(summary, flush=True)
        for line in notable:
            print(line, flush=True)
