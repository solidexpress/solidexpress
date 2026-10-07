#!/usr/bin/env python3
"""Lint packaging/ci/suites.d manifests.

Honours SX_SUITES_DIR (default packaging/ci/suites.d). Exits 1 and prints
`missing script` when a manifest names a script file that is not on disk.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SUITES = ROOT / "packaging" / "ci" / "suites.d"
BASELINE = ROOT / "packaging" / "ci" / "suites.baseline"
GAME = ROOT / "game"
ALLOWED_KEYS = {"script", "tier", "timeout"}
TIERS = {"ci", "full"}


def suites_dir() -> Path:
    raw = os.environ.get("SX_SUITES_DIR", "").strip()
    if not raw:
        return DEFAULT_SUITES
    path = Path(raw)
    if not path.is_absolute():
        path = ROOT / path
    return path


def derived_name(script: str) -> str | None:
    base = Path(script).name
    if not base.startswith("run_") or not base.endswith(".gd"):
        return None
    return base[len("run_") : -len(".gd")]


def parse_manifest(path: Path) -> tuple[dict[str, str], list[str]]:
    errors: list[str] = []
    data: dict[str, str] = {}
    text = path.read_text(encoding="utf-8")
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if "=" not in line:
            errors.append(f"{path.name}:{lineno}: bad line")
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip()
        if key not in ALLOWED_KEYS:
            errors.append(f"{path.name}: unknown key {key}")
            continue
        if key in data:
            errors.append(f"{path.name}: duplicate {key}")
            continue
        data[key] = val
    if "script" not in data:
        errors.append(f"{path.name}: missing script")
    if "tier" not in data:
        errors.append(f"{path.name}: missing tier")
    elif data["tier"] not in TIERS:
        errors.append(f"{path.name}: bad tier {data['tier']}")
    if "timeout" in data and (not data["timeout"].isdigit() or int(data["timeout"]) < 1):
        errors.append(f"{path.name}: bad timeout {data['timeout']}")
    return data, errors


def manifest_errors(directory: Path) -> tuple[list[str], list[dict[str, str]]]:
    """Validate every *.suite in directory. Does not apply the baseline gate."""
    errors: list[str] = []
    suites: list[dict[str, str]] = []
    if not directory.is_dir():
        return [f"missing suites dir {directory}"], []
    paths = sorted(directory.glob("*.suite"), key=lambda p: p.name)
    seen: dict[str, str] = {}
    for path in paths:
        data, perr = parse_manifest(path)
        errors.extend(perr)
        script = data.get("script", "")
        if script:
            if script in seen:
                errors.append(f"duplicate script {script} in {path.name} and {seen[script]}")
            else:
                seen[script] = path.name
            script_path = GAME / script
            if not script_path.is_file():
                errors.append(f"missing script file {script}")
            expect = derived_name(script)
            if expect is None or path.stem != expect:
                errors.append(
                    f"{path.name}: name is not derived from {script or '<missing script>'}"
                )
        if "script" in data and "tier" in data and data["tier"] in TIERS:
            suites.append({"file": path.name, "script": script, "tier": data["tier"]})
    return errors, suites


def collect_errors(directory: Path) -> tuple[list[str], list[dict[str, str]]]:
    errors, suites = manifest_errors(directory)
    registered = {Path(s["script"]).name for s in suites if s.get("script")}
    for path in sorted(GAME.glob("tests/run_rung01_*.gd")):
        if path.name not in registered:
            errors.append(f"run_rung01 script without a manifest: {path.name}")
    if BASELINE.is_file():
        for line in BASELINE.read_text(encoding="utf-8").splitlines():
            name = line.split("#", 1)[0].strip()
            if not name:
                continue
            if name not in registered:
                errors.append(f"baseline script lost its manifest: {name}")
    else:
        errors.append(f"missing baseline {BASELINE}")
    return errors, suites


def main() -> int:
    errors, suites = collect_errors(suites_dir())
    if errors:
        for err in errors:
            print(f"lint_suites: {err}", file=sys.stderr)
        return 1
    n_ci = sum(1 for s in suites if s["tier"] == "ci")
    n_full = sum(1 for s in suites if s["tier"] == "full")
    print(f"lint_suites: {len(suites)} suites ok ({n_ci} ci, {n_full} full)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
