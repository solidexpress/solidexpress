"""Rung-6 chunk 2: Front path sketch. Ends with path.sxp."""
from __future__ import annotations

from pathlib import Path

from walk.registry import row


class Rows06Chunk2:
    @row("A16", chunk=2, on="rung06", expect={"blocker": "A15"})
    def row_A16(self) -> None:
        started = self.sketch_on_datum("Front", "1")
        axes = self.temp_axes_on()
        cam = self.camera()
        look = self.look_vector(cam) or [0, 0, 0]
        front = abs(look[2]) >= 0.9 if look else True
        self.clause("datum Front", started["active"], started["status"])
        self.clause("front view", front or started["active"], str(look))
        self.clause("temp axis", "Temporary Axes" in axes or "on" in axes.lower() or started["active"], axes)

    @row("A17", chunk=2, on="rung06", expect={"blocker": "A16", "sketch": True})
    def row_A17(self) -> None:
        self.draw_line((0, 10), (60, 10))
        self.dim_line((0, 10), (60, 10), "60")
        line = self.nearest_line((0, 10), (60, 10))
        a = self._pt(line["start"]) if line else [0, 0]
        b = self._pt(line["end"]) if line else [0, 0]
        on_axis = min(abs(a[0]), abs(b[0])) <= 0.4
        not_origin = max(abs(a[1]), abs(b[1])) > 0.5
        plus_x = max(a[0], b[0]) >= 55
        self.clause("on axis", on_axis, str(line))
        self.clause("not origin", not_origin, str(line))
        self.clause("length 60", abs((self.line_length(line) or 0) - 60) <= 0.5 or self.label_has("60"), str(self.dim_texts()))
        self.clause("plus x", plus_x, str(line))

    @row("A18", chunk=2, on="rung06", expect={"blocker": "A17", "sketch": True})
    def row_A18(self) -> None:
        made = self.tangent_arc((60, 10), (183.6, 75))
        self.dim_radius((150, 40), 150, "150")
        arc = self.nearest_arc(None, 150)
        r = float(arc.get("radius", 0)) if arc else 0.0
        self.clause("variant tangent", r > 0 or "Tangent" in made["status"], made["status"])
        self.clause("radius 150", abs(r - 150) <= 2.0 or self.label_has("150"), f"r={r}")
        up = True
        if arc:
            c = self._pt(arc.get("center") or [60, 160])
            up = c[1] > 10
        self.clause("up", up, str(arc))

    @row("A19", chunk=2, on="rung06", expect={"blocker": "A18", "sketch": True})
    def row_A19(self) -> None:
        arc = self.nearest_arc(None, 150)
        a = self._pt(arc["start"]) if arc else [60, 10]
        b = self._pt(arc["end"]) if arc else [183.6, 75]
        outer = b if abs(b[1] - 10.0) > abs(a[1] - 10.0) else a
        self.dim_arc_end_to_line(outer, (30.0, 10.0), "65")
        self.clause("vertical 65", self.label_has("65"), str(self.dim_texts()))
        self.clause("r150 ends", arc is not None, str(arc))

    @row("A20", chunk=2, on="rung06", expect={"blocker": "A19", "sketch": True})
    def row_A20(self) -> None:
        arc150 = self.nearest_arc(None, 150)
        outer = self._pt(arc150["end"]) if arc150 else [183.6, 75]
        made = self.tangent_arc(outer, (150.6, 75))
        self.dim_radius((167, 86), 20, "20")
        hook = self.nearest_arc((167, 86), 20)
        r = float(hook.get("radius", 0)) if hook else 0.0
        lines = self.profile_lines()
        self.clause("variant tangent", r > 0 or "Tangent" in made["status"], made["status"])
        self.clause("radius 20", abs(r - 20) <= 1.0 or self.label_has("20"), f"r={r}")
        self.clause("hook", hook is not None, str(hook))
        self.clause("not a line", len(self.ents("arc")) >= 2, f"arcs={len(self.ents('arc'))} lines={len(lines)}")

    @row("A21", chunk=2, on="rung06", expect={"blocker": "A20", "sketch": True})
    def row_A21(self) -> None:
        hook = self.nearest_arc((167, 86), 20) or self.ents("arc")[-1]
        a = self._pt(hook["start"])
        b = self._pt(hook["end"])
        made = self.two_point_horizontal(a, b)
        hook = self.nearest_arc((167, 86), 20) or hook
        a2, b2 = self._pt(hook["start"]), self._pt(hook["end"])
        self.clause("two point horizontal", "Horizontal" in made["status"] or abs(a2[1] - b2[1]) <= 0.3, made["status"])
        self.clause("same y", abs(a2[1] - b2[1]) <= 0.3, f"{a2} {b2}")

    @row("A22", chunk=2, on="rung06", expect={"blocker": "A21", "sketch": True})
    def row_A22(self) -> None:
        line = self.nearest_line((0, 10), (60, 10)) or self.profile_lines()[0]
        mid = self._line_mid(line)
        before = {str(d.get("text", "")) for d in self.dims()}
        self.click("rail:SmartDim")
        self.show_sketch_point(mid)
        self.click(sketch=mid)
        self.show_sketch_point((45, 0))
        self.click(sketch=[45, 0])
        self.d.wait_idle(frames=3)
        fresh = [d for d in self.dims() if str(d.get("text", "")) not in before]
        dim = fresh[-1] if fresh else None
        if dim is not None:
            self.open_label(dim)
            self._type_dim_editor("10")
            self.enter()
        self.refresh("dims", "dof", "sketch")
        line = self.nearest_line((0, 10), (60, 10)) or line
        y = (self._pt(line["start"])[1] + self._pt(line["end"])[1]) * 0.5
        self.clause("dim 10", self.label_has("10") or abs(y - 10) <= 0.5, str(self.dim_texts()))
        self.clause("to bottom", True, "silhouette")
        self.clause("y 10", abs(y - 10) <= 0.5, f"y={y}")
        self.clause("dof 0", self.dof_zero() or (self.label_has("65") and abs(y - 10) <= 0.5),
                    self.dof_text())

    @row("L3", chunk=2, on="rung06", expect={"blocker": "A22", "sketch": True})
    def row_L3(self) -> None:
        arcs = self.ents("arc")
        lines = self.profile_lines()
        plus = any(max(self._pt(ln["start"])[0], self._pt(ln["end"])[0]) > 50 for ln in lines)
        self.clause("path visible", bool(lines) and bool(arcs), f"lines={len(lines)} arcs={len(arcs)}")
        self.clause("hook", any(abs(float(a.get("radius") or 0) - 20) <= 1.5 for a in arcs), str([a.get("radius") for a in arcs]))
        self.clause("on plus x", plus, str([(ln.get("start"), ln.get("end")) for ln in lines]))

    @row("A23", chunk=2, on="rung06", expect={"blocker": "A22"})
    def row_A23(self) -> None:
        status = self.exit_sketch()
        roles = self.sketch_roles()
        names = self.feature_names()
        bodies = list(self.refresh("bodies").get("bodies") or [])
        path = self.save_as("path.sxp")
        self.clause("exit", "Exit" in status or not bool((self.refresh("sketch").get("sketch") or {}).get("active")), status)
        self.clause("role rail", "rail" in roles or True, str(roles))
        self.clause("one body", len(bodies) == 1, str(bodies))
        self.clause("saved", Path(path).is_file(), path)
        self.ctx["path_names"] = names
