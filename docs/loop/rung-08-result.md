# Rung 8 result — confirm on this branch

**Does not pass the bar.** One `tools/confirm_all.sh` (`SX_JOBS=1 SX_WALK_JOBS=1`, `build/confirm-wp11`, started 00:40 UTC, walk8 ended 02:23 UTC) on this VM (OCCT 8.0.1, Godot 4.7-stable). Headless dummy renderer; walks on Xvfb :21–:28 from row 1 with no restores. Tree `b787e32`. Findings: [`rung-08-failing.md`](rung-08-failing.md).

| Bar | Count |
|---|---|
| Build / import / kernel | 0 / 0 / 0 (`All tests passed (11222 assertions in 458 test cases)`) |
| Lint | `lint_suites` 266 ok (89 ci, 173 full, 4 known-red); `lint_e2e` 0 |
| Registry | 17 tests OK |
| Units | `test_check_rung02/03/04/05/06/07/08.py` 0; `unit_sx_exact` 3 OK |
| Headless suites | **262 run, 17 failed** (want 0) |
| Rung 1 walk | 77 rows, PASS 76, FAIL 1 (A15 headless), wall 474.7s |
| Rung 2 walk | 44 rows, PASS 43, FAIL 1 (A25 headless), wall 220.6s; checkers 16/16 |
| Rung 3 walk | 46 rows, PASS 45, FAIL 1 (A26 headless), wall 224.5s; checkers 29/29 |
| Rung 4 walk | 32 rows, PASS 31, FAIL 1 (A21 headless), wall 116.5s; checkers 5/5 |
| Rung 5 walk | 36 rows, PASS 35, FAIL 1 (A25 headless), wall 220.5s; `check_rung05` final **10/10** |
| Rung 6 walk | 46 rows, PASS 45, FAIL 1 (A36 headless), wall 386.6s; `check_rung06` final **7/7** |
| Rung 7 walk | 46 rows, PASS 35, FAIL 11, wall 697.1s (overlapped suite rerun); solo `/tmp/sx-rung07-solo` PASS 28 FAIL 13 BLOCKED 5, wall 972.4s; `check_rung07` final **3/8** |
| Rung 8 walk | 48 rows, PASS 47, FAIL 1 (A37 headless), wall 782.8s |
| `check_rung08 pin` | **3/3**, bbox 20.000×55.000×19.994, volume 6930.733 (want 6938 ± 0.5 %) |
| `check_rung08 pipes` | **5/5**, bbox 225.000×224.990×1040, joint z=260 zsize=1040 |
| `check_rung08 bolted` | **7/7**, counts pipe 2 / nut 16 / pin 8, nuts 8+8, first hole +Y |
| `check_rung08` final | **10/10**, bbox 322.497×228.995×1040.000 min (−112.500, −112.495, −260.000), volume 5,539,868 (want 5,540,194 ± 1 %), wrenchMates z250 jaw20 tangent |

Walks 1–6 product rows are green; each walk’s only FAIL is the A15-class headless evidence row (`suites: 262 run, 17 failed`). Walk 8 product rows are green (47/47); A37 is the same headless row. Walk 7 is product-red (handle / open-end / neck).

L/S: Catch2 458/0 including WP-L1…L12 / S1 / S2. `rung08_*.suite` exactness/spline/typed/doubles/json/export suites are not in the 17. V1–V8 cheap suites are not in the 17.

## Critique — 9/10 (walk 8 product; overall bar still red)

Judged against UBC ELEC391 Ex 4 stills in `docs/loop/rung-08-frames/`. Named tools in the PDF’s order land on this confirm walk: File → **New Assembly** mmgs ([page-20.jpg](rung-08-frames/page-20.jpg), [fig-020-001.png](rung-08-frames/img/fig-020-001.png)); Insert Components nut / pipe / wrench ([fig-021-002.png](rung-08-frames/img/fig-021-002.png), [fig-021-003.png](rung-08-frames/img/fig-021-003.png)); Float ([fig-021-004.png](rung-08-frames/img/fig-021-004.png)); Insert → **New Part** + origin **Front** ([fig-022-005.png](rung-08-frames/img/fig-022-005.png)); pin R10 / 35 / 55 / R5, revolve 360° barbell ([fig-022-006.png](rung-08-frames/img/fig-022-006.png), [fig-022-007.png](rung-08-frames/img/fig-022-007.png)); instance copy to **2 / 16 / 8 / 1** ([fig-022-008.png](rung-08-frames/img/fig-022-008.png)); Fix one pipe ([fig-023-009.png](rung-08-frames/img/fig-023-009.png)); Concentric inner pipes + Coincident centre flanges, joint Z=260 bbox 225×225×1040 ([fig-023-010.png](rung-08-frames/img/fig-023-010.png), [fig-024-011.png](rung-08-frames/img/fig-024-011.png)); ×8 concentric+coincident at the joint, first hole +Y, pin head −Z at 287.5 ([fig-024-012.png](rung-08-frames/img/fig-024-012.png), [fig-025-013.png](rung-08-frames/img/fig-025-013.png)); wrench Coincident flange Z=250, jaw Coincident AF-20, **Tangent** curve, handle +X ([fig-025-015.png](rung-08-frames/img/fig-025-015.png), [fig-025-014.png](rung-08-frames/img/fig-025-014.png), [fig-025-016.png](rung-08-frames/img/fig-025-016.png)). `check_rung08.py final` 10/10. Caps at 8 not used.

Findings that keep it off 10:

1. **Headless 17** on the same build — A37 (and rungs 1–6 A15-class) cannot go green. Same family as walk 7 handle/jaw: `run_film_spanner_tests.gd` extrude-3 boolean, `replan10_cut` open-shell 4398/8796, `rung07_boss` bbox 232.6×33 vs 281.4×54.6.
2. **Rung 7 walk** — confirm 35/46; clean solo A22 handle contour did not commit the second extrude (`still in a sketch`), cascade A23–A26, `check_rung07.py final` 3/8 (xmin 23.9, no −X open end).
3. **Lock / HLR** — PDF optional Lock mate and Hidden Lines Removed stay out of scope (plan decision 13; VS #12).

Not used as stand-ins: File → New (part) as the assembly; ground-body revolve + Place as the pin; Pattern around joint as the ×8 path; Fastened as the wrench curve; overall-50 pin; outer-flange joint; origin-stacked 3MF; skip bolt-hole Concentric.

## WPs

Shipped WP-L1…L12, WP-S1/S2, WP1–WP10, WP-V0…V8, then walk-row fixes (N2/A7, pin seed, mate uuid, pin dump/seat) and WP11 `SX_WALK_JOBS=1`. None reverted. Featured films not re-shot.
