"""Rung-5 gestures: Front cylinder, two-face shell, circular pattern, feature mirror.

Rows call these helpers. Face picks are the FACES table; plane= is n·pick.
"""
from __future__ import annotations

import sys
from pathlib import Path

from sxdrive import SxError
from walk import proc
from walk.chrome import WalkChrome
from walk.gates import parse_tier, run_kernel, run_tier, take

PINNED_NEW = "New — empty part, Top plane (XY). View ▸ Timeline to edit features"

# name -> (normal, world_z, view_key). plane_offset = n · (0,0,z).
FACES = {
    "cyl_plus":  ((0.0, 0.0, 1.0), 250.0, "3"),
    "cyl_minus": ((0.0, 0.0, -1.0), 0.0, "8"),
    "flange":    ((0.0, 0.0, 1.0), 250.0, "3"),
    "cut":       ((0.0, 0.0, 1.0), 260.0, "3"),
    "mirror":    ((0.0, 0.0, -1.0), 0.0, "8"),
    "reshell":   ((0.0, 0.0, -1.0), -260.0, "8"),
    "fillet_p":  ((0.0, 0.0, 1.0), 260.0, "3"),
    "fillet_m":  ((0.0, 0.0, -1.0), -260.0, "8"),
}

# Export rows share one 3MF per stage (decision 11 checkpoints are .sxp).
STAGE_FILE = {
    "cyl": "cyl.3mf",
    "shelled": "shelled.3mf",
    "cut": "cut.3mf",
    "mirror": "mirror.3mf",
    "reshell": "reshell.3mf",
    "final": "final.3mf",
}

# Timeline collector for feature-mirror: first extrude, shell, flange, cut.
MIRROR_TYPES = ("extrude", "shell", "extrude", "extrude")


def plane_of(normal, world_z: float) -> float:
    return float(normal[2]) * float(world_z)


class WalkUI05(WalkChrome):
    _INTENDED = (
        "Dimension must be a positive number",
        "limit",
        "nothing added",
        "Pattern: count must be at least 2",
        "Pattern needs a selection",
        "Mirror: pick features",
        "fillet failed",
        "Fillet could not be built",
        "could not be built",
        "regenerate stopped at feature fillet",
    )

    def part(self) -> dict:
        return WalkChrome.part(self, "check_rung05.py")

    def mm(self, key: str) -> float:
        return float(self.part()["PART"][key])

    def sketch_on_datum(self, name: str, view_key: str) -> dict:
        self.d.key(view_key)
        self.d.wait_idle(frames=2)
        self.click("rail:Sketch")
        self.refresh("status")
        self.click(datum=name)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "camera")
        sk = self.st.get("sketch") or {}
        return {
            "status": self.S(),
            "active": bool(sk.get("active")),
            "plane": sk.get("plane") or {},
        }

    def construction_circles(self) -> list[dict]:
        self.refresh("sketch")
        return [
            e for e in self._entities()
            if e.get("type") == "circle" and e.get("construction")
        ]

    def draw_circle(self, centre=(0.0, 0.0), rim=(75.0, 0.0)) -> dict:
        dx = float(rim[0]) - float(centre[0])
        dy = float(rim[1]) - float(centre[1])
        radius = (dx * dx + dy * dy) ** 0.5
        self.show_sketch_point(centre)
        # Ø10 is ~14 px after flange fit; a rim click does not commit. Type it.
        if radius < 20.0:
            made = self.circle(list(centre), radius=f"{radius:g}")
        else:
            made = self.circle(list(centre), rim=list(rim))
        return {
            "status": made["status"] if isinstance(made, dict) else str(made),
            "circles": self.profile_circles(),
        }

    def _dim_cids(self) -> set[str]:
        found: set[str] = set()
        for dim in self.dims():
            raw = dim.get("raw") or {}
            cid = str(raw.get("cid") or dim.get("cid") or "")
            if cid:
                found.add(cid)
        return found

    def _newest_dim(self, before: set[str]) -> dict | None:
        newest = None
        for dim in self.dims():
            raw = dim.get("raw") or {}
            cid = str(raw.get("cid") or dim.get("cid") or "")
            if cid and cid not in before:
                newest = dim
        return newest

    def _commit_dim_editor(self) -> None:
        if self._dim_editor_open():
            self.enter()
            self.d.wait_idle(frames=1)

    def _drive_new_dim(self, before: set[str], value: str) -> None:
        dim = self._newest_dim(before)
        if dim is None:
            self._commit_dim_editor()
            return
        if not self._dim_editor_open():
            self.open_label(dim)
        self._type_dim_editor(value)
        self.enter()

    def dimension_diameter(self, value: str, centre=None) -> dict:
        circles = self.profile_circles()
        if centre is not None:
            circles = [
                c for c in circles
                if abs(float(c["center"][0]) - centre[0]) <= 0.5
                and abs(float(c["center"][1]) - centre[1]) <= 0.5
            ]
        if not circles:
            return {"texts": self.dim_texts(), "status": "no circle"}
        self._commit_dim_editor()
        before = self._dim_cids()
        rim = self._rim_of(circles[-1]["center"])
        self.click("rail:SmartDim")
        self.show_sketch_point(rim)
        self.click(sketch=rim)
        self.d.wait_idle(frames=2)
        self.refresh("dims", "status")
        self._drive_new_dim(before, value)
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def _rim_of(self, centre) -> list[float]:
        cx, cy = float(centre[0]), float(centre[1])
        for circle in self.profile_circles():
            cc = circle["center"]
            if abs(float(cc[0]) - cx) <= 0.5 and abs(float(cc[1]) - cy) <= 0.5:
                radius = float(circle.get("radius") or 5)
                # −X stays on the 1280 canvas after sketch-fit (the +X Ø130
                # rim lands at x≈1282 and becomes a drag).
                return [cx - radius, cy]
        return [cx, cy]

    def dimension_centres(self, a, b, value: str) -> dict:
        self._commit_dim_editor()
        before = self._dim_cids()
        self.click("rail:SmartDim")
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.show_sketch_point(b)
        self.click(sketch=list(b))
        self.d.wait_idle(frames=3)
        self.refresh("dims", "status")
        self._drive_new_dim(before, value)
        self.refresh("dims", "dof", "status")
        return {"texts": self.dim_texts(), "status": self.S()}

    def last_index(self, items, value) -> int:
        for i in range(len(items) - 1, -1, -1):
            if items[i] == value:
                return i
        return -1

    def vertical_centres(self, a, b) -> dict:
        self.click("rail:Select")
        self.d.wait_idle(frames=2)
        # Centres are region fills on a face sketch. The +X Ø130 rim sits off
        # the 1280 window after fit; the −X rim and hole +X rim stay on canvas.
        pa = self._rim_of(a)
        pb = self._rim_of(b)
        self.show_sketch_point(pa)
        self.click(sketch=pa)
        self.d.wait_idle(frames=2)
        self.show_sketch_point(pb)
        self.d.key("shift", action="down")
        self.d.wait_idle(frames=2)
        self.click(sketch=pb)
        self.d.key("shift", action="up")
        self.d.wait_idle(frames=4)
        self.refresh("controls", "status", "selection")
        self.click_verb("Vertical")
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dof")
        return {"status": self.S(), "dof": self.dof_text()}

    def hole_ring(self) -> list[dict]:
        pcd = self.mm("PCD")
        hole_r = self.mm("HOLE_D") * 0.5
        found = []
        for circle in self.profile_circles():
            cx, cy = float(circle["center"][0]), float(circle["center"][1])
            radius = float(circle.get("radius") or 0)
            pitch = (cx * cx + cy * cy) ** 0.5
            if abs(pitch - pcd) <= 0.2 and abs(radius - hole_r) <= 0.2:
                found.append(circle)
        return found

    def try_extrude(
        self, distance: str, op: str = "New", end: str = "Blind", apply: bool = True,
    ) -> dict:
        self._ensure_finish_bar()
        self.set_option("finish:Op", op)
        self.set_option("finish:End", end)
        shown = self.type_into("finish:Distance", distance)
        self.refresh("finish")
        op_text = self.field("finish:Op")
        end_text = self.field("finish:End")
        if op_text == "" or end_text == "":
            self.d.wait_idle(frames=3)
            self.refresh("finish")
            op_text = self.field("finish:Op") or op_text
            end_text = self.field("finish:End") or end_text
        mark = self.mark()
        reply = self.click("finish:Extrude", frames=8) if apply else {}
        if apply:
            self.d.wait_idle(frames=8)
        results = self.result_texts(mark) if apply else []
        self.refresh("status", "sketch", "finish", "bodies")
        bodies = list(self.st.get("bodies") or [])
        return {
            "field": shown,
            "op": op_text,
            "end": end_text,
            "reply": reply,
            "results": results,
            "status": " | ".join(results) or str(reply.get("status", self.S())),
            "sketch": bool((self.refresh("sketch").get("sketch") or {}).get("active")),
            "bodies": bodies,
            "names": self.feature_names(),
        }

    def select_body(self) -> str:
        self.refresh("bodies", "selection")
        if str((self.st.get("selection") or {}).get("body") or ""):
            return self.S()
        bodies = self.st.get("bodies") or []
        if not bodies:
            raise SxError("no body to select")
        screen = bodies[0].get("screen")
        if not screen:
            z = self.mm("L0") * 0.5
            screen = self.d.project(model=[0, 0, z])["screen"]
        self.click(screen=screen)
        self.refresh("selection", "status")
        return self.S()

    def select_face(self, normal, plane=None) -> dict:
        fields: dict = {"face_normal": list(normal)}
        if plane is not None:
            fields["plane"] = float(plane)
        reply = self.click(**fields)
        self.refresh("selection", "status", "faces")
        sel = self.st.get("selection") or {}
        if not sel.get("face"):
            reply = self.click(**fields)
            self.refresh("selection", "status", "controls", "faces")
            sel = self.st.get("selection") or {}
        else:
            self.refresh("controls", "faces")
        face_id = str(sel.get("face") or "")
        record = self._face_record(face_id)
        return {
            "face": face_id,
            "status": str(reply.get("status", self.S())),
            "normal": reply.get("normal") or (record or {}).get("normal"),
            "plane": (record or {}).get("plane"),
            "record": record,
        }

    def pick_face(self, key: str, shift: bool = False) -> dict:
        normal, world_z, view = FACES[key]
        self.view_key(view)
        self.d.wait_idle(frames=6)
        plane = plane_of(normal, world_z)
        if shift:
            return self.shift_click_face(normal, plane)
        return self.select_face(normal, plane=plane)

    def shift_click_face(self, normal, plane: float) -> dict:
        self.d.key("shift", action="down")
        self.d.wait_idle(frames=1)
        mark = self.mark()
        fields = {"face_normal": list(normal), "plane": float(plane)}
        reply = self.click(**fields)
        status = " | ".join(self.result_texts(mark)) or str(reply.get("status", self.S()))
        self.d.key("shift", action="up")
        self.d.wait_idle(frames=1)
        self.refresh("status", "selection")
        sel = self.st.get("selection") or {}
        faces = list(sel.get("faces") or [])
        return {
            "status": status,
            "count": self.fillet_count(status),
            "faces": faces,
            "face": str(sel.get("face") or ""),
        }

    def selected_faces(self) -> list:
        sel = (self.refresh("selection").get("selection") or {})
        return list(sel.get("faces") or [])

    def face_sketch(self, key: str) -> dict:
        self.ctx["camera_before_sketch"] = dict(self.refresh("camera").get("camera") or {})
        self.select_body()
        selected = self.pick_face(key)
        camera = dict(self.refresh("camera").get("camera") or {})
        self.click("chip:Sketch")
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        sk = self.st.get("sketch") or {}
        return {
            "selected": selected,
            "camera": camera,
            "active": bool(sk.get("active")),
            "plane": sk.get("plane") or {},
            "status": self.S(),
        }

    def apply_shell(self, text: str) -> dict:
        self.click("strip:shell")
        self.refresh("controls")
        shown = self.type_into("finish:Thickness", text)
        mark = self.mark()
        self.click("finish:Ok")
        self.d.wait_idle(frames=8)
        results = self.result_texts(mark)
        field = str((self.control("finish:Thickness") or {}).get("text", ""))
        return {
            "shown": shown,
            "field": field,
            "status": " | ".join(results) or self.S(),
            "names": self.feature_names(),
        }

    def shell_both_ends(self, thickness: str) -> dict:
        self.view_key("7")
        self.d.wait_idle(frames=2)
        self.select_body()
        first = self.pick_face("cyl_plus")
        second = self.pick_face("cyl_minus", shift=True)
        faces = self.selected_faces()
        if len(faces) < 2 and second.get("face") and first.get("face"):
            faces = [first["face"], second["face"]]
        made = self.apply_shell(thickness)
        made["faces"] = faces
        made["first"] = first
        made["second"] = second
        return made

    def refuse_shell(self, thickness: str) -> dict:
        before = self.feature_names()
        size = self.body_size()
        self.d.key("ctrl+z")
        self.d.wait_idle(frames=6)
        self.refresh("features", "bodies", "status")
        tried = self.shell_both_ends(thickness)
        field = tried["field"] or str((self.control("finish:Thickness") or {}).get("text", ""))
        restored = self.apply_shell("10") if (
            "limit" in tried["status"].lower() or "nothing added" in tried["status"].lower()
        ) else tried
        return {
            "tried": tried,
            "before": before,
            "after": self.feature_names(),
            "size": size,
            "field": field,
            "status": tried["status"],
            "restored": restored,
        }

    def arm_circular_pattern(self) -> dict:
        self.click("rail:Pattern")
        self.refresh("controls", "status")
        self.click("variant:Circular")
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status")
        variant = self.control("variant:Circular") or {}
        return {
            "status": self.S(),
            "pressed": bool(variant.get("pressed") or variant.get("lit")),
            "count": self.control("pattern:Count"),
            "angle": self.control("pattern:Angle"),
        }

    def pattern_ok(self, count: str, angle: str) -> dict:
        shown_c = self.type_into("pattern:Count", count)
        shown_a = self.type_into("pattern:Angle", angle)
        mark = self.mark()
        self.click("pattern:Ok")
        self.d.wait_idle(frames=4)
        results = self.result_texts(mark)
        field = str((self.control("pattern:Count") or {}).get("text", ""))
        return {
            "count": shown_c,
            "angle": shown_a,
            "field": field,
            "status": " | ".join(results) or self.S(),
            "holes": self.hole_ring(),
            "profile": self.profile_circles(),
            "layout": self.construction_circles(),
        }

    def _seed_circle(self) -> dict | None:
        holes = self.hole_ring()
        if holes:
            on_y = [
                h for h in holes
                if abs(float(h["center"][0])) <= 0.5 and float(h["center"][1]) > 0.0
            ]
            return on_y[0] if on_y else holes[0]
        pcd = self.mm("PCD")
        ranked: list[tuple[float, dict]] = []
        for circle in self.profile_circles():
            cx, cy = float(circle["center"][0]), float(circle["center"][1])
            pitch = (cx * cx + cy * cy) ** 0.5
            if abs(pitch - pcd) > 0.5:
                continue
            ranked.append((float(circle.get("radius") or 1e9), circle))
        ranked.sort(key=lambda item: item[0])
        return ranked[0][1] if ranked else None

    def select_seed(self) -> None:
        self.click("rail:Select")
        self.d.wait_idle(frames=2)
        seed = self._seed_circle()
        if seed is None:
            rim = self._rim_of((0.0, self.mm("PCD")))
        else:
            rim = self._rim_of(seed["center"])
        self.show_sketch_point(rim)
        self.click(sketch=rim)
        self.d.wait_idle(frames=2)
        sel = (self.refresh("selection").get("selection") or {})
        if not (sel.get("sketch") or sel.get("entities")):
            hole_r = self.mm("HOLE_D") * 0.5
            self.click(sketch=[0.0, self.mm("PCD") + hole_r])
        self.refresh("selection", "status")

    def mirror_source_names(self) -> list[str]:
        by_type: dict[str, list[str]] = {}
        for feat in self.refresh("features").get("features") or []:
            kind = str(feat.get("type", ""))
            name = str(feat.get("name", ""))
            if name:
                by_type.setdefault(kind, []).append(name)
        names = []
        used: dict[str, int] = {}
        for kind in MIRROR_TYPES:
            idx = used.get(kind, 0)
            pool = by_type.get(kind, [])
            if idx < len(pool):
                names.append(pool[idx])
            used[kind] = idx + 1
        return names

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

    def arm_feature_mirror(self) -> dict:
        self.select_body()
        self._show_timeline()
        mark = self.mark()
        self.click("mirror:Features")
        self.d.wait_idle(frames=2)
        self.refresh("controls", "status")
        return {"status": " | ".join(self.result_texts(mark)) or self.S()}

    def mirror_ok(self) -> dict:
        for _ in range(16):
            if self.control("mirror:Ok"):
                break
            self.d.wait_idle(frames=2)
            self.refresh("controls")
        mark = self.mark()
        self.click("mirror:Ok")
        self.d.wait_idle(frames=10)
        results = self.result_texts(mark)
        self.refresh("bodies", "status", "features", "timeline")
        return {
            "status": " | ".join(results) or self.S(),
            "bodies": list(self.st.get("bodies") or []),
            "names": self.feature_names(),
        }

    def arm_fillet(self, radius: str = "5") -> dict:
        self.select_body()
        self.click("chip:Fillet")
        shown = self.type_into("finish:StripR", radius)
        self.d.key("enter")
        self.d.wait_idle(frames=2)
        self.refresh("status", "finish", "controls")
        return {"status": self.S(), "radius": shown or self.field("finish:StripR")}

    def rects_overlap(self, a, b) -> bool:
        if len(a) < 4 or len(b) < 4:
            return False
        return (
            a[0] < b[0] + b[2]
            and b[0] < a[0] + a[2]
            and a[1] < b[1] + b[3]
            and b[1] < a[1] + a[3]
        )

    def z_extent(self) -> tuple[float, float] | None:
        bodies = list(self.refresh("bodies").get("bodies") or [])
        if len(bodies) != 1:
            return None
        mn = bodies[0].get("min") or [0, 0, 0]
        mx = bodies[0].get("max") or [0, 0, 0]
        return float(mn[2]), float(mx[2])

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
        check_ok = code == 0 and "FAIL" not in text
        report = {
            "exported": Path(path).is_file(),
            "code": code,
            "text": text,
            "check_ok": check_ok,
        }
        self.ctx[f"report:{stage}"] = report
        return report

    def headless(self) -> dict[str, dict]:
        keys = ("kernel", "godot", "lint", "unit", "registry", "errors")
        if not self.run_a15:
            blocked = "BLOCKED-by-flag: pass --a15"
            return {key: {"ok": False, "evidence": blocked} for key in keys}
        errors = self.log_errors()
        owned = take("kernel")
        if owned is not None:
            return self._headless_report(
                owned,
                run_tier(self),
                take("lint_suites"),
                take("unit_rung05"),
                take("registry"),
                errors,
            )
        self._release_project()
        try:
            kernel = run_kernel(self.repo)
            godot = run_tier(self)
            lint = proc.run([sys.executable, "tools/lint_suites.py"], cwd=self.repo)
            unit = proc.run([sys.executable, "tools/test_check_rung05.py"], cwd=self.repo)
            registry = proc.run([sys.executable, "tools/test_walk_registry.py"], cwd=self.repo)
        finally:
            if getattr(self, "proc", None) is None or self.proc.poll() is not None:
                self.launch()
        return self._headless_report(kernel, godot, lint, unit, registry, errors)

    def _headless_report(self, kernel, godot, lint, unit, registry, errors) -> dict[str, dict]:
        godot_text = (godot.stdout or "") + (godot.stderr or "")
        (self.out / "a25-godot.log").write_text(godot_text)
        (self.out / "a25-kernel.log").write_text((kernel.stdout or "") + (kernel.stderr or ""))
        ran = parse_tier(godot_text)
        return {
            "kernel": {"ok": kernel.returncode == 0, "evidence": proc.tail(kernel.stdout, kernel.stderr)},
            "godot": {
                "ok": ran is not None and ran[1] == 0,
                "evidence": (
                    f"suites: {ran[0]} run, {ran[1]} failed"
                    if ran else proc.tail(godot.stdout, godot.stderr)
                ),
            },
            "lint": {"ok": lint.returncode == 0, "evidence": proc.tail(lint.stdout, lint.stderr)},
            "unit": {"ok": unit.returncode == 0, "evidence": proc.tail(unit.stdout, unit.stderr)},
            "registry": {
                "ok": registry.returncode == 0,
                "evidence": proc.tail(registry.stdout, registry.stderr),
            },
            "errors": {"ok": not errors, "evidence": "; ".join(errors[:3]) or "none"},
        }
