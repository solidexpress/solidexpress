"""Rung-2 chunk 1: the 100 × 60 × 50 blank."""
from __future__ import annotations

from walk.registry import row


def _near(pt, x, y, tol=0.2) -> bool:
    return abs(pt[0] - x) <= tol and abs(pt[1] - y) <= tol


class Rows02Chunk1:
    @row("N1", chunk=1, on="rung02")
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

    @row("A1", chunk=1, on="rung02")
    def row_A1(self) -> None:
        status = self.new_part()
        self.clause("new", "New —" in status or "empty part" in status, status)
        view = self.ground_sketch()
        active = bool((self.st.get("sketch") or {}).get("active"))
        self.clause("sketch", active and ("Sketch" in self.S() or "Top" in view), f"{self.S()} | {view}")
        snap = self.control("rail:Snap") or {}
        infer = self.control("rail:Infer") or {}
        self.clause(
            "Snap Infer",
            snap.get("text") == "Snap" and infer.get("text") == "Infer",
            f"snap={snap.get('text')!r} infer={infer.get('text')!r}",
        )
        dof = self.dof_text()
        self.clause("dof glyph", dof != "", f"dof={dof!r}")

    @row("A2", chunk=1, on="rung02", expect={"blocker": "A1", "sketch": True})
    def row_A2(self) -> None:
        drawn = self.draw_corner_rect((0, 0), (100, 65))
        self.clause("rect armed", drawn["armed"]["ok"], f"{drawn['armed']['status']} lit={drawn['armed']['lit']}")
        self.clause("four lines", len(drawn["lines"]) == 4, f"lines={len(drawn['lines'])}")
        pts = (drawn["bbox"] or {}).get("pts") or []
        self.clause("origin corner", any(_near(p, 0, 0) for p in pts), f"pts={pts[:8]}")
        self.clause("status", "Rect" in drawn["status"], drawn["status"])
        box = drawn["bbox"] or {}
        span = None
        if box:
            span = (box["max"][0] - box["min"][0], box["max"][1] - box["min"][1])
        ok = span is not None and abs(span[0] - 100) <= 0.2 and abs(span[1] - 65) <= 0.2
        self.clause("bbox sketch 100 × 65", ok, f"span={span}")

    @row("L1", chunk=1, on="rung02", expect={"blocker": "A1", "sketch": True})
    def row_L1(self) -> None:
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        nodes = self.rail_label_nodes()
        texts = {str(n.get("text", "")) for n in nodes}
        clipped = [n.get("text") for n in nodes if not self.node_inside(n, size)]
        want = {"Rect", "Smart Dim", "Circle", "Convert", "Select"}
        self.clause("labels", want <= texts and not clipped, f"have={sorted(texts)} clipped={clipped}")
        keys = []
        ok = True
        for key, prefix in (("r", "Rect"), ("d", "Smart"), ("c", "Circle"), ("s", "Select")):
            armed = self.arm_by_key(key)
            hit = armed["status"].startswith(prefix) and len(armed["lit"]) == 1
            ok = ok and hit
            keys.append(f"{key}:{armed['status']} lit={armed['lit']}")
        self.clause("keys", ok, "; ".join(keys))

    @row("A3", chunk=1, on="rung02", expect={"blocker": "A2", "sketch": True, "min_lines": 4})
    def row_A3(self) -> None:
        top = self.dimension_line(self.top_line(), "100")
        right = self.dimension_line(self.right_line(), "65")
        self.clause("label 100", self.label_has("100"), f"{top['texts']}")
        self.clause("label 65", self.label_has("65"), f"{right['texts']}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")
        width = self.line_length(self.top_line())
        height = self.line_length(self.right_line())
        ok = width is not None and height is not None and abs(width - 100) <= 0.2 and abs(height - 65) <= 0.2
        self.clause("lines length", ok, f"top={width} right={height}")

    @row("N2", chunk=1, on="rung02", expect={"blocker": "A3", "sketch": True, "dim_has": "65"})
    def row_N2(self) -> None:
        zero = self.refuse_dim("65", "0")
        self.clause("zero refused", "positive number" in zero["results"], zero["results"])
        neg = self.refuse_dim("65", "-5")
        self.clause("negative refused", "positive number" in neg["results"], neg["results"])
        self.clause("unchanged", self.label_has("65") and self.label_has("100"), f"{neg['after']}")
        esc = self.esc_editor()
        self.clause("esc", esc["opened"] and not esc["editor"], f"opened={esc['opened']} editor={esc['editor']}")

    @row("A4", chunk=1, on="rung02", expect={"blocker": "A3", "sketch": True, "dim_has": "65"})
    def row_A4(self) -> None:
        edited = self.edit_label_to("65", "60")
        self.clause("editor open", edited["opened"], f"texts={edited['texts']}")
        self.clause("label 60", self.label_has("60"), f"{edited['texts']}")
        box = edited["bbox"] or {}
        span = None
        if box:
            span = (box["max"][0] - box["min"][0], box["max"][1] - box["min"][1])
        ok = span is not None and abs(span[0] - 100) <= 0.2 and abs(span[1] - 60) <= 0.2
        self.clause("bbox 100 × 60", ok, f"span={span}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")
        added = edited["undo_after"][len(edited["undo_before"]):]
        self.clause("undo step", any("Dimension" in str(label) for label in added), f"undo={edited['undo_after']}")
        self.ctx["width"] = 60.0

    @row("L2", chunk=1, on="rung02", expect={"blocker": "A4", "sketch": True, "dim_has": "60"})
    def row_L2(self) -> None:
        boxes = self.label_boxes(["100", "60"])
        self.clause("visible", len(boxes) >= 2 and all(d.get("visible", True) for d in boxes), str(self.dim_texts()))
        self.clause("not occluded", all(not d.get("occluded") for d in boxes), str([d.get("rect") for d in boxes]))
        overlap = len(boxes) >= 2 and self.rects_overlap(boxes[0].get("rect") or [], boxes[1].get("rect") or [])
        self.clause("no overlap", len(boxes) >= 2 and not overlap, str([d.get("rect") for d in boxes]))

    @row("N3", chunk=1, on="rung02", expect={"blocker": "A4", "sketch": True})
    def row_N3(self) -> None:
        tried = self.try_extrude("0", apply=True)
        refused = any(tok in tried["status"].lower() for tok in ("fail", "positive", "small", "zero", "invalid", "closed"))
        self.clause("zero refused", refused, tried["status"])
        self.clause("sketch kept", tried["sketch"], tried["status"])
        self.clause("no feature", not any(str(n).startswith("extrude") for n in tried["names"]), str(tried["names"]))

    @row("A5", chunk=1, on="rung02", expect={"blocker": "A4", "sketch": True, "min_lines": 4})
    def row_A5(self) -> None:
        made = self.try_extrude("50")
        self.clause("extrude", "Extrude Blind 50.0000 mm" in made["status"], made["status"])
        self.clause("status", "Extrude Blind" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        report = self.export_and_check("base", "base.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("exported", report["exported"], "base.3mf")
        self.clause("base", report["check_ok"], report["check_text"])

    @row("A6", chunk=1, on="rung02", expect={"blocker": "A5", "part": True, "min_bodies": 1})
    def row_A6(self) -> None:
        saved = self.save_part("box.sxp")
        self.clause("saved", "Saved" in saved["status"], saved["status"])
        self.clause("file exists", saved["exists"], saved["path"])
        self.clause("title", "box" in saved["status"], saved["status"])
