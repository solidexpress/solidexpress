"""Process launch, judging, checkpoints, and the report."""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
import time
import traceback
from pathlib import Path

from sxdrive import SxDrive, SxError
from walk.registry import CHUNKS, EXPECT, ROWS, checkpoint_file

class RowAbort(Exception):
    """A clause already failed; the rest of the row cannot run."""

class Walk:
    def __init__(self, out: Path, port: int, godot: Path, display: str, run_a15: bool, checkpoint: bool,
                 app: Path | None = None, resolution: str = "1280x800") -> None:
        self.out = out
        self.port = port
        self.godot = godot
        self.app = app
        self.resolution = resolution
        self.display = display
        self.run_a15 = run_a15
        self.checkpoint = checkpoint
        self.repo = Path(__file__).resolve().parents[2]
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

    def _row_body(self, rid: str):
        from walk.registry import ROW_HANDLERS
        handler = ROW_HANDLERS.get(rid)
        if handler is None:
            raise AttributeError(f"no walk row {rid}")
        return handler.__get__(self, type(self))

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

    def run_row(self, rid: str, nxt: str | None = None) -> None:
        self.clauses = []
        started = time.monotonic()
        wants_dialog = bool((EXPECT.get(rid) or {}).get("popup"))
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
            self.rows.append(rec)
            print(f"{rid:5} {rec['verdict']:16} {rec['seconds']:6.1f}s  {rec['evidence'][:220]}", flush=True)
            return
        bodies_before = [str(b.get("name", "")) for b in (self.refresh("bodies").get("bodies") or [])]
        try:
            self._row_body(rid)()
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
        next_wants = bool((EXPECT.get(nxt) or {}).get("popup")) if nxt else False
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
        self.rows.append(rec)
        print(f"{rid:5} {verdict:8} {rec['seconds']:6.1f}s  {evidence[:220]}", flush=True)

    # --- bridge sugar -----------------------------------------------------

    def gate(self, rid: str) -> tuple[str, str] | None:
        spec = EXPECT.get(rid)
        if not spec:
            return None
        st = self.refresh("sketch", "bodies", "finish", "popups", "timeline", "status", "dims")
        sk = st.get("sketch") or {}
        ents = list(sk.get("entities") or [])
        reasons: list[str] = []
        if spec.get("sketch") and not sk.get("active"):
            reasons.append(f"sketch not active status={self.S()!r}")
        if spec.get("part") and sk.get("active"):
            reasons.append("still in a sketch")
        if "min_circles" in spec:
            n = sum(1 for e in ents if e.get("type") == "circle")
            if n < int(spec["min_circles"]):
                reasons.append(f"circles={n}")
        if "span_mm" in spec and self._circle_span(ents) < float(spec["span_mm"]):
            reasons.append(f"circle span {self._circle_span(ents):.1f} mm")
        if "min_lines" in spec:
            n = sum(1 for e in ents if e.get("type") == "line")
            if n < int(spec["min_lines"]):
                reasons.append(f"lines={n}")
        if "min_bodies" in spec and len(st.get("bodies") or []) < int(spec["min_bodies"]):
            reasons.append(f"bodies={len(st.get('bodies') or [])}")
        if "bbox_x" in spec:
            lo, hi = spec["bbox_x"]
            span = self._bbox_x(list(st.get("bodies") or []))
            if span is None or not (float(lo) <= span <= float(hi)):
                reasons.append(f"bbox X={span}")
        if spec.get("finish_op") and self.field("finish:Op") != spec["finish_op"]:
            reasons.append(f"finish op={self.field('finish:Op')!r}")
        if spec.get("finish_end") and spec["finish_end"] not in self.field("finish:End"):
            reasons.append(f"finish end={self.field('finish:End')!r}")
        if spec.get("popup") and not self.has_popup(str(spec["popup"])):
            reasons.append(f"popup {spec['popup']!r} not open ({self.popup_text()[:80]})")
        if spec.get("timeline"):
            names = " ".join(str(r.get("name", "")) for r in (st.get("timeline") or []))
            if str(spec["timeline"]) not in names:
                reasons.append(f"timeline={names!r}")
        if spec.get("dim_has"):
            texts = " ".join(self.dim_texts())
            if str(spec["dim_has"]) not in texts:
                reasons.append(f"dims={texts!r}")
        if not reasons:
            return None
        return str(spec["blocker"]), "; ".join(reasons)

    def checker(self, kind: str, name: str, extra: str | None = None) -> tuple[int, str]:
        cmd = [sys.executable, str(self.repo / "tools" / "check_rung01.py"), kind, str(self.out / name)]
        if extra:
            cmd.append(extra)
        proc = subprocess.run(cmd, cwd=str(self.repo), capture_output=True, text=True)
        text = (proc.stdout or "") + (proc.stderr or "")
        (self.out / f"check-{kind}-{Path(name).stem}.txt").write_text(text)
        return proc.returncode, text

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

    def body_guard(self, kind: str, thickness: float | None = None) -> bool:
        """S0: exactly one body before an export. A miss is runner-gap, not a checker FAIL."""
        self.refresh("bodies")
        bodies = list(self.st.get("bodies") or [])
        if len(bodies) != 1:
            named = ", ".join(f"{b.get('name')} ({self._fmt_volume(b)})" for b in bodies) or "(none)"
            left = self.ctx.get("bodies_left_by") or "unknown"
            evidence = f"runner-gap: stray body {named} left by {left}"
            self.clause("S0", False, evidence, kind="runner-gap")
            return False
        body = bodies[0]
        name = str(body.get("name", ""))
        if kind == "nut":
            self.clause("S0", True, f"one body {name} ({self._fmt_volume(body)})")
            return True
        sx, sy, sz = self._bbox_size(body)
        ok = (
            name.startswith("extrude")
            and abs(sx - 232.5) <= 0.3
            and abs(sy - 45.0) <= 0.1
            and thickness is not None
            and abs(sz - float(thickness)) <= 0.01
        )
        evidence = f"{name} ({self._fmt_volume(body)}) bbox {sx:.3f}×{sy:.3f}×{sz:.3f} T={thickness}"
        if not ok and len(bodies) == 1:
            evidence = f"runner-gap: body {name} ({self._fmt_volume(body)}) bbox {sx:.3f}×{sy:.3f}×{sz:.3f} want 232.5×45×{thickness}"
        self.clause("S0", ok, evidence, kind="" if ok else "runner-gap")
        return ok

    def _note_bodies(self, rid: str, before: list[str]) -> None:
        after = [str(b.get("name", "")) for b in (self.refresh("bodies").get("bodies") or [])]
        if after != before:
            self.ctx["bodies_left_by"] = rid

    # --- rows -------------------------------------------------------------

    def _sketch_active(self) -> bool:
        return bool((self.refresh("sketch").get("sketch") or {}).get("active"))

    def _previous_chunk_ready(self, chunk: int) -> bool:
        """True when the previous chunk already left the state this chunk expects."""
        prev = chunk - 1
        if prev < 1:
            return True
        sketch = self._sketch_active()
        if prev == 1:
            return (self.out / "blank.sxp").exists() and not sketch
        if prev == 2:
            texts = self.dim_texts()
            return (
                sketch
                and any(self._label_is("20", t) for t in texts)
                and any(self._label_is("45", t) for t in texts)
            )
        if prev == 3:
            return (self.out / "cut.sxp").exists() and not sketch
        if prev == 4:
            return (self.out / "wrench-wip.sxp").exists() and not sketch
        if prev == 5:
            return (self.out / "wrench-wip.sxp").exists() and not sketch and not self.modal_open()
        return True

    def _reload_checkpoint(self, name: str) -> None:
        self.dismiss_modals()
        self.open_file(name)
        self.refresh("status", "sketch", "bodies")
        print(f"checkpoint-reload {name}", flush=True)
        self.ctx["checkpoint"] = name

    def build_open_jaw(self) -> None:
        """Open blank.sxp and leave the 20 mm / 45° jaw sketch editing."""
        self.dismiss_modals()
        self.open_file("blank.sxp")
        self.refresh("status", "sketch")
        if self._sketch_active():
            self.click("rail:ExitSketch")
            self.refresh("status")
        self.sketch_on_top()
        if "Sketch on face" not in self.S():
            raise SxError(f"jaw rebuild did not open the face sketch: {self.S()!r}")
        self.jaw_basis()
        self._jaw_clicks(-10)
        if "Jaw committed" not in self.S():
            raise SxError(f"jaw rebuild did not commit: {self.S()!r}")
        width, angle = self._drawn_angle_and_width()
        if width is None or angle is None:
            raise SxError(f"jaw rebuild has no labels: {self.dim_texts()}")
        self.edit_dim(width, "20")
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        if angle is None:
            raise SxError(f"jaw width edit dropped the angle: {self.dim_texts()}")
        self.edit_dim(angle, "45")
        texts = self.dim_texts()
        if not any(self._label_is("45", t) for t in texts):
            raise SxError(f"jaw rebuild angle is not 45°: {texts}")

    def build_cut_file(self) -> bool:
        """Chunk 3 cut, from blank.sxp, saved as cut.sxp."""
        self.build_open_jaw()
        self.circle([0, 0], "5")
        self.circle([200, 0], "22.5", burst=True)
        self.click("rail:Line")
        self.click(sketch=[160, 40])
        self.click(sketch=[240, -40])
        self.click("rail:Trim")
        self.d.drag({"sketch": [250, 0]}, {"sketch": [190, 0]})
        self.refresh("status")
        print(f"checkpoint: cut trim {self.S()!r}", flush=True)
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Up To Surface")
        try:
            self.click("finish:OppositeFace")
            self.click(face=self.bottom_face()["id"])
        except SxError as exc:
            print(f"checkpoint: opposite face {exc}", flush=True)
        self.click("finish:Extrude", frames=10)
        self.refresh("status")
        path = self.save_as("cut.sxp")
        ok = Path(path).exists() and "Saved" in self.S()
        print(f"checkpoint: built cut.sxp ok={ok} status={self.S()!r}", flush=True)
        return ok

    def build_wip_file(self) -> bool:
        """Slot cut from cut.sxp, saved as wrench-wip.sxp."""
        self.dismiss_modals()
        self.open_file("cut.sxp")
        self.sketch_on_top()
        self.click("rail:Slot")
        self.type_into("finish:Radius", "5")
        self.enter()
        self.click(sketch=[18.5, 0])
        self.d.type("150")
        self.enter()
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Blind")
        self.type_into("finish:Distance", "2.5", burst=True)
        self.enter()
        self.click("finish:Extrude", frames=10)
        self.refresh("status")
        path = self.save_as("wrench-wip.sxp")
        ok = Path(path).exists() and "Saved" in self.S()
        print(f"checkpoint: built wrench-wip.sxp ok={ok} status={self.S()!r}", flush=True)
        return ok

    def ensure_chunk_start(self, chunk: int, force: bool = False) -> None:
        if chunk <= 1:
            return
        if not force and self._previous_chunk_ready(chunk):
            return
        try:
            if chunk == 2:
                if (self.out / "blank.sxp").exists():
                    self._reload_checkpoint("blank.sxp")
                return
            if chunk == 3:
                if not (self.out / "blank.sxp").exists():
                    print("checkpoint: blank.sxp missing, cannot rebuild the jaw", flush=True)
                    return
                print("checkpoint-reload blank.sxp", flush=True)
                self.build_open_jaw()
                return
            if chunk == 4:
                if not (self.out / "cut.sxp").exists():
                    if not (self.out / "blank.sxp").exists():
                        print("checkpoint: blank.sxp missing, cannot build cut.sxp", flush=True)
                        return
                    print("checkpoint: building cut.sxp from blank.sxp", flush=True)
                    if not self.build_cut_file():
                        return
                self._reload_checkpoint("cut.sxp")
                return
            if chunk in (5, 6):
                if not (self.out / "wrench-wip.sxp").exists():
                    if not (self.out / "cut.sxp").exists():
                        if not (self.out / "blank.sxp").exists():
                            print("checkpoint: no blank.sxp to build the wrench", flush=True)
                            return
                        if not self.build_cut_file():
                            return
                    print("checkpoint: building wrench-wip.sxp from cut.sxp", flush=True)
                    if not self.build_wip_file():
                        return
                self._reload_checkpoint("wrench-wip.sxp")
        except (SxError, RowAbort) as exc:
            print(f"checkpoint: chunk {chunk} reload failed: {exc}", flush=True)

    def open_checkpoint(self, rid: str) -> None:
        name = checkpoint_file(rid)
        if not name:
            print(f"checkpoint: {rid} has no recovery file", flush=True)
            return
        path = self.out / name
        if not path.exists():
            print(f"checkpoint: {name} is not in {self.out}", flush=True)
            return
        try:
            self.open_file(name)
            self.refresh("status", "sketch", "bodies")
            print(f"checkpoint: opened {name} before {rid} status={self.S()!r}", flush=True)
            self.ctx["checkpoint"] = name
        except SxError as exc:
            print(f"checkpoint: open {name} failed: {exc}", flush=True)

    def chunk_failed(self, chunk: int) -> bool:
        rows = set(CHUNKS[chunk])
        return any(r["row"] in rows and not str(r["verdict"]).startswith("PASS") for r in self.rows)

    def write_report(self) -> None:
        counts: dict[str, int] = {}
        for rec in self.rows:
            counts[rec["verdict"]] = counts.get(rec["verdict"], 0) + 1
        wall = time.monotonic() - self.t0
        lines = [
            "# sx-042 walk",
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
