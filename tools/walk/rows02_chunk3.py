"""Rung-2 chunk 3: shell the top face, wall 5."""
from __future__ import annotations

from walk.registry import row


class Rows02Chunk3:
    @row("A10", chunk=3, on="rung02", expect={"blocker": "A9", "part": True, "min_bodies": 1})
    def row_A10(self) -> None:
        selected = self.select_face([0, 0, 1])
        self.clause("face selected", bool(selected["face"]), f"face={selected['face']} {selected['status']}")
        chip = self.shell_chip()
        self.clause("chip present", chip is not None, str((chip or {}).get("rect")))

    @row("L4", chunk=3, on="rung02", expect={"blocker": "A10", "part": True})
    def row_L4(self) -> None:
        size = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        chip = self.shell_chip() or {}
        rect = chip.get("rect") or []
        self.clause("inside", self.node_inside(chip, size), f"rect={rect} window={size}")
        self.clause("label", str(chip.get("text", "")) == "Shell", str(chip.get("text")))
        self.clause("not covered", bool(rect) and not self.covered(rect), f"rect={rect}")
        wheel = self.wheel_over("strip:shell")
        self.clause("wheel", not wheel["moved"], f"distance {wheel['before'].get('distance')} -> {wheel['after'].get('distance')}")

    @row("N6", chunk=3, on="rung02", expect={"blocker": "A10", "part": True})
    def row_N6(self) -> None:
        self.clear_faces()
        self.clause("no chip", self.shell_chip() is None, f"face={(self.st.get('selection') or {}).get('face')}")
        before = self.feature_names()
        self.select_face([1, 0, 0])
        offered = self.shell_chip() is not None
        self.esc()
        after = self.feature_names()
        self.clause("esc nothing added", offered and before == after, f"offered={offered} {before} -> {after}")

    @row("N7", chunk=3, on="rung02", expect={"blocker": "A10", "part": True, "min_bodies": 1})
    def row_N7(self) -> None:
        before = self.feature_names()
        size = self.body_size()
        self.select_face([0, 0, 1])
        tried = self.apply_shell("30")
        self.clause(
            "refused",
            "Shell thickness 30.0000 mm is at least half the 50.0000 mm extent (limit) — nothing added" in tried["status"],
            tried["status"],
        )
        self.clause("unchanged", tried["names"] == before and self.body_size() == size, f"{tried['names']} size={self.body_size()}")
        field = tried["field"] or str((self.control("finish:Thickness") or {}).get("text", ""))
        self.clause("field 5", field.startswith("5"), f"field={field!r}")

    @row("A11", chunk=3, on="rung02", expect={"blocker": "A10", "part": True, "min_bodies": 1})
    def row_A11(self) -> None:
        self.select_face([0, 0, 1])
        chip = self.shell_chip()
        self.clause("panel", chip is not None, str((chip or {}).get("id")))
        made = self.apply_shell("5")
        self.clause("thickness 5", made["shown"].startswith("5") or "5" in made["status"], f"shown={made['shown']!r} {made['status']}")
        self.clause("status", "Shell 5.0000 mm applied" in made["status"], made["status"])
        self.clause("feature", any(n.startswith("Shell") for n in made["names"]), str(made["names"]))
        size = self.body_size()
        ok = size is not None and abs(size[0] - 100) <= 0.1 and abs(size[1] - self.width()) <= 0.1 and abs(size[2] - 50) <= 0.1
        self.clause("bbox", ok, f"size={size}")

    @row("A12", chunk=3, on="rung02", expect={"blocker": "A11", "part": True, "min_bodies": 1})
    def row_A12(self) -> None:
        report = self.export_and_check("shell", "shelled.3mf")
        self.clause("S0", report["s0"], report["s0_evidence"], kind="" if report["s0"] else "runner-gap")
        self.clause("shell", report["check_ok"], report["check_text"])
        saved = self.save_part("shelled.sxp")
        self.clause("saved", saved["exists"] and "Saved" in saved["status"], saved["status"])
