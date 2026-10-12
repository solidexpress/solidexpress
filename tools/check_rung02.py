#!/usr/bin/env python3
"""Rung-2 acceptance checks for the Lesson 2 box.

Usage:
  python3 tools/check_rung02.py <stage> <file.3mf> [--width W]
  python3 tools/check_rung02.py params

Stages: base, rounded, shell, final. Width is 60 or 65 (default 60).
`params` prints the PART table as JSON. Tolerances: 0.2 mm, volume 0.5 %.
"""
import argparse
import json
import math
import sys

import numpy as np

from geom import Report, Row, load_3mf
from solid import Solid, TriMesh

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


def _fmt(value):
    if value is None:
        return "none"
    if isinstance(value, float):
        return round(value, 4)
    return value


class Bbox:
    def run(self, solid: Solid, W):
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

    def run(self, solid: Solid, W):
        got = float(solid.volume())
        want = volumes(W)[self.kind]
        ok = abs(got - want) <= VOLUME_TOL * abs(want)
        return [Row("volume", ok, round(got, 1), f"{want:.1f} ± 0.5%")]


class Watertight:
    def run(self, solid: Solid, W):
        topo = solid.topology()
        ok = topo.open_edges == 0 and topo.nonmanifold_edges == 0 and topo.components == 1
        got = f"open {topo.open_edges} nonmanifold {topo.nonmanifold_edges} components {topo.components}"
        return [Row("watertight", ok, got, "closed, one component")]


class Corner:
    def __init__(self, radius):
        self.radius = radius

    def run(self, solid: Solid, W):
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

    def run(self, solid: Solid, W):
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
    def run(self, solid: Solid, W):
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
    def run(self, solid: Solid, W):
        return [self._axis(solid), self._diameter(solid), self._y_walls(solid, W)]

    def _axis(self, solid: Solid):
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

    def _diameter(self, solid: Solid):
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

    def _y_walls(self, solid: Solid, W):
        a = solid.inside((PART["X"] / 2.0, PART["WALL"] / 2.0, PART["HOLE_Z"]))
        b = solid.inside((PART["X"] / 2.0, W - PART["WALL"] / 2.0, PART["HOLE_Z"]))
        return Row("hole only in x walls", bool(a and b), f"y-walls solid {bool(a)} {bool(b)}", "both solid")


def _span_centre(solid: Solid, origin, axis):
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


def check(stage, solid: Solid, width):
    return [row for probe in STAGES[stage] for row in probe.run(solid, width)]


_FILE_WANT = "stage file.3mf [--width 60|65]"
_STAGE_WANT = "base|rounded|shell|final"


class UsageParser(argparse.ArgumentParser):
    """Bad input prints one usage row and exits 1."""

    def fail_usage(self, got, want):
        self._usage = (got, want)
        self.error("usage-row")

    def error(self, message):
        got, want = getattr(self, "_usage", None) or _builtin_usage(message)
        report = Report()
        report.add("usage", False, got, want)
        report.show()
        raise SystemExit(1)

    def parse_args(self, args=None, namespace=None):
        args = list(sys.argv[1:] if args is None else args)
        if args and args[0].startswith("-"):
            self.fail_usage(args[0], _STAGE_WANT)
        return super().parse_args(args, namespace)


def _builtin_usage(message):
    if "expected one argument" in message:
        return "missing width", _FILE_WANT
    if message.startswith("unrecognized arguments:"):
        return message.split(":", 1)[1].strip().split()[0], _FILE_WANT
    if "invalid choice:" in message:
        return message.split("invalid choice: '", 1)[1].split("'", 1)[0], _STAGE_WANT
    return message, _FILE_WANT


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 2
    if argv[0] == "params":
        json.dump(params_dict(), sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 0
    parser = UsageParser(add_help=False)
    parser.add_argument("stage", choices=("base", "rounded", "shell", "final", "params"))
    parser.add_argument("file", nargs="?")
    parser.add_argument("--width", default="60")
    try:
        args = parser.parse_args(argv)
        if args.file is None:
            parser.fail_usage("missing file", _FILE_WANT)
        width = float(args.width)
        if abs(width - 60.0) > 1e-9 and abs(width - 65.0) > 1e-9:
            parser.fail_usage(width, "60 or 65")
    except SystemExit as exc:
        return exc.code
    V, T = load_3mf(args.file)
    report = Report()
    report.extend(check(args.stage, TriMesh(V, T), float(width)))
    report.show()
    return 1 if report.fail else 0


if __name__ == "__main__":
    sys.exit(main())
