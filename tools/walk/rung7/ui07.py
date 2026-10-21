"""Rung-7 gestures: Front C + 12-point + handle, mid-plane pads, recess, Front mirror."""
from __future__ import annotations

import math

from walk.chrome import WalkChrome

PINNED_NEW = "New — empty part, Top plane (XY). View ▸ Timeline to edit features"

STAGE_FILE = {
    "boss": "boss.3mf",
    "neck": "neck.3mf",
    "mirror": "mirror.3mf",
    "final": "final.3mf",
}


class WeldPolicy:
    DUP_MM = 1e-3
    PAIR_MM = 1.6
    JAW_NEAR_MM = 2.5


class NeckPolicy:
    Y_SLOP = 0.4
    ATTEMPTS = 3


from walk.rung7.boss import BossGestures
from walk.rung7.dress import DressGestures
from walk.rung7.profile import ProfileGestures


class WalkUI07(ProfileGestures, BossGestures, DressGestures, WalkChrome):
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

    def jaw_tip_uv(self, upper: bool) -> tuple[float, float]:
        if upper:
            return self.ellipse_major()
        return self.world(0.0, -self.mm("ELLIPSE_MAJ") * 0.5)

    def neck_open_xys(self) -> list[tuple[float, float]]:
        return [self.handle_xy(True)[0], self.handle_xy(False)[0]]

    def neck_box_xys(self) -> list[tuple[float, float]]:
        return [self.handle_xy(True)[1], self.handle_xy(False)[1]]

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
        # C hit at y=±10 on the ellipse (+X), Ø33 at the left chord. Not the
        # major-axis tip — that vertex is the jaw, and coincident there pulls
        # the strip through the C (A23 volume 41996 vs 41705).
        half = self.mm("HANDLE_HALF")
        ring = self.mm("CENTER") - math.sqrt(max(0.0, (self.mm("RING_D") * 0.5) ** 2 - half ** 2))
        if upper:
            return (22.944, half), (ring, half)
        return (23.929, -half), (ring, -half)

    def c_body_uv(self) -> tuple[float, float]:
        # +X elliptical-arc pick, off the handle (y=±10) and off the CL (y=0).
        return (24.7, 4.0)

    def sketch_on_datum(self, name: str, view_key: str) -> dict:
        self.clear_faces()
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        return WalkChrome.sketch_on_datum(self, name, view_key)
