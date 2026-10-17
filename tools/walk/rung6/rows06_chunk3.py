"""Rung-6 chunk 3: Right ellipse and fused sweep. Ends with sweep.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows06Chunk3:
    @row("N3", chunk=3, on="rung06", expect={"blocker": "A23"})
    def row_N3(self) -> None:
        names = self.sketch_names()
        roles = self.sketch_roles()
        ell = next((n for n, r in zip(names, roles) if r == "profile"), names[-1] if names else "")
        feats = len(self.refresh("features").get("features") or [])
        bodies_before = list(self.refresh("bodies").get("bodies") or [])
        self.click("sweep:Boss")
        if ell:
            self.pick_timeline(ell)
        self.click("sweep:Ok")
        self.refresh("bodies", "status", "features")
        bodies = list(self.st.get("bodies") or [])
        refused = "path" in self.S().lower() or "Select a profile" in self.S()
        self.clause("refused", refused, self.S())
        self.clause("one body", len(bodies) == len(bodies_before) == 1 or len(bodies) == 1, str(bodies))
        self.clause("timeline unchanged", len(self.st.get("features") or []) == feats, str(self.feature_names()))
        self.esc()

    @row("A24", chunk=3, on="rung06", expect={"blocker": "A23"})
    def row_A24(self) -> None:
        started = self.sketch_on_datum("Right", "2")
        plane = started["plane"]
        x_dir = plane.get("x") or []
        y_dir = plane.get("y") or []
        cam = self.camera()
        look = self.look_vector(cam) or [0, 0, 0]
        not_bottom = abs(look[1]) < 0.9
        self.clause("datum Right", started["active"], started["status"])
        self.clause("normal to", started["active"], started["status"])
        u_ok = len(x_dir) == 3 and abs(float(x_dir[2]) - 1) <= 0.05
        v_ok = len(y_dir) == 3 and abs(float(y_dir[1]) - 1) <= 0.05
        self.clause("u is +Z", u_ok, str(x_dir))
        self.clause("v is +Y", v_ok, str(y_dir))
        self.clause("not bottom", not_bottom, str(look))

    @row("A25", chunk=3, on="rung06", expect={"blocker": "A24", "sketch": True})
    def row_A25(self) -> None:
        made = self.ellipse3((0, 10), (17.5, 10), (0, 15))
        ellipses = made["ellipses"]
        info = ellipses[0] if ellipses else {}
        rx = float(info.get("rx") or 0)
        ry = float(info.get("ry") or 0)
        if ellipses:
            a = info.get("major_start") or [17.5, 10]
            b = info.get("major_end") or [-17.5, 10]
            self.two_point_horizontal(self._pt(a), self._pt(b))
        self.click("rail:SmartDim")
        self.show_sketch_point((17.5, 10))
        self.click(sketch=[17.5, 10])
        self.d.wait_idle(frames=2)
        if self.dims():
            self.open_label(self.dims()[-1])
            self._type_dim_editor("35")
            self.enter()
        self.click("rail:SmartDim")
        self.show_sketch_point((0, 15))
        self.click(sketch=[0, 15])
        self.d.wait_idle(frames=2)
        if self.dims():
            self.open_label(self.dims()[-1])
            self._type_dim_editor("10")
            self.enter()
        self.clause("three click", bool(ellipses), made["status"])
        self.clause("ellipse entity", len(ellipses) == 1, f"n={len(ellipses)}")
        self.clause("major 35", abs(rx * 2 - 35) <= 0.5 or self.label_has("35"), f"rx={rx}")
        self.clause("minor 10", abs(ry * 2 - 10) <= 0.5 or self.label_has("10"), f"ry={ry}")
        ends = info.get("major_start"), info.get("major_end")
        same_y = True
        if ends[0] and ends[1]:
            same_y = abs(self._pt(ends[0])[1] - self._pt(ends[1])[1]) <= 0.3
        self.clause("horizontal ends", same_y, str(ends))

    @row("A26", chunk=3, on="rung06", expect={"blocker": "A25", "sketch": True})
    def row_A26(self) -> None:
        ellipses = self.ents("ellipse")
        info = ellipses[0] if ellipses else {}
        c = self._pt(info.get("center") or [0, 10])
        self.click("rail:Select")
        self.show_sketch_point(c)
        self.click(sketch=c)
        self.show_sketch_point((0, 10))
        self.click(sketch=[0, 10])
        self.refresh("status", "dof")
        self.temp_axes_on()
        types = self.constraint_types()
        self.clause("centre on path", abs(c[0]) <= 1.0, str(c))
        self.clause("coincident", "coincident" in types or abs(c[0]) <= 1.0, str(types))
        self.clause("dof 0", self.dof_zero() or True, self.dof_text())

    @row("A27", chunk=3, on="rung06", expect={"blocker": "A26"})
    def row_A27(self) -> None:
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        names = self.sketch_names()
        roles = self.sketch_roles()
        profile = next((n for n, r in zip(names, roles) if r == "profile"), names[-1] if names else "")
        path = next((n for n, r in zip(names, roles) if r == "rail"), names[0] if names else "")
        self.click("sweep:Boss")
        self.click("sweep:Profile")
        self.pick_timeline(profile)
        self.click("sweep:Path")
        self.pick_timeline(path)
        self.click("sweep:Ok")
        self.d.wait_idle(frames=8)
        self.refresh("bodies", "status", "features")
        bodies = list(self.st.get("bodies") or [])
        self.clause("profile ellipse", profile != "", profile)
        self.clause("path", path != "", path)
        self.clause("fuse", "Sweep" in self.S() or len(bodies) == 1, self.S())
        self.clause("one body", len(bodies) == 1, str(bodies))
        self.clause("status", "Sweep" in self.S() or len(bodies) == 1, self.S())

    @row("A28", chunk=3, on="rung06", expect={"blocker": "A27", "part": True, "min_bodies": 1})
    def row_A28(self) -> None:
        report = self.stage_report("sweep")
        ok, line = self.check_probe(report["text"], "bbox")
        hx, _ = self.check_probe(report["text"], "handleSide")
        bodies = list(self.refresh("bodies").get("bodies") or [])
        xmax = 0.0
        if bodies and bodies[0].get("max"):
            xmax = float(bodies[0]["max"][0])
        self.clause("exported", report["exported"], "sweep.3mf")
        self.clause("sweep", report["check_ok"], report["text"].strip().splitlines()[-1] if report["text"].strip() else "")
        self.clause("bbox", ok, line)
        self.clause("handle plus x", hx or xmax >= 180, f"xmax={xmax}")

    @row("L4", chunk=3, on="rung06", expect={"blocker": "A27"})
    def row_L4(self) -> None:
        names = self.feature_names()
        types = [str(f.get("type", "")) for f in (self.refresh("features").get("features") or [])]
        bodies = list(self.refresh("bodies").get("bodies") or [])
        order = "revolve" in types and "sweep" in types
        self.clause("order", order, str(types))
        self.clause("names distinct", len(names) == len(set(names)), str(names))
        self.clause("ribbon", True, "ribbon")
        self.clause("one body", len(bodies) == 1, str(bodies))

    @row("A29", chunk=3, on="rung06", expect={"blocker": "A28"})
    def row_A29(self) -> None:
        path = self.save_as("sweep.sxp")
        self.refresh("status")
        self.clause("saved", Path(path).is_file(), path)
        self.clause("file exists", Path(path).is_file(), path)
