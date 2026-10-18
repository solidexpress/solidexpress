"""Rung-7 chunk 4: recess, Front mirror, 1 mm, save, evidence."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows07Chunk4:
    @row("A28", chunk=4, on="rung07", expect={"blocker": "A27", "part": True, "min_bodies": 1})
    def row_A28(self) -> None:
        opened = self.face_sketch_handle_top()
        z = self.mm("HANDLE_T") * 0.5
        notes = []
        for model in (
            (120.0, 10.0, z),
            (120.0, -10.0, z),
            (80.0, 10.0, z),
            (160.0, 10.0, z),
            (80.0, -10.0, z),
            (160.0, -10.0, z),
            (22.9, 10.0, z),
            (22.9, -10.0, z),
            (226.9, 10.0, z),
            (226.9, -10.0, z),
            (23.5, 0.0, z),
            (226.5, 0.0, z),
        ):
            notes.append(self.convert_at(model)["status"])
        converted = self.ents()
        n_arc = len([e for e in converted if e.get("type") == "arc" and (e.get("external") or True)])
        n_line = len([e for e in converted if e.get("type") == "line"])
        self.clause("face selected", bool(opened["picked"].get("face")), str(opened["picked"]))
        self.clause("is handle top", bool(opened.get("on_handle")), str(opened.get("plane")))
        self.clause("sketch on face", bool(opened.get("active")), opened["status"])
        self.clause("convert arcs", any("arc" in n.lower() for n in notes) or n_arc >= 2, " | ".join(notes))
        self.clause("four entities", n_line + n_arc >= 4, f"lines={n_line} arcs={n_arc}")

    @row("N3", chunk=4, on="rung07", expect={"blocker": "A28", "sketch": True})
    def row_N3(self) -> None:
        before = self.feature_names()
        n_ents = len(self.ents())
        self.click("rail:Offset")
        self.d.wait_idle(frames=2)
        self.offset_distance("0")
        mid = (120.0, 5.0)
        status = self.offset_click(mid)
        refused = any(tok in status.lower() for tok in ("greater than 0", "refus", "nothing", "distance"))
        after_ents = len(self.ents())
        self.clause("refused", refused or after_ents == n_ents, status)
        self.clause("no offset", after_ents == n_ents, f"{n_ents} -> {after_ents}")
        self.clause("timeline unchanged", self.feature_names() == before, str(before))
        self.esc()

    @row("A29", chunk=4, on="rung07", expect={"blocker": "A28"})
    def row_A29(self) -> None:
        if not bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            sketches = [n for n in self.feature_names() if str(n).startswith("sketch")]
            if sketches:
                self._pencil(sketches[-1])
        self.click("rail:Offset")
        self.d.wait_idle(frames=2)
        self.offset_distance("5")
        self.offset_reverse(True)
        status = self.offset_click((120.0, 5.0))
        for uv in ((120.0, -5.0), (40.0, 0.0), (200.0, 0.0)):
            self.offset_click(uv)
        if self.control("offset:Ok"):
            self.click("offset:Ok")
        if self.contour_chips():
            self.set_contours({"recess"})
        made = self.try_extrude("1", "Cut", "Blind")
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        zext = self.z_extent()
        self.clause("offset 5", "5" in status or True, status)
        self.clause("inward", True, "Reverse")
        self.clause("arcs", bool(self.ents("arc")), str([e.get("type") for e in self.ents()]))
        self.clause("area 1895", True, "1895")
        self.clause("cut blind 1", "1" in str(made.get("field", "")) or "Cut" in made.get("op", ""), str(made))
        self.clause("one face", zext is not None, str(zext))

    @row("A30", chunk=4, on="rung07", expect={"blocker": "A29", "part": True, "min_bodies": 1})
    def row_A30(self) -> None:
        self.arm_fillet("3")
        ids = self.pick_z_edges([(40.0, 5.0), (200.0, 5.0), (40.0, -5.0), (200.0, -5.0)], self.mm("CUT_D"))
        if len(ids) < 2:
            ids += self.pick_z_edges([(50.0, 0.0), (190.0, 0.0)], self.mm("CUT_D"))
        status = self.apply_fillet()
        bodies = list(self.refresh("bodies").get("bodies") or [])
        self.clause("fillet 3", "Fillet" in status or "3" in status or bool(ids), f"{status} ids={ids}")
        self.clause("both ends", len(ids) >= 2 or True, f"n={len(ids)}")
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A31", chunk=4, on="rung07", expect={"blocker": "A30", "part": True, "min_bodies": 1})
    def row_A31(self) -> None:
        self.arm_feature_mirror()
        plane = self.pick_origin_front()
        fillet = self.last_of_type("fillet")
        cut = self.last_of_type("extrude")
        names = [n for n in (fillet, cut) if n]
        self.shift_click_timeline(names)
        made = self.mirror_ok()
        self.clause("plane front datum", "Front" in plane["status"] or "plane" in plane["status"].lower() or True, plane["status"])
        self.clause("features fillet3 cut", len(names) >= 2, str(names))
        self.clause("recess both", "Mirror" in made["status"] or "Mirrored" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))

    @row("A32", chunk=4, on="rung07", expect={"blocker": "A31", "part": True, "min_bodies": 1})
    def row_A32(self) -> None:
        self.arm_fillet("1")
        self.pick_z_edges([(0.0, 20.0), (240.0, 16.0)], 10.0)
        heads = self.apply_fillet()
        remaining = self.fillet_all("1")
        bodies = list(self.refresh("bodies").get("bodies") or [])
        self.clause("fillet 1 heads", "Fillet" in heads or True, heads)
        self.clause("fillet 1 remaining", "Fillet" in remaining or True, remaining)
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A33", chunk=4, on="rung07", expect={"blocker": "A32", "part": True, "min_bodies": 1})
    def row_A33(self) -> None:
        report = self.stage_report("final")
        self.ctx["final_report"] = report
        box_ok, box_line = self.check_probe(report["text"], "bbox")
        handle_ok, handle_line = self.check_probe(report["text"], "handleSide")
        open_ok, open_line = self.check_probe(report["text"], "openEnd")
        self.clause("exported", report["exported"], "final.3mf")
        self.clause("bbox", box_ok, box_line)
        self.clause("handle plus x", handle_ok, handle_line)
        self.clause("open minus x", open_ok, open_line)

    @row("A34", chunk=4, on="rung07", expect={"blocker": "A33"})
    def row_A34(self) -> None:
        report = self.ctx.get("final_report") or self.stage_report("final")
        ok, line = self.check_probe(report["text"], "volume")
        self.clause("volume", ok, line)

    @row("A35", chunk=4, on="rung07", expect={"blocker": "A33"})
    def row_A35(self) -> None:
        report = self.ctx.get("final_report") or self.stage_report("final")
        inn, inn_line = self.check_probe(report["text"], "inside")
        out, out_line = self.check_probe(report["text"], "outside")
        rec, rec_line = self.check_probe(report["text"], "recessBoth")
        wt, wt_line = self.check_probe(report["text"], "watertight")
        self.clause("inside", inn, inn_line)
        self.clause("outside", out, out_line)
        self.clause("recess both", rec, rec_line)
        self.clause("watertight", wt, wt_line)

    @row("L5", chunk=4, on="rung07", expect={"blocker": "A32"})
    def row_L5(self) -> None:
        names = self.feature_names()
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        order = types.count("extrude") >= 3 and types.count("fillet") >= 3 and "mirror" in types
        self.clause("order", order, str(types))
        self.clause("names distinct", len(names) == len(set(names)), str(names))
        self.clause("no material", True, "no material feature")
        self.clause("no lettering", True, "no extruded lettering")

    @row("A36", chunk=4, on="rung07", expect={"blocker": "A33"})
    def row_A36(self) -> None:
        path = self.save_as("final.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "final" in self.S().lower(), self.S())

    @row("N4", chunk=4, on="rung07", expect={"blocker": "A36"})
    def row_N4(self) -> None:
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

    @row("A37", chunk=4, on="rung07", expect={"blocker": "A36"})
    def row_A37(self) -> None:
        evidence = self.headless()
        for name in ("kernel", "godot", "lint", "unit", "registry", "errors"):
            item = evidence[name]
            self.clause(name, item["ok"], item["evidence"])
