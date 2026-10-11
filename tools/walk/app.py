"""Assemble the rung-1 walk mixins into WalkApp."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.harness import Walk
from walk.jaw_geometry import WalkJaw
from walk.rows_chunk1 import RowsChunk1
from walk.rows_chunk2 import RowsChunk2
from walk.rows_chunk3 import RowsChunk3
from walk.rows_chunk4 import RowsChunk4
from walk.rows_chunk5 import RowsChunk5
from walk.rows_chunk6 import RowsChunk6
from walk.ui import WalkUI
from walk.variants import WalkVariants
import walk.registry as registry


class WalkApp(RowsChunk1, RowsChunk2, RowsChunk3, RowsChunk4, RowsChunk5, RowsChunk6,
              WalkVariants, WalkJaw, WalkUI, Walk):
    pass


registry.RUNG1 = registry.install("rung01", WalkApp)
registry.ROWS[:] = list(registry.RUNG1.rows)
registry.CHUNKS.clear()
registry.CHUNKS.update(registry.RUNG1.chunks)
registry.EXPECT.clear()
registry.EXPECT.update(registry.RUNG1.expectations)
registry.ROW_HANDLERS.clear()
registry.ROW_HANDLERS.update(registry.RUNG1.handlers)
registry.RUNG1.handlers["A8b-variant-walk"] = WalkApp.row_A8b_variant_walk
registry.RUNG1.handlers["A9-variant-walk"] = WalkApp.row_A9_variant_walk
registry.ROW_HANDLERS["A8b-variant-walk"] = WalkApp.row_A8b_variant_walk
registry.ROW_HANDLERS["A9-variant-walk"] = WalkApp.row_A9_variant_walk


def main() -> int:
    return walk_main(
        WalkApp,
        registry.RUNG1,
        "Walk the sx-041 checklist through the automation bridge",
        "/tmp/sx-041",
    )
