# Post-rung-3 cleanup — confirm pass

`tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). One pass. Wall 1452 s.

| Bar | Count |
|---|---|
| Rung 3 walk | 45 pass, 1 fail (A26) |
| `check_rung03` | base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29 |
| Rung 1 walk | 76 pass, 1 fail (A15) |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 43 pass, 1 fail (A25) |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Headless | 214 run, 1 failed |
| Lint | `218 suites ok (67 ci, 147 full, 4 known-red)` |
| Film | `film_tutor1_tests` 13 checks, 0 failures, checker `29/29 passed` |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 214. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

The one headless failure is `tests/run_rung01_replan21_pick.gd`. At the neck junction, view 55 / y=-10 jitter clicks pick a horizontal edge (`dir.z=0`, length 20) instead of the vertical. That is the WP8 screen tie-break: when alignment is within 0.05 it keeps the edge nearer the camera. A15, A25, and A26 fail only because they require `214 run, 0 failed`. Part checkers above are from the walks, not from that suite.

`film_tutor1_tests` is in the 214 and did not fail. Smoke prints `- smoke skip tutor1` (and the same for `ubc_wrench` and `lesson2_box`).

WP3 stayed parked after a retry. Pixel suites still return early on a headless display (`cap pixels skipped`, `viewport pixels skipped`). X11 + Vulkan does draw, and `frame_post_draw` arrives, but `rung03_section` then fails because the removed-half sample is the cap colour. Dummy stays the starter. ★ WP6 and WP7 were not started.
