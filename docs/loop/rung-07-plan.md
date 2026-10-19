# Rung 7 plan — combination spanner (Mahtabalam)

**PLAN only, no product code.** One BUILD agent implements this in order, one commit per work package, on the branch it is given. Push that branch. Do not open a PR. Source: [How to Sketch Combination Spanner in Solidworks](https://www.youtube.com/watch?v=RZB8m9li098) (CAD CAM Tutorial / Mahtabalam, 9:19). Everything from the video is in [`rung-07-prep.md`](rung-07-prep.md), the 296 stills in [`rung-07-frames/`](rung-07-frames/), and below. Do not re-watch it. The row text is [`rung-07-checklist.md`](rung-07-checklist.md); do not restate it.

No visual-survey batch this rung.

Model: `rung-06-plan.md` package shape (goal, files, change, line delta, one cheap check, revert). Part / frame / walk like `rung-03-plan.md` and `rung-06-plan.md`. Same machinery (`tools/walk/` `Rung`, `automation-bridge.md`).

**Frames are mandatory evidence.** Every view, plane, dimension, click target and expected on-screen state below cites a file in `docs/loop/rung-07-frames/` that was opened for this plan. Where frames and narration disagree, **follow the frames** (called out in Decisions). Where frames and the prep disagree, **follow the frames** and say so.

## Where we are

Baseline: `main` `b783d695` (rung 6 #275 + bump 0.1.5 #276 + post-rung-6 cleanup #278). This branch is cut from there. Seed `4c6d415` is prep and frames only. The prep grepped `24a8306`; cleanup #278 was layering (`CandlestickFixture`, `BooleanTarget`, `FaceLabelPark`, FilmSteps, `SweepFuse.POLICY`, WalkUI06 split) + a parked candlestick film — it did **not** close any spanner modeling gap (re-grepped on this tree). Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. Rung 5 36/36. Rung 6 46/46. Headless 236/0 (`docs/loop/post-rung-06-result.md`). `tools/test_walk_registry.py` freezes those six row lists.

Rung 7 goal: build the combination spanner with the **named tools in the video's order**, by clicking, and end on a solid that passes `tools/check_rung07.py` at every stage.

Pass bar (all of):

- One solid. Bbox **281.4 × 54.6 × 10.0** mm, min corner `(−24.95, −27.30, −5.00)`.
- Volume **38782** mm³ within **±1 %** until WP1's OCCT replica; then **0.5 %** like rung 5 (the replica may replace the digit, not the band). Prep’s 282.9 × 50.4 × 10.0 and ~4.09e4 used the ellipse axes swapped vs the stills — not a second target (see Pass-bar numbers).
- Handle on **+X**. Open-end on **−X**. Two mid-plane thicknesses (heads 10, handle 6). Recess **both** faces. No extruded lettering.
- Every checklist row PASS (no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`). Critique ≥ 9 (rule at the end).
- On the same build: rung 1 walk 77/77, rung 2 44/44, rung 3 46/46, rung 4 32/32, rung 5 36/36, rung 6 46/46, `check_rung01/02/03/04/05/06/07.py` at their bars, headless `0 failed`.

Whole-plan acceptance is **WP10 only**. Earlier packages run the one cheap check they name. They do not run `make test`, `make test-godot`, `confirm_all.sh`, or a walk without `--dry-run`.

## Frame (decision, not a question)

Same axis map as rungs 3–6. Front = XY (normal +Z). Sketch Y on Front is world +Y (up). Origin = open-end ellipse centre. Handle runs +X. Mid-plane extrude straddles Z = 0. Units MMGS. Millimetre values on the stills.

| Item | Video (frame) | SolidExpress |
|---|---|---|
| Units | MMGS, new part. Intro drawing only ([t0021.jpg](rung-07-frames/t0021.jpg), [t0022.jpg](rung-07-frames/t0022.jpg) still the drawing while he says *select front plane*) | Already `state.units = mmgs`. Pinned New sentence unchanged. |
| First sketch | **Front**, status `*Front` ([t0031.jpg](rung-07-frames/t0031.jpg)) | Datum Front, Sketch. Ground path, plane XY. Basis `x = +X`, `y = +Y`. |
| Centerline | Horizontal construction through the origin, +X, pointer 180° ([t0031.jpg](rung-07-frames/t0031.jpg)) | Line + construction. Infer-horizontal on +X. |
| Ellipse | 3-click, centre at the origin ([t0042.jpg](rung-07-frames/t0042.jpg) tool). Full axes **55 × 50**. **55 is the steep axis** (perp. to the 17° construction); **50 is along the 17° construction** ([t0096.jpg](rung-07-frames/t0096.jpg) 60.00 then [t0100.jpg](rung-07-frames/t0100.jpg) 55 on the steep chord; [t0108.jpg](rung-07-frames/t0108.jpg) 50.00 along 17°). Prep put major along 17° — **frames win** | Real 3-click ellipse (`SketchEllipse.SPEC`). Smart Dim ellipse axis. |
| 17° construction | Small angle on the **left** between the horizontal CL and the construction. Opening toward −X, slightly −Y. Construction toward +X is at **+17°** ([t0068.jpg](rung-07-frames/t0068.jpg) `17.00deg`) | Line + construction. Angle chip / Smart Dim angle. |
| Jaw | Parallel to the 17° construction ([t0078.jpg](rung-07-frames/t0078.jpg) Parallel5, Line3+Line4). Endpoint **coincident on the ellipse** ([t0084.jpg](rung-07-frames/t0084.jpg) Ellipse1 + Point13). Offset **12.50**. Length **20** ([t0117.jpg](rung-07-frames/t0117.jpg), [t0123.jpg](rung-07-frames/t0123.jpg) 19.05 → 20) | Parallel chip. Point-on-ellipse coincident (WP3). Line length. Parallel-offset distance. |
| Mirror Entities (jaws) | Copy the jaw about the 17° construction ([t0135.jpg](rung-07-frames/t0135.jpg) both flanks, 20 / 12.50 / 55 / 50) | `mirror_selected` + Symmetric (WP4). |
| 3-point arc | **R15** throat at the inner jaw ends ([t0147.jpg](rung-07-frames/t0147.jpg) `15.00mm` / R15) | Arc variant `three_point` + radius dim. |
| Trim (open end) | Trim the **outer ellipse** between the jaws → C ([t0150.jpg](rung-07-frames/t0150.jpg) scissors on the left; [t0156.jpg](rung-07-frames/t0156.jpg) C ready) | Trim ellipse → elliptical arc (WP2). **First named-tool stop** today. |
| Ring | Circle on the CL, **Ø33** ([t0175.jpg](rung-07-frames/t0175.jpg) `33.00mm`) | Circle + diameter. |
| Hex 1 | Polygon, **Inscribed circle**, 6 sides, across-flats **25**, point-up (25 dim horizontal) ([t0181.jpg](rung-07-frames/t0181.jpg), [t0192.jpg](rung-07-frames/t0192.jpg) `25.00mm`). Concentric with Ø33, vertices **inside** the circle (wall ~2 mm), not on it | Polygon `across_flats`, 6 sides. |
| Hex 2 | Second hex AF **25**, rotated ~30° rel. ([t0208.jpg](rung-07-frames/t0208.jpg) Modify 25mm) | Polygon + drag rotation. |
| Trim (box end) | Trim inside both hexes → 12-point ([t0235.jpg](rung-07-frames/t0235.jpg) both 25 dims remain; Power Trim, Trim-away-inside is visible and unused) | Line-line Power Trim. |
| Center distance | **240** origin → Ø33 centre ([t0248.jpg](rung-07-frames/t0248.jpg) `240.00mm`) | Two-point Smart Dim. |
| Handle line | **Horizontal** (Existing Relations `Horizontal1`). Narrator “make vertical” — the stills win ([t0264.jpg](rung-07-frames/t0264.jpg)). Dim **10.00** from the CL (half-width; full width 20) ([t0270.jpg](rung-07-frames/t0270.jpg)) | Horizontal + parallel-offset / two-point distance. |
| Mirror Entities (handle) | Copy about the CL; **Symmetric3** in Existing Relations ([t0294.jpg](rung-07-frames/t0294.jpg)) | Mirror + Symmetric (WP4). |
| Coincident + trim (handle) | Line ends coincident to **Ø33** (Arc2 + Point59, status X≈226.8 Y=±10 — the left chord) ([t0285.jpg](rung-07-frames/t0285.jpg), [t0290.jpg](rung-07-frames/t0290.jpg)) and to the **ellipse**; trim leftovers ([t0315.jpg](rung-07-frames/t0315.jpg)) | Point-on-circle and point-on-ellipse (WP3). Trim line/ellipse/circle (WP2). |
| Finished sketch | One Front sketch: C + 12-point ring + handle strip. Exit ([t0315.jpg](rung-07-frames/t0315.jpg), [t0321.jpg](rung-07-frames/t0321.jpg)) | `exit_sketch`. |
| Boss-Extrude1 | Selected contours = both **heads**. Mid Plane **10**. Merge off ([t0332.jpg](rung-07-frames/t0332.jpg) Region\<1\>+\<2\>; [t0335.jpg](rung-07-frames/t0335.jpg) Mid Plane 10.00mm) | Contour checkboxes. `end=midplane`. |
| Boss-Extrude2 | Same Sketch1, **handle** region. Mid Plane **6**. **Merge result** on ([t0347.jpg](rung-07-frames/t0347.jpg) 6.00mm, Merge, Region\<1\>) | Second extrude, `op=fuse`. |
| Fillet1 / Fillet2 | **R30** open-end neck, both Z-edges, status length 6 ([t0366.jpg](rung-07-frames/t0366.jpg)). **R20** box-end neck ([t0380.jpg](rung-07-frames/t0380.jpg)) | Edge-pick fillet. HAVE. |
| Face sketch + Convert | Top face of the **handle** (cyan). Convert the filleted outline: two lines + **two arcs** (R30 / R20) ([t0385.jpg](rung-07-frames/t0385.jpg)) | Face sketch. Convert of circular **arcs**, not only full circles (WP6). |
| Offset Entities | Tried 1 ([t0400.jpg](rung-07-frames/t0400.jpg) Select chain, Length 180.63) / 3 (“this is more”) then locked **5.00** inward ([t0415.jpg](rung-07-frames/t0415.jpg)). Arcs, not Lines | Offset of Line **and Arc**, chain (WP6). |
| Cut-Extrude1 | Blind **1** mm. Status area **1895.51 mm²**, perimeter 402.35 mm ([t0430.jpg](rung-07-frames/t0430.jpg)). PM leftover 6.00 while he types — depth is **1**. After OK: one-face recess ([t0438.jpg](rung-07-frames/t0438.jpg)) | Extrude Cut Blind. |
| Fillet3 | **R3** both recess ends, Edge\<1\>+\<2\>, status Length 1 mm ([t0462.jpg](rung-07-frames/t0462.jpg), [t0471.jpg](rung-07-frames/t0471.jpg) Total Length 3mm) | Edge-pick. |
| Mirror1 | Mirror Face/Plane = **Front Plane** (cyan origin-plane rectangle) ([t0483.jpg](rung-07-frames/t0483.jpg)). Features = Fillet3 + Cut-Extrude1. Recess on **both** faces ([t0492.jpg](rung-07-frames/t0492.jpg)) | Feature Mirror, plane = origin Front (WP7), Fillet replay (WP8). |
| Fillet4 / Fillet5 | **R1** C outer then 12-point outer, tangent-propagated (Edge\<1\> then Edge\<2\>), Arc Length 139.23 ([t0498.jpg](rung-07-frames/t0498.jpg), [t0500.jpg](rung-07-frames/t0500.jpg) both heads highlighted). **R1** all remaining, Total Length 539.98 ([t0516.jpg](rung-07-frames/t0516.jpg)) | Edge pick + `_fillet_all`. HAVE. |
| Material | Cast Stainless Steel, viewing only. No text extrude of “CAD CAM TUTORIAL” ([t0523.jpg](rung-07-frames/t0523.jpg)–[t0540.jpg](rung-07-frames/t0540.jpg)) | Out of scope. |

**Spoken vs frames.** Auto-caption “60 mm 55 mm 50 mm” is three keystrokes on two ellipse axes: 60 is discarded ([t0096.jpg](rung-07-frames/t0096.jpg) → [t0100.jpg](rung-07-frames/t0100.jpg)). “Gap 10 mm” is the handle **half-width**, not the open-end gap (that gap is 2 × 12.50 = 25, equal to the hex AF). “Make vertical” on the handle line is **Horizontal** ([t0264.jpg](rung-07-frames/t0264.jpg)). Offset “3 mm / this is more / 5m” is him hunting; **5** sticks ([t0415.jpg](rung-07-frames/t0415.jpg)). Prep “t0285 is handle-on-ellipse”: the still is Arc2 + Point59 at X≈226.8 Y=−10 — that is the **Ø33 left chord**, not the ellipse.

**Prep vs frames (ellipse axes).** Prep locked “major along the 17° construction” and published bbox 282.9 × 50.4 × 10.0. Opened stills: 55 sits on the **steep** chord ([t0096.jpg](rung-07-frames/t0096.jpg), [t0100.jpg](rung-07-frames/t0100.jpg)); 50 sits on the dim **along 17°** at the bottom of the ellipse ([t0108.jpg](rung-07-frames/t0108.jpg), [t0117.jpg](rung-07-frames/t0117.jpg)). Minor 50 along 17°, major 55 perpendicular (17° from vertical). The intro drawing ([t0021.jpg](rung-07-frames/t0021.jpg)) agrees (50 on the opening axis, 55 across the head). Pass-bar Y is **54.6**, not 50.4.

### Pass-bar numbers (recomputed)

Independent numpy replica, this machine, not committed. N = 1024 shoelace on the C and the handle (caps are elliptical / circular, not chords). Hex/ring analytic. Fillet areas from the measured void angles. OCCT headers are not on this VM (`/opt/occt-8.0.1` absent); WP1 builds the OCCT replica.

Local frame: x′ along the 17° construction toward the **handle** (world heading +17°). y′ CCW (mostly +Y). Ellipse \(x' = 25\cos t\), \(y' = 27.5\sin t\). Jaw at \(y' = \pm 12.5\), \(x' < 0\):

\[
x'_\mathrm{jaw} = -25\sqrt{1-(12.5/27.5)^2} = -22.268
\]

Inner jaw \(x' = -2.268\). R15 centre toward the opening \(x' = -10.560\); throat \(x' = 4.440\). Remaining ellipse after the opening trim is the long arc \(t = 153.0^\circ \to -153.0^\circ\) through \(0^\circ\). Shoelace:

\[
A_C = 1495.80\ \mathrm{mm}^2
\]

(full ellipse \(\pi\cdot 25\cdot 27.5 = 2159.84\); the bite is 664). C xy: X ∈ [−24.950, 25.223], Y ∈ [−27.295, 27.295]. X min is the **upper** jaw–ellipse point `to_world(−22.268, +12.5)` = `(−24.950, 5.443)`.

**Ring.** Ø33 minus the union of two AF-25 hexes. Regular hex area \(541.266\). Intersection at 30° = inscribed dodecagon, area \(502.405\). Union \(580.127\). Outer \(\pi\cdot 16.5^2 = 855.299\).

\[
A_\mathrm{ring} = 275.172\ \mathrm{mm}^2
\]

**Handle strip.** Horizontal \(y = \pm 10\) hits the ellipse at `(22.944, 10.000)` and `(23.929, −10.000)` and Ø33 at \(x = 226.876\) (matches [t0285.jpg](rung-07-frames/t0285.jpg) status `X:226.87mm Y:-10.00mm`). Caps are the ellipse arc through \(t=0\) and the circle’s left arc through \((223.5, 0)\), not chords.

\[
A_h = 3999.25\ \mathrm{mm}^2
\]

(trapezoid 4068.79; cap correction \(69.5\ \mathrm{mm}^2 = 417\ \mathrm{mm}^3\) at thickness 6 — prep’s unpinned ~0.7 % of V, now closed).

**Boss volumes** (no fillets, no recess):

\[
V_C = 14958,\quad V_\mathrm{ring} = 2752,\quad V_h = 23996,\quad V_\mathrm{boss} = 41705
\]

**Neck fillets.** Concave, edge length = handle thickness 6. Void at the open-end crotch (above the handle, outside the ellipse) is the 112.42° sector between +X and the ellipse tangent at `(22.944, 10)` (tangent heading 112.42° from +X; a test point at heading 45° sits in that sector). Void at the box-end crotch is 127.31° (circle tangent vs handle; [t0285.jpg](rung-07-frames/t0285.jpg) geometry). Added 2D area \(R^2\bigl(\cot(\alpha/2)-(\pi-\alpha)/2\bigr)\). Two Z-edges each:

\[
V_{30} = 858,\quad V_{20} = 170
\]

(90° stand-in would be 2318 + 1030; that is a mutant, not the locked solid. Prep left this unpinned.)

**Recess.** SW status area **1895.51 mm²** ([t0430.jpg](rung-07-frames/t0430.jpg)), depth 1, both faces after Mirror1. R3 concave corners add back \(8\cdot 3^2(1-\pi/4)\cdot 1 = 15.5\).

\[
V_\mathrm{recess} = 1895.51 \times 2 = 3791
\]

**1 mm all-edge (convex).** Fillet4 Arc Length 139.23 ([t0498.jpg](rung-07-frames/t0498.jpg), both faces → ×2) + Fillet5 Total Length 539.98 ([t0516.jpg](rung-07-frames/t0516.jpg)) = 818.4 mm. Remove \(P\cdot 1^2(1-\pi/4) = 176\).

\[
V = 41705 + 858 + 170 - 3791 + 15 - 176 = 38782\ \mathrm{mm}^3
\]

| | min | max | size |
|---|---:|---:|---:|
| X | −24.95 | 256.50 | 281.45 |
| Y | −27.30 | 27.30 | 54.59 |
| Z | −5.00 | 5.00 | 10.00 |

X max is the ring \(240 + 16.5\). Y is the remaining-ellipse AABB \(\sqrt{(27.5\cos 17^\circ)^2+(25\sin 17^\circ)^2}\times 2 = 54.59\) (major at 73° from +X). Z is mid-plane 10. 1 mm edge fillets sit *inside* that box. Neck fillets add material inside it. Recess is 1 mm into the handle faces (Z still ±5 at the heads).

Prep published 282.9 × 50.4 × 10.0 and \(V \approx 4.09\times 10^4\) with major along 17° (Y half-extent 25.22) and 90° neck fillets. ΔY = 4.2 mm from the axis swap; ΔV vs that 4.09e4 is ~5 % (the band prep left open). Cross-check of the *locked* dims: pass, on the frame axes.

**Tolerance.** Shoelace N = 1024 on C and handle ≪ 0.2 %. Analytic hex/ring and the SW recess area are solid. Neck void angles and handle caps are **resolved**. Remaining uncertainty is the 1 mm-fillet edge set (still lengths vs a true 3D MakeFillet) and any thickness-step interaction at the 10/6 junction. Treat

\[
V = 38782\ \mathrm{mm}^3,\quad \mathrm{bbox}\ 281.4 \times 54.6 \times 10.0
\]

as a **±1 %** band until an OCCT replica of this locked profile; then a 0.5 % band like rung 5. Bbox edges ± **0.2** mm. WP1 copies these into `PART` / `VOLUMES`; after that the walk reads `check_rung07.py params`, not this file.

**Mutants, not targets.** Ellipse 60 × 50 (the discarded 60). Open-end gap 10 (the ladder misread; frames are 25). Handle width 10 overall instead of 10 half. Hex 25 as across-corners (would sit at Ø25 inside Ø33). Offset 3 mm (he tried it; [t0415.jpg](rung-07-frames/t0415.jpg) is 5). Recess on one face only (skip Mirror1). Drawing R3 as the all-edge set (video is 1 mm). “CAD CAM TUTORIAL” extruded. **Major along 17°** (prep’s swapped axes; bbox Y 50.4). Neck fillets forced to 90° (volume ~41102).

Inside (final, locked): `(0, 18, 0)` (C body, above the 12.5 jaw, inside the ellipse and outside the opening), `(120, 0, 0)` (handle core), `(240, 15, 0)` (ring wall, between the 12-point and Ø33). Outside: `(−30, 0, 0)` (past the jaws), `(240, 0, 0)` (12-point bore centre, empty), `(270, 0, 0)` (past the ring), `(0, 0, 8)` (above the 10 mm head), `(120, 0, 4)` (above the 6 mm handle), `(120, 0, 2.5)` and `(120, 0, −2.5)` (recess pockets after Mirror1).

## The video, step by step → SolidExpress

Rows are in the checklist. Frame cites there too.

| # | Video | SolidExpress | Rows |
|---|---|---|---|
| 1 | New part, MMGS ([t0021.jpg](rung-07-frames/t0021.jpg), [t0022.jpg](rung-07-frames/t0022.jpg)) | File → New. Pinned sentence unchanged. `state.units` is `mmgs`. | N1, A1 |
| 2 | Front plane, Sketch ([t0031.jpg](rung-07-frames/t0031.jpg)) | Datum Front, Sketch. Ground path, plane XY. | A2, L1 |
| 3 | Centerline through origin, +X ([t0031.jpg](rung-07-frames/t0031.jpg)) | Line + construction. Infer-horizontal. | A3 |
| 4 | Ellipse at origin ([t0042.jpg](rung-07-frames/t0042.jpg)). Construction, angle **17°** ([t0068.jpg](rung-07-frames/t0068.jpg)) | 3-click ellipse. Angle dim. | A4, A5 |
| 5 | Jaw line, Parallel, coincident to ellipse ([t0078.jpg](rung-07-frames/t0078.jpg), [t0084.jpg](rung-07-frames/t0084.jpg)) | Parallel chip. Point-on-ellipse. | A6 |
| 6 | Smart Dim 55 / 50 / 12.50 / 20 ([t0100.jpg](rung-07-frames/t0100.jpg), [t0108.jpg](rung-07-frames/t0108.jpg), [t0117.jpg](rung-07-frames/t0117.jpg), [t0123.jpg](rung-07-frames/t0123.jpg)) | Ellipse-axis / length / offset. 60 is discarded. | A7 |
| 7 | Mirror Entities: jaw about 17° ([t0135.jpg](rung-07-frames/t0135.jpg)) | Mirror + Symmetric. | A8 |
| 8 | 3 Point Arc, R15 ([t0147.jpg](rung-07-frames/t0147.jpg)) | Arc variant `three_point`. | A9 |
| 9 | Trim outer ellipse → C ([t0150.jpg](rung-07-frames/t0150.jpg), [t0156.jpg](rung-07-frames/t0156.jpg)) | `trim_entity` on Ellipse. | A10, L2 |
| 10 | Circle Ø33 ([t0175.jpg](rung-07-frames/t0175.jpg)) | Circle + diameter. | A11 |
| 11 | Two hexes AF 25, 30° rel. ([t0192.jpg](rung-07-frames/t0192.jpg), [t0208.jpg](rung-07-frames/t0208.jpg)) | Polygon `across_flats`. | A12, A13 |
| 12 | Trim inside hexes → 12-point ([t0235.jpg](rung-07-frames/t0235.jpg)) | Power Trim. | A14 |
| 13 | Smart Dim 240 ([t0248.jpg](rung-07-frames/t0248.jpg)) | Two-point dim. | A15 |
| 14 | Handle Horizontal, 10, Mirror, coincident, trim ([t0264.jpg](rung-07-frames/t0264.jpg)–[t0315.jpg](rung-07-frames/t0315.jpg)) | H + offset + Symmetric + point-on-curve + trim. | A16, A17, A18, L3 |
| 15 | Exit Sketch ([t0315.jpg](rung-07-frames/t0315.jpg), [t0321.jpg](rung-07-frames/t0321.jpg)) | `exit_sketch`. | A19, A20 |
| 16 | Extruded Boss, both heads, Mid Plane 10 ([t0335.jpg](rung-07-frames/t0335.jpg)) | Selected contours, midplane. | N2, A21 |
| 17 | Extruded Boss, handle, Mid Plane 6, Merge ([t0347.jpg](rung-07-frames/t0347.jpg)) | Second extrude, fuse. | A22, A23 |
| 18 | Fillet 30 / 20 on neck edges ([t0366.jpg](rung-07-frames/t0366.jpg), [t0380.jpg](rung-07-frames/t0380.jpg)) | Edge-pick. | A24, A25, A26, L4, A27 |
| 19 | Face Convert of handle outline, Offset 5 chain ([t0385.jpg](rung-07-frames/t0385.jpg), [t0415.jpg](rung-07-frames/t0415.jpg)) | Convert arcs. Offset Arc. | A28, N3 |
| 20 | Extruded Cut Blind 1 mm ([t0430.jpg](rung-07-frames/t0430.jpg), [t0438.jpg](rung-07-frames/t0438.jpg)) | Cut Blind. | A29 |
| 21 | Fillet 3 both recess ends ([t0462.jpg](rung-07-frames/t0462.jpg), [t0471.jpg](rung-07-frames/t0471.jpg)) | Edge-pick. | A30 |
| 22 | Mirror about **Front Plane**, Fillet3 + Cut ([t0483.jpg](rung-07-frames/t0483.jpg), [t0492.jpg](rung-07-frames/t0492.jpg)) | Origin-plane pick. Fillet replay. | A31 |
| 23 | Fillet 1 C outer then 12-point outer; Fillet 1 remaining ([t0498.jpg](rung-07-frames/t0498.jpg), [t0500.jpg](rung-07-frames/t0500.jpg), [t0516.jpg](rung-07-frames/t0516.jpg)) | Edge pick + `_fillet_all`. | A32 |
| 24 | Edit Material → Cast Stainless Steel | Viewing only. Out of scope. | — |
| — | save (implied) | Save As `final.sxp`, reopen. | A33–A36, L5, N4, A37 |

Already in the product, no package: File → New MMGS, Front origin plane, Line / Centerline, real 3-click ellipse, Angle, Parallel, Smart Dim length / diameter / ellipse-axis / offset, 3-point arc, Polygon AF hex, line-line and line-circle trim, Horizontal, Exit Sketch, selected-contour extrude, Mid Plane, Merge, edge fillet, all-edge fillet, Extrude Cut Blind, Feature Mirror of an extrude-cut (once a plane exists).

## Gaps → packages

Grep on this tree (`b783d695` product + seed docs). HAVE = named tool already does this step. PARTIAL = pieces exist, the video step does not. MISSING = no such tool. Cleanup #278 closed **none** of these.

| # | Demand | Mark | Evidence (`file : symbol`) | Package |
|---|---|---|---|---|
| 1 | New, MMGS, empty | HAVE | `document_view.gd` `units = mmgs`; `OriginPlanes.seed` | — |
| 2 | Front + Sketch | HAVE | `origin_planes.gd` BASIS; Front → ground XY | — |
| 3 | Centerline through origin | HAVE | Line + construction. Infer-horizontal on +X | — |
| 4 | Ellipse at origin, 17° construction | HAVE | `sketch_ellipse.gd` 3-click; `SketchEntityType::Ellipse`; `ConstraintType::Angle` | — |
| 5 | Jaw line, Parallel, coincident to ellipse | PARTIAL | Parallel chip HAVE. Coincident is **endpoint-to-endpoint** (`sketch_mode.gd` `_closest_endpoints`); ellipse `self` maps to the **centre** (`solver_planegcs.cpp` `point_of`, `PointRole::Self` → `ellipses[e].center`). No `PointOnEllipse` in `sxkernel`. PlaneGCS `addConstraintPointOnEllipse` is in-tree unused. The video click ([t0084.jpg](rung-07-frames/t0084.jpg)) is point-on-curve | WP3 |
| 6 | Dims 55 / 50 / 12.50 / 20 | HAVE | Ellipse major/minor via Smart Dim (`_apply_diameter_dim` ellipse axis). Line length. Parallel-offset distance | — |
| 7 | Mirror Entities about the 17° line | PARTIAL | `mirror_selected()` copies line/arc/circle about a selected line. **No Symmetric constraint** is added. `constrain("symmetric")` emits `"use Mirror tool"` and adds nothing. Kernel `ConstraintType::Symmetric` + `addConstraintP2PSymmetric` exist. SW shows Symmetric3 on the handle copy ([t0294.jpg](rung-07-frames/t0294.jpg)) | WP4 |
| 8 | 3-Point Arc R15 | HAVE | Arc variant `three_point` + radius dim | — |
| 9 | Trim outer ellipse | **MISSING** | `trim_entity` only Line and Circle (`sketch_tools.cpp`). No elliptical-arc type (`SketchEntityType` is Point/Line/Circle/Arc/Spline/Ellipse). `collect_line_intersections` ignores Ellipse, so a jaw **line** cannot use the ellipse as a cutter either. PlaneGCS `ArcOfEllipse` is in-tree unused. **First named-tool stop** ([t0150.jpg](rung-07-frames/t0150.jpg)) | WP2 |
| 10 | Circle Ø33 | HAVE | Circle + diameter | — |
| 11 | Two hexes AF 25, 30° rel. | HAVE | Polygon `across_flats`, 6 sides. Drag sets rotation. [t0181.jpg](rung-07-frames/t0181.jpg) Inscribed circle = AF | — |
| 12 | Trim inside hexes → 12-point | HAVE | Hex sides are lines; line-line Power Trim works. Trim-away-inside is chrome, not a package | — |
| 13 | 240 centre distance | HAVE | Two-point Smart Dim | — |
| 14 | Handle Horizontal, 10, Mirror, coincident, trim | PARTIAL | Horizontal + length HAVE. Mirror copy PARTIAL (no Symmetric, WP4). Coincident to **Ø33** is the same point-on-curve miss as 5: `_closest_endpoints` for circle/arc returns **center** only; [t0285.jpg](rung-07-frames/t0285.jpg) is Arc2 + Point59. Coincident / trim line-to-**ellipse** MISSING (WP2, WP3). Line-circle trim HAVE | WP2, WP3, WP4 |
| 15 | Exit Sketch | HAVE | `exit_sketch` | — |
| 16 | Extrude heads, selected contours, Mid Plane 10 | HAVE | Contour checkboxes (`selected_contours`). `end=midplane` → kernel `symmetric` | — |
| 17 | Extrude handle Mid Plane 6, Merge | HAVE | Second extrude on the same sketch, `op=fuse` | — |
| 18 | Fillet 30 / 20 on neck edges | HAVE | Edge-pick fillet. Radius 30/20 | — |
| 19 | Face Convert of handle outline (lines **and arcs**), Offset 5 chain | **MISSING** | Convert `kProjectors` is Line + Circle (`sketch3d.cpp`). `project_circle` **returns {}** when `span < 2π − 0.05` — fillet edges are circular **arcs**, not full circles. UI `NOT_SUPPORTED` for other types (`sketch_convert_edge.gd`). Offset `kOffsetters` is Line + Circle; **Arc skipped** (`sketch_tools.cpp` comment). `SketchOffset.KINDS` has no `arc` row | WP6 |
| 20 | Cut Blind 1 mm | HAVE | Extrude Cut Blind. (Unreachable if 19 fails.) | — |
| 21 | Fillet 3 recess ends | HAVE | Edge-pick. (Unreachable if 20 fails.) | — |
| 22 | Feature Mirror about **Front** of Fillet3 + Cut | **PARTIAL / MISSING** | Kernel Cut of an extrude-cut **HAVE** (`FeatureMirror::POLICY` Extrude/`cut` → Cut). **Fillet is Skip** (`ops_transform.cpp` `{FeatureType::Fillet, nullptr, Action::Skip}`). UI plane pick is **a planar body face** (`ops_panel.gd` `_resolve_mirror_pick`; `MirrorFeatures.REFUSALS["plane"]` = `"pick a planar face"`). Origin Front is not offered. After mid-plane extrude the Front plane sits *inside* the solid (Z = 0) — there is no Front face to click ([t0483.jpg](rung-07-frames/t0483.jpg) is the datum rectangle) | WP7, WP8 |
| 23 | Fillet 1 C outer then 12-point outer; Fillet 1 remaining | HAVE | Edge pick + `_fillet_all` | — |
| 24 | Cast stainless material | MISSING | Viewing only. No material library. Harmless | — (out of scope) |

**Readiness.** A named-tool click-through gets through New, Front, centerline, ellipse, 17°, Parallel, 55×50, 12.50, 20, 3-point R15, Ø33, both AF-25 hexes, 12-point trim, 240, handle 10, mid-plane 10/6, neck fillets 30/20, and (later) 1 mm all-edges. It **stops at Trim of the outer ellipse** ([t0150.jpg](rung-07-frames/t0150.jpg)): the C never opens, mixed contours keep a full ellipse, and the open-end head is the wrong solid.

A user who fakes the C (construction lines instead of a trimmed ellipse, or a polyline stand-in) can continue through the hex 12-point and both extrudes, then **stops again at Convert/Offset of the filleted handle chain** ([t0385.jpg](rung-07-frames/t0385.jpg)–[t0415.jpg](rung-07-frames/t0415.jpg)), and **again at Feature Mirror about origin Front of a fillet** ([t0483.jpg](rung-07-frames/t0483.jpg)). Those are downstream of the first stop.

**Risks, largest first.**

- **No elliptical trim / no elliptical arc.** The open end *is* a trimmed ellipse. Without it the C, the jaw coincident, and handle-line trim against the ellipse all fail. This is the rung.
- **Convert + Offset skip arcs.** `project_circle` already rejects partial spans. The recess sketch is the filleted handle outline offset 5 mm. Line/full-circle-only convert and offset cannot place that racetrack.
- **Feature Mirror cannot pick origin Front**, and **fillet-mirror is POLICY Skip.** Even a scripted plane at Z = 0 would skip Fillet3; the mirrored recess would have sharp ends.
- **Point-on-curve coincident is a no-op / wrong (snaps to centre).** Jaw-on-ellipse ([t0084.jpg](rung-07-frames/t0084.jpg)) and handle-on-Ø33 ([t0285.jpg](rung-07-frames/t0285.jpg)) are this relation. PlaneGCS PointOnEllipse / PointOnCircle are unused.
- **Sketch Mirror copies without Symmetric.** Workable with a second 12.50 / 10 dim; not what [t0294.jpg](rung-07-frames/t0294.jpg) shows.
- **Trim-to-closest / Trim-away-inside** chrome. Power Trim can still cut the hexes. S.
- **Display/Delete Relations, material.** Viewing. S.

## Design rules

New behaviour is a row in a table or a value object. `sketch_mode.gd`, `ops_panel.gd`, and `main.gd` only call the helper. A new file starts with a two-line header that says what it owns.

Tables: `SketchEntityType::EllipticalArc` (or Ellipse + start/end, one choice in WP2), Convert `kProjectors` gains `GeomAbs_Circle` partial-span → Arc, Offset `kOffsetters` gains Arc, `FeatureMirror::POLICY` Fillet row, checker `PART` / `STAGES`, walk `Rung`.

Click-driven UI tests (`.cursor/rules/gdscript-click-driven-tests.mdc`). A new suite is one `packaging/ci/suites.d/<name>.suite` file. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. Never pass `user://` or `res://` into GDExtension.

Do not edit `docs/plan/STATUS.md`. Do not commit `.webm`, `.mp4`, `.avi`, `.mov`, `.vtt`. The four `known-red` manifests stay known-red. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call.

Every WP **keeps rungs 1–6 green**: walks 77/77, 44/44, 46/46, 32/32, 36/36, 46/46 and `check_rung05/06` at their bars. Cheap checks include one C-one of a rung-5 or rung-6 suite when the WP touches a shared file (`sketch_tools.cpp`, `sketch_mode.gd`, `ops_transform.cpp`, `ops_panel.gd`). They do not add walk rows until WP9. No visual-survey restyle.

## Decisions (the BUILD agent does not choose)

1. **Front, origin = ellipse centre, handle +X, mid-plane Z.** First sketch Front XY. Open end toward −X. Do not sketch on Top or put the handle on −X.
2. **Ellipse axes follow the stills, not the prep.** Minor 50 along the 17° construction; major 55 perpendicular (steep, 17° from vertical). A bbox Y of 50.4 is the swapped-axes mutant.
3. **17° is from the horizontal CL**, small angle on the left ([t0068.jpg](rung-07-frames/t0068.jpg)). Opening −X slightly −Y. Construction toward +X is at +17°.
4. **Offset is 5, not 3. Handle half-width is 10, not a 10 mm open-end gap. Ellipse is 55×50, not 60×50.** Frames win over narration.
5. **Handle “vertical” is Horizontal** ([t0264.jpg](rung-07-frames/t0264.jpg)).
6. **Feature Mirror plane is origin Front**, not a body face. Pick the Front datum (tree or `mirror:Plane` with the origin plane). `plane_point = origin`, `plane_normal = +Z`.
7. **Mirror features are Fillet3 + Cut-Extrude1**, timeline order. Fillet replays (not Skip). A mirrored recess with sharp ends is a fail.
8. **No material library. No extruded “CAD CAM TUTORIAL”.** Drawing-only.
9. **No visual-survey batch.** Colours, glyphs, edges, hover, grid from rung 6 stay.
10. **Auto-close default on** stays for rungs 1–6. This sketch is closed regions; auto-close is harmless.
11. **Checkpoints.** `sketch.sxp` after A20, `neck.sxp` after A27, `final.sxp` after A36.
12. **Critique.** Checker + walk are necessary, not sufficient. Done = one build follows every video step with the named tool, score ≥ 9, checker passes. Caps at 8: polyline / construction-line stand-in for the C; skip elliptical trim; Convert as pierce points or full circles for the fillet arcs; body-mirror or a side-face stand-in for origin Front; Fillet3 skipped in the mirror; major along 17°; 90° neck as the target; two bodies; offset 3 mm; one-face recess.
13. **Implementation split.** Sketch tools (WP2–WP4) then a green **boss + neck** solid (WP5: two mid-plane extrudes + R30/R20, `check_rung07.py` `boss` and `neck`). Then recess/offset (WP6), origin-plane mirror (WP7), fillet-mirror (WP8), 1 mm in the walk (HAVE). Each WP’s cheap check is green on its own. Do not wait for the walk to prove the boss.

## BUILD agent rules

- One commit per WP: `Rung 7 WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert.** If that WP's cheap check is still red after two honest attempts, `git revert` the commit, write one line in `docs/plan/roadmap.md` §12 naming the check, and continue. Do not loosen a tolerance, drop a `--only`, or edit the tier to get green.
- No new third-party dependency. PlaneGCS `ArcOfEllipse`, `PointOnEllipse`, `PointOnCircle` in `thirdparty/planegcs` are already in-tree.

Cheap checks (not the full pass):

| Check | Command |
|---|---|
| C-py | the `python3 tools/test_….py` the WP names |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<suite>'` |
| C-dry | `python3 tools/walk_rung07.py --dry-run` plus `python3 tools/test_walk_registry.py` |
| C-r56 | C-one a rung-5 or rung-6 suite the WP names when it touches a shared file |

## Work packages

Blocking modeling first (WP2–WP4 sketch, WP5 boss+neck land-green, WP6 recess, WP7–WP8 mirror), walk, then whole-plan acceptance. No visual batch.

### WP1 — Checker `check_rung07.py`

Goal: stages `boss`, `neck`, `mirror`, `final` with the numbers in the frame table. Unit tests use a stub, not the app. Pin `final` volume from an OCCT 8.0.1 replica of the kernel calls (two mid-plane extrudes of the locked profiles, R30/R20 Z-edge fillets, 1 mm recess both faces with R3, 1 mm remaining edges). If it differs from 38782 by more than 0.2 %, put the OCCT number in `VOLUMES["final"]` and say so in the commit. Do not widen the band to skip the replica.

Files: new `tools/check_rung07.py`, `tools/test_check_rung07.py`, `tools/implicit_spanner.py` (tests only). `Makefile` `test-tools` gains `python3 tools/test_check_rung07.py`. Reuse `tools/solid.py`. `tools/confirm_all.sh` gains `unit_rung07` in the same commit if that file is the natural home; otherwise WP9 adds it with the walk.

Change: `PART` holds `ELLIPSE_MAJ = 55`, `ELLIPSE_MIN = 50`, `ANGLE_DEG = 17`, `JAW_OFF = 12.5`, `JAW_LEN = 20`, `R15 = 15`, `RING_D = 33`, `HEX_AF = 25`, `CENTER = 240`, `HANDLE_HALF = 10`, `HEAD_T = 10`, `HANDLE_T = 6`, `R30 = 30`, `R20 = 20`, `OFFSET = 5`, `CUT_D = 1`, `R3 = 3`, `R1 = 1`, `A_C = 1495.80`, `A_RING = 275.172`, `A_H = 3999.25`, `V_C = 14958`, `V_RING = 2752`, `V_H = 23996`, `V_BOSS = 41705`, `V_30 = 858`, `V_20 = 170`, `V_NECK = 42733`, `V_RECESS = 3791.02`, `V_R3 = 15.45`, `V_MIRROR = 38957`, `V_R1 = 176`, `VOLUME = 38782`, `VOID_ELL_DEG = 112.42`, `VOID_CIR_DEG = 127.31`, bbox min/max as the table, the inside/outside points above, `VOL_90NECK = 41102`, `VOL_PREP = 4.09e4` (prep’s swapped-axes + 90°-neck estimate; documentation only, not a stage target). `TOL = 0.2` mm. Volume band **1 %** (`VOLUME_TOL = 0.01`); WP1's OCCT replica tightens `VOLUME_TOL` to 0.005. A wall-less mutant and the swapped-axes / 90°-neck / one-face / offset-3 mutants must still fail.

Probes: `Bbox` (per stage), `Volume`, `Watertight` (one closed component), `Inside`, `Outside`, `HandleSide` (`boss` onward: X max ≥ 250 so the ring is on +X; a −X handle fails), `OpenEnd` (`xmin ≤ −24.5`; a +X open end fails), `RecessBoth` (`mirror`/`final`: `(120, 0, 2.5)` and `(120, 0, −2.5)` **outside**; a one-face recess leaves one of them inside). `STAGES`: `boss` (bbox 281.4 × 54.6 × 10.0, min `(−24.95, −27.30, −5.00)`, volume `V_BOSS`), `neck` (same bbox, volume `V_NECK`), `mirror` (same bbox, volume `V_MIRROR`), `final` (same bbox, volume `VOLUME`). `params` prints `PART` and `VOLUMES` as JSON.

`ImplicitSpanner` (tests only) is the shoelace + analytic ring + void-angle fillets. `volume()` returns the table (mutants override).

Expected delta: about +550 lines.

Check: C-py `test_check_rung07.py` is red on the missing module, then green. Mutations that must fail the named check: height/Y 50.4 as `final` (`bbox`), handle on −X (`handleSide` / `bbox`), one-face recess (`recessBoth`), volume of the 90°-neck solid as `final` (`volume` — 41102 vs 38782 is 6 %, the 1 % band catches it; after OCCT 0.5 % still catches it), two bodies (`watertight`), hex across-corners (`bbox` or `inside` at `(240, 15, 0)`). `test_check_rung02/03/04/05/06.py` stay green.

Revert: revert the commit if C-py is still red after two attempts.

### WP2 — Trim ellipse → elliptical arc; line/ellipse intersections

Goal: Trim the outer ellipse between the jaws and get a C ([t0150.jpg](rung-07-frames/t0150.jpg), [t0156.jpg](rung-07-frames/t0156.jpg)). A jaw line and a handle line trim against the ellipse. Circle-trim stays: a trimmed circle is still an Arc.

Files: `sxkernel/include/sx/sketch.hpp` `SketchEntityType::EllipticalArc` (params: ellipse GCS native + start/end angles or start/end points; one table, not a second ellipse type with a flag). `sxkernel/src/sketch.cpp` / `sketch_json.cpp` / `sketch_regions.cpp` / `features.cpp` `profile_face` / `sketch_spine` wire a `Geom_TrimmedCurve` of `Geom_Ellipse`, not 32 lines. `solver_planegcs.cpp` wires `GCS::ArcOfEllipse` (already in `thirdparty/planegcs`). `sketch_tools.cpp` `trim_entity` dispatches Ellipse like Circle (`trim_circle` → Arc); `collect_line_intersections` and circle-intersection collection include Ellipse / EllipticalArc. `sxcore` `entity_info` / add. Catch2 `test_sketch_tools.cpp` + `test_sketch_ellipse.cpp`. `docs/loop/automation-bridge.md` if a new click form appears.

Change: Power Trim on the left of a 55×50 ellipse cut by two parallel jaws at ±12.5 from the 17° axis leaves one elliptical arc, the C opening. A line that crosses the ellipse trims at the hit. Empty-space trim with no intersection returns false, nothing added. Do not satisfy A10 with a 3-point arc stand-in or a polyline.

Expected delta: about +400 lines.

Check: red first, Catch2: ellipse 55×50, two lines at local \(y' = \pm 12.5\), `trim_entity` on the opening side, remaining entity is EllipticalArc, `profile_face` of the C contour (jaws + R15 + remaining arc) area \(1495.8 \pm 1\,\%\). Then C-one `rung07_trim.suite` (`tier=ci`): Front sketch, ellipse + 17° + jaws + R15, trim the outer opening, one C region, no full ellipse left. Then C-one `rung01` a trim suite / `sketch_parity` (line and circle trim unchanged) and `rung06_ellipse.suite` (full ellipse still an ellipse).

Revert: revert. Do not walk a construction-line C.

### WP3 — Point-on-curve coincident (ellipse and circle/arc)

Goal: Coincident of a point to an ellipse is PointOnEllipse, not snap-to-centre ([t0084.jpg](rung-07-frames/t0084.jpg) Ellipse1 + Point13). Coincident of a point to a circle/arc is PointOnCircle ([t0285.jpg](rung-07-frames/t0285.jpg), [t0290.jpg](rung-07-frames/t0290.jpg) Arc2 + Point59 at the Ø33 chord). Endpoint-to-endpoint coincident is unchanged.

Files: `solver_planegcs.cpp` `ConstraintType::Coincident`: when one ref is an ellipse (role Self) and the other is a point, `addConstraintPointOnEllipse`; when one ref is a circle/arc (role Self) and the other is a point, `addConstraintPointOnCircle` (already in `GCS.h`). `sketch_mode.gd` `_closest_endpoints` / `constrain("coincident")`: for circle/arc/ellipse, offer a curve role (Self) when the pick is on the curve closer than the centre (`_snap_blocked_by_curve` / `SketchEllipse.closest` already exist). Two line endpoints still use start/end. Catch2 + `rung07_coincident.suite`.

Change: select the jaw endpoint and the ellipse, Coincident, the point stays on the curve, not at the origin. Select the handle-line end and Ø33, Coincident, the end sits at \(x = 226.876\), \(y = \pm 10\), not at \((240, 0)\). One entity refuses, nothing added.

Expected delta: about +150 lines.

Check: red first, Catch2: line end + ellipse, coincident, point-on-ellipse error ~0, centre unmoved. Line end + circle Ø33, coincident, distance to centre = 16.5. Then C-one `rung07_coincident.suite` (`tier=ci`): Front, ellipse at origin, line, coincident to the ellipse, not at (0,0); circle Ø33 at x=240, line y=10, coincident, x≈226.9. Then C-one `rung01_sketch_tests` / a coincident suite (endpoint-to-endpoint still works) and `rung06_ellipse.suite` (centre-to-path coincident from WP4 of rung 6 still centre-to-point).

Revert: revert. Do not teach the walk to type the hit coordinates.

### WP4 — Mirror Entities emits Symmetric

Goal: Mirror Entities about a selected line adds Symmetric between original and copy, as [t0294.jpg](rung-07-frames/t0294.jpg) Symmetric3. The chip `constrain("symmetric")` may stay a pointer at the Mirror tool, or it may add Symmetric when the selection is two points + a line; either is fine if the **named** Mirror Entities click emits it.

Files: `game/scripts/sketch_mode.gd` `mirror_selected`: after each copied line, add `ConstraintType::Symmetric` on corresponding endpoints vs the axis line (kernel already accepts three refs). Copy of a circle: Symmetric of centres, or skip circles (this video mirrors lines). `docs/loop/automation-bridge.md` if a new click form appears.

Change: select the jaw plus the 17° construction, Mirror, the copy is Symmetric-constrained; dragging the original moves the copy. Select the handle line plus the CL, Mirror, Symmetric present, second 10 mm dim not required. Empty selection still refuses `"Mirror needs a selection"`.

Expected delta: about +80 lines.

Check: red first, then C-one `rung07_mirror.suite` (`tier=ci`): Front, a line at y=10 and a horizontal axis, Mirror, copy at y=−10 ± 0.2, a Symmetric constraint exists, solve keeps them mirrored. Then C-one `sketch_parity_tests.suite` (existing `mirror_selected` line/arc/circle copy still returns ids).

Revert: revert. Do not walk a second 12.50 / 10 dim as the only path (that path stays a fallback).

### WP5 — Boss + neck stage (sketch + two mid-plane extrudes + R30/R20)

Goal: the first implementation split lands green: one Front sketch of the locked C + 12-point + handle, Mid Plane 10 on both heads, Mid Plane 6 Merge on the handle, Fillet 30 / 20 on the neck Z-edges. `check_rung07.py boss` and `neck` exit 0. Product tools are WP2–WP4 plus HAVE. This WP is the click suite and any glue the red test finds (contour index, merge default) — not a new modelling verb.

Files: `game/tests/run_rung07_boss.gd` + `packaging/ci/suites.d/rung07_boss.suite` (`tier=full`). Optional `game/tests/lib/spanner_fixture.gd` (`class_name SpannerFixture`) reading `SxChecker.run("rung07", ["params"])` so millimetres are not a second table. Catch2 only if a kernel glue bug shows up.

Change: the suite clicks the named tools (not `add_ellipse` private, not a polyline C). After OK of the second extrude, one body, export `boss.3mf`, `check_rung07.py boss` 0. Then Fillet 30 on both open-end Z-edges and Fillet 20 on both box-end Z-edges, export, `check_rung07.py neck` 0. Mid Plane 10 spans Z ±5; handle Z ±3.

Expected delta: about +220 lines of test. Product 0 if green on first try.

Check: C-one `--only 'rung07_boss.suite'` passes. Then C-one `rung06_draft.suite` or a rung-1 extrude suite (mid-plane / merge unchanged). `check_rung05.py` / `check_rung06.py` are not re-run here (WP10).

Revert: revert the test commit if it stays red after two product-fix attempts in this WP; then park the glue in `roadmap.md` §12. Do not fake the C.

### WP6 — Convert circular arcs + Offset Arc chains

Goal: Convert the filleted handle outline (two lines + R30 arc + R20 arc) on the handle top face, Offset 5 inward, chain, closed racetrack, Cut Blind 1 ([t0385.jpg](rung-07-frames/t0385.jpg), [t0415.jpg](rung-07-frames/t0415.jpg), [t0430.jpg](rung-07-frames/t0430.jpg)).

Files: `sxkernel/src/sketch3d.cpp` `project_circle`: when `span < 2π − 0.05` and the arc lies in the sketch plane, `add_arc` (trimmed), not `return {}`. `kProjectors` stays Circle (full and partial) + Line. `sketch_tools.cpp` `kOffsetters` gains `SketchEntityType::Arc` (concentric arc, same span, radius + distance; refuse if nr ≤ 0). `sketch_offset.gd` `KINDS` gains `arc`. `sketch_convert_edge.gd` `PROJECTORS` / `NOT_SUPPORTED` message allows arc. Chain-select (Offset Select chain in [t0400.jpg](rung-07-frames/t0400.jpg)): if a chain helper does not exist, Offset of a multi-selection of the converted edges in one commit is enough; a Select-chain checkbox is allowed but not required. Catch2 `test_sketch_external_circle.cpp` (partial circle now projects as arc; full circle still a circle). `rung07_offset.suite`.

Change: face sketch on the handle top after WP5, Convert four edges (two lines, two arcs), Offset 5 inward, one closed region of area ~1895 ± 5 %, Cut Blind 1, `check_rung07.py` volume drop from `neck` ≈ 1895 (one face). Offset 0 refuses, nothing added ([decision] N3). Reverse still inverts the sign.

Expected delta: about +250 lines.

Check: red first, Catch2: a 90° circular-arc edge on a face projects as Arc, not null; offset of that arc by 5 is a concentric Arc r' = r ± 5. Then C-one `rung07_offset.suite` (`tier=full`): from the neck solid (or a stub rounded rectangle of two lines + two R30/R20 arcs), Convert, Offset 5, Cut 1, one body. Then C-one `rung03` convert / offset suite (full-circle Convert and line Offset unchanged).

Revert: revert. Do not walk four construction lines as the racetrack.

### WP7 — Feature Mirror plane = origin Front

Goal: Mirror Face/Plane accepts the **Front datum** (origin XY, normal +Z), not only a planar body face ([t0483.jpg](rung-07-frames/t0483.jpg) cyan Front Plane rectangle through the part). Kernel already takes `plane_point` / `plane_normal`.

Files: `game/scripts/mirror_features.gd` / `ops_panel.gd` `_resolve_mirror_pick`: a datum pick (`datum=Front`, tree row, or origin-plane hit) sets `plane_point = (0,0,0)`, `plane_normal = +Z` (from `OriginPlanes.BASIS`). Body-face pick stays. `REFUSALS["plane"]` becomes `"pick a planar face or origin plane"` or keep the string and treat a datum as a planar face. `automation_bridge.gd` `mirror:Plane` accepts `datum=Front`. `docs/loop/automation-bridge.md`. `rung07_mirror_plane.suite`.

Change: `mirror:Features`, pick Front, Shift+click Cut-Extrude1 (Fillet3 still Skip until WP8), Ok. Recess appears on the −Z handle face. One body. Empty feature list still refuses. One-click body-mirror on a box (no collector) still body-mirrors (rung 5).

Expected delta: about +120 lines.

Check: red first, then C-one `rung07_mirror_plane.suite` (`tier=full`): from a one-face recess (WP6 path or a stub plate with a blind cut), `mirror:Features`, datum Front, the cut, Ok, `(120,0,2.5)` and `(120,0,-2.5)` both empty if the stub matches, or the stub’s mirrored pocket empty. Then C-one `rung05_mirror.suite` (plane is still a body face at z = 0; that pick path unchanged).

Revert: revert. Do not walk a side-face at x = 0 or a sketch plane dummy.

### WP8 — Feature Mirror of Fillet

Goal: `FeatureMirror::POLICY` replays Fillet (fuse the mirrored fillet onto the same body), so Fillet3’s R3 lands on the mirrored recess ends ([t0492.jpg](rung-07-frames/t0492.jpg) rounded both faces). Skip stays for Shell / Chamfer.

Files: `sxkernel/src/features/ops_transform.cpp` `FeatureMirror::POLICY` Fillet row → `Action::Fuse` (or a dedicated Replay that runs `apply_fillet` on the mirrored edges). Catch2 `test_rung05_mirror.cpp` Shell-skip still skip; new `test_rung07_fillet_mirror.cpp`. `rung07_mirror_fillet.suite`. Cue memory already remembers fillet edges (`cue_memory.cpp`).

Change: Mirror of Fillet3 + Cut-Extrude1 about Front: both pockets have R3 ends. A warning-and-skip of Fillet3 is a fail. Fillet of a box, then feature-mirror that fillet about a face, still one body. Rung 5 Shell-in-the-list remains a skip.

Expected delta: about +100 lines.

Check: red first, Catch2: plate + blind cut + R3 on the pocket ends, mirror Cut+Fillet about Z = 0, both sides rounded, volume matches `check_rung07.py mirror` ± 1 %. Then C-one `rung07_mirror_fillet.suite` (`tier=full`): from the WP6 one-face part, WP7 origin Front, features Fillet3 + Cut, Ok, `check_rung07.py mirror` exits 0. Then C-one `rung05_mirror.suite` (Shell still skipped; pipe `mirror` volume unchanged).

Revert: revert. Do not round the mirrored pocket with a second Fillet click as the only path.

### WP9 — Walk

Goal: `tools/walk_rung07.py` runs the checklist. Registry freezes the row list. Rungs 1–6 stay frozen.

Files: `tools/walk/registry.py` (`RUNG7_ROWS`, `_RUNG_SPEC["rung07"]`, `install`), new `tools/walk/app07.py`, `tools/walk/rung7/ui07.py`, `tools/walk/rung7/rows07_chunk{1,2,3,4}.py`, new `tools/walk_rung07.py` (same CLI as `walk_rung06.py`). `tools/test_walk_registry.py` gains `FROZEN_ROWS_07`. `tools/confirm_all.sh` gains `unit_rung07` (if WP1 did not), walk 7 on display `:27` / port `47327`, and the summary lines (`rung7`, `check-final-final.txt`). `docs/loop/README.md` lists this plan, the checklist, and `walk_rung07.py`. `docs/loop/automation-bridge.md` for new click forms (`mirror:Plane` datum, Convert arc, Offset arc, ellipse trim). `tools/walk/chrome.py` `_HEADLESS` row 7.

Change: each checklist row is a method that calls `ui07` helpers and `self.clause(...)`. Chunks and checkpoints are decision 11. Export rows share one 3MF per stage. A37 is the headless evidence row (needs `--a15`; without the flag it is `BLOCKED-by-flag`), same clause names as rung 6 A36.

Expected delta: about +800 lines.

Check: C-dry. Registry test green for seven rungs. `walk_rung07.py --rows N1,A1,A2 --dry-run` prints those rows. Do not launch Godot here.

Revert: revert if the registry test is red after two attempts.

### WP10 — The single full pass

Goal: one pass on this VM. Counts only. No product edits unless a count is red, and then only the smallest fix, re-run once.

Change: none expected. Run:

`tools/confirm_all.sh`

That script builds, imports, runs the kernel, the lints, `test_check_rung02/03/04/05/06/07.py`, the registry test, the headless suites, and the seven walks. Do not also run `make test` or a second suite pass.

Report, and nothing else: the confirm summary lines (build, kernel, lint, godot suite count, rung1 77, rung2 44, rung3 46, rung4 32, rung5 36, rung6 46, rung7 46, each checker tail including `check_rung05` 10/10, `check_rung06` 7/7, `check_rung07` final N/N).

Expected delta: 0.

Check: the summary. A walk row that fails is a product bug; fix it and re-run confirm once. Do not re-run confirm before that fix.

Revert: not this WP. A bad fix-up commit reverts on its own.

## Chunks

| Chunk | Rows | Ends |
|---|---|---|
| 1 | N1 A1 A2 L1 A3 A4 A5 A6 A7 A8 A9 A10 L2 | C on Front, ellipse trimmed, no ring |
| 2 | A11 A12 A13 A14 A15 A16 A17 A18 L3 A19 A20 | finished sketch, `sketch.sxp`, three regions |
| 3 | N2 A21 A22 A23 A24 A25 A26 L4 A27 | `neck.sxp`, bbox 281.4 × 54.6 × 10, R30/R20 on |
| 4 | A28 N3 A29 A30 A31 A32 A33 A34 A35 L5 A36 N4 A37 | `final.sxp`, checker passed, headless evidence |

46 rows: 37 A, 5 L, 4 N. Clause text: [`rung-07-checklist.md`](rung-07-checklist.md).

## Out of scope

- A units dialog, or editing the pinned New sentence.
- Trim-to-closest / Trim-away-inside as PropertyManager options (Power Trim is the walk path).
- Display/Delete Relations filter. Hide/Show Sketch Relations toggle.
- Material library / Cast Stainless Steel. Extruded “CAD CAM TUTORIAL”.
- A demo film. `docs/plan/STATUS.md`. Visual-survey restyle.
- Feature Mirror of Chamfer (stays Skip). Body-mirror as the recess path.
- Changing rungs 1–6 walk row lists.
