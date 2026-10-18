#!/usr/bin/env python3
"""Rung-7 acceptance checks for the combination spanner.

Usage:
  python3 tools/check_rung07.py <stage> <file.3mf>
  python3 tools/check_rung07.py params

Stages: boss, neck, mirror, final.
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
    "ELLIPSE_MAJ": 55.0,
    "ELLIPSE_MIN": 50.0,
    "ANGLE_DEG": 17.0,
    "JAW_OFF": 12.5,
    "JAW_LEN": 20.0,
    "R15": 15.0,
    "RING_D": 33.0,
    "HEX_AF": 25.0,
    "CENTER": 240.0,
    "HANDLE_HALF": 10.0,
    "HEAD_T": 10.0,
    "HANDLE_T": 6.0,
    "R30": 30.0,
    "R20": 20.0,
    "OFFSET": 5.0,
    "CUT_D": 1.0,
    "R3": 3.0,
    "R1": 1.0,
    "A_C": 1495.80,
    "A_RING": 275.172,
    "A_H": 3999.25,
    "V_C": 14958.0,
    "V_RING": 2752.0,
    "V_H": 23996.0,
    "V_BOSS": 41705.0,
    "V_30": 858.0,
    "V_20": 170.0,
    "V_NECK": 42733.0,
    "V_RECESS": 3791.02,
    "V_R3": 15.45,
    "V_MIRROR": 38957.0,
    "V_R1": 176.0,
    "VOLUME": 38782.0,
    "VOID_ELL_DEG": 112.42,
    "VOID_CIR_DEG": 127.31,
    "VOL_90NECK": 41102.0,
    "VOL_PREP": 4.09e4,
    "TOL": TOL,
    "VOLUME_TOL": VOLUME_TOL,
    "BBOX_MIN": [-24.95, -27.30, -5.00],
    "BBOX_SIZE": [281.4, 54.6, 10.0],
    "HANDLE_XMAX_MIN": 250.0,
    "OPEN_XMIN_MAX": -24.5,
    "INSIDE": [
        [0.0, 18.0, 0.0],
        [120.0, 0.0, 0.0],
        [240.0, 15.0, 0.0],
    ],
    "OUTSIDE": [
        [-30.0, 0.0, 0.0],
        [240.0, 0.0, 0.0],
        [270.0, 0.0, 0.0],
        [0.0, 0.0, 8.0],
        [120.0, 0.0, 4.0],
        [120.0, 0.0, 2.5],
        [120.0, 0.0, -2.5],
    ],
    "RECESS": [
        [120.0, 0.0, 2.5],
        [120.0, 0.0, -2.5],
    ],
}

VOLUMES = {
    "boss": PART["V_BOSS"],
    "neck": PART["V_NECK"],
    "mirror": PART["V_MIRROR"],
    "final": PART["VOLUME"],
}

STAGES_ORDER = ("boss", "neck", "mirror", "final")


def params_dict():
    return {"PART": dict(PART), "VOLUMES": dict(VOLUMES)}


def _bbox_want():
    mn = np.array(PART["BBOX_MIN"], float)
    ext = np.array(PART["BBOX_SIZE"], float)
    return mn, ext


def _fmt_point(point):
    return f"({point[0]:.3f},{point[1]:.3f},{point[2]:.3f})"


class Bbox(Probe):
    def run(self, solid):
        mn, mx = solid.bbox()
        mn = np.asarray(mn, float)
        mx = np.asarray(mx, float)
        ext = mx - mn
        want_mn, want_ext = _bbox_want()
        ok = bool(np.all(np.abs(mn - want_mn) <= TOL) and np.all(np.abs(ext - want_ext) <= TOL))
        got = f"{ext[0]:.3f}×{ext[1]:.3f}×{ext[2]:.3f} min ({mn[0]:.3f},{mn[1]:.3f},{mn[2]:.3f})"
        want = (
            f"{want_ext[0]:.1f}×{want_ext[1]:.1f}×{want_ext[2]:.1f} "
            f"min ({want_mn[0]:.2f},{want_mn[1]:.2f},{want_mn[2]:.2f}) ± {TOL}"
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
        return [Row("inside", all(flags), got, "C body, handle core, ring wall")]


class Outside(Probe):
    def run(self, solid):
        points = PART["OUTSIDE"]
        flags = [not bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'out' if flag else 'in'}" for p, flag in zip(points, flags))
        return [Row("outside", all(flags), got, "past jaws, bore, past ring, above, recess")]


class HandleSide(Probe):
    def run(self, solid):
        _mn, mx = solid.bbox()
        xmax = float(np.asarray(mx, float)[0])
        want = float(PART["HANDLE_XMAX_MIN"])
        ok = xmax >= want
        return [Row("handleSide", ok, round(xmax, 3), f"xmax ≥ {want:g} (+X handle)")]


class OpenEnd(Probe):
    def run(self, solid):
        mn, _mx = solid.bbox()
        xmin = float(np.asarray(mn, float)[0])
        want = float(PART["OPEN_XMIN_MAX"])
        ok = xmin <= want
        return [Row("openEnd", ok, round(xmin, 3), f"xmin ≤ {want:g} (−X open end)")]


class RecessBoth(Probe):
    def run(self, solid):
        points = PART["RECESS"]
        flags = [not bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'out' if flag else 'in'}" for p, flag in zip(points, flags))
        return [Row("recessBoth", all(flags), got, "both handle faces empty at z=±2.5")]


def _stage_probes(stage):
    probes = [Bbox(), Volume(stage), Watertight(), HandleSide(), OpenEnd()]
    if stage in ("mirror", "final"):
        probes.append(RecessBoth())
    if stage == "final":
        probes.extend([Inside(), Outside()])
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
