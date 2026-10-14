"""Rung-3 chunk 6: save, reopen, timeline look, headless evidence."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows03Chunk6:
    @row("A25", chunk=6, on="rung03", expect={"blocker": "A22", "part": True, "min_bodies": 1})
    def row_A25(self) -> None:
        path = self.save_as("final.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
        self.ctx["final_names"] = self.feature_names()

    @row("N12", chunk=6, on="rung03", expect={"blocker": "A25", "part": True})
    def row_N12(self) -> None:
        prior = list(self.ctx.get("final_names") or self.feature_names())
        opened = self.reopen("final.sxp")
        names = opened["names"]
        size = self.body_size()
        side = self.side()
        top = float(self.part()["PART"]["TOP"])
        bbox_ok = (
            size is not None
            and abs(size[0] - side) <= 0.1
            and abs(size[1] - side) <= 0.1
            and abs(size[2] - top) <= 0.1
        )
        section = opened.get("section") or self.section_state()
        self.clause(
            "reopened",
            "Open" in opened["status"] or names == prior or any(n.startswith("sketch") for n in names),
            opened["status"],
        )
        self.clause("order", names == prior or (len(names) >= 6 and names[-1].startswith("Shell")), str(names))
        self.clause("bbox", bbox_ok, f"size={size}")
        self.clause("no error", "error" not in opened["status"].lower(), opened["status"])
        self.clause("section off", not bool(section.get("on")), str(section))
        self.ctx["height"] = top
        report = self.export_and_check("final", "final-reopen.3mf")
        self.clause("final", report["check_ok"], report["check_text"])

    @row("L8", chunk=6, on="rung03", expect={"blocker": "A25", "part": True, "timeline": "sketch 1"})
    def row_L8(self) -> None:
        rows = self._timeline_names(show=True, records=True)
        panel_rect = self.timeline_panel_rect()
        inside = True
        for row_rec in rows:
            rect = row_rec.get("rect") or []
            if len(rect) < 4 or len(panel_rect) < 4:
                inside = False
                continue
            if rect[0] < panel_rect[0] - 2 or rect[0] + rect[2] > panel_rect[0] + panel_rect[2] + 2:
                inside = False
        names = [str(r.get("name")) for r in rows]
        self.clause("rows", inside and len(rows) >= 6, str(names))
        self.clause("names distinct", len(names) == len(set(names)) and len(names) >= 6, str(names))
        self.clause("not truncated", all("…" not in n and not n.endswith("...") for n in names), str(names))

    @row("A26", chunk=6, on="rung03", expect={"blocker": "A25", "part": True})
    def row_A26(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
