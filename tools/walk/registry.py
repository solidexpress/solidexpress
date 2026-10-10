"""Row registry for the sx-041 walk. Order is registration order per chunk."""
from __future__ import annotations

from collections.abc import Callable

_ENTRIES: list[tuple[str, int, str]] = []
EXPECT: dict[str, dict] = {}


def row(rid: str, chunk: int, expect: dict | None = None):
    def deco(fn: Callable):
        _ENTRIES.append((rid, chunk, fn.__name__))
        if expect is not None:
            EXPECT[rid] = expect
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


def _rows_and_chunks() -> tuple[list[str], dict[int, list[str]]]:
    chunks: dict[int, list[str]] = {}
    for rid, chunk, _name in _ENTRIES:
        chunks.setdefault(chunk, []).append(rid)
    rank = {rid: i for i, rid in enumerate(CANONICAL_ROWS)}
    for n, ids in chunks.items():
        chunks[n] = sorted(ids, key=lambda rid: rank.get(rid, len(rank)))
    rows: list[str] = []
    for n in sorted(chunks):
        rows.extend(chunks[n])
    return rows, chunks


def finalize() -> None:
    rows, chunks = _rows_and_chunks()
    ROWS[:] = rows
    CHUNKS.clear()
    CHUNKS.update(chunks)


ROWS: list[str] = []
CHUNKS: dict[int, list[str]] = {}

CHECKPOINT = {2: 'blank.sxp', 4: 'cut.sxp', 5: 'wrench-wip.sxp', 6: 'wrench-wip.sxp'}


def checkpoint_file(rid: str) -> str | None:
    """Saved part that can stand in for live state when a later chunk starts."""
    idx = ROWS.index(rid)
    if idx >= ROWS.index("L7"):
        return "wrench-t14.sxp"
    chunk = next(n for n, rows in CHUNKS.items() if rid in rows)
    if chunk == 3 and idx >= ROWS.index("N20"):
        return "pre-cut.sxp"
    return CHECKPOINT.get(chunk)


ROW_HANDLERS: dict[str, object] = {}
