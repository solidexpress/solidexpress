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
_TIER = re.compile(r"(?m)^suites:\s*(\d+)\s+run,\s*(\d+)\s+failed\s*$")
_CHECKS_LINE = re.compile(r"(?m)^(\d+) checks, (\d+) failures$")
# A15 / automation-bridge: full tier is n ≥ 204. Prefer that over a stray
# inner `suites: 1 run` that confirm_all may append from stderr.
_TIER_FULL_MIN = 204


def parse_suites(text: str) -> tuple[int, int, int] | None:
    found = _SUITES.findall(text)
    if not found:
        return None
    _total, ci, full, known_red = found[-1]
    return int(ci), int(full), int(known_red)


def parse_tier(text: str) -> tuple[int, int] | None:
    found = [(int(run), int(failed)) for run, failed in _TIER.findall(text)]
    if not found:
        return None
    full = [pair for pair in found if pair[0] >= _TIER_FULL_MIN]
    return full[-1] if full else found[-1]


def suite_check_counts(log: str, banner: str) -> tuple[int, int] | None:
    """Counts line for one concatenated suite, even when its body is >80k.

    run_suites.sh cats each suite log in full. The Catch2 summary sits after
    that suite's banner. A mid-log 'Godot Engine' reprint must not hide it.
    """
    found_banner = re.search(rf"(?m)^{re.escape(banner)}", log)
    if not found_banner:
        return None
    rest = log[found_banner.start():]
    parts = rest.split("\nGodot Engine")
    chunk = parts[0]
    if not _CHECKS_LINE.search(chunk) and len(parts) > 1:
        chunk = parts[0] + "\nGodot Engine" + parts[1]
    found = list(_CHECKS_LINE.finditer(chunk))
    if not found:
        return None
    n, failed = found[-1].groups()
    return int(n), int(failed)


def _failure_tail(result: subprocess.CompletedProcess) -> str:
    text = ((result.stdout or "") + (result.stderr or "")).strip()
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    if not lines:
        return "no output"
    last = lines[-1]
    named = ""
    for ln in reversed(lines):
        if "FAILED" in ln:
            named = ln
            break
    if named and named != last:
        return f"{named} — {last}"
    return last


def run_kernel(repo: Path) -> subprocess.CompletedProcess:
    """sxkernel_tests then sxvoice_tests. A later pass must not hide an earlier failure."""
    pairs: list[tuple[str, subprocess.CompletedProcess]] = []
    code = 0
    for rel in ("./build/sxkernel/sxkernel_tests", "./build/sxvoice/sxvoice_tests"):
        result = proc.run([rel], cwd=repo)
        pairs.append((rel, result))
        if result.returncode != 0 and code == 0:
            code = result.returncode
    chunks = [(result.stdout or "") + (result.stderr or "") for _name, result in pairs]
    if code != 0:
        labelled = [
            f"{name}: {_failure_tail(result)}"
            for name, result in pairs
            if result.returncode != 0
        ]
        chunks.append(" | ".join(labelled))
    return subprocess.CompletedProcess(["kernel"], code, "\n".join(chunks), "")


def confirm_dir() -> Path | None:
    """Directory written by tools/confirm_all.sh. Walks read it instead of re-running."""
    raw = os.environ.get("SX_CONFIRM_DIR", "").strip()
    if not raw:
        return None
    path = Path(raw)
    return path if path.is_dir() else None


def cached_proc(name: str) -> subprocess.CompletedProcess | None:
    """One log + rc file from the single confirm pass. None if this pass is not confirm."""
    folder = confirm_dir()
    if folder is None:
        return None
    log = folder / f"{name}.log"
    rc_path = folder / f"{name}.rc"
    if not log.is_file() or not rc_path.is_file():
        return None
    try:
        rc = int(rc_path.read_text().strip() or "1")
    except ValueError:
        rc = 1
    text = log.read_text(errors="replace")
    return subprocess.CompletedProcess([name], rc, text, "")


def take(name: str) -> subprocess.CompletedProcess | None:
    """Cached confirm result, or None when this process should run the command.

    A confirm pass owns each log. A missing file is a failed proc so the walk
    does not launch a second copy.
    """
    if confirm_dir() is None:
        return None
    hit = cached_proc(name)
    if hit is not None:
        return hit
    return subprocess.CompletedProcess(
        [name], 1, "", f"missing {name} log in SX_CONFIRM_DIR"
    )


def run_tier(walk) -> subprocess.CompletedProcess:
    owned = take("godot")
    if owned is not None:
        return owned
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
