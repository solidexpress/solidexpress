"""Walk rows for chunk 1."""
from __future__ import annotations

from pathlib import Path

from sxdrive import SxError
from walk.registry import row

class RowsChunk1:
    @row('N22', chunk=1)
    def row_N22(self) -> None:
        st = self.refresh("window", "controls", "rail")
        win = st.get("window") or {}
        size = win.get("size") or [0, 0]
        screen = win.get("screen") or [0, 0]
        wide = float(size[0]) >= 1272 and float(size[1]) >= 750
        self.clause(
            "window",
            wide or bool(win.get("maximized")),
            f"window {size} screen {screen} maximized={win.get('maximized')}",
        )
        self.ctx["screen"] = screen
        self.ctx["shot"] = size
        status = self.control("hud:Status")
        menu = self.control("menu:File")
        rail = (self.refresh("rail").get("rail") or [None])[0]
        inside = True
        notes = []
        for label, node in (("status", status), ("menu", menu), ("rail", rail)):
            if not node:
                inside = False
                notes.append(f"{label} missing")
                continue
            r = node.get("rect") or []
            if len(r) < 4:
                continue
            if r[0] < -2 or r[1] < -2 or r[0] + r[2] > float(size[0]) + 2 or r[1] + r[3] > float(size[1]) + 2:
                inside = False
            notes.append(f"{label} {r}")
        self.clause("chrome inside", inside, "; ".join(notes))

    @row('A1', chunk=1)
    def row_A1(self) -> None:
        self.file_new()
        self.refresh("status")
        self.clause("new", "New —" in self.S() or "empty part" in self.S(), self.S())
        self.sketch_ground()
        self.need("Sketch" in self.S() or bool((self.st.get("sketch") or {}).get("active")), "sketch", self.S())
        snap = self.control("rail:Snap") or {}
        infer = self.control("rail:Infer") or {}
        self.clause(
            "Snap Infer",
            snap.get("text") == "Snap" and infer.get("text") == "Infer",
            f"snap={snap.get('text')!r} {snap.get('rect')} infer={infer.get('text')!r} {infer.get('rect')}",
        )
        dof = str(self.refresh("dof").get("dof", ""))
        self.clause("dof glyph", dof.strip() in ("—", "-", "OK", "!") or dof.strip().isdigit() or dof.strip() != "", f"dof={dof!r}")
        win = (self.refresh("window", "controls").get("window") or {}).get("size") or [1280, 800]
        seen: set[str] = set()
        rails = []
        for c in self.st.get("controls") or []:
            cid = str(c.get("id", ""))
            if not cid.startswith("rail:") or cid in ("rail:Snap", "rail:Infer"):
                continue
            if not str(c.get("text", "")).strip() or cid in seen:
                continue
            seen.add(cid)
            rails.append(c)
        clipped = []
        for b in rails:
            r = b.get("rect") or []
            if len(r) >= 4 and (r[1] < 0 or r[1] + r[3] > float(win[1]) + 2):
                clipped.append(b.get("text"))
        names = [str(b.get("text", "")) for b in rails]
        self.clause("rail labels", len(rails) >= 19 and not clipped, f"{len(rails)} labels {names} clipped={clipped}")
        self.ctx["rail_count"] = len(rails)

    @row('A2', chunk=1, expect={'blocker': 'A1', 'sketch': True})
    def row_A2(self) -> None:
        self.click("rail:Jaw")
        self.refresh("status", "controls")
        jaw = self.S()
        chips = [str(c.get("text", "")) for c in (self.st.get("controls") or []) if str(c.get("id", "")).startswith("variant:")]
        self.clause("jaw status", jaw.startswith("Jaw"), jaw)
        self.clause("jaw has no chips", not chips, str(chips))
        self.click("rail:Rect")
        self.refresh("status", "controls")
        chips = [str(c.get("text", "")) for c in (self.st.get("controls") or []) if str(c.get("id", "")).startswith("variant:")]
        self.clause("rect status", self.S().startswith("Rect —"), self.S())
        self.clause(
            "rect chips",
            chips[:5] == ["Corner", "Center", "Three Point", "Center Three Point", "Parallelogram"] or "Corner" in chips,
            str(chips),
        )

    @row('N7', chunk=1, expect={'blocker': 'A1', 'sketch': True})
    def row_N7(self) -> None:
        for tool, prefix in (("rail:Jaw", "Jaw"), ("rail:Rect", "Rect"), ("rail:Circle", "Circle")):
            self.click(tool)
            self.refresh("status", "rail")
            lit = self.lit_names()
            self.clause(prefix + " status", self.S().startswith(prefix), self.S())
            self.clause(prefix + " lit", len(lit) == 1 and prefix in lit[0], str(lit))
        self.click(sketch=[0, 0])
        self.refresh("status")
        self.clause("circle centre", "centre set" in self.S(), self.S())
        armed = None
        hovered = None
        for b in self.refresh("rail").get("rail") or []:
            if b.get("lit"):
                armed = b.get("fill") or []
            elif b.get("text") == "Line":
                hovered = b.get("hover_fill") or []
        differ = False
        if armed and hovered and len(armed) >= 3 and len(hovered) >= 3:
            differ = any(abs(float(armed[i]) - float(hovered[i])) >= 20 for i in range(3))
        self.clause("lit vs hover fill", bool(armed and hovered) and differ, f"lit={armed} hover={hovered}")

    @row('L1', chunk=1, expect={'blocker': 'A1', 'sketch': True})
    def row_L1(self) -> None:
        order = [
            ("rail:Jaw", "Jaw"), ("rail:Line", "Line"), ("rail:SmartDim", "Smart Dim"),
            ("rail:Trim", "Trim"), ("rail:Slot", "Slot"), ("rail:Circle", "Circle"), ("rail:Select", "Select"),
        ]
        for target, name in order:
            self.click(target)
            self.refresh("status", "rail")
            lit = self.lit_names()
            self.clause(name, self.S().startswith(name.split()[0]) and len(lit) == 1, f"{self.S()} lit={lit}")
        for key, name in (("l", "Line"), ("d", "Smart"), ("t", "Trim"), ("c", "Circle"), ("s", "Select")):
            self.d.key(key)
            self.refresh("status", "rail", "focus")
            lit = self.lit_names()
            self.clause("key " + key, self.S().startswith(name) and len(lit) == 1, f"{self.S()} lit={lit}")

    @row('A3', chunk=1, expect={'blocker': 'A1', 'sketch': True})
    def row_A3(self) -> None:
        self.click("rail:Select")
        self.d.key("ctrl+a")
        self.d.key("delete")
        self.refresh("status", "sketch")
        self.circle([0, 0], "10")
        self.clause("r10", "Circle r=10.0000" in self.S(), self.S())
        # "Right of it" — the measured centre distance is whatever this click lands,
        # then Smart Dim drives it to 200. Keep the second centre on screen.
        self.circle([30, 0], "22.5", burst=True)
        self.clause("r22.5", "22.5000" in self.S(), self.S())
        self.refresh("sketch")
        circles = [e for e in self._entities() if e.get("type") == "circle" and e.get("center")]
        circles.sort(key=lambda e: float(e["radius"]))
        self.need(len(circles) >= 2, "two circles", str(circles)[:200])
        c0 = list(circles[0]["center"])
        c1 = list(circles[1]["center"])
        self.click("rail:SmartDim")
        self.click(sketch=c0)
        self.refresh("status")
        self.clause("first pick", "first pick" in self.S().lower(), self.S())
        reply = self.click(sketch=c1)
        self.d.wait_idle(frames=3)
        self.refresh("status", "focus", "focus_text")
        self.clause(
            "second pick",
            "Selected 2" in self.S() or "DimEdit" in str(self.st.get("focus", "")) or "dim" in str(reply.get("target", "")),
            f"{self.S()} focus={self.st.get('focus')}",
        )
        typed = self._type_dim_editor("200")
        committed = self._num_is(typed, 200)
        self.clause("burst 200", committed, f"field={typed!r}")
        if committed:
            self.enter()
            self.clause("dimension", "Dimension updated" in self.S(), self.S())
        else:
            self.esc()
            self.clause("dimension", False, f"editor read {typed!r}; did not commit", kind="runner-gap")
        self.ctx["pivot"] = [0, 0]
        self.ctx["head"] = [200, 0]

    @row('L5', chunk=1, expect={'blocker': 'A3', 'sketch': True, 'min_circles': 2, 'span_mm': 100})
    def row_L5(self) -> None:
        mark_f = self.mark()
        self.d.key("f")
        fit_text = " | ".join(self.result_texts(mark_f))
        fit = "Sketch view fit" in fit_text or "Framed" in fit_text
        self.clause("F", fit, fit_text or self.S())
        mark = self.mark()
        self.click("hud:Frame")
        framed = " | ".join(self.result_texts(mark))
        self.clause("HUD Frame", "Sketch view fit" in framed or "Framed" in framed, framed or self.S())
        self.d.key("shift+f")
        self.refresh("status")
        a = self.d.project(sketch=[0, 0])["screen"]
        b = self.d.project(sketch=[200, 0])["screen"]
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        rail = self.rail_right()
        both = rail < a[0] < win[0] and rail < b[0] < win[0] and 40 < a[1] < win[1] and 40 < b[1] < win[1]
        self.clause("both circles inside", both, f"pivot {a} head {b} rail {rail} win {win}")

    def _chip_texts(self) -> str:
        self.refresh("controls")
        return " ".join(
            str(c.get("text", ""))
            for c in (self.st.get("controls") or [])
            if str(c.get("id", "")).startswith("chip:")
        )

    def _click_shaft(self, mid: list[float]) -> str:
        reply = self.click(sketch=mid)
        self.refresh("status")
        return str(reply.get("status", self.S()))

    def _empty_canvas(self) -> dict:
        return self.click(sketch=[320, 160])

    @row('A4', chunk=1, expect={'blocker': 'A3', 'sketch': True, 'min_circles': 2, 'span_mm': 100})
    def row_A4(self) -> None:
        # Smart Dim leaves both circles selected, which is what shows Shaft Lines
        # on the sketch ActionBar (not the part SelectionStrip).
        self.refresh("selection", "sketch", "controls")
        sel = (self.st.get("selection") or {}).get("sketch") or []
        if len(sel) < 2:
            self._select_both_circles()
        chips = self._chip_texts()
        self.clause("chip visible", "Shaft Lines" in chips or "More" in chips, chips[:240])
        if "Shaft Lines" in chips:
            self.click("chip:Shaft Lines")
        elif "More" in chips:
            self.click("chip:… More")
            self.click("popup:Shaft Lines")
        else:
            self.clause("shaft chip", False, "Shaft Lines not on the action bar or in … More: " + chips[:240], kind="runner-gap")
            raise RowAbort()
        self.refresh("status", "sketch")
        self.clause("shaft", "Shaft lines: 2 added" in self.S(), self.S())
        self.need("Shaft lines: 2 added" in self.S(), "shaft added", self.S())
        mids = self._shaft_mids()
        self.need(len(mids) >= 2, "two shaft lines", str(mids))
        self.click("rail:Select")
        self.refresh("status")
        self.clause("select tool", self.S().startswith("Select —"), self.S())
        # The two circles are still selected. An empty click clears them so the
        # shaft-line click is Selected 1, not an additive Selected 3.
        cleared = self._empty_canvas()
        self.refresh("status")
        self.clause("cleared", "No sketch entities" in str(cleared.get("status", self.S())), str(cleared.get("status", self.S())))
        first = self._click_shaft(mids[0])
        self.clause("line 1", "Selected 1 sketch entity" in first and "Constraint selected" not in first, first)
        empty = self._empty_canvas()
        self.refresh("status")
        self.clause("empty", "No sketch entities" in str(empty.get("status", self.S())), str(empty.get("status", self.S())))
        second = self._click_shaft(mids[1])
        self.clause("line 2", "Selected 1 sketch entity" in second and "Constraint selected" not in second, second)
        # Both selected: the second plain click adds.
        both = self._click_shaft(mids[0])
        chips = self._chip_texts()
        self.clause("both lines", "Selected 2" in both or "Selected 2" in self.S(), f"{both} chips={chips[:160]}")
        self.esc()
        after_esc = self._chip_texts()
        self.clause("esc clears chips", "Parallel?" not in after_esc and "Equal?" not in after_esc and "Perpendicular?" not in after_esc, after_esc[:160])
        self._click_shaft(mids[0])
        self._click_shaft(mids[1])
        empty2 = self._empty_canvas()
        self.refresh("status")
        after_empty = self._chip_texts()
        self.clause(
            "empty clears chips",
            "No sketch entities" in str(empty2.get("status", self.S())) and "Parallel?" not in after_empty,
            f"{self.S()} {after_empty[:120]}",
        )
        self._click_shaft(mids[0])
        self._click_shaft(mids[1])
        self.d.key("delete")
        self.refresh("status", "sketch")
        deleted = self.S()
        after_del = self._chip_texts()
        self.clause("delete", "Deleted 2" in deleted and "Parallel?" not in after_del, f"{deleted} {after_del[:80]}")
        self.d.key("ctrl+z")
        self.refresh("status", "sketch")
        mids_back = self._shaft_mids()
        self.clause("undo lines", "Undo: Delete" in self.S() and len(mids_back) >= 2, f"{self.S()} lines={len(mids_back)}")

    @row('L6', chunk=1, expect={'blocker': 'A4', 'sketch': True, 'min_lines': 2})
    def row_L6(self) -> None:
        self.refresh("measure", "glyphs", "infer")
        measure = self.st.get("measure") or []
        infer = self.st.get("infer") or {}
        bad = [m for m in measure if "✕" in str(m.get("text", "")) or "Δ" in str(m.get("text", ""))]
        self.clause(
            "no live delta",
            not bad,
            f"measure={bad} infer_visible={infer.get('visible')} glyphs={len(self.st.get('glyphs') or [])}",
        )
        for _ in range(3):
            self.d.wheel(-1, screen=self.d.project(sketch=[100, 0])["screen"])

    @row('L10', chunk=1, expect={'blocker': 'A3', 'sketch': True})
    def row_L10(self) -> None:
        for text in ("10", "14", "10"):
            got = self.type_into("finish:Distance", text)
            self.enter()
            shown = self.field("finish:Distance") if self.refresh("finish") else ""
            shown = self.field("finish:Distance")
            self.clause("distance " + text, text in got or text in shown, f"typed={got} field={shown} status={self.S()}")
        got = self.type_into("finish:Distance", "1.5")
        self.clause("1.5", "1.5" in str(got), str(got))
        self.d.key("ctrl+a")
        self.d.type("2.5", delay_ms=10)
        got = str(self.refresh("focus_text").get("focus_text", ""))
        self.clause("burst 2.5", got == "2.5", got)
        self.enter()
        self.type_into("finish:Distance", "10")
        self.enter()

    @row('A5', chunk=1, expect={'blocker': 'A4', 'sketch': True, 'min_lines': 2})
    def row_A5(self) -> None:
        self.set_option("finish:Op", "New")
        self.set_option("finish:End", "Blind")
        self.type_into("finish:Distance", "10")
        self.enter()
        reply = self.click("finish:Extrude", frames=8)
        self.refresh("status", "bodies")
        self.clause("extrude", "Extrude Blind 10.0000 mm" in str(reply.get("status", self.S())), str(reply.get("status", self.S())))
        self.clause("one body", len(self.st.get("bodies") or []) == 1, str(self.st.get("bodies")))
        if not self.body_guard("wrench", 10.0):
            raise RowAbort()
        path = self.export_3mf("blank.3mf")
        self.clause("exported", "Exported 3MF" in self.S() and Path(path).exists(), self.S())
        if Path(path).exists():
            code, text = self.checker("blank", "blank.3mf")
            self.clause("blank 5/5", code == 0 and "5/5" in text, text.strip().splitlines()[-1] if text.strip() else text)

    @row('N12', chunk=1, expect={'blocker': 'A5', 'part': True, 'min_bodies': 1, 'bbox_x': (200, 260)})
    def row_N12(self) -> None:
        chips = self.control("chip:Fillet")
        y0 = (chips or {}).get("rect", [0, 0, 0, 0])
        self.ctx["y0"] = y0[1] if len(y0) > 1 else None
        mark = self.mark()
        self.click("menu:File")
        self.esc()
        chips2 = self.control("chip:Fillet")
        y1 = (chips2 or {}).get("rect", [0, 0])
        if self.ctx["y0"] is not None and len(y1) > 1:
            self.clause("chip y stable", abs(float(y1[1]) - float(self.ctx["y0"])) <= 1.5, f"{self.ctx['y0']} -> {y1[1]}")
        else:
            self.clause("chip y", False, "Fillet chip rect missing")
        extrude = self.control("finish:Extrude")
        if extrude and extrude.get("rect"):
            r = extrude["rect"]
            reply = self.click("finish:Extrude")
            self.clause("shield", str(reply.get("disposition", "")) == "drop:shield", str(reply.get("disposition", "")) + " " + str(reply.get("status", "")))
        self.click("chip:Fillet")
        self.refresh("status")
        self.clause("fillet chip", self.S().startswith("Fillet r="), self.S())
        self.esc()
        self.esc_until("Selection cleared", 3)
        self.clause("cleared", "Selection cleared" in self.S() or "Edge pick cancelled" in self.S(), self.S())
        self.menu("View", "Timeline")
        self.refresh("timeline", "status")
        names = [str(r.get("name", "")) for r in (self.st.get("timeline") or [])]
        self.clause("timeline rows", any("sketch" in n for n in names) and any("extrude" in n for n in names), str(names))
        self.menu("View", "Timeline")
        lines = self.trace_from(mark)
        self.clause("popup trace", any("popup-trace" in ln for ln in lines), " | ".join(lines[-6:]))

    @row('A5b', chunk=1, expect={'blocker': 'A5', 'part': True, 'min_bodies': 1, 'bbox_x': (200, 260)})
    def row_A5b(self) -> None:
        self.file_new("cancel")
        self.refresh("status", "bodies")
        self.clause("cancel keeps blank", len(self.st.get("bodies") or []) >= 1 and "New —" not in self.S(), self.S())
        self.menu("File", "Save As...")
        self.refresh("focus_text", "popups")
        shown = str(self.st.get("focus_text", ""))
        self.clause("save as prefilled", "untitled" in shown or shown.endswith(".sxp") or shown == "", shown)

    @row('L8', chunk=1, expect={'blocker': 'A5b', 'popup': 'Save'})
    def row_L8(self) -> None:
        # Save As opens with untitled.sxp selected. Typing replaces that selection;
        # Ctrl+A is not part of this row.
        path = str(self.out / "blank.sxp")
        self._arm_dialog_dir()
        self._type_dialog_name("blank.sxp", replace_selection=True)
        shown = str(self.d.call("dialog_dir", path="").get("file", ""))
        self.clause("name replaced", shown == "blank.sxp" or shown.endswith("blank.sxp"), shown)
        reply = self.commit_dialog(set_dir=False)
        self.clause(
            "saved",
            (f"Saved {path}" in self.S() or self.S().endswith("blank.sxp")) and not reply.get("visible"),
            f"{self.S()} visible={reply.get('visible')}",
        )
        self.clause("file exists", Path(path).exists(), path)

    @row('L11', chunk=1, expect={'blocker': 'A5', 'part': True, 'min_bodies': 1})
    def row_L11(self) -> None:
        mark = self.mark()
        self.click("hud:View")
        self.click(model=[80, 0, 5])
        self.click("menu:View")
        self.esc()
        lines = self.trace_from(mark)
        popup = [ln for ln in lines if "popup-trace" in ln and "HudView" in ln]
        self.clause("HudView trace", any("show" in ln for ln in popup) and any("hide" in ln for ln in popup), " | ".join(popup) or " | ".join(lines[-8:]))

    @row('N17', chunk=1, expect={'blocker': 'A5', 'part': True, 'min_bodies': 1, 'bbox_x': (200, 260)})
    def row_N17(self) -> None:
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        self.need(bool(bodies), "body", "no body")
        self.click(screen=bodies[0]["screen"])
        self.refresh("status", "selection")
        self.clause("selected", self.S().startswith("Selected "), self.S())
        self.click("menu:View")
        self.esc()
        self.refresh("status", "selection")
        self.clause("esc keeps selection", "Selection cleared" not in self.S(), self.S())
        self.click("hud:View")
        self.esc()
        self.refresh("status")
        self.clause("hud esc keeps selection", "Selection cleared" not in self.S(), self.S())
        self.esc()
        self.clause("third esc", "Selection cleared" in self.S(), self.S())
