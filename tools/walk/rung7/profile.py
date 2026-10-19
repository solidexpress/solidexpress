# Front C profile: ellipse, jaws, trim, hex, handle, coincident, weld.
# WalkUI07 mixes this in; click sequences are unchanged.

from __future__ import annotations

import math

from sxdrive import SxError
from walk.rung7.ui07 import WeldPolicy


class ProfileGestures:

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

    def _profile_endpoints(self) -> list[tuple[float, float]]:
        pts: list[tuple[float, float]] = []
        for entity in self.ents():
            if entity.get("construction"):
                continue
            kind = str(entity.get("type") or "")
            if kind == "line":
                pts.append(self._pt(entity.get("start") or [0, 0]))
                pts.append(self._pt(entity.get("end") or [0, 0]))
            elif kind in ("arc", "elliptical_arc"):
                pts.append(self._pt(entity.get("start") or [0, 0]))
                pts.append(self._pt(entity.get("end") or [0, 0]))
        return pts

    def weld_open_profile(self, tol: float = WeldPolicy.PAIR_MM) -> int:
        """Coincident dangling endpoints that sit on top of each other.

        Concurrent walks sometimes leave the jaw/ellipse vertex unwelded
        (N2: open profile at (−24.9, 5.4)) so Midplane extrude makes no body.
        """
        pts = self._profile_endpoints()
        opens: list[tuple[float, float]] = []
        for i, a in enumerate(pts):
            n = sum(1 for b in pts if math.hypot(a[0] - b[0], a[1] - b[1]) <= WeldPolicy.DUP_MM)
            if n == 1:
                opens.append(a)
        welded = 0
        used = [False] * len(opens)
        for i, a in enumerate(opens):
            if used[i]:
                continue
            best_j, best_d = -1, tol
            for j, b in enumerate(opens):
                if i == j or used[j]:
                    continue
                dist = math.hypot(a[0] - b[0], a[1] - b[1])
                if 1e-4 < dist <= best_d:
                    best_j, best_d = j, dist
            if best_j < 0:
                continue
            self.constrain("Coincident", a, opens[best_j])
            used[i] = used[best_j] = True
            welded += 1
        for upper in (True, False):
            jaw = self.jaw_outer(upper)
            near = self.nearest_profile_uv(jaw)
            if math.hypot(jaw[0] - near[0], jaw[1] - near[1]) <= WeldPolicy.JAW_NEAR_MM:
                self.constrain("Coincident", jaw, near)
                welded += 1
        leftover: list[tuple[float, float]] = []
        pts = self._profile_endpoints()
        for a in pts:
            n = sum(1 for b in pts if math.hypot(a[0] - b[0], a[1] - b[1]) <= WeldPolicy.DUP_MM)
            if n == 1:
                leftover.append(a)
        hi = self.nearest_profile_uv(self.jaw_outer(True))
        lo = self.nearest_profile_uv(self.jaw_outer(False))
        self.coincident_on_curve(hi, self.jaw_tip_uv(True))
        self.coincident_on_curve(lo, self.jaw_tip_uv(False))
        if welded:
            self.d.wait_idle(frames=6)
            self.refresh("sketch", "status")
        return welded

    def coincident_on_curve(self, point, on_curve) -> str:
        self.click("rail:Select")
        was = self._set_snap(True)
        self._frame_uv(point, on_curve)
        self.click(sketch=list(point))
        self.d.key("shift", action="down")
        self.click(sketch=list(on_curve))
        self.d.key("shift", action="up")
        self._set_snap(was)
        self.d.wait_idle(frames=2)
        mark = self.mark()
        try:
            self.click_verb("Coincident")
        except SxError:
            pass
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

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
