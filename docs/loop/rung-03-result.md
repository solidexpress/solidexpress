# Rung 3 result — confirm pass on `d94cd82`

**PASS.** `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable), after the sketch-tools suite was put back to a radius label. Critique 2 (`rung-03-critique-2.md`, score 4/10 on `f355557`) is unchanged.

| Bar | Count |
|---|---|
| Rung 3 walk | 46/46 |
| `check_rung03` | base 3/3, boss 4/4, cut 5/5, r5 14/14, rounded 16/16, final 29/29, final-reopen 29/29 |
| Rung 1 walk | 77/77 |
| Rung 1 checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7 |
| Rung 2 walk | 44/44 |
| `check_rung02` | final-60 16/16, final-65 16/16 |
| Headless suites | 213 run, 0 failed |

L7 wall sample after the 1 mm shell: `[158, 168, 184]`, the cap colour. Removed half `[83, 86, 95]`. Outline inside.

## What is left

- DIAG 18/22 is the four T=10 rows on a T=14 wrench. By design.
- Four known-red suites stay red: `run_rung01_replan12_pick.gd`, `run_rung01_replan3_timeline.gd`, `run_rung01_replan_input.gd`, `run_rung01_sketch_tests.gd`.
- `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.
- The video score was not rejudged. The walk and checkers that critique 2 failed now pass.
