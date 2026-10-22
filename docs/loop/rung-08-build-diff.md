# Rung 8 — walk 7 vs tutorial frames

Source stills: [`rung-07-frames/`](rung-07-frames/) (Mahtabalam combination spanner). Walk: `tools/walk/rung7/`. Film: `game/tests/films/film_spanner.gd` + `SpannerFixture`.

Same-build check (the A23 trick): go through the stills in order and name every place the walk’s solid is not the lesson solid. Do not loosen volume bands.

## The volume miss (A26 / A34 / N4)

Tutorial punches the 12-point **in Sketch1**. Midplane 10 of the heads is already a ring (area 275). Walk A14 Power-Trims hex-side midpoints, opens both hexes into stubs, A21 then reads ring **~398** (unpunched / leftover triangles), and A23 `ensure_twelve_point_bore` adds **sketch 4 / extrude 5** (24-gon star Cut). That later cut is not in the video and is the leftover-hex recovery. Neck **42154** vs **42733** and final **38312** vs **38782** sit on that extra feature, not on a band problem.

## Step by step

| Tutorial (frame) | Walk / film | Same? |
|---|---|---|
| Front sketch, horizontal CL through origin ([t0031.jpg](rung-07-frames/t0031.jpg)) | A2 datum Front; A3 construction +X | yes |
| 3-click ellipse at origin ([t0042.jpg](rung-07-frames/t0042.jpg)) | A4 ellipse entity | yes |
| 17° construction, small angle on −X ([t0068.jpg](rung-07-frames/t0068.jpg)) | A5 | yes |
| Jaw parallel to 17°, coincident on the ellipse ([t0078.jpg](rung-07-frames/t0078.jpg), [t0084.jpg](rung-07-frames/t0084.jpg)) | A6 | yes |
| 55 on the **steep** chord, 50 along 17°, offset 12.50, jaw 20 ([t0100.jpg](rung-07-frames/t0100.jpg), [t0108.jpg](rung-07-frames/t0108.jpg), [t0117.jpg](rung-07-frames/t0117.jpg), [t0123.jpg](rung-07-frames/t0123.jpg)) | A7 | yes (frames win vs prep) |
| Mirror jaws about 17° ([t0135.jpg](rung-07-frames/t0135.jpg)) | A8 | yes |
| 3-point R15 at inner jaw ends ([t0147.jpg](rung-07-frames/t0147.jpg) `15.00mm`) | A9 | same tool; confirm-now once read r=13.64 (not this round’s remaining item) |
| Power Trim the **outer** ellipse → C ([t0150.jpg](rung-07-frames/t0150.jpg), [t0156.jpg](rung-07-frames/t0156.jpg)) | A10 | yes when the mouth opens |
| Ø33 on the CL ([t0175.jpg](rung-07-frames/t0175.jpg)) | A11 | yes |
| Hex 1: Polygon, 6, **Inscribed circle**, AF 25, **point-up**, vertices inside Ø33 ([t0181.jpg](rung-07-frames/t0181.jpg), [t0192.jpg](rung-07-frames/t0192.jpg) 25 dim horizontal) | A12 Across Flats, vertex click at +Y | same 12-point; AF `start_angle=0` can swap which hex is point-up vs the still |
| Hex 2: AF 25, ~30° ([t0208.jpg](rung-07-frames/t0208.jpg)) | A13 Vertex at 30° | yes (union is the same star) |
| **Power Trim inner leftovers → closed 12-point hole in Sketch1.** Trim-away-inside unused. Both 25 dims remain ([t0216.jpg](rung-07-frames/t0216.jpg) scissors on an inner segment; [t0235.jpg](rung-07-frames/t0235.jpg) 12-point already, Ø33 outer) | A14 clicks **every hex-side midpoint** (`4 < dist ≤ 12.6`, apothem is 12.5). `trim_at` splits those sides into **stubs**, so nest never sees hole wires. Film `_trim_hex_inners` is the same path, then `_ensure_ring_circle` redraws Ø33 if trim ate it | **NO — this is the construction miss** |
| 240 origin → Ø33 ([t0248.jpg](rung-07-frames/t0248.jpg)) | A15 | yes |
| Horizontal handle, 10 from CL ([t0264.jpg](rung-07-frames/t0264.jpg), [t0270.jpg](rung-07-frames/t0270.jpg)). 12-point **already in the sketch** | A16 draws an overflow span; 12-point may already be stubs | handle yes; box-end not |
| Mirror handle about CL ([t0294.jpg](rung-07-frames/t0294.jpg)) | A17 | yes |
| Ends coincident on Ø33 (status X=226.87, Y=−10, [t0285.jpg](rung-07-frames/t0285.jpg)) and on the ellipse; trim overflow ([t0297.jpg](rung-07-frames/t0297.jpg), [t0315.jpg](rung-07-frames/t0315.jpg)) | A18 coincident at (120, ±10) onto the circle; does **not** coincident both ends onto the rotated ellipse (Symmetric still binds them); Power Trim overflow | close; ellipse-end is trim not coincident |
| **One Front sketch: C + 12-point ring + handle.** Exit ([t0315.jpg](rung-07-frames/t0315.jpg), [t0321.jpg](rung-07-frames/t0321.jpg)) | L3/A19 “three regions” is a tautology; ring may still be a disc | **NO if hex stubs** |
| Boss-Extrude1: Region\<1\>+\<2\> = both **heads**, Mid Plane 10, merge off. Ring already holed ([t0332.jpg](rung-07-frames/t0332.jpg), [t0335.jpg](rung-07-frames/t0335.jpg)) | A21 `keep={c,ring}`. Area gate is ±50 around 275; 398 falls through to the bbox gate and still selects the disc | **NO — A21 ring 398 vs 275** |
| Boss-Extrude2: **same Sketch1**, handle, Mid Plane 6, merge on ([t0347.jpg](rung-07-frames/t0347.jpg)) | A22 Fuse Midplane 6 | yes (when A21 made two pads) |
| — no extra feature — | A23 `ensure_twelve_point_bore`: new Front sketch, `sketch_add_twelve_point` 24-gon star, Cut Midplane 10. Film also `ensure_ring_pad` (Ø33 fuse) if xmax is short. Timeline grows **sketch 4 / extrude 5** | **NO — leftover-hex recovery** |
| R30 open-end neck, R20 box-end ([t0366.jpg](rung-07-frames/t0366.jpg), [t0380.jpg](rung-07-frames/t0380.jpg)) | A24 / A25 | same tools |
| Export neck. Volume **42733** | A26 | **off when recovery cut a different hole** (42154) |
| Handle-top face cyan, Convert two lines + R30 + R20 ([t0385.jpg](rung-07-frames/t0385.jpg)) | A28 convert; A29 Offset 5 then Cut Blind 1. If offset “breaks the chain”, draw a racetrack. Film always draws the racetrack | convert path is the lesson; racetrack is recovery |
| Offset 5 inward ([t0415.jpg](rung-07-frames/t0415.jpg)); Cut Blind 1, area 1895.51 ([t0430.jpg](rung-07-frames/t0430.jpg)) | A29 | yes when convert+offset holds |
| R3 pocket ends ([t0462.jpg](rung-07-frames/t0462.jpg)); Mirror Front Plane, Fillet3+Cut ([t0483.jpg](rung-07-frames/t0483.jpg), [t0492.jpg](rung-07-frames/t0492.jpg)) | A30 / A31 | yes |
| R1 heads then remaining ([t0498.jpg](rung-07-frames/t0498.jpg), [t0516.jpg](rung-07-frames/t0516.jpg)) | A32 | yes |
| Final volume **38782** | A34 / N4 | **off when the boss hole was the recovery star** (38312) |

Lesson timeline ([t0385.jpg](rung-07-frames/t0385.jpg) tree): Sketch1, Boss-Extrude1, Boss-Extrude2, Fillet1, Fillet2, Sketch2, … — **no** extra Front sketch to cut the bore.

## What “in-sketch hex” means here

Kernel already punches two **closed** AF-25 hexes inside Ø33 to one 12-point hole of area **275.172** (`contour_faces overlapping hexes inside a circle are one 12-point hole`). That is the [t0235.jpg](rung-07-frames/t0235.jpg) / [t0335.jpg](rung-07-frames/t0335.jpg) solid.

SolidWorks Power Trim of the inner leftovers **keeps** those hex sides as a closed 12-point. Ours `trim_at` on the same midpoints **opens** them. So the walk must **not** click-trim hex-side midpoints; leave the two closed polygons from A12/A13, drop the A23 star Cut.

Analytic ring: Ø33 minus union of two AF-25 hexes = 855.299 − 580.127 = **275.172**. A 398 pad is that disc minus a partial hole (~123 mm² still solid). Cutting a 24-gon star later from a fused body is not the same 10 mm ring, which is why neck/final sit ~1.3 % low.

## Not this round

Film C-pad leak after `film_hexkey` (shared `game/.godot`) is a suite-isolation bug, not a sketch difference. Walk 6 sweep / open 3MF and wrench-t14 DIAG are unchanged.
