"""Rung-1 gestures: jaw sketch, dialog typing, wrench export guard.
Shared clicks and fields live on WalkGestures.
"""
from __future__ import annotations

from sxdrive import SxError


class WalkUI:
    def _arm_dialog_dir(self) -> None:
        self.d.dialog_dir(str(self.out))
        self.refresh("focus", "focus_text", "popups")

    def _type_dialog_name(self, name: str, replace_selection: bool) -> str:
        focus = str(self.refresh("focus", "focus_text").get("focus", ""))
        if "LineEdit" not in focus and "dialog:Name" not in focus:
            self.click("dialog:Name")
            self.refresh("focus", "focus_text")
        if not replace_selection:
            self.d.key("ctrl+a")
        self.d.type(name, delay_ms=10)
        return str(self.refresh("focus_text", "status").get("focus_text", ""))

    def clear_selection(self) -> None:
        self.esc_until("Selection cleared", 5)

    def top_face(self) -> dict:
        self.refresh("faces")
        faces = list(self.st.get("faces") or [])
        if not faces:
            raise SxError("no faces")
        tops = [f for f in faces if float(f["centre"][2]) >= 9.0]
        pool = tops or faces
        return max(pool, key=lambda f: (float(f["centre"][2]), -abs(float(f["centre"][0]) - 100.0)))

    def bottom_face(self) -> dict:
        self.refresh("faces")
        faces = list(self.st.get("faces") or [])
        lows = [f for f in faces if float(f["centre"][2]) <= 1.0]
        pool = lows or faces
        return min(pool, key=lambda f: float(f["centre"][2]))

    def sketch_on_top(self) -> None:
        self.clear_selection()
        self.click("rail:Sketch")
        face = self.top_face()
        self.click(face=face["id"])
        self.refresh("status", "sketch", "finish")

    def _label_is(self, token: str, text: str) -> bool:
        t = str(text).replace(" ", "")
        if token == "45":
            return t.startswith("45") and "°" in t
        if token == "20":
            return t.startswith("20") and "°" not in t
        if token == "5":
            return t.startswith("5") and not t.startswith("22") and "°" not in t and "45" not in t
        if token == "22.5":
            return t.startswith("22.5")
        return token in t

    def _shaft_mids(self) -> list[list[float]]:
        mids = []
        for e in self._entities():
            if e.get("type") != "line":
                continue
            a, b = e.get("start"), e.get("end")
            if not a or not b:
                continue
            if abs(a[1] - b[1]) > 1.0:
                continue
            if abs(abs(a[1]) - 10.0) > 2.0:
                continue
            mids.append([(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5])
        mids.sort(key=lambda p: p[1])
        return mids

    def _select_both_circles(self) -> None:
        self.click("rail:Select")
        self.refresh("sketch", "selection")
        circles = [e for e in self._entities() if e.get("type") == "circle" and e.get("center")]
        circles.sort(key=lambda e: float(e["radius"]))
        sel = (self.st.get("selection") or {}).get("sketch") or []
        if len(sel) >= 2:
            return
        self.click(sketch=[0, 40])
        self.refresh("status")
        for e in circles[:2]:
            self.click(sketch=list(e["center"]))
        self.refresh("selection", "status")

    def rail_right(self) -> float:
        rights = []
        for b in (self.refresh("rail").get("rail") or []):
            rect = b.get("rect") or []
            if len(rect) >= 4:
                rights.append(float(rect[0]) + float(rect[2]))
        return max(rights) if rights else 129.0

    def label_clear(self, dim: dict) -> bool:
        rect = dim.get("rect") or []
        if len(rect) < 4:
            return False
        win = (self.refresh("window").get("window") or {}).get("size") or [1280, 800]
        x, y, w, h = [float(v) for v in rect[:4]]
        return x >= self.rail_right() - 1 and y >= 36 and x + w <= float(win[0]) - 2 and y + h <= float(win[1]) - 2

    def _reopen_sketch3(self) -> str:
        self._show_timeline()
        self.click("timeline:pencil:sketch 3")
        self.d.wait_idle(frames=3)
        self.refresh("status", "sketch")
        return self.S()

    def body_guard(self, kind: str, thickness: float | None = None) -> bool:
        """S0: exactly one body before an export. A miss is runner-gap, not a checker FAIL."""
        self.refresh("bodies")
        bodies = list(self.st.get("bodies") or [])
        if len(bodies) != 1:
            named = ", ".join(f"{b.get('name')} ({self._fmt_volume(b)})" for b in bodies) or "(none)"
            left = self.ctx.get("bodies_left_by") or "unknown"
            evidence = f"runner-gap: stray body {named} left by {left}"
            self.clause("S0", False, evidence, kind="runner-gap")
            return False
        body = bodies[0]
        name = str(body.get("name", ""))
        if kind == "nut":
            self.clause("S0", True, f"one body {name} ({self._fmt_volume(body)})")
            return True
        sx, sy, sz = self._bbox_size(body)
        ok = (
            name.startswith("extrude")
            and abs(sx - 232.5) <= 0.3
            and abs(sy - 45.0) <= 0.1
            and thickness is not None
            and abs(sz - float(thickness)) <= 0.01
        )
        evidence = f"{name} ({self._fmt_volume(body)}) bbox {sx:.3f}×{sy:.3f}×{sz:.3f} T={thickness}"
        if not ok and len(bodies) == 1:
            evidence = f"runner-gap: body {name} ({self._fmt_volume(body)}) bbox {sx:.3f}×{sy:.3f}×{sz:.3f} want 232.5×45×{thickness}"
        self.clause("S0", ok, evidence, kind="" if ok else "runner-gap")
        return ok

