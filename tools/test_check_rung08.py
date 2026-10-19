#!/usr/bin/env python3
"""Unit tests for the rung-8 pipeline-assembly checker. No kernel, no app.

Run: python3 tools/test_check_rung08.py
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
import check_rung08 as c
from implicit_pin import ImplicitPin, ImplicitPipeline


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung08.py"
STAGES = ("pin", "pipes", "bolted", "final")


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
            "HEAD_R", "TAIL_R", "SHANK_R", "SHANK_L", "OVERALL",
            "NUT_AF", "NUT_AC", "NUT_T", "NUT_BORE",
            "PIPE_OD", "PIPE_ID", "FLANGE_D", "FLANGE_T", "L0", "PCD",
            "N_HOLES", "HOLE_D", "WRENCH_L", "WRENCH_HEAD", "WRENCH_T", "JAW",
            "N_PIPE", "N_NUT", "N_PIN", "N_WRENCH", "PIPE_DZ", "JOINT_Z",
            "NUT_Z_LO", "NUT_Z_HI", "V_PIN", "V_NUT", "V_PIPE", "V_BOLTED",
            "V_WRENCH", "VOL_50", "TOL", "TOL_WRENCH", "VOLUME_TOL",
            "PIN_BBOX_MIN", "PIN_BBOX_SIZE", "PIPES_BBOX_MIN", "PIPES_BBOX_SIZE",
            "FINAL_BBOX_MIN", "FINAL_BBOX_MAX", "FINAL_BBOX_SIZE",
            "INSIDE", "OUTSIDE",
        ):
            self.assertIn(key, part)
        self.assertEqual(part["HEAD_R"], 10)
        self.assertEqual(part["TAIL_R"], 10)
        self.assertEqual(part["SHANK_R"], 5)
        self.assertEqual(part["SHANK_L"], 35)
        self.assertEqual(part["OVERALL"], 55)
        self.assertEqual(part["N_PIPE"], 2)
        self.assertEqual(part["N_NUT"], 16)
        self.assertEqual(part["N_PIN"], 8)
        self.assertEqual(part["N_WRENCH"], 1)
        self.assertEqual(part["PIPE_DZ"], 520)
        self.assertEqual(part["JOINT_Z"], 260)
        self.assertEqual(part["V_PIN"], 6938)
        self.assertAlmostEqual(part["V_WRENCH"], 43882.755, places=3)
        self.assertEqual(part["VOL_50"], 5105)
        self.assertEqual(part["FINAL_BBOX_SIZE"], [322.5, 229.0, 1040.0])
        self.assertEqual(part["PIPES_BBOX_SIZE"], [225.0, 225.0, 1040.0])
        vols = data["VOLUMES"]
        self.assertAlmostEqual(vols["pin"], 6938, delta=0.01)
        self.assertAlmostEqual(vols["bolted"], 5496311, delta=0.01)
        self.assertAlmostEqual(vols["final"], 5496311 + 43882.755, delta=0.01)

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())

    def test_first_hole_plus_y(self):
        x, y = c.hole_xy(0)
        self.assertAlmostEqual(x, 0.0, places=6)
        self.assertAlmostEqual(y, 94.0, places=6)


class StageTests(unittest.TestCase):
    def test_implicit_pin_passes(self):
        rows = _rows("pin", ImplicitPin())
        self.assertEqual(_failed(rows), [], msg=[(r.name, r.ok, r.got, r.want) for r in rows])

    def test_implicit_pipes_bolted_final_pass(self):
        for stage in ("pipes", "bolted", "final"):
            solid = ImplicitPipeline.for_stage(stage)
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

    def test_overall_50_pin_bbox(self):
        self._assert_named("pin", ImplicitPin(overall=50.0), "bbox")

    def test_outer_flange_joint_pipes_bbox(self):
        self._assert_named(
            "pipes", ImplicitPipeline.for_stage("pipes", outer_joint=True), "bbox")

    def test_counts_1_8_4_1_bolted(self):
        self._assert_named(
            "bolted",
            ImplicitPipeline.for_stage("bolted", n_pipe=1, n_nut=8, n_pin=4, n_wrench=1),
            "counts")

    def test_wrench_jaw_25(self):
        self._assert_named(
            "final", ImplicitPipeline.for_stage("final", jaw=25.0), "wrenchMates")

    def test_two_bodies_pin(self):
        self._assert_named("pin", ImplicitPin(two_body=True), "watertight")

    def test_origin_stacked_final_bbox(self):
        self._assert_named(
            "final", ImplicitPipeline.for_stage("final", stacked=True), "bbox")


class VolumeToleranceTests(unittest.TestCase):
    def test_pin_half_percent_band(self):
        want = c.VOLUMES["pin"]
        ok_hi = c.Volume("pin").run(ImplicitPin(volume_override=want * 1.004))[0].ok
        ok_lo = c.Volume("pin").run(ImplicitPin(volume_override=want * 0.996))[0].ok
        bad = c.Volume("pin").run(ImplicitPin(volume_override=want * 1.01))[0].ok
        self.assertTrue(ok_hi)
        self.assertTrue(ok_lo)
        self.assertFalse(bad)
        self.assertEqual(c.PIN_VOLUME_TOL, 0.005)


class OtherRungTests(unittest.TestCase):
    def test_rung02_03_04_05_06_07_still_pass(self):
        for name in (
            "test_check_rung02.py",
            "test_check_rung03.py",
            "test_check_rung04.py",
            "test_check_rung05.py",
            "test_check_rung06.py",
            "test_check_rung07.py",
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
            rc = c.main(["pin"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
