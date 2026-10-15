#!/usr/bin/env python3
"""Unit tests for the rung-5 pipe-section checker. No kernel, no app.

Run: python3 tools/test_check_rung05.py
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
import check_rung05 as c
from implicit_pipe import ImplicitPipe


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung05.py"
STAGES = ("cyl", "shelled", "flange", "cut", "mirror", "reshell", "final")


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
        for key in ("OD", "ID", "WALL", "L0", "FLANGE_D", "FLANGE_T", "HOLE_D",
                    "PCD", "N_HOLES", "FILLET", "TOL", "VOLUME_TOL",
                    "BBOX_MIN", "BBOX_MAX", "INSIDE", "OUTSIDE"):
            self.assertIn(key, part)
        self.assertEqual(part["OD"], 150)
        self.assertEqual(part["ID"], 130)
        self.assertEqual(part["WALL"], 10)
        self.assertEqual(part["L0"], 250)
        self.assertEqual(part["FLANGE_D"], 225)
        self.assertEqual(part["FLANGE_T"], 10)
        self.assertEqual(part["HOLE_D"], 10)
        self.assertEqual(part["PCD"], 94)
        self.assertEqual(part["N_HOLES"], 8)
        self.assertEqual(part["FILLET"], 5)
        self.assertEqual(part["BBOX_MIN"], [-112.5, -112.5, -260.0])
        self.assertEqual(part["BBOX_MAX"], [112.5, 112.5, 260.0])
        self.assertEqual(part["INSIDE"][0], [70.0, 0.0, 125.0])
        self.assertEqual(len(part["OUTSIDE"]), 6)
        vols = data["VOLUMES"]
        for stage in STAGES:
            self.assertIn(stage, vols)
        self.assertAlmostEqual(vols["cyl"], 4417864.669, delta=0.01)
        self.assertAlmostEqual(vols["shelled"], 1099557.429, delta=0.01)
        self.assertAlmostEqual(vols["flange"], 1497165.249, delta=0.01)
        self.assertAlmostEqual(vols["cut"], 1358149.774, delta=0.01)
        self.assertAlmostEqual(vols["mirror"], 6034606.788, delta=0.01)
        self.assertAlmostEqual(vols["reshell"], 2716299.548, delta=0.01)

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())


class StageTests(unittest.TestCase):
    def test_implicit_stages_pass(self):
        for stage in STAGES:
            solid = ImplicitPipe.for_stage(stage)
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

    def test_length_250_after_mirror(self):
        self._assert_named("mirror", ImplicitPipe.for_stage("mirror", skip_minus=True), "bbox")

    def test_flange_d_200(self):
        self._assert_named("flange", ImplicitPipe.for_stage("flange", flange_d=200.0), "flange")

    def test_six_holes(self):
        self._assert_named("cut", ImplicitPipe.for_stage("cut", n_holes=6), "boltRing")

    def test_through_all_hollow_minus_z(self):
        self._assert_named("mirror", ImplicitPipe.for_stage("mirror", through_all=True), "solidHalf")

    def test_original_wall_20_after_reshell(self):
        self._assert_named("reshell", ImplicitPipe.for_stage("reshell", wall_plus=20.0), "wall")

    def test_wall_12_and_8_still_fail(self):
        for thickness in (12.0, 8.0):
            self._assert_named(
                "reshell", ImplicitPipe.for_stage("reshell", wall_plus=thickness), "wall")

    def test_body_mirror_volume_at_mirror(self):
        self._assert_named("mirror", ImplicitPipe.for_stage("mirror", shell_carries=True), "volume")

    def test_second_body(self):
        V, T = _box(-112.5, -112.5, -260.0, 112.5, 112.5, 260.0)
        shift = V.copy()
        shift[:, 0] += 400.0
        V2 = np.vstack([V, shift])
        T2 = np.vstack([T, T + len(V)])
        self._assert_named("final", c.TriMesh(V2, T2), "watertight")


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
    def test_rung02_03_04_still_pass(self):
        for name in ("test_check_rung02.py", "test_check_rung03.py", "test_check_rung04.py"):
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
            rc = c.main(["cyl"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", buf.getvalue())


class _VolumeStub:
    def __init__(self, volume):
        self._volume = float(volume)

    def volume(self):
        return self._volume

    def bbox(self):
        return np.zeros(3), np.array((225.0, 225.0, 520.0))

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
