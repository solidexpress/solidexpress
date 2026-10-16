"""Rung-5 chunk 1: Front Ø150 × 250, two-face shell, shelled.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row
from walk.rung5.ui05 import PINNED_NEW


class Rows05Chunk1:
    @row("N1", chunk=1, on="rung05")
    def row_N1(self) -> None:
        chrome = self.chrome_nodes()
        size = chrome["size"]
        win = chrome["window"]
        wide = float(size[0]) >= 1272 and float(size[1]) >= 750
        self.clause("window", wide or bool(win.get("maximized")), f"window {size} maximized={win.get('maximized')}")
        notes = []
        inside = True
        for label in ("status", "menu", "rail"):
            node = chrome[label]
            if not self.node_inside(node, size):
                inside = False
                notes.append(f"{label} missing" if not node else f"{label} {node.get('rect')}")
            else:
                notes.append(f"{label} {node.get('rect')}")
        self.clause("chrome inside", inside, "; ".join(notes))

    @row("A1", chunk=1, on="rung05")
    def row_A1(self) -> None:
        status = self.new_part()
        self.refresh("status", "units", "popups")
        units = str(self.st.get("units", ""))
        self.clause("new", status.strip() == PINNED_NEW, status)
        self.clause("units mmgs", units == "mmgs", units)

    @row("A2", chunk=1, on="rung05", expect={"blocker": "A1"})
    def row_A2(self) -> None:
        started = self.sketch_on_datum("Front", "1")
        od = self.mm("OD")
        made = self.draw_circle((0.0, 0.0), (od * 0.5, 0.0))
        dimmed = self.dimension_diameter(f"{od:g}")
        circles = made["circles"] or self.profile_circles()
        centre = circles[0].get("center") if circles else None
        radius = float(circles[0].get("radius") or 0) if circles else 0.0
        self.clause("datum Front", started["active"], started["status"])
        self.clause("sketch", started["active"], started["status"])
        self.clause(
            "diameter 150",
            abs(radius * 2 - od) <= 0.2 or self.label_has("Ø150"),
            f"r={radius} {dimmed['texts']}",
        )
        centred = centre is not None and abs(float(centre[0])) <= 0.2 and abs(float(centre[1])) <= 0.2
        self.clause("centre origin", centred, f"centre={centre}")
        self.clause("dof 0", self.dof_zero(), f"dof={self.dof_text()!r}")

    @row("L1", chunk=1, on="rung05", expect={"blocker": "A2", "sketch": True})
    def row_L1(self) -> None:
        size = self.window_size()
        want = {"Circle", "Smart Dim", "Pattern"}
        nodes = []
        for control in (self.refresh("controls").get("controls") or []):
            if str(control.get("text", "")) in want:
                nodes.append(control)
        texts = {str(n.get("text", "")) for n in nodes}
        clipped = [n.get("text") for n in nodes if not self.node_inside(n, size)]
        self.clause("rail labels", want <= texts, f"have={sorted(texts)}")
        names = {str(d.get("name", "")) for d in (self.refresh("datums").get("datums") or [])}
        self.clause("plane names", {"Front", "Top", "Right"} <= names, str(sorted(names)))
        self.clause("not clipped", not clipped, f"clipped={clipped}")

    @row("A3", chunk=1, on="rung05", expect={"blocker": "A2", "sketch": True})
    def row_A3(self) -> None:
        l0 = f"{self.mm('L0'):g}"
        status = self.exit_sketch()
        made = self.try_extrude(l0, op="New")
        self.clause("exit", not bool((self.refresh("sketch").get("sketch") or {}).get("active")), status)
        self.clause("extrude", "Extrude" in made["status"] or made["op"] == "New", made["status"])
        self.clause("status", "Blind" in made["status"] and "250" in made["status"], made["status"])
        self.clause("one body", len(made["bodies"]) == 1, str(made["bodies"]))

    @row("A4", chunk=1, on="rung05", expect={"blocker": "A3", "part": True, "min_bodies": 1})
    def row_A4(self) -> None:
        report = self.stage_report("cyl")
        self.clause("exported", report["exported"], "cyl.3mf")
        self.clause("cyl", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")

    @row("A5", chunk=1, on="rung05", expect={"blocker": "A4", "part": True, "min_bodies": 1})
    def row_A5(self) -> None:
        before = self.feature_names()
        made = self.shell_both_ends("10")
        shells = [n for n in made["names"] if str(n).lower().startswith("shell")]
        added = [n for n in made["names"] if n not in before]
        self.clause("two faces", len(made.get("faces") or []) >= 2, str(made.get("faces")))
        self.clause(
            "thickness 10",
            made["shown"].startswith("10") or "10" in made["status"],
            f"shown={made['shown']!r}",
        )
        self.clause("status", "Shell 10" in made["status"] or "10.0000" in made["status"], made["status"])
        self.clause("one feature", len(shells) == 1 or (len(added) == 1 and "shell" in added[0].lower()), str(made["names"]))

    @row("N2", chunk=1, on="rung05", expect={"blocker": "A5", "part": True, "min_bodies": 1})
    def row_N2(self) -> None:
        tried = self.refuse_shell("80")
        refused = "limit" in tried["status"].lower() or "nothing added" in tried["status"].lower()
        self.clause("refused", refused, tried["status"])
        self.clause(
            "unchanged",
            tried["after"] == tried["before"] or len(tried["after"]) == len(tried["before"]),
            f"{tried['before']} -> {tried['after']}",
        )
        field = tried["field"]
        self.clause("field 10", str(field).startswith("10") or "10" in str(field), f"field={field!r}")

    @row("A6", chunk=1, on="rung05", expect={"blocker": "A5", "part": True, "min_bodies": 1})
    def row_A6(self) -> None:
        report = self.stage_report("shelled")
        self.clause("exported", report["exported"], "shelled.3mf")
        self.clause(
            "shelled",
            report["check_ok"],
            report["text"].strip().splitlines()[-1] if report["text"].strip() else "",
        )

    @row("A7", chunk=1, on="rung05", expect={"blocker": "A6"})
    def row_A7(self) -> None:
        path = self.save_as("shelled.sxp")
        self.refresh("status")
        self.clause("saved", "Saved" in self.S() or Path(path).is_file(), self.S())
        self.clause("file exists", Path(path).is_file(), path)
        self.clause("title", "shelled" in self.S(), self.S())
