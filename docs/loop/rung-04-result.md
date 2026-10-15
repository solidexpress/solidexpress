# Rung 4 result — confirm on this branch

**PASS the bar.** `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable), dummy renderer for headless, walks on Xvfb. Failures at `d0a734e` counts were not environmental: WP5 `ray_hit` treated iso pick rays as origin-plane hits.

| Bar | Count |
|---|---|
| Rung 1 walk | 77 rows, PASS 77 |
| Rung 2 walk | 44 rows, PASS 44 |
| Rung 3 walk | 46 rows, PASS 46 |
| Rung 4 walk | 32 rows, PASS 32 |
| `check_rung04` final | 5/5, `final.3mf` written |
| Headless suites | 221 run, 0 failed |
| Checkers (units) | `test_check_rung02/03/04.py` 0, registry 0, lint_suites 0, kernel 0 |
| spine | polyline; WP9 checker passed. WP10 skipped. |

## Critique — 9/10 (pass ≥ 9)

Judged against Pano Central, Swept Boss, 7:33. Named tools for the video exist and the confirm walk lands them: File → New `mmgs`, Front/Right origin planes, AF polygon + driving 7.65, two-point Vertical on the chip row, Ctrl+8 Normal To, perimeter tangent Ø30, construction-aware trim, Swept Boss `sweep:Boss` / Profile / Path / Ok. Walk 32/32 and `check_rung04.py final` 5/5 (bbox 7.650×98.417×41.417, volume inside 0.5 %). Headless 221/0.

Findings that keep it off 10:

1. **Polyline spine** — WP9 checker passed (chord error ~2 mm³). WP10 arc spine was not started; the video bend is still a polyline.
2. **Origin AF hex** — construction inscribed circle plus origin pin; PlaneGCS reports redundant constraints on that commit. The profile stays six lines and DOF 0 after Vertical.

Not used as stand-ins: fillet-for-bend, key 8 as Normal To, Ctrl+click pads as the Swept Boss command (the walk armed `sweep:Boss`).

## WPs

Shipped this continuation: WP9, WP11, WP12. WP10 skipped (checker already 0). None reverted.
