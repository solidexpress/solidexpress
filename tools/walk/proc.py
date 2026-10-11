"""Process launch for walk rows.

`run` turns OSError into returncode 127; `tail` is the last output line.
"""
from __future__ import annotations

import subprocess


def run(args: list[str], *, cwd, env: dict | None = None) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            args, cwd=str(cwd), capture_output=True, text=True, env=env,
        )
    except OSError as exc:
        return subprocess.CompletedProcess(args, 127, "", str(exc))


def tail(out: str | None, err: str | None) -> str:
    text = ((out or "") + (err or "")).strip()
    return text.splitlines()[-1] if text else "no output"
