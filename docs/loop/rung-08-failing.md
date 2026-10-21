# Rung 8 failing — round 3 leftover

Test-and-fix on `cursor/rung-08-20261019`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

Round-3 items 1–3 are closed (confirm-r7 headless **262/0**; Shade/Frame IGNORE while placing; walk 1 A15 and walk 2 A25 PASS). Glyphs/J6 stay closed. Do not re-open them.

## Walk 7 A23 — heads extrude the handle pad (finding, 3 attempts)

A21/A22 report C + ring + handle among 8 contours (A14 leftover hex triangles, lines=20). `finish:Extrude` Midplane 10 still builds only the handle strip:

`got 226.876×37.295×10.000 min (−0.000,−10.000,−5.000)` want `281.4×54.6×10.0 min (−24.95,−27.30,−5.00)`.

Attempt-3 areas: Contour1 3994.3 (handle ≈ A_H 3999), Contour2 1385.7 (C vs A_C 1495.8, Δ110), Contour3 822.9 (full Ø33 disc, not A_RING 275). `select_contours` by area still yields the handle-only body. Cascade A24–A26 / L4 / A28 / A33–A35. `check_rung07` boss 1/5, neck 1/5, final 1/8.

Three attempts (chip re-assert; select_contours + uncheck + chips; area pick, no chip-toggle). Do not loosen the bbox. `run_rung07_boss.gd` and film_spanner stay **12/0** with bbox 281.450×54.591×10 (`contour_count()==3`).

Walk 8 assembly is green (48/48, `check_rung08` 10/10).
