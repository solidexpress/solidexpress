"""Analytic candlestick used only by the checker unit tests.

Pappus + frustum + centre-outside handle. The CLI checker does not import
this module. volume() returns the stage table; probes measure inside() and
bbox(). Mutants override one field; they do not add branches.
"""
from dataclasses import dataclass

import numpy as np

from check_rung06 import PART, VOLUMES
from geom import Topology


@dataclass
class ImplicitCandlestick:
    """Revolve + optional handle + optional drafted cut. Tests only."""

    stage: str
    height: float = PART["H"]
    handle_sign: float = 1.0
    ymin: float = 0.0
    xmax_override: float = None
    volume_override: float = None
    two_body: bool = False
    draft: bool = True
    equal_kept: bool = False

    @staticmethod
    def for_stage(stage, **overrides):
        data = {"stage": stage}
        if stage == "final":
            data["draft"] = True
        data.update(overrides)
        return ImplicitCandlestick(**data)

    def volume(self):
        if self.volume_override is not None:
            return float(self.volume_override)
        return float(VOLUMES[self.stage])

    def topology(self):
        return Topology(0, 0, 2 if self.two_body else 1)

    def bbox(self):
        z = 112.0
        y1 = float(self.height)
        y0 = float(self.ymin)
        if self.equal_kept:
            xmax = 150.0
            xmin = -xmax
        elif self.stage == "revolve":
            xmax = 112.0
            xmin = -xmax
        else:
            if self.handle_sign < 0:
                xmax = 112.0
                xmin = -192.1
            else:
                xmin = -112.0
                xmax = 192.1 if self.xmax_override is None else float(self.xmax_override)
        return np.array((xmin, y0, -z)), np.array((xmax, y1, z))

    def inside(self, point):
        x, y, z = float(point[0]), float(point[1]), float(point[2])
        p = (round(x, 3), round(y, 3), round(z, 3))
        if p == (13.0, 195.0, 0.0):
            return bool(self.stage == "final" and self.draft)
        if p == (0.0, 205.0, 0.0):
            return self.stage != "final"
        if p in {(0.0, 100.0, 0.0), (40.0, 10.0, 0.0), (0.0, 210.0, 0.0)}:
            return True
        if p in {(113.0, 10.0, 0.0), (0.0, 221.0, 0.0), (193.0, 86.0, 0.0)}:
            return False
        rho = float(np.hypot(x, z))
        if y < self.ymin - 1e-9 or y > self.height + 1e-9:
            return False
        return rho <= 90.0 + 1e-9
