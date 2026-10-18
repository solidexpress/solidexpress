# Post-rung-6 cleanup — confirm pass

`tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). Dummy renderer for headless. Walks on Xvfb. Confirm wall 2358 s (05:23:42–06:03:00). WP7 mixins omitted `R12_BULGE` / `SxError`; first confirm walk 6 was 30 pass + NameError on A11/A13/A21. One-line import fix, then walk 6 rerun **46/46** (411.5 s). One flake in between (A31 cut-miss, 42/46); rerun green.

| Bar | Count |
|---|---|
| Rung 1 walk | 77 pass, 0 fail |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 44 pass, 0 fail |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Rung 3 walk | 46 pass, 0 fail |
| `check_rung03` | base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29 |
| Rung 4 walk | 32 pass, 0 fail |
| `check_rung04` | final 5/5 |
| Rung 5 walk | 36 pass, 0 fail |
| `check_rung05` | final 10/10 |
| Rung 6 walk | 46 pass, 0 fail |
| `check_rung06` | final 7/7 |
| Headless | 236 run, 0 failed |
| Lint | `240 suites ok (79 ci, 157 full, 4 known-red)` |
| Film | none (Part B parked; no `candlestick` suite) |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 236. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered. Featured website set stays 12. No `.webm` / `.vtt` on this branch. No pending `gh release upload`.

Units, registry, kernel, `lint_rung01_e2e` all 0.

## WPs

Shipped WP1–WP7 and the WP11 import fix + this confirm. ★ WP6 and WP7 started (WP1–WP5 green inside 4 hours). Part B WP8–WP10 parked (`roadmap.md` §12): C-one `film_candlestick_tests.suite` stayed red after two attempts; WP8 reverted; WP9 never committed; WP10 not started.

| WP | Title | Net |
|---|---|---|
| 1 | clock and lint line | empty commit |
| 2 | spent docs, STATUS, dead symbols | +18 / −376 |
| 3 | one CandlestickFixture, one PART table | +256 / −291 |
| 4 | BooleanTarget, FaceLabelPark, ARM_CLEAR | +130 / −85 |
| 5 | FilmSteps tangent, 3-point, ellipse, sweep, draft | +157 / −28 |
| 6 | SweepFuse.POLICY | +114 / −116 |
| 7 | WalkUI06 split into profile / path / cut | +976 / −900 |
| 8 | film candlestick, manifest, how-to | reverted |
| 9 | film_candlestick tests | never committed |
| 10 | poster and pending publish | not started |
| 11 | mixin imports, then this result | +5 / −1 on the imports, then this file |

WP8/WP9 C-one: attempt 1 second Front sketch failed (`Start sketch on picked face or ground`); attempt 2 path+ellipse+sweep landed with an extra Path feature, bbox 310.8×230.9×230.0 vs 304.1×220×224.0, `FilmUI: side face not selected` on the +Y top-disc pick, checker 4/7.
