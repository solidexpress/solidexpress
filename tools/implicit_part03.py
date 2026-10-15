"""Analytic Lesson 1 part used only by the checker unit tests.

The CLI checker does not import this module. `volume` is the stage value
from the checker's table; the probes measure `inside` and `hits`.
"""
import math
from dataclasses import dataclass

import numpy as np

from check_rung03 import PART, VOLUMES
from geom import Topology


_STEP = 0.01


@dataclass
class ImplicitPart03:
    """Outer solid minus the hole, then minus the shell cavity when `wall` > 0."""

    stage: str
    h0: float = PART["H0"]
    boss_d: float = PART["BOSS_D"]
    boss_h: float = PART["BOSS_H"]
    hole_d: float = PART["HOLE_D"]
    side: float = PART["SIDE"]
    r_vert: float = 0.0
    r_front: float = 0.0
    r_root: float = 0.0
    r_outer_rim: float = 0.0
    r_inner_rim: float = 0.0
    wall: float = 0.0
    wall_xn: float = None
    wall_xp: float = None
    wall_yn: float = None
    wall_yp: float = None
    wall_hole: float = None
    wall_boss: float = None
    wall_plate: float = None
    inner_corner_r: float = None
    closed_back: bool = False
    blind: bool = False
    shift: tuple = (0.0, 0.0)

    def __post_init__(self):
        for name in ("wall_xn", "wall_xp", "wall_yn", "wall_yp", "wall_hole", "wall_boss", "wall_plate"):
            if getattr(self, name) is None:
                setattr(self, name, self.wall)
        if self.inner_corner_r is None:
            self.inner_corner_r = max(0.0, self.r_vert - self.wall)

    @staticmethod
    def for_stage(stage, **overrides):
        common = dict(
            h0=PART["H0"], boss_d=PART["BOSS_D"], boss_h=PART["BOSS_H"],
            hole_d=PART["HOLE_D"], side=PART["SIDE"],
            r_vert=0.0, r_front=0.0, r_root=0.0,
            r_outer_rim=0.0, r_inner_rim=0.0, wall=0.0,
        )
        shaped = {
            "base": dict(boss_h=0.0, hole_d=0.0),
            "boss": dict(hole_d=0.0),
            "cut": {},
            "r5": dict(r_vert=5.0, r_front=5.0, r_root=5.0),
            "rounded": dict(r_vert=5.0, r_front=5.0, r_root=5.0, r_outer_rim=1.5, r_inner_rim=1.5),
            "final": dict(
                r_vert=5.0, r_front=5.0, r_root=5.0,
                r_outer_rim=1.5, r_inner_rim=1.5, wall=1.0,
            ),
        }[stage]
        data = dict(common)
        data.update(shaped)
        data.update(overrides)
        return ImplicitPart03(stage=stage, **data)

    @property
    def half(self):
        return self.side / 2.0

    @property
    def boss_r(self):
        return self.boss_d / 2.0

    @property
    def hole_r(self):
        return self.hole_d / 2.0

    @property
    def top(self):
        if self.boss_h <= 0.0:
            return self.h0
        return self.h0 + self.boss_h

    def bbox(self):
        sx, sy = self.shift
        h = self.top
        return (
            np.array((-self.half + sx, -self.half + sy, 0.0)),
            np.array((self.half + sx, self.half + sy, h)),
        )

    def volume(self):
        return float(VOLUMES[self.stage])

    def topology(self):
        return Topology(0, 0, 1)

    def inside(self, point):
        x = float(point[0]) - self.shift[0]
        y = float(point[1]) - self.shift[1]
        z = float(point[2])
        if not self._in_outer(x, y, z):
            return False
        return not self._in_void(x, y, z)

    def hits(self, origin, direction):
        o = np.asarray(origin, float)
        d = np.asarray(direction, float)
        nrm = float(np.linalg.norm(d))
        if nrm == 0.0:
            return []
        d = d / nrm
        t_end = self._ray_limit(o, d)
        if t_end <= _STEP:
            return []
        prev = self.inside(o)
        ts = []
        t = _STEP
        while t <= t_end + 1e-12:
            cur = self.inside(o + d * t)
            if cur != prev:
                ts.append(self._bisect(o, d, t - _STEP, t, prev))
                prev = cur
            t += _STEP
        out = []
        for value in ts:
            if value > 1e-6 and (not out or value - out[-1] > 1e-4):
                out.append(value)
        return out

    def _bisect(self, o, d, lo, hi, lo_inside):
        for _ in range(40):
            mid = 0.5 * (lo + hi)
            if self.inside(o + d * mid) == lo_inside:
                lo = mid
            else:
                hi = mid
        return 0.5 * (lo + hi)

    def _ray_limit(self, o, d):
        mn, mx = self.bbox()
        mn = np.asarray(mn, float) - 20.0
        mx = np.asarray(mx, float) + 20.0
        t0, t1 = 0.0, 1e6
        for i in range(3):
            if abs(d[i]) < 1e-15:
                if o[i] < mn[i] or o[i] > mx[i]:
                    return 0.0
                continue
            inv = 1.0 / d[i]
            a = (mn[i] - o[i]) * inv
            b = (mx[i] - o[i]) * inv
            if a > b:
                a, b = b, a
            t0 = max(t0, a)
            t1 = min(t1, b)
        if t1 < t0:
            return 0.0
        return float(t1)

    def _in_void(self, x, y, z):
        if self._in_hole(x, y, z):
            return True
        return self.wall > 0.0 and self._in_cavity(x, y, z)

    def _in_outer(self, x, y, z):
        return self._in_base(x, y, z) or self._in_boss(x, y, z) or self._in_root(x, y, z)

    def _in_base(self, x, y, z):
        if z < -1e-9 or z > self.h0 + 1e-9:
            return False
        if not _rounded_xy(x, y, self.half, self.r_vert):
            return False
        return self._front_keeps(x, y, z)

    def _front_keeps(self, x, y, z):
        radius = self.r_front
        if radius <= 1e-12 or z <= self.h0 - radius:
            return True
        return _edge_keeps(x, z, self.half, radius, self.h0) and _edge_keeps(y, z, self.half, radius, self.h0)

    def _in_boss(self, x, y, z):
        if self.boss_h <= 1e-12:
            return False
        z0, z1 = self.h0, self.top
        if z < z0 - 1e-9 or z > z1 + 1e-9:
            return False
        rho = math.hypot(x, y)
        rb = self.boss_r
        if rho > rb + 1e-9:
            return False
        if not _rim_keeps(rho, z, rb, z1, self.r_outer_rim, outward=True):
            return False
        if self.hole_d > 0.0 and not _rim_keeps(rho, z, self.hole_r, z1, self.r_inner_rim, outward=False):
            return False
        return True

    def _in_root(self, x, y, z):
        radius = self.r_root
        if radius <= 0.0 or self.boss_h <= 0.0:
            return False
        rho = math.hypot(x, y)
        rb = self.boss_r
        if rho < rb - 1e-9 or rho > rb + radius + 1e-9:
            return False
        if z < self.h0 - 1e-9 or z > self.h0 + radius + 1e-9:
            return False
        cr, cz = rb + radius, self.h0 + radius
        return (rho - cr) ** 2 + (z - cz) ** 2 >= radius * radius - 1e-8

    def _in_hole(self, x, y, z):
        if self.hole_d <= 0.0:
            return False
        if math.hypot(x, y) >= self.hole_r:
            return False
        if self.blind and z < self.h0:
            return False
        return True

    def _in_cavity(self, x, y, z):
        if self.closed_back and z <= self.wall_plate + 1e-12:
            return False
        rho = math.hypot(x, y)
        hr = self.hole_r
        if self.hole_d > 0.0 and hr <= rho <= hr + self.wall_hole + 1e-12:
            return False
        rb = self.boss_r
        # The boss interior is open through the base plate, down to the plate's underside.
        plate_bottom = self.h0 - self.wall_plate
        if self.boss_h > 0.0 and rho <= rb - self.wall_boss + 1e-9 and z >= plate_bottom - 1e-9:
            if z > self.top - self.wall_plate:
                return False
            if self._in_root_skin(rho, z):
                return False
            return True
        return self._in_inner_base(x, y, z)

    def _in_root_skin(self, rho, z):
        radius = self.r_root
        if radius <= 0.0:
            return False
        rb = self.boss_r
        inner = radius + self.wall
        cr, cz = rb + radius, self.h0 + radius
        dist2 = (rho - cr) ** 2 + (z - cz) ** 2
        if dist2 < radius * radius - 1e-8 or dist2 > inner * inner + 1e-6:
            return False
        return rb <= rho <= rb + radius + 1e-9 and self.h0 <= z <= self.h0 + radius + 1e-9

    def _in_inner_base(self, x, y, z):
        if z >= self.h0 + 1e-9:
            return False
        if not self._inside_inner_xy(x, y):
            return False
        return self._below_inner_top(x, y, z)

    def _inside_inner_xy(self, x, y):
        xn, xp, yn, yp = self._inner_limits()
        if x <= xn or x >= xp or y <= yn or y >= yp:
            return False
        centre = self.half - self.r_vert
        if self.r_vert > 0.0 and abs(x) > centre and abs(y) > centre:
            if (abs(x) - centre) ** 2 + (abs(y) - centre) ** 2 >= self.inner_corner_r ** 2:
                return False
        return True

    def _below_inner_top(self, x, y, z):
        """Base cavity stops at the plate, with the front edge fillet offset inward."""
        z_plate = self.h0 - self.wall_plate
        if z > z_plate + 1e-9:
            return False
        ri = self.r_front - self.wall_plate
        if ri <= 1e-12:
            return True
        half_i = self.half - self.wall_plate
        return (
            _edge_keeps(x, z, half_i, ri, z_plate)
            and _edge_keeps(y, z, half_i, ri, z_plate)
        )

    def _inner_limits(self):
        half = self.half
        return (
            -half + self.wall_xn,
            half - self.wall_xp,
            -half + self.wall_yn,
            half - self.wall_yp,
        )


def _rounded_xy(x, y, half, radius):
    if radius <= 1e-12:
        return abs(x) <= half + 1e-9 and abs(y) <= half + 1e-9
    core = half - radius
    cx = min(max(x, -core), core)
    cy = min(max(y, -core), core)
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius + 1e-8


def _edge_keeps(coord, z, half, radius, h0):
    outward = abs(coord)
    centre = half - radius
    if outward <= centre:
        return True
    dz = z - (h0 - radius)
    if dz <= 0.0:
        return True
    return (outward - centre) ** 2 + dz * dz <= radius * radius + 1e-8


def _rim_keeps(rho, z, radius_at, z1, fillet, outward):
    """Quarter-round a convex rim. `outward` is the boss outer rim; otherwise the hole rim."""
    if fillet <= 1e-12 or z <= z1 - fillet:
        return True
    if outward:
        if rho <= radius_at - fillet:
            return True
        dr = rho - (radius_at - fillet)
    else:
        if rho >= radius_at + fillet:
            return True
        dr = (radius_at + fillet) - rho
    dz = z - (z1 - fillet)
    if dr <= 0.0 or dz <= 0.0:
        return True
    return dr * dr + dz * dz <= fillet * fillet + 1e-8
