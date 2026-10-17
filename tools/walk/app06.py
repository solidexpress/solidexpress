"""Assemble the rung-6 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung6.rows06_chunk1 import Rows06Chunk1
from walk.rung6.rows06_chunk2 import Rows06Chunk2
from walk.rung6.rows06_chunk3 import Rows06Chunk3
from walk.rung6.rows06_chunk4 import Rows06Chunk4
from walk.rung6.ui06 import WalkUI06
import walk.registry as registry


class WalkApp06(Rows06Chunk1, Rows06Chunk2, Rows06Chunk3, Rows06Chunk4, WalkUI06, WalkGestures):
    pass


registry.RUNG6 = registry.install("rung06", WalkApp06)


def main() -> int:
    return walk_main(
        WalkApp06,
        registry.RUNG6,
        "Walk the candlestick through the automation bridge",
        "/tmp/sx-rung06",
    )
