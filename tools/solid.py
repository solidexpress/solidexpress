"""What a checker measures, and the mesh that satisfies it.

`Solid` is bounds, volume, membership and ray hits. `TriMesh` is that
protocol on a triangle mesh. `Probe` is one named measurement.
"""
from typing import Protocol

import numpy as np

from geom import Topology, ray_hits, topology_report, tri_arrays
from geom import inside as mesh_inside


class Solid(Protocol):
    """Bounds, volume, membership, sorted ray parameters, topology."""

    def bbox(self): ...
    def volume(self) -> float: ...
    def inside(self, point) -> bool: ...
    def hits(self, origin, direction) -> list[float]: ...
    def topology(self) -> Topology: ...


class TriMesh:
    """Solid from a triangle mesh. Geometry goes through `geom`."""

    def __init__(self, V, T):
        self.V = np.asarray(V, float)
        self.T = np.asarray(T, int)
        self._tris = tri_arrays(self.V, self.T)

    def bbox(self):
        return self.V.min(0), self.V.max(0)

    def volume(self):
        a, b, c = self._tris
        signed = float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)
        return abs(signed)

    def inside(self, p):
        return bool(mesh_inside(self._tris, p))

    def hits(self, origin, direction):
        d = np.asarray(direction, float)
        d = d / np.linalg.norm(d)
        ts = ray_hits(self._tris, np.asarray(origin, float), d)
        out = []
        for t in ts:
            tf = float(t)
            if not out or tf - out[-1] > 1e-5:
                out.append(tf)
        return out

    def topology(self):
        return topology_report(self.V, self.T)


class Probe:
    """One measurement. `run` returns rows; a stage is a list of probes."""

    def run(self, solid: Solid) -> list:
        raise NotImplementedError
