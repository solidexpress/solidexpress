# Rung 8 result — round 5

**Does not pass the bar.** Walk 7 A23/A26 volume still red after 3 attempts. No `tools/confirm_all.sh` from row 1.

| Bar | Count |
|---|---|
| Head sha | `bb5f336` |
| Walks r1–r6, r8 | last green at `4d112db`: 77/77, 44/44, 46/46, 32/32, 36/36, 46/46, 48/48 — **not re-run** |
| Walk 7 | bbox **PASS** 281.450×54.590; volume **FAIL** 41996 vs 41705 (A23/A26 4/5). A21 C 1395.6 + two 2.3×10 islands at (24.1, ±5) |
| `check_rung05` | last **10/10** (`4d112db`) |
| `check_rung06` | last **7/7** |
| `check_rung07` | boss/neck 4/5 volume; `rung07_coincident` **23/0**; `rung07_boss` still PASS in isolation |
| `check_rung08` | last **pin 3/3 pipes 5/5 bolted 7/7 final 10/10** |
| Other checkers | wrench-t14 **18/22 DIAG** (T=14) |
| Headless | last **262/0** at `4d112db` — **not re-run** |
| Lint | not re-run this round |
| Critique | **9/10** (walk 8 product on last confirm; overall bar still red) |

## Critique — 9/10 (walk 8 product; overall bar still red)

Judged against UBC ELEC391 Ex 4 stills in `docs/loop/rung-08-frames/`. Named tools in the PDF’s order landed on the last confirm walk: File → **New Assembly** mmgs ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)); Insert Components nut / pipe / wrench ([fig-021-002.png](rung-08-frames/img/fig-021-002.png), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)); Float ([fig-021-004.png](rung-08-frames/img/fig-021-004.png)); Insert → **New Part** + origin **Front** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)); pin R10 / 35 / 55 / R5, revolve 360° barbell ([fig-022-006.png](rung-08-frames/img/fig-022-006.png), [fig-022-007.png](rung-08-frames/img/fig-022-007.png)); instance copy to **2 / 16 / 8 / 1** ([fig-022-008.png](rung-08-frames/img/fig-022-008.png)); Fix one pipe ([fig-023-009.png](rung-08-frames/img/fig-023-009.png)); Concentric inner pipes + Coincident centre flanges, joint Z=260 bbox 225×225×1040 ([fig-023-010.png](rung-08-frames/img/fig-023-010.png), [fig-024-011.png](rung-08-frames/img/fig-024-011.png)); ×8 concentric+coincident at the joint, first hole +Y, pin head −Z at 287.5 ([fig-024-012.png](rung-08-frames/img/fig-024-012.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)); wrench Coincident flange Z=250, jaw Coincident AF-20, **Tangent** curve, handle +X ([fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png)). Caps at 8 not used.

Off 10: walk 7 A23/A26 volume 41996 vs 41705 (C 1395 vs A_C 1496). Confirm_all from row 1 not run.

## Round 5 product

Shift-select prefers the elliptical arc once a handle is picked; coincident with only the strip selected welds ends that sit on a curve. Walk A18 second pick is the C body. Isolated handle-on-C coincident stays at the y=±10 hit (`rung07_coincident` 23/0). On the full sketch that coincident is rejected. Geometric seating of interior ends was tried and reverted (it ate the C pad). Hex-recovery bbox unchanged.
