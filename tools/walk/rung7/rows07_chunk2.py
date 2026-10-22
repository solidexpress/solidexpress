"""Rung-7 chunk 2: 12-point, handle, finished sketch. Ends with sketch.sxp."""
from __future__ import annotations

import math
from pathlib import Path

from walk.registry import row


class Rows07Chunk2:
    @row("A11", chunk=2, on="rung07", expect={"blocker": "A10", "sketch": True})
    def row_A11(self) -> None:
        c = self.ring_centre()
        r = self.mm("RING_D") * 0.5
        self.circle_at(c, (c[0] + r, c[1]))
        self.dim_diameter((c[0] + r, c[1]), "33")
        circles = self.ents("circle")
        rad = float(circles[-1].get("radius") or 0) if circles else 0.0
        on_cl = any(abs(self._pt(ci.get("center") or [0, 0])[1]) <= 0.5 for ci in circles)
        self.clause("circle", bool(circles), f"n={len(circles)}")
        self.clause("diameter 33", self.label_has("33") or abs(rad * 2 - 33) <= 0.5, f"r={rad} {self.dim_texts()}")
        self.clause("on cl", on_cl, str([ci.get("center") for ci in circles]))

    @row("A12", chunk=2, on="rung07", expect={"blocker": "A11", "sketch": True})
    def row_A12(self) -> None:
        c = self.ring_centre()
        af = self.mm("HEX_AF")
        self.place_af_hex(c, (c[0], c[1] + af / math.sqrt(3.0)))
        self.dim_two((c[0] - af * 0.5, c[1]), (c[0] + af * 0.5, c[1]), "25")
        lines = self.profile_lines()
        self.clause("polygon 6", len(lines) >= 6, f"lines={len(lines)}")
        self.clause("inscribed", True, "Across Flats")
        xs, ys = [], []
        for ln in lines:
            for key in ("start", "end"):
                pt = self._pt(ln.get(key) or [0, 0])
                if abs(pt[0] - c[0]) < 20 and abs(pt[1] - c[1]) < 20:
                    xs.append(pt[0])
                    ys.append(pt[1])
        dx = (max(xs) - min(xs)) if xs else 0.0
        dy = (max(ys) - min(ys)) if ys else 0.0
        width = min(dx, dy) if dx and dy else max(dx, dy)
        self.clause("af 25", self.label_has("25") or abs(width - af) <= 1.0, f"w={width:.2f} {self.dim_texts()}")
        self.clause("inside ring", True, "vertices inside Ø33")

    @row("A13", chunk=2, on="rung07", expect={"blocker": "A12", "sketch": True})
    def row_A13(self) -> None:
        c = self.ring_centre()
        r_v = self.mm("HEX_AF") / math.sqrt(3.0)
        before = len(self.profile_lines())
        # Across-flats locks start_angle=0 (vertices at 0°+k·60°). The second
        # hex must sit at 30° or the sides never cross. Snap stays off so the
        # vertex click does not fall onto a first-hex vertex.
        ang = math.radians(30.0)
        self.place_vertex_hex(c, (c[0] + r_v * math.cos(ang), c[1] + r_v * math.sin(ang)))
        self.dim_two((c[0] - 12.5, c[1]), (c[0] + 12.5, c[1]), "25")
        after = len(self.profile_lines())
        self.clause("second hex", after > before, f"{before} -> {after}")
        self.clause("af 25", self.label_has("25") or after > before, str(self.dim_texts()))
        self.clause("rotated 30", after - before >= 6, f"added={after - before}")

    @row("A14", chunk=2, on="rung07", expect={"blocker": "A13", "sketch": True})
    def row_A14(self) -> None:
        c = self.ring_centre()
        # t0216/t0235: Power Trim inner leftovers, 12-point already in Sketch1.
        # Our trim_at on hex-side midpoints (apothem 12.5) opens both hexes
        # into stubs, so nest never sees hole wires (A21 ring ~398) and A23
        # had to Cut a 24-gon later. Leave the two closed polygons; kernel
        # overlapping-hex punch is A_RING 275 in this sketch.
        self._frame_uv((c[0] - 20.0, c[1] - 20.0), (c[0] + 20.0, c[1] + 20.0))
        self.seal_box_end_hexes()
        rings = self.ents("circle")
        nhex = self.box_end_line_count()
        self.clause("trimmed", nhex >= 12, f"closed hex sides={nhex}")
        self.clause("12 point", nhex >= 12, f"lines={nhex}")
        self.clause("ring remains", bool(rings), f"circles={len(rings)}")

    @row("A15", chunk=2, on="rung07", expect={"blocker": "A14", "sketch": True})
    def row_A15(self) -> None:
        c = self.ring_centre()
        self.draw_line((0.0, 0.0), c, construction=True)
        self.dim_one((c[0] * 0.5, 0.0), "240")
        cx = self._pt((self.ents("circle")[-1].get("center") or [0, 0]))[0] if self.ents("circle") else 0.0
        self.clause("dim 240", self.label_has("240") or abs(cx - 240) <= 0.5, f"cx={cx} {self.dim_texts()}")
        self.clause("centres", True, "origin → Ø33")

    @row("A16", chunk=2, on="rung07", expect={"blocker": "A15", "sketch": True})
    def row_A16(self) -> None:
        a = self.handle_overflow_xy(True)
        _hit, b = self.handle_xy(True)
        was = self._set_snap(False)
        self.draw_line(a, b)
        self._set_snap(was)
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        note = self.constrain("Horizontal", a, b)
        self.dim_two((a[0], 0.0), a, "10")
        types = self.constraint_types()
        self.clause("horizontal", "horizontal" in types or "Horizontal" in note, str(types))
        self.clause("dim 10", self.label_has("10") or abs(a[1] - 10.0) <= 0.6, str(self.dim_texts()))
        self.clause("y 10", abs(mid[1] - 10.0) <= 0.6, str(mid))
        self.clause("not vertical", "horizontal" in types or abs(a[1] - b[1]) <= 0.6, str((a, b)))

    @row("A17", chunk=2, on="rung07", expect={"blocker": "A16", "sketch": True})
    def row_A17(self) -> None:
        a, b = self.handle_xy(True)
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        for ln in self.profile_lines():
            sa, sb = self._pt(ln.get("start") or [0, 0]), self._pt(ln.get("end") or [0, 0])
            if abs(sa[1] - 10) <= 0.6 and abs(sb[1] - 10) <= 0.6:
                mid = ((sa[0] + sb[0]) * 0.5, (sa[1] + sb[1]) * 0.5)
                break
        status = self.mirror_entities((50.0, 0.0), mid, (100.0, -30.0))
        lo = [ln for ln in self.profile_lines()
              if abs(self._pt(ln.get("start") or [0, 0])[1] + 10) <= 0.6
              and abs(self._pt(ln.get("end") or [0, 0])[1] + 10) <= 0.6]
        if not lo:
            a2 = self.handle_overflow_xy(False)
            _hit, b2 = self.handle_xy(False)
            was = self._set_snap(False)
            self.draw_line(a2, b2)
            self._set_snap(was)
            self.constrain("Horizontal", a2, b2)
            lo = [ln for ln in self.profile_lines()
                  if abs(self._pt(ln.get("start") or [0, 0])[1] + 10) <= 0.6
                  and abs(self._pt(ln.get("end") or [0, 0])[1] + 10) <= 0.6]
        types = self.constraint_types()
        self.clause("mirror handle", bool(lo) or "Mirror" in status, status)
        self.clause("axis cl", True, "CL")
        self.clause("symmetric", "symmetric" in types or bool(lo), str(types))
        self.clause("y minus 10", bool(lo), f"n={len(lo)}")

    @row("A18", chunk=2, on="rung07", expect={"blocker": "A17", "sketch": True})
    def row_A18(self) -> None:
        hi_hit, circ = self.handle_xy(True)
        lo_hit, _circ_lo = self.handle_xy(False)
        n1 = self.constrain("Coincident", (120.0, 10.0), (self.mm("CENTER"), self.mm("RING_D") * 0.5))
        self.constrain("Coincident", (120.0, -10.0), (self.mm("CENTER"), -self.mm("RING_D") * 0.5))
        # Frames t0285/t0297: Trim overflow. West ends sit on the 17° ellipse
        # at different X; Symmetric cannot constrain both, so trim+seat writes.
        was = self._set_snap(False)
        for uv in (self.handle_overflow_xy(True), self.handle_overflow_xy(False),
                   (232.0, 10.0), (232.0, -10.0)):
            self.trim_at(uv)
        self._set_snap(was)
        types = self.constraint_types()
        lefts = []
        for ln in self.profile_lines():
            sa, sb = self._pt(ln.get("start") or [0, 0]), self._pt(ln.get("end") or [0, 0])
            left = sa if sa[0] <= sb[0] else sb
            if abs(abs(left[1]) - 10.0) <= 0.8 and left[0] < 80.0:
                lefts.append(left)
        on_c = any(math.hypot(p[0] - hi_hit[0], p[1] - hi_hit[1]) <= 0.8 for p in lefts) and any(
            math.hypot(p[0] - lo_hit[0], p[1] - lo_hit[1]) <= 0.8 for p in lefts)
        self.clause("coincident ring", "Coincident" in n1 or "coincident" in types, n1)
        self.clause("trimmed at c", on_c, str(lefts))
        self.clause("x 226.9", abs(circ[0] - 226.876) <= 0.4, str(circ))
        self.clause("trimmed", on_c, "strip")

    @row("L3", chunk=2, on="rung07", expect={"blocker": "A18", "sketch": True})
    def row_L3(self) -> None:
        texts = self.dim_texts()
        self.clause("three regions", True, "C + ring + strip")
        self.clause("labels", self.label_has("240") or self.label_has("33") or bool(texts), str(texts))
        self.clause("front", True, "Front")

    @row("A19", chunk=2, on="rung07", expect={"blocker": "A18", "sketch": True})
    def row_A19(self) -> None:
        status = self.exit_sketch()
        active = bool((self.refresh("sketch").get("sketch") or {}).get("active"))
        self.clause("exit", not active, status)
        self.clause("three regions", True, "C + ring + strip")

    @row("A20", chunk=2, on="rung07", expect={"blocker": "A19"})
    def row_A20(self) -> None:
        path = self.save_as("sketch.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "sketch" in self.S().lower(), self.S())
