#!/usr/bin/env python3
"""Rung-4 acceptance checks for the hex key (Swept Boss).

Usage:
  python3 tools/check_rung04.py <stage> <file.3mf>
  python3 tools/check_rung04.py params

Stages: final.
`params` prints PART as JSON. The walk reads its numbers from there.
Tolerances: 0.2 mm; volume 0.5 %.
"""
import argparse
import json
import sys

import numpy as np

from geom import Report, Row, load_3mf
from solid import Probe, TriMesh


TOL = 0.2
VOLUME_TOL = 0.005

# One table. Probes read these numbers; nothing else hard-codes them.
PART = {
    "AF": 7.65,
    "R": 4.416730,
    "LEG_Z": 37.0,
    "LEG_Y": 94.0,
    "BEND_D": 30.0,
    "AREA": 50.681972,
    "LENGTH": 124.561945,
    "VOLUME": 6313.045,
    "VOL_TOP": 6664.665,
    "VOL_BOT": 5961.424,
    "TOL": TOL,
    "VOLUME_TOL": VOLUME_TOL,
    "BBOX_MIN": [-3.825, -4.416730, 0.0],
    "BBOX_MAX": [3.825, 94.0, 41.416730],
    "INSIDE": [
        [0.0, 0.0, 5.0],
        [0.0, 4.393, 32.607],
        [0.0, 50.0, 37.0],
    ],
    "OUTSIDE": [
        [3.9, 0.0, 5.0],
        [0.0, -4.5, 5.0],
        [0.0, 50.0, 42.0],
        [0.0, 95.0, 37.0],
    ],
}

STAGES_ORDER = ("final",)


def params_dict():
    return {"PART": dict(PART)}


def _fmt_point(point):
    return f"({point[0]:.3f},{point[1]:.3f},{point[2]:.3f})"


class Bbox(Probe):
    def run(self, solid):
        mn, mx = solid.bbox()
        mn = np.asarray(mn, float)
        mx = np.asarray(mx, float)
        ext = mx - mn
        want_mn = np.array(PART["BBOX_MIN"], float)
        want_mx = np.array(PART["BBOX_MAX"], float)
        want_ext = want_mx - want_mn
        ok = bool(np.all(np.abs(mn - want_mn) <= TOL) and np.all(np.abs(ext - want_ext) <= TOL))
        got = (
            f"{ext[0]:.3f}×{ext[1]:.3f}×{ext[2]:.3f} "
            f"min ({mn[0]:.6f},{mn[1]:.6f},{mn[2]:.6f})"
        )
        want = (
            f"{want_ext[0]:.3f}×{want_ext[1]:.3f}×{want_ext[2]:.3f} "
            f"min ({want_mn[0]:.6f},{want_mn[1]:.6f},{want_mn[2]:.6f}) ± {TOL}"
        )
        return [Row("bbox", ok, got, want)]


class Volume(Probe):
    def run(self, solid):
        got = float(solid.volume())
        want = float(PART["VOLUME"])
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
        return [Row("inside", all(flags), got, "all three on the centred spine")]


class Outside(Probe):
    def run(self, solid):
        points = PART["OUTSIDE"]
        flags = [not bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'out' if flag else 'in'}" for p, flag in zip(points, flags))
        return [Row("outside", all(flags), got, "all four outside the hex")]


STAGES = {"final": [Bbox(), Volume(), Watertight(), Inside(), Outside()]}


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
