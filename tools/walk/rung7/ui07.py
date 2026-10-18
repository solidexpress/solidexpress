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

    def ellipse_axis_uv(self, which: str):
        ells = self.ents("ellipse") or self.ents("elliptical_arc")
        if ells:
            key = "major_start" if which == "major" else "minor_start"
            pt = ells[0].get(key)
            if pt:
                return self._pt(pt)
        return self.ellipse_major() if which == "major" else self.ellipse_minor()

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

    def _set_snap(self, on: bool) -> bool:
        btn = self.control("rail:Snap")
        if not btn:
            return False
        pressed = bool(btn.get("pressed"))
        if pressed != on:
            self.click("rail:Snap")
            self.d.wait_idle(frames=1)
        return pressed

    def _frame_uv(self, *points) -> None:
        self.frame_clickable(*points)

    def variant(self, label: str) -> None:
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status")
        want = label.lower().replace("_", " ")
        chip = self.control(f"variant:{label}")
        if chip is None:
            for c in (self.st.get("controls") or []):
                if not str(c.get("id", "")).startswith("variant:"):
                    continue
                text = str(c.get("text", "")).lower().replace("_", " ")
                cid = str(c.get("id", "")).lower().replace("_", " ")
                if want in text or want in cid:
                    chip = c
                    break
        if chip and chip.get("visible") is not False:
            self.click(str(chip.get("id") or f"variant:{label}"))
            self.d.wait_idle(frames=3)

    def draw_line(self, a, b, *, construction: bool = False) -> None:
        self._arm_sketch_tool("rail:Line")
        if construction:
            self.variant("Centerline")
        self._frame_uv(a, b)
        self.click(sketch=list(a))
        self.click(sketch=list(b))
        self.refresh("sketch", "status")

    def _click_uv(self, uv, *, shift: bool = False, frame: bool = True) -> None:
        if frame:
            self._frame_uv(uv)
        self.show_sketch_point(uv)
        if shift:
            self._shift_click_uv(uv)
        else:
            self._click_sketch_geom(uv)
        self.d.wait_idle(frames=1)

    def _click_sketch_geom(self, uv) -> dict:
        """Click sketch UV, skipping dimension labels that sit on endpoints."""
        last = {}
        for off in (
            [0, 0], [3, 0], [-3, 0], [0, 3], [0, -3],
            [0, 8], [0, -8], [8, 0], [-8, 0],
        ):
            last = self.click(sketch=list(uv), offset=list(off))
            disp = str(last.get("disposition", ""))
            if "dim-label" not in disp:
                return last
        return last

    def nearest_profile_uv(self, want) -> tuple:
        wx, wy = float(want[0]), float(want[1])
        best = (wx, wy)
        best_d = 12.0
        for line in self.profile_lines():
            for key in ("start", "end"):
                pt = self._pt(line.get(key) or [0, 0])
                d = ((pt[0] - wx) ** 2 + (pt[1] - wy) ** 2) ** 0.5
                if d < best_d:
                    best_d = d
                    best = pt
        return best

    def select_pair(self, first, second) -> None:
        """Select two entities with a tight frame on each pick."""
        self.click("rail:Select")
        self._click_uv(first)
        self._click_uv(second, shift=True)
        self.refresh("controls", "status")

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
        # Frame before arming Arc so pan keys are not strokes of the tool.
        self._frame_uv(p1, bulge, p3)
        self._arm_sketch_tool("rail:Arc")
        self.variant("Three Point")
        self.d.wait_idle(frames=2)
        was = self._set_snap(False)
        for pt in (p1, bulge, p3):
            self._click_sketch_geom(pt)
            self.d.wait_idle(frames=2)
        self._set_snap(was)
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
        # Across-flats pointer is scaled by √3 onto the vertex ring, so the
        # click sits on a vertex (AF/√3) and the overlay reads AF.
        self._arm_sketch_tool("rail:Polygon")
        self.variant("Across Flats")
        self._frame_uv(centre, vertex)
        was = self._set_snap(False)
        self.click(sketch=list(centre))
        self.d.wait_idle(frames=2)
        self.click(sketch=list(vertex))
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dims")
        return {"status": self.S(), "lines": self.profile_lines()}

    def place_vertex_hex(self, centre, vertex) -> dict:
        self._arm_sketch_tool("rail:Polygon")
        self.variant("Vertex")
        self._frame_uv(centre, vertex)
        was = self._set_snap(False)
        self.click(sketch=list(centre))
        self.d.wait_idle(frames=2)
        self.click(sketch=list(vertex))
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dims")
        return {"status": self.S(), "lines": self.profile_lines()}

    def trim_at(self, uv) -> str:
        self._frame_uv(uv)
        self.click("rail:Trim")
        was = self._set_snap(False)
        self.show_sketch_point(uv)
        self.d.hover(sketch=list(uv))
        self.click(sketch=list(uv))
        self._set_snap(was)
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
        self.select_pair(first, second)
        mark = self.mark()
        try:
            self.click_verb(name)
        except SxError:
            pass
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def mirror_entities(self, axis_uv, geom_uv, confirm_uv) -> str:
        # Axis first (construction wins in mirror_selected), then geometry.
        # Confirm in empty space — a dim callout must not eat the Mirror click.
        self.select_pair(axis_uv, geom_uv)
        self.click("rail:Mirror")
        self.d.wait_idle(frames=2)
        mark = self.mark()
        self.show_sketch_point(confirm_uv)
        self.click(sketch=list(confirm_uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def _commit_fresh_dim(self, before: set[str], value: str) -> dict:
        self.d.wait_idle(frames=3)
        self.refresh("dims", "controls", "focus")
        if self._dim_editor_open():
            self.d.key("ctrl+a")
            self._type_dim_editor(value)
            self.enter()
            self.refresh("dims", "status")
            return {"texts": self.dim_texts(), "status": self.S()}
        fresh = [
            d for d in self.dims()
            if str(d.get("text", "")) not in before and "°" not in str(d.get("text", ""))
        ]
        if not fresh:
            fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        dim = fresh[-1] if fresh else None
        if dim is not None:
            self.fit_sketch()
            opened = self.open_label(dim)
            if opened:
                self.d.key("ctrl+a")
                self._type_dim_editor(value)
                self.enter()
            else:
                self.edit_dim(dim, value)
        self.refresh("dims", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def dim_two(self, a, b, value: str) -> dict:
        before = {str(d.get("text", "")) for d in self.dims()}
        self.select_pair(a, b)
        self.click("rail:SmartDim")
        self.d.wait_idle(frames=2)
        self._click_uv(a)
        return self._commit_fresh_dim(before, value)

    def dim_one(self, uv, value: str) -> dict:
        before = {str(d.get("text", "")) for d in self.dims()}
        self.clear_sketch_selection()
        self._frame_uv(uv)
        self.click("rail:SmartDim")
        was = self._set_snap(False)
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self._set_snap(was)
        return self._commit_fresh_dim(before, value)

    def dim_diameter(self, rim, value: str) -> dict:
        before = {str(d.get("text", "")) for d in self.dims()}
        self.clear_sketch_selection()
        self._frame_uv(rim)
        self.click("rail:SmartDim")
        was = self._set_snap(False)
        self.show_sketch_point(rim)
        self.click(sketch=list(rim))
        self._set_snap(was)
        return self._commit_fresh_dim(before, value)

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

    def _parse_contour_note(self, note: str) -> tuple[float, float, float, float]:
        """Return (cx, cy, width, height) from a contour status sentence."""
        cx = cy = width = height = 0.0
        if "at (" in note:
            try:
                xy = note.split("at (")[-1].split(")")[0]
                parts = xy.split(",")
                cx = float(parts[0])
                cy = float(parts[1])
            except (ValueError, IndexError):
                pass
        if "—" in note and "×" in note:
            try:
                span = note.split("—")[1]
                wh = span.split("mm")[0]
                width = float(wh.split("×")[0].strip())
                height = float(wh.split("×")[1].strip())
            except (ValueError, IndexError):
                pass
        return cx, cy, width, height

    def _contour_wanted(self, keep: set[str], note: str) -> bool:
        cx, _cy, width, height = self._parse_contour_note(note)
        long_side = max(width, height)
        for token in keep:
            if token == "c" and abs(cx) < 50 and 40.0 < long_side < 80:
                return True
            if token == "ring" and abs(cx - self.mm("CENTER")) < 25 and long_side >= 30 and min(width, height) >= 20:
                return True
            if token == "handle" and long_side > 80:
                return True
            if token == "recess" and 80.0 < long_side < 200.0 and 6.0 <= min(width, height) <= 16.0:
                return True
        return False

    def set_contours(self, keep: set[str]) -> list[str]:
        # Probe-toggle leaves chips unknown. Uncheck all, click each once to
        # read the bbox, keep only the wanted set, then re-assert pressed.
        self._ensure_finish_bar()
        self.refresh("controls")
        self.uncheck_all_contours()
        self.refresh("controls")
        mapping = []
        notes = []
        for chip in self.contour_chips():
            cid = str(chip.get("id", ""))
            if not cid:
                continue
            mark = self.mark()
            self.click(cid)
            self.d.wait_idle(frames=1)
            note = " | ".join(self.result_texts(mark)) or self.S()
            want = self._contour_wanted(keep, note)
            notes.append(note)
            mapping.append((cid, want))
            if not want:
                self.click(cid)
                self.d.wait_idle(frames=1)
        for _pass in range(2):
            self.refresh("controls")
            for cid, want in mapping:
                node = self.control(cid) or {}
                pressed = bool(node.get("pressed") or node.get("button_pressed"))
                if want != pressed:
                    self.click(cid)
                    self.d.wait_idle(frames=1)
        self.refresh("controls")
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
        self.d.key("7")
        self.d.wait_idle(frames=4)
        self.click("chip:Fillet")
        shown = self.type_into("finish:StripR", radius)
        self.d.key("enter")
        self.d.wait_idle(frames=2)
        self.refresh("status", "finish", "controls")
        return {"status": self.S(), "radius": shown or self.field("finish:StripR")}

    def _z_edge_near(self, x: float, y: float, want_len: float, max_d: float = 8.0) -> dict | None:
        best = None
        best_d = max_d
        for edge in self.edges():
            direction = edge.get("dir") or [0, 0, 0]
            if abs(float(direction[2])) < 0.9:
                continue
            length = float(edge.get("length") or 0.0)
            if length and abs(length - want_len) > 1.2:
                continue
            centre = self._edge_centre(edge)
            dist = ((centre[0] - x) ** 2 + (centre[1] - y) ** 2) ** 0.5
            if dist < best_d:
                best, best_d = edge, dist
        return best

    def pick_z_edges(self, xys, want_len: float) -> list[str]:
        ids = []
        for x, y in xys:
            edge = self._z_edge_near(float(x), float(y), float(want_len))
            if edge is None:
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
            try:
                self.d.click(edge=eid, along=0.5)
            except SxError:
                try:
                    self.click(model=[float(x), float(y), 0.0])
                except SxError:
                    continue
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

    def _ent_uv(self, entity: dict) -> tuple[float, float]:
        kind = str(entity.get("type") or "")
        if kind == "line":
            a, b = self._pt(entity.get("start") or [0, 0]), self._pt(entity.get("end") or [0, 0])
            return ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        if kind == "arc":
            c = self._pt(entity.get("center") or [0, 0])
            r = float(entity.get("radius") or 0.0)
            sa = float(entity.get("start_angle") or 0.0)
            ea = float(entity.get("end_angle") or 0.0)
            mid = 0.5 * (sa + ea)
            return (c[0] + r * math.cos(mid), c[1] + r * math.sin(mid))
        return (0.0, 0.0)

    def select_converted(self) -> int:
        converted = [e for e in self.ents() if e.get("external")]
        if not converted:
            converted = [e for e in self.ents() if e.get("type") in ("line", "arc")]
        if not converted:
            return 0
        self.click("rail:Select")
        self._click_uv(self._ent_uv(converted[0]))
        for entity in converted[1:]:
            self._click_uv(self._ent_uv(entity), shift=True)
        self.refresh("selection", "status")
        return len(converted)

    def convert_face_outline(self, z: float) -> list[str]:
        """Convert handle sides (|y|≈10) and neck-zone curves, not C-head crumbs."""
        notes = []
        self.refresh("edges")
        seen = set()
        for edge in self.edges():
            mid = edge.get("mid") or list(self._edge_centre(edge))
            if len(mid) < 3:
                continue
            if abs(float(mid[2]) - z) > 0.6:
                continue
            x, y = float(mid[0]), float(mid[1])
            length = float(edge.get("length") or 0.0)
            if math.hypot(x - self.mm("CENTER"), y) < 18.0:
                continue
            handle_side = 8.0 <= abs(y) <= 12.5 and length > 40.0 and 30.0 < x < 220.0
            neck = (x < 55.0 or 205.0 < x < 235.0) and abs(y) < 36.0 and length > 8.0
            if not (handle_side or neck):
                continue
            eid = str(edge.get("id") or "")
            if eid in seen:
                continue
            seen.add(eid)
            notes.append(self.convert_at((x, y, float(mid[2])))["status"])
        return notes

    def prune_stray_convert(self) -> int:
        """Drop short interior lines (the x=43 chain-breaker) before Offset."""
        removed = 0
        self.click("rail:Select")
        for entity in list(self.ents("line")):
            a, b = self._pt(entity.get("start") or [0, 0]), self._pt(entity.get("end") or [0, 0])
            mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
            length = math.hypot(a[0] - b[0], a[1] - b[1])
            if length < 50.0 and abs(mid[1]) < 8.5:
                self._click_uv(mid)
                self.d.key("delete")
                self.d.wait_idle(frames=1)
                removed += 1
        self.refresh("sketch", "status")
        return removed

    def _twelve_point_uvs(self) -> list[tuple[float, float]]:
        c = self.ring_centre()
        af = self.mm("HEX_AF")
        outer = af / math.sqrt(3.0)
        inner = (af * 0.5) / math.cos(math.radians(15.0))
        pts: list[tuple[float, float]] = []
        for k in range(24):
            ang = math.radians(float(k) * 15.0)
            radius = outer if (k % 2) == 0 else inner
            pts.append((c[0] + math.cos(ang) * radius, c[1] + math.sin(ang) * radius))
        return pts

    def draw_twelve_point_star(self) -> int:
        """Named Line: 24-gon star (union of two AF hexes). Opposite winding
        from add_twelve_point is a sequential close; a Cut does not care."""
        pts = self._twelve_point_uvs()
        c = self.ring_centre()
        self._frame_uv((c[0] - 22.0, c[1] - 22.0), (c[0] + 22.0, c[1] + 22.0))
        was = self._set_snap(False)
        before = len(self.profile_lines())
        for i in range(24):
            a, b = pts[i], pts[(i + 1) % 24]
            self._arm_sketch_tool("rail:Line")
            self.show_sketch_point(a)
            self.click(sketch=list(a))
            self.show_sketch_point(b)
            self.click(sketch=list(b))
        self.click("rail:Select")
        self._set_snap(was)
        self.refresh("sketch", "status")
        return len(self.profile_lines()) - before

    def ensure_twelve_point_bore(self) -> dict:
        """Front sketch + Line star + Cut Midplane 10. Polygon Power Trim of
        two hexes leaves leftover triangles, so the Ø33 disc stays solid."""
        bodies = list(self.refresh("bodies").get("bodies") or [])
        vol = float(bodies[0].get("volume") or 0.0) if bodies else 0.0
        if vol and vol <= self.mm("V_BOSS") * 1.01:
            return {"skipped": True, "status": f"volume {vol:.1f} already at boss"}
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        started = self.sketch_on_datum("Front", "1")
        added = 0
        if started.get("active"):
            added = self.draw_twelve_point_star()
        made = self.try_extrude(f"{self.mm('HEAD_T'):g}", "Cut", "Midplane")
        if made.get("sketch"):
            self.exit_sketch()
        self.refresh("bodies", "features", "status")
        return {
            "started": started,
            "added": added,
            "cut": made,
            "status": made.get("status", self.S()),
            "volume": (self.refresh("bodies").get("bodies") or [{}])[0].get("volume"),
        }

    def _handle_top_face(self) -> dict | None:
        z_top = self.mm("HANDLE_T") * 0.5
        best = None
        best_score = -1.0e9
        for face in list(self.refresh("faces").get("faces") or []):
            normal = face.get("normal") or [0.0, 0.0, 0.0]
            if float(normal[2]) < 0.95:
                continue
            plane = float(face.get("plane") or 0.0)
            if abs(plane - z_top) > 0.5:
                continue
            area = float(face.get("area") or 0.0)
            if area < 200.0:
                continue
            centre = face.get("centre") or [0.0, 0.0, 0.0]
            score = area - abs(float(centre[0]) - 120.0) * 2.0 - abs(float(centre[1])) * 4.0
            if score > best_score:
                best, best_score = face, score
        return best

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
        self.d.key("3")
        self.d.wait_idle(frames=4)
        z_top = self.mm("HANDLE_T") * 0.5
        face = self._handle_top_face()
        picked = {"face": "", "status": self.S(), "record": {}}
        if face and face.get("id"):
            self.click(face=str(face["id"]))
            self.d.wait_idle(frames=2)
            self.refresh("selection", "status", "faces")
            sel = self.st.get("selection") or {}
            face_id = str(sel.get("face") or face.get("id") or "")
            record = self._face_record(face_id) or face
            picked = {
                "face": face_id,
                "status": self.S(),
                "normal": record.get("normal"),
                "plane": record.get("plane"),
                "record": record,
            }
        if float((picked.get("record") or {}).get("area") or 0.0) < 1000.0:
            self.click(model=[120.0, 0.0, z_top])
            self.d.wait_idle(frames=2)
            self.refresh("selection", "faces", "status")
            sel = self.st.get("selection") or {}
            face_id = str(sel.get("face") or "")
            record = self._face_record(face_id) or {}
            if float(record.get("area") or 0.0) > float((picked.get("record") or {}).get("area") or 0.0):
                picked = {
                    "face": face_id,
                    "status": self.S(),
                    "normal": record.get("normal"),
                    "plane": record.get("plane"),
                    "record": record,
                }
        self.click("chip:Sketch")
        self.d.wait_idle(frames=4)
        self.refresh("sketch", "status")
        sk = self.st.get("sketch") or {}
        origin = (sk.get("plane") or {}).get("origin") or [0, 0, 0]
        on_top = abs(float(origin[2]) - z_top) <= 0.4 if origin else False
        area = float((picked.get("record") or {}).get("area") or 0.0)
        return {
            "picked": picked,
            "active": bool(sk.get("active")),
            "on_handle": on_top and area >= 1000.0,
            "area": area,
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
