"""Analytic pin (two R10 hemispheres + Ø10×35 shank) used only by checker tests.

The CLI checker does not import this module. volume() returns the table
(mutants override). Probes measure bbox(), inside(), and topology().
"""
from dataclasses import dataclass, field

import numpy as np

from check_rung08 import PART, VOLUMES, hole_xy
from geom import Topology


@dataclass
class ImplicitPin:
    """Barbell pin, origin at the tail pole, axis +Y. Tests only."""

    overall: float = None
    two_body: bool = False
    volume_override: float = None

    def volume(self):
        if self.volume_override is not None:
            return float(self.volume_override)
        overall = PART["OVERALL"] if self.overall is None else float(self.overall)
        if abs(overall - 50.0) < 1e-9:
            return float(PART["VOL_50"])
        return float(VOLUMES["pin"])

    def topology(self):
        return Topology(0, 0, 2 if self.two_body else 1)

    def bbox(self):
        overall = PART["OVERALL"] if self.overall is None else float(self.overall)
        r = float(PART["HEAD_R"])
        mn = np.array([-r, 0.0, -r], float)
        mx = np.array([r, overall, r], float)
        return mn, mx

    def inside(self, point):
        x, y, z = (float(point[0]), float(point[1]), float(point[2]))
        r = float(PART["SHANK_R"])
        overall = PART["OVERALL"] if self.overall is None else float(self.overall)
        head_r = float(PART["HEAD_R"])
        tail_r = float(PART["TAIL_R"])
        radial = (x * x + z * z) ** 0.5
        if 0.0 <= y <= tail_r:
            cx, cy, cz = 0.0, tail_r, 0.0
            return (x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2 <= tail_r * tail_r + 1e-9
        if tail_r <= y <= overall - head_r:
            return radial <= r + 1e-9
        if overall - head_r <= y <= overall:
            cx, cy, cz = 0.0, overall - head_r, 0.0
            return (x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2 <= head_r * head_r + 1e-9
        return False

    def hits(self, origin, direction):
        return []


@dataclass
class ImplicitPipeline:
    """Assembly stub for pipes / bolted / final checker tests."""

    stage: str
    n_pipe: int = 2
    n_nut: int = 16
    n_pin: int = 8
    n_wrench: int = 1
    outer_joint: bool = False
    stacked: bool = False
    jaw: float = None
    coaxial: bool = True
    volume_override: float = None
    bbox_min: list = None
    bbox_max: list = None
    nut_zs: list = field(default_factory=list)
    pin_axes: list = field(default_factory=list)

    @staticmethod
    def for_stage(stage, **overrides):
        data = {"stage": stage}
        data.update(overrides)
        return ImplicitPipeline(**data)

    def counts(self):
        return {
            "pipe": int(self.n_pipe),
            "nut": int(self.n_nut),
            "pin": int(self.n_pin),
            "wrench": int(self.n_wrench),
        }

    def volume(self):
        if self.volume_override is not None:
            return float(self.volume_override)
        if self.stage == "pipes":
            return 2.0 * float(PART["V_PIPE"])
        if self.stage == "bolted":
            return float(VOLUMES["bolted"])
        wrench = PART["V_WRENCH"]
        if wrench is None:
            return float(VOLUMES["bolted"])
        return float(VOLUMES["bolted"]) + float(wrench)

    def topology(self):
        return Topology(0, 0, 1)

    def bbox(self):
        if self.bbox_min is not None and self.bbox_max is not None:
            mn = np.array(self.bbox_min, float)
            mx = np.array(self.bbox_max, float)
            return mn, mx
        if self.stacked or self.outer_joint:
            mn = np.array(PART["PIPES_BBOX_MIN"], float)
            mx = mn + np.array([PART["FLANGE_D"], PART["FLANGE_D"], 520.0], float)
            return mn, mx
        key = "FINAL" if self.stage == "final" else "PIPES"
        mn = np.array(PART[f"{key}_BBOX_MIN"], float)
        mx = np.array(PART[f"{key}_BBOX_MAX"], float)
        return mn, mx

    def hole_axes_xy(self):
        if self.pin_axes:
            return [tuple(a) for a in self.pin_axes]
        return [hole_xy(i) for i in range(int(PART["N_HOLES"]))]

    def nut_face_zs(self):
        if self.nut_zs:
            return [float(z) for z in self.nut_zs]
        lo, hi = float(PART["NUT_Z_LO"]), float(PART["NUT_Z_HI"])
        n = int(self.n_nut)
        half = n // 2
        return [lo] * half + [hi] * (n - half)

    def wrench_state(self):
        jaw = float(PART["JAW"] if self.jaw is None else self.jaw)
        return {
            "flange_z": float(PART["NUT_Z_LO"]),
            "jaw": jaw,
            "gap": jaw,
            "tangent": abs(jaw - float(PART["JAW"])) <= 1e-9,
            "handle_plus_x": True,
        }

    def pipes_coaxial(self):
        return bool(self.coaxial)

    def joint_z(self):
        if self.outer_joint or self.stacked:
            return 0.0
        return float(PART["JOINT_Z"])

    def inside(self, point):
        x, y, z = (float(point[0]), float(point[1]), float(point[2]))
        p = (round(x, 5), round(y, 5), round(z, 5))
        inside = {
            (70.0, 0.0, 125.0),
            (70.0, 0.0, 520.0),
            (0.0, 94.0, 260.0),
            (0.0, 102.0, 246.25),
        }
        outside = {
            (0.0, 0.0, 125.0),
            (113.0, 0.0, 0.0),
            (0.0, 0.0, -261.0),
            (0.0, 0.0, 781.0),
        }
        if p in inside:
            return True
        if p in outside:
            return False
        return False

    def hits(self, origin, direction):
        return []
