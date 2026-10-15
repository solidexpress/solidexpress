#!/usr/bin/env python3
"""Walk the hex-key checklist against a live SolidExpress window.

Same arguments as tools/walk_rung03.py. Checkpoints are hex.sxp and path.sxp.
The checker is tools/check_rung04.py.

    python3 tools/walk_rung04.py --out /tmp/sx-rung04
    python3 tools/walk_rung04.py --rows N1,A1,A2 --dry-run
    python3 tools/walk_rung04.py --from A7 --checkpoint --out /tmp/sx-rung04
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app04 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
