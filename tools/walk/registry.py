"""Rows register against a rung. Rung 1's frozen list is unchanged."""
from __future__ import annotations

from collections.abc import Callable

from walk.checkpoint import checkpoint_reload
from walk.rung import CheckpointAfter, Rung, expect_from
from walk.rung1.chunk_start import Rung1ChunkStart

_PENDING: dict[str, list[tuple]] = {}
_VARIANTS: dict[str, list[tuple[str, Callable]]] = {}


def row(rid: str, chunk: int, expect: dict | None = None, *, on: str = "rung01"):
    def deco(fn: Callable):
        _PENDING.setdefault(on, []).append((rid, chunk, fn, expect))
        return fn
    return deco


def variant(rid: str, *, on: str = "rung01"):
    def deco(fn: Callable):
        _VARIANTS.setdefault(on, []).append((rid, fn))
        return fn
    return deco


# Checklist order copied from the pre-split walk_rung01.py ROWS list.
CANONICAL_ROWS = [
    "N22", "A1", "A2", "N7", "L1", "A3", "L5", "A4", "L6", "L10",
    "A5", "N12", "A5b", "L8", "L11", "N17",
    "A7", "L2", "A6", "N4", "A7b", "A8r", "A8w", "A8", "N5", "N25", "A8b", "N8a",
    "A9", "L4", "N1a", "N21", "N21b", "N26", "L12", "N24", "N24b", "A17",
    "A9c", "N1b", "N20", "A9b",
    "A16", "N6", "A11a", "N10", "N18",
    "A11b", "N2", "L3", "A11c", "N3", "A11d", "A11e", "A11f", "N15", "N13",
    "N16", "N19", "N23",
    "A12", "N11", "A13b", "A13d", "A13", "A13c", "N9", "L7", "N8b", "N14",
    "A10", "A10b", "A14", "L9", "A15",
]

# Lesson 2 box. Order is the checklist, not import order.
RUNG2_ROWS = [
    "N1", "A1", "A2", "L1", "A3", "N2", "A4", "L2", "N3", "A5", "A6",
    "A7", "L3", "A8", "N4", "N5", "A9",
    "A10", "L4", "N6", "N7", "A11", "A12",
    "A13", "A14", "L5", "A15", "A16", "N8", "A17", "A18", "A19", "L6", "N9", "A20", "N10", "A21",
    "A22", "A23", "N11", "A24", "N12", "L7", "A25",
]

_RUNG_SPEC = {
    "rung01": {
        "checker": "check_rung01.py",
        "checkpoints": {2: "blank.sxp", 4: "cut.sxp", 5: "wrench-wip.sxp", 6: "wrench-wip.sxp"},
        "canonical": CANONICAL_ROWS,
        "chunk_start": Rung1ChunkStart(),
        "report_title": "sx-042 walk",
        "checkpoint_after": (
            CheckpointAfter("L7", "wrench-t14.sxp"),
            CheckpointAfter("N20", "pre-cut.sxp", chunk=3),
        ),
    },
    "rung02": {
        "checker": "check_rung02.py",
        "checkpoints": {2: "box.sxp", 3: "rounded.sxp", 4: "shelled.sxp", 5: "final.sxp"},
        "canonical": RUNG2_ROWS,
        "chunk_start": checkpoint_reload,
        "report_title": "rung-02 walk",
        "checkpoint_after": (),
    },
}


def _assemble(name: str) -> tuple[list[str], dict[int, list[str]], dict, dict[str, Callable]]:
    spec = _RUNG_SPEC[name]
    rank = {rid: i for i, rid in enumerate(spec["canonical"])}
    chunks: dict[int, list[str]] = {}
    expectations = {}
    handlers: dict[str, Callable] = {}
    for rid, chunk, fn, expect in _PENDING.get(name, []):
        chunks.setdefault(chunk, []).append(rid)
        handlers[rid] = fn
        built = expect_from(expect)
        if built is not None:
            expectations[rid] = built
    for n, ids in chunks.items():
        chunks[n] = sorted(ids, key=lambda rid: rank.get(rid, len(rank)))
    rows: list[str] = []
    for n in sorted(chunks):
        rows.extend(chunks[n])
    return rows, chunks, expectations, handlers


def _defined_on(fn: Callable, app_cls: type) -> bool:
    return any(cls.__dict__.get(fn.__name__) is fn for cls in app_cls.__mro__)


def install(name: str, app_cls: type) -> Rung:
    spec = _RUNG_SPEC[name]
    rows, chunks, expectations, handlers = _assemble(name)
    variants = dict(_VARIANTS.get(name, []))
    for fn in (*handlers.values(), *variants.values()):
        if not _defined_on(fn, app_cls):
            raise RuntimeError(f"{name} handler {fn.__name__} is not defined on {app_cls.__name__}")
    return Rung(
        name=name,
        checker=spec["checker"],
        chunks=chunks,
        checkpoints=dict(spec["checkpoints"]),
        expectations=expectations,
        rows=tuple(rows),
        handlers=handlers,
        checkpoint_after=tuple(spec["checkpoint_after"]),
        chunk_start=spec["chunk_start"],
        report_title=spec["report_title"],
        variants=variants,
    )


RUNG1: Rung | None = None
RUNG2: Rung | None = None
