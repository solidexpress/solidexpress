"""Rung-7 gestures: Front C + 12-point + handle, mid-plane pads, recess, Front mirror."""
from __future__ import annotations

import math
from pathlib import Path

from sxdrive import SxError
from walk.chrome import WalkChrome

PINNED_NEW = "New — empty part, Top plane (XY). View ▸ Timeline to edit features"

STAGE_FILE = {
    "boss": "boss.3mf",
    "neck": "neck.3mf",
    "mirror": "mirror.3mf",
    "final": "final.3mf",
}


class WalkUI07(WalkChrome):
    _RUNG = 7
    _EMPTY_SKETCH = (-40.0, 40.0)
    _INTENDED = (
        "Dimension must be a positive number",
        "nothing added",
        "Mirror: pick features",
        "Mirror needs a selection",
        "distance must be greater than 0",
        "fillet failed",
        "Fillet could not be built",
        "could not be built",
        "regenerate stopped at feature fillet",
        "Select a closed profile",
        "no selected contour",
        "Offset: distance must be greater than 0",
    )

    def part(self) -> dict:
        return WalkChrome.part(self, "check_rung07.py")

    def mm(self, key: str) -> float:
        return float(self.part()["PART"][key])

    def deg(self) -> float:
        return self.mm("ANGLE_DEG")

    def world(self, xp: float, yp: float) -> tuple[float, float]:
        a = math.radians(self.deg())
        return (xp * math.cos(a) - yp * math.sin(a), xp * math.sin(a) + yp * math.cos(a))

    def x_jaw(self) -> float:
        semi_along = self.mm("ELLIPSE_MIN") * 0.5
        semi_steep = self.mm("ELLIPSE_MAJ") * 0.5
        off = self.mm("JAW_OFF")
        return -semi_along * math.sqrt(1.0 - (off / semi_steep) ** 2)

    def jaw_outer(self, upper: bool) -> tuple[float, float]:
        return self.world(self.x_jaw(), self.mm("JAW_OFF") if upper else -self.mm("JAW_OFF"))

    def jaw_inner(self, upper: bool) -> tuple[float, float]:
        return self.world(
            self.x_jaw() + self.mm("JAW_LEN"),
            self.mm("JAW_OFF") if upper else -self.mm("JAW_OFF"),
        )

    def throat(self) -> tuple[float, float]:
        off = self.mm("JAW_OFF")
        r15 = self.mm("R15")
        cx = (self.x_jaw() + self.mm("JAW_LEN")) - math.sqrt(r15 * r15 - off * off)
        return self.world(cx + r15, 0.0)

    def trim_opening(self) -> tuple[float, float]:
        return self.world(-24.73, 4.0)

    def ellipse_major(self) -> tuple[float, float]:
        return self.world(0.0, self.mm("ELLIPSE_MAJ") * 0.5)

    def ellipse_minor(self) -> tuple[float, float]:
        return self.world(self.mm("ELLIPSE_MIN") * 0.5, 0.0)

    def axis_17(self) -> tuple[float, float]:
        return self.world(40.0, 0.0)

    def ring_centre(self) -> tuple[float, float]:
        return (self.mm("CENTER"), 0.0)

    def handle_xy(self, upper: bool) -> tuple[tuple[float, float], tuple[float, float]]:
        half = self.mm("HANDLE_HALF")
        ring = self.mm("CENTER") - math.sqrt(max(0.0, (self.mm("RING_D") * 0.5) ** 2 - half ** 2))
        if upper:
            return (22.944, half), (ring, half)
        return (23.929, -half), (ring, -half)

    def ents(self, kind: str | None = None, construction: bool | None = None) -> list[dict]:
        found = []
        for entity in self._entities():
            if kind is not None and entity.get("type") != kind:
                continue
            flag = bool(entity.get("construction"))
            if construction is not None and flag != construction:
                continue
            found.append(entity)
        return found

    def constraint_types(self) -> list[str]:
        sk = self.refresh("sketch").get("sketch") or {}
        return [str(c.get("type", "")) for c in (sk.get("constraints") or [])]

    def _arm_sketch_tool(self, rail: str) -> None:
        self.click("rail:Select")
        self.d.wait_idle(frames=1)
        self.click(rail)
        self.d.wait_idle(frames=3)

    def _frame_uv(self, *points) -> None:
        self.frame_clickable(*points)

    def variant(self, label: str) -> None:
        self.refresh("controls", "status")
        chip = self.control(f"variant:{label}")
        if chip is None:
            for c in (self.st.get("controls") or []):
                if str(c.get("id", "")).startswith("variant:") and label.lower() in str(c.get("text", "")).lower():
                    chip = c
                    break
        if chip and chip.get("visible") is not False:
            self.click(str(chip.get("id") or f"variant:{label}"))
            self.d.wait_idle(frames=2)

    def draw_line(self, a, b, *, construction: bool = False) -> None:
        self._arm_sketch_tool("rail:Line")
        if construction:
            self.variant("Centerline")
        self._frame_uv(a, b)
        self.click(sketch=list(a))
        self.click(sketch=list(b))
        self.refresh("sketch", "status")

    def ellipse3(self, centre, major, minor) -> dict:
        self._arm_sketch_tool("rail:Ellipse")
        self._frame_uv(centre, major, minor)
        for pt in (centre, major, minor):
            self.click(sketch=list(pt))
            self.d.wait_idle(frames=2)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"ellipses": self.ents("ellipse"), "status": self.S()}

    def three_point_arc(self, p1, bulge, p3) -> dict:
        self._arm_sketch_tool("rail:Arc")
        self.variant("Three Point")
        self._frame_uv(p1, bulge, p3)
        for pt in (p1, bulge, p3):
            self.click(sketch=list(pt))
            self.d.wait_idle(frames=2)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"arcs": self.ents("arc"), "status": self.S()}

    def circle_at(self, centre, rim) -> dict:
        self._arm_sketch_tool("rail:Circle")
        self._frame_uv(centre, rim)
        self.click(sketch=list(centre))
        self.click(sketch=list(rim))
        self.refresh("sketch", "status")
        return {"circles": self.ents("circle"), "status": self.S()}

    def place_af_hex(self, centre, vertex) -> dict:
        self._arm_sketch_tool("rail:Polygon")
        self.variant("Across Flats")
        self._frame_uv(centre, vertex)
        self.click(sketch=list(centre))
        self.d.wait_idle(frames=2)
        self.click(sketch=list(vertex))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dims")
        return {"status": self.S(), "lines": self.profile_lines()}

    def place_vertex_hex(self, centre, vertex) -> dict:
        self._arm_sketch_tool("rail:Polygon")
        self.variant("Vertex")
        self._frame_uv(centre, vertex)
        self.click(sketch=list(centre))
        self.d.wait_idle(frames=2)
        self.click(sketch=list(vertex))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dims")
        return {"status": self.S(), "lines": self.profile_lines()}

    def trim_at(self, uv) -> str:
        self._arm_sketch_tool("rail:Trim")
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return self.S()

    def _shift_click_uv(self, uv) -> None:
        self.show_sketch_point(uv)
        self.d.key("shift", action="down")
        self.click(sketch=list(uv))
        self.d.key("shift", action="up")
        self.d.wait_idle(frames=1)

    def constrain(self, name: str, first, second) -> str:
        self.click("rail:Select")
        self._frame_uv(first, second)
        self.click(sketch=list(first))
        self._shift_click_uv(second)
        self.refresh("controls", "status")
        mark = self.mark()
        try:
            self.click_verb(name)
        except SxError:
            pass
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def mirror_entities(self, axis_uv, geom_uv, confirm_uv) -> str:
        # Select axis + geometry first. `_arm_sketch_tool` clicks Select and
        # would wipe that set; Mirror's viewport click only confirms.
        self.click("rail:Select")
        self._frame_uv(axis_uv, geom_uv, confirm_uv)
        self.click(sketch=list(axis_uv))
        self._shift_click_uv(geom_uv)
        self.click("rail:Mirror")
        self.d.wait_idle(frames=2)
        self.show_sketch_point(confirm_uv)
        mark = self.mark()
        self.click(sketch=list(confirm_uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def dim_two(self, a, b, value: str) -> dict:
        before = {str(d.get("text", "")) for d in self.dims()}
        self.click("rail:SmartDim")
        self._frame_uv(a, b)
        self.click(sketch=list(a))
        self.d.wait_idle(frames=2)
        self.click(sketch=list(b))
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        dim = fresh[-1] if fresh else (self.dims()[-1] if self.dims() else None)
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def dim_one(self, uv, value: str) -> dict:
        before = {str(d.get("text", "")) for d in self.dims()}
        self.click("rail:SmartDim")
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        dim = fresh[-1] if fresh else (self.dims()[-1] if self.dims() else None)
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def sketch_on_datum(self, name: str, view_key: str) -> dict:
        self.clear_faces()
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        return WalkChrome.sketch_on_datum(self, name, view_key)

    def contour_chips(self) -> list[dict]:
        self.refresh("controls")
        return [
            c for c in (self.st.get("controls") or [])
            if str(c.get("id", "")).startswith("contour:")
        ]

    def _contour_note(self, chip: dict) -> str:
        mark = self.mark()
        cid = str(chip.get("id", ""))
        if not cid:
            return ""
        self.click(cid)
        self.d.wait_idle(frames=1)
        self.click(cid)
        self.d.wait_idle(frames=1)
        return " | ".join(self.result_texts(mark)) or self.S()

    def set_contours(self, keep: set[str]) -> list[str]:
        notes = []
        for chip in self.contour_chips():
            note = self._contour_note(chip)
            notes.append(note)
            pressed = bool((self.control(str(chip.get("id", ""))) or {}).get("pressed")
                           or (self.control(str(chip.get("id", ""))) or {}).get("button_pressed"))
            want = False
            if "at (" in note:
                try:
                    xy = note.split("at (")[-1].split(")")[0]
                    x = float(xy.split(",")[0])
                    want = any(
                        (token == "c" and abs(x) < 40)
                        or (token == "ring" and abs(x - self.mm("CENTER")) < 20)
                        or (token == "handle" and 80 < x < 200)
                        for token in keep
                    )
                except ValueError:
                    pass
            if want != pressed:
                self.click(str(chip.get("id")))
                self.d.wait_idle(frames=1)
        return notes

    def uncheck_all_contours(self) -> None:
        for chip in self.contour_chips():
            node = self.control(str(chip.get("id", ""))) or chip
            if bool(node.get("pressed") or node.get("button_pressed")):
                self.click(str(chip.get("id")))
                self.d.wait_idle(frames=1)

    def try_extrude(self, distance: str, op: str = "New", end: str = "Midplane", apply: bool = True) -> dict:
        self._ensure_finish_bar()
        self.set_option("finish:Op", op)
        self.set_option("finish:End", end)
        shown = self.type_into("finish:Distance", distance)
        mark = self.mark()
        reply = self.click("finish:Extrude", frames=8) if apply else {}
        if apply:
            self.d.wait_idle(frames=8)
        results = self.result_texts(mark) if apply else []
        self.refresh("status", "sketch", "finish", "bodies", "features")
        return {
            "field": shown,
            "op": self.field("finish:Op"),
            "end": self.field("finish:End"),
            "reply": reply,
            "status": " | ".join(results) or str(reply.get("status", self.S())),
            "sketch": bool((self.st.get("sketch") or {}).get("active")),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def select_body(self) -> str:
        self.refresh("bodies", "selection")
        if str((self.st.get("selection") or {}).get("body") or ""):
            return self.S()
        bodies = self.st.get("bodies") or []
        if not bodies:
            return self.S()
        screen = bodies[0].get("screen")
        if screen:
            self.click(screen=screen)
            self.d.wait_idle(frames=2)
            self.refresh("selection", "status")
        return self.S()

    def arm_fillet(self, radius: str) -> dict:
        self.select_body()
        self.click("chip:Fillet")
        shown = self.type_into("finish:StripR", radius)
        self.d.key("enter")
        self.d.wait_idle(frames=2)
        self.refresh("status", "finish", "controls")
        return {"status": self.S(), "radius": shown or self.field("finish:StripR")}

    def pick_z_edges(self, xys, want_len: float) -> list[str]:
        ids = []
        for x, y in xys:
            edge = self._z_edge_at(float(x), float(y))
            if edge is None:
                continue
            length = float(edge.get("length") or 0.0)
            if length and abs(length - want_len) > 1.2:
                continue
            eid = str(edge.get("id", ""))
            if not eid or eid in ids:
                continue
            mark = self.mark()
            self.d.click(edge=eid, along=0.5)
            self.d.wait_idle(frames=2)
            ids.append(eid)
            _ = self.result_texts(mark)
        self.refresh("status", "selection")
        return ids

    def apply_fillet(self) -> str:
        mark = self.mark()
        focus = str(self.refresh("focus").get("focus", ""))
        if "LineEdit" in focus or "SpinBox" in focus:
            self.d.key("tab")
            self.d.wait_idle(frames=1)
        self.enter()
        self.d.wait_idle(frames=6)
        return " | ".join(self.result_texts(mark)) or self.S()

    def fillet_all(self, radius: str) -> str:
        self.select_body()
        self.esc()
        self.select_body()
        self.click("chip:Fillet")
        self.type_into("finish:StripR", radius)
        return self.apply_fillet()

    def convert_at(self, model) -> dict:
        self.click("rail:Convert")
        self.d.wait_idle(frames=2)
        mark = self.mark()
        reply = self.click(model=list(model))
        self.refresh("sketch", "status")
        return {
            "status": " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S())),
            "ents": self.ents(),
        }

    def offset_distance(self, value: str) -> str:
        return self.type_into("offset:Distance", value)

    def offset_reverse(self, on: bool = True) -> None:
        node = self.control("offset:Reverse") or {}
        pressed = bool(node.get("pressed") or node.get("button_pressed"))
        if pressed != on:
            self.click("offset:Reverse")
            self.refresh("controls", "status")

    def offset_click(self, uv) -> str:
        mark = self.mark()
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def face_sketch_handle_top(self) -> dict:
        self.select_body()
        z_top = self.mm("HANDLE_T") * 0.5
        picked = self.select_face([0, 0, 1], plane=z_top)
        self.click("chip:Sketch")
        self.d.wait_idle(frames=4)
        self.refresh("sketch", "status")
        sk = self.st.get("sketch") or {}
        origin = (sk.get("plane") or {}).get("origin") or [0, 0, 0]
        on_top = abs(float(origin[2]) - z_top) <= 0.4 if origin else False
        return {
            "picked": picked,
            "active": bool(sk.get("active")),
            "on_handle": on_top,
            "plane": sk.get("plane") or {},
            "status": self.S(),
        }

    def arm_feature_mirror(self) -> dict:
        self.select_body()
        self._show_timeline()
        mark = self.mark()
        self.click("mirror:Features")
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status")
        return {"status": " | ".join(self.result_texts(mark)) or self.S()}

    def pick_origin_front(self) -> dict:
        mark = self.mark()
        self.click(datum="Front")
        self.d.wait_idle(frames=3)
        self.refresh("status", "controls")
        return {"status": " | ".join(self.result_texts(mark)) or self.S()}

    def last_of_type(self, kind: str) -> str:
        names = []
        for feat in self.refresh("features").get("features") or []:
            if str(feat.get("type", "")) == kind:
                names.append(str(feat.get("name", "")))
        return names[-1] if names else ""

    def shift_click_timeline(self, names: list[str]) -> None:
        self._show_timeline()
        if not names:
            return
        self.click(f"timeline:row:{names[0]}")
        self.d.wait_idle(frames=1)
        if len(names) == 1:
            return
        self.d.key("shift", action="down")
        for name in names[1:]:
            self.click(f"timeline:row:{name}")
            self.d.wait_idle(frames=1)
        self.d.key("shift", action="up")
        self.refresh("timeline", "status")

    def mirror_ok(self) -> dict:
        for _ in range(16):
            if self.control("mirror:Ok"):
                break
            self.d.wait_idle(frames=2)
            self.refresh("controls")
        mark = self.mark()
        self.click("mirror:Ok")
        self.d.wait_idle(frames=10)
        self.refresh("bodies", "status", "features", "timeline")
        return {
            "status": " | ".join(self.result_texts(mark)) or self.S(),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def stage_report(self, stage: str) -> dict:
        cached = self.ctx.get(f"report:{stage}")
        if isinstance(cached, dict):
            return cached
        filename = STAGE_FILE[stage]
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            named = ", ".join(str(b.get("name", "")) for b in bodies) or "(none)"
            report = {
                "exported": False,
                "code": 1,
                "text": f"runner-gap: bodies={named}",
                "check_ok": False,
            }
            self.ctx[f"report:{stage}"] = report
            return report
        path = self.export_3mf(filename)
        code, text = self.checker(stage, filename)
        report = {
            "exported": Path(path).is_file(),
            "code": code,
            "text": text,
            "check_ok": code == 0 and "FAIL" not in text,
        }
        self.ctx[f"report:{stage}"] = report
        return report

    def z_extent(self) -> tuple[float, float] | None:
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            return None
        mn = bodies[0].get("min") or [0, 0, 0]
        mx = bodies[0].get("max") or [0, 0, 0]
        return float(mn[2]), float(mx[2])
