#!/usr/bin/env python3
"""Fail if the rung-1 walk or replan-3/4/5/6 scripts shortcut the operator GUI.

Exits non-zero when run_rung01_wrench.gd contains:
  - infer_enabled
  - text_submitted.emit
  - assignment to .value
  - assignment to .text
  - interaction._input
  - id_pressed.emit
  - item_selected.emit outside function _pick_end
  - assignment to a dialog current_path or current_dir
  - a root size other than Vector2i(1280, 800) (including 1920 or 900 in _widen)
  - focus_dim_for_typing / focus_distance_for_typing / set_extrude_distance
  - set_up_to_face / set_finish_op / set_finish_end / export_3mf(
  - sketch_mode.cancel( / exit_sketch( / trim_at( / new_document( / graph_update_sketch(
  - dimension_edit_requested.emit
  - an _x11_click helper, Power Trim click, recovery click, centreline,
    right-half head click, or path-field export that awaits between
    pressed=true and pressed=false
  - _dimension_label_pos2 inside _smart_dim_centres (or a replacement)

Also scans game/tests/run_rung01_replan3_*.gd for:
  - interaction._input
  - id_pressed.emit
  - set_extrude_distance
  - set_up_to_face
  - export_3mf(
  - text_submitted.emit

And game/tests/run_rung01_replan4_*.gd for the replan-3 list plus:
  - focus_dim_for_typing
  - focus_distance_for_typing
  - assignment to .text
  - set_extrude_distance (already in the replan-3 list)

And game/tests/run_rung01_replan5_*.gd for the walk's new forbiddens plus
the no-await-between-press/release rule.

And game/tests/run_rung01_replan6_*.gd for the replan-5 list plus
assignment to current_dir and a call to _dimension_label_pos2.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WALK = ROOT / "game" / "tests" / "run_rung01_wrench.gd"
TESTS = ROOT / "game" / "tests"
ALLOWED_SIZE = (1280, 800)
REPLAN3_FORBIDDEN = (
    "interaction._input",
    "id_pressed.emit",
    "set_extrude_distance",
    "set_up_to_face",
    "export_3mf(",
    "text_submitted.emit",
)
REPLAN4_EXTRA_FORBIDDEN = (
    "focus_dim_for_typing",
    "focus_distance_for_typing",
)
REPLAN5_FORBIDDEN = (
    "sketch_mode.cancel(",
    "sketch_mode.exit_sketch(",
    "sketch_mode.trim_at(",
    "new_document(",
    "graph_update_sketch(",
    "set_up_to_face",
    "focus_dim_for_typing",
    "focus_distance_for_typing",
    "set_extrude_distance",
)
WALK_EXTRA_FORBIDDEN = REPLAN4_EXTRA_FORBIDDEN + (
    "set_extrude_distance",
    "set_up_to_face",
    "set_finish_op",
    "set_finish_end",
    "export_3mf(",
    "dimension_edit_requested.emit",
    "select_entity(",
) + (
    "sketch_mode.cancel(",
    "sketch_mode.exit_sketch(",
    "sketch_mode.trim_at(",
    "new_document(",
    "graph_update_sketch(",
)
REPLAN7_FORBIDDEN = REPLAN5_FORBIDDEN + (
    "select_entity(",
)
REPLAN11_CAMERA = (
    "_look_along",
    "set_view(",
    ".yaw =",
    ".pitch =",
    ".basis =",
)
REPLAN11_CAMERA_YAW_PITCH = (".yaw =", ".pitch =")
REPLAN11_YAW_PITCH_OK = ("_zoom", "_zoom_uv")
REPLAN11_NO_ZOOM = (
    "_fillet_neck",
    "_fillet_face",
    "_refuse_slot_floor",
    "_ensure_body_selected",
    "_sketch_on_top",
)
REPLAN11_VALIDATION = {
    "run_rung01_replan11_fillet_ui.gd",
    "run_rung01_replan11_fillet_err.gd",
    "run_rung01_replan11_trim.gd",
    "run_rung01_replan11_slot.gd",
    "run_rung01_replan11_dim.gd",
    "run_rung01_replan11_dimhit.gd",
    "run_rung01_replan11_poly.gd",
    "run_rung01_replan11_ux.gd",
}
WALK_PRESS_RELEASE_EXTRA = (
    "_draw_centreline",
    "_end_centreline_chain",
    "_place_head_right_half",
    "_export_bare_via_path_field",
    "_smart_dim_centres",
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


def _is_press_release_fn(name: str) -> bool:
    if name == "_x11_click" or name.startswith("_x11_click_"):
        return True
    if name.startswith("_recovery") or name.startswith("_power_trim"):
        return True
    if name in WALK_PRESS_RELEASE_EXTRA:
        return True
    return False


def _lint_needles(src: str, needles: tuple[str, ...], errors: list[str], prefix: str) -> None:
    for needle in needles:
        for m in re.finditer(re.escape(needle), src):
            errors.append(f"{prefix}line {_line_of(src, m.start())}: {needle}")


def _lint_text_assignment(src: str, errors: list[str], prefix: str) -> None:
    for m in re.finditer(r"\.\s*text\s*=(?!=)", src):
        errors.append(f"{prefix}line {_line_of(src, m.start())}: assignment to .text")


def _lint_current_dir_assignment(src: str, errors: list[str], prefix: str) -> None:
    for m in re.finditer(r"\bcurrent_dir\s*=", src):
        errors.append(f"{prefix}line {_line_of(src, m.start())}: assignment to current_dir")


def _lint_dimension_label_pos2(src: str, errors: list[str], prefix: str) -> None:
    for m in re.finditer(r"_dimension_label_pos2", src):
        errors.append(f"{prefix}line {_line_of(src, m.start())}: _dimension_label_pos2")


def _lint_x11_click_await(src: str, errors: list[str], prefix: str) -> None:
    found = False
    found_screen = False
    for name, start, end in _functions(src):
        if not _is_press_release_fn(name):
            continue
        found = found or name == "_x11_click"
        found_screen = found_screen or name == "_x11_click_screen"
        body = src[start:end]
        down = body.find("pressed = true")
        up = body.find("pressed = false")
        if down < 0 or up < 0:
            continue
        if up <= down:
            errors.append(
                f"{prefix}line {_line_of(src, start)}: {name} has pressed=false before pressed=true"
            )
            continue
        await_at = body.find("await ", down)
        if await_at >= 0 and await_at < up:
            errors.append(
                f"{prefix}line {_line_of(src, start + await_at)}: "
                f"{name} awaits between mouse-down and mouse-up"
            )
    if prefix == "" and not found:
        errors.append("walk is missing func _x11_click (numeric fields must use the X11 burst)")
    if prefix == "" and not found_screen:
        errors.append(
            "walk is missing func _x11_click_screen (Power Trim and recovery must use it)"
        )


def _lint_walk_trim_recovery(src: str, errors: list[str]) -> None:
    if "Trimmed open jaw" not in src:
        errors.append("walk does not assert Trimmed open jaw")
    if "_power_trim_shaft_click" not in src:
        errors.append("walk is missing _power_trim_shaft_click")
    if "_recovery_open_profile_then_new" not in src:
        errors.append("walk is missing recovery scene _recovery_open_profile_then_new")
    for i, line in enumerate(src.splitlines(), 1):
        if "_click_uv" in line and "Trim" in line:
            errors.append(
                f"line {i}: Power Trim click uses _click_uv (must use _x11_click_screen)"
            )
        if "set_view(" in line:
            errors.append(
                f"line {i}: camera set_view is not the Opposite face / Front-view pick"
            )


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

    _lint_current_dir_assignment(src, errors, "")

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

    _lint_needles(src, WALK_EXTRA_FORBIDDEN, errors, "")
    _lint_text_assignment(src, errors, "")
    _lint_x11_click_await(src, errors, "")
    _lint_walk_trim_recovery(src, errors)
    _lint_walk_smart_dim(src, errors)
    _lint_walk_replan11_camera(src, errors)


def _lint_walk_smart_dim(src: str, errors: list[str]) -> None:
    found = False
    for name, start, end in _functions(src):
        if name != "_smart_dim_centres" and "smart_dim" not in name:
            continue
        found = True
        body = src[start:end]
        hit = body.find("_dimension_label_pos2")
        if hit >= 0:
            errors.append(
                f"line {_line_of(src, start + hit)}: {name} contains _dimension_label_pos2"
            )
    if not found:
        errors.append(
            "walk is missing _smart_dim_centres (or a replacement) for centre-to-centre Smart Dimension"
        )


def _lint_replan3(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan3_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan3_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        for needle in REPLAN3_FORBIDDEN:
            for m in re.finditer(re.escape(needle), src):
                errors.append(f"{rel}:{_line_of(src, m.start())}: {needle}")


def _lint_replan4(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan4_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan4_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN3_FORBIDDEN, errors, prefix)
        _lint_needles(src, REPLAN4_EXTRA_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)


def _lint_replan5(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan5_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan5_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN5_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)


def _lint_replan6(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan6_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan6_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN5_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)
        _lint_current_dir_assignment(src, errors, prefix)
        _lint_dimension_label_pos2(src, errors, prefix)


def _lint_replan7(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan7_*.gd"))
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)
        _lint_current_dir_assignment(src, errors, prefix)
        _lint_dimension_label_pos2(src, errors, prefix)


def _lint_replan8(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan8_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan8_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)
        _lint_current_dir_assignment(src, errors, prefix)
        _lint_dimension_label_pos2(src, errors, prefix)


def _lint_replan9(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan9_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan9_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)
        _lint_current_dir_assignment(src, errors, prefix)
        _lint_dimension_label_pos2(src, errors, prefix)


def _lint_replan10(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan10_*.gd"))
    if not paths:
        errors.append(f"no run_rung01_replan10_*.gd scripts under {TESTS}")
        return
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)
        _lint_current_dir_assignment(src, errors, prefix)
        _lint_dimension_label_pos2(src, errors, prefix)


def _lint_replan11_camera(src: str, errors: list[str], prefix: str, *, skip_look_along: bool = False) -> None:
    always = tuple(
        n for n in REPLAN11_CAMERA
        if n not in REPLAN11_CAMERA_YAW_PITCH and not (skip_look_along and n == "_look_along")
    )
    _lint_needles(src, always, errors, prefix)
    funcs = _functions(src)
    for needle in REPLAN11_CAMERA_YAW_PITCH:
        for m in re.finditer(re.escape(needle), src):
            idx = m.start()
            owner = ""
            for name, start, end in funcs:
                if start <= idx < end:
                    owner = name
                    break
            if owner in REPLAN11_YAW_PITCH_OK:
                continue
            errors.append(f"{prefix}line {_line_of(src, idx)}: {needle}")


def _lint_walk_replan11_camera(src: str, errors: list[str]) -> None:
    _lint_replan11_camera(src, errors, "")
    funcs = {name: src[start:end] for name, start, end in _functions(src)}
    for name in REPLAN11_NO_ZOOM:
        body = funcs.get(name, "")
        if "_zoom(" in body:
            errors.append(f"{name} contains _zoom(")


def _lint_replan11(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan11_*.gd"))
    if len(paths) != 11:
        errors.append("expected 11 run_rung01_replan11_*.gd")
    for path in paths:
        src = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        prefix = f"{rel}:"
        # dimhit's header comment names _look_along as forbidden and does not
        # call it. Exempt that needle for this file only.
        skip_look_along = path.name == "run_rung01_replan11_dimhit.gd"
        _lint_replan11_camera(src, errors, prefix, skip_look_along=skip_look_along)
        if path.name in REPLAN11_VALIDATION:
            continue
        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
        _lint_text_assignment(src, errors, prefix)
        _lint_x11_click_await(src, errors, prefix)
        _lint_current_dir_assignment(src, errors, prefix)


def _lint_replan12(errors: list[str]) -> None:
    paths = sorted(TESTS.glob("run_rung01_replan12_*.gd"))
    if len(paths) != 10:
        errors.append("expected 10 run_rung01_replan12_*.gd")
    for path in paths:
        src = path.read_text(encoding="utf-8")
        prefix = f"{path.relative_to(ROOT)}:"
        # These are validation suites: script-side setup (insert_primitive,
        # select_entity to arm) is allowed, but the pointer and camera paths
        # under test must be real keys and events.
        _lint_replan11_camera(src, errors, prefix)


def main() -> int:
    if not WALK.is_file():
        print(f"lint_rung01_e2e: missing {WALK}", file=sys.stderr)
        return 1
    src = WALK.read_text(encoding="utf-8")
    errors: list[str] = []
    _lint_walk(src, errors)
    _lint_replan3(errors)
    _lint_replan4(errors)
    _lint_replan5(errors)
    _lint_replan6(errors)
    _lint_replan7(errors)
    _lint_replan8(errors)
    _lint_replan9(errors)
    _lint_replan10(errors)
    _lint_replan11(errors)
    _lint_replan12(errors)

    if errors:
        print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1
    n3 = len(list(TESTS.glob("run_rung01_replan3_*.gd")))
    n4 = len(list(TESTS.glob("run_rung01_replan4_*.gd")))
    n5 = len(list(TESTS.glob("run_rung01_replan5_*.gd")))
    n6 = len(list(TESTS.glob("run_rung01_replan6_*.gd")))
    n7 = len(list(TESTS.glob("run_rung01_replan7_*.gd")))
    n8 = len(list(TESTS.glob("run_rung01_replan8_*.gd")))
    n9 = len(list(TESTS.glob("run_rung01_replan9_*.gd")))
    n10 = len(list(TESTS.glob("run_rung01_replan10_*.gd")))
    n11 = len(list(TESTS.glob("run_rung01_replan11_*.gd")))
    print(f"lint_rung01_e2e: {WALK} is clean")
    print(f"lint_rung01_e2e: {n3} replan3 scripts are clean")
    print(f"lint_rung01_e2e: {n4} replan4 scripts are clean")
    print(f"lint_rung01_e2e: {n5} replan5 scripts are clean")
    print(f"lint_rung01_e2e: {n6} replan6 scripts are clean")
    print(f"lint_rung01_e2e: {n7} replan7 scripts are clean")
    print(f"lint_rung01_e2e: {n8} replan8 scripts are clean")
    print(f"lint_rung01_e2e: {n9} replan9 scripts are clean")
    print(f"lint_rung01_e2e: {n10} replan10 scripts are clean")
    print(f"lint_rung01_e2e: {n11} replan11 scripts are clean")
    n12 = len(list(TESTS.glob("run_rung01_replan12_*.gd")))
    print(f"lint_rung01_e2e: {n12} replan12 scripts are clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
