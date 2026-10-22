# Rung 8 — walk 7 vs tutorial frames

Source stills: [`rung-07-frames/`](rung-07-frames/) (Mahtabalam combination spanner). Walk: `tools/walk/rung7/`. Film: `game/tests/films/film_spanner.gd` + `SpannerFixture`.

Same-build check (the A23 trick): go through the stills in order and name every place the walk’s solid is not the lesson solid. Do not loosen volume bands (`VOLUME=38782`, `V_NECK=42733`, `VOLUME_TOL=0.005` → final [38588, 38976], neck [42519, 42947]).

## Hex punch is now the same solid as the lesson

Tutorial punches the 12-point **in Sketch1**. Midplane 10 of the heads is already a ring (area 275). Walk A14 used to Power-Trim hex-side midpoints, open both hexes into stubs, A21 then read ring **~398**, and A23 `ensure_twelve_point_bore` added **sketch 4 / extrude 5**. That recovery is unused now.

Walk A14 calls `seal_box_end_hexes` (two **closed** AF-25 hexes + Ø33). Kernel nest-punches overlapping closed hexes to **A_RING 275.172**. Film does the same. FEATURES pin is `sketch 1 … fillet 10` with no extra Front sketch. Analytic: Ø33 − union of two AF-25 hexes = 855.299 − 580.127 = **275.172**.

Sketch wires still differ from [t0235.jpg](rung-07-frames/t0235.jpg) (lesson shows a trimmed 12-point; we keep two overlapping hex polygons). The extruded ring is the same hole.

## Step by step

| Tutorial (frame) | Walk / film | Same? |
|---|---|---|
| Front sketch, horizontal CL through origin ([t0031.jpg](rung-07-frames/t0031.jpg)) | A2 datum Front; A3 construction +X | yes |
| 3-click ellipse at origin ([t0042.jpg](rung-07-frames/t0042.jpg)) | A4 ellipse entity | yes |
| 17° construction, small angle on −X ([t0068.jpg](rung-07-frames/t0068.jpg)) | A5 | yes |
| Jaw parallel to 17°, coincident on the ellipse ([t0078.jpg](rung-07-frames/t0078.jpg), [t0084.jpg](rung-07-frames/t0084.jpg)) | A6 | yes |
| 55 on the **steep** chord, 50 along 17°, offset 12.50, jaw 20 ([t0100.jpg](rung-07-frames/t0100.jpg), [t0108.jpg](rung-07-frames/t0108.jpg), [t0117.jpg](rung-07-frames/t0117.jpg), [t0123.jpg](rung-07-frames/t0123.jpg)) | A7 | yes (frames win vs prep) |
| Mirror jaws about 17° ([t0135.jpg](rung-07-frames/t0135.jpg)) | A8 | yes |
| 3-point R15 at inner jaw ends ([t0147.jpg](rung-07-frames/t0147.jpg) `15.00mm`) | A9 | same tool |
| Power Trim the **outer** ellipse → C ([t0150.jpg](rung-07-frames/t0150.jpg), [t0156.jpg](rung-07-frames/t0156.jpg)) | A10 | yes when the mouth opens |
| Ø33 on the CL ([t0175.jpg](rung-07-frames/t0175.jpg)) | A11 | yes |
| Hex 1: Polygon, 6, **Inscribed circle**, AF 25, **point-up**, vertices inside Ø33 ([t0181.jpg](rung-07-frames/t0181.jpg), [t0192.jpg](rung-07-frames/t0192.jpg) 25 dim horizontal) | A12 Across Flats, vertex click at +Y; A14 `seal_box_end_hexes` | same 12-point solid |
| Hex 2: AF 25, ~30° ([t0208.jpg](rung-07-frames/t0208.jpg)) | A13 Vertex at 30° | yes (union is the same star) |
| **Power Trim inner leftovers → closed 12-point hole in Sketch1.** Trim-away-inside unused. Both 25 dims remain ([t0216.jpg](rung-07-frames/t0216.jpg) scissors on an inner segment; [t0235.jpg](rung-07-frames/t0235.jpg) 12-point already, Ø33 outer) | A14 does **not** click hex-side midpoints. Leaves two closed polygons; kernel overlapping-hex punch is A_RING 275 | **wires differ; solid matches** |
| 240 origin → Ø33 ([t0248.jpg](rung-07-frames/t0248.jpg)) | A15 | yes |
| Horizontal handle, 10 from CL ([t0264.jpg](rung-07-frames/t0264.jpg), [t0270.jpg](rung-07-frames/t0270.jpg)). 12-point **already in the sketch** | A16 overflow span | yes |
| Mirror handle about CL ([t0294.jpg](rung-07-frames/t0294.jpg)) | A17 | yes |
| East ends coincident on Ø33 (status X=226.87, Y=−10, [t0285.jpg](rung-07-frames/t0285.jpg)); west ends on the 17° ellipse; trim overflow ([t0297.jpg](rung-07-frames/t0297.jpg), [t0315.jpg](rung-07-frames/t0315.jpg)) | A18 coincident at (120, ±10) onto the circle; after trim, `_seat_handle_on_c_pad` writes y=±10 west onto the remaining elliptical arc (22.944 / 23.929) | **close** — Symmetric cannot coincident both west ends on that ellipse, so seat is a write not a relation |
| **One Front sketch: C + 12-point ring + handle.** Exit ([t0315.jpg](rung-07-frames/t0315.jpg), [t0321.jpg](rung-07-frames/t0321.jpg)) | L3/A19 three regions; ring is the punched hole | yes |
| Boss-Extrude1: Region\<1\>+\<2\> = both **heads**, Mid Plane 10, merge off. Ring already holed ([t0332.jpg](rung-07-frames/t0332.jpg), [t0335.jpg](rung-07-frames/t0335.jpg)) | A21 `keep={c,ring}` | yes (ring 275) |
| Boss-Extrude2: **same Sketch1**, handle, Mid Plane 6, merge on ([t0347.jpg](rung-07-frames/t0347.jpg)) | A22 Fuse Midplane 6 | yes |
| — no extra feature — | A23 is boss export only. `ensure_twelve_point_bore` is unused | yes |
| R30 open-end neck, R20 box-end ([t0366.jpg](rung-07-frames/t0366.jpg), [t0380.jpg](rung-07-frames/t0380.jpg)) | A24 / A25 `graph_add_fillet` both 6 mm crotches first. Kernel fuses void-wedges **before** MakeFillet (MakeFillet alone nicked ~390) | yes (both flanks) |
| Export neck. Volume **42733** | A26 | film **42841** (in 0.5%). Walk **42370** after 3 tries: R30 dv≈548 (one crotch, replica west-chord) vs 858/971. Logged as finding |
| Handle-top face cyan, Convert two lines + R30 + R20 ([t0385.jpg](rung-07-frames/t0385.jpg)) | A28 convert; A29 Offset 5 then Cut Blind 1. If offset “breaks the chain”, draw a racetrack. Film always draws the racetrack when convert fails | convert is the lesson; racetrack is recovery |
| Offset 5 inward ([t0415.jpg](rung-07-frames/t0415.jpg)); Cut Blind 1, area 1895.51 ([t0430.jpg](rung-07-frames/t0430.jpg)) | A29 | yes when convert+offset holds; racetrack ~1925 (+59 mm³) |
| R3 pocket ends ([t0462.jpg](rung-07-frames/t0462.jpg)); Mirror Front Plane, Fillet3+Cut ([t0483.jpg](rung-07-frames/t0483.jpg), [t0492.jpg](rung-07-frames/t0492.jpg)) | A30 / A31 | yes |
| R1 heads then remaining ([t0498.jpg](rung-07-frames/t0498.jpg) C-head outer, [t0516.jpg](rung-07-frames/t0516.jpg) remaining) | A32 / film `fillet_remaining`: **box-end 12-point face rims only**. C-head 10 mm Z-edge pulled xmin to 281.09; UI leftover created `fillet 11 failed` and hit recess limit 0.5. Rim-only dv≈−21 | **NO on C-head R1**; volume still in band |
| Final volume **38782** | A34 / N4 | film **38954–38967** (in 0.5%). Walk **38528** (7/8, volume only; neck deficit carries). Logged as finding |

Lesson timeline ([t0385.jpg](rung-07-frames/t0385.jpg) tree): Sketch1, Boss-Extrude1, Boss-Extrude2, Fillet1, Fillet2, Sketch2, … — **no** extra Front sketch to cut the bore. Ours: sketch 1, extrude 2, extrude 3, fillet 4, fillet 5, sketch 6, extrude 7, fillet 8, mirror 9, fillet 10.

## Volume budget after in-sketch hex

\(V_\mathrm{boss}+V_{30}+V_{20}=41705+858+170=42733\). Then \(−V_\mathrm{RECESS}+V_{R3}−V_{R1}=−3791+15−176=38782\).

Isolated film (hexkey then spanner, cloned `game/.godot`): C **1494.5**, handle **3998.1**, ring **275.2**, R30 dv **972**, R20 dv **170**, neck **42841**, R1 dv **−21**, final **38954–38967**, bbox **281.45**. Band holds. Extra vs 38782 is leftover R30-vs-analytic (~114) minus extra racetrack 59 minus rim R1 21.

Do not loosen the 0.5 % band. Do not restore leftover-hex recovery.

## Not a sketch difference

Film C-pad leak after `film_hexkey` was shared `game/.godot` **and** product trim/solve dropping the elliptical_arc. Suites now clone `game/` (incl `.godot`) plus unique HOME / XDG_* / TMPDIR / `MESA_SHADER_CACHE_DIR`. Product: stay armed, golden/recipe restore, rearm on pencil re-entry, never Power Trim C pad at x>5, seat handle only after trim. Hexkey then spanner **8/0 + 12/0**.
