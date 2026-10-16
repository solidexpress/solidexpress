"""Rung-3 gestures: centre rect, face sketch, offset, fillet, shell, section.

Rows call these helpers. Pixel positions come from project(), never literals.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from sxdrive import SxError
from walk import proc
from walk.chrome import WalkChrome
from walk.gates import parse_tier, run_kernel, run_tier, take

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
# Iso (key 7) sits on model −Y, so Top keeps +Y and the removed half is −Y.
REMOVED_POINT = (0.0, -40.0, 15.0)


REFUSE_FACE = (
    "No edge near click — click on an edge "
    "(a face click fillets the whole face only as the first pick)"
)


class WalkUI03(WalkChrome):
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

    def part(self) -> dict:
        return WalkChrome.part(self, "check_rung03.py")

    def side(self) -> float:
        return float(self.part()["PART"]["SIDE"])

    def height(self) -> float:
        part = self.part()["PART"]
        return float(self.ctx.get("height", part["H0"]))

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

    def clear_sketch_selection(self) -> None:
        self.click("rail:Select")
        self.show_sketch_point([30, 20])
        self.click(sketch=[30, 20])
        self.refresh("selection", "status")

    def rects_overlap(self, a, b) -> bool:
        if len(a) < 4 or len(b) < 4:
            return False
        return (
            a[0] < b[0] + b[2]
            and b[0] < a[0] + a[2]
            and a[1] < b[1] + b[3]
            and b[1] < a[1] + a[3]
        )

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
        # Enter commits the radius and releases the LineEdit. Tab left it
        # focused, and the next 2/6 was typed into the field instead of
        # changing the view — the far vertical then toggled the near one.
        self.d.key("enter")
        self.d.wait_idle(frames=2)
        self.refresh("status", "finish", "controls")
        return {"status": self.S(), "radius": shown or self.field("finish:StripR")}

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
            self._release_numeric_focus()
            self.d.key(view)
            # Number-row views snap, but a running pose tween and the radius
            # field's focus release both need more than a couple of frames
            # before the corner's screen point is the near edge.
            self.d.wait_idle(frames=8)
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

    def _release_numeric_focus(self) -> None:
        focus = str(self.refresh("focus").get("focus", ""))
        if "LineEdit" not in focus and "Spin" not in focus:
            return
        self.d.key("enter")
        self.d.wait_idle(frames=2)

    def pick_edge_again(self, edge_id: str, view: str = "") -> str:
        if view:
            self._release_numeric_focus()
            self.d.key(view)
            self.d.wait_idle(frames=8)
        mark = self.mark()
        reply = self.d.click(edge=edge_id, along=0.5)
        return " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))

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
        # The refusal replaces the "Fillet: N edge(s)" line. The picks are
        # still the selection; the status text no longer carries the count.
        count = self.fillet_count(status)
        if count is None:
            count = self.selected_edge_count()
        return {"status": status, "count": count}

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

    def covered(self, rect: list, skip_ids: tuple[str, ...] = ("strip:shell",),
                owner_path: str = "") -> bool:
        if len(rect) < 4:
            return True
        cx, cy = rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5
        for c in (self.refresh("controls").get("controls") or []):
            if c.get("id") in skip_ids:
                continue
            if c.get("blocks_mouse", True) is False:
                continue
            path = str(c.get("path") or "")
            if owner_path and (path == owner_path or path.startswith(owner_path + "/")):
                continue
            other = c.get("rect") or []
            if len(other) < 4:
                continue
            # The widget's own chrome sits inside its rect. A cover is a
            # different control that reaches the centre from outside.
            inside = (
                other[0] >= rect[0] - 1.0
                and other[1] >= rect[1] - 1.0
                and other[0] + other[2] <= rect[0] + rect[2] + 1.0
                and other[1] + other[3] <= rect[1] + rect[3] + 1.0
            )
            if inside:
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

    def reopen(self, name: str) -> dict:
        self.file_new("ok")
        self.open_file(name)
        self.refresh("status", "timeline", "sketch", "section", "bodies")
        return {
            "status": self.S(),
            "names": self.feature_names(),
            "section": self.section_state(),
        }

    def headless(self) -> dict[str, dict]:
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
                take("unit_rung03"),
                take("registry"),
                errors,
            )
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
        return self._headless_report(kernel, godot, lint, unit, registry, errors)

    def _headless_report(self, kernel, godot, lint, unit, registry, errors) -> dict[str, dict]:
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

    def _kernel_tests(self) -> subprocess.CompletedProcess:
        # Labelled by run_kernel so a later passer cannot hide an earlier failure.
        return run_kernel(self.repo)
