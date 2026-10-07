#!/usr/bin/env python3
"""Unit tests for tools/lint_suites.py and the suite runner's list/tier split."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import lint_suites  # noqa: E402

OLD_CI = [
    "run_workflow_tests.gd",
    "run_ui_tests.gd",
    "run_sketch_tests.gd",
    "run_sketch_tools_tests.gd",
    "run_print_tests.gd",
    "run_rung01_wrench.gd",
    "run_rung01_sx036_esc.gd",
    "run_rung01_sx036_fields.gd",
    "run_rung01_jaw_label_hit.gd",
    "run_rung01_replan15_shaftbadges.gd",
    "run_rung01_replan6_cut.gd",
    "run_rung01_replan12_status.gd",
    "run_rung01_n12_extrude.gd",
    "run_rung01_sx036_rail.gd",
    "run_rung01_replan15_jawstub.gd",
    "run_rung01_replan15_thick.gd",
]
KNOWN_RED = [
    "run_camera_tests.gd",
    "run_place_tests.gd",
    "run_howto_tests.gd",
    "run_infer_tests.gd",
    "run_icon_tests.gd",
]
UNREGISTERED = [
    "run_film_caption_tests.gd",
    "run_ui_scroll_tests.gd",
]


def _run_lint(env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    merged.pop("SX_SUITES_DIR", None)
    if env:
        merged.update(env)
    return subprocess.run(
        [sys.executable, str(ROOT / "tools" / "lint_suites.py")],
        cwd=ROOT,
        capture_output=True,
        text=True,
        env=merged,
        check=False,
    )


class LintSuitesTests(unittest.TestCase):
    def test_repo_tree_is_155(self):
        proc = _run_lint()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("lint_suites: 155 suites ok (17 ci, 138 full)", proc.stdout)

    def test_old_ci_stays_ci_and_known_red_stays_full(self):
        _errors, suites = lint_suites.collect_errors(lint_suites.DEFAULT_SUITES)
        by_base = {Path(s["script"]).name: s["tier"] for s in suites}
        for name in OLD_CI:
            self.assertEqual(by_base.get(name), "ci", name)
        self.assertEqual(by_base.get("run_rung01_replan16_suites.gd"), "ci")
        for name in KNOWN_RED:
            self.assertEqual(by_base.get(name), "full", name)
        for name in UNREGISTERED:
            self.assertNotIn(name, by_base)

    def test_missing_script_exits_1(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "no_such_suite.suite"
            path.write_text("script=tests/run_no_such_suite.gd\ntier=full\n", encoding="utf-8")
            proc = _run_lint({"SX_SUITES_DIR": tmp})
        self.assertEqual(proc.returncode, 1)
        self.assertIn("missing script", proc.stderr)

    def test_bad_tier_and_unknown_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "no_such_suite.suite").write_text(
                "script=tests/run_no_such_suite.gd\ntier=nightly\nextra=1\n",
                encoding="utf-8",
            )
            errors, _suites = lint_suites.manifest_errors(Path(tmp))
        blob = "\n".join(errors)
        self.assertIn("bad tier", blob)
        self.assertIn("unknown key", blob)
        self.assertIn("missing script", blob)

    def test_duplicate_script(self):
        with tempfile.TemporaryDirectory() as tmp:
            body = "script=tests/run_no_such_suite.gd\ntier=full\n"
            (Path(tmp) / "no_such_suite.suite").write_text(body, encoding="utf-8")
            (Path(tmp) / "also_no_such_suite.suite").write_text(body, encoding="utf-8")
            errors, _suites = lint_suites.manifest_errors(Path(tmp))
        self.assertTrue(any("duplicate script" in e for e in errors))

    def test_runner_ci_list_is_old_gate_plus_replan16(self):
        proc = subprocess.run(
            ["bash", str(ROOT / "packaging" / "ci" / "run_suites.sh"), "--tier", "ci", "--list"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
        self.assertEqual(len(lines), 17)
        got = {Path(ln).name for ln in lines}
        self.assertEqual(got, set(OLD_CI) | {"run_rung01_replan16_suites.gd"})

    def test_runner_full_list_covers_baseline(self):
        proc = subprocess.run(
            ["bash", str(ROOT / "packaging" / "ci" / "run_suites.sh"), "--tier", "full", "--list"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
        self.assertGreaterEqual(len(lines), 155)
        got = {Path(ln).name for ln in lines}
        baseline = [
            ln.strip()
            for ln in (ROOT / "packaging" / "ci" / "suites.baseline").read_text().splitlines()
            if ln.strip()
        ]
        self.assertEqual(len(baseline), 154)
        self.assertTrue(set(baseline) <= got)

    def test_bad_manifest_exits_2(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "no_such_suite.suite").write_text(
                "script=tests/run_no_such_suite.gd\ntier=nope\n",
                encoding="utf-8",
            )
            proc = subprocess.run(
                ["bash", str(ROOT / "packaging" / "ci" / "run_suites.sh"), "--tier", "full", "--list"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                env={**os.environ, "SX_SUITES_DIR": tmp},
                check=False,
            )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("bad tier", proc.stderr)
        self.assertEqual(proc.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
