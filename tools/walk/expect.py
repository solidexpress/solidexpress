"""Row preconditions. gate() walks CHECKS; a new key is one table entry."""
from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from walk.rung import Expect


@dataclass(frozen=True)
class State:
    status: str
    sketch_active: bool
    n_circles: int
    n_lines: int
    circle_span: float
    n_bodies: int
    bbox_x: float | None
    finish_op: str
    finish_end: str
    popup_text: str
    timeline: str
    dim_texts: str


def _mode(state: State, value) -> str | None:
    if value == "sketch" and not state.sketch_active:
        return f"sketch not active status={state.status!r}"
    if value == "part" and state.sketch_active:
        return "still in a sketch"
    return None


def _sketch(state: State, value) -> str | None:
    reasons = []
    if "min_circles" in value and state.n_circles < int(value["min_circles"]):
        reasons.append(f"circles={state.n_circles}")
    if "span_mm" in value and state.circle_span < float(value["span_mm"]):
        reasons.append(f"circle span {state.circle_span:.1f} mm")
    if "min_lines" in value and state.n_lines < int(value["min_lines"]):
        reasons.append(f"lines={state.n_lines}")
    if "dim_has" in value and str(value["dim_has"]) not in state.dim_texts:
        reasons.append(f"dims={state.dim_texts!r}")
    return "; ".join(reasons) or None


def _bodies(state: State, value) -> str | None:
    if state.n_bodies < int(value):
        return f"bodies={state.n_bodies}"
    return None


def _bbox(state: State, value) -> str | None:
    lo, hi = value
    span = state.bbox_x
    if span is None or not (float(lo) <= span <= float(hi)):
        return f"bbox X={span}"
    return None


def _timeline(state: State, value) -> str | None:
    if str(value) not in state.timeline:
        return f"timeline={state.timeline!r}"
    return None


def _finish_bar(state: State, value) -> str | None:
    reasons = []
    if "op" in value and state.finish_op != value["op"]:
        reasons.append(f"finish op={state.finish_op!r}")
    if "end" in value and str(value["end"]) not in state.finish_end:
        reasons.append(f"finish end={state.finish_end!r}")
    if "popup" in value and str(value["popup"]).lower() not in state.popup_text.lower():
        shown = state.popup_text[:80]
        reasons.append(f"popup {value['popup']!r} not open ({shown})")
    return "; ".join(reasons) or None


CHECKS: dict[str, Callable[[State, object], str | None]] = {
    "mode": _mode,
    "sketch": _sketch,
    "bodies": _bodies,
    "bbox": _bbox,
    "timeline": _timeline,
    "finish_bar": _finish_bar,
}


def gate(state: State, spec: Expect) -> list[str]:
    values = {
        "mode": spec.mode,
        "sketch": spec.sketch,
        "bodies": spec.bodies,
        "bbox": spec.bbox,
        "timeline": spec.timeline,
        "finish_bar": spec.finish_bar,
    }
    reasons: list[str] = []
    for key, check in CHECKS.items():
        value = values[key]
        if value is None:
            continue
        why = check(state, value)
        if why:
            reasons.append(why)
    return reasons
