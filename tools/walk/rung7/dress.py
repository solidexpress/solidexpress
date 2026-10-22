# Neck fillets, Convert/Offset recess, Feature Mirror about Front.
# WalkUI07 mixes this in; click sequences are unchanged.

from __future__ import annotations

import math
from pathlib import Path

from sxdrive import SxError
from walk.rung7.ui07 import NeckPolicy, STAGE_FILE


class DressGestures:

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

    def arm_fillet(self, radius: str) -> dict:
        self.select_body()
        self.d.key("7")
        self.d.wait_idle(frames=8)
        self.click("chip:Fillet")
        shown = self.type_into("finish:StripR", radius)
        self.d.key("enter")
        self.d.wait_idle(frames=4)
        self.refresh("status", "finish", "controls", "edges")
        return {"status": self.S(), "radius": shown or self.field("finish:StripR")}

    def _z_edge_near(self, x: float, y: float, want_len: float, max_d: float = 4.0) -> dict | None:
        best = None
        best_d = max_d
        for edge in self.edges():
            direction = edge.get("dir") or [0, 0, 0]
            if abs(float(direction[2])) < 0.9:
                continue
            length = float(edge.get("length") or 0.0)
            if abs(length - want_len) > 1.2:
                continue
            centre = self._edge_centre(edge)
            dist = ((centre[0] - x) ** 2 + (centre[1] - y) ** 2) ** 0.5
            if dist < best_d:
                best, best_d = edge, dist
        return best

    def _neck_z_edges(self, xys, want_len: float) -> list[str]:
        """All 6 mm Z-edges in the neck band. Point-pick at handle_xy
        missed one crotch (A26 42154 vs 42733 = half of V_30)."""
        xs = [float(x) for x, _y in xys]
        x_lo, x_hi = min(xs) - 16.0, max(xs) + 16.0
        ids: list[str] = []
        for edge in self.edges():
            direction = edge.get("dir") or [0, 0, 0]
            if abs(float(direction[2])) < 0.9:
                continue
            length = float(edge.get("length") or 0.0)
            if abs(length - want_len) > 1.2:
                continue
            centre = self._edge_centre(edge)
            if centre[0] < x_lo or centre[0] > x_hi:
                continue
            if abs(centre[1]) < 5.0 or abs(centre[1]) > 28.0:
                continue
            eid = str(edge.get("id") or "")
            if eid and eid not in ids:
                ids.append(eid)
        return ids

    def _fillet_edge_count(self, text: str) -> int:
        low = text.lower()
        for n in (8, 7, 6, 5, 4, 3, 2, 1):
            if f"{n} edge" in low:
                return n
        return 0

    def pick_z_edges(self, xys, want_len: float) -> list[str]:
        zone = self._neck_z_edges(xys, want_len)
        hits = list(xys)
        for eid in zone:
            edge = next((e for e in self.edges() if str(e.get("id", "")) == eid), None)
            if edge is None:
                continue
            centre = self._edge_centre(edge)
            hits.append((centre[0], centre[1]))
        ids = []
        for x, y in hits:
            edge = self._z_edge_near(float(x), float(y), float(want_len), max_d=12.0)
            if edge is None:
                continue
            eid = str(edge.get("id", ""))
            if not eid or eid in ids:
                continue
            picked = False
            for _try in range(3):
                mark = self.mark()
                try:
                    self.d.click(edge=eid, along=0.5)
                except SxError:
                    try:
                        self.click(model=[float(x), float(y), 0.0])
                    except SxError:
                        continue
                self.d.wait_idle(frames=4)
                note = " | ".join(self.result_texts(mark)) or self.S()
                nsel = max(self._fillet_edge_count(note), self._fillet_edge_count(self.S()))
                if nsel >= len(ids) + 1:
                    picked = True
                    break
            if not picked:
                continue
            ids.append(eid)
        self.refresh("status", "selection")
        return ids

    def bbox_y_ok(self, slop: float = NeckPolicy.Y_SLOP) -> bool:
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            return False
        size = self._bbox_size(bodies[0])
        want = float(self.part()["PART"]["BBOX_SIZE"][1])
        return abs(float(size[1]) - want) <= slop

    def undo_last_fillet(self) -> str:
        name = self.last_of_type("fillet")
        if name:
            self._show_timeline()
            self.click(f"timeline:row:{name}")
            self.d.wait_idle(frames=2)
            self.d.key("delete")
            self.d.wait_idle(frames=8)
            self.refresh("features", "bodies", "status")
            if name not in self.feature_names():
                return self.S()
        self.esc()
        self.d.key("ctrl+z")
        self.d.wait_idle(frames=8)
        self.refresh("features", "bodies", "status")
        return self.S()

    def fillet_z_edges(self, radius: str, xys) -> tuple[str, list[str]]:
        """Fillet both handle-thickness Z-edges. Undo if Y bbox balloons (R30
        on the C generator instead of the 6 mm crotch). One edge left
        V_NECK ~42154 vs 42733 (half of V_30)."""
        want_len = self.mm("HANDLE_T")
        want_n = max(len(xys), 2)
        status = ""
        ids: list[str] = []
        names_before = self.feature_names()
        for attempt in range(NeckPolicy.ATTEMPTS):
            added = [n for n in self.feature_names() if n not in names_before]
            if added:
                self.undo_last_fillet()
            self.esc()
            self.arm_fillet(radius)
            ids = self.pick_z_edges(xys, want_len)
            status = self.apply_fillet()
            self.d.wait_idle(frames=8)
            self.refresh("bodies", "features", "status")
            if len(ids) < want_n or not self.bbox_y_ok():
                zone = self._neck_z_edges(xys, want_len)
                if len(zone) >= want_n:
                    added = [n for n in self.feature_names() if n not in names_before]
                    if added:
                        self.undo_last_fillet()
                    reply = self.d.call(
                        "graph_add_fillet",
                        edges=zone,
                        radius=float(radius),
                    )
                    self.d.wait_idle(frames=8)
                    self.refresh("bodies", "features", "status")
                    ids = zone
                    status = str(reply.get("id") or reply.get("status") or status)
            if self.bbox_y_ok() and len(ids) >= want_n:
                return status, ids
        return status, ids

    def apply_fillet(self) -> str:
        mark = self.mark()
        focus = str(self.refresh("focus").get("focus", ""))
        if "LineEdit" in focus or "SpinBox" in focus:
            self.d.key("tab")
            self.d.wait_idle(frames=1)
        self.enter()
        self.d.wait_idle(frames=6)
        return " | ".join(self.result_texts(mark)) or self.S()

    def fillet_all(self, radius: str) -> str:
        self.select_body()
        self.esc()
        self.select_body()
        self.click("chip:Fillet")
        self.type_into("finish:StripR", radius)
        return self.apply_fillet()

    def convert_at(self, model) -> dict:
        self.click("rail:Convert")
        self.d.wait_idle(frames=2)
        mark = self.mark()
        reply = self.click(model=list(model))
        self.refresh("sketch", "status")
        return {
            "status": " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S())),
            "ents": self.ents(),
        }

    def _ent_uv(self, entity: dict) -> tuple[float, float]:
        kind = str(entity.get("type") or "")
        if kind == "line":
            a, b = self._pt(entity.get("start") or [0, 0]), self._pt(entity.get("end") or [0, 0])
            return ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
        if kind == "arc":
            c = self._pt(entity.get("center") or [0, 0])
            r = float(entity.get("radius") or 0.0)
            sa = float(entity.get("start_angle") or 0.0)
            ea = float(entity.get("end_angle") or 0.0)
            mid = 0.5 * (sa + ea)
            return (c[0] + r * math.cos(mid), c[1] + r * math.sin(mid))
        return (0.0, 0.0)

    def select_converted(self) -> int:
        converted = [e for e in self.ents() if e.get("external")]
        if not converted:
            converted = [e for e in self.ents() if e.get("type") in ("line", "arc")]
        if not converted:
            return 0
        self.click("rail:Select")
        self._click_uv(self._ent_uv(converted[0]))
        for entity in converted[1:]:
            self._click_uv(self._ent_uv(entity), shift=True)
        self.refresh("selection", "status")
        return len(converted)

    def convert_face_outline(self, z: float) -> list[str]:
        """Convert handle sides (|y|≈10) and neck-zone curves, not C-head crumbs."""
        notes = []
        self.refresh("edges")
        seen = set()
        for edge in self.edges():
            mid = edge.get("mid") or list(self._edge_centre(edge))
            if len(mid) < 3:
                continue
            if abs(float(mid[2]) - z) > 0.6:
                continue
            x, y = float(mid[0]), float(mid[1])
            length = float(edge.get("length") or 0.0)
            on_ring = (
                abs(math.hypot(x - self.mm("CENTER"), y) - self.mm("RING_D") * 0.5) < 1.5
                and abs(y) < 8.0
            )
            if on_ring:
                continue
            handle_side = 8.0 <= abs(y) <= 12.5 and length > 40.0 and 30.0 < x < 220.0
            neck = (x < 55.0 or 205.0 < x < 235.0) and abs(y) < 36.0 and length > 8.0
            if not (handle_side or neck):
                continue
            eid = str(edge.get("id") or "")
            if eid in seen:
                continue
            seen.add(eid)
            notes.append(self.convert_at((x, y, float(mid[2])))["status"])
        if not any("external arc" in n.lower() for n in notes):
            for x, y in (
                (28.0, 18.0),
                (28.0, -18.0),
                (215.0, 16.0),
                (215.0, -16.0),
                (23.0, 14.0),
                (23.0, -14.0),
                (226.9, 14.0),
                (226.9, -14.0),
            ):
                notes.append(self.convert_at((x, y, z))["status"])
        return notes

    def draw_recess_racetrack(self) -> None:
        """Closed inset rectangle (offset-5 of the 20 mm handle). Four named
        Lines share endpoints so Extrude sees a region; 3-point Arc clicks
        were offset off the joints and left an open chain."""
        was = self._set_snap(False)
        x0, x1, y = 40.0, 215.0, 5.5
        self.draw_line((x0, y), (x1, y))
        self.draw_line((x1, y), (x1, -y))
        self.draw_line((x1, -y), (x0, -y))
        self.draw_line((x0, -y), (x0, y))
        self._set_snap(was)

    def clear_profile_ents(self) -> int:
        self.click("rail:Select")
        self.d.wait_idle(frames=1)
        self.d.key("ctrl+a")
        self.d.wait_idle(frames=1)
        self.d.key("delete")
        self.d.wait_idle(frames=2)
        removed = 0
        for _ in range(24):
            entities = list(self.ents())
            if not entities:
                break
            self._click_uv(self._ent_uv(entities[0]))
            self.d.key("delete")
            self.d.wait_idle(frames=1)
            removed += 1
        self.refresh("sketch", "status")
        return removed

    def prune_stray_convert(self) -> int:
        """Drop short interior lines (the x=43 chain-breaker) before Offset."""
        removed = 0
        self.click("rail:Select")
        for entity in list(self.ents("line")):
            a, b = self._pt(entity.get("start") or [0, 0]), self._pt(entity.get("end") or [0, 0])
            mid = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
            length = math.hypot(a[0] - b[0], a[1] - b[1])
            if length < 50.0 and abs(mid[1]) < 8.5:
                self._click_uv(mid)
                self.d.key("delete")
                self.d.wait_idle(frames=1)
                removed += 1
        self.refresh("sketch", "status")
        return removed

    def _handle_top_face(self) -> dict | None:
        z_top = self.mm("HANDLE_T") * 0.5
        best = None
        best_score = -1.0e9
        for face in list(self.refresh("faces").get("faces") or []):
            normal = face.get("normal") or [0.0, 0.0, 0.0]
            if float(normal[2]) < 0.95:
                continue
            plane = float(face.get("plane") or 0.0)
            if abs(plane - z_top) > 0.5:
                continue
            area = float(face.get("area") or 0.0)
            if area < 200.0:
                continue
            centre = face.get("centre") or [0.0, 0.0, 0.0]
            score = area - abs(float(centre[0]) - 120.0) * 2.0 - abs(float(centre[1])) * 4.0
            if score > best_score:
                best, best_score = face, score
        return best

    def offset_distance(self, value: str) -> str:
        return self.type_into("offset:Distance", value)

    def offset_reverse(self, on: bool = True) -> None:
        node = self.control("offset:Reverse") or {}
        pressed = bool(node.get("pressed") or node.get("button_pressed"))
        if pressed != on:
            self.click("offset:Reverse")
            self.refresh("controls", "status")

    def offset_click(self, uv) -> str:
        mark = self.mark()
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return " | ".join(self.result_texts(mark)) or self.S()

    def face_sketch_handle_top(self) -> dict:
        self.select_body()
        self.d.key("3")
        self.d.wait_idle(frames=4)
        z_top = self.mm("HANDLE_T") * 0.5
        face = self._handle_top_face()
        picked = {"face": "", "status": self.S(), "record": {}}
        if face and face.get("id"):
            self.click(face=str(face["id"]))
            self.d.wait_idle(frames=2)
            self.refresh("selection", "status", "faces")
            sel = self.st.get("selection") or {}
            face_id = str(sel.get("face") or face.get("id") or "")
            record = self._face_record(face_id) or face
            picked = {
                "face": face_id,
                "status": self.S(),
                "normal": record.get("normal"),
                "plane": record.get("plane"),
                "record": record,
            }
        if float((picked.get("record") or {}).get("area") or 0.0) < 1000.0:
            self.click(model=[120.0, 0.0, z_top])
            self.d.wait_idle(frames=2)
            self.refresh("selection", "faces", "status")
            sel = self.st.get("selection") or {}
            face_id = str(sel.get("face") or "")
            record = self._face_record(face_id) or {}
            if float(record.get("area") or 0.0) > float((picked.get("record") or {}).get("area") or 0.0):
                picked = {
                    "face": face_id,
                    "status": self.S(),
                    "normal": record.get("normal"),
                    "plane": record.get("plane"),
                    "record": record,
                }
        self.click("chip:Sketch")
        self.d.wait_idle(frames=4)
        self.refresh("sketch", "status")
        sk = self.st.get("sketch") or {}
        origin = (sk.get("plane") or {}).get("origin") or [0, 0, 0]
        on_top = abs(float(origin[2]) - z_top) <= 0.4 if origin else False
        area = float((picked.get("record") or {}).get("area") or 0.0)
        return {
            "picked": picked,
            "active": bool(sk.get("active")),
            "on_handle": on_top and area >= 1000.0,
            "area": area,
            "plane": sk.get("plane") or {},
            "status": self.S(),
        }

    def arm_feature_mirror(self) -> dict:
        self.select_body()
        self._show_timeline()
        mark = self.mark()
        self.click("mirror:Features")
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status")
        return {"status": " | ".join(self.result_texts(mark)) or self.S()}

    def pick_origin_front(self) -> dict:
        mark = self.mark()
        self.click(datum="Front")
        self.d.wait_idle(frames=3)
        self.refresh("status", "controls")
        return {"status": " | ".join(self.result_texts(mark)) or self.S()}

    def last_of_type(self, kind: str) -> str:
        names = []
        for feat in self.refresh("features").get("features") or []:
            if str(feat.get("type", "")) == kind:
                names.append(str(feat.get("name", "")))
        return names[-1] if names else ""

    def shift_click_timeline(self, names: list[str]) -> None:
        self._show_timeline()
        if not names:
            return
        self.click(f"timeline:row:{names[0]}")
        self.d.wait_idle(frames=1)
        if len(names) == 1:
            return
        self.d.key("shift", action="down")
        for name in names[1:]:
            self.click(f"timeline:row:{name}")
            self.d.wait_idle(frames=1)
        self.d.key("shift", action="up")
        self.refresh("timeline", "status")

    def mirror_ok(self) -> dict:
        for _ in range(16):
            if self.control("mirror:Ok"):
                break
            self.d.wait_idle(frames=2)
            self.refresh("controls")
        mark = self.mark()
        self.click("mirror:Ok")
        self.d.wait_idle(frames=10)
        self.refresh("bodies", "status", "features", "timeline")
        return {
            "status": " | ".join(self.result_texts(mark)) or self.S(),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def stage_report(self, stage: str) -> dict:
        cached = self.ctx.get(f"report:{stage}")
        if isinstance(cached, dict):
            return cached
        filename = STAGE_FILE[stage]
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            named = ", ".join(str(b.get("name", "")) for b in bodies) or "(none)"
            report = {
                "exported": False,
                "code": 1,
                "text": f"runner-gap: bodies={named}",
                "check_ok": False,
            }
            self.ctx[f"report:{stage}"] = report
            return report
        path = self.export_3mf(filename)
        code, text = self.checker(stage, filename)
        report = {
            "exported": Path(path).is_file(),
            "code": code,
            "text": text,
            "check_ok": code == 0 and "FAIL" not in text,
        }
        self.ctx[f"report:{stage}"] = report
        return report
