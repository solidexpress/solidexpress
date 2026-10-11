#!/usr/bin/env python3
"""Rung-2 acceptance checks for the Lesson 2 box.

Usage:
  python3 tools/check_rung02.py <stage> <file.3mf> [--width W]
  python3 tools/check_rung02.py params

Stages: base, rounded, shell, final. Width is 60 or 65 (default 60).
`params` prints the PART table as JSON. Tolerances: 0.2 mm, volume 0.5 %.
"""
import json
import math
import sys
from dataclasses import dataclass

import numpy as np

from geom import R, Topology, load_3mf, ray_hits, topology_report, tri_arrays
from geom import inside as mesh_inside

TOL = 0.2
VOLUME_TOL = 0.005
CORNER_TOL = 0.083  # 0.2 * (sqrt(2) - 1), the R10 ± 0.2 band

# One table. Volumes and probes read these numbers; nothing else hard-codes them.
PART = {
    "X": 100.0,
    "H": 50.0,
    "R": 10.0,
    "WALL": 5.0,
    "HOLE_D": 10.0,
    "HOLE_Y": 35.0,
    "HOLE_Z": 40.0,
    "OPEN": "+Z",
    "TOL": TOL,
    "VOLUME_TOL": VOLUME_TOL,
    "widths": [60, 65],
}


def _rounded_area(width, height, radius):
    if width <= 0 or height <= 0:
        return 0.0
    radius = min(radius, width / 2.0, height / 2.0)
    if radius <= 0:
        return width * height
    return width * height - (4.0 - math.pi) * radius * radius


def volumes(W):
    """Analytic volumes for width W. The walk reads these from `params`."""
    X, H, R, wall = PART["X"], PART["H"], PART["R"], PART["WALL"]
    block = X * W * H
    rounded = H * _rounded_area(X, W, R)
    inner_r = R - wall
    inner = (H - wall) * _rounded_area(X - 2 * wall, W - 2 * wall, inner_r)
    hole = 2.0 * wall * math.pi * (PART["HOLE_D"] / 2.0) ** 2
    no_hole = rounded - inner
    return {
        "block": block,
        "rounded": rounded,
        "inner": inner,
        "no_hole": no_hole,
        "hole": hole,
        "final": no_hole - hole,
    }


def params_dict():
    data = dict(PART)
    data["volumes"] = {str(W): volumes(W) for W in PART["widths"]}
    return data


class Row:
    def __init__(self, name, ok, got, want):
        self.name = name
        self.ok = bool(ok)
        self.got = got
        self.want = want


class TriMesh:
    """Solid from a triangle mesh. Geometry goes through `geom`."""

    def __init__(self, V, T):
        self.V = np.asarray(V, float)
        self.T = np.asarray(T, int)
        self._tris = tri_arrays(self.V, self.T)

    def bbox(self):
        return self.V.min(0), self.V.max(0)

    def volume(self):
        a, b, c = self._tris
        signed = float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)
        return abs(signed)

    def inside(self, p):
        return bool(mesh_inside(self._tris, p))

    def hits(self, origin, direction):
        d = np.asarray(direction, float)
        d = d / np.linalg.norm(d)
        ts = ray_hits(self._tris, np.asarray(origin, float), d)
        out = []
        for t in ts:
            tf = float(t)
            if not out or tf - out[-1] > 1e-5:
                out.append(tf)
        return out

    def topology(self):
        return topology_report(self.V, self.T)


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


def _fmt(value):
    if value is None:
        return "none"
    if isinstance(value, float):
        return round(value, 4)
    return value


class Bbox:
    def run(self, solid, W):
        mn, mx = solid.bbox()
        ext = np.asarray(mx, float) - np.asarray(mn, float)
        mn = np.asarray(mn, float)
        ok = (
            abs(ext[0] - PART["X"]) <= TOL and abs(ext[1] - W) <= TOL
            and abs(ext[2] - PART["H"]) <= TOL
            and abs(mn[0]) <= TOL and abs(mn[1]) <= TOL and abs(mn[2]) <= TOL
        )
        got = f"{ext[0]:.3f}×{ext[1]:.3f}×{ext[2]:.3f} min ({mn[0]:.3f},{mn[1]:.3f},{mn[2]:.3f})"
        want = f"{PART['X']:.0f}×{W:.0f}×{PART['H']:.0f} min (0,0,0) ± {TOL}"
        return [Row("bbox", ok, got, want)]


class Volume:
    def __init__(self, kind):
        self.kind = kind

    def run(self, solid, W):
        got = float(solid.volume())
        want = volumes(W)[self.kind]
        ok = abs(got - want) <= VOLUME_TOL * abs(want)
        return [Row("volume", ok, round(got, 1), f"{want:.1f} ± 0.5%")]


class Watertight:
    def run(self, solid, W):
        topo = solid.topology()
        ok = topo.open_edges == 0 and topo.nonmanifold_edges == 0 and topo.components == 1
        got = f"open {topo.open_edges} nonmanifold {topo.nonmanifold_edges} components {topo.components}"
        return [Row("watertight", ok, got, "closed, one component")]


class Corner:
    def __init__(self, radius):
        self.radius = radius

    def run(self, solid, W):
        expect = self.radius * (math.sqrt(2.0) - 1.0)
        z = PART["H"] / 2.0
        X = PART["X"]
        origins = (
            ((0.0, 0.0, z), (1.0, 1.0, 0.0)),
            ((X, 0.0, z), (-1.0, 1.0, 0.0)),
            ((X, W, z), (-1.0, -1.0, 0.0)),
            ((0.0, W, z), (1.0, -1.0, 0.0)),
        )
        rows = []
        for origin, direction in origins:
            d = np.asarray(direction, float)
            d = d / np.linalg.norm(d)
            hs = solid.hits(np.asarray(origin, float), d)
            got = None if not hs else hs[0]
            ok = got is not None and abs(got - expect) <= CORNER_TOL
            rows.append(Row("corner R10", ok, _fmt(None if got is None else round(got, 3)),
                            f"{expect:.3f} ± {CORNER_TOL}"))
        return rows


class Wall:
    """Thickness = second hit − first hit along one inward ray."""

    def __init__(self, name, origin_of, direction):
        self.name = name
        self.origin_of = origin_of
        self.direction = direction

    def run(self, solid, W):
        origin = np.asarray(self.origin_of(W), float)
        d = np.asarray(self.direction, float)
        d = d / np.linalg.norm(d)
        hs = solid.hits(origin, d)
        if len(hs) < 2:
            return [Row(self.name, False, f"{len(hs)} hits", f"{PART['WALL']:.1f} ± {TOL}")]
        thick = hs[1] - hs[0]
        ok = abs(thick - PART["WALL"]) <= TOL
        return [Row(self.name, ok, round(thick, 3), f"{PART['WALL']:.1f} ± {TOL}")]


def _walls():
    x, h = PART["X"], PART["H"]
    return (
        Wall("wall x", lambda W: (-10.0, 20.0, h / 2.0), (1.0, 0.0, 0.0)),
        Wall("wall x", lambda W: (x + 10.0, 20.0, h / 2.0), (-1.0, 0.0, 0.0)),
        Wall("wall y", lambda W: (x / 2.0, -10.0, h / 2.0), (0.0, 1.0, 0.0)),
        Wall("wall y", lambda W: (x / 2.0, W + 10.0, h / 2.0), (0.0, -1.0, 0.0)),
        Wall("floor", lambda W: (x / 2.0, W / 2.0, -10.0), (0.0, 0.0, 1.0)),
    )


class OpenTop:
    def run(self, solid, W):
        d = np.array((0.0, 0.0, -1.0))
        centre = np.array((PART["X"] / 2.0, W / 2.0, PART["H"] + 10.0))
        hs = solid.hits(centre, d)
        z_floor = None if not hs else centre[2] - hs[0]
        cavity = not solid.inside((PART["X"] / 2.0, W / 2.0, PART["H"] - 2.0))
        rim_o = np.array((PART["WALL"] / 2.0, 20.0, PART["H"] + 10.0))
        hs_rim = solid.hits(rim_o, d)
        z_rim = None if not hs_rim else rim_o[2] - hs_rim[0]
        ok = (
            z_floor is not None and abs(z_floor - PART["WALL"]) <= TOL
            and cavity
            and z_rim is not None and abs(z_rim - PART["H"]) <= TOL
        )
        got = f"floor z { _fmt(None if z_floor is None else round(z_floor, 3)) } cavity {cavity} rim z {_fmt(None if z_rim is None else round(z_rim, 3))}"
        return [Row("open top", ok, got, f"floor z {PART['WALL']}, cavity, rim z {PART['H']}")]


class Hole:
    def run(self, solid, W):
        return [self._axis(solid), self._diameter(solid), self._y_walls(solid, W)]

    def _axis(self, solid):
        # Through-ray plus the void centre. A 3 mm shift still clears a Ø10
        # centre ray, so the centre is what rejects that mutation.
        y, z = PART["HOLE_Y"], PART["HOLE_Z"]
        origin = np.array((-10.0, y, z))
        hs = solid.hits(origin, np.array((1.0, 0.0, 0.0)))
        xs = [-10.0 + t for t in hs]
        blocked = [round(x, 3) for x in xs if -1e-6 <= x <= PART["X"] + 1e-6]
        centres = []
        centre_ok = not blocked
        if centre_ok:
            for x in (PART["WALL"] / 2.0, PART["X"] - PART["WALL"] / 2.0):
                p = np.array((x, y, z))
                if solid.inside(p):
                    centre_ok = False
                    centres.append("solid")
                    break
                cy = _span_centre(solid, p, 1)
                cz = _span_centre(solid, p, 2)
                centres.append((None if cy is None else round(cy, 3),
                                None if cz is None else round(cz, 3)))
                if cy is None or cz is None or abs(cy - y) > TOL or abs(cz - z) > TOL:
                    centre_ok = False
        ok = centre_ok
        return Row("hole axis", ok, f"hits x {blocked or 'none'} centre {centres}",
                   f"through, centre y {y} z {z}")

    def _diameter(self, solid):
        y, z = PART["HOLE_Y"], PART["HOLE_Z"]
        radius = PART["HOLE_D"] / 2.0
        bad = 0
        for x in (PART["WALL"] / 2.0, PART["X"] - PART["WALL"] / 2.0):
            for delta, void in ((radius - TOL, True), (radius + TOL, False)):
                for sign in (-1.0, 1.0):
                    for axis in (1, 2):
                        p = [x, y, z]
                        p[axis] += sign * delta
                        inn = solid.inside(p)
                        if void and inn:
                            bad += 1
                        if not void and not inn:
                            bad += 1
        return Row("hole Ø10", bad == 0, f"{bad} samples off", f"Ø{PART['HOLE_D']:.0f} ± {2 * TOL}")

    def _y_walls(self, solid, W):
        a = solid.inside((PART["X"] / 2.0, PART["WALL"] / 2.0, PART["HOLE_Z"]))
        b = solid.inside((PART["X"] / 2.0, W - PART["WALL"] / 2.0, PART["HOLE_Z"]))
        return Row("hole only in x walls", bool(a and b), f"y-walls solid {bool(a)} {bool(b)}", "both solid")


def _span_centre(solid, origin, axis):
    """Centre of the void along one axis, from the first hits each way."""
    pos = np.zeros(3)
    pos[axis] = 1.0
    hp = solid.hits(origin, pos)
    hn = solid.hits(origin, -pos)
    if not hp or not hn:
        return None
    return float(origin[axis] + (hp[0] - hn[0]) / 2.0)


STAGES = {
    "base": [Bbox(), Volume("block"), Watertight()],
    "rounded": [Bbox(), Corner(PART["R"]), Volume("rounded"), Watertight()],
    "shell": [Bbox(), Corner(PART["R"]), *_walls(), OpenTop(), Volume("no_hole"), Watertight()],
    "final": [Bbox(), Corner(PART["R"]), *_walls(), OpenTop(), Hole(), Volume("final"), Watertight()],
}


def check(stage, solid, width):
    rows = []
    for probe in STAGES[stage]:
        rows.extend(probe.run(solid, width))
    return rows


def _usage(got, want):
    report = R()
    report.add("usage", False, got, want)
    report.show()
    return 1


def _parse_rest(args):
    path = None
    width = 60.0
    i = 0
    while i < len(args):
        if args[i] == "--width":
            if i + 1 >= len(args):
                return None, None, "missing width"
            width = float(args[i + 1])
            i += 2
            continue
        if path is not None:
            return None, None, args[i]
        path = args[i]
        i += 1
    return path, width, None


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    if argv[0] == "params":
        json.dump(params_dict(), sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0
    stage = argv[0]
    if stage not in STAGES:
        return _usage(stage, "base|rounded|shell|final")
    path, width, err = _parse_rest(argv[1:])
    if err or path is None:
        return _usage(err or "missing file", "stage file.3mf [--width 60|65]")
    if abs(width - 60.0) > 1e-9 and abs(width - 65.0) > 1e-9:
        return _usage(width, "60 or 65")
    V, T = load_3mf(path)
    rows = check(stage, TriMesh(V, T), float(width))
    report = R()
    for row in rows:
        report.add(row.name, row.ok, row.got, row.want)
    report.show()
    return 1 if report.fail else 0


if __name__ == "__main__":
    sys.exit(main())
