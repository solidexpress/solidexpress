#!/usr/bin/env python3
"""Unit tests for the rung-6 candlestick checker. No kernel, no app.

Run: python3 tools/test_check_rung06.py
"""
import io
import json
import subprocess
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_rung06 as c
from implicit_candlestick import ImplicitCandlestick


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung06.py"
STAGES = ("revolve", "sweep", "final")


def _rows(stage, solid):
    return c.check(stage, solid)


def _failed(rows):
    return [row.name for row in rows if not row.ok]


class ParamsTests(unittest.TestCase):
    def test_params_json_has_the_walk_keys(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["params"])
        self.assertEqual(rc, 0)
        data = json.loads(buf.getvalue())
        self.assertIn("PART", data)
        self.assertIn("VOLUMES", data)
        part = data["PART"]
        for key in (
            "H", "TOP_R", "BASE_R", "R10", "UPPER", "R20", "LOWER", "R60", "R12",
            "PATH_Y", "PATH_60", "PATH_R150", "PATH_65", "PATH_R20",
            "ELLIPSE_MAJ", "ELLIPSE_MIN", "CUT_D", "CUT_H", "CUT_DRAFT_DEG",
            "AREA", "XBAR", "V_REV", "V_HANDLE", "V_CUT", "VOLUME",
            "VOL_UNCLIP", "VOL_NODRAFT_DELTA", "TOL", "VOLUME_TOL",
            "BBOX_MIN", "BBOX_MAX", "INSIDE", "OUTSIDE", "DRAFT_HOLE",
        ):
            self.assertIn(key, part)
        self.assertEqual(part["H"], 220)
        self.assertEqual(part["TOP_R"], 20)
        self.assertEqual(part["BASE_R"], 90)
        self.assertEqual(part["R10"], 10)
        self.assertEqual(part["UPPER"], 40)
        self.assertEqual(part["R20"], 20)
        self.assertEqual(part["LOWER"], 50)
        self.assertEqual(part["R60"], 60)
        self.assertEqual(part["R12"], 12.5)
        self.assertEqual(part["PATH_Y"], 10)
        self.assertEqual(part["PATH_60"], 60)
        self.assertEqual(part["PATH_R150"], 150)
        self.assertEqual(part["PATH_65"], 65)
        self.assertEqual(part["PATH_R20"], 20)
        self.assertEqual(part["ELLIPSE_MAJ"], 35)
        self.assertEqual(part["ELLIPSE_MIN"], 10)
        self.assertEqual(part["CUT_D"], 30)
        self.assertEqual(part["CUT_H"], 25)
        self.assertEqual(part["CUT_DRAFT_DEG"], 15)
        self.assertEqual(part["AREA"], 9588.322)
        self.assertEqual(part["XBAR"], 28.064)
        self.assertEqual(part["V_REV"], 1690750)
        self.assertEqual(part["V_HANDLE"], 50548)
        self.assertEqual(part["V_CUT"], 10954.475)
        self.assertEqual(part["VOLUME"], 1730343)
        self.assertEqual(part["VOL_UNCLIP"], 1726807)
        self.assertEqual(part["VOL_NODRAFT_DELTA"], 17671.459)
        self.assertEqual(part["BBOX_MIN"], [-112.0, 0.0, -112.0])
        self.assertEqual(part["BBOX_MAX"], [192.1, 220.0, 112.0])
        self.assertEqual(part["INSIDE"][0], [0.0, 100.0, 0.0])
        self.assertEqual(len(part["OUTSIDE"]), 4)
        self.assertEqual(part["DRAFT_HOLE"], [13.0, 195.0, 0.0])
        vols = data["VOLUMES"]
        for stage in STAGES:
            self.assertIn(stage, vols)
        self.assertAlmostEqual(vols["revolve"], 1690750, delta=0.01)
        self.assertAlmostEqual(vols["sweep"], 1741298, delta=0.01)
        self.assertAlmostEqual(vols["final"], 1730343, delta=0.01)

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())


class StageTests(unittest.TestCase):
    def test_implicit_stages_pass(self):
        for stage in STAGES:
            solid = ImplicitCandlestick.for_stage(stage)
            rows = _rows(stage, solid)
            self.assertEqual(
                _failed(rows), [],
                msg=f"{stage} {[(r.name, r.ok, r.got, r.want) for r in rows]}")


class MutationTests(unittest.TestCase):
    def _assert_named(self, stage, solid, needle):
        rows = _rows(stage, solid)
        failed = _failed(rows)
        self.assertTrue(
            any(needle in name for name in failed),
            msg=f"expected {needle!r} to fail, got {[(r.name, r.ok, r.got) for r in rows]}")
        return rows

    def test_height_200(self):
        self._assert_named("revolve", ImplicitCandlestick.for_stage("revolve", height=200.0), "bbox")

    def test_handle_on_minus_x(self):
        solid = ImplicitCandlestick.for_stage("sweep", handle_sign=-1.0)
        self._assert_named("sweep", solid, "handleSide")
        self._assert_named("sweep", solid, "bbox")

    def test_unclipped_toe_ymin(self):
        self._assert_named(
            "final",
            ImplicitCandlestick.for_stage("final", ymin=-4.375, volume_override=c.PART["VOL_UNCLIP"]),
            "bbox")

    def test_straight_cut(self):
        self._assert_named("final", ImplicitCandlestick.for_stage("final", draft=False), "draftHole")

    def test_two_bodies(self):
        V, T = _box(-112.0, 0.0, -112.0, 192.1, 220.0, 112.0)
        shift = V.copy()
        shift[:, 0] += 400.0
        V2 = np.vstack([V, shift])
        T2 = np.vstack([T, T + len(V)])
        self._assert_named("final", c.TriMesh(V2, T2), "watertight")

    def test_equal_kept_r60_at_y90(self):
        self._assert_named(
            "revolve", ImplicitCandlestick.for_stage("revolve", equal_kept=True), "bbox")


class VolumeToleranceTests(unittest.TestCase):
    def _volume_ok(self, stage, factor):
        want = c.VOLUMES[stage]
        rows = c.Volume(stage).run(_VolumeStub(want * factor))
        return rows[0].ok

    def test_half_percent_band(self):
        for stage in STAGES:
            self.assertTrue(self._volume_ok(stage, 1.004), stage)
            self.assertTrue(self._volume_ok(stage, 0.996), stage)
            self.assertFalse(self._volume_ok(stage, 1.007), stage)
            self.assertFalse(self._volume_ok(stage, 0.993), stage)


class OtherRungTests(unittest.TestCase):
    def test_rung02_03_04_05_still_pass(self):
        for name in (
            "test_check_rung02.py",
            "test_check_rung03.py",
            "test_check_rung04.py",
            "test_check_rung05.py",
        ):
            proc = subprocess.run(
                [sys.executable, str(ROOT / "tools" / name)],
                check=False, capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)


class CliTests(unittest.TestCase):
    def test_bad_stage(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["cube"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", buf.getvalue())

    def test_missing_file(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["revolve"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", buf.getvalue())


class _VolumeStub:
    def __init__(self, volume):
        self._volume = float(volume)

    def volume(self):
        return self._volume

    def bbox(self):
        return np.zeros(3), np.array((304.1, 220.0, 224.0))

    def inside(self, point):
        return False

    def hits(self, origin, direction):
        return []

    def topology(self):
        from geom import Topology
        return Topology(0, 0, 1)


def _box(x0, y0, z0, x1, y1, z1):
    V = np.array([
        [x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0],
        [x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1],
    ], float)
    faces = (
        (0, 2, 1), (0, 3, 2),
        (4, 5, 6), (4, 6, 7),
        (0, 1, 5), (0, 5, 4),
        (1, 2, 6), (1, 6, 5),
        (2, 3, 7), (2, 7, 6),
        (3, 0, 4), (3, 4, 7),
    )
    return V, np.array(faces, int)


if __name__ == "__main__":
    unittest.main()
