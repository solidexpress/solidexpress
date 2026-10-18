# Top-disc pick, drafted Blind cut, Swept Boss arm and timeline picks.
# WalkUI06 mixes this in; click sequences are unchanged.

from __future__ import annotations

from sxdrive import SxError


class CutGestures:

    def pick_top_disc(self, orient: bool = True) -> dict:
        if orient:
            self.d.key("3")
            self.d.wait_idle(frames=6)
        self.refresh("faces")
        disc = None
        disc_err = 1e9
        want_area = 3.1415926535 * 20.0 * 20.0
        for face in list(self.st.get("faces") or []):
            n = face.get("normal") or [0.0, 0.0, 0.0]
            c = face.get("centre") or [0.0, 0.0, 0.0]
            if len(n) < 3 or len(c) < 2:
                continue
            ny = float(n[1])
            y = float(c[1])
            area = float(face.get("area") or 0.0)
            if ny < 0.85 or abs(y - 220.0) > 6.0:
                continue
            if area < 400.0 or area > 2500.0:
                continue
            err = abs(ny - 1.0) * 200.0 + abs(y - 220.0) + abs(area - want_area) * 0.01
            if err < disc_err:
                disc_err = err
                disc = face
        best = disc
        if best and best.get("id"):
            screen = best.get("screen") or best.get("pick")
            if screen:
                self.click(screen=screen)
                self.d.wait_idle(frames=2)
            self.click(face=str(best["id"]))
            self.d.wait_idle(frames=2)
            self.refresh("selection", "status", "faces")
            sel = self.st.get("selection") or {}
            if not sel.get("face"):
                if screen:
                    self.click(screen=screen)
                    self.d.wait_idle(frames=2)
                self.click(face=str(best["id"]))
                self.d.wait_idle(frames=2)
                self.refresh("selection", "status", "faces")
                sel = self.st.get("selection") or {}
            face_id = str(sel.get("face") or "")
            record = self._face_record(face_id) or (best if face_id == str(best.get("id") or "") else {})
            return {
                "face": face_id,
                "status": self.S(),
                "normal": (record or {}).get("normal"),
                "plane": (record or {}).get("plane"),
                "record": record,
            }
        return {"face": "", "status": self.S(), "normal": None, "plane": None, "record": {}}


    def _plane_on_top_disc(self) -> bool:
        plane = (self.refresh("sketch").get("sketch") or {}).get("plane") or {}
        origin = plane.get("origin") or [0.0, 0.0, 0.0]
        normal = plane.get("normal") or [0.0, 0.0, 0.0]
        if len(origin) < 2 or len(normal) < 2:
            return False
        return abs(float(origin[1]) - 220.0) <= 2.0 and abs(float(normal[1]) - 1.0) <= 0.08


    def select_body(self) -> str:
        self.refresh("bodies", "selection")
        if str((self.st.get("selection") or {}).get("body") or ""):
            return self.S()
        bodies = self.st.get("bodies") or []
        if not bodies:
            return self.S()
        screen = bodies[0].get("screen")
        if screen:
            self.click(screen=screen)
            self.d.wait_idle(frames=2)
            self.refresh("selection", "status")
        return self.S()


    def open_top_disc_sketch(self) -> dict:
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        self.esc()
        self.d.wait_idle(frames=4)
        picked = self.pick_top_disc(orient=True)
        self.d.wait_idle(frames=4)
        if picked.get("face"):
            look = self.control("Look at")
            if look:
                self.click("Look at")
                self.d.wait_idle(frames=4)
        self.click("rail:Sketch")
        self.d.wait_idle(frames=4)
        self.refresh("sketch", "status")
        if not self._plane_on_top_disc():
            if bool((self.st.get("sketch") or {}).get("active")):
                self.exit_sketch()
            # Pick-host path: Sketch is armed, click the disc without re-framing.
            picked = self.pick_top_disc(orient=False)
            self.d.wait_idle(frames=4)
            if not self._plane_on_top_disc():
                self.click("rail:Sketch")
                self.d.wait_idle(frames=3)
                picked = self.pick_top_disc(orient=False)
                self.d.wait_idle(frames=4)
            if not bool((self.refresh("sketch").get("sketch") or {}).get("active")):
                if self.control("chip:Sketch"):
                    self.click("chip:Sketch")
                    self.d.wait_idle(frames=4)
            self.refresh("sketch", "status")
        return {
            "picked": picked,
            "active": bool((self.st.get("sketch") or {}).get("active")),
            "on_disc": self._plane_on_top_disc(),
            "status": self.S(),
            "plane": (self.st.get("sketch") or {}).get("plane") or {},
        }


    def ensure_disc_cut_sketch(self) -> dict:
        """Re-enter the Ø30 top-disc sketch, or draw it if A30 did not land."""
        if self._plane_on_top_disc():
            return {"on_disc": True, "status": self.S()}
        if bool((self.refresh("sketch").get("sketch") or {}).get("active")):
            self.exit_sketch()
        for name in reversed(self.sketch_names()):
            self._pencil(name)
            if self._plane_on_top_disc():
                return {"on_disc": True, "status": self.S(), "name": name}
            if bool((self.st.get("sketch") or {}).get("active")):
                self.exit_sketch()
        opened = self.open_top_disc_sketch()
        if opened.get("on_disc") and not self.ents("circle"):
            self.circle([0.0, 0.0], rim=[15.0, 0.0])
            self.dimension_diameter("30")
        return opened


    def discard_active_sketch(self) -> None:
        """Leave part mode without committing a throwaway (N4 75° refuse)."""
        for _ in range(10):
            sketch = (self.refresh("sketch").get("sketch") or {})
            if not bool(sketch.get("active")):
                return
            if self.control("rail:Select"):
                try:
                    self.click("rail:Select")
                except SxError:
                    pass
            self.esc()
            self.d.wait_idle(frames=2)
        sketch = (self.refresh("sketch").get("sketch") or {})
        if not bool(sketch.get("active")):
            return
        if int(sketch.get("entity_count") or 0) == 0:
            self.exit_sketch()


    def try_extrude_cut(self, distance: str, draft: str | None = "15") -> dict:
        self._ensure_finish_bar()
        self.set_option("finish:Op", "Cut")
        self.d.wait_idle(frames=2)
        self.set_option("finish:End", "Blind")
        shown = self.type_into("finish:Distance", distance)
        if draft is not None:
            for _ in range(3):
                toggle = self.control("finish:Draft")
                if toggle and toggle.get("pressed"):
                    break
                try:
                    self.click("finish:Draft")
                except SxError:
                    break
                self.d.wait_idle(frames=2)
            self.type_into("finish:DraftAngle", draft)
            self.d.wait_idle(frames=2)
        shown_draft = self.field("finish:DraftAngle")
        mark = self.mark()
        reply = self.click("finish:Extrude", frames=8)
        self.d.wait_idle(frames=8)
        results = self.result_texts(mark)
        self.refresh("status", "sketch", "finish", "bodies", "features")
        bodies = list(self.st.get("bodies") or [])
        if not bodies:
            self.d.wait_idle(frames=8)
            self.refresh("bodies", "status", "features", "sketch")
            bodies = list(self.st.get("bodies") or [])
        return {
            "field": shown,
            "draft": shown_draft or self.field("finish:DraftAngle"),
            "reply": reply,
            "results": results,
            "status": " | ".join(results) or str(reply.get("status", self.S())),
            "sketch": bool((self.st.get("sketch") or {}).get("active")),
            "bodies": bodies,
            "names": self.feature_names(),
        }


    def arm_sweep(self) -> None:
        """Swept Boss lives on the palette, which hides while a body is selected."""
        self.clear_faces()
        self.d.wait_idle(frames=2)
        self.click("sweep:Boss")
        self.d.wait_idle(frames=3)


    def pick_timeline(self, name: str) -> None:
        self._show_timeline()
        self.click(f"timeline:row:{name}")
        self.d.wait_idle(frames=2)


    def sketch_names(self) -> list[str]:
        return [n for n in self.feature_names() if str(n).lower().startswith("sketch")]


    def sketch_roles(self) -> list[str]:
        feats = self.refresh("features").get("features") or []
        out = []
        for f in feats:
            if str(f.get("type", "")) == "sketch":
                out.append(str(f.get("role") or ""))
        return out
