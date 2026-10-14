"""Rung-3 chunk 2: Ø70 boss fused 25 mm above the base."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


def _axis(got, want) -> bool:
    if not got:
        return False
    return all(abs(float(got[i]) - want[i]) < 1e-3 for i in range(3))


class Rows03Chunk2:
    @row("A6", chunk=2, on="rung03", expect={"blocker": "A5", "part": True, "min_bodies": 1})
    def row_A6(self) -> None:
        opened = self.face_sketch([0, 0, 1], plane=30.0, view_key="3")
        selected = opened["selected"]
        plane = opened["plane"]
        origin = plane.get("origin") or [0, 0, 0]
        normal = plane.get("normal") or [0, 0, 0]
        axis_x = plane.get("x") or [0, 0, 0]
        axis_y = plane.get("y") or [0, 0, 0]
        z30 = selected.get("plane")
        is_z30 = z30 is not None and abs(float(z30) - 30.0) <= 0.2
        self.clause("face selected", bool(selected["face"]), selected["status"])
        self.clause("is z30", is_z30, f"plane={z30}")
        self.clause("sketch on face", opened["active"], opened["status"])
        self.clause("normal", abs(float(normal[2]) - 1) < 1e-3, str(normal))
        self.clause(
            "origin",
            abs(float(origin[0])) < 0.2 and abs(float(origin[1])) < 0.2 and abs(float(origin[2]) - 30) < 0.2,
            str(origin),
        )
        self.clause("basis", _axis(axis_x, (1, 0, 0)) and _axis(axis_y, (0, 1, 0)), f"x={axis_x} y={axis_y}")
        self.ctx["camera_at_sketch"] = opened["camera"]

    @row("L2", chunk=2, on="rung03", expect={"blocker": "A6", "sketch": True})
    def row_L2(self) -> None:
        framed = self.fit_sketch()
        self.clause("framed", "Sketch view fit" in framed or "Framed" in framed, framed or self.S())
        size = self.window_size()
        corners = ((-60, -60, 30), (60, -60, 30), (-60, 60, 30), (60, 60, 30))
        notes = []
        inside = True
        for model in corners:
            screen = self.project_model(model)
            hit = 0 <= float(screen[0]) <= float(size[0]) and 0 <= float(screen[1]) <= float(size[1])
            inside = inside and hit
            notes.append(str(screen))
        self.clause("outline inside", inside, "; ".join(notes))
        cam = self.camera()
        # Top view after face sketch ("Normal To").
        look = self.look_vector(cam)
        top = look is not None and look[2] < -0.9
        self.clause("view top", top or "Top" in self.S(), f"look={look} {self.S()}")

    @row("A7", chunk=2, on="rung03", expect={"blocker": "A6", "sketch": True})
    def row_A7(self) -> None:
        made = self.draw_circle((0, 0), (35, 0))
        circles = made["circles"]
        self.clause("circle", "Circle" in made["status"] or len(circles) == 1, made["status"])
        self.clause("one circle", len(circles) == 1, f"circles={len(circles)}")
        centre = circles[0].get("center") if circles else None
        ok = centre is not None and abs(float(centre[0])) <= 0.2 and abs(float(centre[1])) <= 0.2
        self.clause("centre origin", ok, f"centre={centre}")

    @row("A8", chunk=2, on="rung03", expect={"blocker": "A7", "sketch": True, "min_circles": 1})
    def row_A8(self) -> None:
        made = self.dimension_diameter("70")
        self.clause("label Ø70", self.label_has("Ø70"), str(made["texts"]))
        circles = self.profile_circles()
        radius = float(circles[0].get("radius") or 0) if circles else 0.0
        self.clause("diameter 70", abs(radius * 2 - 70) <= 0.2 or self.label_has("Ø70"), f"r={radius}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")

    @row("N3", chunk=2, on="rung03", expect={"blocker": "A8", "sketch": True})
    def row_N3(self) -> None:
        before = self.profile_circles()
        r0 = float(before[0].get("radius") or 0) if before else 0.0
        zero = self.refuse_dim("Ø70", "0") if self.label_has("Ø70") else self.refuse_dim("70", "0")
        after = self.profile_circles()
        r1 = float(after[0].get("radius") or 0) if after else 0.0
        self.clause("zero refused", "positive number" in zero["results"], zero["results"])
        self.clause("unchanged", abs(r1 - 35) <= 0.2 or abs(r1 - r0) <= 0.01, f"r {r0} -> {r1}")
        esc = self.esc_editor()
        self.clause("esc", esc["opened"] and not esc["editor"], f"opened={esc['opened']} editor={esc['editor']}")

    @row("A9", chunk=2, on="rung03", expect={"blocker": "A8", "sketch": True, "min_circles": 1})
    def row_A9(self) -> None:
        exit_status = self.exit_sketch()
        trimetric = self.view_key("7")
        made = self.try_extrude("25", op="Fuse")
        self.clause("exit", "Sketch" in exit_status or not self._sketch_active(), exit_status)
        self.clause("trimetric", "Isometric view" in trimetric, trimetric)
        # Re-read op from the finish bar after extrude.
        self.clause("op fuse", made["op"] == "Fuse" or "Fuse" in made["status"], f"op={made['op']!r}")
        self.clause("status", "Extrude Blind 25.0000 mm" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        self.ctx["height"] = float(self.part()["PART"]["TOP"])
        report = self.export_and_check("boss", "boss.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("boss", report["check_ok"], report["check_text"])

    @row("A10", chunk=2, on="rung03", expect={"blocker": "A9", "part": True, "min_bodies": 1})
    def row_A10(self) -> None:
        path = self.save_as("boss.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
