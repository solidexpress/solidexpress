# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Isolated `--from A24` after the AABB clip is **3/3 PASS** (neck 5/5, bbox 281.450×54.590×10.000, volume 42820). Awaiting one full `confirm_all`.

## Checklist rows not passing

Rung 7 walk rows A26/A33/N4 on confirm2 were the same R30 Y-spike.

| Row | Symptom | Status |
|---|---|---|
| r1 **N16** | result/restore timing under 7 walks | **PASS** 16.1s on confirm2. |
| r6 **A14** | `revolve.3mf` missing | **PASS** on confirm2. |
| r6 **A28** | `sweep.3mf` missing | **PASS** on confirm2. |
| r1 **N11** | bare `wrench-noext` vs `name.3mf` | **PASS** on confirm2, 28/28. |
| r7 **A24** / **A26** | R30 MakeFillet grew Y 54.587 → 59.299 (T-points outside the ellipse). Volume still in band. | **Fix attempt 2:** prefer void-angle fuse; never fuse an unclipped wedge; Common the result to the boss AABB (Y tight). Isolated A24–A26 PASS. Walker still refuses the row if live Y balloons. |
| r7 **A33** / **N4** | same bbox on `final.3mf` | consequence of A24; isolated neck is now 54.590 |

## Resume gap

**Fixed.** `--from` restores `ckpts/<prev>.sxp` or chunk-start + prefix replay (`afe6a77`).

## Pass bar (last full confirm = confirm2 @ `b28962b`)

| Item | Want | Current |
|---|---|---|
| Rung 1 walk | 77 | **77** |
| Rung 2–6 | 44/46/32/36/46 | **44/46/32/36/46** |
| Rung 7 walk | 46 | **43** on confirm2; isolated A24–A26 **3/3** after clip |
| `check_rung07` final | 8/8, 281.4×54.6×10.0, 38782 ±1% | confirm2 **7/8** 59.299 Y; isolated neck **5/5** 54.590 |
| Headless | 0 failed | **244 run, 0 failed** |
| Checkers | 0 | **0** |
