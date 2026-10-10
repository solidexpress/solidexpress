#!/usr/bin/env python3
"""Frozen row-id order for the split walk package."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from walk.app import WalkApp  # noqa: E402
from walk import registry  # noqa: E402

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


class WalkRegistryTests(unittest.TestCase):
    def test_frozen_id_list_is_registry_order(self) -> None:
        self.assertEqual(list(registry.ROWS), FROZEN_ROWS)
        self.assertEqual(len(registry.ROWS) + len(FROZEN_VARIANTS), 77)

    def test_every_id_has_a_chunk(self) -> None:
        for rid in FROZEN_ROWS:
            chunk = next(n for n, rows in registry.CHUNKS.items() if rid in rows)
            self.assertEqual(chunk, next(n for n, rows in FROZEN_CHUNKS.items() if rid in rows))

    def test_chunks_match_frozen_slices(self) -> None:
        self.assertEqual({n: list(rows) for n, rows in registry.CHUNKS.items()}, FROZEN_CHUNKS)
        flattened = [rid for n in sorted(registry.CHUNKS) for rid in registry.CHUNKS[n]]
        self.assertEqual(flattened, FROZEN_ROWS)

    def test_handlers_cover_rows_and_variants(self) -> None:
        for rid in FROZEN_ROWS:
            self.assertIn(rid, registry.ROW_HANDLERS)
            self.assertTrue(callable(getattr(WalkApp, registry.ROW_HANDLERS[rid].__name__)))
        for rid in FROZEN_VARIANTS:
            self.assertIn(rid, registry.ROW_HANDLERS)


if __name__ == "__main__":
    unittest.main()
