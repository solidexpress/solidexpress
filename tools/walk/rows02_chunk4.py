"""Rung-2 chunk 4: the Ø10 hole on the +X face."""
from __future__ import annotations

from walk.registry import row


class Rows02Chunk4:
    @row("A13", chunk=4, on="rung02", expect={"blocker": "A12", "part": True, "min_bodies": 1})
    def row_A13(self) -> None:
        selected = self.select_face([1, 0, 0])
        view = self.view_key("2")
        look = self.look_vector(self.camera())
        self.clause("face selected", bool(selected["face"]), selected["status"])
        self.clause("right view", "Right view" in view or "Right view" in self.S(), view or self.S())
        aimed = look is not None and look[0] < -0.9
        self.clause("camera dir", aimed, f"look={look}")

    @row("A14", chunk=4, on="rung02", expect={"blocker": "A13", "part": True, "min_bodies": 1})
    def row_A14(self) -> None:
        opened = self.open_face_sketch([1, 0, 0], "2")
        plane = opened["plane"]
        axis_x = plane.get("x") or [0, 0, 0]
        axis_y = plane.get("y") or [0, 0, 0]
        normal = plane.get("normal") or [0, 0, 0]
        self.clause("sketch on face", opened["active"], opened["status"])
        self.clause("normal", abs(float(normal[0]) - 1) < 1e-3, str(normal))
        self.clause("basis x", _axis(axis_x, (0, 1, 0)), str(axis_x))
        self.clause("basis y", _axis(axis_y, (0, 0, 1)), str(axis_y))
        self.ctx["face_plane"] = plane
        self.ctx["camera_at_sketch"] = opened["camera"]

    @row("L5", chunk=4, on="rung02", expect={"blocker": "A14", "sketch": True})
    def row_L5(self) -> None:
        framed = self.fit_sketch()
        self.clause("framed", "Sketch view fit" in framed or "Framed" in framed, framed or self.S())
        width = self.width()
        corners = ((100, 10, 0), (100, width - 10, 0), (100, 10, 50), (100, width - 10, 50))
        size = self.window_size()
        notes = []
        inside = True
        for model in corners:
            screen = self.project_model(model)
            hit = 0 <= float(screen[0]) <= float(size[0]) and 0 <= float(screen[1]) <= float(size[1])
            inside = inside and hit
            notes.append(str(screen))
        self.clause("outline inside", inside, "; ".join(notes))
        camera = self.camera()
        before = self.ctx.get("camera_at_sketch") or {}
        kept = abs(float(camera.get("yaw", 0)) - float(before.get("yaw", 0))) < 0.05
        self.clause("camera kept", kept, f"yaw {before.get('yaw')} -> {camera.get('yaw')}")

    @row("A15", chunk=4, on="rung02", expect={"blocker": "A14", "sketch": True})
    def row_A15(self) -> None:
        made = self.draw_circle((35, 40), (45, 40))
        self.clause("circle", "Circle" in made["status"] or len(made["circles"]) == 1, made["status"])
        self.clause("one circle", len(made["circles"]) == 1, f"circles={len(made['circles'])}")

    @row("A16", chunk=4, on="rung02", expect={"blocker": "A15", "sketch": True, "min_circles": 1})
    def row_A16(self) -> None:
        left = self.convert_edge([100, 10, 25])
        bottom = self.convert_edge([100, 30, 0])
        lines = self.external_lines()
        self.clause("left edge", "external line" in left["status"], left["status"])
        self.clause("bottom edge", "external line" in bottom["status"], bottom["status"])
        self.clause("two externals", len(lines) >= 2, f"externals={len(lines)}")
        self.clause("construction", all(ln.get("construction") or ln.get("external") for ln in lines), str(lines)[:240])

    @row("N8", chunk=4, on="rung02", expect={"blocker": "A16", "sketch": True})
    def row_N8(self) -> None:
        before = len(self.external_lines())
        # Right view is orthographic along X, so the far face (x=0) projects
        # onto this face. The off-face edge is the fillet's y=0 tangent
        # (x=90), far enough from the face edge at y=10 that the 8 mm search
        # does not grab that boundary.
        refused = self.convert_edge([90, 0, 25])
        after = len(self.external_lines())
        self.clause("refused", "not on this face" in refused["status"], refused["status"])
        self.clause("no new external", after == before, f"{before} -> {after}")
        self.esc()
        self.refresh("status")
        tool = str((self.st.get("tool") or {}).get("name", self.S()))
        self.clause("esc", "Convert" not in tool and not self.S().startswith("Convert"), f"{tool} {self.S()}")

    @row("A17", chunk=4, on="rung02", expect={"blocker": "A16", "sketch": True, "min_circles": 1})
    def row_A17(self) -> None:
        made = self.dimension_diameter("10")
        self.clause("label", self.label_has("Ø10") or any("Ø" in t for t in made["texts"]), str(made["texts"]))
        self.clause("diameter 10", self.label_has("Ø10"), str(made["texts"]))

    @row("A18", chunk=4, on="rung02", expect={"blocker": "A17", "sketch": True, "min_circles": 1})
    def row_A18(self) -> None:
        circles = self.sketch_circles()
        centre = circles[0]["center"] if circles else [35, 40]
        mid = self.external_mid("left") or [10, 25]
        made = self.dim_between(centre, mid, "25")
        world = self.circle_world()
        self.clause("label 25", self.label_has("25"), str(made["texts"]))
        y = None if world is None else world[1]
        self.clause("centre y 35", y is not None and abs(y - 35) <= 0.01, f"world={world}")

    @row("A19", chunk=4, on="rung02", expect={"blocker": "A18", "sketch": True})
    def row_A19(self) -> None:
        circles = self.sketch_circles()
        centre = circles[0]["center"] if circles else [35, 40]
        mid = self.external_mid("bottom") or [30, 0]
        made = self.dim_between(centre, mid, "40")
        world = self.circle_world()
        self.clause("label 40", self.label_has("40"), str(made["texts"]))
        z = None if world is None else world[2]
        self.clause("centre z 40", z is not None and abs(z - 40) <= 0.01, f"world={world}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")

    @row("L6", chunk=4, on="rung02", expect={"blocker": "A19", "sketch": True, "dim_has": "40"})
    def row_L6(self) -> None:
        boxes = self.label_boxes(["Ø10", "25", "40"])
        self.clause("visible", len(boxes) >= 3 and all(d.get("visible", True) for d in boxes), str(self.dim_texts()))
        self.clause("not occluded", all(not d.get("occluded") for d in boxes), str([d.get("occluded") for d in boxes]))
        overlap = False
        for i, a in enumerate(boxes):
            for b in boxes[i + 1:]:
                overlap = overlap or self.rects_overlap(a.get("rect") or [], b.get("rect") or [])
        self.clause("no overlap", len(boxes) >= 3 and not overlap, str([d.get("rect") for d in boxes]))
        outline = _screen_box(self, ((100, 10, 0), (100, self.width() - 10, 50)))
        outside = all(_outside(d.get("rect") or [], outline) for d in boxes)
        self.clause("outside outline", outside and bool(boxes), f"outline={outline}")

    @row("N9", chunk=4, on="rung02", expect={"blocker": "A19", "sketch": True, "dim_has": "25"})
    def row_N9(self) -> None:
        undo0 = list(self.refresh("undo").get("undo") or [])
        self.edit_label_to("25", "26")
        y1 = (self.circle_world() or [0, 0, 0])[1]
        self.clause("moved 36", abs(y1 - 36) <= 0.05, f"y={y1}")
        self.edit_label_to("26", "25")
        y2 = (self.circle_world() or [0, 0, 0])[1]
        self.clause("back 35", abs(y2 - 35) <= 0.01, f"y={y2}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")
        undo1 = list(self.refresh("undo").get("undo") or [])
        self.clause("undo balanced", len(undo1) == len(undo0) + 2, f"{len(undo0)} -> {len(undo1)}")

    @row("A20", chunk=4, on="rung02", expect={"blocker": "A19", "sketch": True})
    def row_A20(self) -> None:
        status = self.exit_sketch()
        names = self.feature_names()
        self.clause("exit", "Sketch" in status or not self._sketch_active(), status)
        self.clause("part mode", not self._sketch_active(), status)
        self.clause("timeline", sum(1 for n in names if n.startswith("sketch")) >= 2, str(names))

    @row("N10", chunk=4, on="rung02", expect={"blocker": "A20", "part": True})
    def row_N10(self) -> None:
        before = self.feature_names()
        armed = self.try_extrude("3", op="Cut", end="Blind", apply=False)
        self.clause("blind selected", "Blind" in armed["end"], f"end={armed['end']!r}")
        self.clause("nothing applied", self.feature_names() == before, str(self.feature_names()))
        end = self.set_end("Through All")
        self.clause("end through all", "Through All" in end, end)
        # A21 starts in part mode. The finish bar is the sketch session's,
        # so this row leaves the way A20 did.
        self.exit_sketch()

    @row("A21", chunk=4, on="rung02", expect={"blocker": "A20", "part": True, "min_bodies": 1})
    def row_A21(self) -> None:
        before = self.feature_names()
        made = self.try_extrude("50", op="Cut", end="Through All")
        names = self.feature_names()
        added = [n for n in names if n not in before]
        self.clause("op cut", made["op"] == "Cut", f"op={made['op']!r}")
        self.clause("end through all", "Through All" in made["end"] or "Through All" in made["status"], made["status"])
        self.clause("applied", "Extrude" in made["status"] and "Through All" in made["status"], made["status"])
        self.clause("feature", len(added) == 1 and added[0].startswith("extrude"), str(added))
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        report = self.export_and_check("final", "final-60.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("final", report["check_ok"], report["check_text"])
        saved = self.save_part("final.sxp")
        self.clause("saved", saved["exists"] and "Saved" in saved["status"], saved["status"])
        self.ctx["final60_volume"] = report.get("volume")


def _axis(got, want) -> bool:
    if not got:
        return False
    return all(abs(float(got[i]) - want[i]) < 1e-3 for i in range(3))


def _left_external(lines: list[dict]) -> dict | None:
    best = None
    best_x = 1e9
    for line in lines:
        start, end = line.get("start"), line.get("end")
        if not start or not end:
            continue
        mid = (float(start[0]) + float(end[0])) * 0.5
        if mid < best_x:
            best, best_x = line, mid
    return best


def _bottom_external(lines: list[dict]) -> dict | None:
    best = None
    best_y = 1e9
    for line in lines:
        start, end = line.get("start"), line.get("end")
        if not start or not end:
            continue
        mid = (float(start[1]) + float(end[1])) * 0.5
        if mid < best_y:
            best, best_y = line, mid
    return best


def _screen_box(walk, models) -> list[float] | None:
    xs, ys = [], []
    for model in models:
        screen = walk.d.project(model=list(model))["screen"]
        xs.append(float(screen[0]))
        ys.append(float(screen[1]))
    if not xs:
        return None
    return [min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)]


def _outside(rect, outline) -> bool:
    if len(rect) < 4 or not outline:
        return False
    cx, cy = rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.5
    return not (outline[0] <= cx <= outline[0] + outline[2] and outline[1] <= cy <= outline[1] + outline[3])
