# Rung 8 failing — round 5 leftover

Test-and-fix on `cursor/rung-08-20261019`. Do not open a PR. Do not edit `docs/plan/STATUS.md`. Do not commit `.uid`.

Round-3 items stay closed. Glyphs/J6 stay closed. wrench-t14 **18/22** is by-design DIAG (T=14), not a regression.

A23 bbox **281.450×54.590** stays PASS (hex recovery punches A_RING 275). Round-5 seating that destroyed the C pad was reverted.

## Walk 7 A23 / A26 volume (finding, 3 attempts)

Boss/neck **4/5**: volume `41996` vs `41705` (0.71% over the 0.5% band). C contour **1395.6** vs A_C **1496** (Δ101 mm²). A21 lists five regions: handle 3994, C 1395.6, ring 275.2, plus two 2.3×10 mm islands at (24.1, ±5). Those islands are the missing C area; they are not selected as heads (`A_C` band 80). `run_rung07_boss.gd` never draws hexes or A18 overflow trims; `contour_count()==3` (3999/1496/855) volume **41693** PASS.

Kernel replica with leftover hex stubs + `handle_xy` is three regions 3999/1496/275. Walk A18 is what adds the split.

Root cause: the handle strips at y=±10 slightly enter the remaining elliptical arc, so OCCT splits two islands off the C. Frames t0264/t0297/t0315 weld the strip to the C at the y=±10 hit then Power Trim overflow. Isolated PlaneGCS point-on-ellipse at that hit stays at y=10 (kernel + `rung07_coincident` 23/0). On the live spanner sketch the same coincident is **rejected** (`Relation did not stick` / `coincident: failed`) — Horizontal + dim 10 + ring coincident + jaw/ellipse dims already busy the system.

Three volume attempts this round (seating reverted):

1. Walk/fixture coincident at `handle_xy` (~23, ±10) instead of `ellipse_major()`. Both Shift-picks landed on the strip (`Selected 1 sketch entity`); coincident was a no-op. Volume still 41996.
2. Product: Shift-select skips construction and prefers the curve; coincident with only a strip selected welds ends that sit on a curve. Walk second pick is the C body (24.7, 4). Two entities selected; solver dropped the relation. C stayed 1395.6.
3. Geometric seat of an interior line end onto the ellipse before extrude. `closest()` on the remaining arc jumped to a jaw vertex and pulled the handle through the C (A21 lost the 1496 pad, then 2 contours / ring 398). Length-filtered seat still dropped the C. Reverted.

Do not loosen the volume band. Do not repeat overflow-then-trim, OuterWire fill, skip-A18-trim, or unconstrained seating onto elliptical-arc ends.

Next lever (not this round): keep a **driving** point-on-curve that the busy sketch will accept (weaker sibling constraints on the strip, or a non-DogLeg solve of that coincident alone), so the handle end stays at the y=±10 hit without moving jaw vertices.

Cascade while volume is red: A23/A26 4/5, `check_rung07` boss/neck. Hex-recovery bbox PASS. wrench-t14 18/22 DIAG.
