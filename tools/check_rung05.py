#!/usr/bin/env python3
"""Rung-5 acceptance checks for the UBC pipe section.

Usage:
  python3 tools/check_rung05.py <stage> <file.3mf>
  python3 tools/check_rung05.py params

Stages: cyl, shelled, flange, cut, mirror, reshell, final.
`params` prints PART and VOLUMES as JSON. The walk reads its numbers from there.
Tolerances: 0.2 mm; volume 0.5 %.
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

# One table. Volumes and probes read these numbers; nothing else hard-codes them.
PART = {
    "OD": 150.0,
    "ID": 130.0,
    "WALL": 10.0,
    "L0": 250.0,
    "FLANGE_D": 225.0,
    "FLANGE_T": 10.0,
    "HOLE_D": 10.0,
    "PCD": 94.0,
    "N_HOLES": 8,
    "FILLET": 5.0,
    "TOL": TOL,
    "VOLUME_TOL": VOLUME_TOL,
    "BBOX_MIN": [-112.5, -112.5, -260.0],
    "BBOX_MAX": [112.5, 112.5, 260.0],
    "INSIDE": [
        [70.0, 0.0, 125.0],
        [70.0, 0.0, -125.0],
        [80.0, 0.0, 255.0],
        [80.0, 0.0, -255.0],
    ],
    "OUTSIDE": [
        [0.0, 0.0, 125.0],
        [80.0, 0.0, 125.0],
        [94.0, 0.0, 255.0],
        [113.0, 0.0, 0.0],
        [0.0, 0.0, 261.0],
        [0.0, 0.0, -261.0],
    ],
}

VOLUMES = {
    "cyl": 4417864.669,
    "shelled": 1099557.429,
    "flange": 1497165.249,
    "cut": 1358149.774,
    "mirror": 6034606.788,
    "reshell": 2716299.548,
    "final": 2704332.648,
}

STAGES_ORDER = ("cyl", "shelled", "flange", "cut", "mirror", "reshell", "final")


def params_dict():
    return {"PART": dict(PART), "VOLUMES": dict(VOLUMES)}


def _bbox_want(stage):
    od, fd = PART["OD"], PART["FLANGE_D"]
    l0, ft = PART["L0"], PART["FLANGE_T"]
    if stage in ("cyl", "shelled"):
        half = od / 2.0
        return (-half, -half, 0.0), (half, half, l0)
    if stage in ("flange", "cut"):
        half = fd / 2.0
        return (-half, -half, 0.0), (half, half, l0 + ft)
    return tuple(PART["BBOX_MIN"]), tuple(PART["BBOX_MAX"])


class Bbox(Probe):
    def __init__(self, stage):
        self.stage = stage

    def run(self, solid):
        mn, mx = solid.bbox()
        mn = np.asarray(mn, float)
        mx = np.asarray(mx, float)
        ext = mx - mn
        want_mn, want_mx = (np.array(p, float) for p in _bbox_want(self.stage))
        want_ext = want_mx - want_mn
        ok = bool(np.all(np.abs(mn - want_mn) <= TOL) and np.all(np.abs(ext - want_ext) <= TOL))
        got = f"{ext[0]:.3f}×{ext[1]:.3f}×{ext[2]:.3f} min ({mn[0]:.3f},{mn[1]:.3f},{mn[2]:.3f})"
        want = (
            f"{want_ext[0]:.3f}×{want_ext[1]:.3f}×{want_ext[2]:.3f} "
            f"min ({want_mn[0]:.3f},{want_mn[1]:.3f},{want_mn[2]:.3f}) ± {TOL}"
        )
        return [Row("bbox", ok, got, want)]


class Volume(Probe):
    def __init__(self, stage):
        self.stage = stage

    def run(self, solid):
        got = float(solid.volume())
        want = VOLUMES[self.stage]
        tol = float(PART["VOLUME_TOL"])
        ok = abs(got - want) <= tol * abs(want)
        return [Row("volume", ok, round(got, 3), f"{want:.3f} ± {tol * 100:g}%")]


class Watertight(Probe):
    def run(self, solid):
        topo = solid.topology()
        ok = topo.open_edges == 0 and topo.nonmanifold_edges == 0 and topo.components == 1
        got = f"open {topo.open_edges} nonmanifold {topo.nonmanifold_edges} components {topo.components}"
        return [Row("watertight", ok, got, "closed, one component")]


class Wall(Probe):
    """Ray +X at each z: hits x = ±OD/2, ±ID/2 (the 10 mm tube wall)."""

    def __init__(self, zs):
        self.zs = tuple(zs)

    def run(self, solid):
        r_out = PART["OD"] / 2.0
        r_in = PART["ID"] / 2.0
        want = (-r_out, -r_in, r_in, r_out)
        rows = []
        for z in self.zs:
            origin = np.array((-PART["OD"], 0.0, float(z)))
            xs = [float(origin[0] + t) for t in solid.hits(origin, np.array((1.0, 0.0, 0.0)))]
            if len(xs) != 4:
                rows.append(Row("wall", False, f"{len(xs)} hits {[round(x, 3) for x in xs]}",
                                f"±{r_out:.0f}, ±{r_in:.0f}"))
                continue
            ok = all(abs(g - w) <= TOL for g, w in zip(xs, want))
            rows.append(Row("wall", ok, [round(x, 3) for x in xs],
                            f"±{r_out:.0f}, ±{r_in:.0f} ± {TOL}"))
        return rows


class OpenEnds(Probe):
    def run(self, solid):
        origin = np.array((0.0, 0.0, PART["BBOX_MIN"][2] - 50.0))
        hs = solid.hits(origin, np.array((0.0, 0.0, 1.0)))
        ok = len(hs) == 0
        return [Row("openEnds", ok, f"{len(hs)} axis hits", "through, both ends open")]


class Flange(Probe):
    def __init__(self, signs):
        self.signs = tuple(signs)

    def run(self, solid):
        r = PART["FLANGE_D"] / 2.0
        z_mid = PART["L0"] + PART["FLANGE_T"] / 2.0
        rows = []
        for sign in self.signs:
            z = sign * z_mid
            inn = bool(solid.inside((r - TOL, 0.0, z)))
            out = not bool(solid.inside((r + TOL, 0.0, z)))
            ok = inn and out
            rows.append(Row("flange", ok, f"z={z:g} in {inn} out {out}",
                            f"Ø{PART['FLANGE_D']:.0f} at |z|>{PART['L0']:.0f}"))
        return rows


class BoltRing(Probe):
    def __init__(self, signs):
        self.signs = tuple(signs)

    def run(self, solid):
        n = int(PART["N_HOLES"])
        pcd = PART["PCD"]
        z_mid = PART["L0"] + PART["FLANGE_T"] / 2.0
        bad = 0
        for sign in self.signs:
            z = sign * z_mid
            for k in range(n):
                ang = k * (2.0 * math.pi / n)
                x = pcd * math.sin(ang)
                y = pcd * math.cos(ang)
                if solid.inside((x, y, z)):
                    bad += 1
        return [Row("boltRing", bad == 0, f"{bad} filled", f"{n} empty centres / flange")]


class SolidHalf(Probe):
    def run(self, solid):
        p = (0.0, 0.0, -PART["L0"] / 2.0)
        inn = bool(solid.inside(p))
        return [Row("solidHalf", inn, inn, "inside (0,0,-125)")]


class HollowBoth(Probe):
    def run(self, solid):
        p = (0.0, 0.0, -PART["L0"] / 2.0)
        inn = bool(solid.inside(p))
        return [Row("hollowBoth", not inn, inn, "empty (0,0,-125)")]


def _stage_probes(stage):
    z_half = PART["L0"] / 2.0
    walls = {
        "cyl": (),
        "shelled": (z_half,),
        "flange": (z_half,),
        "cut": (z_half,),
        "mirror": (z_half,),
        "reshell": (z_half, -z_half),
        "final": (z_half, -z_half),
    }[stage]
    open_ends = stage in ("shelled", "cut", "reshell", "final")
    flanges = {
        "cyl": (), "shelled": (),
        "flange": (1.0,), "cut": (1.0,),
        "mirror": (1.0, -1.0), "reshell": (1.0, -1.0), "final": (1.0, -1.0),
    }[stage]
    bolts = {
        "cyl": (), "shelled": (), "flange": (),
        "cut": (1.0,),
        "mirror": (1.0, -1.0), "reshell": (1.0, -1.0), "final": (1.0, -1.0),
    }[stage]
    probes = [Bbox(stage), Volume(stage), Watertight()]
    if walls:
        probes.append(Wall(walls))
    if open_ends:
        probes.append(OpenEnds())
    if flanges:
        probes.append(Flange(flanges))
    if bolts:
        probes.append(BoltRing(bolts))
    if stage == "mirror":
        probes.append(SolidHalf())
    if stage in ("reshell", "final"):
        probes.append(HollowBoth())
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
