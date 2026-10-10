"""A8b/A9 variant rebuild walks."""
from __future__ import annotations

from sxdrive import SxError
from walk.harness import RowAbort

class WalkVariants:
    def row_A8b_variant_walk(self) -> None:
        # Screenshot walk: Exit Sketch, reopen with the Timeline pencil, then
        # the wall click / Esc / Esc / Ctrl+Z that left sketch 3 on the Timeline.
        self.click("rail:ExitSketch")
        exited = self.refresh("status", "timeline")
        self.clause("exit sketch", "Sketch saved" in self.S() or self.S().startswith("Sketch"), str(exited.get("status", self.S())))
        reopened = self._reopen_sketch3()
        self.clause("pencil reopen", "Editing sketch" in reopened, reopened)
        self.click("rail:Select")
        samples = self.wall_screen_points(4) or [self._jaw_wall_screen(0.3)]
        got = ""
        hit = False
        for pt in samples:
            self.click(screen=pt)
            self.refresh("status")
            got = self.S()
            if "Selected 1 sketch entity" in got and "Constraint selected" not in got:
                hit = True
                break
            self.click(sketch=[300, 80])
        self.clause("wall", hit, got)
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc", "Selection cleared" in s1 and "Sketch saved" in s2, s1 + " | " + s2)
        self._show_timeline()
        self.d.key("ctrl+z")
        self.refresh("status", "timeline")
        names = self._timeline_names()
        stayed = any("sketch 3" in n for n in names)
        self.clause(
            "sketch 3 after part undo",
            not stayed,
            f"status={self.S()!r} timeline={names}",
            kind="" if not stayed else "product",
        )

    def row_A9_variant_walk(self) -> None:
        # Same walk: pencil reopen, Smart Dim already applied, Line across the
        # head, Power Trim dragged from the outer stub (head-side closing cut).
        names = self._timeline_names()
        if not any("sketch 3" in n for n in names):
            self.d.key("ctrl+shift+z")
            self.refresh("status", "timeline")
            names = self._timeline_names()
        if not self._sketch_active():
            reopened = self._reopen_sketch3()
            self.clause("pencil reopen", "Editing sketch" in reopened, reopened)
        else:
            self.clause("pencil reopen", True, "sketch already open")
        self.d.key("f")
        self.refresh("status")
        typed = self.circle([0, 0], "5")
        self.clause("pivot circle", "Circle r=5.0000" in self.S(), f"typed={typed} {self.S()}")
        typed = self.circle([200, 0], "22.5", burst=True)
        self.clause("head circle", "22.5000" in self.S(), f"typed={typed} {self.S()}")
        self.click("rail:Line")
        self.refresh("focus_text", "finish")
        length = self.field("finish:Radius") or str(self.st.get("focus_text", ""))
        self.clause("length not 22.5", "22.5" not in length, length or "(empty)")
        # Walk log, head centre (1573, 620), s≈4.57: line (1440,496)→(1720,736).
        self.click(sketch=[171, 27])
        self.click(sketch=[232, -25])
        self.refresh("status")
        self.click("rail:Trim")
        # Outer stub of that line, dragged across it toward the head.
        self.d.drag({"sketch": [226, -20]}, {"sketch": [200, 0]})
        self.refresh("status", "dims")
        self.clause("trimmed", "Trimmed open jaw" in self.S(), self.S())
        texts = self.dim_texts()
        neg = any("-" in str(t) for t in texts)
        has_45 = any(self._label_is("45", t) for t in texts)
        self.clause(
            "angle after this trim",
            (not neg) and has_45,
            f"drawn={texts}",
            kind="" if (not neg and has_45) else "product",
        )

    def run_variants(self) -> None:
        if not (self.out / "blank.sxp").exists():
            self.clauses = []
            self.clause("blank.sxp", False, "variant rebuild has no blank.sxp", kind="runner-gap")
            self.rows.append({
                "row": "A8b-variant-walk",
                "verdict": "FAIL runner-gap",
                "seconds": 0,
                "clauses": self.clauses,
                "evidence": "blank.sxp missing",
                "status": "",
            })
            return
        try:
            self.build_open_jaw()
        except (SxError, RowAbort) as exc:
            self.clauses = []
            self.clause("rebuild jaw", False, str(exc), kind="runner-gap")
            self.rows.append({
                "row": "A8b-variant-walk",
                "verdict": "FAIL runner-gap",
                "seconds": 0,
                "clauses": self.clauses,
                "evidence": str(exc),
                "status": self.st.get("status", ""),
            })
            return
        self.run_row("A8b-variant-walk")
        self.run_row("A9-variant-walk")

    # --- report -----------------------------------------------------------
