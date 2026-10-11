"""Walk rows for chunk 4."""
from __future__ import annotations

from pathlib import Path

from sxdrive import SxError
from walk.registry import row

class RowsChunk4:
    @row('A16', chunk=4, expect={'blocker': 'A9b', 'part': True, 'min_bodies': 1})
    def row_A16(self) -> None:
        mark = self.mark()
        # "Orientation" is a separator, not an item. The entries under it are the views.
        self.click("menu:View")
        self.refresh("popups")
        listed = self.popup_text()
        self.clause("orientation list", "Front" in listed and "Isometric" in listed, listed[:400])
        self.esc()
        self.click("hud:View")
        self.esc()
        lines = self.trace_from(mark)
        self.clause("hud view trace", any("HudView" in ln for ln in lines), " | ".join(lines[-6:]))
        for key, name in (("1", "Front"), ("2", "Right"), ("4", "Back"), ("6", "Left"), ("7", "Isometric"), ("8", "Bottom"), ("3", "Top")):
            self.d.key(key)
            self.refresh("status", "camera")
            self.clause(name, name.split()[0] in self.S() or name in self.S(), self.S())
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        if bodies:
            self.click(screen=bodies[0]["screen"])
            self.refresh("status")
            self.clause("jaw see-through or body", self.S().startswith("Selected ") or "nothing" in self.S().lower() or self.S() == "", self.S())

    @row('N6', chunk=4, expect={'blocker': 'A16', 'part': True})
    def row_N6(self) -> None:
        self.d.key("3")
        self.refresh("bodies", "camera")
        bodies = self.st.get("bodies") or []
        self.need(bool(bodies), "body", "no body")
        px = list(bodies[0]["screen"])
        before = self.d.project(model=[100, 0, 10])["screen"]
        self.d.wheel(1, screen=before)
        after = self.d.project(model=[100, 0, 10])["screen"]
        drift = ((after[0] - before[0]) ** 2 + (after[1] - before[1]) ** 2) ** 0.5
        self.clause("first notch", drift <= 2.5, f"{before} -> {after} drift={drift:.2f} pointer-body {px}")
        self.d.key("f")
        self.refresh("status")
        self.clause("frame", "Framed" in self.S(), self.S())

    @row('A11a', chunk=4, expect={'blocker': 'A9b', 'part': True, 'min_bodies': 1})
    def row_A11a(self) -> None:
        self.d.key("3")
        self.refresh("status", "camera")
        cam = dict(self.st.get("camera") or {})
        p0 = self.d.project(model=[0, 0, 10])["screen"]
        p1 = self.d.project(model=[200, 0, 10])["screen"]
        self.ctx["top_pose"] = {
            "target": cam.get("target"),
            "distance": cam.get("distance"),
            "yaw": cam.get("yaw"),
            "pitch": cam.get("pitch"),
            "p0": p0,
            "p1": p1,
        }
        self.clause(
            "top before slot",
            cam.get("target") is not None and "Top view" in self.S(),
            f"target={cam.get('target')} p0={p0} p1={p1} {self.S()}",
        )
        self.sketch_on_top()
        self.need("Sketch on face" in self.S(), "sketch", self.S())
        self.click("rail:Slot")
        self.type_into("finish:Radius", "5")
        self.enter()
        self.click(sketch=[18.5, 0])
        self.refresh("status", "finish", "focus_text")
        self.clause("centre 1", "Slot" in self.S(), self.S())
        shown = self.field("finish:Radius") or str(self.st.get("focus_text", ""))
        self.clause("not prefilled 5", shown.strip() not in ("5.0", "5", "0.01"), shown)
        self.d.type("150")
        self.enter()
        self.refresh("status")
        self.clause("slot typed", "150.0000" in self.S() and "R5.0000" in self.S(), self.S())

    @row('N10', chunk=4, expect={'blocker': 'A11a', 'sketch': True})
    def row_N10(self) -> None:
        self.circle([200, 0], "5")
        self.refresh("contours", "controls")
        chips = [c for c in (self.st.get("controls") or []) if str(c.get("id", "")).startswith("contour:")]
        self.clause("chips", len(chips) >= 1 or len(self.st.get("contours") or []) >= 1, str(self.st.get("contours"))[:200])
        if chips:
            self.d.hover(target=chips[0]["id"])
        tags = self.refresh("contours").get("contours") or []
        if tags:
            clearances = [float(t.get("clearance", t.get("gap", 99))) for t in tags if isinstance(t, dict)]
            self.clause("tag clearance", (not clearances) or min(clearances) >= 4 or any(t.get("leader") for t in tags), str(tags)[:300])
        else:
            self.clause("tag clearance", False, "contour tag rect was not drawn")
        self.click("rail:Select")
        self.click(sketch=[205, 0])
        self.d.key("delete")
        self.refresh("status")
        self.clause("deleted", "Deleted" in self.S(), self.S())

    @row('N18', chunk=4, expect={'blocker': 'A11a', 'sketch': True})
    def row_N18(self) -> None:
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Blind")
        got = self.type_into("finish:Distance", "2.5", burst=True)
        self.clause("2.5", got == "2.5", got)
        self.enter()
        reply = self.click("finish:Extrude", frames=10)
        self.clause("slot cut", "Extrude Blind 2.5000 mm" in str(reply.get("status", "")), str(reply.get("status", "")))
        path = self.save_as("wrench-wip.sxp")
        self.clause("saved", Path(path).exists(), self.S())
        before = self.ctx.get("top_pose") or {}
        self.d.key("3")
        self.refresh("camera", "status")
        cam = self.st.get("camera") or {}
        p0 = self.d.project(model=[0, 0, 10])["screen"]
        p1 = self.d.project(model=[200, 0, 10])["screen"]

        def near(a, b, tol: float) -> bool:
            if a is None or b is None:
                return False
            return abs(float(a) - float(b)) <= tol

        def pix(a, b) -> float:
            return ((float(a[0]) - float(b[0])) ** 2 + (float(a[1]) - float(b[1])) ** 2) ** 0.5

        pose_ok = (
            near(cam.get("distance"), before.get("distance"), 1e-3)
            and near(cam.get("yaw"), before.get("yaw"), 1e-3)
            and near(cam.get("pitch"), before.get("pitch"), 1e-3)
            and pix(p0, before.get("p0") or p0) <= 5.0
            and pix(p1, before.get("p1") or p1) <= 5.0
        )
        bt = before.get("target") or [0, 0, 0]
        ct = cam.get("target") or [0, 0, 0]
        if isinstance(bt, list) and isinstance(ct, list) and len(bt) >= 3 and len(ct) >= 3:
            pose_ok = pose_ok and all(abs(float(bt[i]) - float(ct[i])) <= 1e-3 for i in range(3))
        self.clause("top after slot", pose_ok, f"before={before} now target={ct} p0={p0} p1={p1}")
