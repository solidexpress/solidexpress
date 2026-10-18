# Rung 6 result — confirm on this branch

**PASS the bar.** `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable), dummy renderer for headless, walks on Xvfb. Confirm ran at `7372006`.

| Bar | Count |
|---|---|
| Rung 1 walk | 77 rows, PASS 77 |
| Rung 2 walk | 44 rows, PASS 44 |
| Rung 3 walk | 46 rows, PASS 46 |
| Rung 4 walk | 32 rows, PASS 32 |
| Rung 5 walk | 36 rows, PASS 36 |
| Rung 6 walk | 46 rows, PASS 46 |
| `check_rung05` final | 10/10 |
| `check_rung06` final | 7/7, bbox 304.064×220.000×223.972 mm (want 304.1×220×224.0 ± 0.2), volume 1,729,551 mm³ (want 1,730,343 ± 0.5 %) |
| Headless suites | 236 run, 0 failed |
| Checkers (units) | `test_check_rung02/03/04/05/06.py` 0, registry 0, lint_suites 0, kernel 0 |
| spine | arc |

## Critique — 9/10 (pass ≥ 9)

Judged against SolidWorks Tutorials – Revolve & Sweep (m7GuVfPN164) and the stills in `docs/loop/rung-06-frames/`. Named tools in the video’s order land on the confirm walk: File → New `mmgs`, Front sketch ([t0052.jpg](rung-06-frames/t0052.jpg)), Line 20 / 220 / 90, Tangent Arc R10 from the top-horizontal end ([t0104.jpg](rung-06-frames/t0104.jpg)), 3-point R20, Equal then drop so 40 + 80 remain ([t0350.jpg](rung-06-frames/t0350.jpg)), R60 + R12.50, Revolve Blind 360° about the 220 line ([t0385.jpg](rung-06-frames/t0385.jpg)), Front path 60 + R150 + R20 hook not a line ([t0670.jpg](rung-06-frames/t0670.jpg)), two-point Horizontal on the hook ends, silhouette dim 10, Right-plane ellipse 35×10 ([t0715.jpg](rung-06-frames/t0715.jpg)), Swept Boss fuse Follow path ([t0820.jpg](rung-06-frames/t0820.jpg)), top-disc Ø30 ([t0828.jpg](rung-06-frames/t0828.jpg)), Cut Blind 25 draft 15° inward ([t0867.jpg](rung-06-frames/t0867.jpg), [t0878.jpg](rung-06-frames/t0878.jpg)). Walk 46/46 and `check_rung06.py final` 7/7 (handle xmax 192.097 on +X, one body, drafted hole occupied at (13, 195, 0)). Headless 236/0. Rungs 1–5 at bar.

Findings that keep it off 10:

1. **Foreshortened radius leaders** — [t0524.jpg](rung-06-frames/t0524.jpg) / [t0670.jpg](rung-06-frames/t0670.jpg) R150 leader. Display only; out of scope.
2. **Hidden Lines Removed** — [t0492.jpg](rung-06-frames/t0492.jpg) path sketch. W cycle stays Shade / Edges / Wire.
3. **Rim clip y ≥ 0** — [t0350.jpg](rung-06-frames/t0350.jpg) and [t0820.jpg](rung-06-frames/t0820.jpg) read as a rim on the baseline; the checker clips the R12.50 toe so the solid sits on the y = 0 disc.
4. **Equal** — the walk clicks it ([t0233.jpg](rung-06-frames/t0233.jpg)) then drops it so DOF is 0; the finished still ([t0350.jpg](rung-06-frames/t0350.jpg)) shows 40 and 80 without Equal.

Not used as stand-ins: 32-gon ellipse; face-draft as the hole; polyline ribbon that fails the checker; path “20” as a line; Equal kept; handle on −X; two bodies; a straight cut.

## WPs

Shipped WP1–WP16. WP7 circular spine ran (`spine: arc`). None reverted. Caps at 8 not used.
