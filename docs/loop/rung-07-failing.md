# Rung 7 failing rows

Tree: `cursor/rung-07-20261018` @ `c180027`. Isolated `--from A24` after MakeFillet-first: A24–N4 PASS.

## Checklist rows not passing

| Row | Symptom | Status |
|---|---|---|
| r1 N16/N11, r6 A14/A28 | prior walker flakes | **PASS** confirm3 |
| r7 **A21** | N2 open profile at (−24.9, 5.4) | **Fixed** A10: each jaw to its own steep tip. Isolated A10: A21/A22 PASS. |
| r7 **A24** Y 59.3 after R30 | MakeFillet T-points | AABB clip kept. `--from A24` A24–A26 3/3, bbox 281.450×54.590×10.000, V_NECK 42589. |
| r7 **A28 A29** | Fuse-wedge caps not on handle-top (area A_H); Convert 0 arcs | **Fixed** MakeFillet-first. `--from A24` A28 area 4172, A29 n=7 arcs. Final 281.450×54.590×10.000 vol 38747.568. |

## Resume gap

**Fixed.** `--from` restores `ckpts/<prev>.sxp` by opening the `ckpts/` folder (file list cannot select a nested relative name).

## Pass bar

`confirm_all.sh` (`build/confirm4`, started 09:08 UTC) headless **244/0**. Walks in flight.
