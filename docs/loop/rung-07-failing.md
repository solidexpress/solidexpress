# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Confirm3 (`cbac5d8`) r1–r6 **PASS**. Rung 7 **28/46**: A21 open profile, no body.

## Checklist rows not passing

| Row | Symptom | Status |
|---|---|---|
| r1 **N16** N11, r6 **A14 A28** | prior walker flakes | **PASS** on confirm2 and confirm3 |
| r7 **A24** Y 59.3 after R30 | MakeFillet T-points outside ellipse | **Fixed** in kernel (AABB clip). Isolated A24–A26 3/3. Confirm3 never reached A24 (A21). |
| r7 **A21** | `two pads=[]`. N2: `open profile at (-24.9, 5.4). Close that vertex.` Jaw outer not welded to the C. Contour chips empty. | **Fix attempt 1:** coincident leftover ends — still open (arc JSON start/end are major-axis stubs). **Attempt 2:** snap Coincident jaw → steep ellipse tips (point-on-curve). |

## Resume gap

**Fixed.** `--from` restores snapshot or chunk-start + prefix replay.

## Pass bar (confirm3 @ `cbac5d8`)

| Item | Want | Current |
|---|---|---|
| Rung 1–6 | 77/44/46/32/36/46 | **77/44/46/32/36/46** |
| Rung 7 | 46 | **28** (A21 open C) |
| Headless | 0 failed | **244 run, 0 failed** |
| Checkers | 0 | **0** |
