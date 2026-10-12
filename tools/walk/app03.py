"""Assemble the rung-3 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung3.rows03_chunk1 import Rows03Chunk1
from walk.rung3.rows03_chunk2 import Rows03Chunk2
from walk.rung3.rows03_chunk3 import Rows03Chunk3
from walk.rung3.rows03_chunk4 import Rows03Chunk4
from walk.rung3.rows03_chunk5 import Rows03Chunk5
from walk.rung3.rows03_chunk6 import Rows03Chunk6
from walk.rung3.ui03 import WalkUI03
import walk.registry as registry


class WalkApp03(Rows03Chunk1, Rows03Chunk2, Rows03Chunk3, Rows03Chunk4, Rows03Chunk5,
                Rows03Chunk6, WalkUI03, WalkGestures):
    pass


registry.RUNG3 = registry.install("rung03", WalkApp03)


def main() -> int:
    return walk_main(
        WalkApp03,
        registry.RUNG3,
        "Walk the Lesson 1 parts through the automation bridge",
        "/tmp/sx-rung03",
    )
