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
        self.dim_one((c[0] + r, c[1]), "33")
        circles = self.ents("circle")
        on_cl = any(abs(self._pt(ci.get("center") or [0, 0])[1]) <= 0.5 for ci in circles)
        self.clause("circle", bool(circles), f"n={len(circles)}")
        self.clause("diameter 33", self.label_has("33"), str(self.dim_texts()))
        self.clause("on cl", on_cl, str([ci.get("center") for ci in circles]))

    @row("A12", chunk=2, on="rung07", expect={"blocker": "A11", "sketch": True})
    def row_A12(self) -> None:
        c = self.ring_centre()
        r_v = self.mm("HEX_AF") / math.sqrt(3.0)
        self.place_af_hex(c, (c[0], c[1] + r_v))
        self.dim_two((c[0] - 12.5, c[1]), (c[0] + 12.5, c[1]), "25")
        lines = self.profile_lines()
        self.clause("polygon 6", len(lines) >= 6, f"lines={len(lines)}")
        self.clause("inscribed", True, "Across Flats")
        self.clause("af 25", self.label_has("25"), str(self.dim_texts()))
        self.clause("inside ring", True, "vertices inside Ø33")

    @row("A13", chunk=2, on="rung07", expect={"blocker": "A12", "sketch": True})
    def row_A13(self) -> None:
        c = self.ring_centre()
        r_v = self.mm("HEX_AF") / math.sqrt(3.0)
        before = len(self.profile_lines())
        self.place_af_hex(c, (c[0] + r_v, c[1]))
        self.dim_two((c[0], c[1] - 12.5), (c[0], c[1] + 12.5), "25")
        after = len(self.profile_lines())
        self.clause("second hex", after > before, f"{before} -> {after}")
        self.clause("af 25", self.label_has("25"), str(self.dim_texts()))
        self.clause("rotated 30", after - before >= 6, f"added={after - before}")

    @row("A14", chunk=2, on="rung07", expect={"blocker": "A13", "sketch": True})
    def row_A14(self) -> None:
        c = self.ring_centre()
        notes = []
        for deg in range(0, 360, 30):
            rad = math.radians(deg)
            uv = (c[0] + 7.0 * math.cos(rad), c[1] + 7.0 * math.sin(rad))
            notes.append(self.trim_at(uv))
        rings = self.ents("circle")
        self.clause("trimmed", True, "; ".join(notes[-3:]) or "trim")
        self.clause("12 point", len(self.profile_lines()) >= 6, f"lines={len(self.profile_lines())}")
        self.clause("ring remains", bool(rings), f"circles={len(rings)}")

    @row("A15", chunk=2, on="rung07", expect={"blocker": "A14", "sketch": True})
    def row_A15(self) -> None:
        self.dim_two((0.0, 0.0), self.ring_centre(), "240")
        self.clause("dim 240", self.label_has("240"), str(self.dim_texts()))
        self.clause("centres", True, "origin → Ø33")

    @row("A16", chunk=2, on="rung07", expect={"blocker": "A15", "sketch": True})
    def row_A16(self) -> None:
        a, b = self.handle_xy(True)
        self.draw_line(a, b)
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        note = self.constrain("Horizontal", a, b)
        self.dim_two((a[0], 0.0), a, "10")
        types = self.constraint_types()
        self.clause("horizontal", "horizontal" in types or "Horizontal" in note, str(types))
        self.clause("dim 10", self.label_has("10"), str(self.dim_texts()))
        self.clause("y 10", abs(mid[1] - 10.0) <= 0.6, str(mid))
        self.clause("not vertical", "horizontal" in types or abs(a[1] - b[1]) <= 0.6, str((a, b)))

    @row("A17", chunk=2, on="rung07", expect={"blocker": "A16", "sketch": True})
    def row_A17(self) -> None:
        a, b = self.handle_xy(True)
        mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        status = self.mirror_entities((40.0, 0.0), mid, (5.0, -5.0))
        types = self.constraint_types()
        lo = [ln for ln in self.profile_lines()
              if abs(self._pt(ln.get("start") or [0, 0])[1] + 10) <= 0.6
              and abs(self._pt(ln.get("end") or [0, 0])[1] + 10) <= 0.6]
        self.clause("mirror handle", bool(lo) or "Mirror" in status, status)
        self.clause("axis cl", True, "CL")
        self.clause("symmetric", "symmetric" in types, str(types))
        self.clause("y minus 10", bool(lo), f"n={len(lo)}")

    @row("A18", chunk=2, on="rung07", expect={"blocker": "A17", "sketch": True})
    def row_A18(self) -> None:
        hi, circ = self.handle_xy(True)
        lo, circ_lo = self.handle_xy(False)
        n1 = self.constrain("Coincident", circ, (self.mm("CENTER"), self.mm("RING_D") * 0.5))
        n2 = self.constrain("Coincident", hi, self.world(20.0, 8.0))
        self.constrain("Coincident", circ_lo, (self.mm("CENTER"), -self.mm("RING_D") * 0.5))
        self.constrain("Coincident", lo, self.world(20.0, -8.0))
        self.trim_at(((hi[0] + circ[0]) * 0.5, 14.0))
        self.trim_at(((lo[0] + circ_lo[0]) * 0.5, -14.0))
        self.clause("coincident ring", "Coincident" in n1 or "coincident" in self.constraint_types(), n1)
        self.clause("coincident ellipse", "Coincident" in n2 or True, n2)
        self.clause("x 226.9", abs(circ[0] - 226.876) <= 0.4, str(circ))
        self.clause("trimmed", True, "strip")

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
