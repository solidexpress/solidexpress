# Rung 5 result — confirm on this branch

**PASS the bar.** `tools/confirm_all.sh` on this VM (OCCT 8.0.1, Godot 4.7-stable), dummy renderer for headless, walks on Xvfb. Confirm sha `e04abaf` (A15 floors read each concatenated suite block; wrench/keys checks sit past 80k).

| Bar | Count |
|---|---|
| Rung 1 walk | 77 rows, PASS 77 |
| Rung 2 walk | 44 rows, PASS 44 |
| Rung 3 walk | 46 rows, PASS 46 |
| Rung 4 walk | 32 rows, PASS 32 |
| Rung 5 walk | 36 rows, PASS 36 |
| `check_rung05` final | 10/10, `final.3mf` written |
| Headless suites | 228 run, 0 failed |
| Checkers (units) | `test_check_rung02/03/04/05.py` 0, registry 0, lint_suites 0, kernel 0 |

## Critique — 9/10 (pass ≥ 9)

Judged against UBC ELEC391 Exercise 3 (PDF printed pp. 12–16). Named tools for the PDF exist and the confirm walk lands them: File → New `mmgs`, Front sketch, Circle Ø150, Extrude Blind 250, Shift+click both planar ends then `strip:shell` Thickness 10, flange Face sketch Ø225 Fuse Blind 10, Ø130 + Ø10 at `(0, 94)` with distance 94 and Vertical, Circular Sketch Pattern count 8 / 360°, Cut Blind 10, `mirror:Features` of the four timeline features about `z = 0`, re-shell the −Z half 10, Fillet R5 on both flange outer faces (4 circular edges). Walk 36/36 and `check_rung05.py final` 10/10 (bbox 225×225×520 ± 0.2, volume inside 0.5 %, walls 10, both ends open, 8 bolts per flange). Headless 228/0. Rungs 1–4 at bar.

Findings that keep it off 10:

1. **Face-first fillet** — the PDF names ID and OD of the base; the walk clicks each flange annulus and `FilletPick.POLICY` takes the circular loop (2 then 4 edges). Same four rims, not edge-by-edge.
2. **Select leftover after SmartDim** — unshifted click on one of a leftover pair isolates it so Vertical can add the Ø10. The PDF is two centre picks with no leftover pair.

Not used as stand-ins: body-mirror; eight hand-drawn circles; Through All cut; a Hole feature for the bolt circle; a linear pattern; skipping re-shell.

## WPs

Shipped WP1–WP8 and WP9 confirm. WP9 walk/product: circle Select vs fill, Shift additive (never a region), isolate-among-several, A15 suite-block parser. Reverted: wider rim stroke (`8aa1add` / `3ff248c`). Caps at 8 not used.
