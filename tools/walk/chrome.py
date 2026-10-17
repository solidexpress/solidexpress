# Shared click and read helpers for the rung walks.
# Each UI class sets `_INTENDED`; these helpers only read it.
from __future__ import annotations

import json
import re
import subprocess
import sys

from sxdrive import SxError
from walk import proc
from walk.gates import parse_tier, run_kernel, run_tier, take
from walk.gestures import label_reads

_REGEN_BAD = ("[ERROR]", "soft-skip", "regenerate stopped", "lost on rebuild")
_ENGINE_NOISE = (
    "already connected",
    "nonexistent connection",
    "tree_exited",
    "Vulkan",
    "ERR_CANT_OPEN",
)
_HEADLESS = {
    2: {"unit": "tools/test_check_rung02.py", "unit_key": "unit_rung02", "log": "a25"},
    3: {"unit": "tools/test_check_rung03.py", "unit_key": "unit_rung03", "log": "a26"},
    4: {"unit": "tools/test_check_rung04.py", "unit_key": "unit_rung04", "log": "a21"},
    5: {"unit": "tools/test_check_rung05.py", "unit_key": "unit_rung05", "log": "a25"},
    6: {"unit": "tools/test_check_rung06.py", "unit_key": "unit_rung06", "log": "a36"},
}


class WalkChrome:
    def part(self, script: str) -> dict:
        cached = self.ctx.get("part")
        if isinstance(cached, dict):
            return cached
        result = proc.run(
            [sys.executable, str(self.repo / "tools" / script), "params"],
            cwd=self.repo,
        )
        data = json.loads(result.stdout)
        self.ctx["part"] = data
        return data

    def _line_mid(self, line: dict) -> list[float]:
        a, b = self._pt(line["start"]), self._pt(line["end"])
        return [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5]

    def _pencil(self, name: str) -> str:
        self._show_timeline()
        mark = self.mark()
        self.click(f"timeline:pencil:{name}")
        self.d.wait_idle(frames=3)
        self.refresh("status", "sketch", "timeline")
        return " | ".join(self.result_texts(mark)) or self.S()

    def _pt(self, value) -> tuple[float, float]:
        return float(value[0]), float(value[1])

    def _reads(self, token: str, text: str) -> bool:
        return label_reads(token, text)

    def _uv_inside(self, uv) -> bool:
        try:
            screen = self.d.project(sketch=list(uv))["screen"]
        except SxError:
            return False
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        x, y = float(screen[0]), float(screen[1])
        return 8 <= x <= float(size[0]) - 8 and 40 <= y <= float(size[1]) - 8

    def _view_centre(self) -> list[float]:
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        return [float(size[0]) * 0.5, float(size[1]) * 0.5]

    def _z_edge_at(self, x: float, y: float) -> dict | None:
        best = None
        best_d = 4.0
        for edge in self.edges():
            direction = edge.get("dir") or [0, 0, 0]
            if abs(float(direction[2])) < 0.9:
                continue
            centre = self._edge_centre(edge)
            dist = ((centre[0] - x) ** 2 + (centre[1] - y) ** 2) ** 0.5
            if dist < best_d:
                best, best_d = edge, dist
        return best

    def arm_by_key(self, key: str) -> dict:
        self.d.key(key)
        self.refresh("status", "rail")
        return {"status": self.S(), "lit": self.lit_names()}

    def body_size(self) -> tuple[float, float, float] | None:
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            return None
        return self._bbox_size(bodies[0])

    def camera(self) -> dict:
        return dict(self.refresh("camera").get("camera") or {})

    def chip_rect(self, cid: str) -> list:
        node = self.control(cid) or {}
        return list(node.get("rect") or [])

    def chrome_nodes(self) -> dict:
        st = self.refresh("window", "controls", "rail")
        win = st.get("window") or {}
        size = win.get("size") or [0, 0]
        return {
            "window": win,
            "size": size,
            "status": self.control("hud:Status"),
            "menu": self.control("menu:File"),
            "rail": (self.refresh("rail").get("rail") or [None])[0],
        }

    def clear_faces(self) -> None:
        self.esc_until("Selection cleared", 4)
        self.refresh("selection")

    def clear_sketch_selection(self) -> None:
        """Empty click so Smart Dim does not reuse the last sketch pick."""
        self.click("rail:Select")
        empty = list(getattr(self, "_EMPTY_SKETCH", (-15.0, 40.0)))
        self.show_sketch_point(empty)
        self.click(sketch=empty)
        self.refresh("selection", "status")

    def dimension_line(self, line: dict, value: str) -> dict:
        self.clear_sketch_selection()
        self.click("rail:SmartDim")
        before = {str(d.get("text", "")) for d in self.dims()}
        mid = self._line_mid(line)
        self.show_sketch_point(mid)
        self.click(sketch=mid)
        self.d.wait_idle(frames=3)
        fresh = [
            d for d in self.dims()
            if str(d.get("text", "")) not in before and "°" not in str(d.get("text", ""))
        ]
        dim = fresh[-1] if fresh else None
        opened = False
        if dim is not None:
            opened = self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"opened": opened, "texts": self.dim_texts(), "status": self.S()}

    def disarm_fillet(self) -> None:
        if self.fillet_armed_count() not in (None, 0):
            self.esc()
            self.refresh("status")

    def dof_text(self) -> str:
        return str(self.refresh("dof").get("dof", "")).strip()

    def dof_zero(self) -> bool:
        return self.dof_text() in ("OK", "0")

    def esc_editor(self) -> dict:
        dim = self.dims()[-1] if self.dims() else None
        opened = self.open_label(dim) if dim else False
        self.esc()
        return {"opened": opened, "editor": self._dim_editor_open(), "texts": self.dim_texts()}

    def exit_sketch(self) -> str:
        mark = self.mark()
        self.click("rail:ExitSketch")
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def feature_names(self) -> list[str]:
        return [str(r.get("name", "")) for r in self._timeline_names(show=True, records=True)]

    def fillet_armed_count(self) -> int | None:
        return self.fillet_count(self.S())

    def fillet_count(self, status: str) -> int | None:
        match = re.search(r"Fillet:\s*(\d+)\s+edge", status)
        return int(match.group(1)) if match else None

    def fit_sketch(self) -> str:
        mark = self.mark()
        self.d.key("f")
        self.d.wait_idle(frames=2)
        return " | ".join(self.result_texts(mark))

    def label_boxes(self, tokens: list[str]) -> list[dict]:
        found = []
        for dim in self.dims():
            if any(self._reads(tok, str(dim.get("text", ""))) for tok in tokens):
                found.append(dim)
        return found

    def label_has(self, token: str) -> bool:
        return any(self._reads(token, text) for text in self.dim_texts())

    def line_length(self, line: dict | None) -> float | None:
        if not line:
            return None
        a, b = self._pt(line["start"]), self._pt(line["end"])
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5

    def log_errors(self) -> list[str]:
        path = self.out / "input-trace.log"
        if not path.is_file():
            return []
        bad = []
        for line in path.read_text(errors="replace").splitlines():
            if "[ERROR]" not in line:
                continue
            if any(tok in line for tok in _ENGINE_NOISE) or any(tok in line for tok in self._INTENDED):
                continue
            bad.append(line)
        return bad

    def look_vector(self, camera: dict) -> list[float] | None:
        pos, target = camera.get("position"), camera.get("target")
        if not pos or not target:
            return None
        vec = [float(target[i]) - float(pos[i]) for i in range(3)]
        length = sum(v * v for v in vec) ** 0.5
        if length < 1e-6:
            return None
        return [v / length for v in vec]

    def new_part(self) -> str:
        self.file_new("ok")
        self.refresh("status")
        return self.S()

    def node_inside(self, node: dict | None, size) -> bool:
        if not node:
            return False
        rect = node.get("rect") or []
        if len(rect) < 4:
            return False
        return (
            rect[0] >= -2
            and rect[1] >= -2
            and rect[0] + rect[2] <= float(size[0]) + 2
            and rect[1] + rect[3] <= float(size[1]) + 2
        )

    def profile_lines(self) -> list[dict]:
        self.refresh("sketch")
        return [
            e for e in self._entities()
            if e.get("type") == "line" and not e.get("construction") and not e.get("external")
        ]

    def project_model(self, model) -> list:
        return list(self.d.project(model=list(model))["screen"])

    def refuse_dim(self, token: str, bad: str) -> dict:
        dim = self.find_dim(lambda d: self._reads(token, str(d.get("text", ""))))
        before = self.dim_texts()
        mark = self.mark()
        if dim is not None:
            self.edit_dim(dim, bad)
        results = " | ".join(self.result_texts(mark))
        return {"results": results or self.S(), "before": before, "after": self.dim_texts()}

    def regen_report(self, mark: int) -> dict:
        lines = self.trace_from(mark)
        bad = [ln for ln in lines if any(tok in ln for tok in _REGEN_BAD)]
        return {"lines": lines, "bad": bad, "names": self.feature_names()}

    def shell_chip(self) -> dict | None:
        node = self.control("strip:shell")
        if not node:
            return None
        if node.get("visible") is False:
            return None
        return node

    def show_sketch_point(self, uv) -> None:
        self.fit_sketch()
        centre = self._view_centre()
        for _ in range(8):
            if self._uv_inside(uv):
                return
            self.d.wheel(notches=-2, screen=centre)
            self.d.wait_idle(frames=1)

    def sketch_bbox(self) -> dict | None:
        pts = []
        for line in self.profile_lines():
            if line.get("start"):
                pts.append(self._pt(line["start"]))
            if line.get("end"):
                pts.append(self._pt(line["end"]))
        if not pts:
            return None
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return {"min": (min(xs), min(ys)), "max": (max(xs), max(ys)), "pts": pts}

    def timeline_panel_rect(self) -> list:
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "panel":
                return list(row.get("rect") or [])
        return []

    def view_key(self, key: str) -> str:
        mark = self.mark()
        self.d.key(key)
        self.d.wait_idle(frames=2)
        self.refresh("status", "camera")
        return " | ".join(self.result_texts(mark)) or self.S()

    def wheel_over(self, cid: str) -> dict:
        before = dict(self.refresh("camera").get("camera") or {})
        rect = self.chip_rect(cid)
        if len(rect) < 4:
            return {"moved": True, "before": before, "after": {}, "rect": rect}
        centre = [rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5]
        self.d.wheel(notches=1, screen=centre)
        self.d.wait_idle(frames=2)
        after = dict(self.refresh("camera").get("camera") or {})
        moved = abs(float(after.get("distance", 0)) - float(before.get("distance", 0))) > 0.05
        return {"moved": moved, "before": before, "after": after, "rect": rect}

    def window_size(self) -> list:
        return (self.refresh("window").get("window") or {}).get("size") or [1280, 800]

    def apply_enter(self) -> str:
        mark = self.mark()
        focus = str(self.refresh("focus").get("focus", ""))
        if "LineEdit" in focus or "SpinBox" in focus:
            self.d.key("tab")
            self.d.wait_idle(frames=1)
        self.enter()
        return " | ".join(self.result_texts(mark)) or self.S()

    def check_probe(self, text: str, name: str) -> tuple[bool, str]:
        for line in text.splitlines():
            bits = line.split()
            if len(bits) >= 2 and bits[1] == name:
                return bits[0] == "PASS", line.strip()
        return False, f"missing {name}"

    def click_verb(self, name: str) -> None:
        chip = self.control(f"chip:{name}")
        if chip and chip.get("visible") is not False:
            self.click(f"chip:{name}")
            return
        more = self.control("chip:… More") or self.control("chip:More")
        if not more:
            raise SxError(f"control not found: chip:{name}")
        self.click("chip:… More" if self.control("chip:… More") else "chip:More")
        self.d.wait_idle(frames=2)
        self.click(f"popup:{name}")

    def _ensure_finish_bar(self) -> None:
        snap = self.refresh("sketch", "controls")
        active = bool((snap.get("sketch") or {}).get("active"))
        ids = {str(c.get("id", "")) for c in (snap.get("controls") or [])}
        if active and "finish:Op" in ids:
            return
        sketches = [n for n in self.feature_names() if str(n).startswith("sketch")]
        if sketches:
            self._pencil(sketches[-1])
        for _ in range(6):
            shown = {str(c.get("id", "")) for c in (self.refresh("controls").get("controls") or [])}
            if "finish:Op" in shown:
                return
            self.d.wait_idle(frames=2)

    def _face_record(self, face_id: str) -> dict | None:
        if not face_id:
            return None
        for face in (self.refresh("faces").get("faces") or []):
            if str(face.get("id")) == face_id:
                return face
        return None

    def profile_circles(self) -> list[dict]:
        self.refresh("sketch")
        return [
            e for e in self._entities()
            if e.get("type") == "circle"
            and not e.get("construction")
            and not e.get("external")
        ]

    def _release_project(self) -> None:
        self.d.close()
        proc_obj = getattr(self, "proc", None)
        if proc_obj is not None and proc_obj.poll() is None:
            proc_obj.terminate()
            try:
                proc_obj.wait(timeout=8)
            except subprocess.TimeoutExpired:
                proc_obj.kill()
                proc_obj.wait(timeout=5)
        log_fp = getattr(self, "log_fp", None)
        if log_fp is not None and not log_fp.closed:
            log_fp.close()

    def reopen(self, name: str) -> dict:
        self.file_new("ok")
        self.open_file(name)
        self.refresh("status", "timeline", "sketch", "bodies")
        return {"status": self.S(), "names": self.feature_names()}

    def selected_edge_count(self) -> int:
        sel = (self.refresh("selection").get("selection") or {})
        edges = sel.get("edges") or []
        return len(edges) if isinstance(edges, list) else 0

    def rects_overlap(self, a, b) -> bool:
        if len(a) < 4 or len(b) < 4:
            return False
        return (
            a[0] < b[0] + b[2]
            and b[0] < a[0] + a[2]
            and a[1] < b[1] + b[3]
            and b[1] < a[1] + a[3]
        )

    def select_face(self, normal, plane=None) -> dict:
        fields: dict = {"face_normal": list(normal)}
        if plane is not None:
            fields["plane"] = float(plane)
        reply = self.click(**fields)
        self.refresh("selection", "status", "faces")
        sel = self.st.get("selection") or {}
        if not sel.get("face"):
            reply = self.click(**fields)
            self.refresh("selection", "status", "controls", "faces")
            sel = self.st.get("selection") or {}
        else:
            self.refresh("controls", "faces")
        face_id = str(sel.get("face") or "")
        record = self._face_record(face_id)
        return {
            "face": face_id,
            "status": str(reply.get("status", self.S())),
            "normal": reply.get("normal") or (record or {}).get("normal"),
            "plane": (record or {}).get("plane"),
            "record": record,
        }

    def sketch_on_datum(self, name: str, view_key: str) -> dict:
        self.d.key(view_key)
        self.d.wait_idle(frames=2)
        self.click("rail:Sketch")
        self.refresh("status")
        self.click(datum=name)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "camera")
        sk = self.st.get("sketch") or {}
        return {
            "status": self.S(),
            "active": bool(sk.get("active")),
            "plane": sk.get("plane") or {},
        }

    def _rung(self) -> int:
        return int(getattr(self, "_RUNG", 0))

    def headless(self, unit_script: str | None = None, unit_key: str | None = None,
                 log_stem: str | None = None) -> dict[str, dict]:
        row = _HEADLESS[self._rung()]
        unit_script = unit_script or row["unit"]
        unit_key = unit_key or row["unit_key"]
        log_stem = log_stem or row["log"]
        keys = ("kernel", "godot", "lint", "unit", "registry", "errors")
        if not self.run_a15:
            blocked = "BLOCKED-by-flag: pass --a15"
            return {key: {"ok": False, "evidence": blocked} for key in keys}
        errors = self.log_errors()
        owned = take("kernel")
        if owned is not None:
            return self._headless_report(
                owned,
                run_tier(self),
                take("lint_suites"),
                take(unit_key),
                take("registry"),
                errors,
                log_stem,
            )
        self._release_project()
        try:
            kernel = run_kernel(self.repo)
            godot = run_tier(self)
            lint = proc.run([sys.executable, "tools/lint_suites.py"], cwd=self.repo)
            unit = proc.run([sys.executable, unit_script], cwd=self.repo)
            registry = proc.run([sys.executable, "tools/test_walk_registry.py"], cwd=self.repo)
        finally:
            if getattr(self, "proc", None) is None or self.proc.poll() is not None:
                self.launch()
        return self._headless_report(kernel, godot, lint, unit, registry, errors, log_stem)

    def _headless_report(self, kernel, godot, lint, unit, registry, errors,
                        log_stem: str | None = None) -> dict[str, dict]:
        log_stem = log_stem or _HEADLESS[self._rung()]["log"]
        godot_text = (godot.stdout or "") + (godot.stderr or "")
        (self.out / f"{log_stem}-godot.log").write_text(godot_text)
        (self.out / f"{log_stem}-kernel.log").write_text((kernel.stdout or "") + (kernel.stderr or ""))
        ran = parse_tier(godot_text)
        return {
            "kernel": {"ok": kernel.returncode == 0, "evidence": proc.tail(kernel.stdout, kernel.stderr)},
            "godot": {
                "ok": ran is not None and ran[1] == 0,
                "evidence": (
                    f"suites: {ran[0]} run, {ran[1]} failed"
                    if ran else proc.tail(godot.stdout, godot.stderr)
                ),
            },
            "lint": {"ok": lint.returncode == 0, "evidence": proc.tail(lint.stdout, lint.stderr)},
            "unit": {"ok": unit.returncode == 0, "evidence": proc.tail(unit.stdout, unit.stderr)},
            "registry": {
                "ok": registry.returncode == 0,
                "evidence": proc.tail(registry.stdout, registry.stderr),
            },
            "errors": {"ok": not errors, "evidence": "; ".join(errors[:3]) or "none"},
        }
