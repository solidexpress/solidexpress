#!/usr/bin/env python3
"""Unit tests for the rung-2 box checker. No kernel, no app.

Run: python3 tools/test_check_rung02.py
"""
import io
import json
import math
import subprocess
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_rung01
import check_rung02 as c
import geom
from implicit_part import ImplicitPart


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "tools" / "check_rung02.py"


def _rows(stage, solid, width):
    return c.check(stage, solid, width)


def _failed(rows):
    return [row.name for row in rows if not row.ok]


def _passed(rows, needle):
    return any(row.ok and needle in row.name for row in rows)


class ParamsTests(unittest.TestCase):
    def test_params_json_has_the_walk_keys(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["params"])
        self.assertEqual(rc, 0)
        data = json.loads(buf.getvalue())
        for key in ("X", "H", "R", "WALL", "HOLE_D", "HOLE_Y", "HOLE_Z", "OPEN",
                    "TOL", "VOLUME_TOL", "widths", "volumes"):
            self.assertIn(key, data)
        self.assertEqual(data["widths"], [60, 65])
        self.assertAlmostEqual(data["volumes"]["60"]["final"], 93388.3, delta=0.1)
        self.assertAlmostEqual(data["volumes"]["65"]["final"], 98138.3, delta=0.1)
        self.assertAlmostEqual(data["volumes"]["60"]["no_hole"], 94173.7, delta=0.1)
        self.assertAlmostEqual(data["volumes"]["60"]["rounded"], 295708.0, delta=0.1)
        self.assertAlmostEqual(data["volumes"]["60"]["block"], 300000.0, delta=0.05)
        self.assertAlmostEqual(data["volumes"]["65"]["no_hole"], 98923.7, delta=0.1)
        self.assertEqual(data["HOLE_Y"], 35)
        self.assertEqual(data["HOLE_Z"], 40)


class StageTests(unittest.TestCase):
    def test_implicit_stages_pass(self):
        cases = (
            ("base", ImplicitPart.base(60), 60),
            ("base", ImplicitPart.base(65), 65),
            ("rounded", ImplicitPart.rounded(60), 60),
            ("rounded", ImplicitPart.rounded(65), 65),
            ("shell", ImplicitPart.shell(60), 60),
            ("shell", ImplicitPart.shell(65), 65),
            ("final", ImplicitPart.final(60), 60),
            ("final", ImplicitPart.final(65), 65),
        )
        for stage, solid, width in cases:
            rows = _rows(stage, solid, width)
            self.assertEqual(_failed(rows), [], msg=f"{stage} W={width} {rows}")

    def test_mesh_stages_pass(self):
        cases = (
            ("base", ImplicitPart.base(60), 60),
            ("rounded", ImplicitPart.rounded(60), 60),
            ("shell", ImplicitPart.shell(60), 60),
            ("final", ImplicitPart.final(60), 60),
            ("final", ImplicitPart.final(65), 65),
        )
        for stage, part, width in cases:
            solid = c.TriMesh(*mesh_from_implicit(part))
            rows = _rows(stage, solid, width)
            self.assertEqual(_failed(rows), [], msg=f"mesh {stage} W={width} {[ (r.name, r.ok, r.got) for r in rows ]}")


class MutationTests(unittest.TestCase):
    def _assert_named(self, stage, solid, width, needle):
        rows = _rows(stage, solid, width)
        failed = _failed(rows)
        self.assertTrue(any(needle in name for name in failed),
                        msg=f"expected {needle!r} to fail, got {[(r.name, r.ok, r.got) for r in rows]}")
        return rows

    def test_r5_and_r15_corners(self):
        for radius in (5.0, 15.0):
            rows = self._assert_named("rounded", ImplicitPart.rounded(60, radius), 60, "corner")
            self.assertTrue(_passed(rows, "bbox"))
            self.assertTrue(_passed(rows, "watertight"))

    def test_wall_3_and_7(self):
        for thickness in (3.0, 7.0):
            wall = (thickness, thickness, thickness, thickness)
            self._assert_named("shell", ImplicitPart.shell(60, wall=wall), 60, "wall")

    def test_one_wall_thinner(self):
        rows = self._assert_named(
            "shell", ImplicitPart.shell(60, wall=(4.0, 5.0, 5.0, 5.0)), 60, "wall")
        self.assertTrue(_passed(rows, "open top"))

    def test_closed_top(self):
        self._assert_named("shell", ImplicitPart.shell(60, closed_top=True), 60, "open top")

    def test_hole_diameter(self):
        for diameter in (8.0, 12.0):
            part = ImplicitPart.final(60, hole_d=diameter)
            rows = self._assert_named("final", part, 60, "hole Ø10")
            self.assertTrue(_passed(rows, "hole axis"))

    def test_hole_one_wall(self):
        self._assert_named("final", ImplicitPart.final(60, hole_mode="one-x"), 60, "hole axis")

    def test_hole_moved(self):
        for kwargs in ({"hole_y": 38.0}, {"hole_z": 43.0}):
            self._assert_named("final", ImplicitPart.final(60, **kwargs), 60, "hole axis")

    def test_hole_in_y_wall(self):
        self._assert_named("final", ImplicitPart.final(60, hole_mode="both-y"), 60, "hole axis")

    def test_no_hole(self):
        rows = self._assert_named("final", ImplicitPart.shell(60), 60, "hole axis")
        self.assertTrue(any(name == "volume" for name in _failed(rows)))

    def test_width_mismatch(self):
        self._assert_named("final", ImplicitPart.final(65), 60, "bbox")

    def test_duplicate_body(self):
        V, T = mesh_from_implicit(ImplicitPart.final(60))
        shift = V.copy()
        shift[:, 0] += 300.0
        base = len(V)
        V2 = np.vstack([V, shift])
        T2 = np.vstack([T, T + base])
        self._assert_named("final", c.TriMesh(V2, T2), 60, "watertight")

    def test_flipped_triangle(self):
        V, T = mesh_from_implicit(ImplicitPart.final(60))
        T = T.copy()
        T[0, 1], T[0, 2] = T[0, 2], T[0, 1]
        self._assert_named("final", c.TriMesh(V, T), 60, "watertight")

    def test_final_checked_as_base(self):
        rows = self._assert_named("base", ImplicitPart.final(60), 60, "volume")
        self.assertTrue(_passed(rows, "bbox"))
        self.assertTrue(_passed(rows, "watertight"))


class CliTests(unittest.TestCase):
    def test_width_usage(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "box.3mf"
            write_3mf(path, *mesh_from_implicit(ImplicitPart.final(60)))
            buf = io.StringIO()
            with redirect_stdout(buf):
                rc = c.main(["final", str(path), "--width", "70"])
            text = buf.getvalue()
            self.assertEqual(rc, 1)
            self.assertIn("FAIL  usage  got 70.0  want 60 or 65", text)

    def test_bad_stage(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["cube"])
        self.assertEqual(rc, 1)
        self.assertEqual(
            buf.getvalue(),
            "FAIL  usage  got cube  want base|rounded|shell|final\n\n0/1 passed\n",
        )

    def test_missing_file(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = c.main(["final"])
        self.assertEqual(rc, 1)
        self.assertEqual(
            buf.getvalue(),
            "FAIL  usage  got missing file  want stage file.3mf [--width 60|65]\n\n0/1 passed\n",
        )

    def test_params_cli(self):
        proc = subprocess.run(
            [sys.executable, str(CHECK), "params"],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout), c.params_dict())

    def test_cli_final_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "final.3mf"
            write_3mf(path, *mesh_from_implicit(ImplicitPart.final(60)))
            proc = subprocess.run(
                [sys.executable, str(CHECK), "final", str(path)],
                check=False, capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertIn("PASS", proc.stdout)
            self.assertNotIn("FAIL", proc.stdout)

    def test_rung01_still_imports_geom(self):
        self.assertIs(check_rung01.load_3mf, geom.load_3mf)
        self.assertIs(check_rung01.manifold_report, geom.manifold_report)
        self.assertIs(check_rung01.R, geom.R)
        proc = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "test_check_rung01.py")],
            check=False, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)


def write_3mf(path, V, T):
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


class _Mesh:
    def __init__(self):
        self.V = []
        self.T = []
        self._map = {}

    def add(self, p):
        key = (round(float(p[0]), 6), round(float(p[1]), 6), round(float(p[2]), 6))
        hit = self._map.get(key)
        if hit is not None:
            return hit
        self._map[key] = i = len(self.V)
        self.V.append(key)
        return i

    def tri(self, a, b, c):
        if len({a, b, c}) < 3:
            return
        self.T.append((a, b, c))

    def arrays(self):
        V = np.array(self.V, float)
        T = np.array(self.T, int)
        a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
        signed = float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)
        if signed < 0:
            T = T[:, [0, 2, 1]]
        return V, T


def _loop(x0, y0, x1, y1, rad, seg=32):
    if rad <= 1e-9:
        return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    corners = (
        (x1 - rad, y0 + rad, -math.pi / 2, 0.0),
        (x1 - rad, y1 - rad, 0.0, math.pi / 2),
        (x0 + rad, y1 - rad, math.pi / 2, math.pi),
        (x0 + rad, y0 + rad, math.pi, 3 * math.pi / 2),
    )
    pts = []
    for cx, cy, a0, a1 in corners:
        for i in range(seg + 1):
            t = a0 + (a1 - a0) * i / seg
            pts.append((cx + rad * math.cos(t), cy + rad * math.sin(t)))
    return pts


def _fan(mesh, loop, z, up):
    cx = sum(p[0] for p in loop) / len(loop)
    cy = sum(p[1] for p in loop) / len(loop)
    ci = mesh.add((cx, cy, z))
    ids = [mesh.add((x, y, z)) for x, y in loop]
    n = len(ids)
    for i in range(n):
        a, b = ids[i], ids[(i + 1) % n]
        if up:
            mesh.tri(ci, a, b)
        else:
            mesh.tri(ci, b, a)


def _wall_quad(mesh, p, q, z0, z1):
    a = mesh.add((p[0], p[1], z0))
    b = mesh.add((q[0], q[1], z0))
    c = mesh.add((q[0], q[1], z1))
    d = mesh.add((p[0], p[1], z1))
    mesh.tri(a, b, c)
    mesh.tri(a, c, d)


def _cross2(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def _strictly_inside(p, a, b, c):
    v0 = (c[0] - a[0], c[1] - a[1])
    v1 = (b[0] - a[0], b[1] - a[1])
    v2 = (p[0] - a[0], p[1] - a[1])
    dot00 = v0[0] * v0[0] + v0[1] * v0[1]
    dot01 = v0[0] * v1[0] + v0[1] * v1[1]
    dot02 = v0[0] * v2[0] + v0[1] * v2[1]
    dot11 = v1[0] * v1[0] + v1[1] * v1[1]
    dot12 = v1[0] * v2[0] + v1[1] * v2[1]
    den = dot00 * dot11 - dot01 * dot01
    if abs(den) < 1e-18:
        return False
    inv = 1.0 / den
    u = (dot11 * dot02 - dot01 * dot12) * inv
    v = (dot00 * dot12 - dot01 * dot02) * inv
    eps = 1e-10
    return u > eps and v > eps and u + v < 1.0 - eps


def _ear_clip(pts):
    """CCW simple polygon, bridge duplicates allowed. Index triples into pts."""
    idx = list(range(len(pts)))
    tris = []
    guard = 0
    while len(idx) > 3:
        guard += 1
        if guard > len(pts) * len(pts):
            raise RuntimeError("ear clip did not finish")
        m = len(idx)
        clipped = False
        for i in range(m):
            ip, ic, inn = idx[(i - 1) % m], idx[i], idx[(i + 1) % m]
            if _cross2(pts[ip], pts[ic], pts[inn]) <= 1e-12:
                continue
            tri = (pts[ip], pts[ic], pts[inn])
            if any(_strictly_inside(pts[idx[j]], *tri) for j in range(m) if idx[j] not in (ip, ic, inn)):
                continue
            tris.append((ip, ic, inn))
            del idx[i]
            clipped = True
            break
        if not clipped:
            raise RuntimeError("ear clip found no ear")
    tris.append(tuple(idx))
    return tris


def _rect_with_hole(mesh, x, y0, y1, z0, z1, cy, cz, radius, normal_x, n=64):
    """Planar rectangle at x with a circular hole. Outer boundary stays the four edges."""
    circle = [
        (cy + radius * math.cos(2 * math.pi * i / n), cz + radius * math.sin(2 * math.pi * i / n))
        for i in range(n)
    ]
    outer = [(y0, z0), (y1, z0), (y1, z1), (y0, z1)]
    hi = max(range(n), key=lambda i: (circle[i][0], circle[i][1]))
    oi = max(range(4), key=lambda i: (outer[i][0], -abs(outer[i][1] - circle[hi][1])))
    poly = list(outer[:oi + 1])
    for k in range(n + 1):
        poly.append(circle[(hi - k) % n])
    poly.extend(outer[oi:])
    tris = [(poly[a], poly[b], poly[c]) for a, b, c in _ear_clip(poly)]
    p0 = np.array((x, tris[0][0][0], tris[0][0][1]))
    p1 = np.array((x, tris[0][1][0], tris[0][1][1]))
    p2 = np.array((x, tris[0][2][0], tris[0][2][1]))
    if float(np.cross(p1 - p0, p2 - p0)[0]) * normal_x < 0:
        tris = [(a, c, b) for a, b, c in tris]
    for a, b, c in tris:
        mesh.tri(
            mesh.add((x, a[0], a[1])),
            mesh.add((x, b[0], b[1])),
            mesh.add((x, c[0], c[1])),
        )
    return circle


def _cylinder(mesh, x0, x1, circle, cy, cz):
    n = len(circle)
    ids0 = [mesh.add((x0, y, z)) for y, z in circle]
    ids1 = [mesh.add((x1, y, z)) for y, z in circle]
    for i in range(n):
        j = (i + 1) % n
        # Two windings; keep the one whose normal points toward the axis.
        candidates = (
            (ids0[i], ids0[j], ids1[j], ids0[i], ids1[j], ids1[i]),
        )
        a, b, c = ids0[i], ids0[j], ids1[j]
        pa, pb, pc = (np.array(mesh.V[k]) for k in (a, b, c))
        nrm = np.cross(pb - pa, pc - pa)
        mid = (pa + pb + pc) / 3.0
        toward = np.array((0.0, cy - mid[1], cz - mid[2]))
        if float(np.dot(nrm, toward)) < 0:
            mesh.tri(a, c, b)
            mesh.tri(a, ids1[i], c)
        else:
            mesh.tri(a, b, c)
            mesh.tri(a, c, ids1[i])


def _is_flat(p, q, axis, value):
    return abs(p[axis] - value) < 1e-6 and abs(q[axis] - value) < 1e-6


def mesh_from_implicit(part, seg=32):
    """Extrude the analytic cross-section. 32 segments per fillet arc; hole is a 64-gon."""
    mesh = _Mesh()
    X, H, W, R = part.X, part.H, part.W, part.R
    outer = _loop(0.0, 0.0, X, W, R, seg)
    shell = part.shell
    if not shell:
        for i, p in enumerate(outer):
            q = outer[(i + 1) % len(outer)]
            _wall_quad(mesh, p, q, 0.0, H)
        _fan(mesh, outer, 0.0, up=False)
        _fan(mesh, outer, H, up=True)
        return mesh.arrays()

    L, Rt, B, Tp = part.wall
    floor = B
    top_inset = Tp if part.closed_top else 0.0
    z_top_inner = H - top_inset
    rin = max(0.0, R - max(part.wall))
    inner = _loop(L, B, X - Rt, W - Tp, rin, seg)
    hole = part.hole_mode
    hole_r = part.hole_d / 2.0
    cut_left = hole in ("both-x", "one-x")
    cut_right = hole == "both-x"

    # Outer walls. Left flat (x=0) normal -X; right flat (x=X) normal +X.
    left_circle = None
    right_circle = None
    for i, p in enumerate(outer):
        q = outer[(i + 1) % len(outer)]
        if cut_left and _is_flat(p, q, 0, 0.0):
            y0, y1 = sorted((p[1], q[1]))
            left_circle = _rect_with_hole(
                mesh, 0.0, y0, y1, 0.0, H, part.hole_y, part.hole_z, hole_r, -1)
        elif cut_right and _is_flat(p, q, 0, X):
            y0, y1 = sorted((p[1], q[1]))
            right_circle = _rect_with_hole(
                mesh, X, y0, y1, 0.0, H, part.hole_y, part.hole_z, hole_r, +1)
        else:
            _wall_quad(mesh, p, q, 0.0, H)

    for i, p in enumerate(inner):
        q = inner[(i + 1) % len(inner)]
        # Inner faces point into the cavity: left inner (x=L) normal +X, right inner normal -X.
        if cut_left and _is_flat(p, q, 0, L):
            y0, y1 = sorted((p[1], q[1]))
            _rect_with_hole(mesh, L, y0, y1, floor, z_top_inner, part.hole_y, part.hole_z, hole_r, +1)
        elif cut_right and _is_flat(p, q, 0, X - Rt):
            y0, y1 = sorted((p[1], q[1]))
            _rect_with_hole(
                mesh, X - Rt, y0, y1, floor, z_top_inner,
                part.hole_y, part.hole_z, hole_r, -1)
        else:
            # Reverse of the outer winding so the normal points inward.
            _wall_quad(mesh, q, p, floor, z_top_inner)

    if left_circle is not None:
        _cylinder(mesh, 0.0, L, left_circle, part.hole_y, part.hole_z)
    if right_circle is not None:
        _cylinder(mesh, X, X - Rt, right_circle, part.hole_y, part.hole_z)

    _fan(mesh, outer, 0.0, up=False)
    _fan(mesh, inner, floor, up=True)
    if part.closed_top:
        _fan(mesh, outer, H, up=True)
        _fan(mesh, inner, z_top_inner, up=False)
    else:
        # Rim annulus at z=H, normal +Z. Loops share the arc sampling.
        if len(outer) != len(inner):
            raise RuntimeError(f"loop mismatch {len(outer)} vs {len(inner)}")
        for i in range(len(outer)):
            j = (i + 1) % len(outer)
            o0 = mesh.add((outer[i][0], outer[i][1], H))
            o1 = mesh.add((outer[j][0], outer[j][1], H))
            i1 = mesh.add((inner[j][0], inner[j][1], H))
            i0 = mesh.add((inner[i][0], inner[i][1], H))
            mesh.tri(o0, o1, i1)
            mesh.tri(o0, i1, i0)
    return mesh.arrays()


if __name__ == "__main__":
    unittest.main()
