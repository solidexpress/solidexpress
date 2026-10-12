# Analytic Lesson 2 box used only by the checker unit tests.
# The CLI checker does not import this module.

import math
from dataclasses import dataclass

import numpy as np

from geom import Topology


def _rounded_area(width, height, radius):
    if width <= 0 or height <= 0:
        return 0.0
    radius = min(radius, width / 2.0, height / 2.0)
    if radius <= 0:
        return width * height
    return width * height - (4.0 - math.pi) * radius * radius


def _in_rounded(x, y, x0, y0, x1, y1, rad):
    if x1 - x0 <= 1e-12 or y1 - y0 <= 1e-12:
        return False
    rad = min(rad, (x1 - x0) / 2.0, (y1 - y0) / 2.0)
    if rad <= 1e-12:
        return x0 <= x <= x1 and y0 <= y <= y1
    cx = min(max(x, x0 + rad), x1 - rad)
    cy = min(max(y, y0 + rad), y1 - rad)
    return (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad


@dataclass
class ImplicitPart:
    """Analytic rounded box, optional shell, optional hole. Tests only."""

    W: float
    R: float = 0.0
    shell: bool = False
    wall: tuple = (5.0, 5.0, 5.0, 5.0)  # left, right, bottom, top insets
    closed_top: bool = False
    hole_mode: str = "none"  # none | both-x | one-x | both-y
    hole_d: float = 10.0
    hole_y: float = 35.0
    hole_z: float = 40.0
    X: float = 100.0
    H: float = 50.0

    @staticmethod
    def base(W):
        return ImplicitPart(W=W, R=0.0, shell=False, hole_mode="none")

    @staticmethod
    def rounded(W, R=10.0):
        return ImplicitPart(W=W, R=R, shell=False, hole_mode="none")

    @staticmethod
    def shell(W, R=10.0, wall=(5.0, 5.0, 5.0, 5.0), closed_top=False):
        return ImplicitPart(W=W, R=R, shell=True, wall=tuple(wall), closed_top=closed_top, hole_mode="none")

    @staticmethod
    def final(W, R=10.0, wall=(5.0, 5.0, 5.0, 5.0), hole_mode="both-x",
              hole_d=10.0, hole_y=35.0, hole_z=40.0, closed_top=False):
        return ImplicitPart(
            W=W, R=R, shell=True, wall=tuple(wall), closed_top=closed_top,
            hole_mode=hole_mode, hole_d=hole_d, hole_y=hole_y, hole_z=hole_z)

    def _inner_radius(self):
        return max(0.0, self.R - max(self.wall))

    def inside(self, p):
        x, y, z = (float(p[0]), float(p[1]), float(p[2]))
        if z < 0.0 or z > self.H:
            return False
        if not _in_rounded(x, y, 0.0, 0.0, self.X, self.W, self.R):
            return False
        if self.shell and self._in_cavity(x, y, z):
            return False
        if self._in_hole(x, y, z):
            return False
        return True

    def _in_cavity(self, x, y, z):
        left, right, bottom, top = self.wall
        z_hi = self.H - (top if self.closed_top else 0.0)
        if self.closed_top:
            in_z = bottom < z < z_hi
        else:
            in_z = bottom < z <= self.H
        if not in_z:
            return False
        return _in_rounded(x, y, left, bottom, self.X - right, self.W - top, self._inner_radius())

    def _in_hole(self, x, y, z):
        if self.hole_mode == "none":
            return False
        left, right, bottom, top = self.wall
        r2 = (self.hole_d * 0.5) ** 2
        if self.hole_mode in ("both-x", "one-x"):
            if (y - self.hole_y) ** 2 + (z - self.hole_z) ** 2 <= r2:
                if 0.0 <= x <= left:
                    return True
                if self.hole_mode == "both-x" and self.X - right <= x <= self.X:
                    return True
        if self.hole_mode == "both-y":
            if (x - self.X * 0.5) ** 2 + (z - self.hole_z) ** 2 <= r2:
                if 0.0 <= y <= bottom or self.W - top <= y <= self.W:
                    return True
        return False

    def volume(self):
        outer = self.H * _rounded_area(self.X, self.W, self.R)
        if not self.shell:
            return outer
        left, right, bottom, top = self.wall
        height = self.H - bottom - (top if self.closed_top else 0.0)
        inner = height * _rounded_area(
            self.X - left - right, self.W - bottom - top, self._inner_radius())
        return outer - inner - self._hole_volume()

    def _hole_volume(self):
        if self.hole_mode == "none":
            return 0.0
        area = math.pi * (self.hole_d * 0.5) ** 2
        left, right, bottom, top = self.wall
        if self.hole_mode == "both-x":
            return area * (left + right)
        if self.hole_mode == "one-x":
            return area * left
        if self.hole_mode == "both-y":
            return area * (bottom + top)
        return 0.0

    def bbox(self):
        return np.array((0.0, 0.0, 0.0)), np.array((self.X, self.W, self.H))

    def hits(self, origin, direction):
        o = np.asarray(origin, float)
        d = np.asarray(direction, float)
        d = d / np.linalg.norm(d)
        span = self._span(o, d)
        if span is None:
            return []
        t0, t1 = span
        step = 0.01
        t = t0
        prev = self.inside(o + t * d)
        found = []
        limit = t1 + step
        while t < limit - 1e-15:
            t_next = min(t + step, limit)
            cur = self.inside(o + t_next * d)
            if cur != prev:
                found.append(self._bisect(o, d, t, t_next, prev))
            prev = cur
            t = t_next
        return [hit for hit in found if hit > 1e-9]

    def _span(self, o, d):
        bmin = np.array((-2.0, -2.0, -2.0))
        bmax = np.array((self.X + 2.0, self.W + 2.0, self.H + 2.0))
        t_near, t_far = -1e9, 1e9
        for i in range(3):
            if abs(d[i]) < 1e-15:
                if o[i] < bmin[i] or o[i] > bmax[i]:
                    return None
                continue
            ta = (bmin[i] - o[i]) / d[i]
            tb = (bmax[i] - o[i]) / d[i]
            t_near = max(t_near, min(ta, tb))
            t_far = min(t_far, max(ta, tb))
        if t_far < max(t_near, 0.0):
            return None
        return max(t_near, 0.0), t_far

    def _bisect(self, o, d, t_a, t_b, inside_a):
        for _ in range(40):
            mid = 0.5 * (t_a + t_b)
            if self.inside(o + mid * d) == inside_a:
                t_a = mid
            else:
                t_b = mid
        return 0.5 * (t_a + t_b)

    def topology(self):
        return Topology(0, 0, 1)
