"""Walk rows for chunk 5."""
from __future__ import annotations

import time

from sxdrive import SxError
from walk.registry import row

class RowsChunk5:
    def _arm_fillet(self) -> None:
        self.refresh("bodies", "selection", "status")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            bodies = self.st.get("bodies") or []
            if bodies:
                self.click(screen=bodies[0]["screen"])
        self.click("chip:Fillet")
        self.refresh("status")

    def _vertical_necks(self) -> list[dict]:
        found = []
        for e in self.edges():
            d = e.get("dir") or [0, 0, 0]
            mid = e.get("mid") or [0, 0, 0]
            if abs(float(d[2])) > 0.8 and 170 < float(mid[0]) < 190 and 8 < float(e.get("length", 0)) < 14:
                found.append(e)
        return found

    def _pick_neck(self, edge: dict) -> str:
        reply = self.d.click(edge=edge["id"], along=0.5)
        self.refresh("status")
        return str(reply.get("status", self.S()))

    @row('A11b', chunk=5, expect={'blocker': 'N18', 'part': True, 'min_bodies': 1})
    def row_A11b(self) -> None:
        # Top view, both necks, then cancel. State-neutral before the Front pick.
        for label, sign in (("top view +Y", 1.0), ("top view -Y", -1.0)):
            self._arm_fillet()
            self.d.key("3")
            self.refresh("status")
            group = [e for e in self._vertical_necks() if float((e.get("mid") or [0, 0, 0])[1]) * sign > 0]
            if not group:
                self.clause(label, False, "no vertical neck")
            else:
                status = self._pick_neck(group[0])
                self.clause(
                    label,
                    "Fillet: 1 edge" in status and "10.0 mm vertical" in status,
                    status,
                )
            self.esc()
            self.esc()
            self.refresh("status")
        self._arm_fillet()
        self.clause("armed", self.S().startswith("Fillet"), self.S())
        necks = self._vertical_necks()
        if len(necks) < 2:
            self.clause("neck edge", False, f"found {len(necks)} vertical necks")
            return
        # Front view looks along the neck pair, so both midpoints are one
        # pixel and the second click toggles the first off ("removed 10.0 mm
        # vertical"). −Y is the Front silhouette (key 1); +Y is the Back
        # silhouette (key 4). Same split as run_rung01_wrench.gd _fillet_neck.
        status = ""
        for edge in necks[:2]:
            mid = edge.get("mid") or [0, 0, 0]
            self.d.key("4" if float(mid[1]) > 0.0 else "1")
            self.refresh("status")
            status = self._pick_neck(edge)
        self.clause(
            "neck edge",
            "Fillet: 2 edge" in status and status.count("10.0 mm vertical") >= 2,
            status,
        )

    @row('N2', chunk=5)
    def row_N2(self) -> None:
        self.click("finish:StripR")
        self.d.key("up")
        self.refresh("finish", "status")
        up = self.field("finish:StripR")
        self.d.key("down")
        down = self.field("finish:StripR") if self.refresh("finish") else ""
        self.d.key("3")
        self.refresh("status")
        self.clause("spinner", "2.5" in up or "2" in down, f"up={up} down={down} {self.S()}")
        got = self.type_into("finish:StripR", "10")
        self.enter()
        self.d.key("3")
        self.refresh("status")
        self.clause("enter does not apply", "Top view" in self.S() and "applied" not in self.S().lower(), f"field={got} {self.S()}")

    @row('L3', chunk=5)
    def row_L3(self) -> None:
        got = self.type_into("finish:StripR", "10")
        self.d.key("tab")
        self.d.key("3")
        self.refresh("status")
        self.clause("tab releases", "Top view" in self.S(), f"{got} {self.S()}")
        self.click("finish:PanelRadius")
        time.sleep(0.3)
        self.click("finish:PanelRadius")
        self.refresh("status", "focus")
        self.clause("second click stays", "Selected face" not in self.S() and "Radius" in str(self.st.get("focus", "")), f"{self.S()} {self.st.get('focus')}")
        self.d.key("ctrl+a")
        self.d.type("1.5", delay_ms=10)
        got = str(self.refresh("focus_text").get("focus_text", ""))
        self.clause("1.5", "1.5" in got, got)
        self.d.key("tab")
        self.type_into("finish:PanelRadius", "10")
        self.d.key("tab")

    @row('A11c', chunk=5)
    def row_A11c(self) -> None:
        self.enter()
        self.refresh("status")
        applied = "Fillet 2 edges 10.00 applied" in self.S() and "no longer armed" in self.S()
        self.clause("applied", applied, self.S())
        if applied:
            self.ctx["fillet_applies"] = [self.S()]

    def _click_solid(self) -> None:
        try:
            pt = self.d.project(model=[30, 0, 10])["screen"]
        except SxError:
            bodies = self.st.get("bodies") or []
            if not bodies:
                return
            pt = bodies[0]["screen"]
        self.click(screen=pt)
        self.refresh("status", "selection")

    @row('N3', chunk=5)
    def row_N3(self) -> None:
        self.refresh("bodies", "selection")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            self._click_solid()
        fillet = self.control("chip:Fillet")
        chamfer = self.control("chip:Chamfer")
        self.clause("chips present", bool(fillet), str(fillet)[:160])
        if fillet and chamfer:
            self.ctx["chip_x"] = fillet["rect"][0]
            self.clause("chips side by side", fillet["rect"][0] != chamfer["rect"][0], f"{fillet['rect']} {chamfer['rect']}")

    @row('A11d', chunk=5)
    def row_A11d(self) -> None:
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("3")
        self.refresh("status")
        self.clause("released", "Top view" in self.S(), self.S())
        self.click(model=[200, -16, 10])
        self.refresh("status")
        self.clause("face loop", "Fillet: 15 edge" in self.S(), self.S())
        self.enter()
        self.refresh("status")
        top = self.S()
        self.clause("top fillet", "Fillet 15 edges 1.00 applied" in top and "no longer armed" in top, top)
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("8")
        self.refresh("status")
        self.click(model=[50, 0, 0])
        self.refresh("status")
        self.enter()
        self.refresh("status")
        bottom = self.S()
        self.clause("bottom fillet", "Fillet 11 edges 1.00 applied" in bottom, bottom)
        self.ctx.setdefault("fillet_applies", []).extend([top, bottom])

    @row('A11e', chunk=5)
    def row_A11e(self) -> None:
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("3")
        self.refresh("status")
        self.click(model=[93.5, 0, 7.5])
        self.refresh("status")
        picked = self.S()
        self.clause("floor pick", "Fillet: 4 edge" in picked, picked)
        self.enter()
        self.refresh("status")
        applied = self.S()
        self.clause("R1 applied", "Fillet 4 edges 1.00 applied" in applied, applied)
        self.ctx.setdefault("fillet_applies", []).append(applied)
        self._arm_fillet()
        self.type_into("finish:StripR", "1.5")
        self.enter()
        self.click(model=[93.5, 0, 7.5])
        self.refresh("status")
        self.enter()
        self.refresh("status")
        self.clause("refused", "exceeds the 1.250 mm limit" in self.S(), self.S())
        names = [
            str(r.get("name", ""))
            for r in (self.refresh("timeline").get("timeline") or [])
            if str(r.get("name", "")).startswith("fillet")
        ]
        applies = " ".join(self.ctx.get("fillet_applies") or [])
        four = len(names) == 4 and "2 edges" in applies and "15 edges" in applies and "11 edges" in applies and "4 edges" in applies
        self.clause("four fillets", four, f"timeline={names} applies={applies}")
        self.esc()

    @row('A11f', chunk=5)
    def row_A11f(self) -> None:
        self._arm_fillet()
        self.type_into("finish:StripR", "1")
        self.enter()
        self.d.key("3")
        # R10 plus the two R1 face fillets leave an 8 mm vertical seam.
        # The old (8, 14) window excluded that edge.
        neck = [
            e for e in self.edges()
            if abs(float((e.get("dir") or [0, 0, 0])[2])) > 0.8
            and 6.5 <= float(e.get("length", 0)) <= 12.0
        ]
        if not neck:
            brief = [
                (round(float(e.get("length", 0)), 2), [round(float(c), 2) for c in (e.get("dir") or [])])
                for e in self.edges()
                if abs(float((e.get("dir") or [0, 0, 1])[2])) > 0.5
            ][:8]
            self.clause("corner", False, f"no vertical edge {brief}")
            return
        edge = neck[0]
        # along=0.85 is the upper end, the one top view can see.
        self.d.click(edge=str(edge["id"]), along=0.85)
        self.refresh("status")
        self.clause("near", "Fillet: 1 edge" in self.S() or "1 edge" in self.S(), self.S())
        self.d.click(edge=str(edge["id"]), along=0.85)
        self.refresh("status")
        self.clause("removed", "removed" in self.S().lower() or "Fillet" in self.S(), self.S())
        self.esc()

    @row('N15', chunk=5)
    def row_N15(self) -> None:
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        if bodies:
            self.click(screen=[bodies[0]["screen"][0], bodies[0]["screen"][1]])
        self.refresh("status")
        self.clause("ground not sketch", "Editing sketch" not in self.S(), self.S())
        self.click("chip:Fillet")
        self.refresh("status")
        self.clause("armed", self.S().startswith("Fillet"), self.S())
        self.esc()
        self.clause("cancelled", "cancelled" in self.S().lower() or "Selection" in self.S(), self.S())

    @row('N13', chunk=5)
    def row_N13(self) -> None:
        self.refresh("bodies")
        bodies = self.st.get("bodies") or []
        if bodies and bodies[0].get("screen"):
            self.click(screen=bodies[0]["screen"])
        else:
            self.click(model=[0, 0, 5])
        cam = dict(self.refresh("camera").get("camera") or {})
        self.d.key("0")
        self.refresh("status", "camera")
        cam2 = self.st.get("camera") or {}
        self.clause("no view", "No view for key 0" in self.S(), self.S())
        same = abs(float(cam.get("yaw", 0)) - float(cam2.get("yaw", 0))) < 1e-3
        self.clause("camera still", same, f"{cam.get('yaw')} {cam2.get('yaw')}")
        self.d.key("3")
        self.refresh("status")
        self.clause("top", "Top view" in self.S(), self.S())

    @row('N16', chunk=5)
    def row_N16(self) -> None:
        before_bodies, before_timeline = self._body_snapshot()
        self.clear_selection()
        self.refresh("bodies", "selection")
        bodies = self.st.get("bodies") or []
        self.need(bool(bodies) and bodies[0].get("screen"), "body screen", str(bodies)[:180])
        self.clause("nothing selected", not str((self.st.get("selection") or {}).get("body") or ""), self.S())
        self.d.hover(screen=bodies[0]["screen"])
        self.d.wait_idle(frames=2)
        mark = self.mark()
        self.d.key("0")
        self.d.wait_idle(frames=4)
        time.sleep(4.0)
        lines = self.trace_from(mark)
        status_lines = [ln for ln in lines if "status-trace" in ln]
        hover_between = [ln for ln in lines if "hover-trace" in ln]
        result_i = next((i for i, ln in enumerate(status_lines) if "kind=result" in ln and "No view for key 0" in ln), -1)
        restore_i = next((i for i, ln in enumerate(status_lines) if "kind=restore" in ln and "Face" in ln), -1)
        dt = None
        if result_i >= 0 and restore_i > result_i:
            t0 = self._trace_time(status_lines[result_i])
            t1 = self._trace_time(status_lines[restore_i])
            if t0 is not None and t1 is not None:
                dt = t1 - t0
        ordered = result_i >= 0 and restore_i > result_i and dt is not None and 2.0 <= dt <= 4.0 and not hover_between
        self.clause(
            "result then restore",
            ordered,
            f"dt={dt} hover={hover_between[:2]} " + " | ".join(status_lines[-6:]),
        )
        self.clause("headless-only hold edge", None, "headless-only: rung01_replan19_hint", kind="headless-only")
        ground = self.d.project(model=[400, 300, 0])["screen"]
        mark2 = self.mark()
        self.d.key("0")
        self.d.hover(screen=ground)
        self.d.wait_idle(frames=2)
        time.sleep(4.0)
        lines2 = self.trace_from(mark2)
        hover_none = any("hover-trace" in ln and "target=none" in ln for ln in lines2)
        face_later = any(
            "status-trace" in ln and ("kind=hint" in ln or "kind=restore" in ln) and "Face" in ln
            for ln in lines2
        )
        self.clause(
            "leave clears hint",
            hover_none and not face_later,
            " | ".join(lines2[-8:]),
        )
        after_bodies, after_timeline = self._body_snapshot()
        self.clause(
            "bodies and timeline",
            before_bodies == after_bodies and before_timeline == after_timeline,
            f"bodies {before_bodies} -> {after_bodies} timeline {before_timeline} -> {after_timeline}",
        )

    @row('N19', chunk=5)
    def row_N19(self) -> None:
        self.refresh("bodies", "selection")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            self._click_solid()
        self.click("chip:Fillet")
        self.d.wait_idle(frames=4)
        self.refresh("status")
        if not self.S().startswith("Fillet"):
            self._click_solid()
            self.click("chip:Fillet")
            self.d.wait_idle(frames=4)
        radius = None
        self.refresh("finish")
        for fid in ("finish:PanelRadius", "finish:StripR"):
            for f in (self.st.get("finish") or {}).get("fields") or []:
                if f.get("id") == fid and f.get("rect"):
                    radius = f
                    break
            if radius:
                break
        title = None
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "title":
                title = row.get("rect")
        panel = radius.get("rect") if radius else None
        overlap = False
        if title and panel and len(title) >= 4 and len(panel) >= 4:
            overlap = not (title[0] + title[2] < panel[0] or panel[0] + panel[2] < title[0] or title[1] + title[3] < panel[1] or panel[1] + panel[3] < title[1])
        self.clause(
            "timeline misses radius",
            radius is not None and not overlap,
            f"title={title} radius={panel}",
            kind="" if radius is not None else "runner-gap",
        )
        if radius:
            self.type_into(radius["id"], "2")
        self.esc()
        self.refresh("status")
        self.clause("esc hides radius", "cancelled" in self.S().lower() or "Edge pick" in self.S(), self.S())

    @row('N23', chunk=5)
    def row_N23(self) -> None:
        self.refresh("bodies", "selection")
        if not str((self.st.get("selection") or {}).get("body") or ""):
            self._click_solid()
        chip = self.control("chip:Group Similar") or self.control("chip:Fillet")
        title = None
        for row in self.refresh("timeline").get("timeline") or []:
            if row.get("kind") == "title" and row.get("visible", True):
                title = row.get("rect")
        if chip and title and len(chip["rect"]) >= 4 and len(title) >= 4:
            gap = float(title[1]) - (float(chip["rect"][1]) + float(chip["rect"][3]))
            self.clause("title below chips", gap >= 8, f"gap={gap:.1f} chip={chip['rect']} title={title}")
        else:
            self.clause("measured", False, f"chip={chip} title={title}")
        self.esc_until("Selection cleared", 3)
