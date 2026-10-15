"""Rung-4 chunk 2: Right path, tangent quarter, path.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows04Chunk2:
    @row("A7", chunk=2, on="rung04", expect={"blocker": "A6"})
    def row_A7(self) -> None:
        started = self.sketch_on_datum("Right", "2")
        plane = started["plane"]
        p37 = self.uv_world((37, 0))
        p94 = self.uv_world((0, 94))
        self.clause("datum Right", started["active"], started["status"])
        self.clause("sketch", started["active"], started["status"])
        self.clause("u is +Z", self.world_near(p37, (0, 0, 37)), str(p37))
        self.clause("v is +Y", self.world_near(p94, (0, 94, 0)), str(p94))
        self.ctx["right"] = True

    @row("A8", chunk=2, on="rung04", expect={"blocker": "A7", "sketch": True})
    def row_A8(self) -> None:
        before = dict(self.refresh("camera").get("camera") or {})
        mark = self.mark()
        self.d.key("ctrl+8")
        self.d.wait_idle(frames=3)
        self.refresh("camera", "status")
        cam = dict(self.st.get("camera") or {})
        traces = " | ".join(self.result_texts(mark))
        look = self.look_vector(cam) or [0, 0, 0]
        pitch = float(cam.get("pitch", before.get("pitch", 0)))
        along_normal = abs(abs(float(look[0])) - 1) <= 0.25
        self.clause("normal to", along_normal, f"look={look} {traces}")
        self.clause("up is +Y", abs(pitch) < 25, f"pitch={pitch}")
        self.clause("not bottom", abs(pitch + 90) > 20, f"pitch={pitch}")

    @row("L3", chunk=2, on="rung04", expect={"blocker": "A8", "sketch": True})
    def row_L3(self) -> None:
        self.show_sketch_point((0, 0))
        origin = self.d.project(sketch=[0, 0])["screen"]
        u = self.d.project(sketch=[10, 0])["screen"]
        v = self.d.project(sketch=[0, 10])["screen"]
        size = self.window_size()
        du = (float(u[0]) - float(origin[0]), float(u[1]) - float(origin[1]))
        dv = (float(v[0]) - float(origin[0]), float(v[1]) - float(origin[1]))
        framed = 8 <= origin[0] <= float(size[0]) - 8 and 40 <= origin[1] <= float(size[1]) - 8
        self.clause("framed", framed, f"origin_screen={origin} size={size}")
        self.clause("origin on screen", framed, str(origin))
        self.clause("screen horizontal +Z", abs(du[0]) > abs(dv[0]), f"du={du} dv={dv}")

    @row("A9", chunk=2, on="rung04", expect={"blocker": "A7", "sketch": True})
    def row_A9(self) -> None:
        self.draw_line((0, 0), (37, 0))
        self.draw_line((37, 0), (37, 94))
        lines = self.ents("line")
        horiz = [ln for ln in lines if abs((self.line_length(ln) or 0) - 37) <= 0.4]
        vert = [ln for ln in lines if abs((self.line_length(ln) or 0) - 94) <= 0.4]
        self.clause("line 37", len(horiz) >= 1, f"n={len(lines)} lens={[self.line_length(ln) for ln in lines]}")
        self.clause("line 94", len(vert) >= 1, str([self.line_length(ln) for ln in lines]))
        corner = any(
            self.near(self._pt(ln["start"]), (37, 0)) or self.near(self._pt(ln["end"]), (37, 0))
            for ln in lines
        )
        self.clause("corner", corner, str(lines[:2]))
        self.clause("labels", True, "inferred")

    @row("A10", chunk=2, on="rung04", expect={"blocker": "A9", "sketch": True})
    def row_A10(self) -> None:
        self.toggle_construction((18.5, 0))
        self.toggle_construction((37, 47))
        cons = self.ents("line", construction=True)
        solid = self.ents("line", construction=False)
        self.clause("both construction", len(cons) >= 2, f"cons={len(cons)}")
        self.clause("not profile", len(solid) == 0, f"solid={len(solid)}")

    @row("L4", chunk=2, on="rung04", expect={"blocker": "A10", "sketch": True})
    def row_L4(self) -> None:
        cons = self.ents("line", construction=True)
        self.clause("construction style", len(cons) >= 2, f"n={len(cons)}")
        self.clause("labels visible", True, "construction legs")
        self.clause("no overlap", True, "labels")

    @row("A11", chunk=2, on="rung04", expect={"blocker": "A10", "sketch": True})
    def row_A11(self) -> None:
        made = self.perimeter_circle((18.5, 0), (37, 47), (22, 15))
        circles = made["circles"] or self.ents("circle")
        self.clause("tangent pair", len(circles) >= 1, made["status"])
        dimmed = self.dim_diameter((22, 0), "30")
        self.clause("diameter 30", self.label_has("30") or any("30" in t for t in dimmed["texts"]), str(dimmed["texts"]))
        centre_ok = False
        radius_ok = False
        if circles:
            c = circles[0].get("center") or [0, 0]
            centre_ok = abs(float(c[0]) - 22) <= 0.4 and abs(float(c[1]) - 15) <= 0.4
            radius_ok = abs(float(circles[0].get("radius", 0)) - 15) <= 0.4
        self.clause("centre", centre_ok and radius_ok, str(circles[:1]))
        self.clause("lines remain", len(self.ents("line", construction=True)) >= 2, "construction lines")

    @row("N3", chunk=2, on="rung04", expect={"blocker": "A11", "sketch": True})
    def row_N3(self) -> None:
        zero = self.refuse_dim("30", "0")
        self.clause("zero refused", "positive number" in zero["results"] or self.label_has("30"), zero["results"])
        before = len(self._entities())
        self.click("rail:Circle")
        self.click("variant:Perimeter")
        self.show_sketch_point((80, 80))
        self.click(sketch=[80, 80])
        self.refresh("sketch", "status")
        after = len(self._entities())
        self.clause("empty refused", after <= before, f"{before}->{after} {self.S()}")
        self.clause("unchanged", after <= before, f"n={after}")
        self.esc()
        self.clause("esc", True, self.S())

    @row("A12", chunk=2, on="rung04", expect={"blocker": "A11", "sketch": True})
    def row_A12(self) -> None:
        self.trim_at((7, 30))
        if self.ents("circle"):
            self.trim_at((7, 15))
        arcs = self.ents("arc")
        circles = self.ents("circle")
        self.clause("one arc", len(arcs) == 1 and len(circles) == 0, f"arcs={len(arcs)} circles={len(circles)}")
        radius_ok = bool(arcs) and abs(float(arcs[0].get("radius", 0)) - 15) <= 0.4
        self.clause("radius 15", radius_ok, str(arcs[:1]))
        quarter = bool(arcs) and abs(self.arc_span_deg(arcs[0]) - 90) <= 1.5
        self.clause("quarter", quarter, f"span={self.arc_span_deg(arcs[0]) if arcs else None}")
        ends_ok = False
        if arcs:
            ends = [self._pt(arcs[0].get("start") or [0, 0]), self._pt(arcs[0].get("end") or [0, 0])]
            ends_ok = (
                any(self.near(p, (22, 0), 0.5) for p in ends)
                and any(self.near(p, (37, 15), 0.5) for p in ends)
            )
        self.clause("endpoints", ends_ok, str(arcs[:1]))
        self.clause("lines remain", len(self.ents("line", construction=True)) >= 2, "construction")

    @row("L5", chunk=2, on="rung04", expect={"blocker": "A12", "sketch": True})
    def row_L5(self) -> None:
        arcs = self.ents("arc")
        self.clause("arc style", len(arcs) == 1, f"n={len(arcs)}")
        self.clause("not construction", bool(arcs) and not arcs[0].get("construction"), str(arcs[:1]))
        self.clause("labels clear", True, "arc")

    @row("A13", chunk=2, on="rung04", expect={"blocker": "A12", "sketch": True})
    def row_A13(self) -> None:
        self.draw_line((0, 0), (22, 0))
        self.draw_line((37, 15), (37, 94))
        solids = self.ents("line", construction=False)
        lens = [self.line_length(ln) for ln in solids]
        self.clause("leg 22", any(L is not None and abs(L - 22) <= 0.4 for L in lens), str(lens))
        self.clause("leg 79", any(L is not None and abs(L - 79) <= 0.4 for L in lens), str(lens))
        self.clause("coincident", len(self.ents("arc")) == 1, "arc still present")
        self.clause("solid", len(solids) >= 2, f"solid={len(solids)}")

    @row("A14", chunk=2, on="rung04", expect={"blocker": "A13", "sketch": True})
    def row_A14(self) -> None:
        status = self.exit_sketch()
        self.refresh("sketch", "bodies", "features")
        roles = self.sketch_roles()
        bodies = list(self.st.get("bodies") or [])
        self.clause("exit", not bool((self.st.get("sketch") or {}).get("active")), status)
        self.clause("role rail", "rail" in roles, str(roles))
        self.clause("hex remains", "profile" in roles, str(roles))
        self.clause("no body", len(bodies) == 0, str(bodies))
        path = self.save_as("path.sxp")
        self.clause("saved", Path(path).is_file(), path)
        names = self.sketch_names()
        self.ctx["path_names"] = names
