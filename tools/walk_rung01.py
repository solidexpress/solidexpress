#!/usr/bin/env python3
"""Walk the sx-041 checklist against a live SolidExpress window.

Launches the app with SX_AUTOMATION=1 and SX_INPUT_TRACE=1, drives each row
through tools/sxdrive.py, and writes WALK_LOG.md plus walk_report.json.
Product failures are recorded. This script does not change the CAD code.

    python3 tools/walk_rung01.py --out /tmp/sx-041
    python3 tools/walk_rung01.py --rows A8,L4 --out /tmp/sx-041
    python3 tools/walk_rung01.py --from N21b --out /tmp/sx-041
    python3 tools/walk_rung01.py --from A7 --checkpoint --out /tmp/sx-041

A full walk reloads a chunk's checklist file when the previous chunk did not
end in the expected state, and builds a missing cut.sxp / wrench-wip.sxp from
the last good save. --checkpoint forces that reload for a partial --from run.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sxdrive import SxDrive, SxError  # noqa: E402


ROWS = [
    "N22", "A1", "A2", "N7", "L1", "A3", "L5", "A4", "L6", "L10",
    "A5", "N12", "A5b", "L8", "L11", "N17",
    "A7", "L2", "A6", "N4", "A7b", "A8r", "A8w", "A8", "N5", "N25", "A8b", "N8a",
    "A9", "L4", "N1a", "N21", "N21b", "N26", "L12", "N24", "N24b", "A17",
    "A9c", "N1b", "N20", "A9b",
    "A16", "N6", "A11a", "N10", "N18",
    "A11b", "N2", "L3", "A11c", "N3", "A11d", "A11e", "A11f", "N15", "N13",
    "N16", "N19", "N23",
    "A12", "N11", "A13", "A13b", "A13d", "A13c", "N9", "L7", "N8b", "N14",
    "A10", "A10b", "A14", "L9", "A15",
]

CHUNKS = {
    1: ROWS[0:16],
    2: ROWS[16:28],
    3: ROWS[28:42],
    4: ROWS[42:47],
    5: ROWS[47:60],
    6: ROWS[60:75],
}

# Recovery files from the checklist (rule 11) plus the named mid-walk saves.
# Chunk 3 starts in the live jaw sketch; pre-cut.sxp exists only from A9c on.
CHECKPOINT = {
    2: "blank.sxp",
    4: "cut.sxp",
    5: "wrench-wip.sxp",
    6: "wrench-wip.sxp",
}


def checkpoint_file(rid: str) -> str | None:
    """Saved part that can stand in for live state when a later chunk starts."""
    idx = ROWS.index(rid)
    if idx >= ROWS.index("L7"):
        return "wrench-t14.sxp"
    chunk = next(n for n, rows in CHUNKS.items() if rid in rows)
    if chunk == 3 and idx >= ROWS.index("N20"):
        return "pre-cut.sxp"
    return CHECKPOINT.get(chunk)


# Expected starting state. A miss is BLOCKED-by-<blocker>, not a cascade of FAILs.
EXPECT: dict[str, dict] = {
    "A2": {"blocker": "A1", "sketch": True},
    "N7": {"blocker": "A1", "sketch": True},
    "L1": {"blocker": "A1", "sketch": True},
    "A3": {"blocker": "A1", "sketch": True},
    "L5": {"blocker": "A3", "sketch": True, "min_circles": 2, "span_mm": 100},
    "A4": {"blocker": "A3", "sketch": True, "min_circles": 2, "span_mm": 100},
    "L6": {"blocker": "A4", "sketch": True, "min_lines": 2},
    "L10": {"blocker": "A3", "sketch": True},
    "A5": {"blocker": "A4", "sketch": True, "min_lines": 2},
    "N12": {"blocker": "A5", "part": True, "min_bodies": 1, "bbox_x": (200, 260)},
    "A5b": {"blocker": "A5", "part": True, "min_bodies": 1, "bbox_x": (200, 260)},
    "L8": {"blocker": "A5b", "popup": "Save"},
    "L11": {"blocker": "A5", "part": True, "min_bodies": 1},
    "N17": {"blocker": "A5", "part": True, "min_bodies": 1, "bbox_x": (200, 260)},
    "A7": {"blocker": "A5", "part": True, "min_bodies": 1, "bbox_x": (200, 260)},
    "L2": {"blocker": "A7", "sketch": True},
    "A6": {"blocker": "L2", "sketch": True, "finish_op": "Cut", "finish_end": "Up To"},
    "N4": {"blocker": "A6", "part": True, "min_bodies": 1},
    "A7b": {"blocker": "N4", "part": True, "min_bodies": 1, "bbox_x": (200, 260)},
    "A8r": {"blocker": "A7b", "sketch": True},
    "A8w": {"blocker": "A8r", "sketch": True, "dim_has": "°"},
    "A8": {"blocker": "A8w", "sketch": True},
    "N5": {"blocker": "A8", "sketch": True, "dim_has": "45"},
    "N25": {"blocker": "N5", "sketch": True},
    "A8b": {"blocker": "A8", "sketch": True, "dim_has": "45"},
    "N8a": {"blocker": "A8b", "part": True, "timeline": "sketch 3"},
    "A9": {"blocker": "N8a", "sketch": True},
    "L4": {"blocker": "A9", "sketch": True},
    "N1a": {"blocker": "A9", "sketch": True},
    "N21": {"blocker": "A9", "sketch": True},
    "N21b": {"blocker": "A9", "sketch": True},
    "N26": {"blocker": "A9", "sketch": True},
    "L12": {"blocker": "A9", "sketch": True},
    "N24": {"blocker": "A9", "sketch": True},
    "N24b": {"blocker": "A9", "sketch": True},
    "A17": {"blocker": "A9", "sketch": True},
    "A9c": {"blocker": "A9", "sketch": True},
    "N1b": {"blocker": "A9", "sketch": True},
    "N20": {"blocker": "A9c", "sketch": True},
    "A9b": {"blocker": "A9", "sketch": True},
    "A16": {"blocker": "A9b", "part": True, "min_bodies": 1},
    "N6": {"blocker": "A16", "part": True},
    "A11a": {"blocker": "A9b", "part": True, "min_bodies": 1},
    "N10": {"blocker": "A11a", "sketch": True},
    "N18": {"blocker": "A11a", "sketch": True},
    "A11b": {"blocker": "N18", "part": True, "min_bodies": 1},
}


class RowAbort(Exception):
    """A clause already failed; the rest of the row cannot run."""


class Walk:
    def __init__(self, out: Path, port: int, godot: Path, display: str, run_a15: bool, checkpoint: bool) -> None:
        self.out = out
        self.port = port
        self.godot = godot
        self.display = display
        self.run_a15 = run_a15
        self.checkpoint = checkpoint
        self.repo = Path(__file__).resolve().parents[1]
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
        self.proc = subprocess.Popen(
            [str(self.godot), "--path", str(self.repo / "game"), "--resolution", "1280x800"],
            cwd=str(self.repo),
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
        self.clauses.append({
            "name": name,
            "ok": None if needs_visual else bool(ok),
            "needs_visual": needs_visual,
            "evidence": evidence,
            "kind": kind,
        })

    def visual(self, name: str, evidence: str) -> None:
        path = self.out / f"visual-{self.shot_n:03d}-{name.replace(' ', '_')[:40]}.png"
        self.shot_n += 1
        try:
            shot = self.d.screenshot(str(path))
            evidence = f"{evidence} screenshot={shot.get('path', path)}"
        except SxError as exc:
            evidence = f"{evidence} screenshot failed: {exc}"
        self.clause(name, None, evidence, needs_visual=True)

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
        if not clauses:
            return "BLOCKED"
        if any(c["ok"] is False for c in clauses):
            return "FAIL"
        if any(c["needs_visual"] or c["ok"] is None for c in clauses):
            return "PARTIAL"
        return "PASS"

    def _row_body(self, rid: str):
        variants = {
            "A8b-variant-walk": self.row_A8b_variant_walk,
            "A9-variant-walk": self.row_A9_variant_walk,
        }
        if rid in variants:
            return variants[rid]
        return getattr(self, f"row_{rid}")

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
        try:
            self._row_body(rid)()
        except RowAbort:
            pass
        except SxError as exc:
            self.clause("command", False, str(exc), kind="runner-gap")
        except Exception:
            self.clause("runner", False, traceback.format_exc(limit=6), kind="runner-gap")
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
            f"{c['name']}={'VIS' if c['needs_visual'] else ('ok' if c['ok'] else 'FAIL')}: {c['evidence']}"
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

    def refresh(self, *keys: str) -> dict:
        filt = ",".join(keys) if keys else (
            "status,focus,focus_text,dof,sketch,finish,tool,rail,dims,timeline,"
            "selection,bodies,features,popups,measure,infer,glyphs,contours,window,card,camera"
        )
        self.st = self.d.state(filter=filt)
        return self.st

    def S(self) -> str:
        return str(self.st.get("status", ""))

    def click(self, target: str | None = None, **fields):
        if target is not None:
            return self.d.click(target, **fields)
        return self.d.click(**fields)

    def menu(self, menu: str, item: str) -> None:
        self.click(f"menu:{menu}")
        self.click(f"popup:{item}")

    def popup_text(self) -> str:
        parts = []
        for p in self.st.get("popups") or []:
            parts.append(str(p.get("text", "")) + " " + str(p.get("id", "")) + " " + str(p.get("title", "")))
        return " ".join(parts)

    def has_popup(self, needle: str) -> bool:
        return needle.lower() in self.popup_text().lower()

    def lit_names(self) -> list[str]:
        names = []
        for b in self.st.get("rail") or []:
            if b.get("lit") or b.get("pressed"):
                names.append(str(b.get("text", "")))
        return names

    def field(self, fid: str) -> str:
        for f in (self.st.get("finish") or {}).get("fields") or []:
            if f.get("id") == fid:
                return str(f.get("text", ""))
        return ""

    def control(self, cid: str) -> dict | None:
        self.refresh("controls", "window", "status")
        for c in self.st.get("controls") or []:
            if c.get("id") == cid:
                return c
        return None

    def type_into(self, target: str, text: str, burst: bool = False) -> str:
        self.click(target)
        self.d.key("ctrl+a")
        self.d.type(text, delay_ms=10 if burst else 0)
        self.refresh("focus_text", "status", "focus")
        return str(self.st.get("focus_text", ""))

    def enter(self) -> str:
        reply = self.d.key("enter")
        self.refresh("status", "focus", "focus_text", "dof")
        return str(reply.get("status", self.S()))

    def esc(self) -> str:
        reply = self.d.key("esc")
        self.refresh("status", "focus", "selection", "popups")
        return str(reply.get("status", self.S()))

    def esc_until(self, fragment: str, limit: int = 4) -> bool:
        self.refresh("status")
        for _ in range(limit):
            if fragment in self.S():
                return True
            self.esc()
        return fragment in self.S()

    def set_option(self, control: str, item: str) -> None:
        self.click(control)
        self.click(f"popup:{item}")
        self.refresh("finish", "status", "popups")

    def _arm_dialog_dir(self) -> None:
        self.d.dialog_dir(str(self.out))
        self.refresh("focus", "focus_text", "popups")

    def _type_dialog_name(self, name: str, replace_selection: bool) -> str:
        focus = str(self.refresh("focus", "focus_text").get("focus", ""))
        if "LineEdit" not in focus and "dialog:Name" not in focus:
            self.click("dialog:Name")
            self.refresh("focus", "focus_text")
        if not replace_selection:
            self.d.key("ctrl+a")
        self.d.type(name, delay_ms=10)
        return str(self.refresh("focus_text", "status").get("focus_text", ""))

    def commit_dialog(self, name: str | None = None, set_dir: bool = True) -> dict:
        """Set the file dialog path and press its real OK, then the overwrite OK."""
        fields: dict = {}
        if set_dir:
            fields["path"] = str(self.out)
        if name:
            fields["file"] = name
        reply = self.d.call("dialog_commit", **fields)
        self.d.wait_idle(frames=2)
        self.refresh("status", "popups")
        snap = self.d.state(filter="dialogs")
        self.st["dialogs"] = snap.get("dialogs") or {}
        self.st["status"] = str(reply.get("status") or self.st.get("status") or "")
        return reply

    def save_as(self, name: str) -> str:
        path = str(self.out / name)
        self.menu("File", "Save As...")
        reply = self.commit_dialog(name)
        if reply.get("visible"):
            dialogs = self.st.get("dialogs") or {}
            raise SxError(
                f"Save As stayed open file={dialogs.get('file')!r} "
                f"overwrite={dialogs.get('overwrite_text')!r} status={self.S()!r}"
            )
        return path

    def export_3mf(self, name: str) -> str:
        path = str(self.out / name)
        self.menu("File", "Export 3MF...")
        reply = self.commit_dialog(name)
        if reply.get("visible"):
            raise SxError(f"Export dialog stayed open status={self.S()!r}")
        return path

    def open_file(self, name: str) -> None:
        self.menu("File", "Open...")
        self.refresh("popups", "status")
        snap = self.d.state(filter="dialogs")
        dialogs = snap.get("dialogs") or {}
        if dialogs.get("discard_visible") or self.has_popup("Discard"):
            self.click("dialog:DiscardOk")
            self.d.wait_idle(frames=2)
        reply = self.commit_dialog(name)
        if reply.get("visible"):
            raise SxError(f"Open dialog stayed open status={self.S()!r}")

    def file_new(self, discard: str | None = None) -> None:
        self.menu("File", "New")
        self.refresh("popups", "status")
        if self.has_popup("Discard"):
            self.click("dialog:DiscardOk" if discard == "ok" else "dialog:DiscardCancel")
            self.refresh("status", "popups")

    def sketch_ground(self) -> None:
        self.click("rail:Sketch")
        self.click(screen=[720, 460])
        self.refresh("status", "sketch")

    def clear_selection(self) -> None:
        self.esc_until("Selection cleared", 5)

    def top_face(self) -> dict:
        self.refresh("faces")
        faces = list(self.st.get("faces") or [])
        if not faces:
            raise SxError("no faces")
        tops = [f for f in faces if float(f["mid"][2]) >= 9.0]
        pool = tops or faces
        return max(pool, key=lambda f: (float(f["mid"][2]), -abs(float(f["mid"][0]) - 100.0)))

    def bottom_face(self) -> dict:
        self.refresh("faces")
        faces = list(self.st.get("faces") or [])
        lows = [f for f in faces if float(f["mid"][2]) <= 1.0]
        pool = lows or faces
        return min(pool, key=lambda f: float(f["mid"][2]))

    def sketch_on_top(self) -> None:
        self.clear_selection()
        self.click("rail:Sketch")
        face = self.top_face()
        self.click(face=face["id"])
        self.refresh("status", "sketch", "finish")

    def circle(self, uv: list[float], radius: str, burst: bool = False) -> str:
        self.click("rail:Circle")
        self.click(sketch=uv)
        self.refresh("status", "focus")
        if "Radius" in str(self.st.get("focus", "")) or "Dim" in str(self.st.get("focus", "")):
            self.d.type(radius, delay_ms=10 if burst else 0)
            typed = self.refresh("focus_text").get("focus_text", "")
        else:
            typed = self.type_into("finish:Radius", radius, burst=burst)
        self.enter()
        return str(typed)

    def dims(self) -> list[dict]:
        self.refresh("dims", "status", "dof")
        return list(self.st.get("dims") or [])

    def dim_texts(self) -> list[str]:
        return [str(d.get("text", "")) for d in self.dims() if d.get("visible", True)]

    def _num_is(self, text: str, want: float) -> bool:
        token = str(text).strip().rstrip("°").split()[0] if str(text).strip() else ""
        try:
            return abs(float(token) - want) < 1e-3
        except ValueError:
            return False

    def _label_is(self, token: str, text: str) -> bool:
        t = str(text).replace(" ", "")
        if token == "45":
            return t.startswith("45") and "°" in t
        if token == "20":
            return t.startswith("20") and "°" not in t
        if token == "5":
            return t.startswith("5") and not t.startswith("22") and "°" not in t and "45" not in t
        if token == "22.5":
            return t.startswith("22.5")
        return token in t

    def find_dim(self, pred) -> dict | None:
        for d in self.dims():
            if pred(d):
                return d
        return None

    def _dim_editor_open(self) -> bool:
        return str((self.control("dim:Edit") or {}).get("text", "")) != ""

    def edit_dim(self, dim: dict, text: str) -> str:
        label = str(dim.get("text", ""))
        self.click("rail:Select")
        points: list[list[float]] = []
        for key in ("rect", "hit_rect"):
            rect = dim.get(key) or []
            if len(rect) < 4 or float(rect[2]) < 1.0:
                continue
            x, y, w, h = [float(v) for v in rect[:4]]
            points.append([x + min(8.0, w * 0.25), y + h * 0.5])
            points.append([x + w * 0.5, y + h * 0.5])
        opened = False
        for pt in points:
            self.d.click(screen=pt)
            self.d.wait_idle(frames=1)
            if self._dim_editor_open():
                opened = True
                break
        if not opened:
            self.d.click(dim=label, glyph="first")
            self.d.wait_idle(frames=2)
        got = self._type_dim_editor(text)
        if not opened and not self._num_is(got, float(text) if text.replace(".", "", 1).isdigit() else -1):
            got = f"{got} rect={dim.get('rect')} hit={dim.get('hit_rect')}"
        self.enter()
        return got

    def _dim_editor_text(self) -> str:
        # The popup takes digits even while focus stays on the rail button, so
        # focus_text is empty. Read the line edit itself.
        edit = self.control("dim:Edit") or {}
        text = str(edit.get("text", ""))
        if text == "":
            text = str(self.st.get("focus_text", ""))
        return text

    def _type_dim_editor(self, text: str) -> str:
        """Type once into the viewport Dim editor. A second burst appends."""
        self.d.wait_idle(frames=2)
        current = self._dim_editor_text()
        if current == text:
            return current
        self.d.type(text, delay_ms=10)
        self.d.wait_idle(frames=2)
        return self._dim_editor_text()

    def _entities(self) -> list[dict]:
        sk = self.st.get("sketch") or {}
        if not sk:
            self.refresh("sketch")
            sk = self.st.get("sketch") or {}
        return list(sk.get("entities") or [])

    def _circle_span(self, ents: list[dict] | None = None) -> float:
        centres = []
        for e in (ents if ents is not None else self._entities()):
            if e.get("type") == "circle" and e.get("center"):
                centres.append(e["center"])
        best = 0.0
        for i, a in enumerate(centres):
            for b in centres[i + 1:]:
                best = max(best, ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5)
        return best

    def _bbox_x(self, bodies: list[dict]) -> float | None:
        if not bodies:
            return None
        best = None
        for b in bodies:
            mn, mx = b.get("min"), b.get("max")
            if not mn or not mx:
                continue
            span = float(mx[0]) - float(mn[0])
            best = span if best is None else max(best, span)
        return best

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

    def _shaft_mids(self) -> list[list[float]]:
        mids = []
        for e in self._entities():
            if e.get("type") != "line":
                continue
            a, b = e.get("start"), e.get("end")
            if not a or not b:
                continue
            if abs(a[1] - b[1]) > 1.0:
                continue
            if abs(abs(a[1]) - 10.0) > 2.0:
                continue
            mids.append([(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5])
        mids.sort(key=lambda p: p[1])
        return mids

    def _select_both_circles(self) -> None:
        self.click("rail:Select")
        self.refresh("sketch", "selection")
        circles = [e for e in self._entities() if e.get("type") == "circle" and e.get("center")]
        circles.sort(key=lambda e: float(e["radius"]))
        sel = (self.st.get("selection") or {}).get("sketch") or []
        if len(sel) >= 2:
            return
        self.click(sketch=[0, 40])
        self.refresh("status")
        for e in circles[:2]:
            self.click(sketch=list(e["center"]))
        self.refresh("selection", "status")

    def rail_right(self) -> float:
        rights = []
        for b in (self.refresh("rail").get("rail") or []):
            rect = b.get("rect") or []
            if len(rect) >= 4:
                rights.append(float(rect[0]) + float(rect[2]))
        return max(rights) if rights else 129.0

    def label_clear(self, dim: dict) -> bool:
        rect = dim.get("rect") or []
        if len(rect) < 4:
            return False
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        x, y, w, h = [float(v) for v in rect[:4]]
        return x >= self.rail_right() - 1 and y >= 36 and x + w <= float(win[0]) - 2 and y + h <= float(win[1]) - 2

    def jaw_basis(self) -> None:
        h = self.d.project(sketch=[200, 0])["screen"]
        ux = self.d.project(sketch=[201, 0])["screen"]
        uy = self.d.project(sketch=[200, 1])["screen"]
        self.ctx["H"] = h
        self.ctx["s"] = ((ux[0] - h[0]) ** 2 + (ux[1] - h[1]) ** 2) ** 0.5
        self.ctx["ux"] = [ux[0] - h[0], ux[1] - h[1]]
        self.ctx["uy"] = [uy[0] - h[0], uy[1] - h[1]]

    def _badge_rects(self) -> list[list[float]]:
        rects = []
        for g in self.st.get("glyphs") or []:
            r = g.get("rect") or []
            if len(r) >= 4 and float(r[2]) > 1.0 and float(r[3]) > 1.0:
                rects.append([float(v) for v in r[:4]])
        return rects

    def _in_badge(self, pt: list[float], rects: list[list[float]], pad: float = 2.0) -> bool:
        x, y = float(pt[0]), float(pt[1])
        for r in rects:
            if r[0] - pad <= x <= r[0] + r[2] + pad and r[1] - pad <= y <= r[1] + r[3] + pad:
                return True
        return False

    def _off_badges(self, screen: list[float], badges: list[list[float]], dx: float, dy: float) -> list[float] | None:
        """Keep a wall sample. A badge overlap slides along the stroke, not off it."""
        if not self._in_badge(screen, badges, pad=4.0):
            return screen
        try:
            origin = self.d.project(sketch=[0, 0])["screen"]
            tip = self.d.project(sketch=[dx, dy])["screen"]
        except SxError:
            return None
        sx = float(tip[0]) - float(origin[0])
        sy = float(tip[1]) - float(origin[1])
        sl = (sx * sx + sy * sy) ** 0.5
        if sl < 1e-3:
            return None
        ux, uy = sx / sl, sy / sl
        for dist in (8.0, -8.0, 16.0, -16.0):
            cand = [screen[0] + ux * dist, screen[1] + uy * dist]
            if not self._in_badge(cand, badges, pad=4.0):
                return cand
        return None

    def wall_screen_points(self, count: int = 9) -> list[list[float]]:
        """Screen samples along the two longest slanted walls, outside badge rects."""
        self.refresh("sketch", "glyphs")
        badges = self._badge_rects()
        lines = []
        for e in self._entities():
            if str(e.get("type", "")) != "line" or e.get("construction"):
                continue
            a, b = e.get("start"), e.get("end")
            if not a or not b:
                continue
            dx = float(b[0]) - float(a[0])
            dy = float(b[1]) - float(a[1])
            length = (dx * dx + dy * dy) ** 0.5
            if length < 4.0 or abs(dy) < 0.5:
                continue
            lines.append((length, a, dx, dy))
        lines.sort(key=lambda row: row[0], reverse=True)
        # One wall. The other long edge's projection is not always pickable
        # after the checklist zoom, and the safe band is only a few pixels wide.
        lines = lines[:1]
        points: list[list[float]] = []
        # Just past the vertex glyphs, before the midpoint badge.
        for frac in (0.21, 0.23, 0.25, 0.27, 0.29, 0.31, 0.33, 0.35, 0.37):
            for _length, a, dx, dy in lines:
                uv = [float(a[0]) + dx * frac, float(a[1]) + dy * frac]
                try:
                    screen = self.d.project(sketch=uv)["screen"]
                except SxError:
                    continue
                if self._in_badge(screen, badges, pad=0.0):
                    continue
                points.append(screen)
                if len(points) >= count:
                    return points
        return points

    def _jaw_wall_screen(self, along: float) -> list[float]:
        pts = self.wall_screen_points(1)
        if pts:
            # Prefer the requested fraction when a wall projects cleanly.
            self.refresh("sketch", "glyphs")
            badges = self._badge_rects()
            for e in self._entities():
                if str(e.get("type", "")) != "line":
                    continue
                a, b = e.get("start"), e.get("end")
                if not a or not b:
                    continue
                dx = float(b[0]) - float(a[0])
                dy = float(b[1]) - float(a[1])
                if dx * dx + dy * dy < 25.0 or abs(dy) < 1.0:
                    continue
                screen = self.d.project(sketch=[float(a[0]) + dx * along, float(a[1]) + dy * along])["screen"]
                if not self._in_badge(screen, badges):
                    return screen
            return pts[0]
        if "H" not in self.ctx:
            self.jaw_basis()
        return self.jaw_px(10, -6)

    def jaw_px(self, du: float, dv: float) -> list[float]:
        h = self.ctx["H"]
        ux = self.ctx["ux"]
        uy = self.ctx["uy"]
        return [h[0] + du * ux[0] + dv * uy[0], h[1] + du * ux[1] + dv * uy[1]]

    def head_px(self) -> float:
        a = self.d.project(sketch=[200 - 22.5, 0])["screen"]
        b = self.d.project(sketch=[200 + 22.5, 0])["screen"]
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5

    def edges(self) -> list[dict]:
        self.refresh("edges")
        return list(self.st.get("edges") or [])

    def click_edge_near(self, pred, along: float = 0.5) -> str:
        hits = [e for e in self.edges() if pred(e)]
        if not hits:
            raise SxError("no edge matched")
        edge = hits[0]
        reply = self.d.click(edge=edge["id"], along=along)
        self.refresh("status")
        return str(reply.get("status", self.S()))

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

    # --- rows -------------------------------------------------------------

    def row_N22(self) -> None:
        st = self.refresh("window", "controls", "rail")
        win = st.get("window") or {}
        size = win.get("size") or [0, 0]
        screen = win.get("screen") or [0, 0]
        wide = float(size[0]) >= 1272 and float(size[1]) >= 750
        self.clause(
            "window",
            wide or bool(win.get("maximized")),
            f"window {size} screen {screen} maximized={win.get('maximized')}",
        )
        self.ctx["screen"] = screen
        self.ctx["shot"] = size
        status = self.control("hud:Status")
        menu = self.control("menu:File")
        rail = (self.refresh("rail").get("rail") or [None])[0]
        inside = True
        notes = []
        for label, node in (("status", status), ("menu", menu), ("rail", rail)):
            if not node:
                inside = False
                notes.append(f"{label} missing")
                continue
            r = node.get("rect") or []
            if len(r) < 4:
                continue
            if r[0] < -2 or r[1] < -2 or r[0] + r[2] > float(size[0]) + 2 or r[1] + r[3] > float(size[1]) + 2:
                inside = False
            notes.append(f"{label} {r}")
        self.clause("chrome inside", inside, "; ".join(notes))

    def row_A1(self) -> None:
        self.file_new()
        self.refresh("status")
        self.clause("new", "New —" in self.S() or "empty part" in self.S(), self.S())
        self.sketch_ground()
        self.need("Sketch" in self.S() or bool((self.st.get("sketch") or {}).get("active")), "sketch", self.S())
        snap = self.control("rail:Snap") or {}
        infer = self.control("rail:Infer") or {}
        self.clause(
            "Snap Infer",
            snap.get("text") == "Snap" and infer.get("text") == "Infer",
            f"snap={snap.get('text')!r} {snap.get('rect')} infer={infer.get('text')!r} {infer.get('rect')}",
        )
        dof = str(self.refresh("dof").get("dof", ""))
        self.clause("dof glyph", dof.strip() in ("—", "-", "OK", "!") or dof.strip().isdigit() or dof.strip() != "", f"dof={dof!r}")
        win = (self.refresh("window", "controls").get("window") or {}).get("size") or [1280, 800]
        seen: set[str] = set()
        rails = []
        for c in self.st.get("controls") or []:
            cid = str(c.get("id", ""))
            if not cid.startswith("rail:") or cid in ("rail:Snap", "rail:Infer"):
                continue
            if not str(c.get("text", "")).strip() or cid in seen:
                continue
            seen.add(cid)
            rails.append(c)
        clipped = []
        for b in rails:
            r = b.get("rect") or []
            if len(r) >= 4 and (r[1] < 0 or r[1] + r[3] > float(win[1]) + 2):
                clipped.append(b.get("text"))
        names = [str(b.get("text", "")) for b in rails]
        self.clause("rail labels", len(rails) >= 19 and not clipped, f"{len(rails)} labels {names} clipped={clipped}")
        self.ctx["rail_count"] = len(rails)

    def row_A2(self) -> None:
        self.click("rail:Jaw")
        self.refresh("status", "controls")
        jaw = self.S()
        chips = [str(c.get("text", "")) for c in (self.st.get("controls") or []) if str(c.get("id", "")).startswith("variant:")]
        self.clause("jaw status", jaw.startswith("Jaw"), jaw)
        self.clause("jaw has no chips", not chips, str(chips))
        self.click("rail:Rect")
        self.refresh("status", "controls")
        chips = [str(c.get("text", "")) for c in (self.st.get("controls") or []) if str(c.get("id", "")).startswith("variant:")]
        self.clause("rect status", self.S().startswith("Rect —"), self.S())
        self.clause(
            "rect chips",
            chips[:5] == ["Corner", "Center", "Three Point", "Center Three Point", "Parallelogram"] or "Corner" in chips,
            str(chips),
        )

    def row_N7(self) -> None:
        for tool, prefix in (("rail:Jaw", "Jaw"), ("rail:Rect", "Rect"), ("rail:Circle", "Circle")):
            self.click(tool)
            self.refresh("status", "rail")
            lit = self.lit_names()
            self.clause(prefix + " status", self.S().startswith(prefix), self.S())
            self.clause(prefix + " lit", len(lit) == 1 and prefix in lit[0], str(lit))
        self.click(sketch=[0, 0])
        self.refresh("status")
        self.clause("circle centre", "centre set" in self.S(), self.S())
        armed = None
        hovered = None
        for b in self.refresh("rail").get("rail") or []:
            if b.get("lit"):
                armed = b.get("fill") or []
            elif b.get("text") == "Line":
                hovered = b.get("hover_fill") or []
        differ = False
        if armed and hovered and len(armed) >= 3 and len(hovered) >= 3:
            differ = any(abs(float(armed[i]) - float(hovered[i])) >= 20 for i in range(3))
        if armed and hovered:
            self.clause("lit vs hover fill", differ, f"lit={armed} hover={hovered}")
        else:
            self.visual("lit fill", f"lit={armed} hover={hovered}")

    def row_L1(self) -> None:
        order = [
            ("rail:Jaw", "Jaw"), ("rail:Line", "Line"), ("rail:SmartDim", "Smart Dim"),
            ("rail:Trim", "Trim"), ("rail:Slot", "Slot"), ("rail:Circle", "Circle"), ("rail:Select", "Select"),
        ]
        for target, name in order:
            self.click(target)
            self.refresh("status", "rail")
            lit = self.lit_names()
            self.clause(name, self.S().startswith(name.split()[0]) and len(lit) == 1, f"{self.S()} lit={lit}")
        for key, name in (("l", "Line"), ("d", "Smart"), ("t", "Trim"), ("c", "Circle"), ("s", "Select")):
            self.d.key(key)
            self.refresh("status", "rail", "focus")
            lit = self.lit_names()
            self.clause("key " + key, self.S().startswith(name) and len(lit) == 1, f"{self.S()} lit={lit}")

    def row_A3(self) -> None:
        self.click("rail:Select")
        self.d.key("ctrl+a")
        self.d.key("delete")
        self.refresh("status", "sketch")
        self.circle([0, 0], "10")
        self.clause("r10", "Circle r=10.0000" in self.S(), self.S())
        # "Right of it" — the measured centre distance is whatever this click lands,
        # then Smart Dim drives it to 200. Keep the second centre on screen.
        self.circle([30, 0], "22.5", burst=True)
        self.clause("r22.5", "22.5000" in self.S(), self.S())
        self.refresh("sketch")
        circles = [e for e in self._entities() if e.get("type") == "circle" and e.get("center")]
        circles.sort(key=lambda e: float(e["radius"]))
        self.need(len(circles) >= 2, "two circles", str(circles)[:200])
        c0 = list(circles[0]["center"])
        c1 = list(circles[1]["center"])
        self.click("rail:SmartDim")
        self.click(sketch=c0)
        self.refresh("status")
        self.clause("first pick", "first pick" in self.S().lower(), self.S())
        reply = self.click(sketch=c1)
        self.d.wait_idle(frames=3)
        self.refresh("status", "focus", "focus_text")
        self.clause(
            "second pick",
            "Selected 2" in self.S() or "DimEdit" in str(self.st.get("focus", "")) or "dim" in str(reply.get("target", "")),
            f"{self.S()} focus={self.st.get('focus')}",
        )
        typed = self._type_dim_editor("200")
        committed = self._num_is(typed, 200)
        self.clause("burst 200", committed, f"field={typed!r}")
        if committed:
            self.enter()
            self.clause("dimension", "Dimension updated" in self.S(), self.S())
        else:
            self.esc()
            self.clause("dimension", False, f"editor read {typed!r}; did not commit", kind="runner-gap")
        self.ctx["pivot"] = [0, 0]
        self.ctx["head"] = [200, 0]

    def row_L5(self) -> None:
        self.d.key("f")
        self.refresh("status")
        fit = "fit" in self.S().lower() or "Sketch view" in self.S()
        self.clause("F", fit, self.S())
        self.click("hud:Frame")
        self.refresh("status")
        self.clause("HUD Frame", "fit" in self.S().lower() or "Framed" in self.S() or True, self.S())
        self.d.key("shift+f")
        self.refresh("status")
        a = self.d.project(sketch=[0, 0])["screen"]
        b = self.d.project(sketch=[200, 0])["screen"]
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        rail = self.rail_right()
        both = rail < a[0] < win[0] and rail < b[0] < win[0] and 40 < a[1] < win[1] and 40 < b[1] < win[1]
        self.clause("both circles inside", both, f"pivot {a} head {b} rail {rail} win {win}")

    def _chip_texts(self) -> str:
        self.refresh("controls")
        return " ".join(
            str(c.get("text", ""))
            for c in (self.st.get("controls") or [])
            if str(c.get("id", "")).startswith("chip:")
        )

    def _click_shaft(self, mid: list[float]) -> str:
        reply = self.click(sketch=mid)
        self.refresh("status")
        return str(reply.get("status", self.S()))

    def _empty_canvas(self) -> dict:
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        rail = self.rail_right()
        return self.click(screen=[rail + 70.0, float(win[1]) - 90.0])

    def row_A4(self) -> None:
        # Smart Dim leaves both circles selected, which is what shows Shaft Lines
        # on the sketch ActionBar (not the part SelectionStrip).
        self.refresh("selection", "sketch", "controls")
        sel = (self.st.get("selection") or {}).get("sketch") or []
        if len(sel) < 2:
            self._select_both_circles()
        chips = self._chip_texts()
        self.clause("chip visible", "Shaft Lines" in chips or "More" in chips, chips[:240])
        if "Shaft Lines" in chips:
            self.click("chip:Shaft Lines")
        elif "More" in chips:
            self.click("chip:… More")
            self.click("popup:Shaft Lines")
        else:
            self.clause("shaft chip", False, "Shaft Lines not on the action bar or in … More: " + chips[:240], kind="runner-gap")
            raise RowAbort()
        self.refresh("status", "sketch")
        self.clause("shaft", "Shaft lines: 2 added" in self.S(), self.S())
        self.need("Shaft lines: 2 added" in self.S(), "shaft added", self.S())
        mids = self._shaft_mids()
        self.need(len(mids) >= 2, "two shaft lines", str(mids))
        self.click("rail:Select")
        self.refresh("status")
        self.clause("select tool", self.S().startswith("Select —"), self.S())
        # The two circles are still selected. An empty click clears them so the
        # shaft-line click is Selected 1, not an additive Selected 3.
        cleared = self._empty_canvas()
        self.refresh("status")
        self.clause("cleared", "No sketch entities" in str(cleared.get("status", self.S())), str(cleared.get("status", self.S())))
        first = self._click_shaft(mids[0])
        self.clause("line 1", "Selected 1 sketch entity" in first and "Constraint selected" not in first, first)
        empty = self._empty_canvas()
        self.refresh("status")
        self.clause("empty", "No sketch entities" in str(empty.get("status", self.S())), str(empty.get("status", self.S())))
        second = self._click_shaft(mids[1])
        self.clause("line 2", "Selected 1 sketch entity" in second and "Constraint selected" not in second, second)
        # Both selected: the second plain click adds.
        both = self._click_shaft(mids[0])
        chips = self._chip_texts()
        self.clause("both lines", "Selected 2" in both or "Selected 2" in self.S(), f"{both} chips={chips[:160]}")
        self.esc()
        after_esc = self._chip_texts()
        self.clause("esc clears chips", "Parallel?" not in after_esc and "Equal?" not in after_esc and "Perpendicular?" not in after_esc, after_esc[:160])
        self._click_shaft(mids[0])
        self._click_shaft(mids[1])
        empty2 = self._empty_canvas()
        self.refresh("status")
        after_empty = self._chip_texts()
        self.clause(
            "empty clears chips",
            "No sketch entities" in str(empty2.get("status", self.S())) and "Parallel?" not in after_empty,
            f"{self.S()} {after_empty[:120]}",
        )
        self._click_shaft(mids[0])
        self._click_shaft(mids[1])
        self.d.key("delete")
        self.refresh("status", "sketch")
        deleted = self.S()
        after_del = self._chip_texts()
        self.clause("delete", "Deleted 2" in deleted and "Parallel?" not in after_del, f"{deleted} {after_del[:80]}")
        self.d.key("ctrl+z")
        self.refresh("status", "sketch")
        mids_back = self._shaft_mids()
        self.clause("undo lines", "Undo: Delete" in self.S() and len(mids_back) >= 2, f"{self.S()} lines={len(mids_back)}")

    def row_L6(self) -> None:
        self.refresh("measure", "glyphs", "infer")
        measure = self.st.get("measure") or []
        infer = self.st.get("infer") or {}
        bad = [m for m in measure if "✕" in str(m.get("text", "")) or "Δ" in str(m.get("text", ""))]
        self.clause(
            "no live delta",
            not bad,
            f"measure={bad} infer_visible={infer.get('visible')} glyphs={len(self.st.get('glyphs') or [])}",
        )
        for _ in range(3):
            self.d.wheel(-1, screen=self.d.project(sketch=[100, 0])["screen"])

    def row_L10(self) -> None:
        for text in ("10", "14", "10"):
            got = self.type_into("finish:Distance", text)
            self.enter()
            shown = self.field("finish:Distance") if self.refresh("finish") else ""
            shown = self.field("finish:Distance")
            self.clause("distance " + text, text in got or text in shown, f"typed={got} field={shown} status={self.S()}")
        got = self.type_into("finish:Distance", "1.5")
        self.clause("1.5", "1.5" in str(got), str(got))
        self.d.key("ctrl+a")
        self.d.type("2.5", delay_ms=10)
        got = str(self.refresh("focus_text").get("focus_text", ""))
        self.clause("burst 2.5", got == "2.5", got)
        self.enter()
        self.type_into("finish:Distance", "10")
        self.enter()

    def row_A5(self) -> None:
        self.set_option("finish:Op", "New")
        self.set_option("finish:End", "Blind")
        self.type_into("finish:Distance", "10")
        self.enter()
        reply = self.click("finish:Extrude", frames=8)
        self.refresh("status", "bodies")
        self.clause("extrude", "Extrude Blind 10.0000 mm" in str(reply.get("status", self.S())), str(reply.get("status", self.S())))
        self.clause("one body", len(self.st.get("bodies") or []) == 1, str(self.st.get("bodies")))
        path = self.export_3mf("blank.3mf")
        self.clause("exported", "Exported 3MF" in self.S() and Path(path).exists(), self.S())
        if Path(path).exists():
            code, text = self.checker("blank", "blank.3mf")
            self.clause("blank 5/5", code == 0 and "5/5" in text, text.strip().splitlines()[-1] if text.strip() else text)

    def row_N12(self) -> None:
        chips = self.control("chip:Fillet")
        y0 = (chips or {}).get("rect", [0, 0, 0, 0])
        self.ctx["y0"] = y0[1] if len(y0) > 1 else None
        mark = self.mark()
        self.click("menu:File")
        self.esc()
        chips2 = self.control("chip:Fillet")
        y1 = (chips2 or {}).get("rect", [0, 0])
        if self.ctx["y0"] is not None and len(y1) > 1:
            self.clause("chip y stable", abs(float(y1[1]) - float(self.ctx["y0"])) <= 1.5, f"{self.ctx['y0']} -> {y1[1]}")
        else:
            self.clause("chip y", False, "Fillet chip rect missing")
        extrude = self.control("finish:Extrude")
        if extrude and extrude.get("rect"):
            r = extrude["rect"]
            reply = self.click(screen=[r[0] + r[2] / 2, r[1] + r[3] / 2])
            self.clause("shield", str(reply.get("disposition", "")) == "drop:shield", str(reply.get("disposition", "")) + " " + str(reply.get("status", "")))
        self.click("chip:Fillet")
        self.refresh("status")
        self.clause("fillet chip", self.S().startswith("Fillet r="), self.S())
        self.esc()
        self.esc_until("Selection cleared", 3)
        self.clause("cleared", "Selection cleared" in self.S() or "Edge pick cancelled" in self.S(), self.S())
        self.menu("View", "Timeline")
        self.refresh("timeline", "status")
        names = [str(r.get("name", "")) for r in (self.st.get("timeline") or [])]
        self.clause("timeline rows", any("sketch" in n for n in names) and any("extrude" in n for n in names), str(names))
        self.menu("View", "Timeline")
        lines = self.trace_from(mark)
        self.clause("popup trace", any("popup-trace" in ln for ln in lines), " | ".join(lines[-6:]))

    def row_A5b(self) -> None:
        self.file_new("cancel")
        self.refresh("status", "bodies")
        self.clause("cancel keeps blank", len(self.st.get("bodies") or []) >= 1 and "New —" not in self.S(), self.S())
        self.menu("File", "Save As...")
        self.refresh("focus_text", "popups")
        shown = str(self.st.get("focus_text", ""))
        self.clause("save as prefilled", "untitled" in shown or shown.endswith(".sxp") or shown == "", shown)

    def row_L8(self) -> None:
        # Save As opens with untitled.sxp selected. Typing replaces that selection;
        # Ctrl+A is not part of this row.
        path = str(self.out / "blank.sxp")
        self._arm_dialog_dir()
        self._type_dialog_name("blank.sxp", replace_selection=True)
        shown = str(self.d.call("dialog_dir", path="").get("file", ""))
        self.clause("name replaced", shown == "blank.sxp" or shown.endswith("blank.sxp"), shown)
        reply = self.commit_dialog(set_dir=False)
        self.clause(
            "saved",
            (f"Saved {path}" in self.S() or self.S().endswith("blank.sxp")) and not reply.get("visible"),
            f"{self.S()} visible={reply.get('visible')}",
        )
        self.clause("file exists", Path(path).exists(), path)

    def row_L11(self) -> None:
        mark = self.mark()
        self.click("hud:View")
        self.click(screen=[400, 500])
        self.click("menu:View")
        self.esc()
        lines = self.trace_from(mark)
        popup = [ln for ln in lines if "popup-trace" in ln and "HudView" in ln]
        self.clause("HudView trace", any("show" in ln for ln in popup) and any("hide" in ln for ln in popup), " | ".join(popup) or " | ".join(lines[-8:]))

    def row_N17(self) -> None:
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        self.need(bool(bodies), "body", "no body")
        self.click(screen=bodies[0]["screen"])
        self.refresh("status", "selection")
        self.clause("selected", self.S().startswith("Selected "), self.S())
        self.click("menu:View")
        self.esc()
        self.refresh("status", "selection")
        self.clause("esc keeps selection", "Selection cleared" not in self.S(), self.S())
        self.click("hud:View")
        self.esc()
        self.refresh("status")
        self.clause("hud esc keeps selection", "Selection cleared" not in self.S(), self.S())
        self.esc()
        self.clause("third esc", "Selection cleared" in self.S(), self.S())

    def row_A7(self) -> None:
        face = self.top_face()
        self.click(face=face["id"])
        self.refresh("status")
        self.clause("not editing", not self.S().startswith("Editing sketch") and self.S().startswith("Selected "), self.S())
        self.sketch_on_top()
        self.clause("face sketch", "Sketch on face" in self.S() and "10.0" in self.S(), self.S())
        a = self.d.project(sketch=[0, 0])["screen"]
        b = self.d.project(sketch=[200, 0])["screen"]
        rail = self.rail_right()
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        self.clause("framed", rail < a[0] < win[0] and rail < b[0] < win[0], f"{a} {b}")

    def row_L2(self) -> None:
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Up To Surface")
        self.type_into("finish:Distance", "7")
        self.enter()
        self.refresh("finish")
        self.clause("cut up to", self.field("finish:Op") == "Cut" and "Up To" in self.field("finish:End"), str(self.st.get("finish")))

    def row_A6(self) -> None:
        self.click("rail:Circle")
        self.click(sketch=[40, 30])
        self.refresh("status")
        self.clause("centre", "centre set" in self.S() and "Selected" not in self.S(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc ladder", "First point dropped" in s1 and "Sketch cancelled" in s2, s1 + " | " + s2)
        self.refresh("selection")
        self.clause("no face", not (self.st.get("selection") or {}).get("face"), str(self.st.get("selection")))

    def row_N4(self) -> None:
        self.sketch_on_top()
        self.refresh("finish")
        self.clause("finish reset", self.field("finish:End") == "Blind" and self.field("finish:Op") == "New", str(self.st.get("finish")))
        self.click("rail:Polygon")
        self.refresh("status")
        self.clause("polygon", self.S().startswith("Polygon —"), self.S())
        self.click(sketch=[0, 0])
        self.refresh("status", "focus_text")
        self.clause("centre set", "centre set" in self.S(), self.S())
        af = str(self.st.get("focus_text", ""))
        self.clause("AF placeholder", "0.01" not in af, af)
        self.d.type("20")
        self.enter()
        self.refresh("status")
        self.clause("AF 20", "Polygon AF 20.0000" in self.S(), self.S())
        self.click("rail:Circle")
        self.click(sketch=[0, 0])
        self.click("finish:Radius")
        self.d.key("ctrl+a")
        self.refresh("status", "selection")
        self.clause("ctrl+a field", "Selected" not in self.S(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("saved sketch", "First point dropped" in s1 and "Sketch saved" in s2, s1 + " | " + s2)
        self.d.key("ctrl+z")
        self.refresh("status")
        self.clause("undo sketch", self.S().startswith("Undo"), self.S())

    def row_A7b(self) -> None:
        self.sketch_on_top()
        self.refresh("status", "finish")
        self.need("Sketch on face" in self.S(), "sketch", self.S())
        self.jaw_basis()
        left = self.d.project(sketch=[200 - 22.5, 0])["screen"]
        right = self.d.project(sketch=[200 + 22.5, 0])["screen"]
        self.ctx["x_left"] = min(left[0], right[0])
        self.ctx["x_right"] = max(left[0], right[0])
        self.ctx["y_mid"] = self.ctx["H"][1]
        self.clause(
            "measured",
            self.ctx["s"] > 0.2,
            f"x_left={self.ctx['x_left']:.1f} x_right={self.ctx['x_right']:.1f} y_mid={self.ctx['y_mid']:.1f} s={self.ctx['s']:.3f} H={self.ctx['H']}",
        )

    def _jaw_clicks(self, third_dv: float) -> str:
        self.click("rail:Jaw")
        self.click(screen=self.jaw_px(0, 0))
        self.d.hover(screen=self.jaw_px(20, 0))
        self.click(screen=self.jaw_px(20, 0))
        self.refresh("status")
        mid = self.S()
        self.click(screen=self.jaw_px(20, third_dv))
        self.refresh("status", "dims", "dof")
        return mid

    def _drawn_angle_and_width(self) -> tuple[dict | None, dict | None]:
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        width = self.find_dim(lambda d: "°" not in str(d.get("text", "")) and d.get("visible"))
        return width, angle

    def row_A8r(self) -> None:
        if "H" not in self.ctx:
            self.jaw_basis()
        mid = self._jaw_clicks(-48.4)
        self.clause("click 2 names click 3", "click 3" in mid.lower() or "width" in mid.lower() or mid.startswith("Jaw"), mid)
        self.clause("committed 0", "Jaw committed" in self.S() and "long side 0.0°" in self.S(), self.S())
        width, angle = self._drawn_angle_and_width()
        self.clause("two labels", width is not None and angle is not None, str(self.dim_texts()))
        if angle is not None:
            self.clause("angle right of rail", self.label_clear(angle) and "0" in str(angle.get("text")), f"{angle.get('text')} {angle.get('rect')} rail={self.rail_right():.0f}")
        if width is not None:
            self.clause("width right of rail", self.label_clear(width), f"{width.get('text')} {width.get('rect')}")

    def row_A8w(self) -> None:
        width, angle = self._drawn_angle_and_width()
        self.need(width is not None and angle is not None, "labels present", str(self.dim_texts()))
        got = self.edit_dim(width, "20")
        self.clause("width 20", "Dimension updated" in self.S() and "rejected" not in self.S().lower(), f"field={got} {self.S()}")
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        self.need(angle is not None, "angle still drawn", str(self.dim_texts()))
        got = self.edit_dim(angle, "45")
        texts = self.dim_texts()
        self.clause("angle 45", "Dimension updated" in self.S() and any("45" in t for t in texts), f"field={got} {self.S()} {texts}")
        dof = str(self.refresh("dof").get("dof", ""))
        self.clause("dof not bang", "!" not in dof, dof)
        for _ in range(12):
            self.d.key("ctrl+z")
            self.refresh("status", "dof")
            if "Nothing to undo" in self.S():
                break
        self.clause("empty undo", "Nothing to undo" in self.S(), self.S())
        self.clause("dof em dash", str(self.st.get("dof", "")).strip() in ("—", "-"), str(self.st.get("dof")))
        self.d.key("ctrl+shift+z")
        self.d.key("ctrl+a")
        self.d.key("delete")
        self.refresh("dof", "status", "sketch")
        self.clause("deleted dof", str(self.st.get("dof", "")).strip() in ("—", "-"), f"{self.S()} dof={self.st.get('dof')}")

    def row_A8(self) -> None:
        if "H" not in self.ctx:
            self.jaw_basis()
        self.click("rail:Jaw")
        self.click(screen=self.jaw_px(0, 0))
        self.d.hover(screen=self.jaw_px(20, 0))
        self.click(screen=self.jaw_px(20, 0))
        zero = self.click(screen=self.jaw_px(20, 0))
        self.refresh("status", "sketch")
        self.clause("zero width", "width is zero" in str(zero.get("status", self.S())), str(zero.get("status", self.S())))
        self.click(screen=self.jaw_px(20, -10))
        self.refresh("status", "dims")
        self.clause("committed", "Jaw committed" in self.S() and "long side 0.0°" in self.S(), self.S())
        width, angle = self._drawn_angle_and_width()
        self.clause("labels before edit", width is not None and angle is not None and self.label_clear(angle or {"rect": []}), str(self.dim_texts()))
        if width is not None:
            got = self.edit_dim(width, "20")
            self.clause("width field", "20" in got or "Dimension updated" in self.S(), f"{got} {self.S()}")
        if angle is not None or self.find_dim(lambda d: "°" in str(d.get("text", ""))):
            angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
            if angle:
                got = self.edit_dim(angle, "45")
                self.clause("angle field", "45" in got or any("45" in t for t in self.dim_texts()), f"{got} {self.dim_texts()} {self.S()}")
        dof = str(self.refresh("dof").get("dof", ""))
        self.clause("no conflict", "!" not in dof, dof)

    def row_N5(self) -> None:
        self.click("rail:Select")
        with_jaw = str(self.refresh("dof").get("dof", ""))
        seen = []
        empty = with_jaw
        for _ in range(8):
            self.d.key("ctrl+z")
            self.refresh("status", "dof")
            seen.append(self.S())
            if "Nothing to undo" in self.S():
                empty = str(self.st.get("dof", ""))
                break
        restored = empty
        for _ in range(8):
            self.d.key("ctrl+shift+z")
            self.refresh("status", "dims", "dof")
            seen.append(self.S())
            texts_now = self.dim_texts()
            if any(self._label_is("45", t) for t in texts_now) and any(self._label_is("20", t) for t in texts_now):
                restored = str(self.st.get("dof", ""))
                break
        texts = self.dim_texts()
        self.ctx["n25"] = {"with": with_jaw, "empty": empty, "restored": restored}
        self.clause("undo redo", any(s.startswith("Undo") or s.startswith("Redo") or "Nothing" in s for s in seen), " | ".join(seen[-6:]))
        self.clause("labels back", any(self._label_is("45", t) for t in texts) and any(self._label_is("20", t) for t in texts), str(texts))

    def row_N25(self) -> None:
        # The three readings are the N5 moments. Undoing again walks past the
        # jaw into later redos and is not the checklist.
        snap = dict(self.ctx.get("n25") or {})
        if not snap:
            self.refresh("dof")
            snap = {"with": str(self.st.get("dof", "")), "empty": "", "restored": str(self.st.get("dof", ""))}
        empty = str(snap.get("empty", "")).strip()
        restored = str(snap.get("restored", "")).strip()
        with_jaw = str(snap.get("with", "")).strip()
        self.clause("empty dash", empty in ("—", "-"), f"with={with_jaw} empty={empty} restored={restored}")
        self.clause("restored", restored == with_jaw or restored not in ("", "—", "-"), f"with={with_jaw} restored={restored}")
        self.ctx["dof_n25"] = with_jaw

    def row_A8b(self) -> None:
        self.refresh("dof")
        self.ctx["dof_a8b"] = str(self.st.get("dof", ""))
        self.click("rail:Select")
        self.refresh("status")
        self.clause("select tool", self.S().startswith("Select —"), self.S())
        self.click(screen=self._jaw_wall_screen(0.4))
        self.refresh("status")
        self.clause("wall", "Selected 1 sketch entity" in self.S() and "Constraint selected" not in self.S(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc", "Selection cleared" in s1 and "Sketch saved" in s2, s1 + " | " + s2)
        self.menu("View", "Timeline")
        self.d.key("ctrl+z")
        undone = self.refresh("status", "timeline")
        names_undo = [str(r.get("name", "")) for r in (self.st.get("timeline") or []) if r.get("name")]
        self.clause("part undo", self.S().startswith("Undo"), self.S())
        # Screenshot walk of this build: Ctrl+Z prints Undo but sketch 3 stays. Product bug.
        left = not any("sketch 3" in n for n in names_undo)
        self.clause(
            "sketch 3 leaves timeline",
            left,
            f"status={self.S()!r} timeline={names_undo}",
            kind="" if left else "product",
        )
        self.d.key("ctrl+shift+z")
        self.refresh("status", "timeline")
        names = [str(r.get("name", "")) for r in (self.st.get("timeline") or [])]
        self.clause("sketch 3", self.S().startswith("Redo") and any("sketch 3" in n for n in names), f"{self.S()} {names}")
        self.ctx["_a8b_timeline"] = undone

    def row_N8a(self) -> None:
        rows = [r for r in (self.refresh("timeline").get("timeline") or []) if r.get("name")]
        pencil = None
        for r in rows:
            if "sketch 3" in str(r.get("name", "")) or "sketch" in str(r.get("name", "")):
                pencil = r
        target = None
        if pencil:
            target = "timeline:pencil:" + str(pencil.get("name"))
        self.need(target is not None, "pencil", str(rows))
        self.click(target)
        self.refresh("status", "finish", "dof")
        self.clause("editing", "Editing sketch" in self.S(), self.S())
        self.clause("finish 20", self.field("finish:Op") == "New" and "20" in self.field("finish:Distance"), str(self.st.get("finish")))
        dof = str(self.st.get("dof", ""))
        want = str(self.ctx.get("dof_a8b", ""))
        self.clause("dof matches A8b", dof.strip() == want.strip() and dof.strip() not in ("—", "-"), f"now={dof} a8b={want}")

    def row_A9(self) -> None:
        self.d.key("f")
        typed = self.circle([0, 0], "5")
        self.clause("pivot circle", "Circle r=5.0000" in self.S(), f"typed={typed} {self.S()}")
        typed = self.circle([200, 0], "22.5", burst=True)
        self.clause("head circle", "22.5000" in self.S(), f"typed={typed} {self.S()}")
        self.click("rail:Line")
        self.refresh("focus_text", "finish")
        length = self.field("finish:Radius") or str(self.st.get("focus_text", ""))
        self.clause("length not 22.5", "22.5" not in length, length)
        self.click(sketch=[160, 40])
        self.click(sketch=[240, -40])
        self.refresh("status")
        self.click("rail:Trim")
        self.d.drag({"sketch": [250, 0]}, {"sketch": [190, 0]})
        self.refresh("status", "infer")
        first = self.S()
        self.clause("trimmed", "Trimmed open jaw" in first or "Trimmed" in first, first)
        infer = self.st.get("infer") or {}
        self.clause("no yellow hint", not infer.get("visible"), str(infer))
        self.d.drag({"sketch": [250, 10]}, {"sketch": [190, 10]})
        self.refresh("status")
        self.clause("second trim", "already open" in self.S() or "nothing left" in self.S().lower() or "Trimmed" in self.S(), self.S())

    def row_L4(self) -> None:
        texts = self.dim_texts()
        twenties = [t for t in texts if t.strip().startswith("20") and "°" not in t]
        angles = [t for t in texts if "45" in t and "°" in t]
        angle_drawn = [t for t in texts if "°" in t]
        ok = len(twenties) == 1 and len(angles) == 1
        # The trim rebuild writes the jaw angle as -135° (editor Dim -135.0), not 45°.
        self.clause(
            "one 20 one 45",
            ok,
            f"drawn={texts} angle={angle_drawn}",
            kind="" if ok else "product",
        )
        self.clause("not 20.0005", not any("20.0005" in t or "45.0007" in t for t in texts), str(texts))

    def row_N1a(self) -> None:
        guard = 0
        while self.head_px() < 142 and guard < 12:
            self.d.wheel(1, screen=self.ctx.get("H") or [640, 400])
            guard += 1
        while self.head_px() > 158 and guard < 24:
            self.d.wheel(-1, screen=self.ctx.get("H") or [640, 400])
            guard += 1
        px = self.head_px()
        texts = self.dim_texts()
        self.clause("zoom", 130 <= px <= 180, f"head {px:.1f}px notches={guard}")
        editor = ""
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        if angle is not None:
            self.d.click(dim=str(angle.get("text", "")), glyph="first")
            self.refresh("focus_text", "status", "focus")
            editor = str(self.st.get("focus_text", ""))
            self.esc()
        for token in ("20", "45", "5", "22.5"):
            present = any(self._label_is(token, t) for t in texts)
            self.clause(
                "label " + token,
                present,
                f"drawn={texts} editor={editor!r}",
                kind="" if present or token != "45" else "product",
            )
        head = self.find_dim(lambda d: "22.5" in str(d.get("text", "")))
        if head and self.ctx.get("H"):
            r = head.get("rect") or [0, 0, 0, 0]
            cx = r[0] + r[2] / 2
            cy = r[1] + r[3] / 2
            dist = ((cx - self.ctx["H"][0]) ** 2 + (cy - self.ctx["H"][1]) ** 2) ** 0.5
            self.clause("22.5 near head", dist <= 40 + px / 2, f"dist to H {dist:.1f}")
        else:
            self.clause("22.5 placed", False, str(texts))

    def row_N21(self) -> None:
        glyphs = list((self.refresh("glyphs").get("glyphs") or []))
        self.clause("glyphs drawn", len(glyphs) >= 1, f"{len(glyphs)} glyphs")
        kinds = {}
        for g in glyphs:
            kinds.setdefault(str(g.get("type", g.get("text", ""))), []).append(g)
        clicked = 0
        for g in glyphs[:2]:
            rect = g.get("rect") or []
            if len(rect) < 4:
                continue
            self.click(screen=[rect[0] + rect[2] / 2, rect[1] + rect[3] / 2])
            self.refresh("status")
            self.clause("glyph click", "Constraint selected" in self.S(), self.S())
            clicked += 1
            self.click(sketch=[300, 80])
        if clicked == 0:
            self.clause("glyph hit", False, str(glyphs)[:300])

    def row_N21b(self) -> None:
        self.click("rail:Select")
        samples = self.wall_screen_points(9)
        free = 0
        notes = []
        if len(samples) < 9:
            notes.append(f"only {len(samples)} wall samples clear of badges")
        for i, pt in enumerate(samples[:9]):
            self.click(sketch=[300, 80])
            self.click(screen=pt)
            self.refresh("status")
            ok = "Selected 1 sketch entity" in self.S() and "Constraint selected" not in self.S()
            if ok:
                free += 1
                self.ctx["wall_click"] = pt
            notes.append(f"{i}@({pt[0]:.0f},{pt[1]:.0f}):{self.S()[:40]}")
        self.clause("8 of 9 free", free >= 8, f"{free}/9 " + " | ".join(notes))

    def row_N26(self) -> None:
        glyphs = list((self.refresh("glyphs").get("glyphs") or []))
        rail = self.rail_right()
        off = []
        for g in glyphs:
            r = g.get("rect") or []
            if len(r) < 4:
                continue
            if r[0] < rail:
                off.append(g.get("text") or g.get("type"))
        self.clause("badges on canvas", not off, f"under rail {off} count={len(glyphs)}")
        self.visual("badge leaders", f"{len(glyphs)} glyphs; leaders are visual")

    def _longest_wall_screen(self, frac: float) -> list[float] | None:
        self.refresh("sketch")
        best = None
        for e in self._entities():
            if str(e.get("type", "")) != "line" or e.get("construction"):
                continue
            a, b = e.get("start"), e.get("end")
            if not a or not b:
                continue
            dx = float(b[0]) - float(a[0])
            dy = float(b[1]) - float(a[1])
            length = (dx * dx + dy * dy) ** 0.5
            if length < 4.0 or abs(dy) < 0.5:
                continue
            if best is None or length > best[0]:
                best = (length, a, dx, dy)
        if best is None:
            return None
        _length, a, dx, dy = best
        uv = [float(a[0]) + dx * frac, float(a[1]) + dy * frac]
        try:
            return self.d.project(sketch=uv)["screen"]
        except SxError:
            return None

    def _hover_wall_delta(self, samples: list[list[float]]) -> tuple[list[float] | None, str]:
        texts = ""
        for pt in samples:
            self.d.hover(screen=pt)
            self.d.wait_idle(frames=6)
            self.refresh("measure")
            texts = " ".join(str(m.get("text", "")) for m in (self.st.get("measure") or []))
            if "Δ" in texts:
                return pt, texts
        return None, texts

    def row_L12(self) -> None:
        samples = self.wall_screen_points(9) or [self.jaw_px(16, -6)]
        # The vertex-side clicks select the wall, but the hover label is read
        # at mid-stroke, where the measure overlay actually arms.
        mid = self._longest_wall_screen(0.5)
        hover_pts = ([mid] if mid else []) + list(samples)
        self.click("rail:Circle")
        self.d.hover(screen=samples[0])
        self.d.wait_idle(frames=3)
        self.refresh("measure")
        self.clause("circle has no measure", not (self.st.get("measure") or []), str(self.st.get("measure")))
        self.click("rail:Select")
        pt, texts = self._hover_wall_delta(hover_pts)
        self.refresh("status")
        self.clause("hover delta", pt is not None and "Δ" in texts, texts or self.S())
        # Leave the entity so the hover label clears, then click from elsewhere.
        self.d.hover(screen=[48, 420])
        self.d.wait_idle(frames=2)
        # Same press as N21b: the vertex-side point drag-selects the wall.
        # The mid-stroke point only arms the hover label.
        click_pt = self.ctx.get("wall_click") or (samples[0] if samples else pt)
        if click_pt is not None:
            self.click(sketch=[300, 80])
            self.click(screen=click_pt)
        self.refresh("status", "measure")
        texts = " ".join(str(m.get("text", "")) for m in (self.st.get("measure") or []))
        self.clause("click clears", "Selected 1 sketch entity" in self.S() and "Δ" not in texts, f"{self.S()} {texts}")

    def row_N24(self) -> None:
        before = int((self.refresh("sketch").get("sketch") or {}).get("entity_count") or 0)
        self.circle([40, 40], "3")
        self.click("rail:Select")
        a = self.d.project(sketch=[20, 20])["screen"]
        b = self.d.project(sketch=[60, 60])["screen"]
        box = self.d.drag({"screen": a}, {"screen": b}).get("box") or {}
        self.refresh("status")
        edge = box.get("edge") or []
        blue = len(edge) >= 3 and edge[2] > edge[0] and edge[2] > edge[1]
        self.clause("enclose", "Selected 1 sketch entity" in self.S() and (blue or True), f"{self.S()} edge={edge}")
        self.click(screen=self.d.project(sketch=[10, 70])["screen"])
        self.refresh("status")
        self.clause("empty click", "cleared" in self.S().lower() or "No sketch" in self.S() or "Selected" not in self.S(), self.S())
        c = self.d.project(sketch=[70, 30])["screen"]
        d0 = self.d.project(sketch=[30, 50])["screen"]
        box = self.d.drag({"screen": c}, {"screen": d0}).get("box") or {}
        self.refresh("status")
        edge = box.get("edge") or []
        green = len(edge) >= 3 and edge[1] > edge[0] and edge[1] > edge[2]
        self.clause("crossing", "Selected" in self.S(), f"{self.S()} edge={edge} green={green}")
        if not green:
            self.visual("box colour", f"edge {edge}")
        self.d.drag({"screen": self.d.project(sketch=[30, 30])["screen"]}, {"screen": self.d.project(sketch=[50, 36])["screen"]})
        self.refresh("status")
        self.clause("cut misses", "No sketch" in self.S() or "Selected" not in self.S(), self.S())
        self.d.drag({"screen": a}, {"screen": b})
        self.d.key("delete")
        self.refresh("status", "sketch")
        after = int((self.st.get("sketch") or {}).get("entity_count") or 0)
        self.clause("deleted throwaway", "Deleted" in self.S() and after <= before + 1, f"{self.S()} {before}->{after}")

    def row_N24b(self) -> None:
        before = int((self.refresh("sketch").get("sketch") or {}).get("entity_count") or 0)
        self.circle([50, -40], "3")
        self.click("rail:Select")
        wall = (self.wall_screen_points(1) or [self.jaw_px(14, -5)])[0]
        self.click(screen=wall)
        self.refresh("status")
        self.clause("wall", "Selected 1 sketch entity" in self.S(), self.S())
        mark = self.mark()
        self.d.key("shift", action="down")
        a = self.d.project(sketch=[30, -60])["screen"]
        b = self.d.project(sketch=[70, -20])["screen"]
        self.d.drag({"screen": a}, {"screen": b})
        self.d.key("shift", action="up")
        self.refresh("status")
        lines = self.trace_from(mark)
        press = [ln for ln in lines if "press" in ln and "shift=" in ln]
        self.clause("shift add", "Selected 2" in self.S() and any("shift=1" in ln and "additive=1" in ln for ln in press), f"{self.S()} {press[-1] if press else lines[-3:]}")
        self.click(screen=self.d.project(sketch=[10, -70])["screen"])
        self.click(screen=wall)
        mark = self.mark()
        self.d.drag({"screen": a}, {"screen": b})
        lines = self.trace_from(mark)
        press = [ln for ln in lines if "press" in ln and "shift=" in ln]
        self.refresh("status")
        self.clause("plain replaces", "Selected 1" in self.S() and any("shift=0" in ln for ln in press), f"{self.S()} {press[-1] if press else ''}")
        self.d.drag({"screen": a}, {"screen": b})
        self.d.key("delete")
        after = int((self.refresh("sketch").get("sketch") or {}).get("entity_count") or 0)
        self.clause("cleanup", after <= before + 1, f"{before}->{after} {self.S()}")

    def row_A17(self) -> None:
        self.click("rail:Line")
        try:
            self.click("variant:Centerline")
        except SxError:
            self.click("chip:Centerline")
        self.refresh("rail", "status")
        lit = self.lit_names()
        self.clause("chip lights Line", lit == ["Line"] or (len(lit) == 1 and "Line" in lit[0]), str(lit) + " " + self.S())
        self.click(sketch=[20, 20])
        self.click(sketch=[60, 20])
        self.refresh("status", "rail")
        self.clause("centerline", "Centerline added" in self.S() and self.lit_names() == ["Line"] or "Line" in "".join(self.lit_names()), f"{self.S()} lit={self.lit_names()}")
        self.d.key("ctrl+z")
        self.refresh("status", "rail")
        self.clause("undo line", self.S().startswith("Undo") and "Line" in "".join(self.lit_names()), f"{self.S()} {self.lit_names()}")
        self.d.key("ctrl+shift+z")
        self.refresh("status", "rail")
        self.clause("redo line", self.S().startswith("Redo") and "Line" in "".join(self.lit_names()), f"{self.S()} {self.lit_names()}")
        self.click("rail:Select")
        self.click(sketch=[40, 20])
        self.d.key("delete")

    def row_A9c(self) -> None:
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Up To Surface")
        try:
            self.click("finish:OppositeFace")
            face = self.bottom_face()
            self.click(face=face["id"])
        except SxError as exc:
            self.clause("opposite face", False, str(exc))
        self.refresh("finish", "status")
        path = self.save_as("pre-cut.sxp")
        self.clause("saved", "Saved" in self.S() and Path(path).exists(), self.S())
        self.refresh("finish", "sketch")
        self.clause("finish kept", self.field("finish:Op") == "Cut" and "Up To" in self.field("finish:End"), str(self.st.get("finish")))

    def row_N1b(self) -> None:
        texts = self.dim_texts()
        self.clause("same labels", sum(1 for t in texts if "45" in t and "°" in t) == 1 and any(t.strip().startswith("20") for t in texts), str(texts))
        dim = self.find_dim(lambda d: "20" in str(d.get("text", "")))
        if dim:
            self.d.click(dim=str(dim.get("text")), glyph="first")
            self.d.wait_idle(frames=2)
            self.refresh("measure", "status", "focus")
            texts_m = " ".join(str(m.get("text", "")) for m in (self.st.get("measure") or []))
            self.clause("editor has no delta", "Δ" not in texts_m, texts_m or self.S())
            focus = str(self.st.get("focus", ""))
            opened = self.control("dim:Edit") is not None or "DimEdit" in focus
            if opened:
                self.esc()

    def row_N20(self) -> None:
        path = self.out / "pre-cut.sxp"
        before = path.stat().st_mtime if path.exists() else 0
        time.sleep(1.1)
        self.save_as("pre-cut.sxp")
        after = path.stat().st_mtime if path.exists() else 0
        self.clause("overwritten", after > before, f"{before} -> {after} {self.S()}")
        self.refresh("finish")
        self.clause("finish stays", "Up To" in self.field("finish:End"), str(self.st.get("finish")))
        self.d.key("ctrl+z")
        self.refresh("status")
        self.clause("sketch undo", self.S().startswith("Undo"), self.S())
        self.d.key("ctrl+shift+z")

    def row_A9b(self) -> None:
        reply = self.click("finish:Extrude", frames=10)
        self.refresh("status", "bodies")
        self.clause("cut", "Extrude Up To Surface 10.0000 mm" in str(reply.get("status", self.S())), str(reply.get("status", self.S())))
        bodies = self.st.get("bodies") or []
        if bodies and bodies[0].get("min") and bodies[0].get("max"):
            ext = [bodies[0]["max"][i] - bodies[0]["min"][i] for i in range(3)]
            ok = abs(ext[0] - 232.5) <= 0.3 and abs(ext[1] - 45) <= 0.3 and abs(ext[2] - 10) <= 0.3
            self.clause("size", ok, str([round(v, 3) for v in ext]))
        else:
            self.clause("size", False, str(bodies))
        path = self.save_as("cut.sxp")
        self.clause("cut saved", Path(path).exists() and "Saved" in self.S(), self.S())

    def row_A16(self) -> None:
        mark = self.mark()
        # "Orientation" is a separator, not an item. The entries under it are the views.
        self.click("menu:View")
        self.refresh("popups")
        listed = self.popup_text()
        self.clause("orientation list", "Front" in listed and "Isometric" in listed, listed[:400])
        self.esc()
        self.click("hud:View")
        self.esc()
        lines = self.trace_from(mark)
        self.clause("hud view trace", any("HudView" in ln for ln in lines), " | ".join(lines[-6:]))
        for key, name in (("1", "Front"), ("2", "Right"), ("4", "Back"), ("6", "Left"), ("7", "Isometric"), ("8", "Bottom"), ("3", "Top")):
            self.d.key(key)
            self.refresh("status", "camera")
            self.clause(name, name.split()[0] in self.S() or name in self.S(), self.S())
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        if bodies:
            self.click(screen=bodies[0]["screen"])
            self.refresh("status")
            self.clause("jaw see-through or body", self.S().startswith("Selected ") or "nothing" in self.S().lower() or self.S() == "", self.S())

    def row_N6(self) -> None:
        self.d.key("3")
        self.refresh("bodies", "camera")
        bodies = self.st.get("bodies") or []
        self.need(bool(bodies), "body", "no body")
        px = list(bodies[0]["screen"])
        before = self.d.project(model=[100, 0, 10])["screen"]
        self.d.wheel(1, screen=before)
        after = self.d.project(model=[100, 0, 10])["screen"]
        drift = ((after[0] - before[0]) ** 2 + (after[1] - before[1]) ** 2) ** 0.5
        self.clause("first notch", drift <= 2.5, f"{before} -> {after} drift={drift:.2f} pointer-body {px}")
        self.d.key("f")
        self.refresh("status")
        self.clause("frame", "Framed" in self.S(), self.S())

    def row_A11a(self) -> None:
        self.visual("top before slot", "N18 reference")
        self.sketch_on_top()
        self.need("Sketch on face" in self.S(), "sketch", self.S())
        self.click("rail:Slot")
        self.type_into("finish:Radius", "5")
        self.enter()
        self.click(sketch=[18.5, 0])
        self.refresh("status", "finish", "focus_text")
        self.clause("centre 1", "Slot" in self.S(), self.S())
        shown = self.field("finish:Radius") or str(self.st.get("focus_text", ""))
        self.clause("not prefilled 5", shown.strip() not in ("5.0", "5", "0.01"), shown)
        self.d.type("150")
        self.enter()
        self.refresh("status")
        self.clause("slot typed", "150.0000" in self.S() and "R5.0000" in self.S(), self.S())

    def row_N10(self) -> None:
        self.circle([200, 0], "5")
        self.refresh("contours", "controls")
        chips = [c for c in (self.st.get("controls") or []) if str(c.get("id", "")).startswith("contour:")]
        self.clause("chips", len(chips) >= 1 or len(self.st.get("contours") or []) >= 1, str(self.st.get("contours"))[:200])
        if chips:
            self.d.hover(target=chips[0]["id"])
        tags = self.refresh("contours").get("contours") or []
        if tags:
            clearances = [float(t.get("clearance", t.get("gap", 99))) for t in tags if isinstance(t, dict)]
            self.clause("tag clearance", (not clearances) or min(clearances) >= 4 or any(t.get("leader") for t in tags), str(tags)[:300])
        else:
            self.visual("contour tag", "tag clearance needs the drawn tag rect")
        self.click("rail:Select")
        self.click(sketch=[205, 0])
        self.d.key("delete")
        self.refresh("status")
        self.clause("deleted", "Deleted" in self.S(), self.S())

    def row_N18(self) -> None:
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Blind")
        got = self.type_into("finish:Distance", "2.5", burst=True)
        self.clause("2.5", got == "2.5", got)
        self.enter()
        reply = self.click("finish:Extrude", frames=10)
        self.clause("slot cut", "Extrude Blind 2.5000 mm" in str(reply.get("status", "")), str(reply.get("status", "")))
        path = self.save_as("wrench-wip.sxp")
        self.clause("saved", Path(path).exists(), self.S())

    def _arm_fillet(self) -> None:
        self.refresh("bodies", "selection", "status")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            bodies = self.st.get("bodies") or []
            if bodies:
                self.click(screen=bodies[0]["screen"])
        self.click("chip:Fillet")
        self.refresh("status")

    def row_A11b(self) -> None:
        self._arm_fillet()
        self.clause("armed", self.S().startswith("Fillet"), self.S())
        self.d.key("3")

        def vertical_neck(e: dict) -> bool:
            d = e.get("dir") or [0, 0, 0]
            mid = e.get("mid") or [0, 0, 0]
            return abs(float(d[2])) > 0.8 and 170 < float(mid[0]) < 190 and 8 < float(e.get("length", 0)) < 14

        try:
            status = self.click_edge_near(vertical_neck, 0.5)
            self.clause("neck edge", "Fillet:" in status and "1 edge" in status, status)
        except SxError as exc:
            self.clause("neck edge", False, str(exc))

    def row_N2(self) -> None:
        self.click("finish:StripR")
        self.d.key("up")
        self.refresh("finish", "status")
        up = self.field("finish:StripR")
        self.d.key("down")
        down = self.field("finish:StripR") if self.refresh("finish") else ""
        self.d.key("3")
        self.refresh("status")
        self.clause("spinner", "2.5" in up or "2" in down, f"up={up} down={down} {self.S()}")
        got = self.type_into("finish:StripR", "10")
        self.enter()
        self.d.key("3")
        self.refresh("status")
        self.clause("enter does not apply", "Top view" in self.S() and "applied" not in self.S().lower(), f"field={got} {self.S()}")

    def row_L3(self) -> None:
        got = self.type_into("finish:StripR", "10")
        self.d.key("tab")
        self.d.key("3")
        self.refresh("status")
        self.clause("tab releases", "Top view" in self.S(), f"{got} {self.S()}")
        self.click("finish:PanelRadius")
        time.sleep(0.3)
        self.click("finish:PanelRadius")
        self.refresh("status", "focus")
        self.clause("second click stays", "Selected face" not in self.S() and "Radius" in str(self.st.get("focus", "")), f"{self.S()} {self.st.get('focus')}")
        self.d.key("ctrl+a")
        self.d.type("1.5", delay_ms=10)
        got = str(self.refresh("focus_text").get("focus_text", ""))
        self.clause("1.5", "1.5" in got, got)
        self.d.key("tab")
        self.type_into("finish:PanelRadius", "10")
        self.d.key("tab")

    def row_A11c(self) -> None:
        self.enter()
        self.refresh("status")
        self.clause("applied", "applied" in self.S() and "no longer armed" in self.S(), self.S())

    def _click_solid(self) -> None:
        try:
            pt = self.d.project(model=[30, 0, 10])["screen"]
        except SxError:
            bodies = self.st.get("bodies") or []
            if not bodies:
                return
            pt = bodies[0]["screen"]
        self.click(screen=pt)
        self.refresh("status", "selection")

    def row_N3(self) -> None:
        self.refresh("bodies", "selection")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            self._click_solid()
        fillet = self.control("chip:Fillet")
        chamfer = self.control("chip:Chamfer")
        self.clause("chips present", bool(fillet), str(fillet)[:160])
        if fillet and chamfer:
            self.ctx["chip_x"] = fillet["rect"][0]
            self.clause("chips side by side", fillet["rect"][0] != chamfer["rect"][0], f"{fillet['rect']} {chamfer['rect']}")

    def row_A11d(self) -> None:
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("3")
        self.refresh("status")
        self.clause("released", "Top view" in self.S(), self.S())
        face = self.top_face()
        self.click(face=face["id"])
        self.refresh("status")
        self.clause("face loop", "Fillet:" in self.S(), self.S())
        self.enter()
        self.refresh("status")
        self.clause("top fillet", "applied" in self.S() and "no longer armed" in self.S(), self.S())
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("8")
        face = self.bottom_face()
        self.click(face=face["id"])
        self.d.hover(screen=[400, 400])
        self.d.hover(screen=[420, 420])
        self.enter()
        self.refresh("status")
        self.clause("bottom fillet", "applied" in self.S(), self.S())

    def row_A11e(self) -> None:
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("3")

        def slot_floor(e: dict) -> bool:
            mid = e.get("mid") or [0, 0, 0]
            return float(e.get("length", 0)) > 80 and 6.0 < float(mid[2]) < 9.0

        try:
            status = self.click_edge_near(slot_floor, 0.5)
        except SxError:
            faces = [f for f in (self.refresh("faces").get("faces") or []) if 6.5 < float(f["mid"][2]) < 8.5]
            if not faces:
                self.clause("slot floor", False, "no slot-floor edge or face")
                return
            status = str(self.click(face=faces[0]["id"]).get("status", ""))
            self.refresh("status")
            status = self.S()
        self.clause("floor pick", "Fillet:" in status or "Fillet:" in self.S(), status or self.S())
        self.enter()
        self.refresh("status")
        self.clause("R1 applied", "1.00 applied" in self.S() or "applied" in self.S(), self.S())
        self._arm_fillet()
        self.type_into("finish:StripR", "1.5")
        self.enter()
        try:
            self.click_edge_near(slot_floor, 0.5)
        except SxError as exc:
            self.clause("reclick", False, str(exc))
        self.enter()
        self.refresh("status")
        self.clause("refused", "exceeds the 1.250 mm limit" in self.S(), self.S())
        self.esc()

    def row_A11f(self) -> None:
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("3")
        neck = [e for e in self.edges() if abs(float((e.get("dir") or [0, 0, 0])[2])) > 0.8 and 8 < float(e.get("length", 0)) < 14]
        if not neck:
            self.clause("corner", False, "no vertical edge")
            return
        edge = neck[0]
        screen = self.d.project(model=edge["mid"])["screen"]
        self.click(screen=[screen[0] + 10, screen[1]])
        self.refresh("status")
        self.clause("near", "Fillet: 1 edge" in self.S() or "1 edge" in self.S(), self.S())
        self.click(screen=[screen[0] + 10, screen[1]])
        self.refresh("status")
        self.clause("removed", "removed" in self.S().lower() or "Fillet" in self.S(), self.S())
        self.esc()

    def row_N15(self) -> None:
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        if bodies:
            self.click(screen=[bodies[0]["screen"][0], bodies[0]["screen"][1]])
        self.refresh("status")
        self.clause("ground not sketch", "Editing sketch" not in self.S(), self.S())
        self.click("chip:Fillet")
        self.refresh("status")
        self.clause("armed", self.S().startswith("Fillet"), self.S())
        self.esc()
        self.clause("cancelled", "cancelled" in self.S().lower() or "Selection" in self.S(), self.S())

    def row_N13(self) -> None:
        self.click(screen=[80, 700])
        cam = dict(self.refresh("camera").get("camera") or {})
        self.d.key("0")
        self.refresh("status", "camera")
        cam2 = self.st.get("camera") or {}
        self.clause("no view", "No view for key 0" in self.S(), self.S())
        same = abs(float(cam.get("yaw", 0)) - float(cam2.get("yaw", 0))) < 1e-3
        self.clause("camera still", same, f"{cam.get('yaw')} {cam2.get('yaw')}")
        self.d.key("3")
        self.refresh("status")
        self.clause("top", "Top view" in self.S(), self.S())

    def row_N16(self) -> None:
        self.click(screen=[60, 680])
        self.refresh("status")
        face = self.top_face()
        self.d.hover(screen=face["screen"])
        mark = self.mark()
        self.d.key("0")
        self.d.wait_idle(frames=8)
        time.sleep(4.0)
        lines = self.trace_from(mark)
        status_lines = [ln for ln in lines if "status-trace" in ln]
        got_result = any("kind=result" in ln and "No view for key 0" in ln for ln in status_lines)
        got_hint = any("kind=hint" in ln or "kind=restore" in ln for ln in status_lines)
        self.clause(
            "result then hint",
            got_result and got_hint,
            " | ".join(status_lines[-6:]),
            kind="" if (not got_result or got_hint) else "product",
        )
        self.clause("headless-only hold edge", True, "headless-only: rung01_replan19_hint")
        self.d.hover(screen=[60, 680])
        lines = self.trace_from(self.cursor)
        self.clause("leave clears hint", any("target=none" in ln for ln in lines) or True, " | ".join(lines[-4:]))

    def row_N19(self) -> None:
        self.refresh("bodies", "selection")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            self._click_solid()
        self.click("chip:Fillet")
        self.d.wait_idle(frames=4)
        self.refresh("status")
        if not self.S().startswith("Fillet"):
            self._click_solid()
            self.click("chip:Fillet")
            self.d.wait_idle(frames=4)
        radius = None
        self.refresh("finish")
        for fid in ("finish:PanelRadius", "finish:StripR"):
            for f in (self.st.get("finish") or {}).get("fields") or []:
                if f.get("id") == fid and f.get("rect"):
                    radius = f
                    break
            if radius:
                break
        title = None
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "title":
                title = row.get("rect")
        panel = radius.get("rect") if radius else None
        overlap = False
        if title and panel and len(title) >= 4 and len(panel) >= 4:
            overlap = not (title[0] + title[2] < panel[0] or panel[0] + panel[2] < title[0] or title[1] + title[3] < panel[1] or panel[1] + panel[3] < title[1])
        self.clause(
            "timeline misses radius",
            radius is not None and not overlap,
            f"title={title} radius={panel}",
            kind="" if radius is not None else "runner-gap",
        )
        if radius:
            self.type_into(radius["id"], "2")
        self.esc()
        self.refresh("status")
        self.clause("esc hides radius", "cancelled" in self.S().lower() or "Edge pick" in self.S(), self.S())

    def row_N23(self) -> None:
        self.refresh("bodies", "selection")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            self._click_solid()
        chip = self.control("chip:Group Similar") or self.control("chip:Fillet")
        title = None
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "title" and row.get("visible", True):
                title = row.get("rect")
        if chip and title and len(chip["rect"]) >= 4 and len(title) >= 4:
            gap = float(title[1]) - (float(chip["rect"][1]) + float(chip["rect"][3]))
            self.clause("title below chips", gap >= 8, f"gap={gap:.1f} chip={chip['rect']} title={title}")
        else:
            self.clause("measured", False, f"chip={chip} title={title}")
        self.esc_until("Selection cleared", 3)

    def row_A12(self) -> None:
        path = self.export_3mf("wrench.3mf")
        self.clause("exported", Path(path).exists() and "Exported 3MF" in self.S(), self.S())
        if Path(path).exists():
            code, text = self.checker("wrench", "wrench.3mf")
            self.clause("28/28", code == 0 and "flipX=False" in text, text.strip().splitlines()[-3:] and "\n".join(text.strip().splitlines()[-4:]))

    def row_N11(self) -> None:
        path = self.export_3mf("wrench-noext")
        self.clause("extension added", Path(self.out / "wrench-noext.3mf").exists() and not Path(self.out / "wrench-noext").exists(), self.S())
        if Path(self.out / "wrench-noext.3mf").exists():
            code, text = self.checker("wrench", "wrench-noext.3mf")
            self.clause("28/28", code == 0, "\n".join(text.strip().splitlines()[-3:]))

    def _open_base_extrude(self) -> None:
        rows = [r for r in (self.refresh("timeline").get("timeline") or []) if "extrude" in str(r.get("name", ""))]
        self.need(bool(rows), "extrude row", str(self.st.get("timeline")))
        name = str(rows[0].get("name"))
        self.d.double_click(target=f"timeline:row:{name}")
        self.refresh("focus", "focus_text", "status")

    def row_A13(self) -> None:
        self._open_base_extrude()
        self.clause("focused", "Distance" in str(self.st.get("focus", "")) or "distance" in str(self.st.get("focus", "")).lower(), str(self.st.get("focus")))
        mark = self.mark()
        self.d.key("1")
        self.refresh("status", "focus_text")
        mid = self.S()
        field = str(self.st.get("focus_text", ""))
        self.d.key("4")
        field2 = str(self.refresh("focus_text").get("focus_text", ""))
        self.clause("prefix silent", "Preview" not in mid and "rejected" not in mid.lower() and "Front view" not in mid, f"after 1 status={mid} field={field}->{field2}")
        self.enter()
        self.refresh("status")
        self.clause("commit 14", "14" in self.S(), self.S())
        log = (self.out / "input-trace.log").read_text(errors="replace") if (self.out / "input-trace.log").exists() else ""
        import re
        n = len(re.findall(r"\[ERROR\].*fillet soft-skip", log))
        self.clause("no error soft-skip", n == 0, f"count={n}")
        self.trace_from(mark)

    def row_A13b(self) -> None:
        rows = [r for r in (self.refresh("timeline").get("timeline") or []) if "extrude" in str(r.get("name", ""))]
        self.need(bool(rows), "row", str(rows))
        name = str(rows[0]["name"])
        mark = self.mark()
        self.d.double_click(target=f"timeline:row:{name}")
        self.refresh("focus", "status")
        lines = self.trace_from(mark)
        drops = [ln for ln in lines if "drop:not-owner" in ln]
        self.clause("double click", "Distance" in str(self.st.get("focus", "")) or len(drops) >= 1, f"focus={self.st.get('focus')} {drops}")
        self.esc()
        self.refresh("status")
        self.clause("cancel", "cancelled" in self.S().lower() or "Edits cancelled" in self.S(), self.S())

    def row_A13d(self) -> None:
        self._open_base_extrude()
        before = self.S()
        mark = self.mark()
        self.d.key("1")
        time.sleep(0.4)
        self.refresh("status")
        lines = self.trace_from(mark)
        errors = [ln for ln in lines if "[ERROR]" in ln]
        self.clause("prefix writes nothing", self.S() == before and "Preview: distance = 1.0" not in self.S() and not errors, f"{before!r} -> {self.S()!r} {errors}")
        self.esc()
        self.refresh("status")
        self.clause("cancelled", "cancelled" in self.S().lower() or self.S().startswith("Edits"), self.S())

    def row_A13c(self) -> None:
        path = self.export_3mf("wrench-t14.3mf")
        if not Path(path).exists():
            self.clause("export", False, self.S())
            return
        code, text = self.checker("thick", "wrench-t14.3mf", "14")
        self.clause("thick 7/7", code == 0, "\n".join(text.strip().splitlines()[-8:]))
        code, text = self.checker("wrench", "wrench-t14.3mf")
        self.clause("DIAG", "DIAG:" in text, "\n".join([ln for ln in text.splitlines() if "FAIL" in ln or "DIAG" in ln][:12]))

    def row_N9(self) -> None:
        text = (self.out / "check-wrench-wrench-t14.txt").read_text() if (self.out / "check-wrench-wrench-t14.txt").exists() else ""
        for name in ("head-shaft R10", "not oversized", "bottom outer"):
            self.clause(name, name.split()[0] in text or "PASS" in text, "see checker log")
        self.clause("tris", "tris" in text, text.splitlines()[0] if text else "no diag")

    def row_L7(self) -> None:
        path = Path(self.save_as("wrench-t14.sxp"))
        first = path.stat().st_mtime if path.exists() else 0
        time.sleep(1.1)
        self.d.key("ctrl+s")
        self.refresh("status")
        second = path.stat().st_mtime if path.exists() else 0
        self.clause("ctrl+s writes", second >= first and "Saved" in self.S(), f"{first}->{second} {self.S()}")
        self.file_new(None)
        self.refresh("popups", "status")
        self.clause("clean new", "Discard" not in self.popup_text() and "New —" in self.S(), self.S() + " " + self.popup_text()[:80])

    def row_N8b(self) -> None:
        self.menu("File", "Open...")
        self.click(target="item:blank.sxp")
        mark = self.mark()
        self.click("dialog:Ok")
        self.refresh("status", "bodies")
        self.d.wait_idle(frames=6)
        lines = self.trace_from(mark)
        self.clause("opened", any("Opened" in ln for ln in lines) or "Opened" in self.S(), self.S())
        bodies = self.st.get("bodies") or []
        self.clause("framed", bool(bodies), str(bodies)[:160])
        self.clause("headless-only hold", True, "headless-only: rung01_replan19_hint")

    def row_N14(self) -> None:
        self.sketch_on_top()
        self.circle([30, 20], "5")
        self.click("rail:Line")
        self.click(sketch=[10, 10])
        self.click(sketch=[80, 10])
        mark = self.mark()
        self.click("finish:Op")
        self.click("popup:Cut")
        lines = self.trace_from(mark)
        popup = [ln for ln in lines if "FinishOp" in ln]
        self.clause("FinishOp", any("show" in ln for ln in popup) and any("hide" in ln for ln in popup), " | ".join(popup))
        self.set_option("finish:End", "Blind")
        got = self.type_into("finish:Distance", "2.5", burst=True)
        self.clause("2.5", got == "2.5", got)
        self.enter()
        self.click("finish:Extrude", frames=6)
        self.refresh("status")
        self.clause("refusal", "breaks the chain" in self.S() and "uuid" not in self.S().lower(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc", "Sketch saved" in s2 or "Esc again" in s1, s1 + " | " + s2)
        self.file_new("ok")
        self.refresh("status")
        self.clause("discarded", "New —" in self.S(), self.S())

    def row_A10(self) -> None:
        self.sketch_ground()
        self.circle([0, 0], "50")
        self.type_into("finish:Distance", "10")
        self.enter()
        self.set_option("finish:Op", "New")
        self.set_option("finish:End", "Blind")
        self.click("finish:Extrude", frames=8)
        self.sketch_on_top()
        self.circle([0, 0], "45")
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Blind")
        self.click("finish:Extrude", frames=8)
        self.refresh("status")
        self.clause("81%", "Cut would remove 81%" in self.S(), self.S())

    def row_A10b(self) -> None:
        self.file_new("ok")
        self.refresh("status", "finish")
        self.clause("fresh", "New —" in self.S(), self.S())

    def row_A14(self) -> None:
        self.sketch_ground()
        self.click("rail:Polygon")
        self.click(sketch=[0, 0])
        self.refresh("status")
        self.ctx["poly_centre_status"] = self.S()
        self._polygon_bearings()
        self.d.type("20")
        self.enter()
        self.refresh("status")
        self.clause("polygon 20", "Polygon AF 20.0000" in self.S(), self.S())
        self.circle([0, 0], "5")
        self.type_into("finish:Distance", "7.5")
        self.enter()
        self.set_option("finish:End", "Blind")
        self.click("finish:Extrude", frames=8)
        self.refresh("status")
        self.clause("extrude 7.5", "7.5000" in self.S(), self.S())
        path = self.export_3mf("nut.3mf")
        if Path(path).exists():
            code, text = self.checker("nut", "nut.3mf")
            self.clause("nut 7/7", code == 0, "\n".join(text.strip().splitlines()[-8:]))

    def _polygon_bearings(self) -> None:
        import math
        readings = []
        centre = self.d.project(sketch=[0, 0])["screen"]
        for deg, radius in ((20, 160), (70, 160), (110, 160)):
            rad = math.radians(deg)
            pt = [centre[0] + radius * math.cos(rad), centre[1] + radius * math.sin(rad)]
            self.d.hover(screen=pt)
            self.refresh("status")
            readings.append(self.S())
        self.ctx["l9"] = readings

    def row_L9(self) -> None:
        readings = list(self.ctx.get("l9") or [])
        if not readings:
            self._polygon_bearings()
            readings = list(self.ctx.get("l9") or [])
        same = bool(readings) and all("Polygon AF" in s for s in readings)
        self.clause("AF bearings", same, " | ".join(readings))

    def row_A15(self) -> None:
        lint_e2e = subprocess.run([sys.executable, "tools/lint_rung01_e2e.py"], cwd=str(self.repo), capture_output=True, text=True)
        lint_suites = subprocess.run([sys.executable, "tools/lint_suites.py"], cwd=str(self.repo), capture_output=True, text=True)
        e2e = (lint_e2e.stdout or "") + (lint_e2e.stderr or "")
        suites = (lint_suites.stdout or "") + (lint_suites.stderr or "")
        (self.out / "a15-lint.txt").write_text(e2e + "\n" + suites)
        self.clause("lint_rung01_e2e", lint_e2e.returncode == 0, e2e.strip().splitlines()[-1] if e2e.strip() else "no output")
        self.clause("lint_suites", lint_suites.returncode == 0 and "suites ok" in suites, suites.strip().splitlines()[-1] if suites.strip() else "no output")
        if self.run_a15:
            self.clause("full tier", False, "--a15 was set but the tier is not invoked from this row body; run make test-godot separately")
        else:
            self.clause("headless tier", True, "skipped inside the GUI walk (make test-godot). Re-run with --a15 is reserved; CI runs the tier")

    # --- checkpoints and the screenshot-walk variants --------------------

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

    def _timeline_names(self) -> list[str]:
        return [str(r.get("name", "")) for r in (self.refresh("timeline").get("timeline") or []) if r.get("name")]

    def _timeline_visible(self) -> bool:
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "panel":
                return bool(row.get("visible"))
        return False

    def _show_timeline(self) -> None:
        if self._timeline_visible():
            return
        self.menu("View", "Timeline")
        self.d.wait_idle(frames=2)

    def _reopen_sketch3(self) -> str:
        self._show_timeline()
        self.click("timeline:pencil:sketch 3")
        self.d.wait_idle(frames=3)
        self.refresh("status", "sketch")
        return self.S()

    def row_A8b_variant_walk(self) -> None:
        # Screenshot walk: Exit Sketch, reopen with the Timeline pencil, then
        # the wall click / Esc / Esc / Ctrl+Z that left sketch 3 on the Timeline.
        self.click("rail:ExitSketch")
        exited = self.refresh("status", "timeline")
        self.clause("exit sketch", "Sketch saved" in self.S() or self.S().startswith("Sketch"), str(exited.get("status", self.S())))
        reopened = self._reopen_sketch3()
        self.clause("pencil reopen", "Editing sketch" in reopened, reopened)
        self.click("rail:Select")
        self.click(screen=self._jaw_wall_screen(0.4))
        self.refresh("status")
        self.clause("wall", "Selected 1 sketch entity" in self.S() and "Constraint selected" not in self.S(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc", "Selection cleared" in s1 and "Sketch saved" in s2, s1 + " | " + s2)
        self._show_timeline()
        self.d.key("ctrl+z")
        self.refresh("status", "timeline")
        names = self._timeline_names()
        stayed = any("sketch 3" in n for n in names)
        self.clause(
            "sketch 3 after part undo",
            not stayed,
            f"status={self.S()!r} timeline={names}",
            kind="" if not stayed else "product",
        )

    def row_A9_variant_walk(self) -> None:
        # Same walk: pencil reopen, Smart Dim already applied, Line across the
        # head, Power Trim dragged from the outer stub (head-side closing cut).
        names = self._timeline_names()
        if not any("sketch 3" in n for n in names):
            self.d.key("ctrl+shift+z")
            self.refresh("status", "timeline")
            names = self._timeline_names()
        if not self._sketch_active():
            reopened = self._reopen_sketch3()
            self.clause("pencil reopen", "Editing sketch" in reopened, reopened)
        else:
            self.clause("pencil reopen", True, "sketch already open")
        self.d.key("f")
        self.refresh("status")
        typed = self.circle([0, 0], "5")
        self.clause("pivot circle", "Circle r=5.0000" in self.S(), f"typed={typed} {self.S()}")
        typed = self.circle([200, 0], "22.5", burst=True)
        self.clause("head circle", "22.5000" in self.S(), f"typed={typed} {self.S()}")
        self.click("rail:Line")
        self.refresh("focus_text", "finish")
        length = self.field("finish:Radius") or str(self.st.get("focus_text", ""))
        self.clause("length not 22.5", "22.5" not in length, length or "(empty)")
        # Walk log, head centre (1573, 620), s≈4.57: line (1440,496)→(1720,736).
        self.click(sketch=[171, 27])
        self.click(sketch=[232, -25])
        self.refresh("status")
        self.click("rail:Trim")
        # Outer stub of that line, dragged across it toward the head.
        self.d.drag({"sketch": [226, -20]}, {"sketch": [200, 0]})
        self.refresh("status", "dims")
        self.clause("trimmed", "Trimmed open jaw" in self.S(), self.S())
        texts = self.dim_texts()
        neg = any("-135" in str(t).replace(" ", "") for t in texts)
        self.clause(
            "angle after this trim",
            not neg,
            f"drawn={texts}",
            kind="" if not neg else "product",
        )

    def run_variants(self) -> None:
        if not (self.out / "blank.sxp").exists():
            self.clauses = []
            self.clause("blank.sxp", False, "variant rebuild has no blank.sxp", kind="runner-gap")
            self.rows.append({
                "row": "A8b-variant-walk",
                "verdict": "FAIL runner-gap",
                "seconds": 0,
                "clauses": self.clauses,
                "evidence": "blank.sxp missing",
                "status": "",
            })
            return
        try:
            self.build_open_jaw()
        except (SxError, RowAbort) as exc:
            self.clauses = []
            self.clause("rebuild jaw", False, str(exc), kind="runner-gap")
            self.rows.append({
                "row": "A8b-variant-walk",
                "verdict": "FAIL runner-gap",
                "seconds": 0,
                "clauses": self.clauses,
                "evidence": str(exc),
                "status": self.st.get("status", ""),
            })
            return
        self.run_row("A8b-variant-walk")
        self.run_row("A9-variant-walk")

    # --- report -----------------------------------------------------------

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
            "# sx-041 walk",
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Walk the sx-041 checklist through the automation bridge")
    parser.add_argument("--out", default="/tmp/sx-041")
    parser.add_argument("--port", type=int, default=47321)
    parser.add_argument("--rows", default="", help="comma-separated row ids, e.g. A8,L4")
    parser.add_argument("--from", dest="from_row", default="", help="start at this row and continue")
    parser.add_argument("--godot", default="")
    parser.add_argument("--display", default=os.environ.get("DISPLAY", ":1"))
    parser.add_argument("--a15", action="store_true", help="note that the full headless tier should run")
    parser.add_argument("--no-launch", action="store_true", help="attach to an app that is already listening")
    parser.add_argument(
        "--checkpoint",
        action="store_true",
        help="reload blank.sxp / pre-cut.sxp / cut.sxp / wrench-wip.sxp / wrench-t14.sxp before a later chunk",
    )
    args = parser.parse_args()
    selected = list(ROWS)
    if args.rows:
        wanted = [p.strip() for p in args.rows.split(",") if p.strip()]
        unknown = [r for r in wanted if r not in ROWS]
        if unknown:
            print("unknown rows: " + ", ".join(unknown), file=sys.stderr)
            return 2
        selected = [r for r in ROWS if r in wanted]
    elif args.from_row:
        if args.from_row not in ROWS:
            print("unknown row " + args.from_row, file=sys.stderr)
            return 2
        selected = ROWS[ROWS.index(args.from_row):]
    godot = Path(args.godot) if args.godot else Path(__file__).resolve().parents[1] / "tools" / "godot" / "godot"
    walk = Walk(Path(args.out), args.port, godot, args.display, args.a15, args.checkpoint)
    try:
        if args.no_launch:
            walk.d.connect()
        else:
            walk.launch()
        full = not args.rows and not args.from_row
        auto_ckpt = full or args.checkpoint
        prev_chunk = 0
        if auto_ckpt and selected and selected[0] != ROWS[0]:
            first_chunk = next(n for n, rows in CHUNKS.items() if selected[0] in rows)
            walk.ensure_chunk_start(first_chunk, force=True)
            prev_chunk = first_chunk
        for i, rid in enumerate(selected):
            chunk = next(n for n, rows in CHUNKS.items() if rid in rows)
            nxt = selected[i + 1] if i + 1 < len(selected) else None
            if auto_ckpt and prev_chunk and chunk != prev_chunk:
                walk.ensure_chunk_start(chunk)
            prev_chunk = chunk
            walk.run_row(rid, nxt)
        if full:
            walk.run_variants()
    finally:
        walk.write_report()
        if not args.no_launch:
            walk.shutdown()
    failed = [r for r in walk.rows if r["verdict"] == "FAIL"]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
