"""Assemble the rung-5 walk."""
from __future__ import annotations

from walk.cli import main as walk_main
from walk.gestures import WalkGestures
from walk.rung5.rows05_chunk1 import Rows05Chunk1
from walk.rung5.rows05_chunk2 import Rows05Chunk2
from walk.rung5.rows05_chunk3 import Rows05Chunk3
from walk.rung5.rows05_chunk4 import Rows05Chunk4
from walk.rung5.ui05 import WalkUI05
import walk.registry as registry


class WalkApp05(Rows05Chunk1, Rows05Chunk2, Rows05Chunk3, Rows05Chunk4, WalkUI05, WalkGestures):
    pass


registry.RUNG5 = registry.install("rung05", WalkApp05)


def main() -> int:
    return walk_main(
        WalkApp05,
        registry.RUNG5,
        "Walk the pipe section through the automation bridge",
        "/tmp/sx-rung05",
    )
