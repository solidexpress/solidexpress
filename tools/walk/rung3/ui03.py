"""Rung-3 gestures: centre rect, face sketch, offset, fillet, shell, section.

Rows call these helpers. Pixel positions come from project(), never literals.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

from sxdrive import SxError
from walk import proc
from walk.gates import parse_tier, run_tier
from walk.gestures import label_reads

# Vertical corner → view key (FilletPick.CORNERS / WP6).
# Right (2) shows +X corners; Left (6) shows −X. Mid-height z=15.
CORNERS = (
    (60.0, 60.0, "2"),
    (60.0, -60.0, "2"),
    (-60.0, 60.0, "6"),
    (-60.0, -60.0, "6"),
)

# SectionPlane.CAP_COLOUR = Color(0.62, 0.66, 0.72) → 8-bit RGB.
CAP_COLOUR = (158, 168, 184)
WALL_POINT = (-59.5, 0.0, 12.0)
REMOVED_POINT = (0.0, 40.0, 15.0)

_REGEN_BAD = ("[ERROR]", "soft-skip", "regenerate stopped", "lost on rebuild")
_ENGINE_NOISE = (
    "already connected",
    "nonexistent connection",
    "tree_exited",
    "Vulkan",
    "ERR_CANT_OPEN",
)
_INTENDED = (
    "Dimension must be a positive number",
    "limit",
    "nothing added",
    "Extrude failed",
    "fillet failed",
    "Fillet could not be built",
    "Offset: distance must be greater than 0",
    "Offset: inward distance is at least the radius",
    "Offset: nothing there",
    "regenerate stopped at feature fillet",
)

REFUSE_FACE = (
    "No edge near click — click on an edge "
    "(a face click fillets the whole face only as the first pick)"
)


def _kernel_failure_tail(result: subprocess.CompletedProcess) -> str:
    """Tail of one binary, with the FAILED assertion line when the summary hides it."""
    text = ((result.stdout or "") + (result.stderr or "")).strip()
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    if not lines:
        return "no output"
    last = lines[-1]
    named = ""
    for ln in reversed(lines):
        if "FAILED" in ln:
            named = ln
            break
    if named and named != last:
        return f"{named} — {last}"
    return last


class WalkUI03:
    def part(self) -> dict:
        cached = self.ctx.get("part")
        if isinstance(cached, dict):
            return cached
        result = proc.run(
            [sys.executable, str(self.repo / "tools" / "check_rung03.py"), "params"],
            cwd=self.repo,
        )
        data = json.loads(result.stdout)
        self.ctx["part"] = data
        return data

    def side(self) -> float:
        return float(self.part()["PART"]["SIDE"])

    def height(self) -> float:
        part = self.part()["PART"]
        return float(self.ctx.get("height", part["H0"]))

    def _view_centre(self) -> list[float]:
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        return [float(size[0]) * 0.5, float(size[1]) * 0.5]

    def _uv_inside(self, uv) -> bool:
        try:
            screen = self.d.project(sketch=list(uv))["screen"]
        except SxError:
            return False
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        x, y = float(screen[0]), float(screen[1])
        return 8 <= x <= float(size[0]) - 8 and 40 <= y <= float(size[1]) - 8

    def fit_sketch(self) -> str:
        mark = self.mark()
        self.d.key("f")
        self.d.wait_idle(frames=2)
        return " | ".join(self.result_texts(mark))

    def show_sketch_point(self, uv) -> None:
        self.fit_sketch()
        centre = self._view_centre()
        for _ in range(8):
            if self._uv_inside(uv):
                return
            self.d.wheel(notches=-2, screen=centre)
            self.d.wait_idle(frames=1)

    def new_part(self) -> str:
        self.file_new("ok")
        self.refresh("status")
        return self.S()

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

    def arm_rect_centre(self) -> dict:
        self.click("rail:Rect")
        self.refresh("status", "controls", "rail")
        self.click("variant:Center")
        self.refresh("status", "controls", "rail")
        lit = self.lit_names()
        variant = self.control("variant:Center") or {}
        return {
            "status": self.S(),
            "lit": lit,
            "variant": variant,
            "ok": self.S().startswith("Rect") and any("Rect" in n for n in lit),
            "centre": bool(variant.get("pressed") or variant.get("lit")
                           or "Center" in str(variant.get("text", ""))),
        }

    def profile_lines(self) -> list[dict]:
        self.refresh("sketch")
        return [
            e for e in self._entities()
            if e.get("type") == "line" and not e.get("construction") and not e.get("external")
        ]

    def _pt(self, value) -> tuple[float, float]:
        return float(value[0]), float(value[1])

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

    def centre_rect(self, a=(0.0, 0.0), b=(60.0, 60.0)) -> dict:
        armed = self.arm_rect_centre()
        self.show_sketch_point(b)
        mark = self.mark()
        self.click(sketch=list(a))
        self.click(sketch=list(b))
        self.refresh("sketch", "status", "tool")
        results = [t for t in self.result_texts(mark) if t]
        box = self.sketch_bbox()
        lines = self.profile_lines()
        centre_ok = False
        if box and lines:
            mid = (
                (box["min"][0] + box["max"][0]) * 0.5,
                (box["min"][1] + box["max"][1]) * 0.5,
            )
            centre_ok = abs(mid[0]) <= 0.2 and abs(mid[1]) <= 0.2
        return {
            "armed": armed,
            "lines": lines,
            "bbox": box,
            "centred": centre_ok,
            "status": " | ".join(results) or self.S(),
        }

    def _line_mid(self, line: dict) -> list[float]:
        a, b = self._pt(line["start"]), self._pt(line["end"])
        return [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5]

    def top_line(self) -> dict | None:
        horiz = [
            ln for ln in self.profile_lines()
            if abs(self._pt(ln["start"])[1] - self._pt(ln["end"])[1]) < 0.5
        ]
        return max(horiz, key=lambda ln: self._pt(ln["start"])[1], default=None)

    def right_line(self) -> dict | None:
        vert = [
            ln for ln in self.profile_lines()
            if abs(self._pt(ln["start"])[0] - self._pt(ln["end"])[0]) < 0.5
        ]
        return max(vert, key=lambda ln: self._pt(ln["start"])[0], default=None)

    def line_length(self, line: dict | None) -> float | None:
        if not line:
            return None
        a, b = self._pt(line["start"]), self._pt(line["end"])
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5

    def clear_sketch_selection(self) -> None:
        self.click("rail:Select")
        self.show_sketch_point([30, 20])
        self.click(sketch=[30, 20])
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

    def dof_text(self) -> str:
        return str(self.refresh("dof").get("dof", "")).strip()

    def dof_zero(self) -> bool:
        return self.dof_text() in ("OK", "0")

    def label_has(self, token: str) -> bool:
        return any(self._reads(token, text) for text in self.dim_texts())

    def _reads(self, token: str, text: str) -> bool:
        return label_reads(token, text)

    def refuse_dim(self, token: str, bad: str) -> dict:
        dim = self.find_dim(lambda d: self._reads(token, str(d.get("text", ""))))
        before = self.dim_texts()
        mark = self.mark()
        if dim is not None:
            self.edit_dim(dim, bad)
        results = " | ".join(self.result_texts(mark))
        return {"results": results or self.S(), "before": before, "after": self.dim_texts()}

    def esc_editor(self) -> dict:
        dim = self.dims()[-1] if self.dims() else None
        opened = self.open_label(dim) if dim else False
        self.esc()
        return {"opened": opened, "editor": self._dim_editor_open(), "texts": self.dim_texts()}

    def label_boxes(self, tokens: list[str]) -> list[dict]:
        found = []
        for dim in self.dims():
            if any(self._reads(tok, str(dim.get("text", ""))) for tok in tokens):
                found.append(dim)
        return found

    def rects_overlap(self, a, b) -> bool:
        if len(a) < 4 or len(b) < 4:
            return False
        return (
            a[0] < b[0] + b[2]
            and b[0] < a[0] + a[2]
            and a[1] < b[1] + b[3]
            and b[1] < a[1] + a[3]
        )

    def arm_by_key(self, key: str) -> dict:
        self.d.key(key)
        self.refresh("status", "rail")
        return {"status": self.S(), "lit": self.lit_names()}

    def rail_label_nodes(self) -> list[dict]:
        want = {"Rect", "Smart Dim", "Circle", "Convert", "Offset", "Select"}
        nodes = []
        for c in (self.refresh("controls").get("controls") or []):
            if str(c.get("text", "")) in want:
                nodes.append(c)
        return nodes

    def try_extrude(
        self, distance: str, op: str = "New", end: str = "Blind", apply: bool = True,
    ) -> dict:
        self._ensure_finish_bar()
        self.set_option("finish:Op", op)
        self.set_option("finish:End", end)
        shown = self.type_into("finish:Distance", distance)
        self.refresh("finish")
        op_text = self.field("finish:Op")
        end_text = self.field("finish:End")
        if op_text == "" or end_text == "":
            self.d.wait_idle(frames=3)
            self.refresh("finish")
            op_text = self.field("finish:Op") or op_text
            end_text = self.field("finish:End") or end_text
        mark = self.mark()
        reply = self.click("finish:Extrude", frames=8) if apply else {}
        if apply:
            self.d.wait_idle(frames=8)
        results = self.result_texts(mark) if apply else []
        self.refresh("status", "sketch", "finish")
        bodies = list(self.refresh("bodies").get("bodies") or [])
        return {
            "field": shown,
            "op": op_text,
            "end": end_text,
            "reply": reply,
            "results": results,
            "status": " | ".join(results) or str(reply.get("status", self.S())),
            "sketch": bool((self.refresh("sketch").get("sketch") or {}).get("active")),
            "bodies": bodies,
            "names": self.feature_names(),
        }

    def s0(self, height: float | None = None) -> dict:
        self.refresh("bodies")
        bodies = list(self.st.get("bodies") or [])
        side = self.side()
        h = float(height if height is not None else self.height())
        if len(bodies) != 1:
            named = ", ".join(f"{b.get('name')} ({self._fmt_volume(b)})" for b in bodies) or "(none)"
            left = self.ctx.get("bodies_left_by") or "unknown"
            return {"ok": False, "evidence": f"runner-gap: stray body {named} left by {left}"}
        body = bodies[0]
        name = str(body.get("name", ""))
        sx, sy, sz = self._bbox_size(body)
        prefix = name.lower().startswith("extrude")
        size_ok = abs(sx - side) <= 0.1 and abs(sy - side) <= 0.1 and abs(sz - h) <= 0.1
        evidence = (
            f"{name} ({self._fmt_volume(body)}) bbox {sx:.3f}×{sy:.3f}×{sz:.3f}"
            f" want {side:.0f}×{side:.0f}×{h:.0f}"
        )
        if not (prefix and size_ok):
            evidence = "runner-gap: " + evidence
        return {"ok": prefix and size_ok, "evidence": evidence, "volume": body.get("volume")}

    def export_and_check(self, stage: str, filename: str, height: float | None = None) -> dict:
        guard = self.s0(height)
        if not guard["ok"]:
            return {
                "s0": False,
                "s0_evidence": guard["evidence"],
                "exported": False,
                "check_ok": False,
                "check_text": "",
                "volume": guard.get("volume"),
            }
        path = self.export_3mf(filename)
        code, text = self.checker(stage, filename)
        check_ok = code == 0 and "\nFAIL " not in ("\n" + text) and not text.startswith("FAIL")
        if "FAIL" in text:
            check_ok = False
        check_text = text.strip().splitlines()[-1] if text.strip() else ""
        return {
            "s0": True,
            "s0_evidence": guard["evidence"],
            "exported": Path(path).is_file(),
            "check_ok": check_ok,
            "check_text": check_text,
            "volume": guard.get("volume"),
        }

    def feature_names(self) -> list[str]:
        return [str(r.get("name", "")) for r in self._timeline_names(show=True, records=True)]

    def select_body(self) -> str:
        self.refresh("bodies", "selection")
        if str((self.st.get("selection") or {}).get("body") or ""):
            return self.S()
        bodies = self.st.get("bodies") or []
        if not bodies:
            raise SxError("no body to select")
        screen = bodies[0].get("screen")
        if not screen:
            screen = self.d.project(model=[0, 0, self.height() * 0.5])["screen"]
        self.click(screen=screen)
        self.refresh("selection", "status")
        return self.S()

    def select_face(self, normal, plane=None) -> dict:
        # First click selects the body; the second drills to the face.
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

    def _face_record(self, face_id: str) -> dict | None:
        if not face_id:
            return None
        for face in (self.refresh("faces").get("faces") or []):
            if str(face.get("id")) == face_id:
                return face
        return None

    def face_sketch(self, normal, plane: float, view_key: str = "3") -> dict:
        self.ctx["camera_before_sketch"] = dict(self.refresh("camera").get("camera") or {})
        self.select_body()
        mark = self.mark()
        self.d.key(view_key)
        self.d.wait_idle(frames=2)
        view = " | ".join(self.result_texts(mark))
        selected = self.select_face(normal, plane=plane)
        camera = dict(self.refresh("camera").get("camera") or {})
        self.click("chip:Sketch")
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        sk = self.st.get("sketch") or {}
        return {
            "selected": selected,
            "view": view,
            "camera": camera,
            "active": bool(sk.get("active")),
            "plane": sk.get("plane") or {},
            "status": self.S(),
        }

    def draw_circle(self, centre=(0.0, 0.0), rim=(35.0, 0.0)) -> dict:
        self.show_sketch_point(rim)
        made = self.circle(list(centre), rim=list(rim))
        circles = [
            e for e in self._entities(kind="circle")
            if not e.get("external") and not e.get("construction")
        ]
        return {
            "status": made["status"] if isinstance(made, dict) else str(made),
            "circles": circles if isinstance(made, dict) else circles,
        }

    def dimension_diameter(self, value: str) -> dict:
        circles = [
            e for e in self._entities()
            if e.get("type") == "circle" and not e.get("construction") and not e.get("external")
        ]
        if not circles:
            return {"texts": self.dim_texts(), "status": "no circle"}
        centre = circles[0]["center"]
        radius = float(circles[0].get("radius") or 5)
        rim = [float(centre[0]) + radius, float(centre[1])]
        self.click("rail:SmartDim")
        self.show_sketch_point(rim)
        self.click(sketch=rim)
        self.d.wait_idle(frames=2)
        dim = self.dims()[-1] if self.dims() else None
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def arm_fillet(self, radius: str = "5") -> dict:
        self.select_body()
        self.click("chip:Fillet")
        shown = self.type_into("finish:StripR", radius)
        self.d.key("tab")
        self.d.wait_idle(frames=2)
        self.refresh("status", "finish", "controls")
        return {"status": self.S(), "radius": shown or self.field("finish:StripR")}

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

    def _edge_centre(self, edge: dict) -> tuple[float, float, float]:
        a = edge.get("a") or edge.get("mid") or [0, 0, 0]
        b = edge.get("b") or a
        return (
            (float(a[0]) + float(b[0])) * 0.5,
            (float(a[1]) + float(b[1])) * 0.5,
            (float(a[2]) + float(b[2])) * 0.5,
        )

    def pick_corner_edges(self) -> list[dict]:
        picked = []
        for x, y, view in CORNERS:
            self.d.key(view)
            self.d.wait_idle(frames=2)
            edge = self._z_edge_at(x, y)
            if edge is None:
                picked.append({"ok": False, "status": f"no edge at {(x, y)}", "id": "", "view": view})
                continue
            mark = self.mark()
            reply = self.d.click(edge=edge["id"], along=0.5)
            status = " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))
            vertical = "30.0 mm vertical" in status or "30 mm vertical" in status
            picked.append({
                "ok": True,
                "status": status,
                "id": edge["id"],
                "view": view,
                "vertical": vertical,
            })
        self.ctx["corner_edges"] = picked
        return picked

    def pick_edge_again(self, edge_id: str, view: str = "") -> str:
        if view:
            self.d.key(view)
            self.d.wait_idle(frames=2)
        mark = self.mark()
        reply = self.d.click(edge=edge_id, along=0.5)
        return " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))

    def fillet_count(self, status: str) -> int | None:
        match = re.search(r"Fillet:\s*(\d+)\s+edge", status)
        return int(match.group(1)) if match else None

    def fillet_armed_count(self) -> int | None:
        return self.fillet_count(self.S())

    def disarm_fillet(self) -> None:
        if self.fillet_armed_count() not in (None, 0):
            self.esc()
            self.refresh("status")

    def shift_click_face(self, normal, plane: float) -> dict:
        self.d.key("shift", action="down")
        self.d.wait_idle(frames=1)
        mark = self.mark()
        fields = {"face_normal": list(normal), "plane": float(plane)}
        reply = self.click(**fields)
        status = " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))
        self.d.key("shift", action="up")
        self.d.wait_idle(frames=1)
        self.refresh("status", "selection")
        return {"status": status, "count": self.fillet_count(status)}

    def plain_click_face(self, normal, plane: float) -> dict:
        mark = self.mark()
        reply = self.click(face_normal=list(normal), plane=float(plane))
        status = " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))
        return {"status": status, "count": self.fillet_count(self.S())}

    def chip_rect(self, cid: str) -> list:
        node = self.control(cid) or {}
        return list(node.get("rect") or [])

    def apply_enter(self) -> str:
        mark = self.mark()
        focus = str(self.refresh("focus").get("focus", ""))
        if "LineEdit" in focus or "SpinBox" in focus:
            self.d.key("tab")
            self.d.wait_idle(frames=1)
        self.enter()
        return " | ".join(self.result_texts(mark)) or self.S()

    def view_key(self, key: str) -> str:
        mark = self.mark()
        self.d.key(key)
        self.d.wait_idle(frames=2)
        self.refresh("status", "camera")
        return " | ".join(self.result_texts(mark)) or self.S()

    def camera(self) -> dict:
        return dict(self.refresh("camera").get("camera") or {})

    def window_size(self) -> list:
        return (self.refresh("window").get("window") or {}).get("size") or [1280, 800]

    def project_model(self, model) -> list:
        return list(self.d.project(model=list(model))["screen"])

    def look_vector(self, camera: dict) -> list[float] | None:
        pos, target = camera.get("position"), camera.get("target")
        if not pos or not target:
            return None
        vec = [float(target[i]) - float(pos[i]) for i in range(3)]
        length = sum(v * v for v in vec) ** 0.5
        if length < 1e-6:
            return None
        return [v / length for v in vec]

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

    def exit_sketch(self) -> str:
        mark = self.mark()
        self.click("rail:ExitSketch")
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def _pencil(self, name: str) -> str:
        self._show_timeline()
        mark = self.mark()
        self.click(f"timeline:pencil:{name}")
        self.d.wait_idle(frames=3)
        self.refresh("status", "sketch", "timeline")
        return " | ".join(self.result_texts(mark)) or self.S()

    def offset_arm(self) -> dict:
        mark = self.mark()
        self.click("rail:Offset")
        self.d.wait_idle(frames=2)
        self.refresh("status", "controls", "rail")
        lit = self.lit_names()
        fields = {
            "distance": self.control("offset:Distance"),
            "reverse": self.control("offset:Reverse"),
            "ok": self.control("offset:Ok"),
        }
        status = " | ".join(self.result_texts(mark)) or self.S()
        return {
            "status": status,
            "lit": lit,
            "fields": fields,
            "armed": any("Offset" in n for n in lit) or status.startswith("Offset"),
        }

    def offset_set_distance(self, value: str) -> str:
        return self.type_into("offset:Distance", value)

    def offset_set_reverse(self, on: bool = True) -> dict:
        node = self.control("offset:Reverse") or {}
        pressed = bool(node.get("pressed") or node.get("button_pressed"))
        if pressed != on:
            self.click("offset:Reverse")
            self.refresh("controls", "status")
            node = self.control("offset:Reverse") or {}
        return {
            "pressed": bool(node.get("pressed") or node.get("button_pressed")),
            "text": str(node.get("text", "")),
        }

    def offset_rim(self, model=(35.0, 0.0, 55.0)) -> dict:
        mark = self.mark()
        reply = self.click(model=list(model))
        self.refresh("sketch", "status", "dof")
        status = " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))
        return {
            "status": status,
            "profile": self.profile_circles(),
            "external": self.external_circles(),
            "dof": self.dof_text(),
        }

    def profile_circles(self) -> list[dict]:
        self.refresh("sketch")
        return [
            e for e in self._entities()
            if e.get("type") == "circle"
            and not e.get("construction")
            and not e.get("external")
        ]

    def external_circles(self) -> list[dict]:
        self.refresh("sketch")
        return [
            e for e in self._entities()
            if e.get("type") == "circle" and (e.get("external") or e.get("construction"))
        ]

    def offset_ok(self) -> dict:
        mark = self.mark()
        self.click("offset:Ok")
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status", "sketch")
        panel = self.control("offset:Distance")
        visible = bool(panel) and panel.get("visible") is not False
        return {
            "status": " | ".join(self.result_texts(mark)) or self.S(),
            "panel_visible": visible,
            "profile": self.profile_circles(),
            "external": self.external_circles(),
        }

    def shell_chip(self) -> dict | None:
        node = self.control("strip:shell")
        if not node:
            return None
        if node.get("visible") is False:
            return None
        return node

    def shell_back(self, thickness: str = "1") -> dict:
        view = self.view_key("8")
        self.select_body()
        selected = self.select_face([0, 0, -1])
        chip = self.shell_chip()
        shown = ""
        status = ""
        names: list[str] = []
        if chip is not None:
            self.click("strip:shell")
            self.refresh("controls")
            shown = self.type_into("finish:Thickness", thickness)
            mark = self.mark()
            self.enter()
            status = " | ".join(self.result_texts(mark)) or self.S()
            names = self.feature_names()
        return {
            "view": view,
            "selected": selected,
            "chip": chip,
            "shown": shown,
            "status": status,
            "names": names,
        }

    def apply_shell(self, text: str) -> dict:
        self.click("strip:shell")
        self.refresh("controls")
        shown = self.type_into("finish:Thickness", text)
        mark = self.mark()
        self.enter()
        results = self.result_texts(mark)
        field = str((self.control("finish:Thickness") or {}).get("text", ""))
        return {
            "shown": shown,
            "field": field,
            "status": " | ".join(results) or self.S(),
            "names": self.feature_names(),
        }

    def clear_faces(self) -> None:
        self.esc_until("Selection cleared", 4)
        self.refresh("selection")

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

    def covered(self, rect: list, skip_ids: tuple[str, ...] = ("strip:shell",)) -> bool:
        if len(rect) < 4:
            return True
        cx, cy = rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5
        for c in (self.refresh("controls").get("controls") or []):
            if c.get("id") in skip_ids:
                continue
            other = c.get("rect") or []
            if len(other) < 4:
                continue
            if other[0] <= cx <= other[0] + other[2] and other[1] <= cy <= other[1] + other[3]:
                if float(other[2]) * float(other[3]) < float(rect[2]) * float(rect[3]):
                    return True
        return False

    def open_section(self, plane: str = "Top") -> dict:
        mark = self.mark()
        self.click("hud:Section")
        self.d.wait_idle(frames=2)
        self.click(f"popup:{plane}")
        self.d.wait_idle(frames=2)
        self.refresh("section", "status", "controls")
        section = dict(self.st.get("section") or {})
        btn = self.control("hud:Section") or {}
        status = " | ".join(self.result_texts(mark)) or self.S()
        return {
            "section": section,
            "button": btn,
            "status": status,
            "pressed": bool(btn.get("pressed") or btn.get("button_pressed")),
        }

    def toggle_section(self) -> dict:
        mark = self.mark()
        self.click("hud:Section")
        self.d.wait_idle(frames=2)
        self.refresh("section", "status", "controls")
        section = dict(self.st.get("section") or {})
        btn = self.control("hud:Section") or {}
        return {
            "section": section,
            "button": btn,
            "status": " | ".join(self.result_texts(mark)) or self.S(),
            "pressed": bool(btn.get("pressed") or btn.get("button_pressed")),
        }

    def section_state(self) -> dict:
        return dict(self.refresh("section").get("section") or {})

    def pixel_at(self, model) -> list[int] | None:
        screen = self.project_model(model)
        reply = self.d.pixels([screen])
        pixels = reply.get("pixels") or []
        if not pixels:
            return None
        rgba = pixels[0].get("rgba") or []
        if len(rgba) < 3:
            return None
        return [int(rgba[0]), int(rgba[1]), int(rgba[2])]

    def pixel_is(self, model, colour=CAP_COLOUR, tol: int = 6) -> dict:
        got = self.pixel_at(model)
        if got is None:
            return {"ok": False, "got": None, "want": colour}
        ok = all(abs(got[i] - colour[i]) <= tol for i in range(3))
        return {"ok": ok, "got": got, "want": colour}

    def body_size(self) -> tuple[float, float, float] | None:
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            return None
        return self._bbox_size(bodies[0])

    def reopen(self, name: str) -> dict:
        self.file_new("ok")
        self.open_file(name)
        self.refresh("status", "timeline", "sketch", "section", "bodies")
        return {
            "status": self.S(),
            "names": self.feature_names(),
            "section": self.section_state(),
        }

    def timeline_panel_rect(self) -> list:
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "panel":
                return list(row.get("rect") or [])
        return []

    def regen_report(self, mark: int) -> dict:
        lines = self.trace_from(mark)
        bad = [ln for ln in lines if any(tok in ln for tok in _REGEN_BAD)]
        return {"lines": lines, "bad": bad, "names": self.feature_names()}

    def log_errors(self) -> list[str]:
        path = self.out / "input-trace.log"
        if not path.is_file():
            return []
        bad = []
        for line in path.read_text(errors="replace").splitlines():
            if "[ERROR]" not in line:
                continue
            if any(tok in line for tok in _ENGINE_NOISE) or any(tok in line for tok in _INTENDED):
                continue
            bad.append(line)
        return bad

    def headless(self) -> dict[str, dict]:
        keys = ("kernel", "godot", "lint", "unit", "registry", "errors")
        if not self.run_a15:
            blocked = "BLOCKED-by-flag: pass --a15"
            return {key: {"ok": False, "evidence": blocked} for key in keys}
        errors = self.log_errors()
        self._release_project()
        try:
            kernel = self._kernel_tests()
            godot = run_tier(self)
            lint = proc.run([sys.executable, "tools/lint_suites.py"], cwd=self.repo)
            unit = proc.run([sys.executable, "tools/test_check_rung03.py"], cwd=self.repo)
            registry = proc.run([sys.executable, "tools/test_walk_registry.py"], cwd=self.repo)
        finally:
            if getattr(self, "proc", None) is None or self.proc.poll() is not None:
                self.launch()
        godot_text = (godot.stdout or "") + (godot.stderr or "")
        (self.out / "a26-godot.log").write_text(godot_text)
        (self.out / "a26-kernel.log").write_text((kernel.stdout or "") + (kernel.stderr or ""))
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

    def _kernel_tests(self) -> subprocess.CompletedProcess:
        # Keep each binary's own (name, result). A later passer (sxvoice_tests
        # prints "All tests passed") must not become the A26 kernel evidence
        # when an earlier binary failed — proc.tail() of a blind concatenation
        # is exactly that bug.
        pairs: list[tuple[str, subprocess.CompletedProcess]] = []
        code = 0
        for rel in ("./build/sxkernel/sxkernel_tests", "./build/sxvoice/sxvoice_tests"):
            result = proc.run([rel], cwd=self.repo)
            pairs.append((rel, result))
            if result.returncode != 0 and code == 0:
                code = result.returncode
        chunks = [(result.stdout or "") + (result.stderr or "") for _name, result in pairs]
        if code != 0:
            labelled = [
                f"{name}: {_kernel_failure_tail(result)}"
                for name, result in pairs
                if result.returncode != 0
            ]
            # First failing binary leads. headless() still takes proc.tail of
            # this stream, so the labelled line has to be last — and a26-kernel.log
            # still contains every binary's full output above it.
            chunks.append(" | ".join(labelled))
        return subprocess.CompletedProcess(["kernel"], code, "\n".join(chunks), "")
