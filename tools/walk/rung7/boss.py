# Contour chips, mid-plane extrude, twelve-point bore, Z extent.
# WalkUI07 mixes this in; click sequences are unchanged.

from __future__ import annotations


class BossGestures:

    def contour_chips(self) -> list[dict]:
        self.refresh("controls")
        return [
            c for c in (self.st.get("controls") or [])
            if str(c.get("id", "")).startswith("contour:")
        ]

    def _parse_contour_note(self, note: str) -> tuple[float, float, float, float]:
        """Return (cx, cy, width, height) from a contour status sentence.

        Probe clicks accumulate status. Use only the last `Contour N of M —`
        sentence so a leftover C bbox cannot mark the handle chip as a head.
        """
        chunk = note
        if "Contour " in note:
            chunk = "Contour " + note.rsplit("Contour ", 1)[-1]
        cx = cy = width = height = 0.0
        if "at (" in chunk:
            try:
                xy = chunk.split("at (")[-1].split(")")[0]
                parts = xy.split(",")
                cx = float(parts[0])
                cy = float(parts[1])
            except (ValueError, IndexError):
                pass
        if "—" in chunk and "×" in chunk:
            try:
                span = chunk.split("—")[1]
                wh = span.split("mm")[0]
                width = float(wh.split("×")[0].strip())
                height = float(wh.split("×")[1].strip())
            except (ValueError, IndexError):
                pass
        return cx, cy, width, height

    def _heads_not_handle(self, notes: list[str]) -> bool:
        has_c = any(self._contour_wanted({"c"}, n) for n in notes)
        has_ring = any(self._contour_wanted({"ring"}, n) for n in notes)
        handle_as_head = any(
            self._contour_wanted({"handle"}, n) and self._contour_wanted({"c", "ring"}, n)
            for n in notes
        )
        return has_c and has_ring and not handle_as_head

    def _contour_wanted_row(self, keep: set[str], row: dict) -> bool:
        area = abs(float(row.get("area") or 0.0))
        sz = row.get("size") or [0, 0]
        mn = row.get("min") or [0, 0]
        w, h = float(sz[0]), float(sz[1])
        cx = float(mn[0]) + w * 0.5
        long_side = max(w, h)
        note = "— %.1f × %.1f mm at (%.1f, 0)" % (w, h, cx)
        for token in keep:
            if token == "c" and abs(area - self.mm("A_C")) < 80:
                return True
            if token == "ring" and abs(area - self.mm("A_RING")) < 50:
                return True
            if token == "handle" and abs(area - self.mm("A_H")) < 250:
                return True
            if token == "recess" and 80.0 < long_side < 200.0 and 6.0 <= min(w, h) <= 16.0:
                return True
        return self._contour_wanted(keep, note)

    def _contour_wanted(self, keep: set[str], note: str) -> bool:
        cx, _cy, width, height = self._parse_contour_note(note)
        long_side = max(width, height)
        for token in keep:
            if token == "c" and abs(cx) < 50 and 40.0 < long_side < 80:
                return True
            if token == "ring" and abs(cx - self.mm("CENTER")) < 25 and long_side >= 30 and min(width, height) >= 20:
                return True
            if token == "handle" and long_side > 80:
                return True
            if token == "recess" and 80.0 < long_side < 200.0 and 6.0 <= min(width, height) <= 16.0:
                return True
        return False

    def set_contours(self, keep: set[str]) -> list[str]:
        # Area from kernel outlines (A_C / A_RING / A_H). Chip clicks plus
        # mixed status notes picked the handle pad (A23 226.876×37.295).
        self._ensure_finish_bar()
        snap = self.refresh("controls", "contour_regions")
        regions = list(snap.get("contour_regions") or [])
        notes: list[str] = []
        want_idx: list[int] = []
        for i, row in enumerate(regions):
            sz = row.get("size") or [0, 0]
            mn = row.get("min") or [0, 0]
            w, h = float(sz[0]), float(sz[1])
            cx = float(mn[0]) + w * 0.5
            cy = float(mn[1]) + h * 0.5
            area = abs(float(row.get("area") or 0.0))
            note = "Contour %d of %d — %.1f × %.1f mm at (%.1f, %.1f) area=%.1f" % (
                i + 1, len(regions), w, h, cx, cy, area)
            notes.append(note)
            if self._contour_wanted_row(keep, row):
                want_idx.append(i)
        self.d.call("select_contours", indices=want_idx)
        self.d.wait_idle(frames=2)
        return notes

    def uncheck_all_contours(self) -> None:
        for chip in self.contour_chips():
            node = self.control(str(chip.get("id", ""))) or chip
            if bool(node.get("pressed") or node.get("button_pressed")):
                self.click(str(chip.get("id")))
                self.d.wait_idle(frames=1)

    def kernel_cut(self, distance: float, end: str = "blind") -> dict:
        """Cut via finish_extrude (empty contours), same path as the offset suite."""
        mark = self.mark()
        reply = self.d.call("finish_extrude", distance=float(distance), op="cut", end=end, frames=12)
        self.d.wait_idle(frames=8)
        self.refresh("status", "sketch", "finish", "bodies", "features")
        return {
            "field": f"{distance:g}",
            "op": "Cut",
            "end": end,
            "reply": reply,
            "status": " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S())),
            "sketch": bool((self.st.get("sketch") or {}).get("active")),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def try_extrude(self, distance: str, op: str = "New", end: str = "Midplane",
                    apply: bool = True, keep: set[str] | None = None) -> dict:
        self._ensure_finish_bar()
        self.set_option("finish:Op", op)
        self.set_option("finish:End", end)
        shown = self.type_into("finish:Distance", distance)
        if keep:
            self.set_contours(keep)
        mark = self.mark()
        reply = self.click("finish:Extrude", frames=8) if apply else {}
        if apply:
            self.d.wait_idle(frames=8)
        results = self.result_texts(mark) if apply else []
        self.refresh("status", "sketch", "finish", "bodies", "features")
        return {
            "field": shown,
            "op": self.field("finish:Op"),
            "end": self.field("finish:End"),
            "reply": reply,
            "status": " | ".join(results) or str(reply.get("status", self.S())),
            "sketch": bool((self.st.get("sketch") or {}).get("active")),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def ensure_twelve_point_bore(self) -> dict:
        """Front sketch + Line star + Cut Midplane 10. Polygon Power Trim of
        two hexes leaves leftover triangles, so the Ø33 disc stays solid."""
        bodies = list(self.refresh("bodies").get("bodies") or [])
        vol = float(bodies[0].get("volume") or 0.0) if bodies else 0.0
        if vol and vol <= self.mm("V_BOSS") * 1.01:
            return {"skipped": True, "status": f"volume {vol:.1f} already at boss"}
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        started = self.sketch_on_datum("Front", "1")
        added = 0
        if started.get("active"):
            added = self.draw_twelve_point_star()
        made = self.try_extrude(f"{self.mm('HEAD_T'):g}", "Cut", "Midplane")
        if made.get("sketch"):
            self.exit_sketch()
        self.refresh("bodies", "features", "status")
        return {
            "started": started,
            "added": added,
            "cut": made,
            "status": made.get("status", self.S()),
            "volume": (self.refresh("bodies").get("bodies") or [{}])[0].get("volume"),
        }

    def z_extent(self) -> tuple[float, float] | None:
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            return None
        mn = bodies[0].get("min") or [0, 0, 0]
        mx = bodies[0].get("max") or [0, 0, 0]
        return float(mn[2]), float(mx[2])
