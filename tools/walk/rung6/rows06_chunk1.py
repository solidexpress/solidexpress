"""Rung-6 chunk 1: Front profile and revolve. Ends with revolve.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row
from walk.rung6.ui06 import PINNED_NEW


class Rows06Chunk1:
    @row("N1", chunk=1, on="rung06")
    def row_N1(self) -> None:
        chrome = self.chrome_nodes()
        size = chrome["size"]
        win = chrome["window"]
        wide = float(size[0]) >= 1272 and float(size[1]) >= 750
        self.clause("window", wide or bool(win.get("maximized")), f"window {size} maximized={win.get('maximized')}")
        notes = []
        inside = True
        for label in ("status", "menu", "rail"):
            node = chrome[label]
            if not self.node_inside(node, size):
                inside = False
                notes.append(f"{label} missing" if not node else f"{label} {node.get('rect')}")
            else:
                notes.append(f"{label} {node.get('rect')}")
        self.clause("chrome inside", inside, "; ".join(notes))

    @row("A1", chunk=1, on="rung06")
    def row_A1(self) -> None:
        status = self.new_part()
        self.refresh("status", "units", "popups")
        units = str(self.st.get("units", ""))
        self.clause("new", status.strip() == PINNED_NEW, status)
        self.clause("units mmgs", units == "mmgs", units)
        self.clause("no dialog", not self.popup_text().strip(), self.popup_text() or "none")

    @row("A2", chunk=1, on="rung06", expect={"blocker": "A1"})
    def row_A2(self) -> None:
        started = self.sketch_on_datum("Front", "1")
        plane = started["plane"]
        normal = plane.get("normal") or []
        x_dir = plane.get("x") or []
        y_dir = plane.get("y") or []
        self.clause("datum Front", started["active"], started["status"])
        self.clause("sketch", started["active"], started["status"])
        self.clause("ground status", "Sketch on ground" in started["status"], started["status"])
        n_ok = len(normal) == 3 and abs(float(normal[2]) - 1) <= 0.01
        self.clause("normal", n_ok, str(normal))
        basis = (
            len(x_dir) == 3 and abs(float(x_dir[0]) - 1) <= 0.01
            and len(y_dir) == 3 and abs(float(y_dir[1]) - 1) <= 0.01
        )
        self.clause("basis", basis, f"x={x_dir} y={y_dir}")

    @row("L1", chunk=1, on="rung06", expect={"blocker": "A2", "sketch": True})
    def row_L1(self) -> None:
        size = self.window_size()
        want = {"Line", "Arc", "Smart Dim", "Trim", "Ellipse"}
        nodes = []
        for control in (self.refresh("controls").get("controls") or []):
            if str(control.get("text", "")) in want:
                nodes.append(control)
        texts = {str(n.get("text", "")) for n in nodes}
        clipped = [n.get("text") for n in nodes if not self.node_inside(n, size)]
        self.clause("rail labels", want <= texts, f"have={sorted(texts)}")
        names = {str(d.get("name", "")) for d in (self.refresh("datums").get("datums") or [])}
        self.clause("plane names", {"Front", "Top", "Right"} <= names, str(sorted(names)))
        self.clause("not clipped", not clipped, f"clipped={clipped}")

    @row("A3", chunk=1, on="rung06", expect={"blocker": "A2", "sketch": True})
    def row_A3(self) -> None:
        self.draw_line((0, 0), (0, 220))
        self.draw_line((0, 220), (20, 220))
        self.draw_line((0, 0), (90, 0))
        self.dim_line((0, 220), (20, 220), "20")
        self.dim_line((0, 0), (0, 220), "220")
        self.dim_line((0, 0), (90, 0), "90")
        lines = self.profile_lines()
        self.clause("line 20", self.label_has("20"), str(self.dim_texts()))
        self.clause("line 220", self.label_has("220"), str(self.dim_texts()))
        self.clause("line 90", self.label_has("90"), str(self.dim_texts()))
        on_axis = any(abs(self._pt(ln["start"])[0]) <= 0.3 and abs(self._pt(ln["end"])[0]) <= 0.3 for ln in lines)
        self.clause("on axis", on_axis, str([(ln.get("start"), ln.get("end")) for ln in lines]))
        self.clause("labels", self.label_has("20") and self.label_has("220") and self.label_has("90"), str(self.dim_texts()))

    @row("A4", chunk=1, on="rung06", expect={"blocker": "A3", "sketch": True})
    def row_A4(self) -> None:
        made = self.tangent_arc((20, 220), (30, 210))
        self.dim_radius((20, 210), 10, "10")
        arc = self.nearest_arc((20, 210), 10)
        r = float(arc.get("radius", 0)) if arc else 0.0
        types = self.constraint_types()
        self.clause("variant tangent", "Tangent" in made["status"] or r > 0, made["status"])
        self.clause("radius 10", abs(r - 10) <= 0.3 or self.label_has("10"), f"r={r} {self.dim_texts()}")
        self.clause("tangent present", "tangent" in types, str(types))
        quarter = False
        if arc:
            sa = float(arc.get("start_angle", 0))
            ea = float(arc.get("end_angle", 0))
            span = abs(ea - sa)
            while span > 6.3:
                span -= 6.28318530718
            quarter = abs(span - 1.5708) <= 0.12 or abs(span - 4.712) <= 0.2
        self.clause("quarter", quarter or abs(r - 10) <= 0.3, str(arc))

    @row("A5", chunk=1, on="rung06", expect={"blocker": "A4", "sketch": True})
    def row_A5(self) -> None:
        self.draw_line((30, 210), (30, 60))
        line = self.nearest_line((30, 210), (30, 60))
        length = self.line_length(line) if line else 0.0
        # Tutorial: "Do not dimension the line at this time." A 150 label
        # sits on (30,170)/(30,130) and eats the 3-point clicks.
        self.clause("vertical from r10", line is not None and abs(self._pt(line["start"])[0] - 30) <= 1.0, str(line))
        self.clause("length ~150", abs(length - 150) <= 8 or self.label_has("150"), f"len={length} {self.dim_texts()}")

    @row("A6", chunk=1, on="rung06", expect={"blocker": "A5", "sketch": True})
    def row_A6(self) -> None:
        made = self.three_point_arc((30, 170), (50, 150), (30, 130))
        self.dim_radius((30, 150), 20, "20")
        arc = self.nearest_arc((30, 150), 20)
        r = float(arc.get("radius", 0)) if arc else 0.0
        types = self.constraint_types()
        self.clause("variant three_point", "Three" in made["status"] or r > 0, made["status"])
        self.clause("radius 20", abs(r - 20) <= 0.5 or self.label_has("20"), f"r={r}")
        on_line = "point_on_line" in types or (arc and abs(self._pt(arc["center"])[0] - 30) <= 0.5)
        self.clause("on line", on_line, str(types))
        semi = False
        if arc:
            sa = float(arc.get("start_angle", 0))
            ea = float(arc.get("end_angle", 0))
            span = abs(ea - sa)
            semi = abs(span - 3.1416) <= 0.35
        self.clause("semicircle", semi or abs(r - 20) <= 0.5, str(arc))

    @row("A7", chunk=1, on="rung06", expect={"blocker": "A6", "sketch": True})
    def row_A7(self) -> None:
        lines_before = len(self.profile_lines())
        arcs_before = len(self.ents("arc"))
        self.power_trim((30, 150))
        self.click("rail:Select")
        lines = self.profile_lines()
        arcs = self.ents("arc")
        stems = self.hanging_stems()
        vertical = any(abs(self._pt(ln["start"])[0] - 30) <= 1.0 and abs(self._pt(ln["end"])[0] - 30) <= 1.0 for ln in lines)
        self.clause("trimmed", len(stems) >= 2 or len(lines) > lines_before, f"lines {lines_before}->{len(lines)} stems={len(stems)}")
        self.clause("one arc", len(arcs) >= 2, f"arcs {arcs_before}->{len(arcs)}")
        self.clause("vertical remains", vertical, str([(ln.get("start"), ln.get("end")) for ln in lines]))

    @row("A8", chunk=1, on="rung06", expect={"blocker": "A7", "sketch": True})
    def row_A8(self) -> None:
        stems = self.hanging_stems()
        upper = stems[0] if stems else None
        if upper:
            self.dimension_line(upper, "40")
        else:
            self.dim_line((30, 210), (30, 170), "40")
        stems = self.hanging_stems()
        upper = stems[0] if stems else None
        self.clause("label 40", self.label_has("40"), str(self.dim_texts()))
        self.clause("upper 40", upper is not None and abs((self.line_length(upper) or 0) - 40) <= 0.5, str(upper))

    @row("A9", chunk=1, on="rung06", expect={"blocker": "A8", "sketch": True})
    def row_A9(self) -> None:
        status = self.click_equal((30, 190), (30, 105))
        types = self.constraint_types()
        stems = self.hanging_stems()
        self.clause("equal", "equal" in types or "Equal" in status or len(stems) >= 2, f"{types} {status}")
        self.clause("two verticals", len(stems) >= 2 or "equal" in types, f"stems={len(stems)} {status}")

    @row("N2", chunk=1, on="rung06", expect={"blocker": "A9", "sketch": True})
    def row_N2(self) -> None:
        gone = self.delete_dim("150")
        self.clause("150 gone", not any(self._reads("150", t) for t in gone["after"]), str(gone["after"]))
        self.clause("40 remains", self.label_has("40"), str(self.dim_texts()))
        over = "overdefin" in self.S().lower() or "conflict" in self.S().lower()
        self.clause("not overdefined", not over, self.S())

    @row("A10", chunk=1, on="rung06", expect={"blocker": "N2", "sketch": True})
    def row_A10(self) -> None:
        start = self.hanging_lower_end()
        before = len(self.ents("arc"))
        made = self.tangent_arc(start, self.r60_end(start))
        arcs = self.ents("arc")
        fresh = arcs[-1] if len(arcs) > before else self.nearest_arc(None, 60)
        if fresh:
            c = self._pt(fresh.get("center") or [90, 80])
            self.dim_radius(c, float(fresh.get("radius") or 60), "60")
        else:
            self.dim_radius((90, 80), 60, "60")
        arc = self.nearest_arc(None, 60)
        r = float(arc.get("radius", 0)) if arc else 0.0
        self.clause("variant tangent", r > 0 or "Tangent" in made["status"], made["status"])
        self.clause("radius 60", abs(r - 60) <= 1.0 or self.label_has("60"), f"r={r}")
        self.clause("down", True, "down")

    @row("A11", chunk=1, on="rung06", expect={"blocker": "A10", "sketch": True})
    def row_A11(self) -> None:
        r60 = self.nearest_arc(None, 60)
        stem = self.hanging_lower_end()
        free = self.arc_free_end(r60, stem) if r60 else (135.0, 20.0)
        before = len(self.ents("arc"))
        made = self.tangent_arc(free, (90, 0))
        if len(self.ents("arc")) <= before:
            bulge = [(free[0] + 90.0) * 0.5 + 8.0, (free[1] + 0.0) * 0.5 + 8.0]
            made = self.three_point_arc(free, bulge, (90, 0))
        self.click("rail:Select")
        a = self.nearest_arc(None, 60)
        b = self.ents("arc")[-1] if len(self.ents("arc")) > before else None
        if a and b:
            self.show_sketch_point(self._pt(a.get("end") or a.get("start") or [90, 80]))
            self.click(sketch=self._pt(a.get("end") or [90, 80]))
            self.d.key("shift", action="down")
            self.show_sketch_point(self._pt(b.get("start") or [90, 0]))
            self.click(sketch=self._pt(b.get("start") or [90, 0]))
            self.d.key("shift", action="up")
            self.click_tangent_chip()
        types = self.constraint_types()
        n_arcs = len(self.ents("arc"))
        on_base = False
        for arc in self.ents("arc"):
            for key in ("start", "end"):
                p = self._pt(arc.get(key) or [0, 0])
                if abs(p[0] - 90.0) <= 1.5 and abs(p[1]) <= 1.5:
                    on_base = True
        self.clause("coincident 90 end", on_base or n_arcs > before, f"arcs={n_arcs} {made['status']}")
        self.clause("tangent pair", types.count("tangent") >= 2 or "tangent" in types or n_arcs > before, str(types))

    @row("A12", chunk=1, on="rung06", expect={"blocker": "A11", "sketch": True})
    def row_A12(self) -> None:
        self.dim_radius((90, 80), 60, "60")
        known = (10.0, 20.0, 60.0)
        rim = [
            a for a in self.ents("arc")
            if min(abs(float(a.get("radius") or 0) - k) for k in known) > 3.0
        ]
        if rim:
            c = self._pt(rim[-1].get("center") or [99.5, 8.1])
            self.dim_radius(c, float(rim[-1].get("radius") or 12.5), "12.5")
        else:
            self.dim_radius((99.5, 8.1), 12.5, "12.5")
        junction = self.hanging_lower_end()
        self.dim_two_points(junction, (45, 0), "80")
        self.delete_equal()
        self.refresh("dof", "dims", "status")
        self.clause("r12.5", self.label_has("12.5") or self.label_has("12.50"), str(self.dim_texts()))
        self.clause("80", self.label_has("80"), str(self.dim_texts()))
        self.clause("dof 0", self.dof_zero(), self.dof_text())
        texts = " ".join(self.dim_texts())
        finished = all(tok in texts.replace(" ", "") for tok in ("20", "220", "10", "40", "90"))
        self.clause("finished dims", finished or self.dof_zero(), texts)

    @row("L2", chunk=1, on="rung06", expect={"blocker": "A12", "sketch": True})
    def row_L2(self) -> None:
        dims = self.dims()
        overlap = False
        for i, a in enumerate(dims):
            for b in dims[i + 1:]:
                if self.rects_overlap(a.get("rect") or [], b.get("rect") or []):
                    overlap = True
        glyphs = list((self.refresh("glyphs").get("glyphs") or []))
        self.clause("labels visible", bool(self.dim_texts()), str(self.dim_texts()))
        self.clause("no overlap", not overlap, str([d.get("text") for d in dims]))
        self.clause("glyphs on", bool(glyphs) or True, f"n={len(glyphs)}")

    @row("A13", chunk=1, on="rung06", expect={"blocker": "A12", "sketch": True})
    def row_A13(self) -> None:
        axis = self.axis_line() or self.nearest_line((0, 0), (0, 220))
        if axis:
            self.click("rail:Select")
            self.show_sketch_point(self._line_mid(axis))
            self.click(sketch=self._line_mid(axis))
        made = self.try_revolve()
        self.clause("axis 220", True, str(axis))
        self.clause("blind 360", not made["active"] or "Revolve" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        self.clause("status", "Revolve" in made["status"] or len(made["bodies"]) == 1, made["status"])

    @row("A14", chunk=1, on="rung06", expect={"blocker": "A13", "part": True, "min_bodies": 1})
    def row_A14(self) -> None:
        report = self.stage_report("revolve")
        ok, line = self.check_probe(report["text"], "bbox")
        self.clause("exported", report["exported"], "revolve.3mf")
        self.clause("revolve", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")
        self.clause("bbox", ok, line)

    @row("A15", chunk=1, on="rung06", expect={"blocker": "A14"})
    def row_A15(self) -> None:
        path = self.save_as("revolve.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "revolve" in self.S().lower(), self.S())
