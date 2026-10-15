"""Rung-4 gestures: origin hex, Right-plane path, Swept Boss.

Rows call these helpers. Pixel positions come from project(), never literals.
"""
from __future__ import annotations

import math
import subprocess
import sys
from pathlib import Path

from sxdrive import SxError
from walk import proc
from walk.chrome import WalkChrome
from walk.gates import parse_tier, run_kernel, run_tier, take

PINNED_NEW = "New — empty part, Top plane (XY). View ▸ Timeline to edit features"


class WalkUI04(WalkChrome):
    _INTENDED = (
        "Dimension must be a positive number",
        "Select a profile sketch and a path sketch",
        "Swept Boss — that sketch is not a path",
        "Swept Boss — that sketch is not a profile",
        "nothing added",
    )

    def part(self) -> dict:
        return WalkChrome.part(self, "check_rung04.py")

    def af(self) -> float:
        return float(self.part()["PART"]["AF"])

    def r_vertex(self) -> float:
        return float(self.part()["PART"]["R"])

    def sketch_on_datum(self, name: str, view_key: str) -> dict:
        self.d.key(view_key)
        self.d.wait_idle(frames=2)
        self.click("rail:Sketch")
        self.refresh("status")
        self.click(datum=name)
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "camera")
        sk = self.st.get("sketch") or {}
        plane = sk.get("plane") or {}
        return {
            "status": self.S(),
            "active": bool(sk.get("active")),
            "plane": plane,
        }

    def uv_world(self, uv) -> list[float]:
        plane = (self.refresh("sketch").get("sketch") or {}).get("plane") or {}
        origin = plane.get("origin") or [0, 0, 0]
        x_dir = plane.get("x") or [1, 0, 0]
        y_dir = plane.get("y") or [0, 1, 0]
        u, v = float(uv[0]), float(uv[1])
        return [origin[i] + u * x_dir[i] + v * y_dir[i] for i in range(3)]

    def ents(self, kind: str | None = None, construction: bool | None = None) -> list[dict]:
        found = []
        for entity in self._entities():
            if kind is not None and entity.get("type") != kind:
                continue
            flag = bool(entity.get("construction"))
            if construction is not None and flag != construction:
                continue
            found.append(entity)
        return found

    def place_af_hex(self, centre=(0.0, 0.0), af: float | None = None) -> dict:
        value = self.af() if af is None else af
        self.click("rail:Polygon")
        self.refresh("controls", "status")
        self.click("variant:Across Flats")
        self.show_sketch_point(centre)
        self.click(sketch=list(centre))
        self.refresh("focus", "status")
        self.d.type(f"{value:g}")
        self.enter()
        self.refresh("sketch", "status", "dims")
        return {"status": self.S(), "lines": self.profile_lines(), "circles": self.ents("circle")}

    def dim_parallel_flats(self, value: str) -> dict:
        half = self.af() * 0.5
        self.click("rail:SmartDim")
        self.show_sketch_point((0, half))
        self.click(sketch=[0, half])
        self.show_sketch_point((0, -half))
        self.click(sketch=[0, -half])
        self.d.wait_idle(frames=3)
        self.refresh("dims", "status")
        dim = self.find_dim(lambda d: "°" not in str(d.get("text", "")))
        opened = False
        if dim is not None:
            opened = self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "dof", "status")
        return {"opened": opened, "texts": self.dim_texts(), "status": self.S()}

    def vertical_vertex_pair(self) -> dict:
        r_val = self.r_vertex()
        self.click("rail:Select")
        self.show_sketch_point((40, 40))
        self.click(sketch=[40, 40])
        self.show_sketch_point((r_val, 0))
        self.click(sketch=[r_val, 0])
        self.show_sketch_point((-r_val, 0))
        self.click(sketch=[-r_val, 0])
        self.refresh("controls", "status")
        self.click("chip:Vertical")
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status", "dof")
        return {"status": self.S(), "dof": self.dof_text()}

    def draw_line(self, a, b) -> None:
        self.click("rail:Line")
        self.show_sketch_point(a)
        self.click(sketch=list(a))
        self.show_sketch_point(b)
        self.click(sketch=list(b))
        self.refresh("sketch", "status")

    def toggle_construction(self, uv) -> str:
        self.click("rail:Select")
        self.show_sketch_point((10, 50))
        self.click(sketch=[10, 50])
        self.show_sketch_point(uv)
        self.click(sketch=list(uv))
        self.refresh("controls", "status")
        self.click("chip:Construction")
        self.refresh("sketch", "status")
        return self.S()

    def perimeter_circle(self, first, second, side) -> dict:
        self.click("rail:Circle")
        self.refresh("controls")
        self.click("variant:Perimeter")
        for uv in (first, second, side):
            self.show_sketch_point(uv)
            self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return {"circles": self.ents("circle"), "status": self.S()}

    def dim_diameter(self, rim, value: str) -> dict:
        self.click("rail:SmartDim")
        self.show_sketch_point(rim)
        self.click(sketch=list(rim))
        self.d.wait_idle(frames=3)
        self.refresh("dims")
        dim = self.find_dim(lambda d: "Ø" in str(d.get("text", "")) or "ø" in str(d.get("text", "")).lower())
        opened = False
        if dim is not None:
            opened = self.open_label(dim)
            self._type_dim_editor(value)
            self.enter()
        self.refresh("dims", "status")
        return {"opened": opened, "texts": self.dim_texts(), "status": self.S()}

    def trim_at(self, uv) -> str:
        self.click("rail:Trim")
        self.show_sketch_point(uv)
        self.d.hover(sketch=list(uv))
        self.click(sketch=list(uv))
        self.d.wait_idle(frames=3)
        self.refresh("sketch", "status")
        return self.S()

    def sketch_roles(self) -> list[str]:
        roles = []
        for feat in self.refresh("features").get("features") or []:
            if str(feat.get("type", "")) == "sketch":
                roles.append(str(feat.get("role", "unknown")))
        return roles

    def sketch_names(self) -> list[str]:
        names = []
        for feat in self.refresh("features").get("features") or []:
            if str(feat.get("type", "")) == "sketch":
                names.append(str(feat.get("name", "")))
        return names

    def pick_timeline(self, name: str) -> None:
        self._show_timeline()
        self.click(f"timeline:row:{name}")
        self.d.wait_idle(frames=2)
        self.refresh("timeline", "status")

    def profile_span(self) -> dict:
        pts = (self.sketch_bbox() or {}).get("pts") or []
        if not pts:
            return {"pts": [], "span_x": None, "span_y": None}
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return {
            "pts": pts,
            "span_x": max(xs) - min(xs),
            "span_y": max(ys) - min(ys),
            "max_y": max(ys),
            "min_y": min(ys),
            "max_x": max(xs),
            "min_x": min(xs),
        }

    def flats_horizontal(self) -> bool:
        pts = (self.sketch_bbox() or {}).get("pts") or []
        if not pts:
            return False
        r_val = self.r_vertex()
        on_x = [p for p in pts if abs(p[1]) <= 0.3 and abs(abs(p[0]) - r_val) <= 0.3]
        return len(on_x) >= 2

    def point_up(self) -> bool:
        pts = (self.sketch_bbox() or {}).get("pts") or []
        if not pts:
            return False
        r_val = self.r_vertex()
        on_y = [p for p in pts if abs(p[0]) <= 0.3 and abs(abs(p[1]) - r_val) <= 0.3]
        return len(on_y) >= 2

    def driving_distance_count(self) -> int:
        n = 0
        for dim in self.dims():
            raw = dim.get("raw") or {}
            kind = str(raw.get("type", ""))
            text = str(dim.get("text", ""))
            if kind == "distance" or ("°" not in text and "Ø" not in text and text):
                if kind == "angle":
                    continue
                if "Ø" in text:
                    continue
                n += 1
        return n

    def arc_span_deg(self, arc: dict) -> float:
        a0 = float(arc.get("start_angle", 0))
        a1 = float(arc.get("end_angle", 0))
        span = math.degrees(a1 - a0)
        while span <= 0:
            span += 360
        while span > 360:
            span -= 360
        return span

    def near(self, pt, want, tol=0.3) -> bool:
        return abs(float(pt[0]) - want[0]) <= tol and abs(float(pt[1]) - want[1]) <= tol

    def world_near(self, got, want, tol=0.2) -> bool:
        return all(abs(float(got[i]) - want[i]) <= tol for i in range(3))

    def check_probe(self, text: str, name: str) -> tuple[bool, str]:
        for line in text.splitlines():
            bits = line.split()
            if len(bits) >= 2 and bits[1] == name:
                return bits[0] == "PASS", line.strip()
        return False, f"missing {name}"

    def final_report(self) -> dict:
        cached = self.ctx.get("final_report")
        if isinstance(cached, dict):
            return cached
        path = self.export_3mf("final.3mf")
        code, text = self.checker("final", "final.3mf")
        report = {
            "exported": Path(path).is_file(),
            "code": code,
            "text": text,
        }
        self.ctx["final_report"] = report
        return report

    def reopen(self, name: str) -> dict:
        self.file_new("ok")
        self.open_file(name)
        self.refresh("status", "timeline", "sketch", "bodies")
        return {"status": self.S(), "names": self.feature_names()}

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
                take("unit_rung04"),
                take("registry"),
                errors,
            )
        self._release_project()
        try:
            kernel = run_kernel(self.repo)
            godot = run_tier(self)
            lint = proc.run([sys.executable, "tools/lint_suites.py"], cwd=self.repo)
            unit = proc.run([sys.executable, "tools/test_check_rung04.py"], cwd=self.repo)
            registry = proc.run([sys.executable, "tools/test_walk_registry.py"], cwd=self.repo)
        finally:
            if getattr(self, "proc", None) is None or self.proc.poll() is not None:
                self.launch()
        return self._headless_report(kernel, godot, lint, unit, registry, errors)

    def _headless_report(self, kernel, godot, lint, unit, registry, errors) -> dict[str, dict]:
        godot_text = (godot.stdout or "") + (godot.stderr or "")
        (self.out / "a21-godot.log").write_text(godot_text)
        (self.out / "a21-kernel.log").write_text((kernel.stdout or "") + (kernel.stderr or ""))
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

    def _release_project(self) -> None:
        self.d.close()
        proc_obj = getattr(self, "proc", None)
        if proc_obj is not None and proc_obj.poll() is None:
            proc_obj.terminate()
            try:
                proc_obj.wait(timeout=8)
            except subprocess.TimeoutExpired:
                proc_obj.kill()
                proc_obj.wait(timeout=5)
        log_fp = getattr(self, "log_fp", None)
        if log_fp is not None and not log_fp.closed:
            log_fp.close()
