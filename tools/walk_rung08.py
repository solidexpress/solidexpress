#!/usr/bin/env python3
"""Walk the UBC pipeline-assembly checklist against a live SolidExpress window.

Same arguments as tools/walk_rung07.py. Named checkpoints are pin.sxp,
pipes.sxp, bolted.sxp, assembly.sxp, and final.sxp. The checker is
tools/check_rung08.py.

    python3 tools/walk_rung08.py --out /tmp/sx-rung08
    python3 tools/walk_rung08.py --rows N1,A1,A2 --dry-run
    python3 tools/walk_rung08.py --from A20 --checkpoint --out /tmp/sx-rung08
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app08 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
