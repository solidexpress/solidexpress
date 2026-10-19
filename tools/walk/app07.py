"""Assemble the rung-7 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung7.rows07_chunk1 import Rows07Chunk1
from walk.rung7.rows07_chunk2 import Rows07Chunk2
from walk.rung7.rows07_chunk3 import Rows07Chunk3
from walk.rung7.rows07_chunk4 import Rows07Chunk4
from walk.rung7.ui07 import WalkUI07
import walk.registry as registry


class WalkApp07(Rows07Chunk1, Rows07Chunk2, Rows07Chunk3, Rows07Chunk4, WalkUI07, WalkGestures):
    pass


registry.RUNG7 = registry.install("rung07", WalkApp07)


def main() -> int:
    return walk_main(
        WalkApp07,
        registry.RUNG7,
        "Walk the combination spanner through the automation bridge",
        "/tmp/sx-rung07",
    )
