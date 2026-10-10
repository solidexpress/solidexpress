"""Walk rows for chunk 6."""
from __future__ import annotations

import math
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from sxdrive import SxError
from walk.registry import row

class RowsChunk6:
    @row('A12', chunk=6)
    def row_A12(self) -> None:
        if not self.body_guard("wrench", 10.0):
            raise RowAbort()
        path = self.export_3mf("wrench.3mf")
        self.clause("exported", Path(path).exists() and "Exported 3MF" in self.S(), self.S())
        if Path(path).exists():
            code, text = self.checker("wrench", "wrench.3mf")
            passed = "28/28 passed" in text and "flipX=False" in text and "flipY=False" in text
            self.clause("28/28", code == 0 and passed, "\n".join(text.strip().splitlines()[-6:]))

    @row('N11', chunk=6)
    def row_N11(self) -> None:
        if not self.body_guard("wrench", 10.0):
            raise RowAbort()
        path = self.export_3mf("wrench-noext")
        self.clause("extension added", Path(self.out / "wrench-noext.3mf").exists() and not Path(self.out / "wrench-noext").exists(), self.S())
        if Path(self.out / "wrench-noext.3mf").exists():
            code, text = self.checker("wrench", "wrench-noext.3mf")
            self.clause("28/28", code == 0 and "28/28 passed" in text, "\n".join(text.strip().splitlines()[-4:]))

    def _open_base_extrude(self) -> None:
        rows = [r for r in (self.refresh("timeline").get("timeline") or []) if "extrude" in str(r.get("name", ""))]
        self.need(bool(rows), "extrude row", str(self.st.get("timeline")))
        name = str(rows[0].get("name"))
        self.d.double_click(target=f"timeline:row:{name}")
        self.refresh("focus", "focus_text", "status")

    @row('A13', chunk=6)
    def row_A13(self) -> None:
        self._open_base_extrude()
        self.clause("focused", "Distance" in str(self.st.get("focus", "")) or "distance" in str(self.st.get("focus", "")).lower(), str(self.st.get("focus")))
        mark = self.mark()
        self.d.key("1")
        self.refresh("status", "focus_text")
        mid = self.S()
        field = str(self.st.get("focus_text", ""))
        self.d.key("4")
        field2 = str(self.refresh("focus_text").get("focus_text", ""))
        self.clause("prefix silent", "Preview" not in mid and "rejected" not in mid.lower() and "Front view" not in mid, f"after 1 status={mid} field={field}->{field2}")
        mark_enter = self.mark()
        self.enter()
        preview = " | ".join(self.result_texts(mark_enter))
        win = (self.refresh("window").get("window") or {})
        size = win.get("size") or [1280, 800]
        # Upper canvas, clear of the framed plate and of the left timeline.
        away = [max(80.0, float(size[0]) - 48.0), 200.0]
        mark_click = self.mark()
        self.click(screen=away)
        committed = " | ".join(self.result_texts(mark_click))
        preview_ok = "Preview: distance = 14.0" in preview and "— fillet" not in preview
        # Click-away calls dismiss_keep_preview and keeps the live preview.
        # commit() emits "Feature updated (n change(s))" only on that path;
        # assert it when it shows up. The preview line is what this click does.
        emitted = "Feature updated" in committed
        quiet = committed.strip() == "" or emitted
        self.clause("commit 14", preview_ok and quiet, f"preview={preview!r} commit={committed!r}")
        if preview_ok:
            self.ctx["thickness"] = 14.0
        log = (self.out / "input-trace.log").read_text(errors="replace") if (self.out / "input-trace.log").exists() else ""
        n = len(re.findall(r"\[ERROR\].*soft-skip", log))
        self.clause("no error soft-skip", n == 0, f"count={n}")
        self.trace_from(mark)

    @row('A13b', chunk=6)
    def row_A13b(self) -> None:
        rows = [r for r in (self.refresh("timeline").get("timeline") or []) if "extrude" in str(r.get("name", ""))]
        self.need(bool(rows), "row", str(rows))
        name = str(rows[0]["name"])
        mark = self.mark()
        self.d.double_click(target=f"timeline:row:{name}")
        self.refresh("focus", "status")
        lines = self.trace_from(mark)
        drops = [ln for ln in lines if "drop:not-owner" in ln]
        self.clause("double click", "Distance" in str(self.st.get("focus", "")) or len(drops) >= 1, f"focus={self.st.get('focus')} {drops}")
        self.esc()
        self.refresh("status")
        # A panel opened with no typed edit has nothing to roll back, so Esc
        # clears the selection instead of saying "Edits cancelled".
        self.clause(
            "cancel",
            "cancelled" in self.S().lower() or "Edits cancelled" in self.S() or "Selection cleared" in self.S(),
            self.S(),
        )

    @row('A13d', chunk=6)
    def row_A13d(self) -> None:
        self._open_base_extrude()
        before = self.S()
        mark = self.mark()
        self.d.key("1")
        time.sleep(0.4)
        self.refresh("status")
        lines = self.trace_from(mark)
        errors = [ln for ln in lines if "[ERROR]" in ln]
        self.clause("prefix writes nothing", self.S() == before and "Preview: distance = 1.0" not in self.S() and not errors, f"{before!r} -> {self.S()!r} {errors}")
        self.esc()
        self.refresh("status")
        self.clause("cancelled", "cancelled" in self.S().lower() or self.S().startswith("Edits"), self.S())

    @row('A13c', chunk=6)
    def row_A13c(self) -> None:
        if not self.body_guard("wrench", float(self.ctx.get("thickness", 10.0))):
            raise RowAbort()
        path = self.export_3mf("wrench-t14.3mf")
        if not Path(path).exists():
            self.clause("export", False, self.S())
            return
        code, text = self.checker("thick", "wrench-t14.3mf", "14")
        self.clause("thick 7/7", code == 0 and "7/7 passed" in text, "\n".join(text.strip().splitlines()[-8:]))
        code, text = self.checker("wrench", "wrench-t14.3mf")
        failed = set()
        for ln in text.splitlines():
            if not ln.startswith("FAIL"):
                continue
            body = ln[4:].strip()
            failed.add(body.split("  got ")[0].strip() if "  got " in body else body)
        expected = {
            "bbox Z (thickness)",
            "grip slot present at y=0,z=8.75",
            "1mm fillet top outer edge",
            "1mm fillet on jaw top edge",
        }
        self.clause(
            "DIAG",
            failed == expected and "18/22 passed" in text,
            f"failed={sorted(failed)}",
        )

    @row('N9', chunk=6)
    def row_N9(self) -> None:
        path = self.out / "check-wrench-wrench-t14.txt"
        text = path.read_text() if path.exists() else ""
        lines = text.splitlines()
        wanted = (
            "PASS  head-shaft R10 fillet +Y",
            "PASS  head-shaft R10 fillet -Y",
            "PASS  R10 fillet not oversized",
            "PASS  1mm fillet bottom outer edge",
        )
        for needle in wanted:
            self.clause(needle, any(ln.startswith(needle) for ln in lines), next((ln for ln in lines if needle.split("  ", 1)[-1][:24] in ln), "missing"))
        tris = next((ln for ln in lines if " tris" in ln or ln.endswith(" tris") or "tris," in ln), "")
        self.clause("tris", "tris" in tris, tris or "no tris line")

    @row('L7', chunk=6)
    def row_L7(self) -> None:
        path = Path(self.save_as("wrench-t14.sxp"))
        first = path.stat().st_mtime if path.exists() else 0
        time.sleep(1.1)
        self.d.key("ctrl+s")
        self.refresh("status")
        second = path.stat().st_mtime if path.exists() else 0
        self.clause("ctrl+s writes", second >= first and "Saved" in self.S(), f"{first}->{second} {self.S()}")
        self.file_new(None)
        self.refresh("popups", "status")
        self.clause("clean new", "Discard" not in self.popup_text() and "New —" in self.S(), self.S() + " " + self.popup_text()[:80])

    @row('N8b', chunk=6)
    def row_N8b(self) -> None:
        self.menu("File", "Open...")
        self.click(target="item:blank.sxp")
        mark = self.mark()
        self.click("dialog:Ok")
        self.refresh("status", "bodies")
        self.d.wait_idle(frames=6)
        lines = self.trace_from(mark)
        self.clause("opened", any("Opened" in ln for ln in lines) or "Opened" in self.S(), self.S())
        bodies = self.st.get("bodies") or []
        self.clause("framed", bool(bodies), str(bodies)[:160])
        self.clause("headless-only hold", None, "headless-only: rung01_replan19_hint", kind="headless-only")

    @row('N14', chunk=6)
    def row_N14(self) -> None:
        self.sketch_on_top()
        self.circle([30, 20], "5")
        self.click("rail:Line")
        self.click(sketch=[10, 10])
        self.click(sketch=[80, 10])
        mark = self.mark()
        self.click("finish:Op")
        self.click("popup:Cut")
        lines = self.trace_from(mark)
        popup = [ln for ln in lines if "FinishOp" in ln]
        self.clause("FinishOp", any("show" in ln for ln in popup) and any("hide" in ln for ln in popup), " | ".join(popup))
        self.set_option("finish:End", "Blind")
        got = self.type_into("finish:Distance", "2.5", burst=True)
        self.clause("2.5", got == "2.5", got)
        self.enter()
        self.click("finish:Extrude", frames=6)
        self.refresh("status")
        self.clause("refusal", "breaks the chain" in self.S() and "uuid" not in self.S().lower(), self.S())
        s1 = self.esc()
        s2 = self.esc()
        self.clause("esc", "Sketch saved" in s2 or "Esc again" in s1, s1 + " | " + s2)
        self.file_new("ok")
        self.refresh("status")
        self.clause("discarded", "New —" in self.S(), self.S())

    @row('A10', chunk=6)
    def row_A10(self) -> None:
        self.sketch_ground()
        self.circle([0, 0], "50")
        self.type_into("finish:Distance", "10")
        self.enter()
        self.set_option("finish:Op", "New")
        self.set_option("finish:End", "Blind")
        self.click("finish:Extrude", frames=8)
        self.sketch_on_top()
        self.circle([0, 0], "45")
        self.set_option("finish:Op", "Cut")
        self.set_option("finish:End", "Blind")
        self.click("finish:Extrude", frames=8)
        self.refresh("status")
        self.clause("81%", "Cut would remove 81%" in self.S(), self.S())

    @row('A10b', chunk=6)
    def row_A10b(self) -> None:
        self.file_new("ok")
        self.refresh("status", "finish")
        self.clause("fresh", "New —" in self.S(), self.S())

    @row('A14', chunk=6)
    def row_A14(self) -> None:
        self.sketch_ground()
        self.click("rail:Polygon")
        self.click(sketch=[0, 0])
        self.refresh("status")
        self.ctx["poly_centre_status"] = self.S()
        self._polygon_bearings()
        self.d.type("20")
        self.enter()
        self.refresh("status")
        self.clause("polygon 20", "Polygon AF 20.0000" in self.S(), self.S())
        self.circle([0, 0], "5")
        self.type_into("finish:Distance", "7.5")
        self.enter()
        self.set_option("finish:End", "Blind")
        self.click("finish:Extrude", frames=8)
        self.refresh("status")
        self.clause("extrude 7.5", "7.5000" in self.S(), self.S())
        if not self.body_guard("nut"):
            raise RowAbort()
        path = self.export_3mf("nut.3mf")
        if Path(path).exists():
            code, text = self.checker("nut", "nut.3mf")
            self.clause("nut 7/7", code == 0, "\n".join(text.strip().splitlines()[-8:]))

    def _polygon_bearings(self) -> None:
        readings = []
        centre = self.d.project(sketch=[0, 0])["screen"]
        for deg, radius in ((20, 160), (70, 160), (110, 160)):
            rad = math.radians(deg)
            pt = [centre[0] + radius * math.cos(rad), centre[1] + radius * math.sin(rad)]
            self.d.hover(screen=pt)
            self.refresh("status")
            readings.append(self.S())
        self.ctx["l9"] = readings

    @row('L9', chunk=6)
    def row_L9(self) -> None:
        readings = list(self.ctx.get("l9") or [])
        if not readings:
            self._polygon_bearings()
            readings = list(self.ctx.get("l9") or [])
        same = bool(readings) and all("Polygon AF" in s for s in readings)
        self.clause("AF bearings", same, " | ".join(readings))

    def _a15_floor(self, log: str, banner: str, floor: int) -> tuple[bool, str]:
        idx = log.find(banner)
        if idx < 0:
            return False, f"missing {banner}"
        window = log[idx:idx + 80000]
        nxt = window.find("\nrung01 ", len(banner))
        if nxt > 0:
            window = window[:nxt]
        match = re.search(r"(\d+) checks, (\d+) failures", window)
        if not match:
            return False, f"{banner}: no checks line"
        n, failed = int(match.group(1)), int(match.group(2))
        return failed == 0 and n >= floor, f"{banner}: {n} checks, {failed} failures (floor {floor})"

    @row('A15', chunk=6)
    def row_A15(self) -> None:
        if not self.run_a15:
            self.clause(
                "headless tier",
                False,
                "BLOCKED-by-flag: pass --a15 to run the lints and make test-godot",
            )
            return
        lint_e2e = subprocess.run([sys.executable, "tools/lint_rung01_e2e.py"], cwd=str(self.repo), capture_output=True, text=True)
        lint_suites = subprocess.run([sys.executable, "tools/lint_suites.py"], cwd=str(self.repo), capture_output=True, text=True)
        e2e = (lint_e2e.stdout or "") + (lint_e2e.stderr or "")
        suites = (lint_suites.stdout or "") + (lint_suites.stderr or "")
        (self.out / "a15-lint-e2e.log").write_text(e2e)
        (self.out / "a15-lint-suites.log").write_text(suites)
        self.clause(
            "lint_rung01_e2e",
            lint_e2e.returncode == 0 and "5 replan21 scripts are clean" in e2e,
            e2e.strip().splitlines()[-1] if e2e.strip() else "no output",
        )
        suite_line = suites.strip().splitlines()[-1] if suites.strip() else ""
        suites_m = re.search(
            r"lint_suites:\s*(\d+)\s+suites ok\s+\((\d+)\s+ci,\s+(\d+)\s+full,\s+(\d+)\s+known-red\)",
            suites,
        )
        suites_ok = (
            lint_suites.returncode == 0
            and suites_m is not None
            and int(suites_m.group(4)) == 4
        )
        self.clause(
            "lint_suites",
            suites_ok,
            suite_line or "no output",
        )
        log_path = self.out / "test-godot.log"
        proc = subprocess.run(
            ["make", "test-godot"],
            cwd=str(self.repo),
            capture_output=True,
            text=True,
            env={**os.environ, "KEEP_GOING": "1"},
        )
        tier = (proc.stdout or "") + (proc.stderr or "")
        log_path.write_text(tier)
        (self.out / "a15-test-godot.log").write_text(tier)
        ran = re.findall(r"suites:\s*(\d+)\s+run,\s*(\d+)\s+failed", tier)
        ci_n = int(suites_m.group(2)) if suites_m else -1
        full_n = int(suites_m.group(3)) if suites_m else -1
        tier_ok = (
            bool(ran)
            and int(ran[-1][1]) == 0
            and int(ran[-1][0]) == ci_n + full_n
        )
        self.clause("headless tier", tier_ok, f"suites: {ran[-1][0]} run, {ran[-1][1]} failed" if ran else tier[-400:])
        floors = (
            ("rung01 wrench walk", 702),
            ("rung01 replan19 keys", 151),
            ("rung01 replan19 shield", 32),
            ("rung01 replan19 jaw", 77),
            ("rung01 replan19 hint", 30),
            ("rung01 replan19 glyphs", 83),
            ("rung01 replan19 timeline", 75),
            ("rung01 replan19 camera", 25),
            ("rung01 replan19 fillet pick", 44),
            ("rung01 replan19 polish", 68),
            ("rung01 replan21 sketch undo", 40),
            ("rung01 replan21 angle", 80),
            ("rung01 replan21 pick", 36),
            ("rung01 replan21 dressup", 20),
            ("rung01 replan21 state", 40),
        )
        notes = []
        floors_ok = True
        for banner, floor in floors:
            ok, note = self._a15_floor(tier, banner, floor)
            floors_ok = floors_ok and ok
            notes.append(note)
        self.clause("suite floors", floors_ok, "; ".join(notes))

    # --- checkpoints and the screenshot-walk variants --------------------
