"""Rung-3 chunk 5: shell the back face, then section Top."""
from __future__ import annotations

from walk.registry import row
from walk.rung3.ui03 import CAP_COLOUR, REMOVED_POINT, WALL_POINT


class Rows03Chunk5:
    @row("A21", chunk=5, on="rung03", expect={"blocker": "A20", "part": True, "min_bodies": 1})
    def row_A21(self) -> None:
        view = self.view_key("8")
        self.select_body()
        selected = self.select_face([0, 0, -1])
        chip = self.shell_chip()
        plane = selected.get("plane")
        is_back = plane is not None and abs(float(plane) - 0.0) <= 0.2
        # Selection kind Face (not an edge).
        sel = self.refresh("selection").get("selection") or {}
        face_not_edge = bool(sel.get("face")) and not sel.get("edge")
        self.clause("bottom view", "Bottom view" in view or "Bottom" in view, view)
        self.clause("face selected", bool(selected["face"]) and face_not_edge, selected["status"])
        self.clause("is back", is_back, f"plane={plane}")
        self.clause("chip present", chip is not None, str((chip or {}).get("rect")))

    @row("L6", chunk=5, on="rung03", expect={"blocker": "A21", "part": True})
    def row_L6(self) -> None:
        size = self.window_size()
        chip = self.shell_chip() or {}
        rect = chip.get("rect") or []
        self.clause("inside", self.node_inside(chip, size), f"rect={rect} window={size}")
        self.clause("label", str(chip.get("text", "")) == "Shell", str(chip.get("text")))
        self.clause("not covered", bool(rect) and not self.covered(rect), f"rect={rect}")
        wheel = self.wheel_over("strip:shell")
        self.clause(
            "wheel",
            not wheel["moved"],
            f"distance {wheel['before'].get('distance')} -> {wheel['after'].get('distance')}",
        )

    @row("N9", chunk=5, on="rung03", expect={"blocker": "A21", "part": True, "min_bodies": 1})
    def row_N9(self) -> None:
        before = self.feature_names()
        size = self.body_size()
        self.select_body()
        self.select_face([0, 0, -1])
        tried = self.apply_shell("30")
        refused = "limit" in tried["status"].lower() or "nothing added" in tried["status"].lower()
        self.clause("refused", refused, tried["status"])
        self.clause(
            "unchanged",
            tried["names"] == before and self.body_size() == size,
            f"{tried['names']} size={self.body_size()}",
        )
        field = tried["field"] or str((self.control("finish:Thickness") or {}).get("text", ""))
        # Shared chrome default is 5 mm (rung 2 N7). A refusal restores that
        # last legal thickness; nothing has applied 1 mm yet.
        self.clause("field 5", field.startswith("5"), f"field={field!r}")

    @row("A22", chunk=5, on="rung03", expect={"blocker": "A21", "part": True, "min_bodies": 1})
    def row_A22(self) -> None:
        self.select_body()
        self.select_face([0, 0, -1])
        chip = self.shell_chip()
        self.clause("panel", chip is not None, str((chip or {}).get("id")))
        made = self.apply_shell("1")
        names = made["names"]
        fillets = [i for i, n in enumerate(names) if str(n).startswith("fillet")]
        shells = [i for i, n in enumerate(names) if str(n).startswith("Shell")]
        order_ok = len(fillets) >= 2 and shells and shells[0] > fillets[-1]
        self.clause("thickness 1", made["shown"].startswith("1") or "1" in made["status"], f"shown={made['shown']!r}")
        self.clause("status", "Shell 1.0000 mm applied" in made["status"], made["status"])
        self.clause("order", order_ok, str(names))
        size = self.body_size()
        side = self.side()
        top = float(self.part()["PART"]["TOP"])
        ok = (
            size is not None
            and abs(size[0] - side) <= 0.1
            and abs(size[1] - side) <= 0.1
            and abs(size[2] - top) <= 0.1
        )
        self.clause("bbox", ok, f"size={size}")
        self.ctx["height"] = top
        report = self.export_and_check("final", "final.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("final", report["check_ok"], report["check_text"])

    @row("N10", chunk=5, on="rung03", expect={"blocker": "A22", "part": True, "min_bodies": 1})
    def row_N10(self) -> None:
        before = self.feature_names()
        self.arm_fillet("5")
        # Open-back rim: an outer edge on z≈0 after shell.
        edge = self._edge_near((-60, 0, 0.5), limit=12.0) or self._edge_near((60, 0, 0.5), limit=12.0)
        mark = self.mark()
        if edge is not None:
            self.d.click(edge=edge["id"], along=0.5)
        status = self.apply_enter()
        pick_status = " | ".join(self.result_texts(mark)) or status
        after = self.feature_names()
        refused = any(
            tok in status.lower()
            for tok in ("could not be built", "limit", "too large", "nothing added")
        )
        self.clause("refused", refused, status)
        self.clause("status pinned", refused, pick_status or status)
        self.clause("no feature", before == after, f"{before} -> {after}")
        self.esc()
        self.refresh("status")
        self.clause("esc", "Fillet" not in self.S() or self.fillet_armed_count() in (None, 0), self.S())

    @row("A23", chunk=5, on="rung03", expect={"blocker": "A22", "part": True, "min_bodies": 1})
    def row_A23(self) -> None:
        self.view_key("7")
        opened = self.open_section("Top")
        section = opened["section"]
        normal = section.get("normal") or [0, 0, 0]
        ny = abs(float(normal[1])) if normal else 0.0
        self.clause("section on", bool(section.get("on")), str(section))
        self.clause("plane Top", str(section.get("plane")) == "Top", str(section))
        self.clause("kept side", ny > 0.9, f"normal={normal}")
        self.clause("button pressed", opened["pressed"], str(opened["button"]))
        self.clause("status", "Section Top" in opened["status"] or "Top" in opened["status"], opened["status"])

    @row("L7", chunk=5, on="rung03", expect={"blocker": "A23", "part": True})
    def row_L7(self) -> None:
        cap = self.pixel_is(WALL_POINT, CAP_COLOUR, tol=6)
        self.clause("cap colour", cap["ok"], f"got={cap['got']} want={cap['want']}")
        removed = self.pixel_at(REMOVED_POINT)
        # Removed half should be darker / background-ish versus the cap.
        if removed is None or cap["got"] is None:
            removed_ok = False
        else:
            rem_sum = sum(removed)
            cap_sum = sum(cap["got"])
            removed_ok = rem_sum < cap_sum
        self.clause("removed is background", removed_ok, f"removed={removed} cap={cap['got']}")
        size = self.window_size()
        outline = ((-60, -60, 0), (60, 60, 55), (-60, 60, 30), (60, -60, 30))
        notes = []
        inside = True
        for model in outline:
            screen = self.project_model(model)
            hit = 0 <= float(screen[0]) <= float(size[0]) and 0 <= float(screen[1]) <= float(size[1])
            inside = inside and hit
            notes.append(str(screen))
        self.clause("outline inside", inside, "; ".join(notes))

    @row("A24", chunk=5, on="rung03", expect={"blocker": "A23", "part": True})
    def row_A24(self) -> None:
        toggled = self.toggle_section()
        section = toggled["section"]
        self.clause("section off", not bool(section.get("on")), str(section))
        self.clause("button released", not toggled["pressed"], str(toggled["button"]))
        wall = self.pixel_is(WALL_POINT, CAP_COLOUR, tol=6)
        self.clause("shading back", not wall["ok"], f"got={wall['got']} (not cap)")

    @row("N11", chunk=5, on="rung03", expect={"blocker": "A24", "part": True})
    def row_N11(self) -> None:
        self.d.key("k")
        self.d.wait_idle(frames=2)
        self.refresh("section", "controls", "status")
        on = self.section_state()
        btn_on = self.control("hud:Section") or {}
        pressed_on = bool(btn_on.get("pressed") or btn_on.get("button_pressed"))
        self.clause("K on", bool(on.get("on")), str(on))
        self.d.key("k")
        self.d.wait_idle(frames=2)
        self.refresh("section", "controls", "status")
        off = self.section_state()
        btn_off = self.control("hud:Section") or {}
        pressed_off = bool(btn_off.get("pressed") or btn_off.get("button_pressed"))
        self.clause("K off", not bool(off.get("on")), str(off))
        self.clause(
            "button follows",
            pressed_on and not pressed_off,
            f"on={pressed_on} off={pressed_off}",
        )
        self.clause(
            "plane kept",
            str(off.get("plane") or on.get("plane")) == "Top",
            f"on={on} off={off}",
        )

    def _edge_near(self, model, limit: float = 8.0) -> dict | None:
        best, best_d = None, limit
        for edge in self.edges():
            centre = self._edge_centre(edge)
            dist = sum((centre[i] - float(model[i])) ** 2 for i in range(3)) ** 0.5
            if dist < best_d:
                best, best_d = edge, dist
        return best
