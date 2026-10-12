"""Assemble the rung-1 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung1.jaw_geometry import WalkJaw
from walk.rung1.rows_chunk1 import RowsChunk1
from walk.rung1.rows_chunk2 import RowsChunk2
from walk.rung1.rows_chunk3 import RowsChunk3
from walk.rung1.rows_chunk4 import RowsChunk4
from walk.rung1.rows_chunk5 import RowsChunk5
from walk.rung1.rows_chunk6 import RowsChunk6
from walk.rung1.ui import WalkUI
from walk.rung1.variants import WalkVariants
import walk.registry as registry


class WalkApp(RowsChunk1, RowsChunk2, RowsChunk3, RowsChunk4, RowsChunk5, RowsChunk6,
              WalkVariants, WalkJaw, WalkUI, WalkGestures):
    pass


registry.RUNG1 = registry.install("rung01", WalkApp)


def main() -> int:
    return walk_main(
        WalkApp,
        registry.RUNG1,
        "Walk the sx-041 checklist through the automation bridge",
        "/tmp/sx-041",
    )
