#!/usr/bin/env python3
"""Fail if run_rung01_wrench.gd still shortcuts the operator GUI (replan-2 WP5).

Exits non-zero when the walk contains:
  - interaction._input
  - id_pressed.emit
  - item_selected.emit outside function _pick_end
  - assignment to a dialog current_path
  - a root size other than Vector2i(1280, 800) (including 1920 or 900 in _widen)
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

WALK = Path(__file__).resolve().parent.parent / "game" / "tests" / "run_rung01_wrench.gd"
ALLOWED_SIZE = (1280, 800)


def _functions(src: str) -> list[tuple[str, int, int]]:
    """Return (name, start, end) for each `func` in src. end is exclusive."""
    starts: list[tuple[str, int]] = []
    for m in re.finditer(r"(?m)^func\s+(\w+)\s*\(", src):
        starts.append((m.group(1), m.start()))
    out: list[tuple[str, int, int]] = []
    for i, (name, start) in enumerate(starts):
        end = starts[i + 1][1] if i + 1 < len(starts) else len(src)
        out.append((name, start, end))
    return out


def _line_of(src: str, index: int) -> int:
    return src.count("\n", 0, index) + 1


def main() -> int:
    if not WALK.is_file():
        print(f"lint_rung01_e2e: missing {WALK}", file=sys.stderr)
        return 1
    src = WALK.read_text(encoding="utf-8")
    errors: list[str] = []

    for m in re.finditer(r"interaction\._input", src):
        errors.append(f"line {_line_of(src, m.start())}: interaction._input")

    for m in re.finditer(r"id_pressed\.emit", src):
        errors.append(f"line {_line_of(src, m.start())}: id_pressed.emit")

    funcs = _functions(src)
    for m in re.finditer(r"item_selected\.emit", src):
        idx = m.start()
        owner = ""
        for name, start, end in funcs:
            if start <= idx < end:
                owner = name
                break
        if owner != "_pick_end":
            where = owner if owner else "top level"
            errors.append(
                f"line {_line_of(src, idx)}: item_selected.emit outside _pick_end (in {where})"
            )

    for m in re.finditer(r"\bcurrent_path\s*=", src):
        errors.append(f"line {_line_of(src, m.start())}: assignment to dialog current_path")

    for m in re.finditer(r"Vector2i\s*\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)", src):
        size = (int(m.group(1)), int(m.group(2)))
        if size != ALLOWED_SIZE:
            errors.append(
                f"line {_line_of(src, m.start())}: root size {size} is not Vector2i{ALLOWED_SIZE}"
            )

    # Catch _widen(1920, 900) and any leftover 1920×900 even without Vector2i.
    for m in re.finditer(r"\b(1920|900)\b", src):
        line_i = _line_of(src, m.start())
        line = src.splitlines()[line_i - 1]
        if re.search(r"_widen|Vector2i|Vector2\s*\(|root\.size|\.size\s*=", line):
            errors.append(
                f"line {line_i}: forbidden window size token {m.group(1)} ({line.strip()})"
            )

    if errors:
        print(f"lint_rung01_e2e: {WALK} still shortcuts the GUI:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1
    print(f"lint_rung01_e2e: {WALK} is clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
