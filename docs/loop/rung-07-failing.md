# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Isolated walk after A10 (`/tmp/r7-a10`): A21 closed; A28/A29 convert failed.

## Checklist rows not passing

| Row | Symptom | Status |
|---|---|---|
| r1 N16/N11, r6 A14/A28 | prior walker flakes | **PASS** confirm3 |
| r7 **A21** | N2 open profile at (−24.9, 5.4) | **Fixed** A10: each jaw point-on-curve to its own steep tip. Isolated N2 `no selected contour` (closed); A21/A22 PASS. |
| r7 **A24** Y 59.3 after R30 | MakeFillet T-points outside ellipse | AABB clip kept. Isolated A24–A26 PASS (54.590). |
| r7 **A28 A29** | Isolated: handle-top area 3999.24 (unfilleted A_H); Convert 0 arcs (`edge is not on this face`); A29 `n=0` then rectangle recovery. Fuse-wedge caps sit beside the host face, so Convert refuses them. | **Attempt 1:** prefer MakeFillet again (circular arcs on the handle-top face) + AABB clip; unify after fuse fallback; extra Convert clicks at R30/R20 mids. |

## Resume gap

**Fixed.** `--from` restores snapshot or chunk-start + prefix replay.

## Pass bar

| Item | Want | Current |
|---|---|---|
| Rung 1–6 | 77/44/46/32/36/46 | **77/44/46/32/36/46** confirm3 |
| Rung 7 | 46 | isolated A10: **A21 PASS, A28/A29 FAIL** (A37 still running) |
| Headless | 0 failed | **244/0** confirm3 |
| Checkers | 0 | **0** |
