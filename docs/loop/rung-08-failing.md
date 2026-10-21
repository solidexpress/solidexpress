# Rung 8 failing — round 4 leftover

Test-and-fix on `cursor/rung-08-20261019`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

Round-3 items stay closed. Glyphs/J6 stay closed. wrench-t14 **18/22** is by-design DIAG (T=14), not a regression.

The original A23 handle-only bbox (`226.876×37.295`) is closed: A14 Power Trim opens the hexes so nest never sees hole wires (Ø33 reads ~823). Product recovers the two AF hexes from vertices on the common circumradius and punches only the circle pad (A_RING 275). r4b bbox **281.450×54.590** PASS.

## Walk 7 A23 / A26 volume (finding, 3 attempts)

Boss/neck still **4/5**: volume `41996` vs `41705` (0.71% over the 0.5% band). C contour is **1395** vs A_C **1496** (Δ101 mm², two holes at the handle-C junction, crumbs at (24.1, ±5)). `run_rung07_boss.gd` never draws hexes or A18 overflow trims; it stays `contour_count()==3` (handle 3999, C 1496, disc 855) and volume **41693** PASS.

Kernel replica with leftover hex stubs + `handle_xy` is three regions 3999/1496/275. Walk A18 coincident to `ellipse_major()` (the +Y tip, not the handle hit) plus trim at (18, ±10) on a strip that already sits on the curve is what the walk adds.

Three volume attempts, all reverted:

1. Draw overflowing handle like t0264, then trim — coincident ellipse failed; trim at (232, ±10) split the strip through Ø33 (bbox 251.8).
2. Fill nested holes &lt;120 mm² on non-circle pads via `OuterWire` — replaced the C with a 31 mm² fragment.
3. Skip A18 trim unless a profile line is within 1.5 mm — without the trim the 0.34 mm handle overshoot shatters the C (no 1496/1395 pad; A21 heads miss).

Do not loosen the volume band. Next lever (not this round): coincident the handle *end* to the elliptical_arc at the hit (~23, ±10), not to the major-axis tip.

Cascade while volume is red: A23/A26 4/5, `check_rung07` boss/neck. Final was 38641 vs 38782 PASS on r4b.
