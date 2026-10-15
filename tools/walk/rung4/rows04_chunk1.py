"""Rung-4 chunk 1: Front hex, point-up, hex.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row
from walk.rung4.ui04 import PINNED_NEW


class Rows04Chunk1:
    @row("N1", chunk=1, on="rung04")
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

    @row("A1", chunk=1, on="rung04")
    def row_A1(self) -> None:
        status = self.new_part()
        self.refresh("status", "units", "popups")
        units = str(self.st.get("units", ""))
        self.clause("new", status.strip() == PINNED_NEW, status)
        self.clause("units mmgs", units == "mmgs", units)
        self.clause("no dialog", not self.popup_text().strip(), self.popup_text() or "none")

    @row("A2", chunk=1, on="rung04", expect={"blocker": "A1"})
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
        self.ctx["front"] = True

    @row("L1", chunk=1, on="rung04", expect={"blocker": "A2", "sketch": True})
    def row_L1(self) -> None:
        size = self.window_size()
        want = {"Polygon", "Line", "Circle", "Smart Dim", "Trim"}
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

    @row("A3", chunk=1, on="rung04", expect={"blocker": "A2", "sketch": True})
    def row_A3(self) -> None:
        placed = self.place_af_hex((0, 0))
        lines = placed["lines"]
        circles = [c for c in self.ents("circle") if c.get("construction")]
        span = self.profile_span()
        radius = float(circles[0]["radius"]) if circles else None
        self.clause("six lines", len(lines) == 6, f"lines={len(lines)}")
        centred = span.get("pts") and abs((span["min_x"] + span["max_x"]) * 0.5) <= 0.3
        self.clause("centre origin", bool(centred), str(span))
        self.clause("inscribed circle", len(circles) == 1, f"n={len(circles)}")
        self.clause(
            "circle construction",
            bool(circles) and abs((radius or 0) - self.af() * 0.5) <= 0.05,
            f"r={radius}",
        )
        self.clause("flats horizontal", self.flats_horizontal(), str(span))

    @row("A4", chunk=1, on="rung04", expect={"blocker": "A3", "sketch": True, "min_lines": 6})
    def row_A4(self) -> None:
        dimmed = self.dim_parallel_flats("7.65")
        self.clause("label 7.65", self.label_has("7.65"), str(dimmed["texts"]))
        self.clause("driving distance", self.driving_distance_count() >= 1, str(dimmed["texts"]))
        span = self.profile_span()
        ok = span.get("span_y") is not None and abs(span["span_y"] - self.af()) <= 0.2
        self.clause("af 7.65", ok, str(span))

    @row("N2", chunk=1, on="rung04", expect={"blocker": "A4", "sketch": True, "dim_has": "7.65"})
    def row_N2(self) -> None:
        zero = self.refuse_dim("7.65", "0")
        self.clause("zero refused", "positive number" in zero["results"], zero["results"])
        neg = self.refuse_dim("7.65", "-5")
        self.clause("negative refused", "positive number" in neg["results"], neg["results"])
        self.clause("unchanged", self.label_has("7.65"), f"{neg['after']}")
        esc = self.esc_editor()
        self.clause("esc", esc["opened"] and not esc["editor"], f"opened={esc['opened']} editor={esc['editor']}")

    @row("A5", chunk=1, on="rung04", expect={"blocker": "A4", "sketch": True})
    def row_A5(self) -> None:
        applied = self.vertical_vertex_pair()
        span = self.profile_span()
        self.clause("vertical", "Vertical" in applied["status"], applied["status"])
        self.clause("point up", self.point_up(), str(span))
        along_x = span.get("span_x") is not None and abs(span["span_x"] - self.af()) <= 0.2
        self.clause("af along x", along_x, str(span))
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")

    @row("L2", chunk=1, on="rung04", expect={"blocker": "A5", "sketch": True})
    def row_L2(self) -> None:
        span = self.profile_span()
        self.clause("vertex up", self.point_up() and (span.get("max_y") or 0) > 1, str(span))
        boxes = self.label_boxes(["7.65"])
        visible = bool(boxes) and all(b.get("visible", True) for b in boxes)
        self.clause("label visible", visible, str(boxes[:2]))
        circles = [c for c in self.ents("circle") if c.get("construction")]
        self.clause("circle reference", len(circles) == 1, f"n={len(circles)}")

    @row("A6", chunk=1, on="rung04", expect={"blocker": "A5", "sketch": True})
    def row_A6(self) -> None:
        status = self.exit_sketch()
        self.refresh("sketch", "bodies", "features")
        roles = self.sketch_roles()
        bodies = list(self.st.get("bodies") or [])
        self.clause("exit", not bool((self.st.get("sketch") or {}).get("active")), status)
        self.clause("one sketch", len(roles) == 1, str(roles))
        self.clause("no body", len(bodies) == 0, str(bodies))
        self.clause("role profile", roles == ["profile"], str(roles))
        path = self.save_as("hex.sxp")
        self.clause("saved", Path(path).is_file(), path)
        self.ctx["hex_name"] = (self.sketch_names() or [""])[0]
