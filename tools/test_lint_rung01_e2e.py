#!/usr/bin/env python3
"""Mutation tests for tools/lint_rung01_e2e.py."""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINT = ROOT / "tools" / "lint_rung01_e2e.py"
TESTS = ROOT / "game" / "tests"

NEEDLES = (
    ("run_rung01_replan3_inject.gd", "interaction._input"),
    ("run_rung01_replan3_inject.gd", "id_pressed.emit"),
    ("run_rung01_replan3_inject.gd", "set_extrude_distance"),
    ("run_rung01_replan4_inject.gd", "focus_dim_for_typing"),
    ("run_rung01_replan5_inject.gd", "sketch_mode.cancel("),
    ("run_rung01_replan7_inject.gd", "select_entity("),
)


def _run(tests_dir: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(LINT), "--tests-dir", str(tests_dir)],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )


class LintRung01E2ETests(unittest.TestCase):
    def test_clean_tree_exits_0(self) -> None:
        proc = _run(TESTS)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("5 replan21 scripts are clean", proc.stdout)

    def test_forbidden_token_exits_1_with_file_line(self) -> None:
        src = (TESTS / "run_rung01_replan3_blank.gd").read_text(encoding="utf-8")
        for name, needle in NEEDLES:
            with self.subTest(needle=needle), tempfile.TemporaryDirectory() as tmp:
                d = Path(tmp)
                (d / name).write_text(
                    src + f"\nfunc _lint_bait() -> void:\n\t{needle}\n",
                    encoding="utf-8",
                )
                proc = _run(d)
                self.assertEqual(proc.returncode, 1, proc.stderr)
                self.assertIn(name, proc.stderr)
                self.assertIn(needle, proc.stderr)
                self.assertRegex(proc.stderr, rf"{re.escape(name)}:line \d+:")


if __name__ == "__main__":
    unittest.main()
