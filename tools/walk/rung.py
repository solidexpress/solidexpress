"""A walk is one Rung: rows, chunks, checkpoints, checker, expectations."""
from __future__ import annotations

from collections.abc import Callable, Mapping
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Expect:
    """Preconditions for one row. A field left unset is not checked."""

    blocker: str = ""
    mode: str | None = None
    sketch: Mapping | None = None
    bodies: int | None = None
    bbox: tuple | None = None
    timeline: str | None = None
    finish_bar: Mapping | None = None

    @property
    def popup(self) -> str | None:
        value = (self.finish_bar or {}).get("popup")
        return str(value) if value else None


def expect_from(raw: dict | None) -> Expect | None:
    """Fold a legacy expect dict into the six CHECKS keys."""
    if not raw:
        return None
    mode = "sketch" if raw.get("sketch") else ("part" if raw.get("part") else None)
    sketch = {key: raw[key] for key in ("min_circles", "span_mm", "min_lines", "dim_has") if key in raw}
    finish = {}
    if "finish_op" in raw:
        finish["op"] = raw["finish_op"]
    if "finish_end" in raw:
        finish["end"] = raw["finish_end"]
    if "popup" in raw:
        finish["popup"] = raw["popup"]
    bbox = raw.get("bbox_x")
    return Expect(
        blocker=str(raw.get("blocker", "")),
        mode=mode,
        sketch=sketch or None,
        bodies=int(raw["min_bodies"]) if "min_bodies" in raw else None,
        bbox=tuple(bbox) if bbox is not None else None,
        timeline=str(raw["timeline"]) if "timeline" in raw else None,
        finish_bar=finish or None,
    )


@dataclass(frozen=True)
class CheckpointAfter:
    """First matching rule wins, ahead of the per-chunk file."""

    row: str
    file: str
    chunk: int | None = None


@dataclass(frozen=True)
class Rung:
    name: str
    checker: str
    chunks: dict[int, list[str]]
    checkpoints: dict[int, str]
    expectations: dict[str, Expect]
    rows: tuple[str, ...] = ()
    handlers: dict[str, Callable] = field(default_factory=dict)
    checkpoint_after: tuple[CheckpointAfter, ...] = ()
    chunk_start: Callable[[object, int, bool], None] | None = None
    report_title: str = "sx-042 walk"
    variants: dict[str, Callable] = field(default_factory=dict)

    def chunk_of(self, rid: str) -> int:
        return next(n for n, rows in self.chunks.items() if rid in rows)
