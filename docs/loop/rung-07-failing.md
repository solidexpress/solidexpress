# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Confirm3 r1–r6 **PASS**. Rung 7 A21 open C.

## Checklist rows not passing

| Row | Symptom | Status |
|---|---|---|
| r1 N16/N11, r6 A14/A28 | prior walker flakes | **PASS** confirm3 |
| r7 **A24** Y 59.3 after R30 | MakeFillet T-points outside ellipse | **Fixed** (AABB clip). Isolated A24–A26 3/3. |
| r7 **A21** | N2 `open profile at (-24.9, 5.4)`; no body | **Attempt 1:** coincident leftover ends — arc JSON start/end are major-axis stubs. **Attempt 2:** snap Coincident on the broken sketch.sxp — still open. **Attempt 3:** A10 had both jaws Coincident to the **same** `ellipse_major()` (+Y tip); lower jaw can leave the C. Each jaw now point-on-curve to its own steep tip. |

## Resume gap

**Fixed.**

## Pass bar (confirm3)

| Item | Want | Current |
|---|---|---|
| Rung 1–6 | 77/44/46/32/36/46 | **77/44/46/32/36/46** |
| Rung 7 | 46 | **28** (A21) |
| Headless | 0 failed | **244/0** |
| Checkers | 0 | **0** |
