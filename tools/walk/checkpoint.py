"""Reload a chunk start, or resume an arbitrary row from a snapshot / replay.
checkpoint_reload is rung 2's chunk start.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from sxdrive import SxError
from walk.harness import RowAbort
from walk.rung import Rung


def resolve_open_parts(out, name: str) -> tuple[str, str]:
    """Directory + basename for File→Open.

    Nested `ckpts/<row>.sxp` cannot be a FileDialog *file* name: the list
    only shows entries in `current_dir`. Open the parent folder instead.
    """
    raw = Path(name)
    path = raw if raw.is_absolute() else Path(out) / name
    return str(path.parent), path.name


@dataclass(frozen=True)
class ResumePlan:
    """How to recreate the document that `start_rid` expects.

    restore_file is a path relative to --out (snapshot after the previous row).
    restore_chunk calls the rung's chunk_start (named .sxp, or rung 1 builders).
    replay runs those rows as setup and does not score them.
    """

    restore_chunk: int | None
    restore_file: str | None
    replay: tuple[str, ...]


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


def _chunk_restorable(rung: Rung, chunk: int, files: set[str]) -> bool:
    if chunk <= 1:
        return False
    name = rung.checkpoints.get(chunk)
    if name and name in files:
        return True
    if rung.name != "rung01":
        return False
    if chunk == 2:
        return "blank.sxp" in files
    if chunk == 3:
        return "blank.sxp" in files
    if chunk == 4:
        return "cut.sxp" in files or "blank.sxp" in files
    if chunk in (5, 6):
        return "wrench-wip.sxp" in files or "cut.sxp" in files or "blank.sxp" in files
    return False


def plan_resume(rung: Rung, start_rid: str, files: set[str] | None = None) -> ResumePlan:
    """Pick restore + replay so `start_rid` sees the same document a full walk would.

    Preference: previous-row snapshot, then this chunk's start file, then an
    earlier chunk start, else replay from the first row (empty document).
    """
    files = set(files or ())
    rows = list(rung.rows)
    if start_rid not in rows:
        raise ValueError("unknown row " + start_rid)
    idx = rows.index(start_rid)
    if idx == 0:
        return ResumePlan(None, None, ())

    prev = rows[idx - 1]
    snap = f"ckpts/{prev}.sxp"
    if snap in files:
        return ResumePlan(None, snap, ())

    chunk = rung.chunk_of(start_rid)
    prefix = tuple(rid for rid in rung.chunks[chunk] if rows.index(rid) < idx)

    if _chunk_restorable(rung, chunk, files):
        return ResumePlan(chunk, None, prefix)

    for earlier in range(chunk - 1, 0, -1):
        if not _chunk_restorable(rung, earlier, files):
            continue
        start_at = rows.index(rung.chunks[earlier][0])
        return ResumePlan(earlier, None, tuple(rows[start_at:idx]))

    return ResumePlan(None, None, tuple(rows[:idx]))


def list_out_files(out) -> set[str]:
    """Names of saved parts in --out, plus ckpts/<row>.sxp snapshots."""
    from pathlib import Path

    root = Path(out)
    found: set[str] = set()
    if not root.is_dir():
        return found
    for path in root.iterdir():
        if path.is_file():
            found.add(path.name)
    ckpts = root / "ckpts"
    if ckpts.is_dir():
        for path in ckpts.iterdir():
            if path.is_file():
                found.add(f"ckpts/{path.name}")
    return found


def resume_walk(walk, start_rid: str) -> None:
    """Restore/replay so the next scored row is `start_rid`."""
    if walk.rung is None:
        return
    plan = plan_resume(walk.rung, start_rid, list_out_files(walk.out))
    print(
        f"resume {start_rid}: chunk={plan.restore_chunk} file={plan.restore_file} "
        f"replay={','.join(plan.replay) or '-'}",
        flush=True,
    )
    if plan.restore_file:
        walk._reload_checkpoint(plan.restore_file)
    elif plan.restore_chunk:
        walk.ensure_chunk_start(plan.restore_chunk, force=True)
    for rid in plan.replay:
        verdict = walk.run_row(rid, record=False)
        if not str(verdict).startswith("PASS"):
            raise RowAbort(f"resume replay {rid} {verdict}")
