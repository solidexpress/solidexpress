"""Headless tier shared by rung 1 A15 and rung 2 A25.

Parses lint_suites and `suites: N run` lines, then runs preflight plus the full tier.
"""
from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

from walk import proc

_SUITES = re.compile(
    r"lint_suites:\s*(\d+)\s+suites ok\s+\((\d+)\s+ci,\s+(\d+)\s+full,\s+(\d+)\s+known-red\)"
)
_TIER = re.compile(r"suites:\s*(\d+)\s+run,\s*(\d+)\s+failed")


def parse_suites(text: str) -> tuple[int, int, int] | None:
    found = _SUITES.findall(text)
    if not found:
        return None
    _total, ci, full, known_red = found[-1]
    return int(ci), int(full), int(known_red)


def parse_tier(text: str) -> tuple[int, int] | None:
    found = _TIER.findall(text)
    if not found:
        return None
    run, failed = found[-1]
    return int(run), int(failed)


def run_tier(walk) -> subprocess.CompletedProcess:
    # Makefile test-godot depends on build, which re-runs cmake. This snapshot's
    # configure does not finish (Boost headers are not installed), so the tier
    # runs the Godot binary and run_suites.sh directly.
    repo = Path(walk.repo)
    godot = str(repo / "tools" / "godot" / "godot")
    env = {**os.environ, "KEEP_GOING": "1", "GODOT_BIN": godot}
    pre = proc.run(
        [godot, "--headless", "--path", "game", "--script", "tests/preflight_sxcore.gd"],
        cwd=repo,
        env=env,
    )
    suites = proc.run(
        ["packaging/ci/run_suites.sh", "--tier", "full", "--keep-going"],
        cwd=repo,
        env=env,
    )
    text = "\n".join(
        part for part in (pre.stdout, pre.stderr, suites.stdout, suites.stderr) if part
    )
    code = 0 if pre.returncode == 0 and suites.returncode == 0 else (suites.returncode or pre.returncode or 1)
    return subprocess.CompletedProcess(["godot"], code, text, "")
