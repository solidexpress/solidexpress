# Rung 7 failing rows

Tree: `cursor/rung-07-20261018` @ `9e03632`. Confirm2 (`tools/confirm_all.sh`) is in Godot suites after the N11 runner-gap fix. Confirm at `0f114f0` was **not** 77/77.

## Checklist rows not passing

Rung 7: **None.** 46/46, `check_rung07` 8/8 (281.450×54.591×10.000, volume 38747) on confirm `0f114f0` and the prior isolated walk.

| Row | Symptom | Status |
|---|---|---|
| r1 **N16** | result/restore timing under 7 walks | **PASS** 16.2s on confirm `0f114f0`. Fix: pump frames, not wall-sleep (`f80b0e9`). |
| r6 **A14** | `revolve.3mf` missing | **PASS** on confirm `0f114f0` (7 concurrent walks). Fix: retry export until the file exists (`7ed23c1`). |
| r6 **A28** | `sweep.3mf` missing | **PASS** same confirm. Same retry. |
| r1 **N11** | `export_3mf wrench-noext failed after retries: missing …/wrench-noext` | **Fix attempt 1** (`9e03632`): wait for `name.3mf` (product appends the extension) and for `Exported 3MF`, not the bare name. Bare `wrench-noext` must stay absent (N11 clause). Isolated `--from N11` with empty `out/` is not a valid resume (chunk 6 checkpoint is pre-fillet `wrench-wip.sxp`). Awaiting confirm2. |

## Resume gap

**Fixed.** `--from` restores `ckpts/<prev>.sxp` or chunk-start + prefix replay (`afe6a77`). Covered by `tools/test_walk_registry.py`. Confirm walks still run every row from the start with no restores.

## Pass bar (last confirm)

| Item | Want | Current (`0f114f0`, pre-N11 fix) |
|---|---|---|
| Rung 1 walk | 77 | **76** (N11 runner-gap from the 3MF retry) |
| Rung 2–7 | 44/46/32/36/46/46 | **44/46/32/36/46/46** |
| Headless | 0 failed | **244 run, 0 failed** |
| Checkers | 0 | **0** |
