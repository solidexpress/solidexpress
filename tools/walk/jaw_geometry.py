"""Jaw basis, wall screen samples, badge rectangles."""
from __future__ import annotations

from sxdrive import SxError

class WalkJaw:
    def jaw_basis(self) -> None:
        h = self.d.project(sketch=[200, 0])["screen"]
        ux = self.d.project(sketch=[201, 0])["screen"]
        uy = self.d.project(sketch=[200, 1])["screen"]
        self.ctx["H"] = h
        self.ctx["s"] = ((ux[0] - h[0]) ** 2 + (ux[1] - h[1]) ** 2) ** 0.5
        self.ctx["ux"] = [ux[0] - h[0], ux[1] - h[1]]
        self.ctx["uy"] = [uy[0] - h[0], uy[1] - h[1]]

    def _badge_rects(self) -> list[list[float]]:
        rects = []
        for g in self.st.get("glyphs") or []:
            r = g.get("rect") or []
            if len(r) >= 4 and float(r[2]) > 1.0 and float(r[3]) > 1.0:
                rects.append([float(v) for v in r[:4]])
        return rects

    def _in_badge(self, pt: list[float], rects: list[list[float]], pad: float = 2.0) -> bool:
        x, y = float(pt[0]), float(pt[1])
        for r in rects:
            if r[0] - pad <= x <= r[0] + r[2] + pad and r[1] - pad <= y <= r[1] + r[3] + pad:
                return True
        return False

    def _off_badges(self, screen: list[float], badges: list[list[float]], dx: float, dy: float) -> list[float] | None:
        """Keep a wall sample. A badge overlap slides along the stroke, not off it."""
        if not self._in_badge(screen, badges, pad=4.0):
            return screen
        try:
            origin = self.d.project(sketch=[0, 0])["screen"]
            tip = self.d.project(sketch=[dx, dy])["screen"]
        except SxError:
            return None
        sx = float(tip[0]) - float(origin[0])
        sy = float(tip[1]) - float(origin[1])
        sl = (sx * sx + sy * sy) ** 0.5
        if sl < 1e-3:
            return None
        ux, uy = sx / sl, sy / sl
        for dist in (8.0, -8.0, 16.0, -16.0):
            cand = [screen[0] + ux * dist, screen[1] + uy * dist]
            if not self._in_badge(cand, badges, pad=4.0):
                return cand
        return None

    def wall_screen_points(self, count: int = 9) -> list[list[float]]:
        """Screen samples along the two longest slanted walls, outside badge rects."""
        self.refresh("sketch", "glyphs")
        badges = self._badge_rects()
        lines = []
        for e in self._entities():
            if str(e.get("type", "")) != "line" or e.get("construction"):
                continue
            a, b = e.get("start"), e.get("end")
            if not a or not b:
                continue
            dx = float(b[0]) - float(a[0])
            dy = float(b[1]) - float(a[1])
            length = (dx * dx + dy * dy) ** 0.5
            if length < 4.0 or abs(dy) < 0.5:
                continue
            lines.append((length, a, dx, dy))
        lines.sort(key=lambda row: row[0], reverse=True)
        # One wall. The other long edge's projection is not always pickable
        # after the checklist zoom, and the safe band is only a few pixels wide.
        lines = lines[:1]
        points: list[list[float]] = []
        # Walk the wall and keep samples that are clear of badge rects.
        # A fixed 0.21–0.37 band sits under the perpendicular glyph at
        # 1280×800; the middle of the same wall is still a plain entity pick.
        frac = 0.12
        while frac <= 0.88:
            for _length, a, dx, dy in lines:
                uv = [float(a[0]) + dx * frac, float(a[1]) + dy * frac]
                try:
                    screen = self.d.project(sketch=uv)["screen"]
                except SxError:
                    continue
                # A point on the rect's edge still hits the glyph after the
                # click is reprojected. Keep a few pixels of clearance.
                if self._in_badge(screen, badges, pad=6.0):
                    continue
                # Coincident marks are hidden until the pointer is near the
                # vertex. Hover and skip a sample that lands in the badge.
                # Pad 0: a 6 px pad covers the whole short wall at 1920×1200.
                try:
                    self.d.hover(screen=screen)
                    self.d.wait_idle(frames=1)
                    self.refresh("glyphs")
                except SxError:
                    pass
                if self._in_badge(screen, self._badge_rects(), pad=0.0):
                    continue
                # 2 px apart. The clear span beside a vertex badge is only
                # about 20 px, and a 3 px gap cannot fit 8 samples in it.
                if any((screen[0] - p[0]) ** 2 + (screen[1] - p[1]) ** 2 < 4.0 for p in points):
                    continue
                points.append(screen)
                if len(points) >= count:
                    return points
            frac += 0.02
        return points

    def _jaw_wall_screen(self, along: float) -> list[float]:
        pts = self.wall_screen_points(1)
        if pts:
            # Prefer the requested fraction when a wall projects cleanly.
            self.refresh("sketch", "glyphs")
            badges = self._badge_rects()
            for e in self._entities():
                if str(e.get("type", "")) != "line":
                    continue
                a, b = e.get("start"), e.get("end")
                if not a or not b:
                    continue
                dx = float(b[0]) - float(a[0])
                dy = float(b[1]) - float(a[1])
                if dx * dx + dy * dy < 25.0 or abs(dy) < 1.0:
                    continue
                screen = self.d.project(sketch=[float(a[0]) + dx * along, float(a[1]) + dy * along])["screen"]
                if not self._in_badge(screen, badges):
                    return screen
            return pts[0]
        if "H" not in self.ctx:
            self.jaw_basis()
        return self.jaw_px(10, -6)

    def jaw_px(self, du: float, dv: float) -> list[float]:
        h = self.ctx["H"]
        ux = self.ctx["ux"]
        uy = self.ctx["uy"]
        return [h[0] + du * ux[0] + dv * uy[0], h[1] + du * ux[1] + dv * uy[1]]

    def head_px(self) -> float:
        a = self.d.project(sketch=[200 - 22.5, 0])["screen"]
        b = self.d.project(sketch=[200 + 22.5, 0])["screen"]
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5
