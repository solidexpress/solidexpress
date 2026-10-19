# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Confirm at `0f114f0` (after N16/A14/A28 walker fixes) was **not** yet 77/77.

## Checklist rows not passing

Rung 7: **None.** 46/46, `check_rung07` 8/8 (281.450×54.591×10.000, volume 38747).

| Row | Symptom | Status |
|---|---|---|
| r1 **N16** | result/restore timing under 7 walks | **PASS** 16.2s on the same confirm |
| r6 **A14** | `revolve.3mf` missing | **PASS** |
| r6 **A28** | `sweep.3mf` missing | **PASS** |
| r1 **N11** | `export_3mf wrench-noext failed after retries: missing …/wrench-noext` | **Fix attempt 1:** wait for `name.3mf` (product appends the extension) and for `Exported 3MF`, not the bare name. Bare `wrench-noext` must stay absent (N11 clause). |

## Resume gap

**Fixed.** `--from` restores `ckpts/<prev>.sxp` or chunk-start + prefix replay.

## Pass bar (last confirm)

| Item | Want | Current |
|---|---|---|
| Rung 1 walk | 77 | **76** (N11 runner-gap from the 3MF retry) |
| Rung 2–7 | 44/46/32/36/46/46 | **44/46/32/36/46/46** |
| Headless | 0 failed | **244 run, 0 failed** |
| Checkers | 0 | **0** |
