"""Rung-6 gestures: Front profile, temp-axis path, Right ellipse, fuse sweep, draft cut."""
from __future__ import annotations

from pathlib import Path

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

from walk.rung6.cut import CutGestures
from walk.rung6.path import PathGestures
from walk.rung6.profile import ProfileGestures


class WalkUI06(ProfileGestures, PathGestures, CutGestures, WalkChrome):
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

    def sketch_on_datum(self, name: str, view_key: str) -> dict:
        self.clear_faces()
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        return WalkChrome.sketch_on_datum(self, name, view_key)

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
