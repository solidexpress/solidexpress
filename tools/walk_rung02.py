#!/usr/bin/env python3
"""Walk the Lesson 2 box checklist against a live SolidExpress window.

Same arguments as tools/walk_rung01.py. Checkpoints are box.sxp, rounded.sxp,
shelled.sxp and final.sxp. The checker is tools/check_rung02.py.

    python3 tools/walk_rung02.py --out /tmp/sx-rung02
    python3 tools/walk_rung02.py --rows A1,A2,A3,A4,A5 --out /tmp/sx-rung02
    python3 tools/walk_rung02.py --from A7 --checkpoint --out /tmp/sx-rung02
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app02 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
