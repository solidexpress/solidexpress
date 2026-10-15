"""Assemble the rung-4 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung4.rows04_chunk1 import Rows04Chunk1
from walk.rung4.rows04_chunk2 import Rows04Chunk2
from walk.rung4.rows04_chunk3 import Rows04Chunk3
from walk.rung4.ui04 import WalkUI04
import walk.registry as registry


class WalkApp04(Rows04Chunk1, Rows04Chunk2, Rows04Chunk3, WalkUI04, WalkGestures):
    pass


registry.RUNG4 = registry.install("rung04", WalkApp04)


def main() -> int:
    return walk_main(
        WalkApp04,
        registry.RUNG4,
        "Walk the hex key through the automation bridge",
        "/tmp/sx-rung04",
    )
