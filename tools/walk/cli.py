"""Shared argv for walk_rung01.py and walk_rung02.py."""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


def main(app_cls: type, rung, description: str, default_out: str) -> int:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--out", default=default_out)
    parser.add_argument("--port", type=int, default=47321)
    parser.add_argument("--rows", default="", help="comma-separated row ids, e.g. A8,L4")
    parser.add_argument("--from", dest="from_row", default="", help="start at this row and continue")
    parser.add_argument("--godot", default="")
    parser.add_argument("--app", default="", help="exported binary to launch instead of the Godot editor")
    parser.add_argument("--resolution", default="1280x800", help="window size passed to the app, e.g. 1920x1200")
    parser.add_argument("--display", default=os.environ.get("DISPLAY", ":1"))
    parser.add_argument("--a15", action="store_true", help="note that the full headless tier should run")
    parser.add_argument("--no-launch", action="store_true", help="attach to an app that is already listening")
    parser.add_argument("--dry-run", action="store_true", help="print the selected rows and do not launch")
    parser.add_argument(
        "--checkpoint",
        action="store_true",
        help="reload the previous chunk's saved part before a later chunk",
    )
    args = parser.parse_args()
    rows = list(rung.rows)
    if args.rows:
        wanted = [p.strip() for p in args.rows.split(",") if p.strip()]
        unknown = [r for r in wanted if r not in rows]
        if unknown:
            print("unknown rows: " + ", ".join(unknown), file=sys.stderr)
            return 2
        selected = [r for r in rows if r in wanted]
    elif args.from_row:
        if args.from_row not in rows:
            print("unknown row " + args.from_row, file=sys.stderr)
            return 2
        selected = rows[rows.index(args.from_row):]
    else:
        selected = rows
    if args.dry_run:
        for rid in selected:
            handler = rung.handlers.get(rid)
            print(f"dry-run {rid} {handler.__name__ if handler else 'missing'}", flush=True)
        return 0 if all(rid in rung.handlers for rid in selected) else 2
    godot = Path(args.godot) if args.godot else Path(__file__).resolve().parents[2] / "tools" / "godot" / "godot"
    app = Path(args.app).resolve() if args.app else None
    if app is not None and not app.is_file():
        print("missing --app binary: " + str(app), file=sys.stderr)
        return 2
    walk = app_cls(
        Path(args.out), args.port, godot, args.display, args.a15, args.checkpoint, app, args.resolution, rung,
    )
    try:
        if args.no_launch:
            walk.d.connect()
        else:
            walk.launch()
        full = not args.rows and not args.from_row
        auto_ckpt = full or args.checkpoint
        prev_chunk = 0
        if auto_ckpt and selected and selected[0] != rows[0]:
            first_chunk = rung.chunk_of(selected[0])
            walk.ensure_chunk_start(first_chunk, force=True)
            prev_chunk = first_chunk
        for i, rid in enumerate(selected):
            chunk = rung.chunk_of(rid)
            nxt = selected[i + 1] if i + 1 < len(selected) else None
            if auto_ckpt and prev_chunk and chunk != prev_chunk:
                walk.ensure_chunk_start(chunk)
            prev_chunk = chunk
            walk.run_row(rid, nxt)
        if full and rung.variants:
            walk.run_variants()
    finally:
        walk.write_report()
        if not args.no_launch:
            walk.shutdown()
    failed = [r for r in walk.rows if str(r["verdict"]).startswith("FAIL")]
    return 1 if failed else 0
