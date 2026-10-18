# Post-rung-6 cleanup — confirm pass

Part A: `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). Dummy renderer for headless. Walks on Xvfb. Confirm wall 2358 s (05:23:42–06:03:00) on `cursor/post-rung-06-cleanup-20261018` at `8e10fa8`.

Part B: candlestick film on `cursor/candlestick-film-20261018`. Headless + walk 6 after WP8 `draw_line` span restore (08:05:11–08:33:21). Dummy renderer. Walk 6 on Xvfb `:29`.

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
| Headless | 237 run, 0 failed |
| Lint | `241 suites ok (79 ci, 158 full, 4 known-red)` |
| Film | `film_candlestick_tests` 12 checks, 0 failures, checker `7/7 passed`, bbox 304.109×220×223.998 |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 237. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered. Smoke prints `- smoke skip candlestick owned by film_candlestick_tests`. Featured website set stays 12. No `.webm` / `.vtt` on the film branch. Walk 6 `check_rung06` final 7/7 at bbox 304.056×220.000×223.972 (TOL 0.2).

Units, registry, kernel, `lint_rung01_e2e` all 0.

`precision_plate` calibrated at 115 s wall (685 frames). candlestick 352 s wall at 30 fps. WebM is VP9 1600×900; container 67.200 s is the unique-frame video track (2016 frames, dup=1514). Last caption 01:57.667 is process-clock. Poster `website/assets/screenshots/candlestick.png` is video-track frame 2015. WebM/VTT/PNG are on `origin/cursor/demo-artifacts-candlestick` and `/opt/cursor/artifacts/`.

`candlestick.webm` is not on Release `demo-movies`. Pending:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber candlestick.webm candlestick.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies candlestick
```

## WPs

Shipped WP1–WP11. ★ WP6 and WP7 started (WP1–WP5 green inside 4 hours). Part B WP8–WP10 on `cursor/candlestick-film-20261018` (WalkUI06 click sequence, not a fresh pick path). None parked.

| WP | Title | Net |
|---|---|---|
| 1 | clock and lint line | empty commit |
| 2 | spent docs, STATUS, dead symbols | +18 / −376 |
| 3 | one CandlestickFixture, one PART table | +256 / −291 |
| 4 | BooleanTarget, FaceLabelPark, ARM_CLEAR | +130 / −85 |
| 5 | FilmSteps tangent, 3-point, ellipse, sweep, draft | +157 / −28 |
| 6 | SweepFuse.POLICY | +114 / −116 |
| 7 | WalkUI06 split into profile / path / cut | +976 / −900 |
| 8 | film candlestick, manifest, how-to | +378 / −6, then draw_line span 280 |
| 9 | film_candlestick tests | +197 / −17 across C-one retries |
| 10 | poster and pending publish | +28 / −5 + PNG |
| 11 | mixin imports, then Part A result | +5 / −1 on the imports, then this file |

WP8 film uses `CandlestickFixture` click builders matching WalkUI06 (named Front/Right datums, walk path UVs, top-disc KEY_3 + `enter_sketch_on_face`). FEATURES pin: `sketch 1, revolve 2, sketch 3, sketch 4, path 5, sweep 6, sketch 7, extrude 8`. Default `draw_line` span must stay 280 so `rung06_refs` / `rung06_tangent_arc` keep a closed revolve; the film passes 0 after `_frame_uv`.
