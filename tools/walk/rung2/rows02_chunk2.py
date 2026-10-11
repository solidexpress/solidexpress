"""Rung-2 chunk 2: one fillet on the four vertical edges."""
from __future__ import annotations

from walk.registry import row
from walk.rung2.ui02 import FEATURE_ORDER


class Rows02Chunk2:
    @row("A7", chunk=2, on="rung02", expect={"blocker": "A6", "part": True, "min_bodies": 1})
    def row_A7(self) -> None:
        armed = self.arm_fillet("10")
        self.clause("armed", armed["status"].startswith("Fillet"), armed["status"])
        self.clause("radius 10", "10" in str(armed["radius"]), f"radius={armed['radius']!r}")
        self.clause("status", "10" in armed["status"] or "Fillet" in armed["status"], armed["status"])

    @row("L3", chunk=2, on="rung02", expect={"blocker": "A7", "part": True})
    def row_L3(self) -> None:
        size = self.window_size()
        chip = self.control("chip:Fillet") or {}
        radius = self.control("finish:StripR") or {}
        inside = self.node_inside(chip, size) and self.node_inside(radius, size)
        self.clause("chip inside", inside, f"chip={chip.get('rect')} radius={radius.get('rect')}")
        y0 = (chip.get("rect") or [0, 0])[1]
        self.ctx["l3_pick"] = self.pick_one_corner()
        y1 = (self.chip_rect("chip:Fillet") or [0, y0])[1]
        self.clause("chip y stable", abs(float(y0) - float(y1)) <= 1.0, f"y {y0} -> {y1}")

    @row("A8", chunk=2, on="rung02", expect={"blocker": "A7", "part": True, "min_bodies": 1})
    def row_A8(self) -> None:
        # L3 leaves one edge picked. A second Fillet click would apply it.
        # Esc first, then arm again so the four picks start from zero.
        prior = self.ctx.pop("l3_pick", None)
        if isinstance(prior, dict) and prior.get("ok"):
            self.esc()
            self.refresh("status")
            self.arm_fillet("10")
        elif self.fillet_armed_count() not in (None, 0):
            self.disarm_fillet()
            self.arm_fillet("10")
        rest = self.pick_corner_edges()
        counts = []
        ok = True
        for i, pick in enumerate(rest, start=1):
            got = self.fillet_count(pick["status"])
            hit = got == i
            ok = ok and hit and pick["ok"]
            counts.append(f"{i}:{got}:{pick['status'][:80]}")
            self.clause(f"pick {i}", hit, pick["status"])
        ids = [p["id"] for p in rest if p.get("id")]
        self.clause("four edges one pick each", ok and len(set(ids)) == 4, "; ".join(counts))

    @row("N4", chunk=2, on="rung02", expect={"blocker": "A8", "part": True})
    def row_N4(self) -> None:
        edges = self.ctx.get("corner_edges") or []
        first = next((p for p in edges if p.get("id")), {})
        edge_id = str(first.get("id", ""))
        view = str(first.get("view", ""))
        status = self.pick_edge_again(edge_id, view) if edge_id else "no edge"
        count = self.fillet_count(status)
        self.clause("no double count", count is not None and count <= 4, status)
        if count is not None and count < 4 and edge_id:
            status = self.pick_edge_again(edge_id, view)
            count = self.fillet_count(status)
        self.clause("restored 4", count == 4, status)

    @row("N5", chunk=2, on="rung02", expect={"blocker": "A8", "part": True})
    def row_N5(self) -> None:
        before = self.feature_names()
        self.type_into("finish:StripR", "30")
        status = self.apply_enter()
        after = self.feature_names()
        refused = any(tok in status.lower() for tok in ("could not be built", "limit", "too large"))
        self.clause("refused", refused, status)
        self.clause("timeline unchanged", before == after, f"{before} -> {after}")
        self.clause("picks kept", self.fillet_count(self.S()) == 4 or "4 edge" in status or "4 edge" in self.S(), self.S())
        shown = self.type_into("finish:StripR", "10")
        self.clause("radius 10", "10" in shown or "10" in self.field("finish:StripR"), shown or self.field("finish:StripR"))

    @row("A9", chunk=2, on="rung02", expect={"blocker": "A8", "part": True, "min_bodies": 1})
    def row_A9(self) -> None:
        before = self.feature_names()
        status = self.apply_enter()
        names = self.feature_names()
        added = [n for n in names if n not in before]
        self.clause("applied", "Fillet 4 edges 10.00 applied" in status, status)
        self.clause("one feature", added == [FEATURE_ORDER[2]] or (len(added) == 1 and added[0].startswith("fillet")), str(added))
        self.clause("four edges", "4 edges" in status, status)
        self.clause("disarmed", "no longer armed" in status, status)
        report = self.export_and_check("rounded", "rounded.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("rounded", report["check_ok"], report["check_text"])
        saved = self.save_part("rounded.sxp")
        self.clause("saved", saved["exists"] and "Saved" in saved["status"], saved["status"])
