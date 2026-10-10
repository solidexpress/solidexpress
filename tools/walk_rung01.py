#!/usr/bin/env python3
"""Walk the sx-041 checklist against a live SolidExpress window.

Launches the app with SX_AUTOMATION=1 and SX_INPUT_TRACE=1, drives each row
through tools/sxdrive.py, and writes WALK_LOG.md plus walk_report.json.
Product failures are recorded. This script does not change the CAD code.

    python3 tools/walk_rung01.py --out /tmp/sx-041
    python3 tools/walk_rung01.py --rows A8,L4 --out /tmp/sx-041
    python3 tools/walk_rung01.py --from N21b --out /tmp/sx-041
    python3 tools/walk_rung01.py --from A7 --checkpoint --out /tmp/sx-041

A full walk reloads a chunk's checklist file when the previous chunk did not
end in the expected state, and builds a missing cut.sxp / wrench-wip.sxp from
the last good save. --checkpoint forces that reload for a partial --from run.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from walk.app import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
