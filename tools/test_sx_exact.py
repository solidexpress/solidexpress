#!/usr/bin/env python3
"""C-py for WP-L1: CLI box-hole report matches Catch2 (Circle r=5, analytic volume)."""

from __future__ import annotations

import math
import unittest

from sx_exact import circles, feature_params, run_verb, volume


class TestSxExactBoxHole(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = run_verb("box-hole")

    def test_circle_radius_5(self) -> None:
        found = circles(self.report)
        self.assertGreaterEqual(len(found), 1, "expected a GeomAbs_Circle hole edge")
        radii = [float(c["radius"]) for c in found]
        self.assertTrue(any(abs(r - 5.0) <= 1e-6 for r in radii), radii)

    def test_volume_analytic(self) -> None:
        analytic = 20.0 * 20.0 * 10.0 - math.pi * 5.0 * 5.0 * 10.0
        vol = volume(self.report)
        self.assertLess(abs(vol - analytic) / analytic, 1e-9)

    def test_hole_diameter_as_written(self) -> None:
        params = feature_params(self.report, "hole")
        self.assertIsNotNone(params)
        assert params is not None
        self.assertEqual(params["diameter"], 10.0)
        self.assertEqual(params["type"], "simple")


if __name__ == "__main__":
    unittest.main()
