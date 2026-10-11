"""Assemble the rung-2 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung2.rows02_chunk1 import Rows02Chunk1
from walk.rung2.rows02_chunk2 import Rows02Chunk2
from walk.rung2.rows02_chunk3 import Rows02Chunk3
from walk.rung2.rows02_chunk4 import Rows02Chunk4
from walk.rung2.rows02_chunk5 import Rows02Chunk5
from walk.rung2.ui02 import WalkUI02
import walk.registry as registry


class WalkApp02(Rows02Chunk1, Rows02Chunk2, Rows02Chunk3, Rows02Chunk4, Rows02Chunk5,
                WalkUI02, WalkGestures):
    pass


registry.RUNG2 = registry.install("rung02", WalkApp02)


def main() -> int:
    return walk_main(
        WalkApp02,
        registry.RUNG2,
        "Walk the Lesson 2 box through the automation bridge",
        "/tmp/sx-rung02",
    )
