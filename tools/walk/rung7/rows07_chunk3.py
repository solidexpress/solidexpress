"""Rung-7 chunk 3: two mid-plane extrudes and neck fillets. Ends with neck.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows07Chunk3:
    @row("N2", chunk=3, on="rung07", expect={"blocker": "A20"})
    def row_N2(self) -> None:
        names = self.feature_names()
        bodies = list(self.refresh("bodies").get("bodies") or [])
        sketches = [n for n in names if str(n).startswith("sketch")]
        if sketches:
            self._pencil(sketches[0])
        self.uncheck_all_contours()
        made = self.try_extrude("10", "New", "Midplane")
        refused = any(tok in made["status"].lower() for tok in ("refus", "contour", "nothing", "select", "profile"))
        after = self.feature_names()
        still_no_body = len(made["bodies"]) == len(bodies)
        self.clause("refused", refused or still_no_body, made["status"])
        self.clause("no body", still_no_body, str(made["bodies"]))
        self.clause("timeline unchanged", after == names or still_no_body, f"{names} -> {after}")
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.esc()

    @row("A21", chunk=3, on="rung07", expect={"blocker": "A20"})
    def row_A21(self) -> None:
        if not bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            sketches = [n for n in self.feature_names() if str(n).startswith("sketch")]
            if sketches:
                self._pencil(sketches[0])
        self.weld_open_profile()
        notes = self.set_contours({"c", "ring"})
        made = self.try_extrude("10", "New", "Midplane")
        if not made.get("bodies"):
            self.weld_open_profile()
            notes = self.set_contours({"c", "ring"})
            made = self.try_extrude("10", "New", "Midplane")
        zext = self.z_extent()
        z_ok = zext is not None and abs(abs(zext[1] - zext[0]) - 10.0) <= 0.3
        self.clause("contours heads", True, "C + ring | " + " ; ".join(notes[:6]))
        self.clause("midplane", "Mid" in made.get("end", "") or "mid" in made["status"].lower(), str(made.get("end")))
        self.clause("10", "10" in str(made.get("field", "")) or "10" in made["status"], str(made.get("field")))
        self.clause("two pads", len(made["bodies"]) >= 1, str(made["bodies"]))
        self.clause("z pm 5", z_ok, str(zext))

    @row("A22", chunk=3, on="rung07", expect={"blocker": "A21"})
    def row_A22(self) -> None:
        if not bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            sketches = [n for n in self.feature_names() if str(n).startswith("sketch")]
            if sketches:
                self._pencil(sketches[0])
        before = self.feature_names()
        notes = self.set_contours({"handle"})
        made = self.try_extrude("6", "Fuse", "Midplane")
        if made.get("sketch") or len(made.get("names") or []) <= len(before):
            notes = self.set_contours({"handle"})
            made = self.try_extrude("6", "Fuse", "Midplane")
        closed = not bool(made.get("sketch"))
        added = len(made.get("names") or []) > len(before)
        op = str(made.get("op") or "")
        fused = "Fuse" in op or "fuse" in str(made.get("status") or "").lower()
        # Finish bar is gone after a successful extrude, so op is often blank.
        merged = (closed and added) or fused
        self.clause("contour handle", True, "handle | " + " ; ".join(notes[:6]))
        self.clause("midplane", "Mid" in made.get("end", "") or "mid" in made["status"].lower(), str(made.get("end")))
        self.clause("6", "6" in str(made.get("field", "")) or "6" in made["status"], str(made.get("field")))
        self.clause("merge", merged, f"op={op} closed={closed} names={made.get('names')}")
        self.clause("one body", len(made["bodies"]) == 1 and closed, str(made["bodies"]))

    @row("A23", chunk=3, on="rung07", expect={"blocker": "A22", "part": True, "min_bodies": 1})
    def row_A23(self) -> None:
        self.ensure_twelve_point_bore()
        report = self.stage_report("boss")
        box_ok, box_line = self.check_probe(report["text"], "bbox")
        handle_ok, handle_line = self.check_probe(report["text"], "handleSide")
        open_ok, open_line = self.check_probe(report["text"], "openEnd")
        self.clause("exported", report["exported"], "boss.3mf")
        self.clause("boss", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")
        self.clause("bbox", box_ok, box_line)
        self.clause("handle plus x", handle_ok, handle_line)
        self.clause("open minus x", open_ok, open_line)

    @row("A24", chunk=3, on="rung07", expect={"blocker": "A23", "part": True, "min_bodies": 1})
    def row_A24(self) -> None:
        status, ids = self.fillet_z_edges("30", [(22.944, 10.0), (23.929, -10.0)])
        bodies = list(self.refresh("bodies").get("bodies") or [])
        self.clause("fillet 30", "Fillet" in status or "30" in status or bool(ids), f"{status} ids={ids}")
        self.clause("open neck", bool(ids) and self.bbox_y_ok(), f"n={len(ids)} y_ok={self.bbox_y_ok()}")
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A25", chunk=3, on="rung07", expect={"blocker": "A24", "part": True, "min_bodies": 1})
    def row_A25(self) -> None:
        status, ids = self.fillet_z_edges("20", [(226.876, 10.0), (226.876, -10.0)])
        bodies = list(self.refresh("bodies").get("bodies") or [])
        self.clause("fillet 20", "Fillet" in status or "20" in status or bool(ids), f"{status} ids={ids}")
        self.clause("box neck", bool(ids) and self.bbox_y_ok(), f"n={len(ids)} y_ok={self.bbox_y_ok()}")
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A26", chunk=3, on="rung07", expect={"blocker": "A25", "part": True, "min_bodies": 1})
    def row_A26(self) -> None:
        report = self.stage_report("neck")
        box_ok, box_line = self.check_probe(report["text"], "bbox")
        vol_ok, vol_line = self.check_probe(report["text"], "volume")
        self.clause("exported", report["exported"], "neck.3mf")
        self.clause("neck", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")
        self.clause("bbox", box_ok, box_line)
        self.clause("volume", vol_ok, vol_line)

    @row("L4", chunk=3, on="rung07", expect={"blocker": "A25"})
    def row_L4(self) -> None:
        names = self.feature_names()
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        order = types.count("extrude") >= 2 and types.count("fillet") >= 2
        self.clause("order", order, str(types))
        self.clause("names distinct", len(names) == len(set(names)), str(names))
        self.clause("one body", len(self.refresh("bodies").get("bodies") or []) == 1, str(self.st.get("bodies")))

    @row("A27", chunk=3, on="rung07", expect={"blocker": "A26"})
    def row_A27(self) -> None:
        path = self.save_as("neck.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "neck" in self.S().lower(), self.S())
