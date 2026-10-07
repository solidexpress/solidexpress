#!/usr/bin/env python3
"""Unit tests for the orientation logic in check_rung01.py.

Run: python3 tools/test_check_rung01.py
"""
import math
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_rung01 as c


def blank_vertices(head_x=200.0, pivot_x=0.0, thickness=10.0):
    """Vertices of a pivot disc (r10), a shaft (half width 10) and a head disc (r22.5)."""
    pts = []
    for cx, r in ((pivot_x, 10.0), (head_x, 22.5)):
        for k in range(48):
            a = 2 * math.pi * k / 48
            for z in (0.0, thickness):
                pts.append((cx + r * math.cos(a), r * math.sin(a), z))
    lo, hi = sorted((pivot_x, head_x))
    for x in np.linspace(lo, hi, 20):
        for y in (-10.0, 10.0):
            for z in (0.0, thickness):
                pts.append((x, y, z))
    return np.array(pts, float)


class OrientationTests(unittest.TestCase):
    def test_head_on_plus_x_is_a_rotation(self):
        v = blank_vertices()
        self.assertFalse(c.head_at_min_x(v))
        self.assertEqual(c.orientation_candidates(v)[0], (False, False))

    def test_head_on_minus_x_tries_the_180_rotation_first(self):
        v = blank_vertices(head_x=-200.0)
        self.assertTrue(c.head_at_min_x(v))
        self.assertEqual(c.orientation_candidates(v)[0], (True, True))

    def test_rotation_about_z_is_never_reported_as_a_mirror(self):
        v = blank_vertices()
        rot = v.copy()
        rot[:, 0] *= -1
        rot[:, 1] *= -1
        fx, fy = c.orientation_candidates(rot)[0]
        self.assertEqual(fx, fy)

    def test_mirror_candidate_is_second(self):
        for v in (blank_vertices(), blank_vertices(head_x=-200.0)):
            fx, fy = c.orientation_candidates(v)[1]
            self.assertNotEqual(fx, fy)


class ThickJawProbeTests(unittest.TestCase):
    def test_thick_jaw_top_probe_at_t14(self):
        x, y, z = c.thick_jaw_top_probe(14.0)
        self.assertAlmostEqual(x, 199.9434, delta=1e-3)
        self.assertAlmostEqual(y, 14.1986, delta=1e-3)
        self.assertAlmostEqual(z, 13.92, delta=1e-3)


class DiagNoteTests(unittest.TestCase):
    def test_four_rows_fail_by_design_at_t14(self):
        want = [
            'bbox Z (thickness)',
            'grip slot present at y=0,z=8.75',
            '1mm fillet top outer edge',
            '1mm fillet on jaw top edge',
        ]
        self.assertEqual(c.diag_expected_failures_at_t(14.0), want)
        self.assertEqual(c.diag_expected_failures_at_t(10.0), [])
        self.assertEqual(c.diag_expected_failures_at_t(10.1), [])
        self.assertEqual(c.TOL, 0.2)


if __name__ == "__main__":
    unittest.main()
