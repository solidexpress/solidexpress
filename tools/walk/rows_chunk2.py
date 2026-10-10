"""Walk rows for chunk 2."""
from __future__ import annotations

from walk.registry import row

class RowsChunk2:
    @row('A7', chunk=2, expect={'blocker': 'A5', 'part': True, 'min_bodies': 1, 'bbox_x': (200, 260)})
    def row_A7(self) -> None:
        face = self.top_face()
        self.click(face=face["id"])
        self.refresh("status")
        self.clause("not editing", not self.S().startswith("Editing sketch") and self.S().startswith("Selected "), self.S())
        self.sketch_on_top()
        self.clause("face sketch", "Sketch on face" in self.S() and "10.0" in self.S(), self.S())
        a = self.d.project(sketch=[0, 0])["screen"]
        b = self.d.project(sketch=[200, 0])["screen"]
        rail = self.rail_right()
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        self.clause("framed", rail < a[0] < win[0] and rail < b[0] < win[0], f"{a} {b}")

    @row('L2', chunk=2, expect={'blocker': 'A7', 'sketch': True})
    def row_L2(self) -> None:
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Up To Surface")
        self.type_into("finish:Distance", "7")
        self.enter()
        self.refresh("finish")
        self.clause("cut up to", self.field("finish:Op") == "Cut" and "Up To" in self.field("finish:End"), str(self.st.get("finish")))

    @row('A6', chunk=2, expect={'blocker': 'L2', 'sketch': True, 'finish_op': 'Cut', 'finish_end': 'Up To'})
    def row_A6(self) -> None:
        self.click("rail:Circle")
        self.click(sketch=[40, 30])
        self.refresh("status")
        self.clause("centre", "centre set" in self.S() and "Selected" not in self.S(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc ladder", "First point dropped" in s1 and "Sketch cancelled" in s2, s1 + " | " + s2)
        self.refresh("selection")
        self.clause("no face", not (self.st.get("selection") or {}).get("face"), str(self.st.get("selection")))

    @row('N4', chunk=2, expect={'blocker': 'A6', 'part': True, 'min_bodies': 1})
    def row_N4(self) -> None:
        before_bodies, before_timeline = self._body_snapshot()
        self.sketch_on_top()
        self.refresh("finish")
        self.clause("finish reset", self.field("finish:End") == "Blind" and self.field("finish:Op") == "New", str(self.st.get("finish")))
        self.click("rail:Polygon")
        self.refresh("status")
        self.clause("polygon", self.S().startswith("Polygon —"), self.S())
        self.click(sketch=[0, 0])
        self.refresh("status", "focus_text")
        self.clause("centre set", "centre set" in self.S(), self.S())
        af = str(self.st.get("focus_text", ""))
        self.clause("AF placeholder", "0.01" not in af, af)
        self.d.type("20")
        self.enter()
        self.refresh("status")
        self.clause("AF 20", "Polygon AF 20.0000" in self.S(), self.S())
        self.click("rail:Circle")
        self.click(sketch=[0, 0])
        self.click("finish:Radius")
        self.d.key("ctrl+a")
        self.refresh("status", "selection")
        self.clause("ctrl+a field", "Selected" not in self.S(), self.S())
        mark = self.mark()
        self.esc()
        self.esc()
        texts = self.result_texts(mark)
        joined = " | ".join(texts)
        self.clause(
            "saved sketch",
            any("First point dropped" in t for t in texts) and any(t.strip() == "Sketch saved" or t.startswith("Sketch saved") for t in texts),
            joined or self.S(),
        )
        undo_mark = self.mark()
        self.d.key("ctrl+z")
        undo_texts = self.result_texts(undo_mark)
        undo_text = " | ".join(undo_texts) or self.S()
        self.clause("undo sketch", any(t.startswith("Undo") for t in undo_texts), undo_text)
        after_bodies, after_timeline = self._body_snapshot()
        self.clause(
            "bodies and timeline",
            before_bodies == after_bodies and before_timeline == after_timeline,
            f"bodies {before_bodies} -> {after_bodies} timeline {before_timeline} -> {after_timeline}",
        )

    @row('A7b', chunk=2, expect={'blocker': 'N4', 'part': True, 'min_bodies': 1, 'bbox_x': (200, 260)})
    def row_A7b(self) -> None:
        self.sketch_on_top()
        self.refresh("status", "finish")
        self.need("Sketch on face" in self.S(), "sketch", self.S())
        self.jaw_basis()
        left = self.d.project(sketch=[200 - 22.5, 0])["screen"]
        right = self.d.project(sketch=[200 + 22.5, 0])["screen"]
        self.ctx["x_left"] = min(left[0], right[0])
        self.ctx["x_right"] = max(left[0], right[0])
        self.ctx["y_mid"] = self.ctx["H"][1]
        self.clause(
            "measured",
            self.ctx["s"] > 0.2,
            f"x_left={self.ctx['x_left']:.1f} x_right={self.ctx['x_right']:.1f} y_mid={self.ctx['y_mid']:.1f} s={self.ctx['s']:.3f} H={self.ctx['H']}",
        )

    def _jaw_clicks(self, third_dv: float) -> str:
        self.click("rail:Jaw")
        self.click(screen=self.jaw_px(0, 0))
        self.d.hover(screen=self.jaw_px(20, 0))
        self.click(screen=self.jaw_px(20, 0))
        self.refresh("status")
        mid = self.S()
        self.click(screen=self.jaw_px(20, third_dv))
        self.refresh("status", "dims", "dof")
        return mid

    def _drawn_angle_and_width(self) -> tuple[dict | None, dict | None]:
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        width = self.find_dim(lambda d: "°" not in str(d.get("text", "")) and d.get("visible"))
        return width, angle

    @row('A8r', chunk=2, expect={'blocker': 'A7b', 'sketch': True})
    def row_A8r(self) -> None:
        if "H" not in self.ctx:
            self.jaw_basis()
        mid = self._jaw_clicks(-48.4)
        self.clause("click 2 names click 3", "click 3" in mid.lower() or "width" in mid.lower() or mid.startswith("Jaw"), mid)
        self.clause("committed 0", "Jaw committed" in self.S() and "long side 0.0°" in self.S(), self.S())
        width, angle = self._drawn_angle_and_width()
        self.clause("two labels", width is not None and angle is not None, str(self.dim_texts()))
        if angle is not None:
            self.clause("angle right of rail", self.label_clear(angle) and "0" in str(angle.get("text")), f"{angle.get('text')} {angle.get('rect')} rail={self.rail_right():.0f}")
        if width is not None:
            self.clause("width right of rail", self.label_clear(width), f"{width.get('text')} {width.get('rect')}")

    @row('A8w', chunk=2, expect={'blocker': 'A8r', 'sketch': True, 'dim_has': '°'})
    def row_A8w(self) -> None:
        width, angle = self._drawn_angle_and_width()
        self.need(width is not None and angle is not None, "labels present", str(self.dim_texts()))
        got = self.edit_dim(width, "20")
        self.clause("width 20", "Dimension updated" in self.S() and "rejected" not in self.S().lower(), f"field={got} {self.S()}")
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        self.need(angle is not None, "angle still drawn", str(self.dim_texts()))
        got = self.edit_dim(angle, "45")
        texts = self.dim_texts()
        self.clause("angle 45", "Dimension updated" in self.S() and any("45" in t for t in texts), f"field={got} {self.S()} {texts}")
        dof = str(self.refresh("dof").get("dof", ""))
        self.clause("dof not bang", "!" not in dof, dof)
        for _ in range(12):
            self.d.key("ctrl+z")
            self.refresh("status", "dof")
            if "Nothing to undo" in self.S():
                break
        self.clause("empty undo", "Nothing to undo" in self.S(), self.S())
        self.clause("dof em dash", str(self.st.get("dof", "")).strip() in ("—", "-"), str(self.st.get("dof")))
        self.d.key("ctrl+shift+z")
        self.d.key("ctrl+a")
        self.d.key("delete")
        self.refresh("dof", "status", "sketch")
        self.clause("deleted dof", str(self.st.get("dof", "")).strip() in ("—", "-"), f"{self.S()} dof={self.st.get('dof')}")

    @row('A8', chunk=2, expect={'blocker': 'A8w', 'sketch': True})
    def row_A8(self) -> None:
        if "H" not in self.ctx:
            self.jaw_basis()
        self.click("rail:Jaw")
        self.click(screen=self.jaw_px(0, 0))
        self.d.hover(screen=self.jaw_px(20, 0))
        self.click(screen=self.jaw_px(20, 0))
        zero = self.click(screen=self.jaw_px(20, 0))
        self.refresh("status", "sketch")
        self.clause("zero width", "width is zero" in str(zero.get("status", self.S())), str(zero.get("status", self.S())))
        self.click(screen=self.jaw_px(20, -10))
        self.refresh("status", "dims")
        self.clause("committed", "Jaw committed" in self.S() and "long side 0.0°" in self.S(), self.S())
        width, angle = self._drawn_angle_and_width()
        self.clause("labels before edit", width is not None and angle is not None and self.label_clear(angle or {"rect": []}), str(self.dim_texts()))
        if width is not None:
            got = self.edit_dim(width, "20")
            self.clause("width field", "20" in got or "Dimension updated" in self.S(), f"{got} {self.S()}")
        if angle is not None or self.find_dim(lambda d: "°" in str(d.get("text", ""))):
            angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
            if angle:
                got = self.edit_dim(angle, "45")
                self.clause("angle field", "45" in got or any("45" in t for t in self.dim_texts()), f"{got} {self.dim_texts()} {self.S()}")
        dof = str(self.refresh("dof").get("dof", ""))
        self.clause("no conflict", "!" not in dof, dof)

    @row('N5', chunk=2, expect={'blocker': 'A8', 'sketch': True, 'dim_has': '45'})
    def row_N5(self) -> None:
        self.click("rail:Select")
        with_jaw = str(self.refresh("dof").get("dof", ""))
        seen = []
        empty = with_jaw
        for _ in range(8):
            self.d.key("ctrl+z")
            self.refresh("status", "dof")
            seen.append(self.S())
            if "Nothing to undo" in self.S():
                empty = str(self.st.get("dof", ""))
                break
        restored = empty
        for _ in range(8):
            self.d.key("ctrl+shift+z")
            self.refresh("status", "dims", "dof")
            seen.append(self.S())
            texts_now = self.dim_texts()
            if any(self._label_is("45", t) for t in texts_now) and any(self._label_is("20", t) for t in texts_now):
                restored = str(self.st.get("dof", ""))
                break
        texts = self.dim_texts()
        self.ctx["n25"] = {"with": with_jaw, "empty": empty, "restored": restored}
        self.clause("undo redo", any(s.startswith("Undo") or s.startswith("Redo") or "Nothing" in s for s in seen), " | ".join(seen[-6:]))
        self.clause("labels back", any(self._label_is("45", t) for t in texts) and any(self._label_is("20", t) for t in texts), str(texts))

    @row('N25', chunk=2, expect={'blocker': 'N5', 'sketch': True})
    def row_N25(self) -> None:
        # The three readings are the N5 moments. Undoing again walks past the
        # jaw into later redos and is not the checklist.
        snap = dict(self.ctx.get("n25") or {})
        if not snap:
            self.refresh("dof")
            snap = {"with": str(self.st.get("dof", "")), "empty": "", "restored": str(self.st.get("dof", ""))}
        empty = str(snap.get("empty", "")).strip()
        restored = str(snap.get("restored", "")).strip()
        with_jaw = str(snap.get("with", "")).strip()
        self.clause("empty dash", empty in ("—", "-"), f"with={with_jaw} empty={empty} restored={restored}")
        self.clause("restored", restored == with_jaw or restored not in ("", "—", "-"), f"with={with_jaw} restored={restored}")
        self.ctx["dof_n25"] = with_jaw

    @row('A8b', chunk=2, expect={'blocker': 'A8', 'sketch': True, 'dim_has': '45'})
    def row_A8b(self) -> None:
        self.refresh("dof")
        self.ctx["dof_a8b"] = str(self.st.get("dof", ""))
        self.click("rail:Select")
        self.refresh("status")
        self.clause("select tool", self.S().startswith("Select —"), self.S())
        # 40% along the wall now sits under a leader badge. Use a sample
        # the badge rects leave clear, the same band N21b presses.
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
        self.menu("View", "Timeline")
        self.d.key("ctrl+z")
        undone = self.refresh("status", "timeline")
        names_undo = [str(r.get("name", "")) for r in (self.st.get("timeline") or []) if r.get("name")]
        self.clause("part undo", self.S().startswith("Undo"), self.S())
        # Screenshot walk of this build: Ctrl+Z prints Undo but sketch 3 stays. Product bug.
        left = not any("sketch 3" in n for n in names_undo)
        self.clause(
            "sketch 3 leaves timeline",
            left,
            f"status={self.S()!r} timeline={names_undo}",
            kind="" if left else "product",
        )
        self.d.key("ctrl+shift+z")
        self.refresh("status", "timeline")
        names = [str(r.get("name", "")) for r in (self.st.get("timeline") or [])]
        self.clause("sketch 3", self.S().startswith("Redo") and any("sketch 3" in n for n in names), f"{self.S()} {names}")
        self.ctx["_a8b_timeline"] = undone

    @row('N8a', chunk=2, expect={'blocker': 'A8b', 'part': True, 'timeline': 'sketch 3'})
    def row_N8a(self) -> None:
        rows = [r for r in (self.refresh("timeline").get("timeline") or []) if r.get("name")]
        pencil = None
        for r in rows:
            if "sketch 3" in str(r.get("name", "")) or "sketch" in str(r.get("name", "")):
                pencil = r
        target = None
        if pencil:
            target = "timeline:pencil:" + str(pencil.get("name"))
        self.need(target is not None, "pencil", str(rows))
        self.click(target)
        self.refresh("status", "finish", "dof")
        self.clause("editing", "Editing sketch" in self.S(), self.S())
        self.clause("finish 20", self.field("finish:Op") == "New" and "20" in self.field("finish:Distance"), str(self.st.get("finish")))
        dof = str(self.st.get("dof", ""))
        want = str(self.ctx.get("dof_a8b", ""))
        self.clause("dof matches A8b", dof.strip() == want.strip() and dof.strip() not in ("—", "-"), f"now={dof} a8b={want}")
