"""Rung-5 chunk 3: feature mirror, re-shell, reshell.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows05Chunk3:
    @row("N4", chunk=3, on="rung05", expect={"blocker": "A16", "part": True, "min_bodies": 1})
    def row_N4(self) -> None:
        before_names = self.feature_names()
        before_bodies = list(self.refresh("bodies").get("bodies") or [])
        self.arm_feature_mirror()
        self.pick_face("mirror")
        made = self.mirror_ok()
        refused = "feature" in made["status"].lower() or "pick" in made["status"].lower()
        zext = self.z_extent()
        length_ok = zext is not None and abs(zext[1] - zext[0] - 260) <= 0.2
        self.clause("refused", refused, made["status"])
        self.clause("one body", len(made["bodies"]) == 1 and len(before_bodies) == 1, str(made["bodies"]))
        self.clause(
            "timeline unchanged",
            made["names"] == before_names and length_ok,
            f"{before_names} -> {made['names']} z={zext}",
        )
        self.esc()

    @row("A17", chunk=3, on="rung05", expect={"blocker": "A16", "part": True, "min_bodies": 1})
    def row_A17(self) -> None:
        self.arm_feature_mirror()
        plane = self.pick_face("mirror")
        names = self.mirror_source_names()
        self.shift_click_timeline(names)
        made = self.mirror_ok()
        z0 = plane.get("plane")
        plane_ok = z0 is not None and abs(float(z0)) <= 0.2
        self.clause("plane z0", plane_ok and bool(plane.get("face")), f"plane={z0} {plane.get('status')}")
        self.clause("four features", len(names) == 4, str(names))
        self.clause("status", "Mirror" in made["status"] or "Mirrored" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))
        self.clause(
            "not body mode",
            len(made["bodies"]) == 1 and ("Mirrored feature" in made["status"] or "Mirror" in made["status"]),
            made["status"],
        )

    @row("A18", chunk=3, on="rung05", expect={"blocker": "A17", "part": True, "min_bodies": 1})
    def row_A18(self) -> None:
        report = self.stage_report("mirror")
        half_ok, half_line = self.check_probe(report["text"], "solidHalf")
        box_ok, box_line = self.check_probe(report["text"], "bbox")
        self.clause("exported", report["exported"], "mirror.3mf")
        self.clause("mirror", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")
        self.clause("solid half", half_ok, half_line)
        self.clause("bbox", box_ok, box_line)

    @row("L4", chunk=3, on="rung05", expect={"blocker": "A17"})
    def row_L4(self) -> None:
        names = self.feature_names()
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        bodies = list(self.refresh("bodies").get("bodies") or [])
        has_mirror = "mirror" in types
        order_ok = types.count("sketch") >= 2 and types.count("extrude") >= 3 and "shell" in types and has_mirror
        self.clause("order", order_ok, str(types))
        self.clause("names distinct", len(names) == len(set(names)) and all("…" not in n for n in names), str(names))
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A19", chunk=3, on="rung05", expect={"blocker": "A17", "part": True, "min_bodies": 1})
    def row_A19(self) -> None:
        before = self.feature_names()
        self.select_body()
        selected = self.pick_face("reshell")
        made = self.apply_shell("10")
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        shell_after = "mirror" in types and "shell" in types and types.rindex("shell") > types.index("mirror")
        self.clause("face selected", bool(selected.get("face")), selected.get("status", ""))
        self.clause(
            "thickness 10",
            made["shown"].startswith("10") or "10" in made["status"],
            f"shown={made['shown']!r}",
        )
        self.clause("status", "Shell 10" in made["status"] or "10.0000" in made["status"], made["status"])
        self.clause("order", shell_after or len(made["names"]) > len(before), f"{types} {made['names']}")

    @row("A20", chunk=3, on="rung05", expect={"blocker": "A19", "part": True, "min_bodies": 1})
    def row_A20(self) -> None:
        report = self.stage_report("reshell")
        wall_ok, wall_line = self.check_probe(report["text"], "wall")
        self.clause("exported", report["exported"], "reshell.3mf")
        self.clause(
            "reshell",
            report["check_ok"],
            report["text"].strip().splitlines()[-1] if report["text"].strip() else "",
        )
        self.clause("walls 10", wall_ok, wall_line)

    @row("A21", chunk=3, on="rung05", expect={"blocker": "A20"})
    def row_A21(self) -> None:
        path = self.save_as("reshell.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
