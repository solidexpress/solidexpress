"""Walk rows for chunk 3."""
from __future__ import annotations

import time
from pathlib import Path

from sxdrive import SxError
from walk.registry import row

class RowsChunk3:
    @row('A9', chunk=3, expect={'blocker': 'N8a', 'sketch': True})
    def row_A9(self) -> None:
        self.d.key("f")
        typed = self.circle([0, 0], "5")
        self.clause("pivot circle", "Circle r=5.0000" in self.S(), f"typed={typed} {self.S()}")
        typed = self.circle([200, 0], "22.5", burst=True)
        self.clause("head circle", "22.5000" in self.S(), f"typed={typed} {self.S()}")
        self.click("rail:Line")
        self.refresh("focus_text", "finish")
        length = self.field("finish:Radius") or str(self.st.get("focus_text", ""))
        self.clause("length not 22.5", "22.5" not in length, length)
        self.click(sketch=[160, 40])
        self.click(sketch=[240, -40])
        self.refresh("status")
        self.click("rail:Trim")
        self.d.drag({"sketch": [250, 0]}, {"sketch": [190, 0]})
        self.refresh("status", "infer")
        first = self.S()
        self.clause("trimmed", "Trimmed open jaw" in first or "Trimmed" in first, first)
        infer = self.st.get("infer") or {}
        self.clause("no yellow hint", not infer.get("visible"), str(infer))
        self.d.drag({"sketch": [250, 10]}, {"sketch": [190, 10]})
        self.refresh("status")
        self.clause("second trim", "already open" in self.S() or "nothing left" in self.S().lower() or "Trimmed" in self.S(), self.S())

    @row('L4', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_L4(self) -> None:
        texts = self.dim_texts()
        twenties = [t for t in texts if t.strip().startswith("20") and "°" not in t]
        angle_drawn = [t for t in texts if "°" in t]
        ok = len(twenties) == 1 and len(angle_drawn) == 1 and angle_drawn[0].replace(" ", "").startswith("45")
        self.clause(
            "one 20 one 45",
            ok,
            f"drawn={texts} angle={angle_drawn}",
            kind="" if ok else "product",
        )
        self.clause("no minus", not any("-" in t for t in texts), str(texts))
        self.clause("not 20.0005", not any("20.0005" in t or "45.0007" in t for t in texts), str(texts))

    def _open_angle_editor(self, angle: dict) -> str:
        """Click the hit-test rect until DimEditLine reads 45. Leave the sketch open."""
        rect = angle.get("hit_rect") or []
        if len(rect) < 4 or float(rect[2]) < 1.0:
            rect = []
        points: list[list[float]] = []
        if rect:
            x, y, w, h = [float(v) for v in rect[:4]]
            points.append([x + w * 0.5, y + h * 0.5])
            points.append([x + min(6.0, max(w * 0.2, 1.0)), y + h * 0.5])
            points.append([x + w * 0.5, y + min(4.0, h * 0.25)])
        editor = ""
        for pt in points:
            self.d.click(screen=pt)
            self.d.wait_idle(frames=6)
            got = str((self.control("dim:Edit") or {}).get("text", ""))
            if got.startswith("45"):
                return got
            if got:
                self.click("dim:Edit")
                self.esc()
                self.click("rail:Select")
                continue
            status = self.S()
            if "Selected" in status and "sketch entity" in status:
                self.d.key("ctrl+z")
                self.d.wait_idle(frames=4)
                self.click("rail:Select")
        return editor

    @row('N1a', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N1a(self) -> None:
        guard = 0
        while self.head_px() < 142 and guard < 12:
            self.d.wheel(1, screen=self.ctx.get("H") or [640, 400])
            guard += 1
        while self.head_px() > 158 and guard < 24:
            self.d.wheel(-1, screen=self.ctx.get("H") or [640, 400])
            guard += 1
        px = self.head_px()
        texts = self.dim_texts()
        self.clause("zoom", 130 <= px <= 180, f"head {px:.1f}px notches={guard}")
        editor = ""
        angle = self.find_dim(lambda d: "°" in str(d.get("text", "")))
        if angle is not None:
            # Trim is still armed after A9; it consumes the label click.
            # The Label3D billboard rect (rect) sits on the jaw wall, so a
            # click there drags the entity. dimension_hit uses hit_rect.
            # Esc with focus on the rail exits the sketch, so only dismiss
            # a popup that is actually open, and only after focusing it.
            self.click("rail:Select")
            editor = self._open_angle_editor(angle)
            if editor.startswith("45"):
                self.click("dim:Edit")
                self.esc()
            elif not editor:
                editor = self.S()
        for token in ("20", "45", "5", "22.5"):
            present = any(self._label_is(token, t) for t in texts)
            self.clause(
                "label " + token,
                present,
                f"drawn={texts} editor={editor!r}",
                kind="" if present or token != "45" else "product",
            )
        self.clause("no minus", not any("-" in t for t in texts), str(texts))
        if angle is not None:
            self.clause("editor 45", "45" in editor and "-" not in editor, f"editor={editor!r}")
        head = self.find_dim(lambda d: "22.5" in str(d.get("text", "")))
        centre = None
        try:
            centre = self.d.project(sketch=[200.0, 0.0])["screen"]
        except (SxError, TypeError, KeyError):
            centre = self.ctx.get("H")
        if head and centre:
            r = head.get("hit_rect") or head.get("rect") or [0, 0, 0, 0]
            left, top, w, h = [float(v) for v in r[:4]]
            dx = max(left - centre[0], 0.0, centre[0] - (left + w))
            dy = max(top - centre[1], 0.0, centre[1] - (top + h))
            dist = (dx * dx + dy * dy) ** 0.5
            self.clause("22.5 near head", dist <= 40 + px / 2, f"dist to head {dist:.1f}")
        else:
            self.clause("22.5 placed", False, str(texts))

    @row('N21', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N21(self) -> None:
        glyphs = list((self.refresh("glyphs").get("glyphs") or []))
        self.clause("glyphs drawn", len(glyphs) >= 1, f"{len(glyphs)} glyphs")
        kinds = {}
        for g in glyphs:
            kinds.setdefault(str(g.get("type", g.get("text", ""))), []).append(g)
        clicked = 0
        for g in glyphs[:2]:
            rect = g.get("rect") or []
            if len(rect) < 4:
                continue
            self.click(screen=[rect[0] + rect[2] / 2, rect[1] + rect[3] / 2])
            self.refresh("status")
            self.clause("glyph click", "Constraint selected" in self.S(), self.S())
            clicked += 1
            self.click(sketch=[300, 80])
        if clicked == 0:
            self.clause("glyph hit", False, str(glyphs)[:300])

    @row('N21b', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N21b(self) -> None:
        self.click("rail:Select")
        samples = self.wall_screen_points(9)
        free = 0
        notes = []
        if len(samples) < 9:
            notes.append(f"only {len(samples)} wall samples clear of badges")
        for i, pt in enumerate(samples[:9]):
            self.click(sketch=[300, 80])
            self.click(screen=pt)
            self.refresh("status")
            ok = "Selected 1 sketch entity" in self.S() and "Constraint selected" not in self.S()
            if ok:
                free += 1
                self.ctx["wall_click"] = pt
            notes.append(f"{i}@({pt[0]:.0f},{pt[1]:.0f}):{self.S()[:40]}")
        self.clause("8 of 9 free", free >= 8, f"{free}/9 " + " | ".join(notes))

    def _screen_of_sketch(self, uv) -> list[float] | None:
        try:
            return self.d.project(sketch=[float(uv[0]), float(uv[1])])["screen"]
        except (SxError, TypeError, KeyError, IndexError):
            return None

    def _seg_hits_rect(self, a: list[float], b: list[float], rect: list) -> bool:
        if len(rect) < 4:
            return False
        x, y, w, h = (float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))

        def inside(px: float, py: float) -> bool:
            return x <= px <= x + w and y <= py <= y + h

        # The anchor sits on the sketch curve and can lie under a neighbour
        # badge. Samples within 14 px of it are that vertex, not the leader.
        # 10 px was short at 1280×800: a 15 px leader still grazed the
        # coincident badge at t=0.75 (~11 px).
        span = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
        if inside(b[0], b[1]) and span >= 14.0:
            return True
        steps = 8
        for i in range(1, steps):
            t = i / steps
            px = a[0] + (b[0] - a[0]) * t
            py = a[1] + (b[1] - a[1]) * t
            if ((px - a[0]) ** 2 + (py - a[1]) ** 2) ** 0.5 < 14.0:
                continue
            if inside(px, py):
                return True
        return False

    def _seg_hit_t(self, a: list[float], b: list[float], rect: list) -> float | None:
        if len(rect) < 4:
            return None
        x, y, w, h = (float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))

        def inside(px: float, py: float) -> bool:
            return x <= px <= x + w and y <= py <= y + h

        span = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
        if inside(b[0], b[1]) and span >= 14.0:
            return 1.0
        for i in range(1, 8):
            t = i / 8
            px = a[0] + (b[0] - a[0]) * t
            py = a[1] + (b[1] - a[1]) * t
            if ((px - a[0]) ** 2 + (py - a[1]) ** 2) ** 0.5 < 14.0:
                continue
            if inside(px, py):
                return t
        return None

    @row('N26', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N26(self) -> None:
        st = self.refresh("glyphs", "glyph_leaders", "dims")
        glyphs = list(st.get("glyphs") or [])
        rail = self.rail_right()
        off = []
        for g in glyphs:
            r = g.get("rect") or []
            if len(r) < 4:
                continue
            if r[0] < rail:
                off.append(g.get("text") or g.get("type"))
        self.clause("badges on canvas", not off, f"under rail {off} count={len(glyphs)}")
        flagged = []
        for g in glyphs:
            if "offset_px" not in g:
                flagged.append("missing offset")
                continue
            want = float(g.get("offset_px", 0)) >= 12.0
            if bool(g.get("leader")) != want or "cid" not in g or "anchor" not in g or "pos" not in g:
                flagged.append(str(g.get("type")))
        self.clause("leader flag", not flagged and bool(glyphs), f"bad={flagged} n={len(glyphs)}")
        leaders = [g for g in glyphs if g.get("leader")]
        mesh = st.get("glyph_leaders") or {}
        present = bool(mesh.get("present"))
        tris = int(mesh.get("tris") or 0)
        mesh_ok = present == bool(leaders) and tris == 2 * len(leaders)
        self.clause("leader mesh", mesh_ok, f"present={present} tris={tris} leaders={len(leaders)}")
        dim_rects = [d.get("rect") or [] for d in (st.get("dims") or [])]
        clearance_bad = []
        for g in leaders:
            anchor = self._screen_of_sketch(g.get("anchor") or [0, 0])
            pos = self._screen_of_sketch(g.get("pos") or [0, 0])
            rect = g.get("rect") or []
            if anchor is None or pos is None or len(rect) < 4:
                clearance_bad.append("unprojected")
                continue
            dist = ((pos[0] - anchor[0]) ** 2 + (pos[1] - anchor[1]) ** 2) ** 0.5
            grown = [rect[0] - 2, rect[1] - 2, rect[2] + 4, rect[3] + 4]
            near_in = (
                grown[0] <= pos[0] <= grown[0] + grown[2]
                and grown[1] <= pos[1] <= grown[1] + grown[3]
            )
            hits_dim = any(self._seg_hits_rect(anchor, pos, r) for r in dim_rects)
            others = []
            for other in glyphs:
                if other is g:
                    continue
                hit_t = self._seg_hit_t(anchor, pos, other.get("rect") or [])
                if hit_t is not None:
                    others.append(f"{other.get('type')}@{hit_t:.2f}")
            if dist > 40.0 or not near_in or hits_dim or others:
                clearance_bad.append(
                    f"{g.get('type')} d={dist:.1f} near={near_in} dim={hits_dim} other={others}"
                )
        self.clause("leader clearance", not clearance_bad, str(clearance_bad) or f"{len(leaders)} leaders")

    def _longest_wall_screen(self, frac: float) -> list[float] | None:
        self.refresh("sketch")
        best = None
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
            if best is None or length > best[0]:
                best = (length, a, dx, dy)
        if best is None:
            return None
        _length, a, dx, dy = best
        uv = [float(a[0]) + dx * frac, float(a[1]) + dy * frac]
        try:
            return self.d.project(sketch=uv)["screen"]
        except SxError:
            return None

    def _hover_wall_delta(self, samples: list[list[float]]) -> tuple[list[float] | None, str]:
        texts = ""
        for pt in samples:
            self.d.hover(screen=pt)
            self.d.wait_idle(frames=6)
            self.refresh("measure")
            texts = " ".join(str(m.get("text", "")) for m in (self.st.get("measure") or []))
            if "Δ" in texts:
                return pt, texts
        return None, texts

    @row('L12', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_L12(self) -> None:
        samples = self.wall_screen_points(9) or [self.jaw_px(16, -6)]
        # The vertex-side clicks select the wall, but the hover label is read
        # at mid-stroke, where the measure overlay actually arms.
        mid = self._longest_wall_screen(0.5)
        hover_pts = ([mid] if mid else []) + list(samples)
        self.click("rail:Circle")
        self.d.hover(screen=samples[0])
        self.d.wait_idle(frames=3)
        self.refresh("measure")
        self.clause("circle has no measure", not (self.st.get("measure") or []), str(self.st.get("measure")))
        self.click("rail:Select")
        pt, texts = self._hover_wall_delta(hover_pts)
        self.refresh("status")
        self.clause("hover delta", pt is not None and "Δ" in texts, texts or self.S())
        # Leave the entity so the hover label clears, then click from elsewhere.
        self.d.hover(sketch=[400, 200])
        self.d.wait_idle(frames=2)
        # Same press as N21b: the vertex-side point drag-selects the wall.
        # The mid-stroke point only arms the hover label.
        click_pt = self.ctx.get("wall_click") or (samples[0] if samples else pt)
        if click_pt is not None:
            self.click(sketch=[300, 80])
            self.click(screen=click_pt)
        self.refresh("status", "measure")
        texts = " ".join(str(m.get("text", "")) for m in (self.st.get("measure") or []))
        self.clause("click clears", "Selected 1 sketch entity" in self.S() and "Δ" not in texts, f"{self.S()} {texts}")

    @row('N24', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N24(self) -> None:
        before = int((self.refresh("sketch").get("sketch") or {}).get("entity_count") or 0)
        self.circle([40, 40], "3")
        self.click("rail:Select")
        a = self.d.project(sketch=[20, 20])["screen"]
        b = self.d.project(sketch=[60, 60])["screen"]
        if a[0] > b[0]:
            a, b = b, a
        box = self.d.drag({"screen": a}, {"screen": b}).get("box") or {}
        self.refresh("status")
        fill = box.get("fill") or []
        edge = box.get("edge") or []
        blue = len(fill) >= 3 and fill[2] > fill[1] > fill[0]
        self.clause("enclose", "Selected 1 sketch entity" in self.S(), f"{self.S()} fill={fill}")
        self.clause("window fill blue", blue, f"fill={fill}")
        window_edge = list(edge)
        self.click(screen=self.d.project(sketch=[10, 70])["screen"])
        self.refresh("status")
        self.clause("empty click", "cleared" in self.S().lower() or "No sketch" in self.S() or "Selected" not in self.S(), self.S())
        c = self.d.project(sketch=[70, 30])["screen"]
        d0 = self.d.project(sketch=[30, 50])["screen"]
        if c[0] < d0[0]:
            c, d0 = d0, c
        box = self.d.drag({"screen": c}, {"screen": d0}).get("box") or {}
        self.refresh("status")
        fill = box.get("fill") or []
        edge = box.get("edge") or []
        green = len(fill) >= 3 and fill[1] > fill[2] and fill[1] > fill[0]
        self.clause("crossing", "Selected" in self.S(), f"{self.S()} fill={fill}")
        self.clause("crossing fill green", green, f"fill={fill}")
        self.clause(
            "edge colour shared",
            len(edge) >= 3 and edge == window_edge and edge[2] > edge[0] and edge[2] > edge[1],
            f"window={window_edge} crossing={edge}",
        )
        self.d.drag({"screen": self.d.project(sketch=[30, 30])["screen"]}, {"screen": self.d.project(sketch=[50, 36])["screen"]})
        self.refresh("status")
        self.clause("cut misses", "No sketch" in self.S() or "Selected" not in self.S(), self.S())
        self.d.drag({"screen": a}, {"screen": b})
        self.d.key("delete")
        self.refresh("status", "sketch")
        after = int((self.st.get("sketch") or {}).get("entity_count") or 0)
        self.clause("deleted throwaway", "Deleted" in self.S() and after <= before + 1, f"{self.S()} {before}->{after}")

    @row('N24b', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N24b(self) -> None:
        before = int((self.refresh("sketch").get("sketch") or {}).get("entity_count") or 0)
        self.circle([50, -40], "3")
        self.click("rail:Select")
        # N21b already found a screen point on this wall that selects the
        # entity. Resampling after the r=3 circle can land in the trimmed
        # gap, which is on the line's bbox and on no stroke.
        remembered = self.ctx.get("wall_click")
        if isinstance(remembered, list) and len(remembered) >= 2:
            wall = remembered
        else:
            found = self.wall_screen_points(1)
            wall = found[0] if found else self.jaw_px(14, -5)
        self.click(screen=wall)
        self.refresh("status")
        self.clause("wall", "Selected 1 sketch entity" in self.S(), self.S())
        mark = self.mark()
        self.d.key("shift", action="down")
        a = self.d.project(sketch=[30, -60])["screen"]
        b = self.d.project(sketch=[70, -20])["screen"]
        self.d.drag({"screen": a}, {"screen": b})
        self.d.key("shift", action="up")
        self.refresh("status")
        lines = self.trace_from(mark)
        press = [ln for ln in lines if "press" in ln and "shift=" in ln]
        self.clause("shift add", "Selected 2" in self.S() and any("shift=1" in ln and "additive=1" in ln for ln in press), f"{self.S()} {press[-1] if press else lines[-3:]}")
        self.click(screen=self.d.project(sketch=[10, -70])["screen"])
        self.click(screen=wall)
        mark = self.mark()
        self.d.drag({"screen": a}, {"screen": b})
        lines = self.trace_from(mark)
        press = [ln for ln in lines if "press" in ln and "shift=" in ln]
        self.refresh("status")
        self.clause("plain replaces", "Selected 1" in self.S() and any("shift=0" in ln for ln in press), f"{self.S()} {press[-1] if press else ''}")
        self.d.drag({"screen": a}, {"screen": b})
        self.d.key("delete")
        after = int((self.refresh("sketch").get("sketch") or {}).get("entity_count") or 0)
        self.clause("cleanup", after <= before + 1, f"{before}->{after} {self.S()}")

    @row('A17', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_A17(self) -> None:
        self.click("rail:Line")
        try:
            self.click("variant:Centerline")
        except SxError:
            self.click("chip:Centerline")
        self.refresh("rail", "status")
        lit = self.lit_names()
        self.clause("chip lights Line", lit == ["Line"] or (len(lit) == 1 and "Line" in lit[0]), str(lit) + " " + self.S())
        self.click(sketch=[20, 20])
        self.click(sketch=[60, 20])
        self.refresh("status", "rail")
        self.clause("centerline", "Centerline added" in self.S() and self.lit_names() == ["Line"] or "Line" in "".join(self.lit_names()), f"{self.S()} lit={self.lit_names()}")
        self.d.key("ctrl+z")
        self.refresh("status", "rail")
        self.clause("undo line", self.S().startswith("Undo") and "Line" in "".join(self.lit_names()), f"{self.S()} {self.lit_names()}")
        self.d.key("ctrl+shift+z")
        self.refresh("status", "rail")
        self.clause("redo line", self.S().startswith("Redo") and "Line" in "".join(self.lit_names()), f"{self.S()} {self.lit_names()}")
        self.click("rail:Select")
        self.click(sketch=[40, 20])
        self.d.key("delete")

    @row('A9c', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_A9c(self) -> None:
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Up To Surface")
        try:
            self.click("finish:OppositeFace")
            face = self.bottom_face()
            self.click(face=face["id"])
        except SxError as exc:
            self.clause("opposite face", False, str(exc))
        self.refresh("finish", "status")
        path = self.save_as("pre-cut.sxp")
        self.clause("saved", "Saved" in self.S() and Path(path).exists(), self.S())
        self.refresh("finish", "sketch")
        self.clause("finish kept", self.field("finish:Op") == "Cut" and "Up To" in self.field("finish:End"), str(self.st.get("finish")))

    @row('N1b', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_N1b(self) -> None:
        texts = self.dim_texts()
        self.clause("same labels", sum(1 for t in texts if "45" in t and "°" in t) == 1 and any(t.strip().startswith("20") for t in texts), str(texts))
        dim = self.find_dim(lambda d: "20" in str(d.get("text", "")))
        if dim:
            self.d.click(dim=str(dim.get("text")), glyph="first")
            self.d.wait_idle(frames=2)
            self.refresh("measure", "status", "focus")
            texts_m = " ".join(str(m.get("text", "")) for m in (self.st.get("measure") or []))
            self.clause("editor has no delta", "Δ" not in texts_m, texts_m or self.S())
            focus = str(self.st.get("focus", ""))
            opened = self.control("dim:Edit") is not None or "DimEdit" in focus
            if opened:
                self.esc()

    @row('N20', chunk=3, expect={'blocker': 'A9c', 'sketch': True})
    def row_N20(self) -> None:
        path = self.out / "pre-cut.sxp"
        before = path.stat().st_mtime if path.exists() else 0
        time.sleep(1.1)
        self.save_as("pre-cut.sxp")
        after = path.stat().st_mtime if path.exists() else 0
        self.clause("overwritten", after > before, f"{before} -> {after} {self.S()}")
        self.refresh("finish")
        self.clause("finish stays", "Up To" in self.field("finish:End"), str(self.st.get("finish")))
        self.d.key("ctrl+z")
        self.refresh("status")
        self.clause("sketch undo", self.S().startswith("Undo"), self.S())
        self.d.key("ctrl+shift+z")

    @row('A9b', chunk=3, expect={'blocker': 'A9', 'sketch': True})
    def row_A9b(self) -> None:
        reply = self.click("finish:Extrude", frames=10)
        self.refresh("status", "bodies")
        self.clause("cut", "Extrude Up To Surface 10.0000 mm" in str(reply.get("status", self.S())), str(reply.get("status", self.S())))
        bodies = self.st.get("bodies") or []
        if bodies and bodies[0].get("min") and bodies[0].get("max"):
            ext = [bodies[0]["max"][i] - bodies[0]["min"][i] for i in range(3)]
            ok = abs(ext[0] - 232.5) <= 0.3 and abs(ext[1] - 45) <= 0.3 and abs(ext[2] - 10) <= 0.3
            self.clause("size", ok, str([round(v, 3) for v in ext]))
        else:
            self.clause("size", False, str(bodies))
        path = self.save_as("cut.sxp")
        self.clause("cut saved", Path(path).exists() and "Saved" in self.S(), self.S())
