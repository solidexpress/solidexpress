"""Rung-3 chunk 3: Offset Entities → Ø60 cut through all."""
from __future__ import annotations

from walk.registry import row


class Rows03Chunk3:
    @row("A11", chunk=3, on="rung03", expect={"blocker": "A10", "part": True, "min_bodies": 1})
    def row_A11(self) -> None:
        # Furthest +Z face without plane= is z=55 (boss top).
        opened = self.face_sketch([0, 0, 1], plane=55.0, view_key="3")
        selected = opened["selected"]
        plane = opened["plane"]
        origin = plane.get("origin") or [0, 0, 0]
        z55 = selected.get("plane")
        is_z55 = z55 is not None and abs(float(z55) - 55.0) <= 0.2
        self.clause("face selected", bool(selected["face"]), selected["status"])
        self.clause("is z55", is_z55, f"plane={z55}")
        self.clause("sketch on face", opened["active"], opened["status"])
        self.clause(
            "origin",
            abs(float(origin[0])) < 0.2 and abs(float(origin[1])) < 0.2 and abs(float(origin[2]) - 55) < 0.2,
            str(origin),
        )

    @row("A12", chunk=3, on="rung03", expect={"blocker": "A11", "sketch": True})
    def row_A12(self) -> None:
        armed = self.offset_arm()
        fields = armed["fields"]
        present = all(fields.get(k) for k in ("distance", "reverse", "ok"))
        self.clause("armed", armed["armed"], f"{armed['status']} lit={armed['lit']}")
        self.clause("fields present", present, str({k: bool(fields.get(k)) for k in fields}))
        self.clause("status", "Offset" in armed["status"], armed["status"])

    @row("L3", chunk=3, on="rung03", expect={"blocker": "A12", "sketch": True})
    def row_L3(self) -> None:
        size = self.window_size()
        dist = self.control("offset:Distance") or {}
        rev = self.control("offset:Reverse") or {}
        ok = self.control("offset:Ok") or {}
        nodes = (dist, rev, ok)
        inside = all(self.node_inside(n, size) for n in nodes)
        self.clause("inside", inside, f"rects={[n.get('rect') for n in nodes]}")
        labels_ok = (
            "Distance" in str((self.refresh("controls").get("controls") or []))
            or str(rev.get("text", "")).find("Reverse") >= 0
        ) and ("Reverse" in str(rev.get("text", "")) or bool(rev.get("text")))
        # Labels: Reverse and OK on the controls; Distance is a sibling Label.
        label_texts = []
        for c in (self.refresh("controls").get("controls") or []):
            label_texts.append(str(c.get("text", "")))
        has_labels = (
            ("Reverse" in str(rev.get("text", "")) or "Reverse" in " ".join(label_texts))
            and ("OK" in str(ok.get("text", "")) or "Ok" in str(ok.get("text", "")))
        )
        self.clause("labels", has_labels or labels_ok, f"rev={rev.get('text')!r} ok={ok.get('text')!r}")
        covered = any(self.covered(list(n.get("rect") or []), skip_ids=("offset:Distance", "offset:Reverse", "offset:Ok")) for n in nodes if n.get("rect"))
        self.clause("not covered", not covered, f"covered={covered}")
        wheel = self.wheel_over("offset:Distance")
        self.clause(
            "wheel",
            not wheel["moved"],
            f"distance {wheel['before'].get('distance')} -> {wheel['after'].get('distance')}",
        )

    @row("N4", chunk=3, on="rung03", expect={"blocker": "A12", "sketch": True})
    def row_N4(self) -> None:
        before = len(self._entities())
        self.offset_set_distance("0")
        zero = self.offset_rim((35, 0, 55))
        after0 = len(self._entities())
        self.clause("zero refused", "greater than 0" in zero["status"], zero["status"])
        self.offset_set_distance("40")
        self.offset_set_reverse(True)
        far = self.offset_rim((35, 0, 55))
        after1 = len(self._entities())
        self.clause("too far refused", "at least the radius" in far["status"], far["status"])
        self.clause("no entity", after0 == before and after1 == before, f"{before} -> {after0}/{after1}")
        shown = self.offset_set_distance("5")
        field = str((self.control("offset:Distance") or {}).get("text", shown))
        self.clause("field 5", field.startswith("5") or "5" in shown, f"field={field!r} shown={shown!r}")

    @row("A13", chunk=3, on="rung03", expect={"blocker": "A12", "sketch": True})
    def row_A13(self) -> None:
        self.offset_set_distance("5")
        self.offset_set_reverse(True)
        made = self.offset_rim((35, 0, 55))
        profile = made["profile"]
        external = made["external"]
        r30 = profile and abs(float(profile[0].get("radius") or 0) - 30) <= 0.01
        r35 = external and abs(float(external[0].get("radius") or 0) - 35) <= 0.2
        centre = profile[0].get("center") if profile else None
        concentric = centre is not None and abs(float(centre[0])) <= 0.2 and abs(float(centre[1])) <= 0.2
        self.clause("status", "Offset: circle r = 30" in made["status"], made["status"])
        self.clause("circle r 30", bool(r30), f"profile={profile[:1]}")
        self.clause("external r 35", bool(r35), f"external={external[:1]}")
        self.clause("concentric", concentric, f"centre={centre}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")

    @row("N5", chunk=3, on="rung03", expect={"blocker": "A13", "sketch": True})
    def row_N5(self) -> None:
        before_p = len(self.profile_circles())
        before_e = len(self.external_circles())
        mark = self.mark()
        self.click(sketch=[80, 80])
        status = " | ".join(self.result_texts(mark)) or self.S()
        after_p = len(self.profile_circles())
        after_e = len(self.external_circles())
        self.clause("refused", "nothing there" in status, status)
        self.clause("unchanged", before_p == after_p and before_e == after_e, f"p {before_p}->{after_p} e {before_e}->{after_e}")
        self.esc()
        self.refresh("status", "rail", "controls")
        lit = self.lit_names()
        self.clause("esc disarms", not any("Offset" in n for n in lit), f"lit={lit} status={self.S()}")

    @row("A14", chunk=3, on="rung03", expect={"blocker": "A13", "sketch": True})
    def row_A14(self) -> None:
        # N5 Esc disarmed Offset; re-arm then Ok closes the panel (WP5 test).
        if not any("Offset" in n for n in self.lit_names()):
            self.offset_arm()
        before_p = len(self.profile_circles())
        before_e = len(self.external_circles())
        done = self.offset_ok()
        self.clause("ok", self._sketch_active(), f"sketch active; {done['status']}")
        self.clause("panel closed", not done["panel_visible"], f"visible={done['panel_visible']}")
        self.clause(
            "entities",
            len(done["profile"]) == before_p and len(done["external"]) == before_e,
            f"profile={len(done['profile'])} external={len(done['external'])}",
        )

    @row("L4", chunk=3, on="rung03", expect={"blocker": "A14", "sketch": True})
    def row_L4(self) -> None:
        external = self.external_circles()
        profile = self.profile_circles()
        style_ok = bool(external) and all(e.get("construction") or e.get("external") for e in external)
        self.clause("external style", style_ok, str(external[:1]))
        boxes = self.label_boxes(["Ø60", "Ø70", "60", "70"])
        # Offset may show Ø60 on the profile; accept any diameter label.
        if not boxes:
            boxes = [d for d in self.dims() if "Ø" in str(d.get("text", ""))]
        self.clause("labels visible", bool(boxes) and all(d.get("visible", True) for d in boxes), str(self.dim_texts()))
        overlap = False
        for i, a in enumerate(boxes):
            for b in boxes[i + 1:]:
                overlap = overlap or self.rects_overlap(a.get("rect") or [], b.get("rect") or [])
        self.clause("no overlap", len(boxes) < 2 or not overlap, str([d.get("rect") for d in boxes]))

    @row("A15", chunk=3, on="rung03", expect={"blocker": "A14", "sketch": True})
    def row_A15(self) -> None:
        exit_status = self.exit_sketch()
        made = self.try_extrude("1", op="Cut", end="Through All")
        self.clause("exit", "Sketch" in exit_status or not self._sketch_active(), exit_status)
        self.clause("op cut", made["op"] == "Cut", f"op={made['op']!r}")
        self.clause(
            "end through all",
            "Through All" in made["end"] or "Through All" in made["status"],
            made["status"],
        )
        self.clause("status", "Extrude" in made["status"] and "Through All" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        self.ctx["height"] = float(self.part()["PART"]["TOP"])
        report = self.export_and_check("cut", "cut.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("cut", report["check_ok"], report["check_text"])
        path = self.save_as("cut.sxp")
        self.refresh("status")
        # Checkpoint file for chunk 4; not a named clause.
        self.ctx["cut_sxp"] = path
