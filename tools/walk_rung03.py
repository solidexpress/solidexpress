#!/usr/bin/env python3
"""Walk the Lesson 1 parts checklist against a live SolidExpress window.

Same arguments as tools/walk_rung02.py. Checkpoints are base.sxp, boss.sxp,
cut.sxp, rounded.sxp and final.sxp. The checker is tools/check_rung03.py.

    python3 tools/walk_rung03.py --out /tmp/sx-rung03
    python3 tools/walk_rung03.py --rows A1,A2,L1,A3,N2,A4,A5 --out /tmp/sx-rung03
    python3 tools/walk_rung03.py --from A6 --checkpoint --out /tmp/sx-rung03
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app03 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
