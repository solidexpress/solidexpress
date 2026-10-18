#!/usr/bin/env python3
"""Walk the candlestick checklist against a live SolidExpress window.

Same arguments as tools/walk_rung05.py. Checkpoints are revolve.sxp, path.sxp,
and sweep.sxp. The checker is tools/check_rung06.py.

    python3 tools/walk_rung06.py --out /tmp/sx-rung06
    python3 tools/walk_rung06.py --rows N1,A1,A2 --dry-run
    python3 tools/walk_rung06.py --from A16 --checkpoint --out /tmp/sx-rung06
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app06 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
