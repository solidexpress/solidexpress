#!/usr/bin/env python3
"""Walk the pipe-section checklist against a live SolidExpress window.

Same arguments as tools/walk_rung04.py. Checkpoints are shelled.sxp, cut.sxp,
and reshell.sxp. The checker is tools/check_rung05.py.

    python3 tools/walk_rung05.py --out /tmp/sx-rung05
    python3 tools/walk_rung05.py --rows N1,A1,A2 --dry-run
    python3 tools/walk_rung05.py --from A8 --checkpoint --out /tmp/sx-rung05
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app05 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
