#!/usr/bin/env python3
"""Unit tests for the rung-3 part checker. No kernel, no app.

Run: python3 tools/test_check_rung03.py
"""
import io
import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_rung03 as c
import geom
from implicit_part03 import ImplicitPart03


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung03.py"
STAGES = ("base", "boss", "cut", "r5", "rounded", "final")


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
        for key in ("SIDE", "H0", "BOSS_D", "BOSS_H", "TOP", "HOLE_D", "OFFSET",
                    "R_BIG", "R_SMALL", "WALL", "OPEN", "TOL", "VOLUME_TOL",
                    "FINAL_VOLUME_TOL"):
            self.assertIn(key, part)
        self.assertEqual(part["H0"], 30)
        self.assertEqual(part["TOP"], 55)
        self.assertEqual(part["OPEN"], "-Z")
        self.assertEqual(part["SIDE"], 120)
        vols = data["VOLUMES"]
        self.assertEqual(vols["base"], 432000.0)
        self.assertEqual(vols["boss"], 528211.3)
        self.assertEqual(vols["cut"], 372702.4)
        self.assertEqual(vols["r5"], 370784.6)
        self.assertEqual(vols["rounded"], 370587.4)
        self.assertEqual(vols["final"], 39311.0)

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())


class StageTests(unittest.TestCase):
    def test_implicit_stages_pass(self):
        for stage in STAGES:
            solid = ImplicitPart03.for_stage(stage)
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

    def test_base_depth_50(self):
        self._assert_named("base", ImplicitPart03.for_stage("base", h0=50), "bbox")

    def test_rectangle_not_centred(self):
        self._assert_named("base", ImplicitPart03.for_stage("base", shift=(10.0, 0.0)), "bbox")

    def test_boss_diameter(self):
        for diameter in (60.0, 80.0):
            self._assert_named("boss", ImplicitPart03.for_stage("boss", boss_d=diameter), "boss")

    def test_boss_height_20(self):
        self._assert_named("boss", ImplicitPart03.for_stage("boss", boss_h=20), "bbox")

    def test_hole_diameter(self):
        for diameter in (50.0, 70.0):
            self._assert_named("cut", ImplicitPart03.for_stage("cut", hole_d=diameter), "hole Ø60")

    def test_blind_hole(self):
        self._assert_named("cut", ImplicitPart03.for_stage("cut", blind=True), "hole Ø60")

    def test_vertical_corner_radius(self):
        for radius in (4.0, 6.0):
            self._assert_named(
                "r5", ImplicitPart03.for_stage("r5", r_vert=radius), "corner R5 vertical")

    def test_no_root_fillet(self):
        self._assert_named("r5", ImplicitPart03.for_stage("r5", r_root=0.0), "root R5")

    def test_one_rim_missing(self):
        self._assert_named(
            "rounded", ImplicitPart03.for_stage("rounded", r_outer_rim=0.0), "annulus R1.5")

    def test_wall_thickness(self):
        for thickness in (1.5, 0.5, 1.2, 0.8):
            self._assert_named(
                "final", ImplicitPart03.for_stage("final", wall=thickness), "wall x")

    def test_one_side_thicker(self):
        self._assert_named("final", ImplicitPart03.for_stage("final", wall_xn=2.0), "wall x")

    def test_back_closed(self):
        solid = ImplicitPart03.for_stage("final", closed_back=True)
        rows = self._assert_named("final", solid, "open back")
        self.assertTrue(any(name == "plates" and not ok for name, ok in
                            ((r.name, r.ok) for r in rows)))

    def test_corner_shell_thicker(self):
        self._assert_named(
            "final", ImplicitPart03.for_stage("final", inner_corner_r=3.0), "wall corner")

    def test_duplicate_body(self):
        V, T = _box(*_base_bounds())
        shift = V.copy()
        shift[:, 0] += 300.0
        V2 = np.vstack([V, shift])
        T2 = np.vstack([T, T + len(V)])
        self._assert_named("base", c.TriMesh(V2, T2), "watertight")

    def test_flipped_triangle(self):
        V, T = _box(*_base_bounds())
        T = T.copy()
        T[0, 1], T[0, 2] = T[0, 2], T[0, 1]
        self._assert_named("base", c.TriMesh(V, T), "watertight")

    def test_base_checked_as_boss(self):
        self._assert_named("boss", ImplicitPart03.for_stage("base"), "bbox")


class VolumeToleranceTests(unittest.TestCase):
    def _volume_ok(self, stage, factor):
        want = c.VOLUMES[stage]
        rows = c.Volume(stage).run(_VolumeStub(want * factor))
        return rows[0].ok

    def test_final_band(self):
        self.assertTrue(self._volume_ok("final", 1.01))
        self.assertTrue(self._volume_ok("final", 0.99))
        self.assertFalse(self._volume_ok("final", 1.02))
        self.assertFalse(self._volume_ok("final", 0.98))

    def test_solid_band(self):
        for stage in ("base", "boss", "cut", "r5", "rounded"):
            self.assertTrue(self._volume_ok(stage, 1.004), stage)
            self.assertTrue(self._volume_ok(stage, 0.996), stage)
            self.assertFalse(self._volume_ok(stage, 1.007), stage)
            self.assertFalse(self._volume_ok(stage, 0.993), stage)


class OtherRungTests(unittest.TestCase):
    def test_rung01_and_rung02_still_pass(self):
        for name in ("test_check_rung01.py", "test_check_rung02.py"):
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
        self.assertIn("usage", buf.getvalue())

    def test_missing_file(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["base"])
        self.assertEqual(rc, 1)
        self.assertIn("FAIL  usage", buf.getvalue())

    def test_base_mesh_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "base.3mf"
            _write_3mf(path, *_box(*_base_bounds()))
            proc = subprocess.run(
                [sys.executable, str(CHECK), "base", str(path)],
                check=False, capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertNotIn("FAIL", proc.stdout)
            self.assertIn("PASS", proc.stdout)


class RayEdgeTests(unittest.TestCase):
    def test_fillet_seam_edge_is_a_hit(self):
        # Outer R1.5 torus, the +X seam. The probe rides the shared edge.
        # u+v comes out 1+1ulp, and a strict barycentric test drops it, so
        # the checker reports the hole wall behind the fillet.
        V = np.array([
            [34.2621, 5.16418, 54.4642],
            [34.4642, 0.0, 54.6491],
            [34.6491, 0.0, 54.4642],
        ])
        T = np.array([[0, 1, 2]])
        direction = np.array([1.0, 0.0, 1.0])
        direction /= np.linalg.norm(direction)
        origin = np.array([35.0, 0.0, 55.0]) + 5.0 * direction
        hits = geom.ray_hits(geom.tri_arrays(V, T), origin, -direction)
        self.assertGreaterEqual(len(hits), 1)
        self.assertAlmostEqual(float(hits[0]), 5.627, delta=0.02)

    def test_ray_missing_the_triangle_stays_empty(self):
        V = np.array([
            [34.2621, 5.16418, 54.4642],
            [34.4642, 0.0, 54.6491],
            [34.6491, 0.0, 54.4642],
        ])
        T = np.array([[0, 1, 2]])
        origin = np.array([0.0, 80.0, 0.0])
        hits = geom.ray_hits(geom.tri_arrays(V, T), origin, np.array([0.0, 1.0, 0.0]))
        self.assertEqual(len(hits), 0)


class _VolumeStub:
    def __init__(self, volume):
        self._volume = float(volume)

    def volume(self):
        return self._volume

    def bbox(self):
        return np.zeros(3), np.array((120.0, 120.0, 55.0))

    def inside(self, point):
        return False

    def hits(self, origin, direction):
        return []

    def topology(self):
        return geom.Topology(0, 0, 1)


def _base_bounds():
    half = c.PART["SIDE"] / 2.0
    return -half, -half, 0.0, half, half, c.PART["H0"]


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


def _write_3mf(path, V, T):
    verts = "".join(
        f'<vertex x="{x:.8f}" y="{y:.8f}" z="{z:.8f}"/>' for x, y, z in V)
    tris = "".join(
        f'<triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in T)
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<model unit="millimeter" xml:lang="en-US" '
        'xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">'
        "<resources><object id=\"1\" type=\"model\"><mesh>"
        f"<vertices>{verts}</vertices><triangles>{tris}</triangles>"
        "</mesh></object></resources><build><item objectid=\"1\"/></build></model>"
    )
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("3D/3dmodel.model", xml)


if __name__ == "__main__":
    unittest.main()
