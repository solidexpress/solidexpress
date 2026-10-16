"""Rung-5 chunk 2: +Z flange, circular pattern, cut.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows05Chunk2:
    @row("A8", chunk=2, on="rung05", expect={"blocker": "A7", "part": True, "min_bodies": 1})
    def row_A8(self) -> None:
        opened = self.face_sketch("flange")
        selected = opened["selected"]
        plane = opened["plane"]
        origin = plane.get("origin") or [0, 0, 0]
        normal = plane.get("normal") or [0, 0, 0]
        z250 = selected.get("plane")
        is_z250 = z250 is not None and abs(float(z250) - 250.0) <= 0.2
        self.clause("face selected", bool(selected.get("face")), selected.get("status", ""))
        self.clause("is z250", is_z250, f"plane={z250}")
        self.clause("sketch on face", opened["active"], opened["status"])
        origin_ok = (
            abs(float(origin[0])) < 0.2
            and abs(float(origin[1])) < 0.2
            and abs(float(origin[2]) - 250) < 0.2
        )
        self.clause("origin", origin_ok and abs(float(normal[2]) - 1) < 1e-3, f"origin={origin} n={normal}")

    @row("A9", chunk=2, on="rung05", expect={"blocker": "A8", "sketch": True})
    def row_A9(self) -> None:
        fd = self.mm("FLANGE_D")
        ft = f"{self.mm('FLANGE_T'):g}"
        made = self.draw_circle((0.0, 0.0), (fd * 0.5, 0.0))
        dimmed = self.dimension_diameter(f"{fd:g}")
        circles = made["circles"] or self.profile_circles()
        radius = float(circles[0].get("radius") or 0) if circles else 0.0
        self.exit_sketch()
        extruded = self.try_extrude(ft, op="Fuse")
        zext = self.z_extent()
        self.clause(
            "diameter 225",
            abs(radius * 2 - fd) <= 0.2 or self.label_has("Ø225"),
            f"r={radius} {dimmed['texts']}",
        )
        self.clause("op fuse", extruded["op"] == "Fuse" or "Fuse" in extruded["status"], f"op={extruded['op']!r}")
        self.clause("one body", len(extruded["bodies"]) == 1, str(extruded["bodies"]))
        z_ok = zext is not None and abs(zext[1] - 260) <= 0.2
        self.clause("z 260", z_ok, f"z={zext}")

    @row("A10", chunk=2, on="rung05", expect={"blocker": "A9", "part": True, "min_bodies": 1})
    def row_A10(self) -> None:
        opened = self.face_sketch("cut")
        selected = opened["selected"]
        plane = opened["plane"]
        origin = plane.get("origin") or [0, 0, 0]
        z260 = selected.get("plane")
        is_z260 = z260 is not None and abs(float(z260) - 260.0) <= 0.2
        self.clause("face selected", bool(selected.get("face")), selected.get("status", ""))
        self.clause("is z260", is_z260, f"plane={z260}")
        origin_ok = abs(float(origin[2]) - 260) < 0.2 if origin else False
        self.clause("sketch on face", opened["active"] and origin_ok, f"{opened['status']} origin={origin}")

    @row("A11", chunk=2, on="rung05", expect={"blocker": "A10", "sketch": True})
    def row_A11(self) -> None:
        inner = self.mm("ID")
        made = self.draw_circle((0.0, 0.0), (inner * 0.5, 0.0))
        dimmed = self.dimension_diameter(f"{inner:g}")
        circles = made["circles"] or self.profile_circles()
        centre = circles[0].get("center") if circles else None
        radius = float(circles[0].get("radius") or 0) if circles else 0.0
        self.clause(
            "diameter 130",
            abs(radius * 2 - inner) <= 0.2 or self.label_has("Ø130"),
            f"r={radius} {dimmed['texts']}",
        )
        centred = centre is not None and abs(float(centre[0])) <= 0.2 and abs(float(centre[1])) <= 0.2
        self.clause("centre origin", centred, f"centre={centre}")

    @row("A12", chunk=2, on="rung05", expect={"blocker": "A11", "sketch": True})
    def row_A12(self) -> None:
        pcd = self.mm("PCD")
        hole = self.mm("HOLE_D")
        made = self.draw_circle((0.0, pcd), (0.0, pcd + hole * 0.5))
        dimmed = self.dimension_diameter(f"{hole:g}", centre=(0.0, pcd))
        dist = self.dimension_centres((0.0, 0.0), (0.0, pcd), f"{pcd:g}")
        vert = self.vertical_centres((0.0, 0.0), (0.0, pcd))
        holes = self.hole_ring()
        seed = holes[0]["center"] if holes else (made["circles"][-1]["center"] if made["circles"] else None)
        self.clause(
            "diameter 10",
            self.label_has("Ø10") or (holes and abs(float(holes[0].get("radius") or 0) * 2 - hole) <= 0.2),
            f"{dimmed['texts']}",
        )
        self.clause("distance 94", self.label_has("94") or "94" in str(dist["texts"]), str(dist["texts"]))
        self.clause("vertical", "Vertical" in vert["status"], vert["status"])
        on_y = seed is not None and abs(float(seed[0])) <= 0.2 and abs(float(seed[1]) - pcd) <= 0.2
        self.clause("on +Y", on_y, f"seed={seed}")

    @row("L2", chunk=2, on="rung05", expect={"blocker": "A12", "sketch": True})
    def row_L2(self) -> None:
        boxes = self.label_boxes(["Ø130", "Ø10", "94"])
        visible = bool(boxes) and all(b.get("visible", True) for b in boxes)
        self.clause("labels visible", visible, str([b.get("text") for b in boxes]))
        origin = self.d.project(sketch=[0, 0]).get("screen") or [0, 0]
        piled = False
        for box in boxes:
            rect = box.get("rect") or []
            if len(rect) >= 4 and abs(rect[0] + rect[2] * 0.5 - float(origin[0])) < 8:
                if abs(rect[1] + rect[3] * 0.5 - float(origin[1])) < 8:
                    piled = True
        overlap = False
        rects = [b.get("rect") or [] for b in boxes]
        for i, a in enumerate(rects):
            for b in rects[i + 1:]:
                if self.rects_overlap(a, b):
                    overlap = True
        self.clause("no overlap", not piled and not overlap, f"piled={piled} overlap={overlap}")

    @row("A13", chunk=2, on="rung05", expect={"blocker": "A12", "sketch": True})
    def row_A13(self) -> None:
        self.select_seed()
        armed = self.arm_circular_pattern()
        made = self.pattern_ok("8", "360")
        holes = made["holes"]
        pcd = self.mm("PCD")
        on_pitch = all(
            abs((float(h["center"][0]) ** 2 + float(h["center"][1]) ** 2) ** 0.5 - pcd) <= 0.2
            for h in holes
        )
        self.clause(
            "variant circular",
            armed["pressed"] or "circular" in armed["status"].lower() or bool(armed["count"]),
            armed["status"],
        )
        self.clause("count 8", "8" in str(made["count"]) or len(holes) == 8, f"count={made['count']!r}")
        self.clause("eight circles", len(holes) == 8, f"n={len(holes)}")
        self.clause("pitch 94", on_pitch and len(holes) == 8, f"n={len(holes)}")

    @row("L3", chunk=2, on="rung05", expect={"blocker": "A13", "sketch": True})
    def row_L3(self) -> None:
        holes = self.hole_ring()
        pcd = self.mm("PCD")
        top = any(
            abs(float(h["center"][0])) <= 0.2 and abs(float(h["center"][1]) - pcd) <= 0.2
            for h in holes
        )
        layout = self.construction_circles()
        profile_layout = [
            c for c in self.profile_circles()
            if abs(float(c.get("radius") or 0) - pcd) <= 1.0
        ]
        self.clause("eight visible", len(holes) == 8, f"n={len(holes)}")
        self.clause("top hole", top, str([h.get("center") for h in holes[:3]]))
        self.clause("layout construction", bool(layout) and not profile_layout, f"layout={len(layout)} fat={len(profile_layout)}")

    @row("N3", chunk=2, on="rung05", expect={"blocker": "A13", "sketch": True})
    def row_N3(self) -> None:
        before = len(self.hole_ring())
        self.select_seed()
        self.arm_circular_pattern()
        made = self.pattern_ok("1", "360")
        refused = "at least 2" in made["status"] or "count" in made["status"].lower()
        self.clause("refused", refused, made["status"])
        self.clause("no extra", len(self.hole_ring()) == before, f"{before} -> {len(self.hole_ring())}")
        self.esc()
        panel = self.control("pattern:Count")
        hidden = not panel or panel.get("visible") is False
        field = made["field"] or str((panel or {}).get("text", ""))
        self.clause("esc", hidden, f"count={panel}")
        self.clause("field 8", str(field).startswith("8") or "8" in str(field), f"field={field!r}")

    @row("A14", chunk=2, on="rung05", expect={"blocker": "A13", "sketch": True})
    def row_A14(self) -> None:
        ft = f"{self.mm('FLANGE_T'):g}"
        status = self.exit_sketch()
        made = self.try_extrude(ft, op="Cut")
        zext = self.z_extent()
        self.clause("exit", not bool((self.refresh("sketch").get("sketch") or {}).get("active")), status)
        self.clause("op cut", made["op"] == "Cut" or "Cut" in made["status"], f"op={made['op']!r}")
        self.clause("blind 10", "Blind" in made["status"] and "10" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        length = zext is not None and abs(zext[1] - zext[0] - 260) <= 0.2
        self.clause("length 260", length, f"z={zext}")

    @row("A15", chunk=2, on="rung05", expect={"blocker": "A14", "part": True, "min_bodies": 1})
    def row_A15(self) -> None:
        report = self.stage_report("cut")
        self.clause("exported", report["exported"], "cut.3mf")
        self.clause("cut", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")

    @row("A16", chunk=2, on="rung05", expect={"blocker": "A15"})
    def row_A16(self) -> None:
        path = self.save_as("cut.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
