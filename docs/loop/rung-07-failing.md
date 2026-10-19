# Rung 7 failing rows — handoff at `9d2a3d8`

Tree: `cursor/rung-07-20261018`. Rung 7 checklist 46/46 is green. The previous confirm (`tools/confirm_all.sh` at `a8aa1c7`) was **not** one clean pass: rung 1 and rung 6 dropped rows under seven concurrent walks. Those rows are the work list. Do not rewrite passing rung 7 modeling.

## Checklist rows not passing

Rung 7: **None.** All 46 rows of [`rung-07-checklist.md`](rung-07-checklist.md) PASSed (`build/confirm/walk7`: 46/46).

Concurrent-walk flakes (treat as failing until one clean `confirm_all`):

| Row | Symptom | Cause | Status |
|---|---|---|---|
| r1 **N16** | `result then restore` FAIL (`dt` outside 2.0–4.0 s, or a `[hover-trace]` in the 4 s window). Isolated `--from N16 --checkpoint` PASS | `STATUS_HOLD_MS` is 2500 ms; restore runs on `_process`. A wall-sleep lets Godot starve so `_hint_tick` is late; any hover-trace after the mark was treated as "between" | **Fix attempt 1:** pump `wait_idle` until restore; hover only between result and restore; Δt 2.0–6.0 s (`tools/walk/rung1/rows_chunk5.py`) |
| r6 **A14** | `exported` FAIL: `revolve.3mf` missing. Isolated retry 46/46 | File → Export 3MF + tessellate/zip of the revolve under 7-walk RAM; dialog can close with no file | open: `tools/walk/gestures.py` `export_3mf` |
| r6 **A28** | `exported` FAIL: `sweep.3mf` missing. Isolated retry 46/46 | Same export path as A14, larger sweep mesh | open: same as A14 |

## Resume gap

**Fixed.** `--from` / `--rows` that do not start at row 1 restore `ckpts/<prev>.sxp` when present, else the latest chunk-start `.sxp` and a replay of the preceding rows (from N1 if `--out` has no file). A full walk still starts empty and writes `ckpts/<row>.sxp` after each PASS. Test: `WalkRegistryTests.test_resume_mid_chunk_replays_prefix_or_restores_snapshot`.

## Already passing (rung 7 checklist)

N1 A1 A2 L1 A3 A4 A5 A6 A7 A8 A9 A10 L2 A11 A12 A13 A14 A15 A16 A17 A18 L3 A19 A20 N2 A21 A22 A23 A24 A25 A26 L4 A27 A28 N3 A29 A30 A31 A32 A33 A34 A35 L5 A36 N4 A37.

## Pass bar

| Item | Want | Current |
|---|---|---|
| Rung 1 walk | 77 | **76** on confirm (N16 flake); isolated 77 |
| Rung 2 walk | 44 | **44** |
| Rung 3 walk | 46 | **46** |
| Rung 4 walk | 32 | **32** |
| Rung 5 walk | 36 | **36** |
| Rung 6 walk | 46 | **44** on confirm (A14/A28); isolated 46 |
| Rung 7 walk | 46 | **46** |
| `check_rung07` bbox | 281.4×54.6×10.0 ± 0.2 | **PASS** 281.450×54.591×10.000 |
| `check_rung07` volume | 38,782 ± 1% | **PASS** 38,748 (0.087%) |
| Checkers | 0 | **0** |
| Headless | 0 failed | **244 run, 0 failed** |
| Critique | ≥ 9/10 | **9/10** in `rung-07-result.md` |

## Notes

- Do not commit untracked `*.uid` files.
- Do not open a PR. Never touch PR #11. Never use the snadrus fork.
