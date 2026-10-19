#!/usr/bin/env python3
"""Headless exactness probes (WP-L1).

Wraps build/sxkernel/sx_exact and parses the JSON reports later L/S WPs
assert on. Mesh checkers are not exactness.

CLI:
    python3 tools/sx_exact.py box-hole
    python3 tools/sx_exact.py help
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[1]


def binary() -> Path:
    env = os.environ.get("SX_EXACT")
    if env:
        return Path(env)
    return REPO / "build" / "sxkernel" / "sx_exact"


def run_verb(verb: str) -> dict[str, Any]:
    exe = binary()
    if not exe.is_file():
        raise FileNotFoundError(
            f"sx_exact not found at {exe}. Build the kernel (make build) first."
        )
    proc = subprocess.run(
        [str(exe), verb],
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"sx_exact {verb} exited {proc.returncode}: {proc.stderr.strip() or proc.stdout}"
        )
    return json.loads(proc.stdout)


def circles(report: dict[str, Any]) -> list[dict[str, Any]]:
    body = report.get("body") or report
    edges = body.get("edges") or []
    return [e for e in edges if e.get("type") == "GeomAbs_Circle"]


def volume(report: dict[str, Any]) -> float:
    body = report.get("body") or report
    return float(body["volume"])


def feature_params(report: dict[str, Any], feature_type: str) -> dict[str, Any] | None:
    for f in report.get("features") or []:
        if f.get("type") == feature_type:
            params = f.get("params")
            return params if isinstance(params, dict) else None
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="sx_exact.py", description="Kernel exactness probes")
    parser.add_argument("verb", nargs="?", default="box-hole", help="box-hole (default) or help")
    args = parser.parse_args(argv)
    if args.verb in ("help", "-h", "--help"):
        parser.print_help()
        return 0
    data = run_verb(args.verb)
    json.dump(data, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 — CLI surface
        print(f"sx_exact: {exc}", file=sys.stderr)
        raise SystemExit(1)
