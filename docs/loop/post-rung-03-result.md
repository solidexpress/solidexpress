# Post-rung-3 cleanup — confirm pass

`tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). One pass. Wall 1776 s.

| Bar | Count |
|---|---|
| Rung 3 walk | 46 pass, 0 fail |
| `check_rung03` | base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29 |
| Rung 1 walk | 77 pass, 0 fail |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 44 pass, 0 fail |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Headless | 214 run, 0 failed |
| Lint | `218 suites ok (67 ci, 147 full, 4 known-red)` |
| Film | `film_tutor1_tests` 13 checks, 0 failures, checker `29/29 passed` |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 214. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

`run_rung01_replan21_pick.gd` is green. `EdgeScreenPick` ranks a screen click: the edge closer to the cursor, then the one more parallel to the view, and the nearer camera edge only when the two are a stacked twin (same direction, same pixel). The wrench-neck horizontal is a crossing edge, so the vertical under the cursor wins. Tutor1 side-view corners are stacked twins, so the visible vertical still wins (R5 is 9 edges, R1.5 is 2).

`film_tutor1_tests` is in the 214. Smoke prints `- smoke skip tutor1` (and the same for `ubc_wrench` and `lesson2_box`).

Tutor1 WebM re-rendered on this VM (film script unchanged, poster unchanged): VP9 1600×900, container 61.800 s, video track 35.133 s, 18,808,869 bytes. Not committed. Copy at `/opt/cursor/artifacts/tutor1.webm` and `.vtt`.

WP3 stayed parked. The removed-half sample `(0, -40, 15)` lies behind the cap along the iso ray, so the framebuffer reads the cap colour. Dummy stays the starter. ★ WP6 and WP7 were not started.
