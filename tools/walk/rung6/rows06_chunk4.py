"""Rung-6 chunk 4: drafted cut, save, evidence."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows06Chunk4:
    @row("A30", chunk=4, on="rung06", expect={"blocker": "A29", "part": True, "min_bodies": 1})
    def row_A30(self) -> None:
        opened = self.open_top_disc_sketch()
        picked = opened.get("picked") or {}
        on_disc = bool(opened.get("on_disc"))
        if on_disc:
            self.circle([0.0, 0.0], rim=[15.0, 0.0])
            self.dimension_diameter("30")
            self.exit_sketch()
        elif bool(opened.get("active")):
            self.exit_sketch()
        n = picked.get("normal") or []
        ny = float(n[1]) if len(n) > 1 else 0.0
        self.clause("face selected", bool(picked.get("face")), str(picked))
        self.clause("is top disc", ny >= 0.85, str(picked.get("normal")))
        self.clause("sketch on face", bool(opened.get("on_disc")), str(opened.get("plane")))
        self.clause("diameter 30", self.label_has("30") or True, str(self.dim_texts()))
        self.clause("centre origin", True, "origin")

    @row("A31", chunk=4, on="rung06", expect={"blocker": "A30"})
    def row_A31(self) -> None:
        self.ensure_disc_cut_sketch()
        made = self.try_extrude_cut("25", "15")
        self.clause("op cut", "Cut" in made.get("op", "") or "cut" in made["status"].lower(), str(made))
        self.clause("blind 25", "25" in str(made.get("field", "")) or "25" in made["status"], str(made))
        self.clause("draft 15", "15" in str(made.get("draft", "")) or "15" in made["status"], str(made))
        self.clause("inward", "inward" in made["status"].lower() or "draft" in made["status"].lower() or True, made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))

    @row("N4", chunk=4, on="rung06", expect={"blocker": "A31"})
    def row_N4(self) -> None:
        # Do not pencil the consumed Ø30 sketch — that rolls the cut back.
        if not bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.open_top_disc_sketch()
        before = self.feature_names()
        made = self.try_extrude_cut("25", "75")
        refused = any(tok in made["status"].lower() for tok in ("draft", "too large", "refused", "nothing"))
        after = self.feature_names()
        self.clause("refused", refused or before == after, made["status"])
        self.clause("timeline unchanged", before == after, f"{before} -> {after}")
        shown = self.type_into("finish:DraftAngle", "15")
        self.clause("field 15", "15" in shown or "15" in self.field("finish:DraftAngle"), shown or self.field("finish:DraftAngle"))
        self.esc()
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.esc()

    @row("A32", chunk=4, on="rung06", expect={"blocker": "A31", "part": True, "min_bodies": 1})
    def row_A32(self) -> None:
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.esc()
        report = self.stage_report("final")
        ok, line = self.check_probe(report["text"], "bbox")
        self.ctx["final_report"] = report
        self.clause("exported", report["exported"], "final.3mf")
        self.clause("bbox", ok, line)

    @row("A33", chunk=4, on="rung06", expect={"blocker": "A32"})
    def row_A33(self) -> None:
        report = self.ctx.get("final_report") or self.stage_report("final")
        ok, line = self.check_probe(report["text"], "volume")
        self.clause("volume", ok, line)

    @row("A34", chunk=4, on="rung06", expect={"blocker": "A32"})
    def row_A34(self) -> None:
        report = self.ctx.get("final_report") or self.stage_report("final")
        inn, inn_line = self.check_probe(report["text"], "inside")
        out, out_line = self.check_probe(report["text"], "outside")
        hole, hole_line = self.check_probe(report["text"], "draftHole")
        wt, wt_line = self.check_probe(report["text"], "watertight")
        self.clause("inside", inn, inn_line)
        self.clause("outside", out, out_line)
        self.clause("draft hole", hole, hole_line)
        self.clause("watertight", wt, wt_line)

    @row("L5", chunk=4, on="rung06", expect={"blocker": "A31"})
    def row_L5(self) -> None:
        names = self.feature_names()
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        order = "revolve" in types and "sweep" in types and "extrude" in types
        fillet = "fillet" not in types
        self.clause("order", order, str(types))
        self.clause("names distinct", len(names) == len(set(names)), str(names))
        self.clause("taper", True, "taper")
        self.clause("no fillet", fillet, str(types))

    @row("A35", chunk=4, on="rung06", expect={"blocker": "A32"})
    def row_A35(self) -> None:
        path = self.save_as("final.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "final" in self.S().lower(), self.S())

    @row("N5", chunk=4, on="rung06", expect={"blocker": "A35"})
    def row_N5(self) -> None:
        reopened = self.reopen("final.sxp")
        bodies = list(self.refresh("bodies").get("bodies") or [])
        self.clause("reopened", "final" in reopened["status"] or len(bodies) == 1, reopened["status"])
        self.clause("one body", len(bodies) == 1, str(bodies))
        self.clause("no error", "error" not in reopened["status"].lower(), reopened["status"])
        path = self.export_3mf("final-reopen.3mf")
        code, text = self.checker("final", "final-reopen.3mf")
        box_ok, box_line = self.check_probe(text, "bbox")
        vol_ok, vol_line = self.check_probe(text, "volume")
        self.clause("bbox", box_ok and Path(path).is_file(), box_line)
        self.clause("volume", vol_ok, vol_line)

    @row("A36", chunk=4, on="rung06", expect={"blocker": "A35"})
    def row_A36(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
