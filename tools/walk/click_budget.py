"""Count clicks and keys from SX_INPUT_TRACE. CI ratchets max_actions down."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUDGET_PATH = ROOT / "packaging" / "ci" / "click_budget.json"
PRESS_RE = re.compile(r"\[input-trace\].*\bpress\b")
KEY_RE = re.compile(r"\[key-trace\].*pressed=1.*echo=0")


def count_trace(text: str) -> dict[str, int]:
    clicks = len(PRESS_RE.findall(text))
    keys = len(KEY_RE.findall(text))
    return {"clicks": clicks, "keys": keys, "actions": clicks + keys}


def load_budget(path: Path | None = None) -> dict:
    p = path or BUDGET_PATH
    return json.loads(p.read_text(encoding="utf-8"))


def check_log(log_text: str, film_id: str, budget: dict | None = None) -> tuple[bool, str]:
    table = budget if budget is not None else load_budget()
    row = table.get(film_id) or {}
    cap = int(row.get("max_actions", 129))
    got = count_trace(log_text)
    ok = got["actions"] <= cap
    note = (
        f"{film_id}: {got['clicks']}C {got['keys']}K = {got['actions']} "
        f"(budget {cap})"
    )
    return ok, note
