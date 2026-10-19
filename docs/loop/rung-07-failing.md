# Rung 7 failing rows

Tree: `cursor/rung-07-20261018`. Confirm4 (`build/confirm4`) **PASS the bar** from row 1, no restores.

## Checklist rows not passing

None.

| Row | Symptom | Status |
|---|---|---|
| r1 N16/N11, r6 A14/A28 | walker flakes under 7 walks | **PASS** confirm4 (same pass as r7 46/46) |
| r7 A21 | open C at (−24.9, 5.4) | **PASS** A10 each jaw to its own steep tip |
| r7 A24 | Y 59.3 after R30 | **PASS** MakeFillet + AABB clip; confirm4 bbox 54.590 |
| r7 A28 A29 | Convert 0 arcs after fuse-wedge | **PASS** MakeFillet-first; A28 `external arc`, area 4172 |

## Resume gap

**Fixed.** `--from` restores `ckpts/<prev>.sxp` by opening the `ckpts/` folder.

## Pass bar (confirm4)

| Item | Want | Current |
|---|---|---|
| Rung 1–6 | 77/44/46/32/36/46 | **77/44/46/32/36/46** |
| Rung 7 | 46 | **46** |
| `check_rung07` | 281.4×54.6×10.0, vol 38782 ±1% | **281.450×54.590×10.000, 38878** |
| Headless | 0 failed | **244/0** |
| Checkers | 0 | **0** |
