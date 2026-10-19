# Post-rung-7 cleanup — confirm pass

Part A: `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). Dummy renderer for headless. Walks on Xvfb. Confirm wall 3073 s (12:31:42–13:22:55 UTC) on `cursor/post-rung-07-cleanup-20261019`.

Part B: parked. C-one `film_spanner_tests.suite` stayed red after three honest attempts (S marking menu, off-screen handle clicks, R30 viewport pick hit the C ellipse / long handle edge). WP8 and WP9 reverted; WP10 not started. No `spanner` film, poster, or artifacts branch. See [`roadmap.md`](../plan/roadmap.md) §13.

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
| Rung 7 walk | 46 pass, 0 fail |
| `check_rung07` | final 8/8 |
| Headless | 244 run, 0 failed |
| Lint | `248 suites ok (82 ci, 162 full, 4 known-red)` |
| Film | none (Part B parked) |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 244. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered. Featured website set stays 12. No `.webm` / `.vtt` on this branch.

Units, registry, kernel, `lint_rung01_e2e` all 0.

## WPs

Shipped WP1–WP7 and WP11. ★ WP6 and WP7 started (WP1–WP5 green inside 4 hours). Parked WP8–WP10 (Part B). Final sweep of parked items: still red for the same viewport-fillet pick; left parked.

| WP | Title | Net |
|---|---|---|
| 1 | clock and lint line | empty commit |
| 2 | spent docs, STATUS, dead symbols | +14 / −423 |
| 3 | one PART table, one boot | +73 / −144 |
| 4 | NeckFillet.POLICY | +174 / −166 |
| 5 | neck fillet, jaw tip, weld as tables | +34 / −16 |
| 6 | FilmSteps midplane_extrude | +22 |
| 7 | WalkUI07 split into profile / boss / dress | +1015 / −980 |
| 8 | film spanner, manifest, how-to | reverted |
| 9 | film_spanner tests | reverted |
| 10 | poster and artifacts | not started |
| 11 | confirm_all + this file | this file |

No pending `gh release upload` for spanner: no WebM was rendered.
