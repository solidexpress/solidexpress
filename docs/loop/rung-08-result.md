# Rung 8 result — round 6

**Passes the bar.** Head `99100e1`. Confirm_all from row 1 (`SX_JOBS=1 SX_WALK_JOBS=1`, no restores) at `6530e5c`: headless **262/0**, walks 1–6 and 8 green; walk 7 A21 lost the C pad. C-head hold then walk 7 from row 1: **46/46**, boss/neck **5/5**, final **8/8**.

| Bar | Count |
|---|---|
| Head sha | `99100e1` |
| Walk 1 | **77/77** (confirm) |
| Walk 2 | **44/44** |
| Walk 3 | **46/46** |
| Walk 4 | **32/32** |
| Walk 5 | **36/36** |
| Walk 6 | **46/46** |
| Walk 7 | **46/46** from row 1 at `99100e1`. A21 C **1495.7**, handle **3999.3**, ring **275.2**. Boss vol **41692** vs 41705 (0.5%). Neck **42734**. Final bbox **281.450×54.590×10**, vol **38892** vs 38782 (0.28%) |
| Walk 8 | **48/48** (confirm) |
| `check_rung05` | **10/10** |
| `check_rung06` | **7/7** |
| `check_rung07` | boss **5/5**, neck **5/5**, final **8/8** |
| `check_rung08` | pin **3/3**, pipes **5/5**, bolted **7/7**, final **10/10** |
| Other checkers | wrench **28/28**, wrench-t14 **18/22 DIAG** (T=14) |
| Headless | **262/0** (confirm + walk 7 A37) |
| Lint | **266** suites ok (89 ci, 173 full, 4 known-red) |
| Critique | **9/10** |

## Critique — 9/10

Judged against UBC ELEC391 Ex 4 stills in `docs/loop/rung-08-frames/` and the combination-spanner frames in `docs/loop/rung-07-frames/`.

Walk 8 named tools in the PDF’s order: File → **New Assembly** mmgs ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)); Insert Components nut / pipe / wrench ([fig-021-002.png](rung-08-frames/img/fig-021-002.png), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)); Float ([fig-021-004.png](rung-08-frames/img/fig-021-004.png)); Insert → **New Part** + origin **Front** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)); pin R10 / 35 / 55 / R5, revolve 360° barbell ([fig-022-006.png](rung-08-frames/img/fig-022-006.png), [fig-022-007.png](rung-08-frames/img/fig-022-007.png)); instance copy to **2 / 16 / 8 / 1** ([fig-022-008.png](rung-08-frames/img/fig-022-008.png)); Fix one pipe ([fig-023-009.png](rung-08-frames/img/fig-023-009.png)); Concentric inner pipes + Coincident centre flanges, joint Z=260 bbox 225×225×1040 ([fig-023-010.png](rung-08-frames/img/fig-023-010.png), [fig-024-011.png](rung-08-frames/img/fig-024-011.png)); ×8 concentric+coincident at the joint, first hole +Y, pin head −Z at 287.5 ([fig-024-012.png](rung-08-frames/img/fig-024-012.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)); wrench Coincident flange Z=250, jaw Coincident AF-20, **Tangent** curve, handle +X ([fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png)).

Walk 7 A16–A18 follows t0270–t0300: strip drawn long from (18, ±10) into the C, Horizontal + dim 10, Mirror, ring coincidents, Trim at the C. No dual end-on-ellipse coincident. After trim the left ends sit at (22.94, 10) and (23.93, −10) ([t0297](rung-07-frames/t0297.jpg), [t0300](rung-07-frames/t0300.jpg)). C area 1496, bbox 281.45×54.59×10.

Off 10: confirm_all’s first walk 7 at `6530e5c` lost the C pad (ring/handle DogLeg); one product restore then 46/46. wrench-t14 stays 18/22 DIAG. Caps at 8 not used.

## Round 6 product

Andy’s three fixes were already on the branch (long-strip trim, trim rebind, diagnose lists + residual gate). This round:

1. Ground sketches always seal the two-circle stadium (stale `[0,1]` chips after the third island).
2. `drop_circle_slivers` keeps a disjoint r=3 / r=1 disk; only leftover cells inside a larger CircPad drop.
3. Tangent is mid-edge; do not weld AF-hex vertices onto the inscribed circle. Distance pins still weld stadium rim hits. New contour islands default on.
4. Once a ring circle exists, snapshot the Front C (x < 80) and put it back after solve so hex/handle DogLeg cannot open the 1496 pad.
