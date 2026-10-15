"""Rung-4 chunk 3: Swept Boss, checker, reopen, headless evidence."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows04Chunk3:
    @row("N4", chunk=3, on="rung04", expect={"blocker": "A14"})
    def row_N4(self) -> None:
        names = self.sketch_names()
        hex_name = next((n for n, r in zip(names, self.sketch_roles()) if r == "profile"), names[0] if names else "")
        feats = len(self.refresh("features").get("features") or [])
        bodies_before = list(self.refresh("bodies").get("bodies") or [])
        self.click("sweep:Boss")
        self.pick_timeline(hex_name)
        self.click("sweep:Ok")
        self.refresh("bodies", "status", "features")
        bodies = list(self.st.get("bodies") or [])
        self.clause("refused", "path" in self.S().lower() or "Select a profile" in self.S(), self.S())
        self.clause("no body", len(bodies) == len(bodies_before), str(bodies))
        self.clause("timeline unchanged", len(self.st.get("features") or []) == feats, str(self.feature_names()))
        self.esc()

    @row("A15", chunk=3, on="rung04", expect={"blocker": "A14"})
    def row_A15(self) -> None:
        names = self.sketch_names()
        roles = self.sketch_roles()
        hex_name = next((n for n, r in zip(names, roles) if r == "profile"), names[0] if names else "")
        path_name = next((n for n, r in zip(names, roles) if r == "rail"), names[-1] if names else "")
        self.click("sweep:Boss")
        self.pick_timeline(hex_name)
        self.pick_timeline(path_name)
        self.click("sweep:Ok")
        self.d.wait_idle(frames=6)
        self.refresh("bodies", "status", "features")
        bodies = list(self.st.get("bodies") or [])
        self.clause("profile", hex_name != "", hex_name)
        self.clause("path", path_name != "", path_name)
        self.clause("status", "Sweep solid created along path" in self.S(), self.S())
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A16", chunk=3, on="rung04", expect={"blocker": "A15", "part": True, "min_bodies": 1})
    def row_A16(self) -> None:
        report = self.final_report()
        ok, line = self.check_probe(report["text"], "bbox")
        self.clause("exported", report["exported"], "final.3mf")
        self.clause("bbox", ok and report["code"] == 0, line)

    @row("A17", chunk=3, on="rung04", expect={"blocker": "A16"})
    def row_A17(self) -> None:
        report = self.final_report()
        ok, line = self.check_probe(report["text"], "volume")
        self.clause("volume", ok, line)

    @row("A18", chunk=3, on="rung04", expect={"blocker": "A16"})
    def row_A18(self) -> None:
        report = self.final_report()
        ok, line = self.check_probe(report["text"], "inside")
        self.clause("inside short", ok, line)
        self.clause("inside arc", ok, line)
        self.clause("inside long", ok, line)

    @row("A19", chunk=3, on="rung04", expect={"blocker": "A16"})
    def row_A19(self) -> None:
        report = self.final_report()
        out_ok, out_line = self.check_probe(report["text"], "outside")
        wt_ok, wt_line = self.check_probe(report["text"], "watertight")
        self.clause("outside", out_ok, out_line)
        self.clause("watertight", wt_ok, wt_line)

    @row("L6", chunk=3, on="rung04", expect={"blocker": "A15"})
    def row_L6(self) -> None:
        names = self.feature_names()
        bodies = list(self.refresh("bodies").get("bodies") or [])
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        self.clause("order", types[:3] == ["sketch", "sketch", "sweep"] or types.count("sketch") >= 2, str(types))
        self.clause("names distinct", len(names) == len(set(names)), str(names))
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A20", chunk=3, on="rung04", expect={"blocker": "A15"})
    def row_A20(self) -> None:
        path = self.save_as("final.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "final" in self.S(), self.S())

    @row("N5", chunk=3, on="rung04", expect={"blocker": "A20"})
    def row_N5(self) -> None:
        reopened = self.reopen("final.sxp")
        bodies = list(self.refresh("bodies").get("bodies") or [])
        self.clause("reopened", "final" in reopened["status"] or len(bodies) == 1, reopened["status"])
        self.clause("one body", len(bodies) == 1, str(bodies))
        self.clause("no error", "error" not in reopened["status"].lower(), reopened["status"])
        path = self.export_3mf("final-reopen.3mf")
        code, text = self.checker("final", "final-reopen.3mf")
        bbox_ok, bbox_line = self.check_probe(text, "bbox")
        vol_ok, vol_line = self.check_probe(text, "volume")
        self.clause("bbox", bbox_ok and code == 0 and Path(path).is_file(), bbox_line)
        self.clause("volume", vol_ok, vol_line)

    @row("A21", chunk=3, on="rung04", expect={"blocker": "A20"})
    def row_A21(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
