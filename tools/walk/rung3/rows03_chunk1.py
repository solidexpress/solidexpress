"""Rung-3 chunk 1: the 120 × 120 × 30 base."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows03Chunk1:
    @row("N1", chunk=1, on="rung03")
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

    @row("A1", chunk=1, on="rung03")
    def row_A1(self) -> None:
        status = self.new_part()
        self.clause("new", "New —" in status or "empty part" in status, status)
        view = self.sketch_ground("3")
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

    @row("A2", chunk=1, on="rung03", expect={"blocker": "A1", "sketch": True})
    def row_A2(self) -> None:
        drawn = self.centre_rect((0, 0), (60, 60))
        self.clause("rect armed", drawn["armed"]["ok"], f"{drawn['armed']['status']} lit={drawn['armed']['lit']}")
        self.clause("centre variant", drawn["armed"]["centre"], str(drawn["armed"]["variant"]))
        self.clause("four lines", len(drawn["lines"]) == 4, f"lines={len(drawn['lines'])}")
        self.clause("centred on origin", drawn["centred"], f"bbox={drawn['bbox']}")
        box = drawn["bbox"] or {}
        span = None
        if box:
            span = (box["max"][0] - box["min"][0], box["max"][1] - box["min"][1])
        ok = span is not None and abs(span[0] - 120) <= 0.2 and abs(span[1] - 120) <= 0.2
        self.clause("bbox sketch 120 × 120", ok, f"span={span}")

    @row("L1", chunk=1, on="rung03", expect={"blocker": "A1", "sketch": True})
    def row_L1(self) -> None:
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        nodes = self.rail_label_nodes()
        texts = {str(n.get("text", "")) for n in nodes}
        clipped = [n.get("text") for n in nodes if not self.node_inside(n, size)]
        want = {"Rect", "Smart Dim", "Circle", "Convert", "Offset", "Select"}
        self.clause("labels", want <= texts and not clipped, f"have={sorted(texts)} clipped={clipped}")
        variant = self.control("variant:Center") or {}
        # Centre may only show while Rect is armed.
        if not variant:
            self.click("rail:Rect")
            self.refresh("controls")
            variant = self.control("variant:Center") or {}
        self.clause(
            "variant visible",
            bool(variant) and variant.get("visible") is not False,
            str(variant.get("rect") or variant),
        )

    @row("A3", chunk=1, on="rung03", expect={"blocker": "A2", "sketch": True, "min_lines": 4})
    def row_A3(self) -> None:
        top = self.dimension_line(self.top_line(), "120")
        right = self.dimension_line(self.right_line(), "120")
        texts = self.dim_texts()
        count120 = sum(1 for t in texts if self._reads("120", t))
        self.clause("label 120", count120 >= 1, f"{top['texts']}")
        self.clause("label 120 (2)", count120 >= 2, f"{right['texts']}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")
        width = self.line_length(self.top_line())
        height = self.line_length(self.right_line())
        ok = width is not None and height is not None and abs(width - 120) <= 0.2 and abs(height - 120) <= 0.2
        self.clause("lines length", ok, f"top={width} right={height}")

    @row("N2", chunk=1, on="rung03", expect={"blocker": "A3", "sketch": True, "dim_has": "120"})
    def row_N2(self) -> None:
        zero = self.refuse_dim("120", "0")
        self.clause("zero refused", "positive number" in zero["results"], zero["results"])
        neg = self.refuse_dim("120", "-5")
        self.clause("negative refused", "positive number" in neg["results"], neg["results"])
        self.clause("unchanged", self.label_has("120"), f"{neg['after']}")
        esc = self.esc_editor()
        self.clause("esc", esc["opened"] and not esc["editor"], f"opened={esc['opened']} editor={esc['editor']}")

    @row("A4", chunk=1, on="rung03", expect={"blocker": "A3", "sketch": True, "min_lines": 4})
    def row_A4(self) -> None:
        made = self.try_extrude("30", op="New")
        self.clause("extrude", "Extrude Blind 30.0000 mm" in made["status"], made["status"])
        self.clause("status", "Extrude Blind" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        self.ctx["height"] = float(self.part()["PART"]["H0"])
        report = self.export_and_check("base", "base.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("exported", report["exported"], "base.3mf")
        self.clause("base", report["check_ok"], report["check_text"])

    @row("A5", chunk=1, on="rung03", expect={"blocker": "A4", "part": True, "min_bodies": 1})
    def row_A5(self) -> None:
        path = self.save_as("base.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "base" in self.S(), self.S())
