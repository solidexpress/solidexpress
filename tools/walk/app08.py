"""Assemble the rung-8 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung8.rows08_chunk1 import Rows08Chunk1
from walk.rung8.rows08_chunk2 import Rows08Chunk2
from walk.rung8.rows08_chunk3 import Rows08Chunk3
from walk.rung8.rows08_chunk4 import Rows08Chunk4
from walk.rung8.ui08 import WalkUI08
import walk.registry as registry


class WalkApp08(Rows08Chunk1, Rows08Chunk2, Rows08Chunk3, Rows08Chunk4, WalkUI08, WalkGestures):
    pass


registry.RUNG8 = registry.install("rung08", WalkApp08)


def main() -> int:
    return walk_main(
        WalkApp08,
        registry.RUNG8,
        "Walk the UBC pipeline assembly through the automation bridge",
        "/tmp/sx-rung08",
    )
