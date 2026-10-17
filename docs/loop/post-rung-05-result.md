# Post-rung-5 cleanup — confirm pass

`tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable). One pass after the tutor1 `FacePick` click fix. Wall 1751 s.

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
| Headless | 229 run, 0 failed |
| Lint | `233 suites ok (75 ci, 154 full, 4 known-red)` |
| Film | `film_flanged_pipe_tests` 12 checks, 0 failures, checker `10/10 passed` |

DIAG 18/22 is the four T=14 rows, by design. The four known-red suites are not in the 229. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered. Smoke prints `- smoke skip flanged_pipe owned by film_flanged_pipe_tests`.

Units, registry, kernel, `lint_rung01_e2e` all 0.

`precision_plate` calibrated at 110 s wall for a 29.6 s film, so flanged_pipe stayed at 30 fps (194 s wall). WebM is VP9 1600×900; container 60.800 s matches the last caption (01:00.800). Video track 36.133 s (1084 frames). Poster `website/assets/screenshots/flanged_pipe.png` is the video-track end. WebM/VTT are not in git (`/opt/cursor/artifacts/flanged_pipe.webm` and `.vtt`).

`flanged_pipe.webm` is not on Release `demo-movies`. Pending:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber flanged_pipe.webm flanged_pipe.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature flanged_pipe
```

## WPs

Shipped WP1–WP10 and the WP11 confirm. ★ WP6 and WP7 started (WP1–WP5 green inside 4 hours). None reverted. None parked.

| WP | Title | Net |
|---|---|---|
| 1 | clock and lint line | empty commit |
| 2 | spent docs, STATUS, dead symbols, uids | +24 / −418 |
| 3 | identical walk helpers on WalkChrome | +87 / −187 |
| 4 | one PipeFixture, one PART table | +215 / −299 |
| 5 | FilmSteps pattern, mirror, two-face shell | +134 |
| 6 | shared near-match walk UI bodies | +111 / −246 |
| 7 | headless log names as a table | +22 / −15 |
| 8 | film flanged_pipe, manifest, how-to | +349 |
| 9 | film_flanged_pipe tests, pin 4 fillet edges | +215 / −22 |
| 10 | poster and pending publish | +24 + PNG |
| 11 | FacePick click, then annulus rim; this result | +16 / −8 on the click, then this file |

WP11 click: the WP9 always-offset of `FacePick.point` when XY < 40 put tutor1's boss pick in the Ø60 hole (`film_tutor1_tests` 5 failures). Click the documented point first; only then the outer rim. C-one after the fix: tutor1 13/0, flanged_pipe 12/0, rung05_fillet 27/0, rung05_reshell 15/0.
