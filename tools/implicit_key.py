"""Analytic hex key used only by the checker unit tests.

The CLI checker does not import this module. volume() is PART['VOLUME'].
"""
import math

import numpy as np

from check_rung04 import PART
from geom import Topology


_END_EPS = 1e-6


class ImplicitKey:
    """Centred swept hex. Mutants override one field and fail one probe."""

    af: float = PART["AF"]
    leg_y: float = PART["LEG_Y"]
    leg_z: float = PART["LEG_Z"]
    bend_d: float = PART["BEND_D"]
    pose: str = "point_up"
    shift: tuple = (0.0, 0.0, 0.0)
    volume_override: float = None
    miss_arc: bool = False

    def __init__(self, af=None, leg_y=None, leg_z=None, bend_d=None, pose="point_up",
                 shift=(0.0, 0.0, 0.0), volume=None, miss_arc=False):
        self.af = float(PART["AF"] if af is None else af)
        self.leg_y = float(PART["LEG_Y"] if leg_y is None else leg_y)
        self.leg_z = float(PART["LEG_Z"] if leg_z is None else leg_z)
        self.bend_d = float(PART["BEND_D"] if bend_d is None else bend_d)
        self.pose = pose
        self.shift = (float(shift[0]), float(shift[1]), float(shift[2]))
        self.volume_override = None if volume is None else float(volume)
        self.miss_arc = bool(miss_arc)

    @property
    def radius(self):
        return self.af / math.sqrt(3.0)

    @property
    def bend_r(self):
        return self.bend_d / 2.0

    def volume(self):
        if self.volume_override is not None:
            return self.volume_override
        return float(PART["VOLUME"])

    def topology(self):
        return Topology(0, 0, 1)

    def hits(self, origin, direction):
        return []

    def bbox(self):
        half = self.af / 2.0
        circum = self.radius
        if self.pose == "flats":
            x_half = circum
            y_min = -half
            z_max = self.leg_z + half
        else:
            x_half = half
            y_min = -circum
            z_max = self.leg_z + circum
        sx, sy, sz = self.shift
        return (
            np.array((-x_half + sx, y_min + sy, 0.0 + sz)),
            np.array((x_half + sx, self.leg_y + sy, z_max + sz)),
        )

    def inside(self, point):
        p = np.asarray(point, float) - np.asarray(self.shift, float)
        hit = self._closest(p)
        if hit is None:
            return False
        if self.miss_arc and hit["piece"] == "arc":
            return False
        if hit["past_start"] or hit["past_end"]:
            return False
        return self._in_hex(hit["lx"], hit["ly"])

    def _in_hex(self, lx, ly):
        half = self.af / 2.0
        ax = abs(lx)
        if ax > half + 1e-9:
            return False
        if self.pose == "flats":
            limit = self.radius - abs(ly) / math.sqrt(3.0)
            return abs(lx) <= limit + 1e-9 and abs(ly) <= half + 1e-9
        limit = self.radius - ax / math.sqrt(3.0)
        return abs(ly) <= limit + 1e-9

    def _closest(self, point):
        best = None
        for hit in (self._seg_short(point), self._arc(point), self._seg_long(point)):
            if best is None or hit["dist"] < best["dist"]:
                best = hit
        return best

    def _section(self, point, foot, local_y):
        delta = point - foot
        return float(delta[0]), float(np.dot(delta, local_y)), float(np.linalg.norm(delta))

    def _seg_short(self, point):
        z1 = self.leg_z - self.bend_r
        z = float(point[2])
        clamped = min(max(z, 0.0), z1)
        foot = np.array((0.0, 0.0, clamped))
        local_y = np.array((0.0, 1.0, 0.0))
        lx, ly, dist = self._section(point, foot, local_y)
        return {
            "piece": "short",
            "dist": dist,
            "lx": lx,
            "ly": ly,
            "past_start": z < -_END_EPS and abs(clamped) <= _END_EPS,
            "past_end": False,
        }

    def _seg_long(self, point):
        y0 = self.bend_r
        y1 = self.leg_y
        y = float(point[1])
        clamped = min(max(y, y0), y1)
        foot = np.array((0.0, clamped, self.leg_z))
        local_y = np.array((0.0, 0.0, -1.0))
        lx, ly, dist = self._section(point, foot, local_y)
        return {
            "piece": "long",
            "dist": dist,
            "lx": lx,
            "ly": ly,
            "past_start": False,
            "past_end": y > y1 + _END_EPS and abs(clamped - y1) <= _END_EPS,
        }

    def _arc(self, point):
        cy = self.bend_r
        cz = self.leg_z - self.bend_r
        radius = self.bend_r
        vy = float(point[1]) - cy
        vz = float(point[2]) - cz
        if abs(vy) < 1e-15 and abs(vz) < 1e-15:
            theta = math.pi / 4.0
        else:
            theta = math.atan2(vz, -vy)
        theta = min(max(theta, 0.0), math.pi / 2.0)
        foot = np.array((0.0, cy - radius * math.cos(theta), cz + radius * math.sin(theta)))
        local_y = np.array((0.0, math.cos(theta), -math.sin(theta)))
        lx, ly, dist = self._section(point, foot, local_y)
        return {
            "piece": "arc",
            "dist": dist,
            "lx": lx,
            "ly": ly,
            "past_start": False,
            "past_end": False,
        }
