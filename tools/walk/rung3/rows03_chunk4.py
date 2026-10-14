"""Rung-3 chunk 4: R5 nine-edge fillet, then R1.5 annulus."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row
from walk.rung3.ui03 import REFUSE_FACE


class Rows03Chunk4:
    @row("A16", chunk=4, on="rung03", expect={"blocker": "A15", "part": True, "min_bodies": 1})
    def row_A16(self) -> None:
        armed = self.arm_fillet("5")
        self.clause("armed", armed["status"].startswith("Fillet"), armed["status"])
        self.clause("radius 5", "5" in str(armed["radius"]), f"radius={armed['radius']!r}")
        self.clause("status", "5" in armed["status"] or "Fillet" in armed["status"], armed["status"])

    @row("L5", chunk=4, on="rung03", expect={"blocker": "A16", "part": True})
    def row_L5(self) -> None:
        size = self.window_size()
        chip = self.control("chip:Fillet") or {}
        radius = self.control("finish:StripR") or {}
        inside = self.node_inside(chip, size) and self.node_inside(radius, size)
        self.clause("chip inside", inside, f"chip={chip.get('rect')} radius={radius.get('rect')}")
        y0 = (chip.get("rect") or [0, 0])[1]
        edges = self.ctx.get("corner_edges")
        if not edges:
            # Probe one corner so the chip y can be compared after a pick.
            from walk.rung3.ui03 import CORNERS
            x, y, view = CORNERS[0]
            self.d.key(view)
            self.d.wait_idle(frames=2)
            edge = self._z_edge_at(x, y)
            if edge is not None:
                self.d.click(edge=edge["id"], along=0.5)
                self.refresh("status", "controls")
                self.ctx["l5_probe_edge"] = edge["id"]
        y1 = (self.chip_rect("chip:Fillet") or [0, y0])[1]
        self.clause("chip y stable", abs(float(y0) - float(y1)) <= 1.0, f"y {y0} -> {y1}")

    @row("A17", chunk=4, on="rung03", expect={"blocker": "A16", "part": True, "min_bodies": 1})
    def row_A17(self) -> None:
        # L5 may have left one edge picked; clear and re-arm so counts start at 1.
        probe = self.ctx.pop("l5_probe_edge", None)
        if probe or self.fillet_armed_count() not in (None, 0):
            self.esc()
            self.refresh("status")
            self.arm_fillet("5")
        rest = self.pick_corner_edges()
        all_vertical = True
        for i, pick in enumerate(rest, start=1):
            got = self.fillet_count(pick["status"])
            hit = got == i and pick["ok"]
            self.clause(f"pick {i}", hit, pick["status"])
            all_vertical = all_vertical and bool(pick.get("vertical"))
        self.clause("all vertical", all_vertical and len(rest) == 4, "; ".join(p["status"][:60] for p in rest))

    @row("N6", chunk=4, on="rung03", expect={"blocker": "A17", "part": True})
    def row_N6(self) -> None:
        edges = self.ctx.get("corner_edges") or []
        first = next((p for p in edges if p.get("id")), {})
        edge_id = str(first.get("id", ""))
        view = str(first.get("view", ""))
        status = self.pick_edge_again(edge_id, view) if edge_id else "no edge"
        count = self.fillet_count(status)
        self.clause("toggled off", count is not None and count == 3, status)
        if edge_id:
            status = self.pick_edge_again(edge_id, view)
            count = self.fillet_count(status)
        self.clause("restored 4", count == 4, status)

    @row("A18", chunk=4, on="rung03", expect={"blocker": "A17", "part": True, "min_bodies": 1})
    def row_A18(self) -> None:
        self.view_key("3")
        shifted = self.shift_click_face([0, 0, 1], plane=30.0)
        status = shifted["status"]
        count = shifted["count"]
        self.clause("shift held", "Fillet:" in status, status)
        self.clause("nine edges", count == 9, status)
        # Root circle is the concave Ø70 at z=30 (~219.9 mm arc in the pick list).
        self.clause("root circle included", count == 9 and "arc" in status, status)
        # A pick that landed on the Ø70 top rim at R5 is refused; nine edges means we stayed clear.
        self.clause("no stray rim", count == 9 and "could not be built" not in status.lower(), status)

    @row("N7", chunk=4, on="rung03", expect={"blocker": "A18", "part": True})
    def row_N7(self) -> None:
        refused = self.plain_click_face([0, 0, 1], plane=30.0)
        status = refused["status"]
        pinned = REFUSE_FACE in status or "No edge near click" in status
        self.clause("refused", pinned, status)
        self.clause("message pinned", pinned, status)
        self.clause("count 9", self.fillet_count(self.S()) == 9 or refused["count"] == 9, self.S())

    @row("N8", chunk=4, on="rung03", expect={"blocker": "A18", "part": True})
    def row_N8(self) -> None:
        before = self.feature_names()
        self.type_into("finish:StripR", "30")
        status = self.apply_enter()
        after = self.feature_names()
        refused = any(tok in status.lower() for tok in ("could not be built", "limit", "too large"))
        self.clause("refused", refused, status)
        self.clause("timeline unchanged", before == after, f"{before} -> {after}")
        kept = self.fillet_count(self.S()) == 9 or "9 edge" in status or "9 edge" in self.S()
        self.clause("picks kept", kept, self.S())
        shown = self.type_into("finish:StripR", "5")
        self.clause("radius 5", "5" in shown or "5" in self.field("finish:StripR"), shown or self.field("finish:StripR"))

    @row("A19", chunk=4, on="rung03", expect={"blocker": "A18", "part": True, "min_bodies": 1})
    def row_A19(self) -> None:
        before = self.feature_names()
        status = self.apply_enter()
        names = self.feature_names()
        added = [n for n in names if n not in before]
        self.clause("applied", "Fillet 9 edges 5.00 applied" in status, status)
        self.clause("one feature", len(added) == 1 and added[0].startswith("fillet"), str(added))
        self.clause("nine edges", "9 edges" in status, status)
        self.clause("disarmed", "no longer armed" in status, status)
        self.ctx["height"] = float(self.part()["PART"]["TOP"])
        report = self.export_and_check("r5", "r5.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("r5", report["check_ok"], report["check_text"])

    @row("A20", chunk=4, on="rung03", expect={"blocker": "A19", "part": True, "min_bodies": 1})
    def row_A20(self) -> None:
        armed = self.arm_fillet("1.5")
        self.view_key("3")
        mark = self.mark()
        self.click(face_normal=[0, 0, 1], plane=55.0)
        face_status = " | ".join(self.result_texts(mark)) or self.S()
        count = self.fillet_count(face_status)
        before = self.feature_names()
        status = self.apply_enter()
        names = self.feature_names()
        added = [n for n in names if n not in before]
        self.clause("armed 1.5", "1.5" in str(armed["radius"]) or "1.5" in armed["status"], f"{armed}")
        self.clause("two edges", count == 2, face_status)
        self.clause("applied", "Fillet 2 edges 1.50 applied" in status, status)
        self.clause("one feature", len(added) == 1 and added[0].startswith("fillet"), str(added))
        report = self.export_and_check("rounded", "rounded.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("rounded", report["check_ok"], report["check_text"])
        path = self.save_as("rounded.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file() and "Saved" in self.S(), f"{path} {self.S()}")
