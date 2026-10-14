# Post-rung-3 cleanup — confirm pass

`tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). Part B is parked (`docs/plan/roadmap.md` §9): no `tutor1` film and no video. Headless stays **213**.

| Bar | Count |
|---|---|
| Rung 3 walk | 46 pass, 0 fail |
| `check_rung03` | base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29 |
| Rung 1 walk | 77 pass, 0 fail |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 44 pass, 0 fail |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Headless | 213 run, 0 failed |
| Lint | `217 suites ok (67 ci, 146 full, 4 known-red)` |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 213. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

WP3 stayed parked, so the pixel suites are still in the 213 and still return early on a headless display. Smoke still runs `ubc_wrench` and `lesson2_box`.
