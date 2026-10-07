#!/usr/bin/env python3
"""Rung-1 acceptance checks for the UBC ELEC391 Exercise 2 wrench / Exercise 1 nut.

Usage:
  python3 check_rung01.py wrench <file.3mf> [--allow-mirror]
  python3 check_rung01.py blank  <file.3mf>   # right after Extrude 10: size and head at +X
  python3 check_rung01.py nut    <file.3mf>
  python3 check_rung01.py thick  <file.3mf> <T>   # after editing base extrude 10 -> T (Up To Surface survival)

Needs only numpy. Reads the first <mesh> objects of a 3MF (all objects merged).
Source frame (wrench): pivot centre (0,0), head centre (200,0), bottom z=0, top z=10,
jaw opening toward +X+Y at 45 deg. The mesh is auto-aligned by its bbox (min corner
moved to (-10,-22.5,0)); the head end is found from the vertices (the X end whose last 10 mm has the larger Y extent); the script then tries only the rotation and the mirror for that end and reports which one it used (mirror only accepted with --allow-mirror).
Tolerance: 0.2 mm on every length.
DIAG: run `wrench` on a T≠10 file only to read the other fillet rows; `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge` and `1mm fillet on jaw top edge` fail by design at T≠10 — `thick` is the pass. `bbox Z`, the grip slot and both fillet rows fail by design at T≠10; the other rows are the diagnostic.
"""
import sys, zipfile, re, math
import xml.etree.ElementTree as ET
import numpy as np

TOL = 0.2

def diag_expected_failures_at_t(T):
    """Wrench-row names that fail by design when T is not 10. Pure; no numpy.

    `wrench` is the T=10 handout checker. At T≠10 the grip-slot probe sits at
    z=8.75 (between the floor fillet 7.5–8.5 and the rim fillet 9–10), which is
    inside solid material, so that row reads 0 samples open along with bbox Z
    and both 1 mm top-edge fillet rows. `thick` is the T-aware pass.
    """
    if abs(float(T) - 10) > TOL:
        return [
            'bbox Z (thickness)',
            'grip slot present at y=0,z=8.75',
            '1mm fillet top outer edge',
            '1mm fillet on jaw top edge',
        ]
    return []

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

class R:
    def __init__(self): self.rows = []; self.fail = 0
    def add(self, name, ok, got, want):
        self.rows.append((name, 'PASS' if ok else 'FAIL', got, want)); self.fail += (not ok)
    def show(self):
        w = max(len(r[0]) for r in self.rows)
        for n, s, g, wnt in self.rows:
            print(f"{s:4}  {n:<{w}}  got {g}  want {wnt}")
        print(f"\n{len(self.rows)-self.fail}/{len(self.rows)} passed")

def wrench_tests(tris, r):
    s2 = math.sqrt(2) / 2
    ax = np.array([s2, s2, 0]); pv = np.array([-s2, s2, 0])
    H = np.array([200.0, 0, 0])
    J = lambda u, v, z: (H + u * ax + v * pv + [0, 0, z]).tolist()
    # pivot hole d10 through
    r.add('pivot hole open z=0.5/5/9.5', all(not inside(tris, (0, 0, z)) for z in (0.5, 5, 9.5)), 'open?', 'open')
    hx = [first_hit(tris, (0, 0, 5), (1, 0, 0)), first_hit(tris, (0, 0, 5), (-1, 0, 0))]
    r.add('pivot hole diameter', None not in hx and abs(sum(hx) - 10) <= TOL, hx and None not in hx and round(sum(hx), 3), '10.0')
    r.add('pivot boss ring solid (7.5,0,5)', inside(tris, (7.5, 0, 5)), '', 'inside')
    # jaw through-cut
    jaw_open = all(not inside(tris, J(u, 0, z)) for u in (3, 11, 18) for z in (0.5, 5, 9.5))
    r.add('jaw open through full depth', jaw_open, '', 'open at u=3/11/18, z=0.5/5/9.5')
    r.add('jaw floor at head centre (u=-1 solid)', inside(tris, J(-1, 0, 5)), '', 'inside')
    fl = first_hit(tris, J(10, 0, 5), -ax)
    r.add('jaw floor through head centre', fl is not None and abs(fl - 10) <= TOL, fl and round(fl, 3), '10.0 from u=10')
    for z in (2, 5, 8):
        a = first_hit(tris, J(10, 0, z), pv); b = first_hit(tris, J(10, 0, z), -pv)
        g = None if None in (a, b) else round(a + b, 3)
        r.add(f'jaw opening AF at z={z}', g is not None and abs(g - 20) <= TOL, g, '20.0')
    # grip slot (X position not dimensioned in source: search 60..130)
    xs = [x for x in np.arange(60, 130, 1.0) if not inside(tris, (x, 0, 8.75))]
    r.add('grip slot present at y=0,z=8.75', len(xs) > 0, f'{len(xs)} samples open', '>0')
    if xs:
        xm = float(np.median(xs))
        top = first_hit(tris, (xm, 0, 30), (0, 0, -1))
        floor = None if top is None else 30 - top
        r.add('grip slot floor z', floor is not None and abs(floor - 7.5) <= TOL, floor and round(floor, 3), '7.5 (2.5 deep)')
        # z=8.75 is between the floor fillet (7.5-8.5) and the rim fillet (9-10)
        a = first_hit(tris, (xm, 0, 8.75), (0, 1, 0)); b = first_hit(tris, (xm, 0, 8.75), (0, -1, 0))
        g = None if None in (a, b) else round(a + b, 3)
        r.add('grip slot width (z=8.75)', g is not None and abs(g - 10) <= TOL, g, '10.0 (2 x R5)')
        a = first_hit(tris, (xm, 0, 8.75), (1, 0, 0)); b = first_hit(tris, (xm, 0, 8.75), (-1, 0, 0))
        g = None if None in (a, b) else round(a + b, 3)
        r.add('grip slot length (z=8.75)', g is not None and abs(g - 160) <= TOL, g, '160.0 (150 c-c + 2 x R5)')
        if g is not None:
            r.add('grip slot X centre (info only)', True, round(xm + (a - b) / 2, 2), 'not dimensioned in source; figure ~93.5')
        r.add('slot floor 1mm fillet (corner material)', inside(tris, (xm, 4.9, 7.6)), '', 'inside')
        r.add('below slot is solid', inside(tris, (xm, 0, 6.5)), '', 'inside')
    # head-shaft R10 fillets
    r.add('head-shaft R10 fillet +Y', inside(tris, (179.0, 10.5, 5)), '', 'inside')
    r.add('head-shaft R10 fillet -Y', inside(tris, (179.0, -10.5, 5)), '', 'inside')
    r.add('R10 fillet not oversized (174,12.5)', not inside(tris, (174.0, 12.5, 5)), '', 'outside')
    # 1 mm edge fillets on top & bottom faces
    r.add('1mm fillet top outer edge', not inside(tris, (-9.9, 0, 9.9)), '', 'outside')
    r.add('1mm fillet bottom outer edge', not inside(tris, (-9.9, 0, 0.1)), '', 'outside')
    r.add('outer wall solid mid-z', inside(tris, (-9.7, 0, 5)), '', 'inside')
    r.add('1mm fillet on jaw top edge', not inside(tris, J(10, 10.08, 9.92)), '', 'outside')

def thick_jaw_top_probe(T):
    """XY of wrench J(10, 10.08, 9.92) shifted to z = T − 0.08.

    At T = 14 this is (199.9434, 14.1986, 13.92). The DIAG wrench row probes
    z ≈ 9.92, inside solid material at T ≠ 10, so `thick` is the T-aware pass.
    """
    s2 = math.sqrt(2) / 2
    return (200 + (10 - 10.08) * s2, (10 + 10.08) * s2, T - 0.08)

END_BAND = 10.0

def head_at_min_x(V):
    """True when the wide (head) end of the part is at the minimum-X end.

    The head end is the X end whose last END_BAND mm has the larger Y extent
    (head dia 45 against pivot boss dia 20). Geometry decides this, never a
    count of failed rows, so a blank without holes cannot report a mirror.
    """
    lo, hi = V[:, 0].min(), V[:, 0].max()
    def ye(m):
        y = V[m, 1]
        return float(y.max() - y.min())
    return ye(V[:, 0] <= lo + END_BAND) > ye(V[:, 0] >= hi - END_BAND)

def orientation_candidates(V):
    """(flipx, flipy) pairs to try. The first is the pure rotation, the second the mirror."""
    if head_at_min_x(V):
        return [(True, True), (True, False)]
    return [(False, False), (False, True)]

def align(V, flipx, flipy, want_min):
    W = V.copy()
    if flipx: W[:, 0] *= -1
    if flipy: W[:, 1] *= -1
    return W - W.min(0) + np.array(want_min)

def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    kind, path = sys.argv[1], sys.argv[2]
    allow_mirror = '--allow-mirror' in sys.argv
    V, T = load_3mf(path)
    ext = V.max(0) - V.min(0)
    r = R()
    bad, ne = manifold_report(V, T)
    print(f"{path}: {len(V)} verts, {len(T)} tris, bbox {np.round(ext,3).tolist()}")
    r.add('mesh closed (every edge used twice)', bad == 0, f'{bad}/{ne} bad edges', '0')
    if kind == 'thick':
        T_ = float(sys.argv[3])
        r.add('bbox Z == new thickness', abs(ext[2] - T_) <= TOL, round(ext[2], 3), f'{T_}')
        s2 = math.sqrt(2) / 2
        best = None
        for fx, fy in orientation_candidates(V):
            W = align(V, fx, fy, (-10, -22.5, 0)); tr = tri_arrays(W, T)
            zs = (0.5, T_ / 2, T_ - 0.5)
            ok_h = all(not inside(tr, (0, 0, z)) for z in zs)
            ok_j = all(not inside(tr, (200 + u * s2, u * s2, z)) for u in (3, 11, 18) for z in zs)
            sc = ok_h + ok_j
            if best is None or sc > best[0]: best = (sc, ok_h, ok_j, fx, fy)
        _, ok_h, ok_j, fx, fy = best
        r.add('pivot hole still through at new T', ok_h, f'flipX={fx} flipY={fy}', 'open at 0.5, T/2, T-0.5')
        r.add('jaw still through at new T', ok_j, '', 'open at 0.5, T/2, T-0.5')
        W = align(V, fx, fy, (-10, -22.5, 0)); tr = tri_arrays(W, T)
        z_open = T_ - 1.25
        xs = [x for x in np.arange(60, 130, 1.0) if not inside(tr, (float(x), 0.0, z_open))]
        xm = float(np.median(xs)) if len(xs) else None
        floor = None
        if xm is not None:
            hit = first_hit(tr, (xm, 0.0, T_ + 5.0), (0, 0, -1))
            floor = None if hit is None else (T_ + 5.0) - hit
        slot_ok = (
            xm is not None
            and not inside(tr, (xm, 0.0, T_ - 1.25))
            and floor is not None and abs(floor - (T_ - 2.5)) <= TOL
            and not inside(tr, (xm, 0.0, T_ - 0.5))
        )
        r.add('grip slot open from the top', slot_ok,
              '' if slot_ok else f'xm={xm} floor={floor}',
              'open at z=T-1.25, floor T-2.5, solid skin absent at z=T-0.5')
        r.add('1mm top fillet at new T', not inside(tr, (-9.9, 0.0, T_ - 0.1)), '', 'outside')
        r.add('1mm jaw top fillet at new T', not inside(tr, thick_jaw_top_probe(T_)), '', 'outside')
        r.show(); sys.exit(1 if r.fail else 0)
    if kind == 'nut':
        e = sorted(ext[:2])
        r.add('nut AF (min XY extent)', abs(e[0] - 20) <= TOL, round(e[0], 3), '20.0')
        r.add('nut AC (max XY extent)', abs(e[1] - 23.094) <= TOL, round(e[1], 3), '23.094')
        r.add('nut thickness', abs(ext[2] - 7.5) <= TOL, round(ext[2], 3), '7.5')
        W = V - (V.min(0) + V.max(0)) / 2 + [0, 0, ext[2] / 2]
        tris = tri_arrays(W, T)
        r.add('bore open', all(not inside(tris, (0, 0, z)) for z in (0.3, 3.75, 7.2)), '', 'open')
        a = first_hit(tris, (0, 0, 3.75), (1, 0, 0)); b = first_hit(tris, (0, 0, 3.75), (-1, 0, 0))
        g = None if None in (a, b) else round(a + b, 3)
        r.add('bore diameter', g is not None and abs(g - 10) <= TOL, g, '10.0')
        r.add('nut body solid at r=8', inside(tris, (0, 8, 3.75)) or inside(tris, (8, 0, 3.75)), '', 'inside')
        r.show(); sys.exit(1 if r.fail else 0)
    if kind == 'blank':
        r.add('bbox X (length)', abs(ext[0] - 232.5) <= TOL, round(ext[0], 3), '232.5')
        r.add('bbox Y (head dia)', abs(ext[1] - 45) <= TOL, round(ext[1], 3), '45.0')
        r.add('bbox Z (thickness)', abs(ext[2] - 10) <= TOL, round(ext[2], 3), '10.0')
        r.add('head end at +X', not head_at_min_x(V), 'head at -X' if head_at_min_x(V) else 'head at +X', 'head at +X')
        r.show(); sys.exit(1 if r.fail else 0)
    # wrench
    r.add('bbox X (length)', abs(ext[0] - 232.5) <= TOL, round(ext[0], 3), '232.5')
    r.add('bbox Y (head dia)', abs(ext[1] - 45) <= TOL, round(ext[1], 3), '45.0')
    r.add('bbox Z (thickness)', abs(ext[2] - 10) <= TOL, round(ext[2], 3), '10.0')
    if abs(ext[2] - 10) > TOL:
        names = ', '.join(diag_expected_failures_at_t(ext[2]))
        print(
            f"DIAG: bbox Z is {ext[2]:.3f} mm, not 10 — this is the T=10 handout checker; "
            f"at T≠10 these four rows fail by design: {names}. Use `thick` for the pass."
        )
    best = None
    for fx, fy in orientation_candidates(V):
        W = align(V, fx, fy, (-10, -22.5, 0))
        rr = R(); wrench_tests(tri_arrays(W, T), rr)
        if best is None or rr.fail < best[0].fail:
            best = (rr, fx, fy)
    rr, fx, fy = best
    mirrored = (fx != fy)  # one flip = mirror image; two flips = 180 deg rotation
    r.add('orientation', (not mirrored) or allow_mirror,
          f'flipX={fx} flipY={fy}' + (' (MIRROR)' if mirrored else ''), 'rotation only (no mirror)')
    r.rows += rr.rows; r.fail += rr.fail
    r.show(); sys.exit(1 if r.fail else 0)

if __name__ == '__main__':
    main()
