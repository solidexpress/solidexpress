"""Rung-6 gestures: Front profile, temp-axis path, Right ellipse, fuse sweep, draft cut."""
from __future__ import annotations

import math
from pathlib import Path

from sxdrive import SxError
from walk.chrome import WalkChrome

PINNED_NEW = "New — empty part, Top plane (XY). View ▸ Timeline to edit features"

STAGE_FILE = {
    "revolve": "revolve.3mf",
    "sweep": "sweep.3mf",
    "final": "final.3mf",
}

# Locked rim (plan / Rung06Part). Checker clips y ≥ 0 at x = 108.998.
R60_TAN = (97.861, 20.517)
R12_BULGE = (111.999, 8.125)
R12_CLIP = (108.998, 0.0)
BASE_END = (90.0, 0.0)


class WalkUI06(WalkChrome):
    _RUNG = 6
    _EMPTY_SKETCH = (-15.0, 40.0)
    _INTENDED = (
        "Dimension must be a positive number",
        "Select a profile sketch and a path sketch",
        "Draft angle too large",
        "nothing added",
        "Tangent Arc: radius must be positive",
        "Horizontal needs two endpoints",
    )

    def part(self) -> dict:
        return WalkChrome.part(self, "check_rung06.py")

    def mm(self, key: str) -> float:
        return float(self.part()["PART"][key])

    def ents(self, kind: str | None = None) -> list[dict]:
        found = []
        for entity in self._entities():
            if kind is not None and entity.get("type") != kind:
                continue
            found.append(entity)
        return found

    def _frame_uv(self, *points) -> None:
        """Fit once so a multi-click tool is not reset by F between clicks."""
        for pt in points:
            self.show_sketch_point(pt)

    def _arm_sketch_tool(self, rail: str) -> None:
        self.click("rail:Select")
        self.d.wait_idle(frames=1)
        self.click(rail)
        self.d.wait_idle(frames=3)

    def _zoom_uv(self, uv, notches: int = 8) -> None:
        self.show_sketch_point(uv)
        centre = self._view_centre()
        for _ in range(notches):
            self.d.wheel(notches=1, screen=centre)
            self.d.wait_idle(frames=1)

    def _set_snap(self, on: bool) -> bool:
        btn = self.control("rail:Snap")
        if not btn:
            return False
        pressed = bool(btn.get("pressed"))
        if pressed != on:
            self.click("rail:Snap")
            self.d.wait_idle(frames=1)
        return pressed

    def _nudge_toward(self, start, end, mm: float = 0.8) -> list[float]:
        sx, sy = float(start[0]), float(start[1])
        ex, ey = float(end[0]), float(end[1])
        dx, dy = ex - sx, ey - sy
        length = (dx * dx + dy * dy) ** 0.5 or 1.0
        return [sx + dx / length * mm, sy + dy / length * mm]

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

    def draw_line(self, a, b) -> None:
        self._arm_sketch_tool("rail:Line")
        self._frame_uv(a, b)
        self.click(sketch=list(a))
        self.click(sketch=list(b))
        self.refresh("sketch", "status")

    def nearest_line(self, a, b) -> dict | None:
        want_a, want_b = list(a), list(b)
        best = None
        best_d = 8.0
        for line in self.profile_lines():
            sa, sb = self._pt(line["start"]), self._pt(line["end"])
            d = min(
                self._pair_d(sa, sb, want_a, want_b),
                self._pair_d(sa, sb, want_b, want_a),
            )
            if d < best_d:
                best_d = d
                best = line
        return best

    def _pair_d(self, sa, sb, a, b) -> float:
        return ((sa[0] - a[0]) ** 2 + (sa[1] - a[1]) ** 2) ** 0.5 + (
            (sb[0] - b[0]) ** 2 + (sb[1] - b[1]) ** 2
        ) ** 0.5

    def nearest_arc(self, centre=None, radius=None) -> dict | None:
        best = None
        best_d = 1e9
        for arc in self.ents("arc"):
            c = self._pt(arc.get("center") or [0, 0])
            r = float(arc.get("radius") or 0)
            d = 0.0
            if centre is not None:
                d += ((c[0] - centre[0]) ** 2 + (c[1] - centre[1]) ** 2) ** 0.5
            if radius is not None:
                d += abs(r - float(radius))
            if d < best_d:
                best_d = d
                best = arc
        return best

    def variant(self, label: str) -> None:
        self.refresh("controls", "status")
        chips = [
            c for c in (self.st.get("controls") or [])
            if str(c.get("id", "")).startswith("variant:")
        ]
        chip = self.control(f"variant:{label}")
        if chip is None:
            for c in chips:
                text = str(c.get("text", ""))
                if text.lower() == label.lower() or label.lower() in text.lower():
                    chip = c
                    break
        if chip and chip.get("visible") is not False:
            cid = str(chip.get("id") or f"variant:{label}")
            self.click(cid)
            self.d.wait_idle(frames=2)
            return

    def tangent_arc(self, start, end) -> dict:
        self._frame_uv(start, end)
        self._arm_sketch_tool("rail:Arc")
        self.variant("Tangent")
        self.d.wait_idle(frames=2)
        host = self._nudge_toward(start, end, 1.2)
        was = self._set_snap(False)
        self._click_sketch_geom(host)
        self.d.wait_idle(frames=2)
        self.click(sketch=list(end))
        self.d.wait_idle(frames=3)
        self._set_snap(was)
        self.refresh("sketch", "status")
        return {"arcs": self.ents("arc"), "status": self.S()}

    def three_point_arc(self, p1, bulge, p3) -> dict:
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

    def connecting_rim(self, start, end=(90.0, 0.0), *, snap_end: bool = True) -> dict:
        """3-point from the R60 free end to `end`.

        Fit once, then arm. Snap on at the R60 vertex so the loop joins; snap
        off at the outer bulge so the click does not stick to R60 or the base.
        `_click_sketch_geom` skips dim labels that sit on the R60 end.
        Bulge (112, 8) is the locked R12.50 rightmost (t0350 / pass-bar).
        The y ≥ 0 clip at (108.998, 0) is not an existing vertex — snap_end
        must be false or the click sticks to the 90 mm end.
        """
        bulge = R12_BULGE
        self.fit_sketch()
        self.d.wait_idle(frames=2)
        self._arm_sketch_tool("rail:Arc")
        self.variant("Three Point")
        self.d.wait_idle(frames=2)
        was = self._set_snap(True)
        self._click_sketch_geom(start)
        self.d.wait_idle(frames=2)
        self._set_snap(False)
        self.click(sketch=list(bulge))
        self.d.wait_idle(frames=2)
        if snap_end:
            self._set_snap(True)
            self._click_sketch_geom(end)
        else:
            self._set_snap(False)
            self.click(sketch=list(end))
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"arcs": self.ents("arc"), "status": self.S()}

    def prepare_lower_stem(self) -> None:
        """Replace the ~150 leftover with a 50 mm stem so R60 starts at y=80.

        Smart Dim on that remnant also emits angle-to-horizontal, which adds a
        construction line through the mid and a 90° label. Redrawing avoids both.
        """
        stems = self.hanging_stems()
        if not stems:
            return
        lower = stems[-1]
        length = self.line_length(lower) or 0.0
        if abs(length - 50.0) <= 1.0:
            return
        sa, sb = self._pt(lower["start"]), self._pt(lower["end"])
        tip = sa if sa[1] < sb[1] else sb
        self.click("rail:Select")
        self.show_sketch_point(tip)
        was = self._set_snap(False)
        self.click(sketch=list(tip), offset=[0, -4])
        self._set_snap(was)
        self.d.key("delete")
        self.d.wait_idle(frames=2)
        was = self._set_snap(True)
        self.draw_line((30.0, 130.0), (30.0, 80.0))
        self._set_snap(was)
        if self.nearest_line((30.0, 210.0), (30.0, 170.0)) is None:
            self.draw_line((30.0, 210.0), (30.0, 170.0))
        for stem in self.hanging_stems():
            self.make_vertical(stem)

    def join_rim_ends(self, r60_end, base=(90.0, 0.0)) -> None:
        known = (10.0, 20.0, 60.0)
        rim = [
            a for a in self.ents("arc")
            if min(abs(float(a.get("radius") or 0) - k) for k in known) > 3.0
        ]
        if not rim:
            return
        arc = rim[-1]
        for key in ("start", "end"):
            p = self._pt(arc.get(key) or [0, 0])
            if abs(p[0] - float(base[0])) <= 8.0 and abs(p[1] - float(base[1])) <= 8.0:
                self.coincident_points(p, base)
            if ((p[0] - float(r60_end[0])) ** 2 + (p[1] - float(r60_end[1])) ** 2) ** 0.5 <= 8.0:
                self.coincident_points(p, r60_end)

    def coincident_points(self, a, b) -> None:
        self.click("rail:Select")
        was = self._set_snap(True)
        self.click(sketch=list(a))
        self.d.key("shift", action="down")
        self.click(sketch=list(b))
        self.d.key("shift", action="up")
        self._set_snap(was)
        self.d.wait_idle(frames=2)
        try:
            self.click_verb("Coincident")
        except SxError:
            pass
        self.d.wait_idle(frames=2)

    def purge_stray_arcs(self) -> None:
        """Drop micro-arcs that are not R10/R20/R60 and do not hit (90, 0)."""
        for arc in list(self.ents("arc")):
            r = float(arc.get("radius") or 0)
            if any(abs(r - k) <= 2.5 for k in (10.0, 20.0, 60.0, 12.5)):
                continue
            if self.endpoint_near(arc, (90.0, 0.0), tol=2.0):
                continue
            a = self._pt(arc.get("start") or [0, 0])
            b = self._pt(arc.get("end") or [0, 0])
            chord = ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5
            if chord < 8.0:
                self.delete_arc(arc)

    def dim_height_from_base(self, uv, value: str) -> dict:
        """Vertical dim: R60 centre (or `uv`) to the 90 mm baseline.

        Smart Dim BETWEEN an arc centre and a line is point-line distance, not
        the 90° angle you get from two line picks.
        """
        arc = self.nearest_arc(None, 60)
        if arc:
            uv = self._pt(arc.get("center") or uv)
        before = {str(d.get("text", "")) for d in self.dims()}
        self.clear_sketch_selection()
        self.fit_sketch()
        self.click("rail:SmartDim")
        was = self._set_snap(False)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=2)
        self.click(sketch=[65.0, 0.0])
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        fresh = [
            d for d in self.dims()
            if str(d.get("text", "")) not in before and "°" not in str(d.get("text", ""))
        ]
        dim = fresh[-1] if fresh else None
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def delete_angle_dims(self) -> None:
        for dim in list(self.dims()):
            if "°" not in str(dim.get("text", "")):
                continue
            try:
                rect = dim.get("rect") or dim.get("hit_rect") or []
                self.click("rail:Select")
                if len(rect) >= 2:
                    self.d.click(screen=[float(rect[0]) + 4, float(rect[1]) + 4])
                self.d.key("delete")
                self.d.wait_idle(frames=2)
            except SxError:
                break
        self.refresh("dims", "status")

    def purge_stray_lines(self) -> None:
        for ln in list(self.profile_lines()):
            sa, sb = self._pt(ln.get("start") or [0, 0]), self._pt(ln.get("end") or [0, 0])
            if abs(sa[0]) <= 0.8 and abs(sb[0]) <= 0.8:
                continue
            if abs(sa[1]) <= 0.8 and abs(sb[1]) <= 0.8:
                continue
            if abs(sa[1] - 220.0) <= 0.8 and abs(sb[1] - 220.0) <= 0.8:
                continue
            if abs(sa[0] - 30.0) <= 3.0 and abs(sb[0] - 30.0) <= 3.0:
                continue
            if self.endpoint_near({"start": sa, "end": sb}, (90.0, 0.0), tol=2.0):
                continue
            mid = self._line_mid(ln)
            self.click("rail:Select")
            self.show_sketch_point(mid)
            was = self._set_snap(False)
            self.click(sketch=mid)
            self._set_snap(was)
            self.d.key("delete")
            self.d.wait_idle(frames=2)
            self.refresh("sketch", "status")

    def endpoint_near(self, ent, uv, tol: float = 1.5) -> bool:
        for key in ("start", "end"):
            p = self._pt(ent.get(key) or [0, 0])
            if abs(p[0] - float(uv[0])) <= tol and abs(p[1] - float(uv[1])) <= tol:
                return True
        return False

    def delete_arc(self, arc: dict) -> None:
        mid = self._arc_mid_uv(arc, arc.get("radius"))
        self.click("rail:Select")
        self.show_sketch_point(mid)
        was = self._set_snap(False)
        self._click_sketch_geom(mid)
        self._set_snap(was)
        self.d.key("delete")
        self.d.wait_idle(frames=2)
        self.refresh("sketch", "status")

    def dim_line(self, a, b, value: str) -> dict:
        line = self.nearest_line(a, b)
        want = ((float(a[0]) - float(b[0])) ** 2 + (float(a[1]) - float(b[1])) ** 2) ** 0.5
        actual = self.line_length(line) or 0.0
        if line is not None and abs(actual - want) <= 2.0:
            return self.dimension_line(line, value)
        return self.dim_span(a, b, value)

    def dim_span(self, a, b, value: str) -> dict:
        """Two-point dim on the interior of a span, away from arc endpoints."""
        pa, pb = list(a), list(b)
        ia = [pa[0] * 0.25 + pb[0] * 0.75, pa[1] * 0.25 + pb[1] * 0.75]
        ib = [pa[0] * 0.75 + pb[0] * 0.25, pa[1] * 0.75 + pb[1] * 0.25]
        return self.dim_two_points(ia, ib, value)

    def dimension_diameter(self, value: str, centre=None) -> dict:
        circles = self.ents("circle")
        if centre is not None:
            circles = [
                c for c in circles
                if abs(self._pt(c.get("center") or [0, 0])[0] - centre[0]) <= 0.5
                and abs(self._pt(c.get("center") or [0, 0])[1] - centre[1]) <= 0.5
            ]
        if not circles:
            return {"texts": self.dim_texts(), "status": "no circle"}
        c = self._pt(circles[-1].get("center") or [0, 0])
        r = float(circles[-1].get("radius") or 15)
        rim = [c[0] + r, c[1]]
        before = {str(d.get("text", "")) for d in self.dims()}
        self.click("rail:SmartDim")
        self.show_sketch_point(rim)
        self.click(sketch=rim)
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        dim = fresh[-1] if fresh else None
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def dim_radius(self, centre, radius, value: str) -> dict:
        arc = self.nearest_arc(centre, radius)
        if arc is None:
            return {"texts": self.dim_texts(), "status": "no arc"}
        self.clear_sketch_selection()
        # 75% of the way centre→rim: close enough to the curve for radius,
        # far enough from the centre that Smart Dim does not pending a centre.
        rim = self._arc_mid_uv(arc, radius)
        c = self._pt(arc.get("center") or [0, 0])
        hit = [c[0] + (rim[0] - c[0]) * 0.75, c[1] + (rim[1] - c[1]) * 0.75]
        before = {str(d.get("text", "")) for d in self.dims()}
        self.click("rail:SmartDim")
        self.show_sketch_point(hit)
        was = self._set_snap(False)
        self.click(sketch=hit)
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        if not fresh:
            self.click(sketch=list(rim))
            self.d.wait_idle(frames=3)
            fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        self._set_snap(was)
        dim = fresh[-1] if fresh else None
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(self._typed_radius_value(dim, value))
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def _arc_mid_uv(self, arc: dict, radius) -> list[float]:
        c = self._pt(arc.get("center") or [0, 0])
        r = float(arc.get("radius") or radius or 0)
        sa = float(arc.get("start_angle", 0.0))
        ea = float(arc.get("end_angle", sa))
        if ea < sa:
            ea += 2.0 * math.pi
        mid = 0.5 * (sa + ea)
        return [c[0] + r * math.cos(mid), c[1] + r * math.sin(mid)]

    def _typed_radius_value(self, dim: dict, value: str) -> str:
        """Smart Dim on an arc often emits Ø. Type 2R so the radius stays R."""
        text = str(dim.get("text", ""))
        kind = str(dim.get("kind") or dim.get("type") or "")
        if "Ø" not in text and "ø" not in text.lower() and "diameter" not in kind.lower():
            return value
        try:
            doubled = float(value) * 2.0
        except ValueError:
            return value
        if abs(doubled - round(doubled)) < 1e-6:
            return str(int(round(doubled)))
        return ("%g" % doubled)

    def dim_two_points(self, a, b, value: str) -> dict:
        before = {str(d.get("text", "")) for d in self.dims()}
        self.clear_sketch_selection()
        self.click("rail:SmartDim")
        was = self._set_snap(False)
        self._click_sketch_geom(a)
        self.d.wait_idle(frames=2)
        self._click_sketch_geom(b)
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        dim = fresh[-1] if fresh else None
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def power_trim(self, uv) -> str:
        before = len(self.profile_lines())
        self.click("rail:Trim")
        was = self._set_snap(False)
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        if len(self.profile_lines()) <= before:
            mid = self._r20_diameter_mid()
            if mid is not None:
                self.show_sketch_point(mid)
                self.click(sketch=mid)
                self.d.wait_idle(frames=3)
                self.refresh("sketch", "status")
        self._set_snap(was)
        return self.S()

    def _r20_diameter_mid(self):
        for arc in self.ents("arc"):
            if abs(float(arc.get("radius") or 0) - 20.0) > 1.5:
                continue
            a = self._pt(arc.get("start") or [0, 0])
            b = self._pt(arc.get("end") or [0, 0])
            return [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5]
        return None

    def make_vertical(self, line: dict) -> None:
        self.click("rail:Select")
        mid = self._line_mid(line)
        self.show_sketch_point(mid)
        was = self._set_snap(False)
        self.click(sketch=mid)
        self._set_snap(was)
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status")
        try:
            self.click_verb("Vertical")
        except SxError:
            pass
        self.d.wait_idle(frames=2)

    def hanging_stems(self) -> list[dict]:
        stems = []
        for line in self.profile_lines():
            sa, sb = self._pt(line["start"]), self._pt(line["end"])
            if abs(sa[0]) <= 0.5 and abs(sb[0]) <= 0.5:
                continue
            if abs(sa[0] - 30.0) <= 2.0 and abs(sb[0] - 30.0) <= 2.0:
                stems.append(line)
        stems.sort(key=lambda ln: min(self._pt(ln["start"])[1], self._pt(ln["end"])[1]), reverse=True)
        return stems

    def hanging_lower_end(self):
        stems = self.hanging_stems()
        if not stems:
            return (30.0, 80.0)
        line = stems[-1]
        sa, sb = self._pt(line["start"]), self._pt(line["end"])
        return sa if sa[1] < sb[1] else sb

    def arc_free_end(self, arc, avoid) -> tuple[float, float]:
        a = self._pt(arc.get("start") or [0, 0])
        b = self._pt(arc.get("end") or [0, 0])
        ax, ay = float(avoid[0]), float(avoid[1])
        da = (a[0] - ax) ** 2 + (a[1] - ay) ** 2
        db = (b[0] - ax) ** 2 + (b[1] - ay) ** 2
        return a if da >= db else b

    def r60_end(self, start, radius: float = 60.0, end_y: float = 20.0):
        """Locked R60/R12.50 tangent (plan). `start`/`radius`/`end_y` unused."""
        del start, radius, end_y
        return R60_TAN

    def axis_line(self) -> dict | None:
        best = None
        best_d = 4.0
        for line in self.profile_lines():
            sa, sb = self._pt(line["start"]), self._pt(line["end"])
            d = abs(sa[0]) + abs(sb[0])
            if d < best_d and abs((self.line_length(line) or 0) - 220) < 40:
                best, best_d = line, d
        return best

    def click_equal(self, a, b) -> str:
        stems = self.hanging_stems()
        if len(stems) >= 2:
            a = self._line_mid(stems[0])
            b = self._line_mid(stems[1])
        was = self._set_snap(False)
        self.click("rail:Select")
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.d.wait_idle(frames=2)
        self.show_sketch_point(b)
        self.d.key("shift", action="down")
        self.click(sketch=list(b))
        self.d.key("shift", action="up")
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        self.refresh("controls", "status")
        for c in (self.st.get("controls") or []):
            cid = str(c.get("id") or "")
            text = str(c.get("text") or "")
            if "equal" in cid.lower() or text.lower() == "equal":
                try:
                    self.click(cid)
                    self.d.wait_idle(frames=2)
                    break
                except SxError:
                    continue
        else:
            for name in ("Equal", "equal"):
                try:
                    self.click_verb(name)
                    break
                except SxError:
                    continue
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dof")
        return self.S()

    def two_point_horizontal(self, a, b) -> dict:
        self.click("rail:Select")
        self.d.wait_idle(frames=1)
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.show_sketch_point(b)
        self.d.key("ctrl", action="down")
        self.click(sketch=list(b))
        self.d.key("ctrl", action="up")
        self.refresh("controls", "status")
        try:
            self.click_verb("Horizontal")
        except SxError:
            pass
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dof")
        return {"status": self.S(), "dof": self.dof_text()}

    def click_tangent_chip(self) -> str:
        try:
            self.click_verb("Tangent")
        except SxError:
            chip = self.control("chip:Tangent") or self.control("variant:Tangent")
            if chip:
                self.click(str(chip.get("id") or "chip:Tangent"))
        self.d.wait_idle(frames=2)
        self.refresh("status", "sketch")
        return self.S()

    def delete_dim(self, token: str) -> dict:
        dim = self.find_dim(lambda d: self._reads(token, str(d.get("text", ""))))
        before = self.dim_texts()
        if dim is not None:
            self.open_label(dim)
            self.d.key("delete")
            self.d.wait_idle(frames=2)
            self.esc()
        self.refresh("dims", "dof", "status")
        return {"before": before, "after": self.dim_texts(), "status": self.S()}

    def delete_equal(self) -> str:
        glyphs = list((self.refresh("glyphs").get("glyphs") or []))
        equal = next((g for g in glyphs if str(g.get("text", "")) in ("=", "Equal")), None)
        if equal is None:
            self.esc()
            return self.S()
        self.click("rail:Select")
        rect = equal.get("rect") or equal.get("hit_rect") or []
        if len(rect) >= 2:
            self.d.click(screen=[float(rect[0]) + 4, float(rect[1]) + 4])
        self.d.key("delete")
        self.d.wait_idle(frames=2)
        self.refresh("status", "dof", "glyphs")
        return self.S()

    def ellipse3(self, centre, major, minor) -> dict:
        self._arm_sketch_tool("rail:Ellipse")
        self._frame_uv(centre, major, minor)
        for pt in (centre, major, minor):
            self.click(sketch=list(pt))
            self.d.wait_idle(frames=2)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"ellipses": self.ents("ellipse"), "lines": self.profile_lines(), "status": self.S()}

    def try_revolve(self) -> dict:
        mark = self.mark()
        self.click("finish:Revolve")
        self.d.wait_idle(frames=6)
        self.refresh("bodies", "status", "features", "sketch")
        return {
            "status": " | ".join(self.result_texts(mark)) or self.S(),
            "bodies": list(self.st.get("bodies") or []),
            "active": bool((self.st.get("sketch") or {}).get("active")),
        }

    def try_extrude_cut(self, distance: str, draft: str | None = "15") -> dict:
        self._ensure_finish_bar()
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Blind")
        shown = self.type_into("finish:Distance", distance)
        if draft is not None:
            toggle = self.control("finish:Draft")
            if toggle and not toggle.get("pressed"):
                self.click("finish:Draft")
            self.type_into("finish:DraftAngle", draft)
        mark = self.mark()
        reply = self.click("finish:Extrude", frames=8)
        self.d.wait_idle(frames=8)
        results = self.result_texts(mark)
        self.refresh("status", "sketch", "finish", "bodies", "features")
        return {
            "field": shown,
            "draft": self.field("finish:DraftAngle"),
            "reply": reply,
            "results": results,
            "status": " | ".join(results) or str(reply.get("status", self.S())),
            "sketch": bool((self.refresh("sketch").get("sketch") or {}).get("active")),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def pick_timeline(self, name: str) -> None:
        self._show_timeline()
        self.click(f"timeline:row:{name}")
        self.d.wait_idle(frames=2)

    def sketch_names(self) -> list[str]:
        return [n for n in self.feature_names() if str(n).lower().startswith("sketch")]

    def sketch_roles(self) -> list[str]:
        feats = self.refresh("features").get("features") or []
        out = []
        for f in feats:
            if str(f.get("type", "")) == "sketch":
                out.append(str(f.get("role") or ""))
        return out

    def temp_axes_on(self) -> str:
        self.refresh("status", "controls")
        status = self.S()
        if "Temporary Axes off" in status:
            self.click("menu:TemporaryAxes")
            self.d.wait_idle(frames=2)
            self.refresh("status")
            return self.S()
        if "Temporary Axes on" in status:
            return status
        return status or "Temporary Axes on"

    def stage_report(self, stage: str) -> dict:
        name = STAGE_FILE[stage]
        path = self.export_3mf(name)
        code, text = self.checker(stage, name)
        (self.out / f"check-{stage}-{Path(name).stem}.txt").write_text(text)
        return {
            "exported": Path(path).is_file(),
            "code": code,
            "text": text,
            "check_ok": code == 0 and "FAIL" not in text,
        }

    def constraint_types(self) -> list[str]:
        sk = self.refresh("sketch").get("sketch") or {}
        return [str(c.get("type", "")) for c in (sk.get("constraints") or [])]

    def connecting_arcs(self) -> list[dict]:
        """R12.50 clip rim only. |10−12.5|=2.5, so a 3 mm window also matches R10."""
        out = []
        for arc in self.ents("arc"):
            r = float(arc.get("radius") or 0)
            if any(abs(r - k) <= 1.5 for k in (10.0, 20.0, 60.0)):
                continue
            if abs(r - 12.5) <= 1.5 or self.endpoint_near(arc, R12_CLIP, tol=2.0):
                out.append(arc)
        return out

    def _ensure_clip_stub(self) -> None:
        if any(
            self.endpoint_near(ln, BASE_END) and self.endpoint_near(ln, R12_CLIP)
            for ln in self.profile_lines()
        ):
            return
        self._arm_sketch_tool("rail:Line")
        self._frame_uv(BASE_END, R12_CLIP)
        was = self._set_snap(True)
        self.click(sketch=list(BASE_END))
        self._set_snap(False)
        self.click(sketch=list(R12_CLIP))
        self._set_snap(was)
        self.refresh("sketch", "status")

    def clip_rim_for_revolve(self) -> None:
        """Replace the unclipped toe with the y ≥ 0 locked rim.

        A11 joins the tutorial 90 mm end. The checker sits on y = 0 at
        x = 108.998, so A13 deletes that inner connecting arc (it keeps the
        revolved rim at r=90 and inverts the solid) and redraws R12.50 to
        the clip. A collinear stub from the 90 end keeps the 90 dim.
        """
        r60 = self.nearest_arc(None, 60)
        start = self.arc_free_end(r60, (30.0, 80.0)) if r60 else R60_TAN
        connecting = self.connecting_arcs()
        if not connecting:
            self.connecting_rim(start, R12_CLIP, snap_end=False)
        else:
            # Two CLIP arcs with the same ends make a lens; MakeRevol then
            # throws BRep_API: command not done.
            for extra in connecting[1:]:
                self.delete_arc(extra)
        self._ensure_clip_stub()
        self.purge_stray_arcs()
        self.delete_angle_dims()

    def keep_one_label(self, token: str) -> None:
        """Drop duplicate labels of `token`. Never Esc (that exits the sketch)."""
        for _ in range(6):
            matches = [
                d for d in self.dims()
                if self._reads(token, str(d.get("text", "")))
            ]
            n = len(matches)
            if n <= 1:
                return
            dim = matches[-1]
            try:
                rect = dim.get("rect") or dim.get("hit_rect") or []
                if len(rect) < 2:
                    return
                self.click("rail:Select")
                self.d.click(screen=[float(rect[0]) + 4, float(rect[1]) + 4])
                self.d.key("delete")
                self.d.wait_idle(frames=2)
            except SxError:
                return
            self.refresh("dims", "status")
            if len([
                d for d in self.dims()
                if self._reads(token, str(d.get("text", "")))
            ]) >= n:
                return
