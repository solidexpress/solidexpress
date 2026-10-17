#!/usr/bin/env python3
"""Rung-6 acceptance checks for the candlestick (Revolve & Sweep).

Usage:
  python3 tools/check_rung06.py <stage> <file.3mf>
  python3 tools/check_rung06.py params

Stages: revolve, sweep, final.
`params` prints PART and VOLUMES as JSON. The walk reads its numbers from there.
Tolerances: 0.2 mm; volume 0.5 % after the OCCT replica.
"""
import argparse
import json
import sys

import numpy as np

from geom import Report, Row, load_3mf
from solid import Probe, TriMesh


TOL = 0.2
VOLUME_TOL = 0.005

# One table. Volumes and probes read these numbers; nothing else hard-codes them.
PART = {
    "H": 220.0,
    "TOP_R": 20.0,
    "BASE_R": 90.0,
    "R10": 10.0,
    "UPPER": 40.0,
    "R20": 20.0,
    "LOWER": 50.0,
    "R60": 60.0,
    "R12": 12.5,
    "PATH_Y": 10.0,
    "PATH_60": 60.0,
    "PATH_R150": 150.0,
    "PATH_65": 65.0,
    "PATH_R20": 20.0,
    "ELLIPSE_MAJ": 35.0,
    "ELLIPSE_MIN": 10.0,
    "CUT_D": 30.0,
    "CUT_H": 25.0,
    "CUT_DRAFT_DEG": 15.0,
    "AREA": 9588.322,
    "XBAR": 28.064,
    "V_REV": 1690750.0,
    "V_HANDLE": 50548.0,
    "V_CUT": 10954.475,
    "VOLUME": 1730343.0,
    "VOL_UNCLIP": 1726807.0,
    "VOL_NODRAFT_DELTA": 17671.459,
    "TOL": TOL,
    "VOLUME_TOL": VOLUME_TOL,
    "BBOX_MIN": [-112.0, 0.0, -112.0],
    "BBOX_MAX": [192.1, 220.0, 112.0],
    "REVOLVE_BBOX_MAX": [112.0, 220.0, 112.0],
    "INSIDE": [
        [0.0, 100.0, 0.0],
        [40.0, 10.0, 0.0],
        [18.0, 215.0, 0.0],
    ],
    "OUTSIDE": [
        [113.0, 10.0, 0.0],
        [0.0, 221.0, 0.0],
        [0.0, 205.0, 0.0],
        [193.0, 86.0, 0.0],
    ],
    "DRAFT_HOLE": [13.0, 195.0, 0.0],
    "HANDLE_XMAX_MIN": 180.0,
}

VOLUMES = {
    "revolve": PART["V_REV"],
    "sweep": PART["V_REV"] + PART["V_HANDLE"],
    "final": PART["VOLUME"],
}

STAGES_ORDER = ("revolve", "sweep", "final")


def params_dict():
    return {"PART": dict(PART), "VOLUMES": dict(VOLUMES)}


def _bbox_want(stage):
    mn = tuple(PART["BBOX_MIN"])
    if stage == "revolve":
        return mn, tuple(PART["REVOLVE_BBOX_MAX"])
    return mn, tuple(PART["BBOX_MAX"])


def _fmt_point(point):
    return f"({point[0]:.3f},{point[1]:.3f},{point[2]:.3f})"


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


class Inside(Probe):
    def run(self, solid):
        points = PART["INSIDE"]
        flags = [bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'in' if flag else 'out'}" for p, flag in zip(points, flags))
        return [Row("inside", all(flags), got, "stem, base, top cylinder")]


class Outside(Probe):
    def run(self, solid):
        points = PART["OUTSIDE"]
        flags = [not bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'out' if flag else 'in'}" for p, flag in zip(points, flags))
        return [Row("outside", all(flags), got, "past rim, above, frustum, past scroll")]


class HandleSide(Probe):
    def run(self, solid):
        _mn, mx = solid.bbox()
        xmax = float(np.asarray(mx, float)[0])
        want = float(PART["HANDLE_XMAX_MIN"])
        ok = xmax >= want
        return [Row("handleSide", ok, round(xmax, 3), f"xmax ≥ {want:g} (+X handle)")]


class DraftHole(Probe):
    def run(self, solid):
        p = PART["DRAFT_HOLE"]
        inn = bool(solid.inside(p))
        return [Row("draftHole", inn, f"{_fmt_point(p)} {'in' if inn else 'out'}",
                    "inside (drafted wall, empty if straight)")]


def _stage_probes(stage):
    probes = [Bbox(stage), Volume(stage), Watertight()]
    if stage in ("sweep", "final"):
        probes.append(HandleSide())
    if stage == "final":
        probes.extend([Inside(), Outside(), DraftHole()])
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
