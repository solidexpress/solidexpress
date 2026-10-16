"""Rung-5 chunk 4: both-flange fillet, final.sxp, headless evidence."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows05Chunk4:
    @row("A22", chunk=4, on="rung05", expect={"blocker": "A21", "part": True, "min_bodies": 1})
    def row_A22(self) -> None:
        before = self.feature_names()
        armed = self.arm_fillet("5")
        first = self.pick_face("fillet_p")
        two = self.selected_edge_count() or self.fillet_count(self.S()) or 0
        shifted = self.pick_face("fillet_m", shift=True)
        four = shifted.get("count") or self.selected_edge_count() or self.fillet_count(self.S()) or 0
        status = self.apply_enter()
        names = self.feature_names()
        added = [n for n in names if n not in before]
        self.clause("armed 5", "5" in str(armed["radius"]) or "5" in armed["status"], str(armed))
        self.clause("two edges", int(two) == 2, f"two={two} {first.get('status')}")
        self.clause("four edges", int(four) == 4, f"four={four} {shifted.get('status')}")
        self.clause("applied", "Fillet 4 edges 5.00" in status or "4 edges" in status, status)
        self.clause(
            "one feature",
            len(added) == 1 and added[0].lower().startswith("fillet"),
            str(added),
        )
        self.ctx["fillet_status"] = status
        self.ctx["fillet_edges"] = four

    @row("N5", chunk=4, on="rung05", expect={"blocker": "A22", "part": True})
    def row_N5(self) -> None:
        before = self.feature_names()
        self.arm_fillet("5")
        self.pick_face("fillet_p")
        self.pick_face("fillet_m", shift=True)
        self.type_into("finish:StripR", "30")
        status = self.apply_enter()
        after = self.feature_names()
        refused = any(tok in status.lower() for tok in ("could not be built", "limit", "too large", "nothing"))
        self.clause("refused", refused, status)
        self.clause("timeline unchanged", before == after, f"{before} -> {after}")
        shown = self.type_into("finish:StripR", "5")
        self.clause(
            "radius 5",
            "5" in shown or "5" in self.field("finish:StripR"),
            shown or self.field("finish:StripR"),
        )
        self.esc()

    @row("A23", chunk=4, on="rung05", expect={"blocker": "A22", "part": True, "min_bodies": 1})
    def row_A23(self) -> None:
        report = self.stage_report("final")
        box_ok, box_line = self.check_probe(report["text"], "bbox")
        vol_ok, vol_line = self.check_probe(report["text"], "volume")
        wt_ok, wt_line = self.check_probe(report["text"], "watertight")
        self.clause("exported", report["exported"], "final.3mf")
        self.clause("final", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")
        self.clause("bbox", box_ok, box_line)
        self.clause("volume", vol_ok, vol_line)
        self.clause("watertight", wt_ok, wt_line)

    @row("L5", chunk=4, on="rung05", expect={"blocker": "A22"})
    def row_L5(self) -> None:
        names = self.feature_names()
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        order_ok = (
            "mirror" in types
            and "shell" in types
            and "fillet" in types
            and types.index("mirror") < types.rindex("shell")
            and types.rindex("shell") < types.index("fillet")
        )
        rims = int(self.ctx.get("fillet_edges") or 0) == 4 or "4 edges" in str(self.ctx.get("fillet_status", ""))
        self.clause("order", order_ok, str(types))
        self.clause("names distinct", len(names) == len(set(names)), str(names))
        self.clause("both rims", rims, str(self.ctx.get("fillet_status", types)))

    @row("A24", chunk=4, on="rung05", expect={"blocker": "A23"})
    def row_A24(self) -> None:
        path = self.save_as("final.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "final" in self.S(), self.S())

    @row("N6", chunk=4, on="rung05", expect={"blocker": "A24"})
    def row_N6(self) -> None:
        reopened = self.reopen("final.sxp")
        bodies = list(self.refresh("bodies").get("bodies") or [])
        zext = self.z_extent()
        length_ok = zext is not None and abs(zext[1] - zext[0] - 520) <= 0.2
        self.clause("reopened", "final" in reopened["status"] or len(bodies) == 1, reopened["status"])
        self.clause("one body", len(bodies) == 1, str(bodies))
        self.clause("no error", "error" not in reopened["status"].lower() and length_ok, f"{reopened['status']} z={zext}")
        path = self.export_3mf("final-reopen.3mf")
        code, text = self.checker("final", "final-reopen.3mf")
        self.clause("final", code == 0 and "FAIL" not in text and Path(path).is_file(), text.strip().splitlines()[-1] if text.strip() else "")

    @row("A25", chunk=4, on="rung05", expect={"blocker": "A24"})
    def row_A25(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
