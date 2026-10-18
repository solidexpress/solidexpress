"""Analytic combination spanner used only by the checker unit tests.

Shoelace + analytic ring + void-angle fillets. The CLI checker does not
import this module. volume() returns the stage table; probes measure
inside() and bbox(). Mutants override one field; they do not add branches.
"""
from dataclasses import dataclass

import numpy as np

from check_rung07 import PART, VOLUMES
from geom import Topology


@dataclass
class ImplicitSpanner:
    """Boss + optional neck fillets + optional both-face recess. Tests only."""

    stage: str
    handle_sign: float = 1.0
    swapped_axes: bool = False
    one_face: bool = False
    hex_across_corners: bool = False
    wall_less: bool = False
    two_body: bool = False
    volume_override: float = None
    ymin: float = None
    ymax: float = None

    @staticmethod
    def for_stage(stage, **overrides):
        data = {"stage": stage}
        data.update(overrides)
        return ImplicitSpanner(**data)

    def volume(self):
        if self.volume_override is not None:
            return float(self.volume_override)
        return float(VOLUMES[self.stage])

    def topology(self):
        return Topology(0, 0, 2 if self.two_body else 1)

    def bbox(self):
        mn = np.array(PART["BBOX_MIN"], float)
        size = np.array(PART["BBOX_SIZE"], float)
        if self.swapped_axes:
            # Prep's swapped-axes mutant: Y half-extent 25.22 → size 50.4.
            size[1] = 50.4
            mn[1] = -25.2
        if self.handle_sign < 0:
            xmax = -mn[0]
            xmin = -(mn[0] + size[0])
            mn[0] = xmin
            size[0] = xmax - xmin
        if self.ymin is not None:
            mn[1] = float(self.ymin)
        if self.ymax is not None:
            size[1] = float(self.ymax) - mn[1]
        return mn, mn + size

    def inside(self, point):
        x, y, z = float(point[0]), float(point[1]), float(point[2])
        p = (round(x, 3), round(y, 3), round(z, 3))
        if p in {(120.0, 0.0, 2.5), (120.0, 0.0, -2.5)}:
            if self.stage not in ("mirror", "final"):
                return True
            if self.one_face and p[2] < 0:
                return True
            return False
        if p == (240.0, 15.0, 0.0):
            return not (self.hex_across_corners or self.wall_less)
        if p in {(0.0, 18.0, 0.0), (120.0, 0.0, 0.0)}:
            return True
        if p in {
            (-30.0, 0.0, 0.0),
            (240.0, 0.0, 0.0),
            (270.0, 0.0, 0.0),
            (0.0, 0.0, 8.0),
            (120.0, 0.0, 4.0),
        }:
            return False
        return abs(z) <= 5.0 and -25.0 <= x <= 256.5 and abs(y) <= 27.3
