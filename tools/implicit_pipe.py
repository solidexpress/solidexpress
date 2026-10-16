"""Analytic pipe section used only by the checker unit tests.

The CLI checker does not import this module. volume() returns the stage
table; probes measure inside() and hits().
"""
import math
from dataclasses import dataclass

import numpy as np

from check_rung05 import PART, VOLUMES
from geom import Topology


_STEP = 0.02

# Per-stage CSG flags. Mutants flip one field; they do not add branches.
STAGE = {
    "cyl":     dict(shell_plus=False, flange_plus=False, cut_plus=False, minus=False, shell_minus=False, fillet=False),
    "shelled": dict(shell_plus=True,  flange_plus=False, cut_plus=False, minus=False, shell_minus=False, fillet=False),
    "flange":  dict(shell_plus=True,  flange_plus=True,  cut_plus=False, minus=False, shell_minus=False, fillet=False),
    "cut":     dict(shell_plus=True,  flange_plus=True,  cut_plus=True,  minus=False, shell_minus=False, fillet=False),
    "mirror":  dict(shell_plus=True,  flange_plus=True,  cut_plus=True,  minus=True,  shell_minus=False, fillet=False),
    "reshell": dict(shell_plus=True,  flange_plus=True,  cut_plus=True,  minus=True,  shell_minus=True,  fillet=False),
    "final":   dict(shell_plus=True,  flange_plus=True,  cut_plus=True,  minus=True,  shell_minus=True,  fillet=True),
}


@dataclass
class ImplicitPipe:
    """Cylinders, flanges, holes, optional R5 rims. Tests only."""

    stage: str
    shell_plus: bool = False
    flange_plus: bool = False
    cut_plus: bool = False
    minus: bool = False
    shell_minus: bool = False
    fillet: bool = False
    od: float = PART["OD"]
    wall_plus: float = PART["WALL"]
    wall_minus: float = PART["WALL"]
    l0: float = PART["L0"]
    flange_d: float = PART["FLANGE_D"]
    flange_t: float = PART["FLANGE_T"]
    hole_d: float = PART["HOLE_D"]
    pcd: float = PART["PCD"]
    n_holes: int = PART["N_HOLES"]
    fillet_r: float = PART["FILLET"]
    through_all: bool = False
    shell_carries: bool = False
    volume_override: float = None

    @staticmethod
    def for_stage(stage, **overrides):
        flags = dict(STAGE[stage])
        if overrides.pop("skip_minus", False):
            flags["minus"] = False
            flags["shell_minus"] = False
        data = dict(flags)
        data.update(overrides)
        return ImplicitPipe(stage=stage, **data)

    @property
    def r_out(self):
        return self.od / 2.0

    @property
    def r_in_plus(self):
        return self.r_out - self.wall_plus

    @property
    def r_in_minus(self):
        return self.r_out - self.wall_minus

    @property
    def r_id(self):
        return PART["ID"] / 2.0

    @property
    def r_flange(self):
        return self.flange_d / 2.0

    @property
    def z_flange(self):
        return self.l0 + self.flange_t

    def volume(self):
        if self.volume_override is not None:
            return self.volume_override
        if self.shell_carries and self.stage == "mirror":
            return float(VOLUMES["reshell"])
        return float(VOLUMES[self.stage])

    def topology(self):
        return Topology(0, 0, 1)

    def bbox(self):
        r = self.r_flange if self.flange_plus else self.r_out
        z1 = self.z_flange if self.flange_plus else self.l0
        z0 = -z1 if self.minus else 0.0
        return np.array((-r, -r, z0)), np.array((r, r, z1))

    def inside(self, point):
        x, y, z = float(point[0]), float(point[1]), float(point[2])
        if not self._in_body(x, y, z):
            return False
        if self._in_hole(x, y, z):
            return False
        if self.fillet and self._in_fillet_void(x, y, z):
            return False
        return True

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
        mn = np.asarray(mn, float) - 80.0
        mx = np.asarray(mx, float) + 80.0
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

    def _in_body(self, x, y, z):
        return self._in_plus(x, y, z) or self._in_minus(x, y, z)

    def _in_plus(self, x, y, z):
        rho = math.hypot(x, y)
        if 0.0 - 1e-9 <= z <= self.l0 + 1e-9 and rho <= self.r_out + 1e-9:
            if not self.shell_plus or rho >= self.r_in_plus - 1e-9:
                return True
        if not self.flange_plus:
            return False
        if self.l0 - 1e-9 <= z <= self.z_flange + 1e-9 and rho <= self.r_flange + 1e-9:
            if not self.cut_plus or rho >= self.r_id - 1e-9:
                return True
        return False

    def _in_minus(self, x, y, z):
        if not self.minus:
            return False
        rho = math.hypot(x, y)
        hollow = self.shell_minus or self.shell_carries or self.through_all
        r_in = self.r_in_minus if (self.shell_minus or self.shell_carries) else self.r_id
        if -self.l0 - 1e-9 <= z <= 0.0 + 1e-9 and rho <= self.r_out + 1e-9:
            if not hollow or rho >= r_in - 1e-9:
                return True
        if self.flange_plus and -self.z_flange - 1e-9 <= z <= -self.l0 + 1e-9 and rho <= self.r_flange + 1e-9:
            if not self.cut_plus or rho >= self.r_id - 1e-9:
                return True
        return False

    def _in_hole(self, x, y, z):
        if not self.cut_plus:
            return False
        r2 = (self.hole_d / 2.0) ** 2
        slabs = []
        if self.flange_plus:
            slabs.append((self.l0, self.z_flange))
        if self.minus and self.flange_plus:
            slabs.append((-self.z_flange, -self.l0))
        if self.through_all and self.minus:
            slabs.append((-self.l0, 0.0))
        for z0, z1 in slabs:
            lo, hi = min(z0, z1), max(z0, z1)
            if z < lo - 1e-9 or z > hi + 1e-9:
                continue
            for k in range(self.n_holes):
                ang = k * (2.0 * math.pi / self.n_holes)
                cx = self.pcd * math.sin(ang)
                cy = self.pcd * math.cos(ang)
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2 + 1e-8:
                    return True
        return False

    def _in_fillet_void(self, x, y, z):
        rho = math.hypot(x, y)
        r = self.fillet_r
        specs = (
            (self.r_flange, self.z_flange, 1.0, True),
            (self.r_id, self.z_flange, 1.0, False),
            (self.r_flange, -self.z_flange, -1.0, True),
            (self.r_id, -self.z_flange, -1.0, False),
        )
        for r_edge, z_face, sign, outer in specs:
            if self._rim_void(rho, z, r_edge, z_face, r, outer, sign):
                return True
        return False

    @staticmethod
    def _rim_void(rho, z, r_edge, z_face, fillet, outer, sign):
        cr = (r_edge - fillet) if outer else (r_edge + fillet)
        cz = z_face - sign * fillet
        if outer:
            if rho < cr - 1e-12 or rho > r_edge + 1e-9:
                return False
        else:
            if rho > cr + 1e-12 or rho < r_edge - 1e-9:
                return False
        if sign > 0:
            if z < cz - 1e-12 or z > z_face + 1e-9:
                return False
        else:
            if z > cz + 1e-12 or z < z_face - 1e-9:
                return False
        return (rho - cr) ** 2 + (z - cz) ** 2 > fillet * fillet + 1e-8
