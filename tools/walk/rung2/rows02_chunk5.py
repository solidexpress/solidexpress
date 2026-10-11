"""Rung-2 chunk 5: 60 → 65 → 60, and the headless evidence row."""
from __future__ import annotations

from walk.registry import row
from walk.rung2.export_report import report_export
from walk.rung2.ui02 import FEATURE_ORDER


class Rows02Chunk5:
    @row("A22", chunk=5, on="rung02", expect={"blocker": "A21", "part": True, "timeline": "sketch 1"})
    def row_A22(self) -> None:
        status = self.edit_base_sketch()
        active = bool((self.refresh("sketch").get("sketch") or {}).get("active"))
        self.clause("editing sketch 1", active and "Editing sketch" in (status + self.S()), status or self.S())
        self.clause("rollback shown", self.timeline_has_rollback(), str(self.feature_names()))

    @row("A23", chunk=5, on="rung02", expect={"blocker": "A22", "sketch": True})
    def row_A23(self) -> None:
        edited = self.edit_dim(token="60", text="65")
        self.clause("edited", self.label_has("65"), str(edited["texts"]))
        mark = self.mark()
        status = self.exit_sketch()
        report_regen = self.regen_report(mark)
        self.clause("regen ok", "Sketch" in status and not report_regen["bad"], status)
        self.clause("no soft-skip", not report_regen["bad"], "; ".join(report_regen["bad"]) or "none")
        self.clause("order", tuple(self.feature_names()) == FEATURE_ORDER, str(self.feature_names()))
        size = self.body_size()
        ok = size is not None and abs(size[0] - 100) <= 0.1 and abs(size[1] - 65) <= 0.1 and abs(size[2] - 50) <= 0.1
        self.clause("bbox", ok, f"size={size}")
        self.ctx["width"] = 65.0
        report = report_export(self, "final", "final-65.3mf", 65)
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("final 65", report["check_ok"], report["check_text"])

    @row("N11", chunk=5, on="rung02", expect={"blocker": "A23", "part": True, "min_bodies": 1})
    def row_N11(self) -> None:
        self.chord("ctrl+z")
        self.ctx["width"] = 60.0
        size = self.body_size()
        undo_ok = size is not None and abs(size[1] - 60) <= 0.1
        self.clause("undo to 60", undo_ok, f"size={size}")
        report = report_export(self, "final", "final-60-undo.3mf", 60)
        self.clause("final 60", report["check_ok"], report["check_text"])
        self.chord("ctrl+shift+z")
        self.ctx["width"] = 65.0
        size = self.body_size()
        self.clause("redo to 65", size is not None and abs(size[1] - 65) <= 0.1, f"size={size}")
        self.clause("one body", len(self.refresh("bodies").get("bodies") or []) == 1, str(self.st.get("bodies")))

    @row("A24", chunk=5, on="rung02", expect={"blocker": "A23", "part": True, "min_bodies": 1})
    def row_A24(self) -> None:
        self.edit_base_sketch()
        edited = self.edit_dim(token="65", text="60")
        self.clause("edited", self.label_has("60"), str(edited["texts"]))
        mark = self.mark()
        status = self.exit_sketch()
        clean = self.regen_report(mark)
        self.clause("regen ok", not clean["bad"] and not self._sketch_active(), status)
        self.ctx["width"] = 60.0
        size = self.body_size()
        ok = size is not None and abs(size[0] - 100) <= 0.1 and abs(size[1] - 60) <= 0.1 and abs(size[2] - 50) <= 0.1
        self.clause("bbox", ok, f"size={size}")
        report = report_export(self, "final", "final-60b.3mf", 60)
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("final 60", report["check_ok"], report["check_text"])
        prev = self.ctx.get("final60_volume")
        vol = report.get("volume")
        same = prev not in (None, "") and vol not in (None, "") and abs(float(vol) - float(prev)) <= 0.001 * abs(float(prev))
        self.clause("same as A21", same, f"A21={prev} now={vol}")

    @row("N12", chunk=5, on="rung02", expect={"blocker": "A24", "part": True})
    def row_N12(self) -> None:
        self.save_as("final.sxp")
        opened = self.reopen("final.sxp")
        self.clause("reopened", "Open" in opened["status"] or opened["names"] == list(FEATURE_ORDER) or "sketch 1" in opened["names"], opened["status"])
        self.clause("order", tuple(opened["names"]) == FEATURE_ORDER, str(opened["names"]))
        self.edit_base_sketch()
        labeled = self.label_has("60")
        mark = self.mark()
        self.exit_sketch()
        clean = self.regen_report(mark)
        self.clause("no error", labeled and not clean["bad"], "; ".join(clean["bad"]) or self.S())
        self.ctx["width"] = 60.0
        report = report_export(self, "final", "final-reopen.3mf", 60)
        self.clause("final 60", report["check_ok"], report["check_text"])

    @row("L7", chunk=5, on="rung02", expect={"blocker": "A21", "part": True, "timeline": "sketch 1"})
    def row_L7(self) -> None:
        rows = self._timeline_names(show=True, records=True)
        panel_rect = self.timeline_panel_rect()
        inside = True
        for row in rows:
            rect = row.get("rect") or []
            if len(rect) < 4 or len(panel_rect) < 4:
                inside = False
                continue
            if rect[0] < panel_rect[0] - 2 or rect[0] + rect[2] > panel_rect[0] + panel_rect[2] + 2:
                inside = False
        names = [str(r.get("name")) for r in rows]
        self.clause("rows", inside and len(rows) >= 6, str(names))
        self.clause("names distinct", len(names) == len(set(names)) and len(names) >= 6, str(names))
        self.clause("not truncated", all("…" not in n and not n.endswith("...") for n in names), str(names))

    @row("A25", chunk=5, on="rung02", expect={"blocker": "A24", "part": True})
    def row_A25(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
