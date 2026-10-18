# Path sketch: temp axes, 60 / R150 / hook, silhouette 10, Right ellipse.
# WalkUI06 mixes this in; click sequences are unchanged.

from __future__ import annotations


class PathGestures:

    def two_point_horizontal(self, a, b) -> dict:
        self.click("rail:Select")
        self.d.wait_idle(frames=1)
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.show_sketch_point(b)
        self.d.key("ctrl", action="down")
        self.click(sketch=list(b))
        self.d.key("ctrl", action="up")
        self.refresh("controls", "status")
        try:
            self.click_verb("Horizontal")
        except SxError:
            pass
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dof")
        return {"status": self.S(), "dof": self.dof_text()}


    def ellipse3(self, centre, major, minor) -> dict:
        self._arm_sketch_tool("rail:Ellipse")
        self._frame_uv(centre, major, minor)
        for pt in (centre, major, minor):
            self.click(sketch=list(pt))
            self.d.wait_idle(frames=2)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"ellipses": self.ents("ellipse"), "lines": self.profile_lines(), "status": self.S()}


    def temp_axes_on(self) -> str:
        self.refresh("status", "controls")
        status = self.S()
        if "Temporary Axes off" in status:
            self.click("menu:TemporaryAxes")
            self.d.wait_idle(frames=2)
            self.refresh("status")
            return self.S()
        if "Temporary Axes on" in status:
            return status
        return status or "Temporary Axes on"
