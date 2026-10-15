# Rung 4 result — confirm on `c55d82b`

**FAIL the bar.** `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable), one re-run after a Vertical/trim/role walk fix (`SX_JOBS=1`). `rung04_sweep.suite` on the WP9 polyline solid was 28/0 with `check_rung04.py final` 5/5 (volume 6311.131). The confirm walks and headless tier did not hold the bar.

| Bar | Count |
|---|---|
| Rung 1 walk | 76 rows, PASS 58, FAIL 13, runner-gap 5 (want 77/77) |
| Rung 2 walk | 44 rows, PASS 25, FAIL 18, BLOCKED-by-A19 1 (want 44/44) |
| Rung 3 walk | 46 rows, PASS 20, FAIL 23, BLOCKED 3 (want 46/46) |
| Rung 4 walk | 32 rows, PASS 18, FAIL 13, BLOCKED-by-A15 1 (want 32/32) |
| `check_rung04` final | missing `final.3mf` on the walk export |
| Headless suites | 221 run, 41 failed |
| Checkers (units) | `test_check_rung02/03/04.py` 0, registry 0, lint_suites 0, kernel 0 |
| spine | polyline; WP9 checker passed. WP10 skipped. |

## Critique — 6/10 (pass needs ≥ 9)

Judged against Pano Central, Swept Boss, 7:33 (prep transcript; not re-watched). Named tools for the video exist: File → New `mmgs`, Front/Right origin planes, AF polygon + driving 7.65, two-point Vertical, Ctrl+8 Normal To, perimeter tangent Ø30, construction-aware trim, Swept Boss `sweep:Boss` / Profile / Path / Ok. The WP9 click suite built the centred key (bbox 7.650×98.417×41.417, volume inside 0.5 %).

Findings that cap the score:

1. **Walk A5 Vertical** — the relation lives in `… More`. The walk click fired Vertical with an empty selection (`Select entities with the Sel tool first`), so the hex stayed flats-horizontal. Video step 4 did not land in the walk.
2. **Walk A12 Trim** — the Ø30 circle stayed a circle. Path role became profile; Swept Boss then took the open hex as the path (`profile has an open loop`). Video steps 11 and 14 did not land in the walk.
3. **Confirm headless 41 failed** — films and face-pick suites red on this pass (same pattern as parallel lavapipe load). Not a video-tool miss, but the bar is 0 failed.
4. **Polyline spine** — WP9 checker passed (chord error ~2 mm³). WP10 arc spine was not started.

Not used as stand-ins: fillet-for-bend, key 8 as Normal To, Ctrl+click pads as the Swept Boss command (the walk armed `sweep:Boss`).

## WPs

Shipped this continuation: WP9, WP11, WP12 (docs + one walk fix). WP10 skipped (checker already 0). None reverted.
