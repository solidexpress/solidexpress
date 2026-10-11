"""Shared mesh queries for the rung checkers.

Owns 3MF loading, ray casting, manifold and topology reports, and the PASS/FAIL printer.
"""
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass

import numpy as np


def load_3mf(path):
    z = zipfile.ZipFile(path)
    name = [n for n in z.namelist() if n.lower().endswith('.model')][0]
    root = ET.fromstring(z.read(name))
    ns = {'m': root.tag.split('}')[0].strip('{')}
    V, T = [], []
    for mesh in root.iter('{%s}mesh' % ns['m']):
        base = len(V)
        for v in mesh.iter('{%s}vertex' % ns['m']):
            V.append((float(v.get('x')), float(v.get('y')), float(v.get('z'))))
        for t in mesh.iter('{%s}triangle' % ns['m']):
            T.append((base + int(t.get('v1')), base + int(t.get('v2')), base + int(t.get('v3'))))
    return np.array(V, float), np.array(T, int)

def tri_arrays(V, T):
    return V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]

def ray_hits(tris, o, d):
    """Return sorted positive t of ray o + t d against all triangles (Moller-Trumbore)."""
    a, b, c = tris
    e1, e2 = b - a, c - a
    p = np.cross(d, e2)
    det = np.einsum('ij,ij->i', e1, p)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    s = o - a
    u = np.einsum('ij,ij->i', s, p) * inv
    q = np.cross(s, e1)
    v = (q @ d) * inv
    t = np.einsum('ij,ij->i', e2, q) * inv
    m = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-9)
    return np.sort(t[m])

def inside(tris, pt):
    # parity along a slightly skewed direction; majority of 3 directions for robustness
    votes = 0
    for d in ([1, 0.0123, 0.0071], [0.0091, 1, 0.0137], [0.0113, 0.0067, 1]):
        d = np.array(d) / np.linalg.norm(d)
        votes += len(ray_hits(tris, np.array(pt, float), d)) % 2
    return votes >= 2

def first_hit(tris, o, d):
    d = np.array(d, float); d /= np.linalg.norm(d)
    h = ray_hits(tris, np.array(o, float), d)
    return h[0] if len(h) else None

def manifold_report(V, T):
    key = np.round(V, 6)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    TT = inv[T]
    TT = TT[(TT[:, 0] != TT[:, 1]) & (TT[:, 1] != TT[:, 2]) & (TT[:, 0] != TT[:, 2])]  # drop sliver/degenerate tris
    edges = np.sort(np.concatenate([TT[:, [0, 1]], TT[:, [1, 2]], TT[:, [2, 0]]]), axis=1)
    _, counts = np.unique(edges, axis=0, return_counts=True)
    return int((counts != 2).sum()), len(counts)


@dataclass(frozen=True)
class Topology:
    open_edges: int
    nonmanifold_edges: int
    components: int


def _welded(V, T):
    key = np.round(V, 6)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    TT = inv[np.asarray(T, int)]
    keep = (TT[:, 0] != TT[:, 1]) & (TT[:, 1] != TT[:, 2]) & (TT[:, 0] != TT[:, 2])
    return TT[keep]


def topology_report(V, T):
    """Open edges, orientation-inconsistent edges, and triangle components.

    `manifold_report` counts undirected edges, so a single flipped triangle
    still looks closed. This report treats a same-direction pair as non-manifold
    and counts bodies that do not share an edge.
    """
    TT = _welded(V, T)
    n = len(TT)
    if n == 0:
        return Topology(0, 0, 0)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    uses = {}
    for ti, tri in enumerate(TT):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            u, v = int(tri[a]), int(tri[b])
            if u < v:
                key, sign = (u, v), 1
            else:
                key, sign = (v, u), -1
            uses.setdefault(key, []).append((ti, sign))
    open_edges = 0
    nonmanifold = 0
    for edge_uses in uses.values():
        for ti, _sign in edge_uses[1:]:
            union(edge_uses[0][0], ti)
        count = len(edge_uses)
        if count == 1:
            open_edges += 1
        elif count == 2:
            if edge_uses[0][1] == edge_uses[1][1]:
                nonmanifold += 1
        else:
            nonmanifold += 1
    components = len({find(i) for i in range(n)})
    return Topology(open_edges, nonmanifold, components)


@dataclass(frozen=True)
class Row:
    name: str
    ok: bool
    got: object
    want: object

    def __post_init__(self):
        object.__setattr__(self, "ok", bool(self.ok))


class Report:
    def __init__(self): self.rows = []; self.fail = 0
    def add(self, name, ok, got, want):
        self.rows.append((name, 'PASS' if ok else 'FAIL', got, want)); self.fail += (not ok)
    def extend(self, rows):
        for row in rows:
            self.add(row.name, row.ok, row.got, row.want)
    def show(self):
        w = max(len(r[0]) for r in self.rows)
        for n, s, g, wnt in self.rows:
            print(f"{s:4}  {n:<{w}}  got {g}  want {wnt}")
        print(f"\n{len(self.rows)-self.fail}/{len(self.rows)} passed")


R = Report
