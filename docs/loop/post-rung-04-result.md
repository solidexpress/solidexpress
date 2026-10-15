# Post-rung-4 cleanup — confirm pass

`tools/confirm_all.sh` on this VM, then a cached-godot re-walk of rung 1 after the mouth cut stayed Up To Surface (so 10→14 stays through).

| Bar | Count |
|---|---|
| Rung 1 walk | 77/77 |
| Rung 2 walk | 44/44 |
| Rung 3 walk | 46/46 |
| Rung 4 walk | 32/32 |
| Checkers | blank 5/5, wrench 28/28, noext 28/28, thick 7/7, DIAG 18/22, nut 7/7; r2 final 16/16; r3 final 29/29; r4 final 5/5 |
| Headless | 223 run, 0 failed (`lint_suites: 227 suites ok (73 ci, 150 full, 4 known-red)`) |
| Wrench clicks | critique **129** (85C 44K) → film **92** (47C 45K). `packaging/ci/click_budget.json` `max_actions` 92. |

Shipped: `SketchRegions`, `IntentResolver` (Cut + Through All on a region pick), host-face contour chips off, Trim kept for the wrench mouth, `SketchOffset.KINDS`, WP3 dummy `render=` + `run_tier` cache, click budget ratchet, hexkey film.

Parked: CommandBus / stay-armed fillet, Jaw template, mouth cap region pick (stroke still wins), SelectionContext, view-independent pick, HintLayer, keymap-as-data, pixel `render=viewport`.
