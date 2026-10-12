"""Rung-2 mesh export report.

Sequences the body guard, export_3mf, and the stage checker.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ExportReport:
    s0: bool
    s0_evidence: str
    exported: bool
    check_ok: bool
    check_text: str
    volume: object = None

    def __getitem__(self, key: str):
        return getattr(self, key)

    def get(self, key: str, default=None):
        return getattr(self, key, default)


def report_export(walk, stage: str, filename: str, width: float | None = None) -> ExportReport:
    w = walk.width() if width is None else float(width)
    guard = walk.s0(w)
    if not guard["ok"]:
        return ExportReport(
            False, guard["evidence"], False, False, "", guard.get("volume"),
        )
    path = walk.export_3mf(filename)
    first = float(walk.part()["widths"][0])
    extra = None if abs(w - first) < 1e-6 else ["--width", str(int(w))]
    code, text = walk.checker(stage, filename, extra)
    check_ok = code == 0 and "\nFAIL " not in ("\n" + text) and not text.startswith("FAIL")
    if "FAIL" in text:
        check_ok = False
    check_text = text.strip().splitlines()[-1] if text.strip() else ""
    return ExportReport(
        True,
        guard["evidence"],
        Path(path).is_file(),
        check_ok,
        check_text,
        guard.get("volume"),
    )
