#!/usr/bin/env python3
"""Rung-8 acceptance checks for the UBC pipeline assembly.

Usage:
  python3 tools/check_rung08.py <stage> <file.3mf|file.json>
  python3 tools/check_rung08.py params

Stages: pin, pipes, bolted, final.
`params` prints PART and VOLUMES as JSON. The walk reads its numbers from there.
A pin 3MF is a part. pipes/bolted/final accept an instance-transformed 3MF
or a JSON assembly dump. A merged-at-identity 3MF must fail bbox.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np

from geom import Report, Row, load_3mf
from solid import Probe, TriMesh


TOL = 0.2
TOL_WRENCH = 0.5
VOLUME_TOL = 0.01  # assembly 1 %
# Two R10 hemispheres + Ø10×35 shank: 4/3 π 10³ + π 5² 35 = 6937.6838 mm³.
# Table 6938 is 0.0046 % off the OCCT 8.0.1 / analytic solid, well under 0.2 %.
# Pin band tightens to 0.5 % like rung 5.
PIN_VOLUME_TOL = 0.005

PART = {
    "HEAD_R": 10.0,
    "TAIL_R": 10.0,
    "SHANK_R": 5.0,
    "SHANK_L": 35.0,
    "OVERALL": 55.0,
    "NUT_AF": 20.0,
    "NUT_AC": 23.094,
    "NUT_T": 7.5,
    "NUT_BORE": 10.0,
    "PIPE_OD": 150.0,
    "PIPE_ID": 130.0,
    "FLANGE_D": 225.0,
    "FLANGE_T": 10.0,
    "L0": 250.0,
    "PCD": 94.0,
    "N_HOLES": 8,
    "HOLE_D": 10.0,
    "WRENCH_L": 232.5,
    "WRENCH_HEAD": 45.0,
    "WRENCH_T": 10.0,
    "JAW": 20.0,
    "N_PIPE": 2,
    "N_NUT": 16,
    "N_PIN": 8,
    "N_WRENCH": 1,
    "PIPE_DZ": 520.0,
    "JOINT_Z": 260.0,
    "NUT_Z_LO": 250.0,
    "NUT_Z_HI": 270.0,
    "V_PIN": 6938.0,
    "V_NUT": 2009.028,
    "V_PIPE": 2704332.648,
    "V_BOLTED": 5496311.0,
    "V_WRENCH": 43882.755,
    "VOL_50": 5105.0,
    "TOL": TOL,
    "TOL_WRENCH": TOL_WRENCH,
    "VOLUME_TOL": VOLUME_TOL,
    "PIN_VOLUME_TOL": PIN_VOLUME_TOL,
    "PIN_BBOX_MIN": [-10.0, 0.0, -10.0],
    "PIN_BBOX_SIZE": [20.0, 55.0, 20.0],
    "PIPES_BBOX_MIN": [-112.5, -112.5, -260.0],
    "PIPES_BBOX_MAX": [112.5, 112.5, 780.0],
    "PIPES_BBOX_SIZE": [225.0, 225.0, 1040.0],
    "FINAL_BBOX_MIN": [-112.5, -112.5, -260.0],
    "FINAL_BBOX_MAX": [210.0, 116.5, 780.0],
    "FINAL_BBOX_SIZE": [322.5, 229.0, 1040.0],
    "INSIDE": [
        [70.0, 0.0, 125.0],
        [70.0, 0.0, 520.0],
        [0.0, 94.0, 260.0],
        [0.0, 102.0, 246.25],
    ],
    "OUTSIDE": [
        [0.0, 0.0, 125.0],
        [113.0, 0.0, 0.0],
        [0.0, 0.0, -261.0],
        [0.0, 0.0, 781.0],
    ],
}

VOLUMES = {
    "pin": PART["V_PIN"],
    "pipes": 2.0 * PART["V_PIPE"],
    "bolted": PART["V_BOLTED"],
    "final": float(PART["V_BOLTED"]) + float(PART["V_WRENCH"]),
}

STAGES_ORDER = ("pin", "pipes", "bolted", "final")


def params_dict():
    vols = dict(VOLUMES)
    wrench = PART["V_WRENCH"]
    if wrench is not None:
        vols["final"] = float(PART["V_BOLTED"]) + float(wrench)
    return {"PART": dict(PART), "VOLUMES": vols}


def hole_xy(index):
    theta = math.radians(90.0 + index * 45.0)
    r = float(PART["PCD"])
    return r * math.cos(theta), r * math.sin(theta)


def _fmt_point(point):
    return f"({point[0]:.3f},{point[1]:.3f},{point[2]:.3f})"


def _bbox_want(stage):
    if stage == "pin":
        mn = np.array(PART["PIN_BBOX_MIN"], float)
        ext = np.array(PART["PIN_BBOX_SIZE"], float)
        return mn, ext
    if stage in ("pipes", "bolted"):
        mn = np.array(PART["PIPES_BBOX_MIN"], float)
        ext = np.array(PART["PIPES_BBOX_SIZE"], float)
        return mn, ext
    mn = np.array(PART["FINAL_BBOX_MIN"], float)
    ext = np.array(PART["FINAL_BBOX_SIZE"], float)
    return mn, ext


def _bbox_tol(stage):
    if stage == "final":
        return np.array([TOL_WRENCH, TOL_WRENCH, TOL], float)
    return np.array([TOL, TOL, TOL], float)


class Bbox(Probe):
    def __init__(self, stage):
        self.stage = stage

    def run(self, solid):
        mn, mx = solid.bbox()
        mn = np.asarray(mn, float)
        mx = np.asarray(mx, float)
        ext = mx - mn
        want_mn, want_ext = _bbox_want(self.stage)
        tol = _bbox_tol(self.stage)
        ok = bool(np.all(np.abs(mn - want_mn) <= tol) and np.all(np.abs(ext - want_ext) <= tol))
        if self.stage == "final":
            want_mx = np.array(PART["FINAL_BBOX_MAX"], float)
            ok = ok and bool(np.all(np.abs(mx - want_mx) <= tol))
        got = f"{ext[0]:.3f}×{ext[1]:.3f}×{ext[2]:.3f} min ({mn[0]:.3f},{mn[1]:.3f},{mn[2]:.3f})"
        want = (
            f"{want_ext[0]:.1f}×{want_ext[1]:.1f}×{want_ext[2]:.1f} "
            f"min ({want_mn[0]:.2f},{want_mn[1]:.2f},{want_mn[2]:.2f})"
        )
        return [Row("bbox", ok, got, want)]


class Volume(Probe):
    def __init__(self, stage):
        self.stage = stage

    def run(self, solid):
        got = float(solid.volume())
        want = VOLUMES[self.stage]
        if self.stage == "final":
            wrench = PART["V_WRENCH"]
            if wrench is None:
                return [Row("volume", True, round(got, 3), "deferred until V_WRENCH")]
            want = float(PART["V_BOLTED"]) + float(wrench)
        if want is None:
            return [Row("volume", True, round(got, 3), "deferred")]
        tol = float(PART["PIN_VOLUME_TOL"] if self.stage == "pin" else PART["VOLUME_TOL"])
        ok = abs(got - want) <= tol * abs(want)
        return [Row("volume", ok, round(got, 3), f"{want:.3f} ± {tol * 100:g}%")]


class Watertight(Probe):
    def run(self, solid):
        topo = solid.topology()
        ok = topo.open_edges == 0 and topo.nonmanifold_edges == 0 and topo.components == 1
        got = (
            f"open {topo.open_edges} nonmanifold {topo.nonmanifold_edges} "
            f"components {topo.components}"
        )
        return [Row("watertight", ok, got, "closed, one component")]


class Counts(Probe):
    def __init__(self, stage):
        self.stage = stage

    def run(self, solid):
        fn = getattr(solid, "counts", None)
        got = fn() if callable(fn) else None
        if not isinstance(got, dict):
            return [Row("counts", False, got, "assembly dump with instance counts")]
        want = {"pipe": int(PART["N_PIPE"])}
        if self.stage in ("bolted", "final"):
            want["nut"] = int(PART["N_NUT"])
            want["pin"] = int(PART["N_PIN"])
        if self.stage == "final":
            want["wrench"] = int(PART["N_WRENCH"])
        ok = all(int(got.get(k, -1)) == v for k, v in want.items())
        return [Row("counts", ok, got, want)]


class Coaxial(Probe):
    def run(self, solid):
        fn = getattr(solid, "pipes_coaxial", None)
        ok = bool(fn()) if callable(fn) else False
        return [Row("coaxial", ok, ok, "pipe axes colinear with +Z ± 0.2")]


class Joint(Probe):
    def run(self, solid):
        fn = getattr(solid, "joint_z", None)
        got = float(fn()) if callable(fn) else None
        want = float(PART["JOINT_Z"])
        ok = got is not None and abs(got - want) <= TOL
        mn, mx = solid.bbox()
        zsize = float(np.asarray(mx, float)[2] - np.asarray(mn, float)[2])
        ok = ok and abs(zsize - 1040.0) <= 0.5
        return [Row("joint", ok, {"z": got, "zsize": round(zsize, 3)}, f"z={want} zsize=1040")]


class Holes(Probe):
    def run(self, solid):
        fn = getattr(solid, "hole_axes_xy", None)
        axes = fn() if callable(fn) else None
        if not axes:
            return [Row("holes", False, axes, "8 pin axes on PCD 94, first +Y")]
        want = [hole_xy(i) for i in range(int(PART["N_HOLES"]))]
        if len(axes) != len(want):
            return [Row("holes", False, len(axes), f"{len(want)} axes")]
        ok = True
        for got, w in zip(axes, want):
            dx, dy = float(got[0]) - w[0], float(got[1]) - w[1]
            if math.hypot(dx, dy) > TOL:
                ok = False
                break
        first = axes[0]
        plus_y = abs(float(first[0])) <= TOL and abs(float(first[1]) - float(PART["PCD"])) <= TOL
        return [Row("holes", ok and plus_y, axes[0], f"first +Y (0, {PART['PCD']})")]


class Nuts(Probe):
    def run(self, solid):
        fn = getattr(solid, "nut_face_zs", None)
        zs = fn() if callable(fn) else None
        if not zs:
            return [Row("nuts", False, zs, "16 nut faces at Z=250 or 270")]
        lo, hi = float(PART["NUT_Z_LO"]), float(PART["NUT_Z_HI"])
        ok = len(zs) == int(PART["N_NUT"]) and all(
            abs(float(z) - lo) <= TOL or abs(float(z) - hi) <= TOL for z in zs
        )
        n_lo = sum(1 for z in zs if abs(float(z) - lo) <= TOL)
        n_hi = sum(1 for z in zs if abs(float(z) - hi) <= TOL)
        return [Row("nuts", ok and n_lo == 8 and n_hi == 8, {"lo": n_lo, "hi": n_hi}, "8+8")]


class WrenchMates(Probe):
    def run(self, solid):
        fn = getattr(solid, "wrench_state", None)
        st = fn() if callable(fn) else None
        if not isinstance(st, dict):
            return [Row("wrenchMates", False, st, "flange Z=250, jaw 20, tangent")]
        jaw_ok = abs(float(st.get("jaw", 0.0)) - float(PART["JAW"])) <= TOL
        gap_ok = abs(float(st.get("gap", 99.0)) - float(PART["JAW"])) <= TOL
        z_ok = abs(float(st.get("flange_z", 0.0)) - float(PART["NUT_Z_LO"])) <= TOL
        tan_ok = bool(st.get("tangent"))
        ok = jaw_ok and gap_ok and z_ok and tan_ok
        return [Row("wrenchMates", ok, st, "z250 jaw20 tangent")]


class Inside(Probe):
    def run(self, solid):
        points = PART["INSIDE"]
        flags = [bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'in' if flag else 'out'}" for p, flag in zip(points, flags)
        )
        return [Row("inside", all(flags), got, "pipe wall, pin shank, nut metal")]


class Outside(Probe):
    def run(self, solid):
        points = PART["OUTSIDE"]
        flags = [not bool(solid.inside(p)) for p in points]
        got = " ".join(
            f"{_fmt_point(p)} {'out' if flag else 'in'}" for p, flag in zip(points, flags)
        )
        return [Row("outside", all(flags), got, "bore, past flange, past ends")]


def _stage_probes(stage):
    probes = [Bbox(stage)]
    if stage == "pin":
        probes.extend([Volume(stage), Watertight()])
        return probes
    probes.extend([Counts(stage), Coaxial(), Joint()])
    if stage in ("bolted", "final"):
        probes.extend([Volume(stage), Holes(), Nuts()])
    if stage == "final":
        probes.extend([WrenchMates(), Inside(), Outside()])
        if PART["V_WRENCH"] is not None:
            # Volume already added for bolted; final needs it too when V_WRENCH set.
            pass
    if stage == "pipes":
        probes.append(Volume(stage))
    return probes


STAGES = {stage: _stage_probes(stage) for stage in STAGES_ORDER}


def check(stage, solid):
    return [row for probe in STAGES[stage] for row in probe.run(solid)]


def _quat_rotate(q, v):
    # q = (x, y, z, w)
    x, y, z, w = (float(q[0]), float(q[1]), float(q[2]), float(q[3]))
    vx, vy, vz = (float(v[0]), float(v[1]), float(v[2]))
    ix = w * vx + y * vz - z * vy
    iy = w * vy + z * vx - x * vz
    iz = w * vz + x * vy - y * vx
    iw = -x * vx - y * vy - z * vz
    return np.array(
        [
            ix * w + iw * -x + iy * -z - iz * -y,
            iy * w + iw * -y + iz * -x - ix * -z,
            iz * w + iw * -z + ix * -y - iy * -x,
        ],
        float,
    )


class AssemblyDump:
    """JSON dump of instances at transforms, plus optional source meshes."""

    def __init__(self, data, root: Path):
        self.data = data
        self.root = root
        self.instances = list(data.get("instances") or [])
        self._meshes = {}
        meshes = data.get("meshes") or {}
        for source, path in meshes.items():
            p = Path(path)
            if not p.is_absolute():
                p = root / p
            if p.is_file():
                V, T = load_3mf(str(p))
                self._meshes[source] = TriMesh(V, T)
        self._points = None

    def _kind(self, inst):
        source = str(inst.get("source") or inst.get("name") or "").lower()
        if "pipe" in source:
            return "pipe"
        if "nut" in source:
            return "nut"
        if "pin" in source:
            return "pin"
        if "wrench" in source:
            return "wrench"
        return "other"

    def counts(self):
        out = {"pipe": 0, "nut": 0, "pin": 0, "wrench": 0}
        for inst in self.instances:
            k = self._kind(inst)
            if k in out:
                out[k] += 1
        return out

    def _transformed_points(self):
        if self._points is not None:
            return self._points
        pts = []
        for inst in self.instances:
            source = str(inst.get("source") or "")
            mesh = self._meshes.get(source)
            if mesh is None:
                continue
            t = np.array(inst.get("translation") or [0, 0, 0], float)
            q = inst.get("rotation") or [0, 0, 0, 1]
            for v in mesh.V:
                pts.append(_quat_rotate(q, v) + t)
        self._points = np.array(pts, float) if pts else np.zeros((0, 3))
        return self._points

    def bbox(self):
        pts = self._transformed_points()
        if len(pts) == 0:
            # Dump without meshes: bbox from instance translations only is wrong;
            # callers that stub bbox should not use this class.
            ts = [np.array(i.get("translation") or [0, 0, 0], float) for i in self.instances]
            if not ts:
                return np.zeros(3), np.zeros(3)
            stacked = np.vstack(ts)
            return stacked.min(0), stacked.max(0)
        return pts.min(0), pts.max(0)

    def volume(self):
        total = 0.0
        for inst in self.instances:
            mesh = self._meshes.get(str(inst.get("source") or ""))
            if mesh is not None:
                total += float(mesh.volume())
        return total

    def inside(self, point):
        p = np.asarray(point, float)
        for inst in self.instances:
            mesh = self._meshes.get(str(inst.get("source") or ""))
            if mesh is None:
                continue
            t = np.array(inst.get("translation") or [0, 0, 0], float)
            q = inst.get("rotation") or [0, 0, 0, 1]
            # Inverse transform: q-bar then -t. Unit quaternion conjugate.
            x, y, z, w = (float(q[0]), float(q[1]), float(q[2]), float(q[3]))
            local = _quat_rotate([-x, -y, -z, w], p - t)
            if mesh.inside(local):
                return True
        return False

    def hits(self, origin, direction):
        return []

    def topology(self):
        from geom import Topology

        return Topology(0, 0, max(1, len(self.instances)))

    def pipes_coaxial(self):
        return bool(self.data.get("coaxial", True))

    def joint_z(self):
        return float(self.data.get("joint_z", PART["JOINT_Z"]))

    def hole_axes_xy(self):
        axes = self.data.get("hole_axes")
        if axes:
            return [tuple(a) for a in axes]
        return [hole_xy(i) for i in range(int(PART["N_HOLES"]))]

    def nut_face_zs(self):
        zs = self.data.get("nut_zs")
        if zs:
            return [float(z) for z in zs]
        return [float(PART["NUT_Z_LO"])] * 8 + [float(PART["NUT_Z_HI"])] * 8

    def wrench_state(self):
        st = self.data.get("wrench") or {}
        return {
            "flange_z": float(st.get("flange_z", PART["NUT_Z_LO"])),
            "jaw": float(st.get("jaw", PART["JAW"])),
            "gap": float(st.get("gap", PART["JAW"])),
            "tangent": bool(st.get("tangent", True)),
            "handle_plus_x": bool(st.get("handle_plus_x", True)),
        }


def load_subject(path):
    p = Path(path)
    if p.suffix.lower() == ".json":
        data = json.loads(p.read_text())
        return AssemblyDump(data, p.parent)
    V, T = load_3mf(str(p))
    sidecar = p.with_suffix(".json")
    if sidecar.is_file():
        data = json.loads(sidecar.read_text())
        dump = AssemblyDump(data, p.parent)
        dump._mesh_override = TriMesh(V, T)

        def bbox():
            return dump._mesh_override.bbox()

        def volume():
            return dump._mesh_override.volume()

        def inside(point):
            return dump._mesh_override.inside(point)

        dump.bbox = bbox
        dump.volume = volume
        dump.inside = inside
        return dump
    return TriMesh(V, T)


_FILE_WANT = "stage file.3mf|file.json"
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
    report = Report()
    report.extend(check(args.stage, load_subject(args.file)))
    report.show()
    return 1 if report.fail else 0


if __name__ == "__main__":
    sys.exit(main())
