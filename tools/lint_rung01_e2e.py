#!/usr/bin/env python3
"""Fail if the rung-1 walk or replan-3 scripts shortcut the operator GUI (replan-3 WP7).

Exits non-zero when run_rung01_wrench.gd contains:
  - infer_enabled
  - text_submitted.emit
  - assignment to .value
  - interaction._input
  - id_pressed.emit
  - item_selected.emit outside function _pick_end
  - assignment to a dialog current_path
  - a root size other than Vector2i(1280, 800) (including 1920 or 900 in _widen)

Also scans game/tests/run_rung01_replan3_*.gd for:
  - interaction._input
  - id_pressed.emit
  - set_extrude_distance
  - set_up_to_face
  - export_3mf(
  - text_submitted.emit
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WALK = ROOT / "game" / "tests" / "run_rung01_wrench.gd"
REPLAN3 = ROOT / "game" / "tests"
ALLOWED_SIZE = (1280, 800)
REPLAN3_FORBIDDEN = (
    "interaction._input",
    "id_pressed.emit",
    "set_extrude_distance",
    "set_up_to_face",
    "export_3mf(",
    "text_submitted.emit",
)


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


def _lint_walk(src: str, errors: list[str]) -> None:
    for m in re.finditer(r"infer_enabled", src):
        errors.append(f"line {_line_of(src, m.start())}: infer_enabled")

    for m in re.finditer(r"text_submitted\.emit", src):
        errors.append(f"line {_line_of(src, m.start())}: text_submitted.emit")

    for m in re.finditer(r"\.\s*value\s*=", src):
        errors.append(f"line {_line_of(src, m.start())}: assignment to .value")

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


def _lint_replan3(errors: list[str]) -> None:
    paths = sorted(REPLAN3.glob("run_rung01_replan3_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan3_*.gd scripts under {REPLAN3}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        for needle in REPLAN3_FORBIDDEN:
            for m in re.finditer(re.escape(needle), src):
                errors.append(f"{rel}:{_line_of(src, m.start())}: {needle}")


def main() -> int:
    if not WALK.is_file():
        print(f"lint_rung01_e2e: missing {WALK}", file=sys.stderr)
        return 1
    src = WALK.read_text(encoding="utf-8")
    errors: list[str] = []
    _lint_walk(src, errors)
    _lint_replan3(errors)

    if errors:
        print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1
    print(f"lint_rung01_e2e: {WALK} is clean")
    print(f"lint_rung01_e2e: {len(list(REPLAN3.glob('run_rung01_replan3_*.gd')))} replan3 scripts are clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
