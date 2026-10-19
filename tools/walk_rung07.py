#!/usr/bin/env python3
"""Walk the combination-spanner checklist against a live SolidExpress window.

Same arguments as tools/walk_rung06.py. Checkpoints are sketch.sxp and
neck.sxp. The checker is tools/check_rung07.py.

    python3 tools/walk_rung07.py --out /tmp/sx-rung07
    python3 tools/walk_rung07.py --rows N1,A1,A2 --dry-run
    python3 tools/walk_rung07.py --from A21 --checkpoint --out /tmp/sx-rung07
    python3 tools/walk_rung07.py --from A24 --dry-run --out /tmp/sx-rung07
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app07 import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
