#!/usr/bin/env python3
"""Rung-3 acceptance checks for the Lesson 1 part (video depth 30).

Usage:
  python3 tools/check_rung03.py <stage> <file.3mf>
  python3 tools/check_rung03.py params

Stages: base, boss, cut, r5, rounded, final.
`params` prints PART and VOLUMES as JSON. The walk reads its numbers from there.
Tolerances: 0.2 mm; volume 0.5 % (solids) and 1.5 % (final).
"""
import argparse
import json
import math
import sys

import numpy as np

from geom import Report, Row, load_3mf
from solid import Probe, TriMesh


TOL = 0.2
VOLUME_TOL = 0.005
FINAL_VOLUME_TOL = 0.015
CORNER_TOL = 0.083  # 0.2 * (sqrt(2) - 1), the R5 ± 0.2 band
ANNULUS_TOL = 0.06
WALL_TOL = 0.1
_SQRT2 = math.sqrt(2.0)
_FILLET = _SQRT2 - 1.0  # distance from a sharp corner to its fillet, / R

# One table. Volumes and probes read these numbers; nothing else hard-codes them.
PART = {
    "SIDE": 120.0,
    "H0": 30.0,
    "BOSS_D": 70.0,
    "BOSS_H": 25.0,
    "TOP": 55.0,
    "HOLE_D": 60.0,
    "OFFSET": 5.0,
    "R_BIG": 5.0,
    "R_SMALL": 1.5,
    "WALL": 1.0,
    "OPEN": "-Z",
    "TOL": TOL,
    "VOLUME_TOL": VOLUME_TOL,
    "FINAL_VOLUME_TOL": FINAL_VOLUME_TOL,
}

VOLUMES = {
    "base": 432000.0,
    "boss": 528211.3,
    "cut": 372702.4,
    "r5": 370784.6,
    "rounded": 370587.4,
    "final": 39311.0,
}

STAGES_ORDER = ("base", "boss", "cut", "r5", "rounded", "final")


def params_dict():
    return {"PART": dict(PART), "VOLUMES": dict(VOLUMES)}


def _fmt(value):
    if value is None:
        return "none"
    if isinstance(value, float):
        return round(value, 4)
    return value


def _unit(direction):
    d = np.asarray(direction, float)
    return d / np.linalg.norm(d)


def _clearance(solid, corner, direction, start):
    """How far past the sharp corner the first hit sits, along `direction`."""
    u = _unit(direction)
    origin = np.asarray(corner, float) + start * u
    hs = solid.hits(origin, -u)
    if not hs:
        return None
    return float(hs[0]) - start


def _raw_t(solid, corner, direction, start):
    u = _unit(direction)
    origin = np.asarray(corner, float) + start * u
    hs = solid.hits(origin, -u)
    if not hs:
        return None
    return float(hs[0])


def _axis_hits(solid, origin, direction, axis):
    d = _unit(direction)
    origin = np.asarray(origin, float)
    return [float(origin[axis] + t * d[axis]) for t in solid.hits(origin, d)]


class Bbox(Probe):
    def __init__(self, height):
        self.height = float(height)

    def run(self, solid):
        mn, mx = solid.bbox()
        ext = np.asarray(mx, float) - np.asarray(mn, float)
        mn = np.asarray(mn, float)
        half = PART["SIDE"] / 2.0
        ok = (
            abs(ext[0] - PART["SIDE"]) <= TOL
            and abs(ext[1] - PART["SIDE"]) <= TOL
            and abs(ext[2] - self.height) <= TOL
            and abs(mn[0] + half) <= TOL
            and abs(mn[1] + half) <= TOL
            and abs(mn[2]) <= TOL
        )
        got = f"{ext[0]:.3f}×{ext[1]:.3f}×{ext[2]:.3f} min ({mn[0]:.3f},{mn[1]:.3f},{mn[2]:.3f})"
        want = f"{PART['SIDE']:.0f}×{PART['SIDE']:.0f}×{self.height:.0f} min ({-half:.0f},{-half:.0f},0) ± {TOL}"
        return [Row("bbox", ok, got, want)]


class Volume(Probe):
    def __init__(self, stage):
        self.stage = stage

    def run(self, solid):
        got = float(solid.volume())
        want = VOLUMES[self.stage]
        tol = FINAL_VOLUME_TOL if self.stage == "final" else VOLUME_TOL
        ok = abs(got - want) <= tol * abs(want)
        pct = tol * 100.0
        return [Row("volume", ok, round(got, 1), f"{want:.1f} ± {pct:g}%")]


class Watertight(Probe):
    def run(self, solid):
        topo = solid.topology()
        ok = topo.open_edges == 0 and topo.nonmanifold_edges == 0 and topo.components == 1
        got = f"open {topo.open_edges} nonmanifold {topo.nonmanifold_edges} components {topo.components}"
        return [Row("watertight", ok, got, "closed, one component")]


class Boss(Probe):
    def run(self, solid):
        rb = PART["BOSS_D"] / 2.0
        z = PART["H0"] + 0.6 * PART["BOSS_H"]  # 45, mid-boss, clear of both fillets
        top = PART["TOP"]
        samples = []
        bad = 0
        for sign in (-1.0, 1.0):
            for delta, want_in in ((-TOL, True), (TOL, False)):
                p = (sign * (rb + delta), 0.0, z)
                inn = bool(solid.inside(p))
                samples.append(inn)
                if inn != want_in:
                    bad += 1
        rho = (rb + PART["HOLE_D"] / 2.0) / 2.0  # 32.5, on the flat top
        z_top = _first_z(solid, (rho, 0.0, top + 15.0))
        z_front = _first_z(solid, (rb + 2.0 * PART["R_BIG"], 0.0, top + 15.0))
        ok = (
            bad == 0
            and z_top is not None and abs(z_top - top) <= TOL
            and z_front is not None and abs(z_front - PART["H0"]) <= TOL
        )
        got = f"samples {samples} top z {_fmt(None if z_top is None else round(z_top, 3))} front z {_fmt(None if z_front is None else round(z_front, 3))}"
        want = f"r {rb:.0f} ± {TOL}, top z {top:.0f}, front z {PART['H0']:.0f}"
        return [Row("boss", ok, got, want)]


class Hole(Probe):
    def run(self, solid):
        hr = PART["HOLE_D"] / 2.0
        zs = (
            2.0 * PART["WALL"],
            PART["H0"] / 2.0,
            PART["H0"] - 2.0 * PART["WALL"],
            PART["H0"] + 12.0,
            PART["TOP"] - 2.0,
        )
        bad = 0
        for z in zs:
            if solid.inside((hr - TOL, 0.0, z)):
                bad += 1
            if not solid.inside((hr + TOL, 0.0, z)):
                bad += 1
        hs = solid.hits(np.array((0.0, 0.0, -10.0)), np.array((0.0, 0.0, 1.0)))
        ok = bad == 0 and len(hs) == 0
        return [Row("hole Ø60", ok, f"{bad} samples off, axis hits {len(hs)}",
                     f"Ø{PART['HOLE_D']:.0f} ± {2 * TOL}, no axis hits")]


class CornerVertical(Probe):
    def run(self, solid):
        half = PART["SIDE"] / 2.0
        z = PART["H0"] / 2.0
        expect = PART["R_BIG"] * _FILLET
        rows = []
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                corner = (sx * half, sy * half, z)
                got = _clearance(solid, corner, (sx, sy, 0.0), 3.0)
                ok = got is not None and abs(got - expect) <= CORNER_TOL
                rows.append(Row("corner R5 vertical", ok, _fmt(None if got is None else round(got, 3)),
                                f"{expect:.3f} ± {CORNER_TOL}"))
        return rows


class EdgeFront(Probe):
    def run(self, solid):
        half = PART["SIDE"] / 2.0
        h0 = PART["H0"]
        expect = PART["R_BIG"] * _FILLET
        specs = (
            ((half, 0.0, h0), (1.0, 0.0, 1.0)),
            ((-half, 0.0, h0), (-1.0, 0.0, 1.0)),
            ((0.0, half, h0), (0.0, 1.0, 1.0)),
            ((0.0, -half, h0), (0.0, -1.0, 1.0)),
        )
        rows = []
        for corner, direction in specs:
            got = _clearance(solid, corner, direction, 3.0)
            ok = got is not None and abs(got - expect) <= CORNER_TOL
            rows.append(Row("edge R5 front", ok, _fmt(None if got is None else round(got, 3)),
                            f"{expect:.3f} ± {CORNER_TOL}"))
        return rows


class RootFillet(Probe):
    def run(self, solid):
        rb = PART["BOSS_D"] / 2.0
        start = 10.0
        expect = start - PART["R_BIG"] * _FILLET
        got = _raw_t(solid, (rb, 0.0, PART["H0"]), (1.0, 0.0, 1.0), start)
        ok = got is not None and abs(got - expect) <= CORNER_TOL
        return [Row("root R5", ok, _fmt(None if got is None else round(got, 3)),
                    f"{expect:.3f} ± {CORNER_TOL}")]


class Annulus(Probe):
    def run(self, solid):
        top = PART["TOP"]
        start = 5.0
        expect = start + PART["R_SMALL"] * _FILLET
        specs = (
            ((PART["BOSS_D"] / 2.0, 0.0, top), (1.0, 0.0, 1.0)),
            ((PART["HOLE_D"] / 2.0, 0.0, top), (-1.0, 0.0, 1.0)),
        )
        rows = []
        for corner, direction in specs:
            got = _raw_t(solid, corner, direction, start)
            ok = got is not None and abs(got - expect) <= ANNULUS_TOL
            rows.append(Row("annulus R1.5", ok, _fmt(None if got is None else round(got, 3)),
                            f"{expect:.3f} ± {ANNULUS_TOL}"))
        return rows


def _pair_rows(solid, name, origin, direction, axis, expected):
    got = _axis_hits(solid, origin, direction, axis)
    if len(got) != len(expected):
        return [Row(name, False, _hit_text(got), _hit_text(expected))]
    rows = []
    for i in range(0, len(expected), 2):
        thick = got[i + 1] - got[i]
        want = expected[i + 1] - expected[i]
        placed = abs(got[i] - expected[i]) <= WALL_TOL and abs(got[i + 1] - expected[i + 1]) <= WALL_TOL
        ok = placed and abs(thick - want) <= WALL_TOL
        rows.append(Row(name, ok, round(thick, 3), f"{want:.1f} ± {WALL_TOL}"))
    return rows


def _hit_text(values):
    return "[" + ", ".join(f"{v:.3f}" for v in values) + "]"


class WallX(Probe):
    def run(self, solid):
        half = PART["SIDE"] / 2.0
        w = PART["WALL"]
        hr = PART["HOLE_D"] / 2.0
        z = PART["H0"] / 2.0
        xs = [-half, -half + w, -(hr + w), -hr, hr, hr + w, half - w, half]
        x_rows = _pair_rows(
            solid, "wall x", (-half - 10.0, 0.0, z), (1.0, 0.0, 0.0), 0, xs)
        ys = [-half, -half + w, half - w, half]
        x = PART["BOSS_D"] / 2.0 + 2.0 * PART["R_BIG"]
        y_rows = _pair_rows(
            solid, "wall x", (x, -half - 10.0, z), (0.0, 1.0, 0.0), 1, ys)
        return x_rows + y_rows


class WallBoss(Probe):
    def run(self, solid):
        rb = PART["BOSS_D"] / 2.0
        hr = PART["HOLE_D"] / 2.0
        w = PART["WALL"]
        z = PART["H0"] + 0.6 * PART["BOSS_H"]
        xs = [-rb, -rb + w, -(hr + w), -hr, hr, hr + w, rb - w, rb]
        return _pair_rows(
            solid, "wall boss", (-rb - 10.0, 0.0, z), (1.0, 0.0, 0.0), 0, xs)


class WallCorner(Probe):
    def run(self, solid):
        half = PART["SIDE"] / 2.0
        radius = PART["R_BIG"]
        start = half - 2.0 * radius
        core = half - radius
        dist = (core - start) * _SQRT2
        expect = [dist + (radius - PART["WALL"]), dist + radius]
        origin = np.array((start, start, PART["H0"] / 2.0))
        d = _unit((1.0, 1.0, 0.0))
        got = solid.hits(origin, d)
        thick = None if len(got) < 2 else got[1] - got[0]
        placed = (
            len(got) >= 2
            and abs(got[0] - expect[0]) <= WALL_TOL
            and abs(got[1] - expect[1]) <= WALL_TOL
        )
        ok = placed and thick is not None and abs(thick - PART["WALL"]) <= WALL_TOL
        got_txt = "none" if thick is None else f"{thick:.3f} at {[round(t, 3) for t in got[:2]]}"
        return [Row("wall corner", ok, got_txt, f"{PART['WALL']:.1f} ± {WALL_TOL}")]


class Plates(Probe):
    def run(self, solid):
        w = PART["WALL"]
        h0 = PART["H0"]
        top = PART["TOP"]
        x_plate = PART["BOSS_D"] / 2.0 + 2.0 * PART["R_BIG"]
        x_boss = (PART["BOSS_D"] / 2.0 + PART["HOLE_D"] / 2.0) / 2.0
        rays = (
            (x_plate, [h0 - w, h0]),
            (x_boss, [top - w, top]),
        )
        bad = []
        for x, expect in rays:
            got = _z_hits(solid, x, 0.0)
            if not _z_match(got, expect):
                bad.append((round(x, 2), [round(z, 3) for z in got]))
        ok = not bad
        return [Row("plates", ok, bad or "29/30 and 54/55", "1.0 ± 0.1, nothing below the plate")]


class OpenBack(Probe):
    def run(self, solid):
        half = PART["SIDE"] / 2.0
        w = PART["WALL"]
        h0 = PART["H0"]
        x = PART["BOSS_D"] / 2.0 + 2.0 * PART["R_BIG"]
        cavity = not solid.inside((x, 0.0, h0 / 2.0))
        zs = _z_hits(solid, x, 0.0)
        z_plate = None if not zs else zs[0]
        plate_ok = z_plate is not None and abs(z_plate - (h0 - w)) <= TOL
        x_rim = -(half - w / 2.0)
        rim = _z_hits(solid, x_rim, 0.0)
        z_enter = None if not rim else rim[0]
        z_leave = None if len(rim) < 2 else rim[1]
        expect_leave = _rim_leave_z()
        rim_ok = (
            z_enter is not None and abs(z_enter) <= TOL
            and z_leave is not None and abs(z_leave - expect_leave) <= 0.3
        )
        ok = cavity and plate_ok and rim_ok
        got = (
            f"cavity {cavity} plate z {_fmt(None if z_plate is None else round(z_plate, 3))} "
            f"rim {_fmt(None if z_enter is None else round(z_enter, 3))}.."
            f"{_fmt(None if z_leave is None else round(z_leave, 3))}"
        )
        return [Row("open back", ok, got, f"void, plate z {h0 - w:.0f}, rim 0..{expect_leave:.2f}")]


def _first_z(solid, origin):
    origin = np.asarray(origin, float)
    hs = solid.hits(origin, np.array((0.0, 0.0, -1.0)))
    if not hs:
        return None
    return float(origin[2] - hs[0])


def _z_hits(solid, x, y):
    origin = np.array((x, y, -10.0))
    return [float(-10.0 + t) for t in solid.hits(origin, np.array((0.0, 0.0, 1.0)))]


def _z_match(got, expect):
    if len(got) < len(expect):
        return False
    if got[0] < expect[0] - TOL:
        return False
    return all(abs(g - e) <= WALL_TOL for g, e in zip(got, expect))


def _rim_leave_z():
    """Outer R5 fillet, 0.5 mm in from the side face. Analytic, from PART."""
    half = PART["SIDE"] / 2.0
    radius = PART["R_BIG"]
    x = -(half - PART["WALL"] / 2.0)
    cx = -(half - radius)
    cz = PART["H0"] - radius
    dz = math.sqrt(radius * radius - (x - cx) ** 2)
    return cz + dz


def _stage_probes(stage):
    height = PART["H0"] if stage == "base" else PART["TOP"]
    probes = [Bbox(height)]
    if stage != "base":
        probes.append(Boss())
    if stage not in ("base", "boss"):
        probes.append(Hole())
    if stage in ("r5", "rounded", "final"):
        probes.extend((CornerVertical(), EdgeFront(), RootFillet()))
    if stage in ("rounded", "final"):
        probes.append(Annulus())
    if stage == "final":
        probes.extend((WallX(), WallBoss(), WallCorner(), Plates(), OpenBack()))
    probes.extend((Volume(stage), Watertight()))
    return probes


STAGES = {stage: _stage_probes(stage) for stage in STAGES_ORDER}


def check(stage, solid):
    return [row for probe in STAGES[stage] for row in probe.run(solid)]


_FILE_WANT = "stage file.3mf"
_STAGE_WANT = "|".join(STAGES_ORDER)


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
        return "missing file", _FILE_WANT
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
    parser.add_argument("stage", choices=STAGES_ORDER + ("params",))
    parser.add_argument("file", nargs="?")
    try:
        args = parser.parse_args(argv)
        if args.file is None:
            parser.fail_usage("missing file", _FILE_WANT)
    except SystemExit as exc:
        return exc.code
    V, T = load_3mf(args.file)
    report = Report()
    report.extend(check(args.stage, TriMesh(V, T)))
    report.show()
    return 1 if report.fail else 0


if __name__ == "__main__":
    sys.exit(main())
