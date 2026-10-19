#!/usr/bin/env python3
"""Unit tests for the rung-7 combination-spanner checker. No kernel, no app.

Run: python3 tools/test_check_rung07.py
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
import check_rung07 as c
from implicit_spanner import ImplicitSpanner


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung07.py"
STAGES = ("boss", "neck", "mirror", "final")


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
            "ELLIPSE_MAJ", "ELLIPSE_MIN", "ANGLE_DEG", "JAW_OFF", "JAW_LEN",
            "R15", "RING_D", "HEX_AF", "CENTER", "HANDLE_HALF", "HEAD_T",
            "HANDLE_T", "R30", "R20", "OFFSET", "CUT_D", "R3", "R1",
            "A_C", "A_RING", "A_H", "V_C", "V_RING", "V_H", "V_BOSS",
            "V_30", "V_20", "V_NECK", "V_RECESS", "V_R3", "V_MIRROR", "V_R1",
            "VOLUME", "VOID_ELL_DEG", "VOID_CIR_DEG", "VOL_90NECK", "VOL_PREP",
            "TOL", "VOLUME_TOL", "BBOX_MIN", "BBOX_SIZE", "INSIDE", "OUTSIDE",
            "RECESS",
        ):
            self.assertIn(key, part)
        self.assertEqual(part["ELLIPSE_MAJ"], 55)
        self.assertEqual(part["ELLIPSE_MIN"], 50)
        self.assertEqual(part["ANGLE_DEG"], 17)
        self.assertEqual(part["JAW_OFF"], 12.5)
        self.assertEqual(part["JAW_LEN"], 20)
        self.assertEqual(part["R15"], 15)
        self.assertEqual(part["RING_D"], 33)
        self.assertEqual(part["HEX_AF"], 25)
        self.assertEqual(part["CENTER"], 240)
        self.assertEqual(part["HANDLE_HALF"], 10)
        self.assertEqual(part["HEAD_T"], 10)
        self.assertEqual(part["HANDLE_T"], 6)
        self.assertEqual(part["R30"], 30)
        self.assertEqual(part["R20"], 20)
        self.assertEqual(part["OFFSET"], 5)
        self.assertEqual(part["CUT_D"], 1)
        self.assertEqual(part["R3"], 3)
        self.assertEqual(part["R1"], 1)
        self.assertEqual(part["A_C"], 1495.80)
        self.assertAlmostEqual(part["A_RING"], 275.172, places=3)
        self.assertEqual(part["A_H"], 3999.25)
        self.assertEqual(part["V_C"], 14958)
        self.assertEqual(part["V_RING"], 2752)
        self.assertEqual(part["V_H"], 23996)
        self.assertEqual(part["V_BOSS"], 41705)
        self.assertEqual(part["V_30"], 858)
        self.assertEqual(part["V_20"], 170)
        self.assertEqual(part["V_NECK"], 42733)
        self.assertEqual(part["V_RECESS"], 3791.02)
        self.assertEqual(part["V_R3"], 15.45)
        self.assertEqual(part["V_MIRROR"], 38957)
        self.assertEqual(part["V_R1"], 176)
        self.assertEqual(part["VOLUME"], 38782)
        self.assertEqual(part["VOID_ELL_DEG"], 112.42)
        self.assertEqual(part["VOID_CIR_DEG"], 127.31)
        self.assertEqual(part["VOL_90NECK"], 41102)
        self.assertEqual(part["VOL_PREP"], 4.09e4)
        self.assertEqual(part["BBOX_MIN"], [-24.95, -27.30, -5.00])
        self.assertEqual(part["BBOX_SIZE"], [281.4, 54.6, 10.0])
        self.assertEqual(part["INSIDE"][0], [0.0, 18.0, 0.0])
        self.assertEqual(len(part["OUTSIDE"]), 7)
        self.assertEqual(part["VOLUME_TOL"], 0.005)
        vols = data["VOLUMES"]
        for stage in STAGES:
            self.assertIn(stage, vols)
        self.assertAlmostEqual(vols["boss"], 41705, delta=0.01)
        self.assertAlmostEqual(vols["neck"], 42733, delta=0.01)
        self.assertAlmostEqual(vols["mirror"], 38957, delta=0.01)
        self.assertAlmostEqual(vols["final"], 38782, delta=0.01)

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())


class StageTests(unittest.TestCase):
    def test_implicit_stages_pass(self):
        for stage in STAGES:
            solid = ImplicitSpanner.for_stage(stage)
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

    def test_swapped_axes_y_50_4(self):
        self._assert_named(
            "final", ImplicitSpanner.for_stage("final", swapped_axes=True), "bbox")

    def test_handle_on_minus_x(self):
        solid = ImplicitSpanner.for_stage("boss", handle_sign=-1.0)
        self._assert_named("boss", solid, "handleSide")
        self._assert_named("boss", solid, "bbox")

    def test_one_face_recess(self):
        self._assert_named(
            "final", ImplicitSpanner.for_stage("final", one_face=True), "recessBoth")

    def test_90_degree_neck_volume(self):
        self._assert_named(
            "final",
            ImplicitSpanner.for_stage("final", volume_override=c.PART["VOL_90NECK"]),
            "volume")

    def test_two_bodies(self):
        V, T = _box(-24.95, -27.30, -5.00, 256.45, 27.30, 5.00)
        shift = V.copy()
        shift[:, 0] += 400.0
        V2 = np.vstack([V, shift])
        T2 = np.vstack([T, T + len(V)])
        self._assert_named("final", c.TriMesh(V2, T2), "watertight")

    def test_hex_across_corners(self):
        self._assert_named(
            "final",
            ImplicitSpanner.for_stage("final", hex_across_corners=True),
            "inside")

    def test_wall_less(self):
        self._assert_named(
            "final", ImplicitSpanner.for_stage("final", wall_less=True), "inside")


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

    def test_90_neck_outside_band(self):
        want = c.VOLUMES["final"]
        mutant = c.PART["VOL_90NECK"]
        rel = abs(mutant - want) / abs(want)
        self.assertGreater(rel, 0.005)
        self.assertFalse(self._volume_ok("final", mutant / want))


class OtherRungTests(unittest.TestCase):
    def test_rung02_03_04_05_06_still_pass(self):
        for name in (
            "test_check_rung02.py",
            "test_check_rung03.py",
            "test_check_rung04.py",
            "test_check_rung05.py",
            "test_check_rung06.py",
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
            rc = c.main(["boss"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", buf.getvalue())


class _VolumeStub:
    def __init__(self, volume):
        self._volume = float(volume)

    def volume(self):
        return self._volume

    def bbox(self):
        return np.array((-24.95, -27.30, -5.00)), np.array((256.45, 27.30, 5.00))

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
