#!/usr/bin/env python3
"""Frozen row-id order for the split walk package."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import walk.app  # noqa: E402, F401
import walk.app02  # noqa: E402, F401
import walk.app03  # noqa: E402, F401
from walk import registry  # noqa: E402
from walk.expect import CHECKS, State, gate  # noqa: E402
from walk.rung import Expect  # noqa: E402

# 75 checklist ids in registration order (chunks 1–6). Plus two variant walks = 77.
FROZEN_ROWS = [
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
FROZEN_VARIANTS = ("A8b-variant-walk", "A9-variant-walk")
FROZEN_CHUNKS = {
    1: FROZEN_ROWS[0:16],
    2: FROZEN_ROWS[16:28],
    3: FROZEN_ROWS[28:42],
    4: FROZEN_ROWS[42:47],
    5: FROZEN_ROWS[47:60],
    6: FROZEN_ROWS[60:75],
}


# 44 checklist ids. Chunks are the slices in docs/loop/rung-02-plan.md.
FROZEN_ROWS_02 = [
    "N1", "A1", "A2", "L1", "A3", "N2", "A4", "L2", "N3", "A5", "A6",
    "A7", "L3", "A8", "N4", "N5", "A9",
    "A10", "L4", "N6", "N7", "A11", "A12",
    "A13", "A14", "L5", "A15", "A16", "N8", "A17", "A18", "A19", "L6", "N9", "A20", "N10", "A21",
    "A22", "A23", "N11", "A24", "N12", "L7", "A25",
]
FROZEN_CHUNKS_02 = {
    1: FROZEN_ROWS_02[0:11],
    2: FROZEN_ROWS_02[11:17],
    3: FROZEN_ROWS_02[17:23],
    4: FROZEN_ROWS_02[23:37],
    5: FROZEN_ROWS_02[37:44],
}


# 46 checklist ids. Chunks are the slices in docs/loop/rung-03-plan.md.
FROZEN_ROWS_03 = [
    "N1", "A1", "A2", "L1", "A3", "N2", "A4", "A5",
    "A6", "L2", "A7", "A8", "N3", "A9", "A10",
    "A11", "A12", "L3", "N4", "A13", "N5", "A14", "L4", "A15",
    "A16", "L5", "A17", "N6", "A18", "N7", "N8", "A19", "A20",
    "A21", "L6", "N9", "A22", "N10", "A23", "L7", "A24", "N11",
    "A25", "N12", "L8", "A26",
]
FROZEN_CHUNKS_03 = {
    1: FROZEN_ROWS_03[0:8],
    2: FROZEN_ROWS_03[8:15],
    3: FROZEN_ROWS_03[15:24],
    4: FROZEN_ROWS_03[24:33],
    5: FROZEN_ROWS_03[33:42],
    6: FROZEN_ROWS_03[42:46],
}


class WalkRegistryTests(unittest.TestCase):
    def test_frozen_id_list_is_registry_order(self) -> None:
        self.assertEqual(list(registry.RUNG1.rows), FROZEN_ROWS)
        self.assertEqual(tuple(registry.RUNG1.variants), FROZEN_VARIANTS)
        self.assertEqual(len(registry.RUNG1.rows) + len(registry.RUNG1.variants), 77)

    def test_every_id_has_a_chunk(self) -> None:
        for rid in FROZEN_ROWS:
            chunk = next(n for n, rows in registry.RUNG1.chunks.items() if rid in rows)
            self.assertEqual(chunk, next(n for n, rows in FROZEN_CHUNKS.items() if rid in rows))

    def test_chunks_match_frozen_slices(self) -> None:
        self.assertEqual({n: list(rows) for n, rows in registry.RUNG1.chunks.items()}, FROZEN_CHUNKS)
        flattened = [rid for n in sorted(registry.RUNG1.chunks) for rid in registry.RUNG1.chunks[n]]
        self.assertEqual(flattened, FROZEN_ROWS)

    def test_handlers_cover_rows_and_variants(self) -> None:
        for rid in FROZEN_ROWS:
            handler = registry.RUNG1.handlers[rid]
            self.assertTrue(callable(handler))
            self.assertEqual(handler.__name__, "row_" + rid)
        for rid in FROZEN_VARIANTS:
            self.assertTrue(callable(registry.RUNG1.variants[rid]))

    def test_rung2_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG2", None)
        self.assertIsNotNone(rung, "rung 2 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_02)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_02)
        self.assertEqual(len(FROZEN_ROWS_02), 44)
        for rid in FROZEN_ROWS_02:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
        self.assertEqual(rung.checker, "check_rung02.py")
        self.assertEqual(rung.checkpoints[2], "box.sxp")

    def test_rung3_rows_and_chunks(self) -> None:
        rung = getattr(registry, "RUNG3", None)
        self.assertIsNotNone(rung, "rung 3 has no rows")
        self.assertEqual(list(rung.rows), FROZEN_ROWS_03)
        self.assertEqual({n: list(rows) for n, rows in rung.chunks.items()}, FROZEN_CHUNKS_03)
        self.assertEqual(len(FROZEN_ROWS_03), 46)
        for rid in FROZEN_ROWS_03:
            self.assertIn(rid, rung.handlers)
            self.assertTrue(callable(rung.handlers[rid]))
            self.assertEqual(rung.handlers[rid].__name__, "row_" + rid)
        self.assertEqual(rung.checker, "check_rung03.py")
        self.assertEqual(rung.checkpoints[2], "base.sxp")
        self.assertEqual(rung.checkpoints[5], "rounded.sxp")

    def test_gate_walks_the_check_table(self) -> None:
        self.assertEqual(list(CHECKS), ["mode", "sketch", "bodies", "bbox", "timeline", "finish_bar"])
        state = State(
            status="x", sketch_active=False, n_circles=0, n_lines=1, circle_span=0,
            n_bodies=0, bbox_x=10, finish_op="", finish_end="", popup_text="",
            timeline="", dim_texts="",
        )
        reasons = gate(state, Expect(blocker="A1", mode="sketch", sketch={"min_lines": 4}))
        self.assertEqual(reasons, ["sketch not active status='x'", "lines=1"])
        self.assertEqual(registry.RUNG1.expectations["A2"].mode, "sketch")


if __name__ == "__main__":
    unittest.main()
