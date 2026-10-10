"""Assemble the walk mixins into WalkApp."""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from walk.harness import Walk
from walk.jaw_geometry import WalkJaw
from walk.registry import CHUNKS, ROWS, finalize
from walk.rows_chunk1 import RowsChunk1
from walk.rows_chunk2 import RowsChunk2
from walk.rows_chunk3 import RowsChunk3
from walk.rows_chunk4 import RowsChunk4
from walk.rows_chunk5 import RowsChunk5
from walk.rows_chunk6 import RowsChunk6
from walk.ui import WalkUI
from walk.variants import WalkVariants
import walk.registry as registry


class WalkApp(RowsChunk1, RowsChunk2, RowsChunk3, RowsChunk4, RowsChunk5, RowsChunk6,
              WalkVariants, WalkJaw, WalkUI, Walk):
    pass


finalize()
registry.ROW_HANDLERS = {}
for _rid, _chunk, _name in registry._ENTRIES:
    registry.ROW_HANDLERS[_rid] = getattr(WalkApp, _name)
registry.ROW_HANDLERS["A8b-variant-walk"] = WalkApp.row_A8b_variant_walk
registry.ROW_HANDLERS["A9-variant-walk"] = WalkApp.row_A9_variant_walk


def main() -> int:
    parser = argparse.ArgumentParser(description="Walk the sx-041 checklist through the automation bridge")
    parser.add_argument("--out", default="/tmp/sx-041")
    parser.add_argument("--port", type=int, default=47321)
    parser.add_argument("--rows", default="", help="comma-separated row ids, e.g. A8,L4")
    parser.add_argument("--from", dest="from_row", default="", help="start at this row and continue")
    parser.add_argument("--godot", default="")
    parser.add_argument("--app", default="", help="exported binary to launch instead of the Godot editor")
    parser.add_argument("--resolution", default="1280x800", help="window size passed to the app, e.g. 1920x1200")
    parser.add_argument("--display", default=os.environ.get("DISPLAY", ":1"))
    parser.add_argument("--a15", action="store_true", help="note that the full headless tier should run")
    parser.add_argument("--no-launch", action="store_true", help="attach to an app that is already listening")
    parser.add_argument(
        "--checkpoint",
        action="store_true",
        help="reload blank.sxp / pre-cut.sxp / cut.sxp / wrench-wip.sxp / wrench-t14.sxp before a later chunk",
    )
    args = parser.parse_args()
    selected = list(ROWS)
    if args.rows:
        wanted = [p.strip() for p in args.rows.split(",") if p.strip()]
        unknown = [r for r in wanted if r not in ROWS]
        if unknown:
            print("unknown rows: " + ", ".join(unknown), file=sys.stderr)
            return 2
        selected = [r for r in ROWS if r in wanted]
    elif args.from_row:
        if args.from_row not in ROWS:
            print("unknown row " + args.from_row, file=sys.stderr)
            return 2
        selected = ROWS[ROWS.index(args.from_row):]
    godot = Path(args.godot) if args.godot else Path(__file__).resolve().parents[2] / "tools" / "godot" / "godot"
    app = Path(args.app).resolve() if args.app else None
    if app is not None and not app.is_file():
        print("missing --app binary: " + str(app), file=sys.stderr)
        return 2
    walk = WalkApp(Path(args.out), args.port, godot, args.display, args.a15, args.checkpoint, app, args.resolution)
    try:
        if args.no_launch:
            walk.d.connect()
        else:
            walk.launch()
        full = not args.rows and not args.from_row
        auto_ckpt = full or args.checkpoint
        prev_chunk = 0
        if auto_ckpt and selected and selected[0] != ROWS[0]:
            first_chunk = next(n for n, rows in CHUNKS.items() if selected[0] in rows)
            walk.ensure_chunk_start(first_chunk, force=True)
            prev_chunk = first_chunk
        for i, rid in enumerate(selected):
            chunk = next(n for n, rows in CHUNKS.items() if rid in rows)
            nxt = selected[i + 1] if i + 1 < len(selected) else None
            if auto_ckpt and prev_chunk and chunk != prev_chunk:
                walk.ensure_chunk_start(chunk)
            prev_chunk = chunk
            walk.run_row(rid, nxt)
        if full:
            walk.run_variants()
    finally:
        walk.write_report()
        if not args.no_launch:
            walk.shutdown()
    failed = [r for r in walk.rows if r["verdict"] == "FAIL"]
    return 1 if failed else 0
