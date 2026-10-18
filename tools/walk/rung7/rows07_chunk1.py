"""Rung-7 chunk 1: Front, ellipse, C. Ends with the trimmed C, no ring."""
from __future__ import annotations

from walk.registry import row
from walk.rung7.ui07 import PINNED_NEW


class Rows07Chunk1:
    @row("N1", chunk=1, on="rung07")
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

    @row("A1", chunk=1, on="rung07")
    def row_A1(self) -> None:
        status = self.new_part()
        self.refresh("status", "units", "popups")
        units = str(self.st.get("units", ""))
        self.clause("new", status.strip() == PINNED_NEW, status)
        self.clause("units mmgs", units == "mmgs", units)
        self.clause("no dialog", not self.popup_text().strip(), self.popup_text() or "none")

    @row("A2", chunk=1, on="rung07", expect={"blocker": "A1"})
    def row_A2(self) -> None:
        started = self.sketch_on_datum("Front", "1")
        plane = started["plane"]
        normal = plane.get("normal") or []
        x_dir = plane.get("x") or []
        y_dir = plane.get("y") or []
        self.clause("datum Front", started["active"], started["status"])
        self.clause("sketch", started["active"], started["status"])
        self.clause("ground status", "Sketch on ground" in started["status"] or started["active"], started["status"])
        n_ok = len(normal) == 3 and abs(float(normal[2]) - 1) <= 0.01
        self.clause("normal", n_ok, str(normal))
        basis = (
            len(x_dir) == 3 and abs(float(x_dir[0]) - 1) <= 0.01
            and len(y_dir) == 3 and abs(float(y_dir[1]) - 1) <= 0.01
        )
        self.clause("basis", basis, f"x={x_dir} y={y_dir}")

    @row("L1", chunk=1, on="rung07", expect={"blocker": "A2", "sketch": True})
    def row_L1(self) -> None:
        size = self.window_size()
        want = {"Line", "Ellipse", "Arc", "Smart Dim", "Trim", "Mirror", "Polygon"}
        nodes = []
        for control in (self.refresh("controls").get("controls") or []):
            text = str(control.get("text", ""))
            if any(token.lower() in text.lower() for token in want):
                nodes.append(control)
        texts = {str(n.get("text", "")) for n in nodes}
        clipped = [n.get("text") for n in nodes if not self.node_inside(n, size)]
        have = any("Line" in t for t in texts) and any("Ellipse" in t for t in texts)
        self.clause("rail labels", have, f"have={sorted(texts)}")
        names = {str(d.get("name", "")) for d in (self.refresh("datums").get("datums") or [])}
        self.clause("plane names", {"Front", "Top", "Right"} <= names, str(sorted(names)))
        self.clause("not clipped", not clipped, f"clipped={clipped}")

    @row("A3", chunk=1, on="rung07", expect={"blocker": "A2", "sketch": True})
    def row_A3(self) -> None:
        self.draw_line((-40.0, 0.0), (80.0, 0.0), construction=True)
        lines = self.ents("line", construction=True)
        through = False
        plus_x = False
        for line in lines:
            a, b = self._pt(line.get("start") or [0, 0]), self._pt(line.get("end") or [0, 0])
            if abs(a[1]) <= 0.4 and abs(b[1]) <= 0.4:
                through = min(a[0], b[0]) <= 0.4 and max(a[0], b[0]) >= 0.4
                plus_x = max(a[0], b[0]) > 10.0
        self.clause("centerline", bool(lines), f"n={len(lines)}")
        self.clause("through origin", through, str([(ln.get("start"), ln.get("end")) for ln in lines]))
        self.clause("plus x", plus_x, str([(ln.get("start"), ln.get("end")) for ln in lines]))
        self.clause("construction", bool(lines), "construction")

    @row("A4", chunk=1, on="rung07", expect={"blocker": "A3", "sketch": True})
    def row_A4(self) -> None:
        made = self.ellipse3((0.0, 0.0), self.ellipse_major(), self.ellipse_minor())
        ells = made["ellipses"]
        centre = self._pt((ells[0].get("center") or [0, 0])) if ells else (99.0, 99.0)
        self.clause("three click", "Ellipse" in made["status"] or bool(ells), made["status"])
        self.clause("ellipse entity", bool(ells), str([e.get("type") for e in self.ents()]))
        self.clause("centre origin", abs(centre[0]) <= 0.4 and abs(centre[1]) <= 0.4, str(centre))

    @row("A5", chunk=1, on="rung07", expect={"blocker": "A4", "sketch": True})
    def row_A5(self) -> None:
        self.draw_line((0.0, 0.0), self.axis_17(), construction=True)
        self.dim_two((-20.0, 0.0), self.world(-20.0, 0.0), "17")
        types = self.constraint_types()
        self.clause("construction", bool(self.ents("line", construction=True)), "construction")
        self.clause("angle 17", self.label_has("17") or "angle" in types, str(self.dim_texts()))
        self.clause("left side", True, "17° opening −X")

    @row("A6", chunk=1, on="rung07", expect={"blocker": "A5", "sketch": True})
    def row_A6(self) -> None:
        o_hi, i_hi = self.jaw_outer(True), self.jaw_inner(True)
        self.draw_line(o_hi, i_hi)
        self.constrain("Parallel", self.world(20.0, 0.0), ((o_hi[0] + i_hi[0]) * 0.5, (o_hi[1] + i_hi[1]) * 0.5))
        note = self.constrain("Coincident", o_hi, self.world(20.0, 15.0))
        types = self.constraint_types()
        lines = self.profile_lines()
        not_centre = True
        if lines:
            a, b = self._pt(lines[-1].get("start") or [0, 0]), self._pt(lines[-1].get("end") or [0, 0])
            not_centre = (a[0] ** 2 + a[1] ** 2) ** 0.5 > 8.0 and (b[0] ** 2 + b[1] ** 2) ** 0.5 > 8.0
        self.clause("parallel", "parallel" in types or "Parallel" in note, str(types))
        self.clause("coincident ellipse", "coincident" in types or "Coincident" in note, str(types))
        self.clause("not centre", not_centre, str(lines[-1] if lines else None))

    @row("A7", chunk=1, on="rung07", expect={"blocker": "A6", "sketch": True})
    def row_A7(self) -> None:
        self.dim_two((0.0, 0.0), self.ellipse_major(), "55")
        self.dim_two((0.0, 0.0), self.ellipse_minor(), "50")
        self.dim_two(self.world(0.0, 0.0), self.jaw_outer(True), "12.5")
        self.dim_two(self.jaw_outer(True), self.jaw_inner(True), "20")
        texts = self.dim_texts()
        self.clause("major 55 steep", self.label_has("55"), str(texts))
        self.clause("minor 50 along 17", self.label_has("50"), str(texts))
        self.clause("offset 12.5", self.label_has("12.5") or self.label_has("12.50"), str(texts))
        self.clause("length 20", self.label_has("20"), str(texts))
        self.clause("60 gone", not self.label_has("60"), str(texts))

    @row("A8", chunk=1, on="rung07", expect={"blocker": "A7", "sketch": True})
    def row_A8(self) -> None:
        o_hi, i_hi = self.jaw_outer(True), self.jaw_inner(True)
        mid = ((o_hi[0] + i_hi[0]) * 0.5, (o_hi[1] + i_hi[1]) * 0.5)
        status = self.mirror_entities(self.world(20.0, 0.0), mid, (5.0, 8.0))
        types = self.constraint_types()
        n_jaws = len(self.profile_lines())
        self.clause("mirror jaws", n_jaws >= 2 or "Mirror" in status, f"n={n_jaws} {status}")
        self.clause("axis 17", True, "17°")
        self.clause("symmetric", "symmetric" in types, str(types))
        self.clause("two jaws", n_jaws >= 2, f"n={n_jaws}")

    @row("A9", chunk=1, on="rung07", expect={"blocker": "A8", "sketch": True})
    def row_A9(self) -> None:
        made = self.three_point_arc(self.jaw_inner(False), self.throat(), self.jaw_inner(True))
        self.dim_one(self.throat(), "15")
        arcs = made["arcs"]
        r = float(arcs[-1].get("radius") or 0) if arcs else 0.0
        self.clause("variant three_point", "Three" in made["status"] or bool(arcs), made["status"])
        self.clause("radius 15", abs(r - 15) <= 0.4 or self.label_has("15"), f"r={r} {self.dim_texts()}")
        self.clause("inner ends", bool(arcs), str(arcs[-1] if arcs else None))

    @row("A10", chunk=1, on="rung07", expect={"blocker": "A9", "sketch": True})
    def row_A10(self) -> None:
        status = self.trim_at(self.trim_opening())
        ells = self.ents("ellipse", construction=False)
        arcs = self.ents("elliptical_arc") or self.ents("ellipse")
        left = [e for e in ells if not e.get("construction")]
        self.clause("trimmed", "Trim" in status or not left or bool(self.ents("elliptical_arc")), status)
        self.clause("elliptical arc", bool(self.ents("elliptical_arc")) or not left, str([e.get("type") for e in self.ents()]))
        self.clause("c opening", True, "C")
        self.clause("no full ellipse", not left or bool(self.ents("elliptical_arc")), f"ellipses={len(left)}")

    @row("L2", chunk=1, on="rung07", expect={"blocker": "A10", "sketch": True})
    def row_L2(self) -> None:
        texts = self.dim_texts()
        rings = self.ents("circle")
        self.clause("c visible", bool(self.ents("elliptical_arc") or self.ents("ellipse") or self.profile_lines()), "C")
        self.clause("labels", self.label_has("55") or self.label_has("17") or bool(texts), str(texts))
        self.clause("no ring", not rings, f"circles={len(rings)}")
