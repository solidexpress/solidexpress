# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Confirm2 at `b28962b` (after N11 wait-for-name.3mf) was **not** 46/46 on rung 7.

## Checklist rows not passing

| Row | Symptom | Status |
|---|---|---|
| r1 **N16** | result/restore timing under 7 walks | **PASS** 16.1s on confirm2. |
| r6 **A14** | `revolve.3mf` missing | **PASS** on confirm2 (7 concurrent walks). |
| r6 **A28** | `sweep.3mf` missing | **PASS** on confirm2. |
| r1 **N11** | `export_3mf wrench-noext` looked for the bare name | **PASS** on confirm2: `check-wrench-wrench-noext.txt` 28/28. |
| r7 **A24** / **A26** | After R30 neck fillet, bbox Y 54.587 → **59.299** (`neck.3mf` 4/5). Extra verts at x≈15–18, z=±3 (handle T). Boss export was 281.450×54.587×10.000. | **Fix attempt 1:** pick only length-6 Z-edges (reject missing length), wait for `N edge(s)` on each click, undo the fillet if live Y bbox balloons, retry 3×. |
| r7 **A33** | same bbox on `final.3mf` (7/8) | consequence of A24 |
| r7 **N4** | reopen still 59.299 Y | consequence of A24 |

## Resume gap

**Fixed.** `--from` restores `ckpts/<prev>.sxp` or chunk-start + prefix replay (`afe6a77`). Covered by `tools/test_walk_registry.py`. Confirm walks still run every row from the start with no restores.

## Pass bar (last confirm = confirm2 @ `b28962b`)

| Item | Want | Current |
|---|---|---|
| Rung 1 walk | 77 | **77** |
| Rung 2–6 | 44/46/32/36/46 | **44/46/32/36/46** |
| Rung 7 walk | 46 | **43** (A26 / A33 / N4 bbox Y) |
| `check_rung07` final | 8/8, 281.4×54.6×10.0, 38782 ±1% | **7/8**, 281.450×59.299×10.000, volume 38881 |
| Headless | 0 failed | **244 run, 0 failed** |
| Checkers | 0 | **0** |
