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
            [0, 0], [0, 18], [0, -18], [18, 0], [-18, 0],
            [14, 14], [-14, 14], [14, -14], [-14, -14],
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
        self.click_verb(label)

    def tangent_arc(self, start, end) -> dict:
        self._arm_sketch_tool("rail:Arc")
        self.variant("Tangent")
        self.d.wait_idle(frames=2)
        self._zoom_uv(start)
        host = self._nudge_toward(start, end, 1.2)
        self._click_sketch_geom(host)
        self.d.wait_idle(frames=2)
        was = self._set_snap(False)
        self.click(sketch=list(end))
        self.d.wait_idle(frames=3)
        self._set_snap(was)
        self.refresh("sketch", "status")
        return {"arcs": self.ents("arc"), "status": self.S()}

    def three_point_arc(self, p1, bulge, p3) -> dict:
        self._arm_sketch_tool("rail:Arc")
        self.variant("Three Point")
        self.d.wait_idle(frames=2)
        self._zoom_uv(p1, 6)
        was = self._set_snap(False)
        for pt in (p1, bulge, p3):
            self._click_sketch_geom(pt)
            self.d.wait_idle(frames=2)
        self._set_snap(was)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"arcs": self.ents("arc"), "status": self.S()}

    def dim_line(self, a, b, value: str) -> dict:
        line = self.nearest_line(a, b)
        if line is None:
            return self.dim_two_points(a, b, value)
        want = ((float(a[0]) - float(b[0])) ** 2 + (float(a[1]) - float(b[1])) ** 2) ** 0.5
        actual = self.line_length(line) or 0.0
        if abs(actual - want) <= 2.0:
            return self.dimension_line(line, value)
        return self.dim_two_points(a, b, value)

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
        rim = self._arc_mid_uv(arc, radius)
        before = {str(d.get("text", "")) for d in self.dims()}
        self.click("rail:SmartDim")
        self.show_sketch_point(rim)
        self.click(sketch=rim)
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
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
        self.click("rail:SmartDim")
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.show_sketch_point(b)
        self.click(sketch=list(b))
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
        self.click("rail:Trim")
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return self.S()

    def click_equal(self, a, b) -> str:
        self.click("rail:Select")
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.show_sketch_point(b)
        self.d.key("shift", action="down")
        self.click(sketch=list(b))
        self.d.key("shift", action="up")
        self.refresh("controls", "status")
        try:
            self.click_verb("Equal")
        except SxError:
            pass
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dof")
        return self.S()

    def two_point_horizontal(self, a, b) -> dict:
        self.click("rail:Select")
        self.d.key("escape")
        self.d.wait_idle(frames=2)
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
