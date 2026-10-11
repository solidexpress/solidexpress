"""Reload the previous chunk from the file named on the rung.
checkpoint_reload is rung 2's chunk start.
"""
from __future__ import annotations

from sxdrive import SxError
from walk.harness import RowAbort


def checkpoint_reload(walk, chunk: int, force: bool = False) -> None:
    """Reload the previous chunk's file. The file names live on the rung."""
    if chunk <= 1 or walk.rung is None:
        return
    name = walk.rung.checkpoints.get(chunk)
    if not name:
        return
    ready = (
        not force
        and not walk.chunk_failed(chunk - 1)
        and not walk._sketch_active()
        and (walk.out / name).exists()
    )
    if ready:
        return
    if not (walk.out / name).exists():
        print(f"checkpoint: {name} is not in {walk.out}", flush=True)
        return
    try:
        walk._reload_checkpoint(name)
    except (SxError, RowAbort) as exc:
        print(f"checkpoint: chunk {chunk} reload failed: {exc}", flush=True)
