#!/usr/bin/env python3
"""Unit tests for the rung-4 hex-key checker. No kernel, no app.

Run: python3 tools/test_check_rung04.py
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
import check_rung04 as c
import geom
from implicit_key import ImplicitKey


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung04.py"


def _rows(solid):
    return c.check("final", solid)


def _failed(rows):
    return [row.name for row in rows if not row.ok]


class ParamsTests(unittest.TestCase):
    def test_params_json_is_part(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["params"])
        self.assertEqual(rc, 0)
        data = json.loads(buf.getvalue())
        part = data["PART"]
        self.assertEqual(part["AF"], 7.65)
        self.assertEqual(part["R"], 4.416730)
        self.assertEqual(part["LEG_Z"], 37)
        self.assertEqual(part["LEG_Y"], 94)
        self.assertEqual(part["BEND_D"], 30)
        self.assertEqual(part["AREA"], 50.681972)
        self.assertEqual(part["LENGTH"], 124.561945)
        self.assertEqual(part["VOLUME"], 6313.045)
        self.assertEqual(part["VOL_TOP"], 6664.665)
        self.assertEqual(part["VOL_BOT"], 5961.424)
        self.assertEqual(part["BBOX_MIN"], [-3.825, -4.416730, 0.0])
        self.assertEqual(part["BBOX_MAX"], [3.825, 94.0, 41.416730])
        self.assertEqual(part["INSIDE"][1], [0.0, 4.393, 32.607])
        self.assertEqual(len(part["OUTSIDE"]), 4)

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())


class StageTests(unittest.TestCase):
    def test_implicit_final_passes(self):
        rows = _rows(ImplicitKey())
        self.assertEqual(
            _failed(rows), [],
            msg=[(r.name, r.ok, r.got, r.want) for r in rows])


class MutationTests(unittest.TestCase):
    def _assert_named(self, solid, needle):
        rows = _rows(solid)
        failed = _failed(rows)
        self.assertTrue(
            any(needle in name for name in failed),
            msg=f"expected {needle!r} to fail, got {[(r.name, r.ok, r.got) for r in rows]}")
        return rows

    def test_af_8(self):
        self._assert_named(ImplicitKey(af=8.0), "bbox")

    def test_length_195(self):
        self._assert_named(ImplicitKey(leg_y=195.0), "bbox")

    def test_flats_horizontal(self):
        self._assert_named(ImplicitKey(pose="flats"), "bbox")

    def test_translated(self):
        self._assert_named(ImplicitKey(shift=(10.0, 0.0, 0.0)), "bbox")

    def test_volume_top_vertex(self):
        self._assert_named(ImplicitKey(volume=c.PART["VOL_TOP"]), "volume")

    def test_volume_bottom_vertex(self):
        self._assert_named(ImplicitKey(volume=c.PART["VOL_BOT"]), "volume")

    def test_arc_point_outside(self):
        self._assert_named(ImplicitKey(miss_arc=True), "inside")

    def test_second_body(self):
        V, T = _box(-3.825, -4.417, 0.0, 3.825, 94.0, 41.417)
        shift = V.copy()
        shift[:, 0] += 40.0
        V2 = np.vstack([V, shift])
        T2 = np.vstack([T, T + len(V)])
        self._assert_named(c.TriMesh(V2, T2), "watertight")


class OtherRungTests(unittest.TestCase):
    def test_rung02_and_rung03_still_pass(self):
        for name in ("test_check_rung02.py", "test_check_rung03.py"):
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
            rc = c.main(["final"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL", buf.getvalue())


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
