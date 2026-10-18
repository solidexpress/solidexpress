# Rung 6 plan — Fully Defined candlestick (Revolve & Sweep)

**PLAN only, no product code.** One BUILD agent implements this in order, one commit per work package, on the branch it is given. Push that branch. Do not open a PR. Source: [SolidWorks Tutorials – Revolve & Sweep](https://www.youtube.com/watch?v=m7GuVfPN164) (Fully Defined, 15:56). Everything from the video is in [`rung-06-prep.md`](rung-06-prep.md), the 412 stills in [`rung-06-frames/`](rung-06-frames/), and below. Do not re-watch it. The row text is [`rung-06-checklist.md`](rung-06-checklist.md); do not restate it.

Visual batch (survey items #1, #3, #4, #5, #6, #8) is [`docs/design/visual-survey.md`](../design/visual-survey.md) “Recommended first batch”. Those WPs are independent of the solid; they land after the blocking modeling gaps and before the walk.

Model: `rung-04-plan.md` package shape (goal, files, change, line delta, one cheap check, revert). Part / frame / walk like `rung-03-plan.md` and `rung-05-plan.md`. Same machinery (`tools/walk/` `Rung`, `automation-bridge.md`).

**Frames are mandatory evidence.** Every view, plane, dimension, click target and expected on-screen state below cites a file in `docs/loop/rung-06-frames/` that was opened for this plan. Where frames and narration disagree, **follow the frames** (called out in Decisions).

## Where we are

Baseline: `main` `99e75e3` (rung 5 #270 + post-rung-5 cleanup #272). This branch is cut from there. Seed `ff91eab` is prep, frames, and the visual survey only. The prep grepped `a7f4227`; cleanup #272 was layering + `flanged_pipe` film — it did **not** close any candlestick modeling gap (re-grepped on this tree). Rung 1 walk 77/77. Rung 2 44/44. Rung 3 46/46. Rung 4 32/32. Rung 5 36/36. Headless 229/0 (`docs/loop/post-rung-05-result.md`). `tools/test_walk_registry.py` freezes those five row lists.

Rung 6 goal: build the candlestick with the **named tools in the video's order**, by clicking, and end on a solid that passes `tools/check_rung06.py` at every stage.

Pass bar (all of):

- One solid. Bbox **304.1 × 220 × 224.0** mm, min corner `(−112.0, 0, −112.0)`.
- Volume **1730343** mm³ within **±2 %** until WP1's OCCT replica; then **0.5 %** like rung 5 (the replica may replace the digit, not the band). Rim clip vs unclipped toe is stated below, not a second target.
- Handle on **+X**. Cut is a Ø30 × 25 frustum, 15° inward, not a straight hole. No fillet feature.
- Every checklist row PASS (no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`). Critique ≥ 9 (rule at the end).
- On the same build: rung 1 walk 77/77, rung 2 44/44, rung 3 46/46, rung 4 32/32, rung 5 36/36, `check_rung01/02/03/04/05/06.py` at their bars, headless `0 failed`.

Whole-plan acceptance is **WP16 only**. Earlier packages run the one cheap check they name. They do not run `make test`, `make test-godot`, `confirm_all.sh`, or a walk without `--dry-run`.

## Frame (decision, not a question)

Same axis map as rungs 3–5. Front = XY (normal +Z). Right = YZ (normal +X). Sketch Y on Front/Right is world +Y (up). Revolve axis = world +Y through the origin. Units MMGS. Millimetre values on the stills.

| Item | Video (frame) | SolidExpress |
|---|---|---|
| Units | MMGS, new part | Already `state.units = mmgs`. Pinned New sentence unchanged. |
| First sketch | **Front**, Normal-To ([t0052.jpg](rung-06-frames/t0052.jpg) step 3) | Datum Front, Sketch. Ground path, plane XY. Basis `x = +X`, `y = +Y`. |
| First lines | Vertical from the origin; top horizontal **20.00**; height **220.00**; base **90.00**. **No** extra 20 mm step ([t0052.jpg](rung-06-frames/t0052.jpg), [t0081.jpg](rung-06-frames/t0081.jpg)) | Line. Smart Dim `line_length`. Auto-close **off** for this open-then-closed profile (decision 12). |
| Top rim | Tangent Arc from the **top-horizontal end**, pointer **right then down** ([t0104.jpg](rung-06-frames/t0104.jpg)). **R10.00**, ~90° ([t0132.jpg](rung-06-frames/t0132.jpg)) | Arc variant `tangent` must add Tangent (WP2). Radius dim. |
| ~150 mm vertical | Typed while dragging from the R10 end ([t0186.jpg](rung-06-frames/t0186.jpg)); **deleted** when Equal + 40 overdefine ([t0242.jpg](rung-06-frames/t0242.jpg)) | Typed length while drawing. Aid only. |
| 3-point arc | Centre and ends on that vertical. **R20.00**, ~180° ([t0186.jpg](rung-06-frames/t0186.jpg), [t0220.jpg](rung-06-frames/t0220.jpg)). Trim the diameter span ([t0214.jpg](rung-06-frames/t0214.jpg)) | Arc variant `three_point` + coincident/point-on-line (WP2). Power Trim for the span (HAVE). |
| Upper vertical | **40.00** ([t0220.jpg](rung-06-frames/t0220.jpg), [t0350.jpg](rung-06-frames/t0350.jpg)) | Smart Dim line length. |
| Equal | Applied to the two verticals beside the R20 ([t0233.jpg](rung-06-frames/t0233.jpg)). **Not** in the finished fully-defined set ([t0350.jpg](rung-06-frames/t0350.jpg)) | `constrain("equal")` HAVE. Walk may click it, then drop it when 80 lands (decision 2). |
| Lower tangent + rim | R60 ~90° down ([t0288.jpg](rung-06-frames/t0288.jpg)); connecting tangent to the **bottom 90 end** ([t0297.jpg](rung-06-frames/t0297.jpg)); **R12.50**, **80** from the baseline to the R60 start ([t0343.jpg](rung-06-frames/t0343.jpg) step 7, [t0350.jpg](rung-06-frames/t0350.jpg)) | Tangent Arc + Tangent chip. Finished lower vertical is **50** (220 − 10 − 40 − 40 − 80), not Equal-40. |
| Fully defined | Status bar *Fully Defined*, geometry black ([t0350.jpg](rung-06-frames/t0350.jpg)) | DOF chip `OK` / `last_dofs == 0`. Visual WP9 turns the flood from green to black/white. |
| Revolve | Axis = the **long vertical** (the 220 line). Blind **360°** ([t0371.jpg](rung-06-frames/t0371.jpg)). Iso shaded after OK ([t0385.jpg](rung-06-frames/t0385.jpg), [t0432.jpg](rung-06-frames/t0432.jpg)) | Finish-bar / rail Revolve. Selected line is the axis (forced construction), else sketch Y through the origin. Angle default τ. |
| Path plane | **Front** again, Front view, Hidden Lines Removed, **Temporary Axes** ([t0492.jpg](rung-06-frames/t0492.jpg)) | Front sketch. HLR is viewing-only (W cycle). Temporary-axis overlay + snap to x = 0 at any Y (WP4). |
| Path 60 | Horizontal **60.00** to **+X**, coincident to the temp axis ([t0519.jpg](rung-06-frames/t0519.jpg)). Lesson still draws it at the upper stem; the 10 mm dim later drops it | Line + length. Start is **not** the origin (decision 5). |
| Path R150 / 65 | Tangent Arc **R150.00** curving **up**, foreshortened leader (display). Vertical **65.00** between the R150 ends ([t0555.jpg](rung-06-frames/t0555.jpg)) | Tangent Arc (WP2). Two-point Smart Dim HAVE. Foreshorten out of scope. |
| Path “20” | **R20.00 hook**, **not** a 20 mm line ([t0582.jpg](rung-06-frames/t0582.jpg), [t0670.jpg](rung-06-frames/t0670.jpg)). Narrator says “dimension of 20” at 09:30; the stills win | Tangent Arc R20 (WP2). |
| Path Horizontal | The **R20 hook’s two endpoints**, Ctrl+click ([t0584.jpg](rung-06-frames/t0584.jpg)) | Two-point Horizontal (WP3). Chip already offered; kernel already accepts it. |
| Path 10 | Distance from the 60 mm line to the **bottom edge of the revolve** → **10** ([t0666.jpg](rung-06-frames/t0666.jpg) placing; [t0670.jpg](rung-06-frames/t0670.jpg) tutorial still). Path fully defined | Convert / snap of that silhouette + Smart Dim (WP4). |
| Handle side | **+X** (Front, same side as the profile) ([t0820.jpg](rung-06-frames/t0820.jpg), [t0010.jpg](rung-06-frames/t0010.jpg), [t0015.jpg](rung-06-frames/t0015.jpg)) | Path toward +X. |
| Section | **Right** plane, Normal To, Ellipse ([t0683.jpg](rung-06-frames/t0683.jpg)). Full axes **35.00 × 10.00**. Major **horizontal in Right view** = world **Z**; minor **vertical** = world **Y** ([t0715.jpg](rung-06-frames/t0715.jpg)). Horizontal on the two major-axis ends. Centre coincident to the path start ([t0735.jpg](rung-06-frames/t0735.jpg)) | Real ellipse, 3-click (WP5). Inter-sketch coincident (WP4). |
| Sweep | Profile = ellipse sketch; Path = path sketch; Follow path (default). **Shaded With Edges**. Flat ribbon, not a tube ([t0765.jpg](rung-06-frames/t0765.jpg), [t0813.jpg](rung-06-frames/t0813.jpg), [t0820.jpg](rung-06-frames/t0820.jpg)) | `sweep:Boss`. Fuse onto the revolve (WP6). Circular spine if the polyline fails the checker (WP7 ★). |
| Cut | **Top face of the revolve** (the r=20 disc) ([t0828.jpg](rung-06-frames/t0828.jpg)). Sketch Normal-To that face, **Ø30** ([t0834.jpg](rung-06-frames/t0834.jpg)). Extruded Cut **Blind 25**, **Draft On**, **15° inward** ([t0867.jpg](rung-06-frames/t0867.jpg), [t0878.jpg](rung-06-frames/t0878.jpg), [t0881.jpg](rung-06-frames/t0881.jpg)) | Face sketch, circle, diameter, Cut Blind HAVE. Draft-on-extrude (WP8). Face Draft `+Z` / bbox-min-Z is **not** a stand-in. |
| Fillets | **None** ([t0820.jpg](rung-06-frames/t0820.jpg)) | Do not fillet. |

**Equal vs 80 (frames win).** [t0233.jpg](rung-06-frames/t0233.jpg) applies Equal to the two verticals beside the R20 (40 already on the upper). That would make the lower vertical 40 and put the R60 start at y = 90. [t0350.jpg](rung-06-frames/t0350.jpg) then puts **80.00** from the bottom to that junction, status *Fully Defined* (black, not overdefined). R10 90° + R20 180° + Equal 40 + 80 cannot coexist. The finished sketch keeps **40** and **80**; the lower vertical is **50**. Equal from lesson step 9 is not in the finished set.

**Rim reconstruction (locked).** R10 90° puts the stem at x = 30. R60 tangent to that vertical at y = 80 has centre (90, 80). R12.50 tangent to R60 and ending at (90, 0) has centre (99.499, 8.125) (external). Outer bulge rightmost x = **111.999**. A 4.375 mm circular-segment toe sits below y = 0. [t0350.jpg](rung-06-frames/t0350.jpg) and [t0820.jpg](rung-06-frames/t0820.jpg) read as a rim on the baseline. Checker **clips y ≥ 0** so the part sits on the y = 0 disc.

### Pass-bar numbers (recomputed)

Independent 192-segment Pappus on the locked contour, this machine, not committed code. Prep 24–48-segment figures in parentheses.

Revolve profile (x = radius, y = height), closed on the axis, y ≥ 0 clip:

- (0, 220) → (20, 220)
- R10, centre (20, 210), 90° to (30, 210)
- (30, 210) → (30, 170) *(upper vertical 40)*
- R20 semicircle, centre (30, 150), through (50, 150), to (30, 130)
- (30, 130) → (30, 80) *(lower vertical 50, from the 80 dim)*
- R60, centre (90, 80), **CCW** (down) from (30, 80) to the R12.50 tangent (97.861, 20.517) — prep’s “CCW” matches the stills; a clockwise long way would put xmax at 150
- R12.50, centre (99.499, 8.125), clipped at y = 0 (x = 108.998), to (90, 0)
- (90, 0) → (0, 0) → (0, 220)

\[
A = 9588.322\ \mathrm{mm}^2\ (9587.799),\quad \bar{x} = 28.064\ \mathrm{mm}\ (28.062)
\]

\[
V_\mathrm{rev} = 2\pi A \bar{x} = 1\,690\,750\ \mathrm{mm}^3\ (1\,690\,536)
\]

Δ vs prep = 0.013 % (sampling). Unclipped toe: A = 9646.0, \(\bar{x}\) = 28.492, \(V_\mathrm{rev}\) = 1,726,807 (prep 1,726,501). Difference ≈ 2.1 % of \(V_\mathrm{rev}\).

**Cut.** Ø30 at y = 220, Blind 25, 15° inward ([t0881.jpg](rung-06-frames/t0881.jpg)). \(R_1 = 15\), \(R_2 = 15 - 25\tan 15° = 8.301270\). Frustum \(V_\mathrm{cut} = 10954.475\) mm³ (exact match to prep). Straight-cut mutant \(V_\mathrm{cut} = 17671.459\).

**Handle.** Ellipse 35×10 full axes, semi 17.5×5; \(A_e = \pi\cdot 17.5\cdot 5 = 274.889357\). Path after the 10 mm dim:

- (0, 10) → (60, 10)
- R150, centre (60, 160), CCW from (60, 10) to (183.592, 75) (ΔY 65, tangent +X at the start); 55.482°, length 145.251
- R20 hook, internal tangent, centre (167.113, 86.333), CCW 249.036° to (150.634, 75); length 86.930

Centreline L = 292.181 mm. Path centre inside the clipped revolve: **108.296** mm (prep 108.659). Net add \(A_e L_\mathrm{out} = 50548\) (prep 50448). Follow-path, centre-outside test, no self-intersection credit on the scroll.

\[
V = V_\mathrm{rev} + V_\mathrm{handle} - V_\mathrm{cut} = 1\,730\,343\ \mathrm{mm}^3
\]

Prep published 1,730,030. Δ = 313 mm³ = **0.018 %**. Cross-check: pass.

| | min | max | size |
|---|---:|---:|---:|
| X | −112.0 | 192.1 | 304.1 |
| Y | 0 | 220 | 220 |
| Z | −112.0 | 112.0 | 224.0 |

X max is the R20 hook’s rightmost (187.113) plus the 5 mm in-plane semi-minor at a vertical tangent. Z is the revolved rim (r = 111.999), which dominates the ribbon’s ±17.5 mm in Z. Handle Y stays below 220 (hook top 106.333 + 5).

**Tolerance.** Pappus sampling ≪ 0.1 %. The **rim clip** (2.1 % of \(V_\mathrm{rev}\)) and the **handle fuse** (centre-outside vs a true boolean) dominate. Treat \(V = 1730343\) as a **±2 %** band until an OCCT replica of this locked profile; then a 0.5 % band like rung 5. Bbox edges ± **0.2** mm. WP1 copies these into `PART` / `VOLUMES`; after that the walk reads `check_rung06.py params`, not this file.

**Mutants, not targets.** Top radial 10 (would not admit Ø30). Ellipse 12×6 (pre-frame guess; [t0715.jpg](rung-06-frames/t0715.jpg) is 35×10). Path starting at the outer rim rather than the axis. Path “20” as a straight line. Handle on −X. Body-sweep without fuse (second body). Straight cut, no draft. Equal kept so the R60 starts at y = 90.

Inside (final, locked): `(0, 100, 0)` (axis, in the stem), `(40, 10, 0)` (base), `(0, 210, 0)` (in the top cylinder, below the hole). Outside: `(113, 10, 0)` (past the rim), `(0, 221, 0)`, `(0, 205, 0)` (in the frustum), `(193, 86, 0)` (past the scroll), `(13, 195, 0)` (in the solid with draft / in the hole without — draft mutant).

## The video, step by step → SolidExpress

Rows are in the checklist. Frame cites there too.

| # | Video | SolidExpress | Rows |
|---|---|---|---|
| 1 | New part, MMGS ([t0020.jpg](rung-06-frames/t0020.jpg)) | File → New. Pinned sentence unchanged. `state.units` is `mmgs`. | N1, A1 |
| 2 | Front plane, Sketch ([t0052.jpg](rung-06-frames/t0052.jpg)) | Datum Front, Sketch. Ground path, plane XY. | A2, L1 |
| 3 | Lines, dim 20 / 220 / 90 ([t0081.jpg](rung-06-frames/t0081.jpg)). Narrator “90, 220 and 20” ([t0075.jpg](rung-06-frames/t0075.jpg)) — same three numbers, spoken order differs | Line. Smart Dim. Closed on the axis, profile does not cross it. | A3 |
| 4 | Tangent Arc from the top-horizontal end, right then down, R10 ([t0104.jpg](rung-06-frames/t0104.jpg), [t0132.jpg](rung-06-frames/t0132.jpg)) | Arc variant `tangent`. | A4 |
| 5 | Vertical ~150 from the R10 end ([t0186.jpg](rung-06-frames/t0186.jpg)). *Do not dimension the line at this time*; typed 150 is later deleted | Line, typed length. | A5 |
| 6 | 3 Point Arc, centre+ends on the line, R20 ([t0186.jpg](rung-06-frames/t0186.jpg)) | Arc variant `three_point`. | A6 |
| 7 | Trim Entities → Trim to closest, diameter span ([t0214.jpg](rung-06-frames/t0214.jpg)) | Power Trim (`trim_entity`). Trim-to-closest PM option is not a package. | A7 |
| 8 | Upper vertical 40 ([t0220.jpg](rung-06-frames/t0220.jpg)) | Smart Dim. | A8 |
| 9 | Equal on the two verticals ([t0233.jpg](rung-06-frames/t0233.jpg)). Delete 150 ([t0242.jpg](rung-06-frames/t0242.jpg)) | Equal chip. Delete the 150 dim. | A9, N2 |
| 10–11 | Tangent Arc R60 down; connecting tangent to the 90 end ([t0288.jpg](rung-06-frames/t0288.jpg), [t0297.jpg](rung-06-frames/t0297.jpg)) | Tangent Arc + Tangent chip. | A10, A11 |
| 12 | Hide/Show Sketch Relations (optional; he leaves them on) ([t0309.jpg](rung-06-frames/t0309.jpg), [t0310.jpg](rung-06-frames/t0310.jpg)) | Glyphs on. Hide toggle out of scope. Green badges are WP11. | L2 |
| 13 | Rest of image 7: R60, R12.50, 80. Fully defined ([t0343.jpg](rung-06-frames/t0343.jpg), [t0350.jpg](rung-06-frames/t0350.jpg)) | Those length/radius dims. If Equal fights 80, drop Equal (decision 2). | A12 |
| 14–15 | Revolve 360° about the long vertical, no Exit required ([t0364.jpg](rung-06-frames/t0364.jpg), [t0371.jpg](rung-06-frames/t0371.jpg)). Iso shaded ([t0385.jpg](rung-06-frames/t0385.jpg)) | Rail / finish Revolve. | A13, A14, A15 |
| 16–17 | Front sketch, temp axis, horizontal 60 ([t0492.jpg](rung-06-frames/t0492.jpg), [t0519.jpg](rung-06-frames/t0519.jpg)) | Front, Temporary Axes, Line 60 on the axis. | A16, A17 |
| 18–19 | Tangent Arc R150 up; vertical 65 ([t0555.jpg](rung-06-frames/t0555.jpg)) | Tangent Arc + two-point dim. | A18, A19 |
| 20–21 | Tangent-arc R20 hook; Horizontal on its ends ([t0582.jpg](rung-06-frames/t0582.jpg), [t0584.jpg](rung-06-frames/t0584.jpg)) | Tangent Arc R20. Two-point Horizontal. | A20, A21 |
| 22 | Display/Delete Relations, filter All (review only) ([t0597.jpg](rung-06-frames/t0597.jpg)–[t0651.jpg](rung-06-frames/t0651.jpg)) | Out of scope. | — |
| 23 | Dim 10 to the revolve bottom. Path fully defined. Exit ([t0666.jpg](rung-06-frames/t0666.jpg), [t0670.jpg](rung-06-frames/t0670.jpg)) | Silhouette dim. | A22, L3, A23 |
| 24 | Right, Normal To, Ellipse 35×10, H, coincident to path ([t0683.jpg](rung-06-frames/t0683.jpg), [t0715.jpg](rung-06-frames/t0715.jpg), [t0735.jpg](rung-06-frames/t0735.jpg)) | Real ellipse. | A24, A25, A26 |
| 25 | Swept Boss, profile then path, Follow path. Shaded With Edges ([t0765.jpg](rung-06-frames/t0765.jpg), [t0820.jpg](rung-06-frames/t0820.jpg)) | `sweep:Boss`. Fuse. | N3, A27, A28, L4, A29 |
| 26 | Top face, Ø30, Cut Blind 25, draft 15° inward ([t0828.jpg](rung-06-frames/t0828.jpg), [t0834.jpg](rung-06-frames/t0834.jpg), [t0881.jpg](rung-06-frames/t0881.jpg)) | Face sketch + Cut + draft. | A30, A31, N4 |
| 27 | Display Pane transparency ([t0895.jpg](rung-06-frames/t0895.jpg)–[t0918.jpg](rung-06-frames/t0918.jpg)) | Viewing only. Out of scope (survey #12 held). | — |
| — | save (implied) | Save As `final.sxp`, reopen. | A32–A36, L5, N5 |

Already in the product, no package: File → New MMGS, Front/Right origin planes, Line / Centerline, Smart Dim length / radius / two-point, Equal, Tangent chip (two-entity), Power Trim, Exit Sketch, Revolve 360° about a selected line, Swept Boss profile+path chrome, face sketch, circle Ø, Extrude Cut Blind, DOF chip.

## Gaps → packages

Grep on this tree (`99e75e3` product + seed docs). HAVE = named tool already does this step. PARTIAL = pieces exist, the video step does not. MISSING = no such tool. Cleanup #272 closed **none** of these.

| # | Demand | Mark | Evidence (`file : symbol`) | Package |
|---|---|---|---|---|
| 1 | New, MMGS, empty | HAVE | `document_view.gd` `units = mmgs`; `OriginPlanes.seed` | — |
| 2 | Front + Sketch | HAVE | `origin_planes.gd` BASIS; Front → ground XY | — |
| 3 | Lines, dims 20 / 220 / 90 | HAVE | Line, Smart Dim `line_length`. Auto-close defaults **on** (`sketch_mode.gd` `_auto_close`) — uncheck (decision 12) | — |
| 4 | Tangent Arc, R10 | PARTIAL | `_click_arc` variant `tangent` drops a free arc; **no tangent constraint**. Radius dim exists. Infer-tangent is for **lines** to circles (`_infer_line`), not this tool | WP2 |
| 5 | Vertical ~150, coincident to arc centre | PARTIAL | Typed length while drawing. Coincident to an arc centre is not automatic | WP2 (infer on the 3-point / line) |
| 6 | 3 Point Arc, centre+ends on the line, R20 | PARTIAL | Variant `three_point` commits an arc, no coincident / point-on-line. `point_on_line` is in `constrain()` but **not** on the selection-chip row (`selection_actions`) | WP2 |
| 7 | Trim to closest | PARTIAL | Power Trim `trim_entity` / `trim_at` click/drag. No Trim-to-closest option in a PM. Orange doomed-span in [t0214.jpg](rung-06-frames/t0214.jpg) is what Power Trim already highlights | — (walk uses Power Trim) |
| 8 | Upper vertical 40 | HAVE | Smart Dim line length | — |
| 9 | Equal on two verticals | HAVE | `constrain("equal")`; solver `EqualLength` | — |
| 10–11 | Tangent Arc R60 / R12.50 + Tangent | PARTIAL | Same as 4. Two-entity **Tangent** chip works (line–arc / arc–arc in the solver) | WP2 |
| 12 | Hide sketch relations | PARTIAL | Glyphs exist (`_rebuild_constraint_glyphs`); pale-blue letters, not green squares. No Hide/Show toggle | WP11 (colour); hide toggle out of scope |
| 13 | Rest of image-7 dims, fully defined | PARTIAL | Length / radius / two-point work. Fully-Define command is not this video’s step. DOF chip `OK` when `last_dofs == 0`. Whole-sketch green flood (`COLOR_CONSTRAINED`) | WP9 (colour); dims HAVE |
| 14 | Exit Sketch | HAVE | `exit_sketch` | — |
| 15 | Revolve 360° about the centreline | HAVE | `finish_revolve`: selected **line** is the axis (forced construction), else sketch Y through the origin. Angle default τ. `BRepPrimAPI_MakeRevol` | — |
| 16 | Front sketch + Temporary Axes | MISSING | No temporary-axis overlay. Origin / Y-axis snap is `Vector2.ZERO` and H/V infer only (`snap_point`) | WP4 |
| 17 | Horizontal 60, coincident to the axis | PARTIAL | Line + length. Must snap to **x = 0 at arbitrary Y**, not only the origin (the 10 mm dim is from the line to y = 0; a start at the origin cannot take dim 10) | WP4 |
| 18 | Tangent Arc R150 | PARTIAL | Same as 4 | WP2 |
| 19 | Vertical 65, two R150 ends | HAVE | Two-point Smart Dim; two-point Vertical is `SketchVertical` | — |
| 20 | Tangent-arc R20 hook | PARTIAL | Same as 4 | WP2 |
| 21 | Horizontal on two R20 endpoints | MISSING | Chip is offered on an endpoint pick (`selection_actions`). `constrain("horizontal")` only adds **line**-horizontal. Kernel two-point Horizontal already exists (`solver_planegcs.cpp` `refs.size() >= 2`) | WP3 |
| 22 | Display/Delete Relations | MISSING | No relations property manager / filter | — (out of scope) |
| 23 | Dim 10, path line to revolve bottom | PARTIAL | Convert of a circular edge is **face-sketch only** (`sketch_convert_edge.gd`: line or circle on the host face). Origin-plane Convert falls back to pierce **points**. Silhouette-edge dim as in [t0666.jpg](rung-06-frames/t0666.jpg) is not there | WP4 |
| 24 | Right, Ellipse 35×10, H, coincident to path | PARTIAL / MISSING | Right origin plane HAVE. Ellipse tool is a **32-gon of lines** (`sketch_mode.gd` two clicks: centre + box corner). Rail label “Ellipse (approx)”. Kernel `SketchEntityType` is Point/Line/Circle/Arc/Spline — **no ellipse**. PlaneGCS already has Ellipse (thirdparty only). Inter-sketch coincident to the Front path end is **MISSING** (snap is current-sketch + origin + body-edge centres/pierces) | WP5, WP4 |
| 25 | Swept Boss, profile then path, Follow path | PARTIAL | `sweep_boss.gd` + rail `sweep:Boss`. `MakePipeShell` `withCorrection=true`. Path is `sketch_ordered_polyline`: arcs → chords (`samples = max(8, ceil(span/(π/12)))`). `BRepBuilderAPI_RightCorner`. No Follow-path checkbox (always on). `graph_add_sweep_along_path` does not set `op`; `apply_sweep` defaults **`op == "new"`** — a second body unless Result=fuse | WP6, WP7 ★ |
| 26 | Face sketch Ø30, Cut Blind 25, draft 15° inward | PARTIAL / MISSING | Face sketch, circle, diameter, Extrude Cut Blind HAVE. Extrude schema has **no draft** (`property_panel.gd` `extrude`). Kernel extrude is `BRepPrimAPI_MakePrism`. Face **Draft** (`ops_panel.gd` `_draft`) pulls **+Z**, neutral **bbox min Z** — wrong axis for a hole along **Y**. No `MakeDPrism` | WP8 |
| 27 | Transparency / display pane | MISSING | Viewing only. W cycles shaded / edges / wireframe | — (out of scope) |

**Visual survey first batch** (independent of the solid; values from the survey):

| Survey | Mark | Evidence | Package |
|---|---|---|---|
| #1 Sketch colours blue / black / red | MISSING | `COLOR_ENTITY` white `(0.95, 0.95, 1.0)`; `COLOR_CONSTRAINED` green `(0.35, 0.85, 0.45)` whole-sketch flood (`_entity_draw_color`). Landing-protocol Visibility already says blue/black/red | WP9 |
| #3 Dimension witness lines + arrows | MISSING | `_rebuild_dimension_labels` is Label3D only; `ui_icons.gd` `"dimension"` already encodes the shape | WP10 |
| #4 Green relation glyphs | MISSING | `COLOR_GLYPH` pale-blue `(0.65, 0.8, 1.0)` letters, no 14×14 green square ([t0310.jpg](rung-06-frames/t0310.jpg), spoken at [t0309.jpg](rung-06-frames/t0309.jpg)) | WP11 |
| #5 Edge colour / width | PARTIAL | `EDGE_COLOR` `(0.12, 0.13, 0.16)` `PRIMITIVE_LINES`, one framebuffer pixel | WP12 |
| #6 Hover vs select accents | PARTIAL | Face select orange `(1.0, 0.62, 0.15)`; hover yellow `(0.95, 0.82, 0.45)`; blue AABB corners. Muddy pair vs Onshape yellow / Fusion cyan | WP13 |
| #8 Grid / origin planes off by default | PARTIAL | `origin_planes_visible := true`; `grid_visible := true`. Films already hide planes (`apply_film_presentation`). [t0820.jpg](rung-06-frames/t0820.jpg) has neither | WP14 |

Verified **not** gaps: MMGS New, Front/Right, Line, Smart Dim length/radius/two-point, Equal, Tangent chip, Power Trim, Exit, Revolve 360° about a selected line, Swept Boss chrome, face sketch, circle Ø, Extrude Cut Blind, two-point Vertical, DOF chip.

## Design rules

New behaviour is a row in a table or a value object. `sketch_mode.gd`, `ops_panel.gd`, and `main.gd` only call the helper. A new file starts with a two-line header that says what it owns.

Tables: `SketchEllipse.SPEC` (3-click, major/minor, Horizontal-on-axis-points), `SketchTangentArc.POLICY` (host segment → Tangent + coincident start), checker `PART` / `STAGES`, walk `Rung`, survey colour consts as named `Color(...)` matching the survey.

Click-driven UI tests (`.cursor/rules/gdscript-click-driven-tests.mdc`). A new suite is one `packaging/ci/suites.d/<name>.suite` file. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. Never pass `user://` or `res://` into GDExtension.

Do not edit `docs/plan/STATUS.md`. Do not commit `.webm`, `.mp4`, `.avi`, `.mov`, `.vtt`. The four `known-red` manifests stay known-red. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call.

Visual WPs **keep rungs 1–5 green** by updating the tests that pin the old `Color` constants in the **same commit**. They do not add walk rows. They do not restyle `FilmPresentation.FLAT_BG` or `apply_film_look` (survey holds #2 light sketch sheet and film goldens). Captions still land; posters are not re-shot in this rung.

## Decisions (the BUILD agent does not choose)

1. **Front, +Y revolve, handle +X, cut −Y.** First sketch Front XY. Revolve about the 220 line (world +Y through the origin). Path on Front toward +X. Ellipse on Right, major world Z = 35, minor world Y = 10. Cut from the top disc along −Y. Do not sketch the profile on Right or put the handle on −X.
2. **Finished profile is 40 + 80, not Equal.** Follow [t0350.jpg](rung-06-frames/t0350.jpg). The walk may click Equal ([t0233.jpg](rung-06-frames/t0233.jpg)) and delete 150 ([t0242.jpg](rung-06-frames/t0242.jpg)); when 80 overdefines, **drop Equal** so DOF is 0. Keeping Equal (R60 at y = 90) is a checker mutant. Skipping Equal entirely is allowed (the finished stills do not show it) but the named click is preferred.
3. **Path “20” is R20.00.** [t0582.jpg](rung-06-frames/t0582.jpg) / [t0670.jpg](rung-06-frames/t0670.jpg). A 20 mm line is a fail.
4. **Ellipse is 35×10, not 12×6.** [t0715.jpg](rung-06-frames/t0715.jpg) and [t0683.jpg](rung-06-frames/t0683.jpg) step 6. A 32-gon stand-in caps the critique at 8.
5. **Path start is on the axis, not at the origin.** Dim 10 is from the 60 mm line to the **bottom edge** (y = 0). A start at `(0, 0)` cannot take that dim. Snap to x = 0 at some Y > 0, then dim 10. Lesson still at [t0492.jpg](rung-06-frames/t0492.jpg) draws it at the upper stem; after the dim it sits at y = 10 ([t0670.jpg](rung-06-frames/t0670.jpg)).
6. **Sweep fuses onto the revolve.** Default `op` is fuse when a body already exists; empty-part Swept Boss stays `new` (rung 4 hex key). A second body is a fail. Follow-path stays the default (no new checkbox required).
7. **Cut draft is on the extrude, 15° inward.** Not face-draft +Z. Not a straight Ø30×25 hole. `finish:Draft` On + `finish:DraftAngle` `15`. Outward is a refuse or a mutant (`(13, 195, 0)` inside vs outside).
8. **Rim clip y ≥ 0.** Checker solid sits on the y = 0 disc. Unclipped toe (−4.375 mm) is reconstruction residue, not a target.
9. **Spine.** WP6 (fuse) uses today’s polyline sweep first. Chord error on R150 / R20 is small vs the 2 % volume band; X max sits on the hook so bbox 0.2 mm may fail. WP7 ★ runs only when that solid fails `check_rung06.py sweep`. Do not widen `TOL` or the volume band to skip WP7.
10. **Critique.** Checker + walk are necessary, not sufficient. Done = one build follows every video step with the named tool, score ≥ 9, checker passes. Caps at 8: 32-gon ellipse; face-draft as the hole; polyline ribbon that fails the checker and skips WP7; path “20” as a line; Equal kept; handle on −X; two bodies; a straight cut.
11. **Checkpoints.** `revolve.sxp` after A15, `path.sxp` after A23, `sweep.sxp` after A29, `final.sxp` after A35.
12. **Auto-close off on the path.** The open path sketch must not grow a closing segment. Uncheck auto-close (or end the chain without the close) before the 60 mm line. Revolve profile is closed on the axis after the connecting arc — auto-close there is harmless if the chain already meets the origin. Default `_auto_close := true` stays for rungs 1–5.
13. **Visual batch does not restyle films.** `FilmPresentation.FLAT_BG` stays charcoal. `apply_film_look` albedo stays. Plane hide in `apply_film_presentation` already matches WP14’s idle default (planes off). Grid-off in idle may change empty-scene film frames if a film is re-shot; this rung does not re-shot. Update tests that pin the old colours / `origin_planes_visible == true` after New in the same WP.
14. **Hold survey #2, #7, #10–#15.** Light sketch sheet, SSAO, ViewCube, Export Image, per-body transparency, rail-icon recolour, gold pads, hidden-line / tangent edges are not this rung.

## BUILD agent rules

- One commit per WP: `Rung 6 WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert.** If that WP's cheap check is still red after two honest attempts, `git revert` the commit, write one line in `docs/plan/roadmap.md` §9 naming the check, and continue. Do not loosen a tolerance, drop a `--only`, or edit the tier to get green. WP7 is the exception in its own section: skip it when the checker already passes; revert it when the arc spine is worse than the polyline.
- **★** Only WP7. Do not start it unless WP6's exported solid fails `check_rung06.py sweep` (or `final` if sweep is not yet exported).
- No new third-party dependency. PlaneGCS Ellipse in `thirdparty/planegcs` is already in-tree.

Cheap checks (not the full pass):

| Check | Command |
|---|---|
| C-py | the `python3 tools/test_….py` the WP names |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<suite>'` |
| C-dry | `python3 tools/walk_rung06.py --dry-run` plus `python3 tools/test_walk_registry.py` |

## Work packages

Modeling gaps first (WP1–WP8; WP6 fuse then WP7 ★ spine, same order as rung 4 WP9/WP10), visual batch independent (WP9–WP14), walk, then whole-plan acceptance.

### WP1 — Checker `check_rung06.py`

Goal: stages `revolve`, `sweep`, `final` with the numbers in the frame table. Unit tests use a stub, not the app.

Files: new `tools/check_rung06.py`, `tools/test_check_rung06.py`, `tools/implicit_candlestick.py` (tests only). `Makefile` `test-tools` gains `python3 tools/test_check_rung06.py`. Reuse `tools/solid.py`.

Change: `PART` holds `H = 220`, `TOP_R = 20`, `BASE_R = 90`, `R10 = 10`, `UPPER = 40`, `R20 = 20`, `LOWER = 50`, `R60 = 60`, `R12 = 12.5`, `PATH_Y = 10`, `PATH_60 = 60`, `PATH_R150 = 150`, `PATH_65 = 65`, `PATH_R20 = 20`, `ELLIPSE_MAJ = 35`, `ELLIPSE_MIN = 10`, `CUT_D = 30`, `CUT_H = 25`, `CUT_DRAFT_DEG = 15`, `AREA = 9588.322`, `XBAR = 28.064`, `V_REV = 1690750`, `V_HANDLE = 50548`, `V_CUT = 10954.475`, `VOLUME = 1730343`, bbox min/max as the table, the inside/outside points above, `VOL_UNCLIP = 1726807`, `VOL_NODRAFT_DELTA` (straight cut 17671.459). `TOL = 0.2` mm. Volume band **2 %** (`VOLUME_TOL = 0.02`); WP1's OCCT replica may tighten `VOLUME_TOL` to 0.005 and retune `VOLUME` if the replica differs by more than 0.2 % — say so in the commit. Do not widen the band to skip the replica. A wall-less mutant and the Equal-kept / no-draft / two-body mutants must still fail.

Probes: `Bbox` (per stage), `Volume`, `Watertight` (one closed component), `Inside`, `Outside`, `HandleSide` (`sweep`/`final`: X max ≥ 180 so the ribbon is on +X; a −X handle fails), `DraftHole` (`final` only: `(13, 195, 0)` **inside** the solid; a straight cut leaves it empty). `STAGES`: `revolve` (bbox 224 × 220 × 224, min `(−112, 0, −112)`, volume `V_REV`), `sweep` (bbox 304.1 × 220 × 224, min `(−112, 0, −112)`, volume `V_REV+V_HANDLE`), `final` (same bbox as sweep, volume `VOLUME`). `params` prints `PART` and `VOLUMES` as JSON.

`ImplicitCandlestick` (tests only) is analytic Pappus + frustum + centre-outside handle. `volume()` returns the table (mutants override).

Pin `final` volume from an OCCT 8.0.1 replica of the kernel calls (revolve of the locked profile, pipe-shell ellipse along the path fused, drafted cut). If it differs from 1730343 by more than 0.2 %, put the OCCT number in `VOLUMES["final"]` and say so in the commit.

Expected delta: about +550 lines.

Check: C-py `test_check_rung06.py` is red on the missing module, then green. Mutations that must fail the named check: height 200 (`bbox`), handle on −X (`bbox` / `handleSide`), volume of the unclipped toe as `final` (`volume` — only if the 2 % band still catches 1,766,807 vs 1,730,343; it does not — so fail that mutant on `ymin < −0.2` instead), straight cut (`draftHole`), two bodies (`watertight`), Equal-kept R60 at y = 90 (`bbox` xmax or volume). `test_check_rung02/03/04/05.py` stay green.

Revert: revert the commit if C-py is still red after two attempts.

### WP2 — Tangent Arc actually tangents; 3-point on a line

Goal: Arc variant `tangent` from an existing endpoint adds Tangent to the host segment and coincident start, so R10 / R60 / R12.50 / R150 / R20 match the stills. 3-point arc whose centre and ends land on a line pick up coincident / point-on-line.

Files: new `game/scripts/sketch_tangent_arc.gd` (`class_name SketchTangentArc`, `POLICY`: first click near an endpoint of a line or arc → coincident start + Tangent to that entity; second click is the end; optional radius dim is Smart Dim, not this tool). `sketch_mode.gd` `_click_arc` variant `tangent` calls it (drop the free two-point arc). Variant `three_point`: after commit, if centre and both ends are within snap radius of the same line, add `point_on_line` for the centre and coincident for the ends. `point_on_line` stays in `constrain()`; offering it on the chip row is allowed but not required if infer covers this video. `docs/loop/automation-bridge.md` if a new click form appears.

Change: a tangent-arc from the top-horizontal end, pointer right then down, Smart Dim R10, is G1 at that end ([t0104.jpg](rung-06-frames/t0104.jpg), [t0132.jpg](rung-06-frames/t0132.jpg)). Empty-space two clicks still make a free arc (no host). Radius 0 refuses and adds nothing.

Expected delta: about +220 lines.

Check: red first, then C-one `rung06_tangent_arc.suite` (`tier=ci`): Front sketch, 20 / 220 / 90 lines, Tangent Arc from the top-horizontal +X end, R10, tangent constraint present, quarter ~90° ± 5°, end at ≈ (30, 210). 3-point arc on a vertical, centre and ends on the line, R20, diameter span still there (trim is A7). Then C-one `sketch_parity_tests.suite` / a wrench sketch suite (line–circle infer tangent still works).

Revert: revert. Do not satisfy A4 with a 3-point arc plus a later Tangent chip as the only path (that path stays a fallback, not the named tool).

### WP3 — Two-point Horizontal on arc ends

Goal: Horizontal on two endpoints (the R20 hook) is the same shape Vertical already has. Chip is no longer a no-op.

Files: `game/scripts/sketch_mode.gd` `constrain("horizontal")` — when `selected` is two endpoints, add two-point Horizontal (kernel already accepts `refs.size() >= 2` in `solver_planegcs.cpp`). Mirror `SketchVertical.offers` / `apply` or a tiny `SketchHorizontal` helper. Glyph: draw point-point horizontal; keep hiding two-centre Horizontal if that is today’s hide. `selection_actions` already appends `horizontal` on `_endpoint_pick()`.

Change: Ctrl+click the two R20 ends, Horizontal, those points share Y ([t0584.jpg](rung-06-frames/t0584.jpg)). One endpoint refuses, nothing added.

Expected delta: about +80 lines.

Check: red first, then C-one `rung06_horizontal_points.suite` (`tier=ci`): an R20-ish arc, two ends selected, Horizontal, same Y ± 0.2, arc still an arc. Line-horizontal on one line still works. Then C-one `rung04_vertical.suite` (two-point Vertical untouched) and `rung01_sketch_tests.suite`.

Revert: revert. Do not walk a construction line between the hook ends.

### WP4 — Temp axis, axis snap, dim-to-silhouette, inter-sketch coincident

Goal: path start coincident to the revolve axis at arbitrary Y; dim 10 from the 60 mm line to the revolve bottom; ellipse centre coincident to the path start.

Files: new `game/scripts/sketch_temp_axes.gd` (dashed overlay of revolve axes when View → Hide/Show → Temporary Axes / `menu:TemporaryAxes` is on; default **on** while a Front sketch exists on a revolved body, matching [t0492.jpg](rung-06-frames/t0492.jpg)). `sketch_mode.gd` `snap_point`: besides `Vector2.ZERO`, project onto the sketch-plane Y axis (x = 0, any y) and onto other **visible** sketches’ endpoints/centres (the Front path start when the Right ellipse is active). `sketch_convert_edge.gd` or Smart Dim: a pick on a body silhouette in an origin-plane sketch converts that edge (or its intersection with the plane) so a line-to-edge distance works ([t0666.jpg](rung-06-frames/t0666.jpg)). Face-sketch Convert stays as it is (rung 3). `docs/loop/automation-bridge.md` `menu:TemporaryAxes` and any new dim pick.

Change: a click on the dashed axis at the upper stem is coincident to x = 0, not forced to the origin. Dragging the ellipse centre onto the path start adds coincident ([t0735.jpg](rung-06-frames/t0735.jpg)). Dim 10 from the path’s 60 mm line to the bottom circular edge of the revolve solves the path to y = 10.

Expected delta: about +280 lines.

Check: red first, then C-one `rung06_refs.suite` (`tier=ci`): revolve a rectangle 90 × 220 about Y, Front sketch, snap a horizontal line to the axis at y ≈ 150, Smart Dim 10 to the y = 0 silhouette, line sits at y = 10 ± 0.2. Second case: Right sketch, ellipse or circle centre dragged to that path start, coincident, DOF of the centre follows the path. Then C-one `rung03` convert / face-edge suite (face Convert unchanged).

Revert: revert. Do not teach the walk to type y = 10 as a line length from the origin.

### WP5 — Real ellipse

Goal: Ellipse is a kernel entity. Three clicks: centre, major, minor. 35×10, Horizontal on the two major-axis ends, coincident centre to a path end. Not a 32-gon.

Files: `sxkernel/include/sx/sketch.hpp` `SketchEntityType::Ellipse` (params: `cx, cy, rx, ry, angle` or PlaneGCS’s centre + major + radmin). `sxkernel/src/sketch.cpp` / `sketch_json.cpp` / `solver_planegcs.cpp` wire `GCS::Ellipse` (already in `thirdparty/planegcs`). `profile_face` builds a `Geom_Ellipse` wire, not 32 lines. `sxcore` `add_ellipse` / `entity_info`. New `game/scripts/sketch_ellipse.gd` (`class_name SketchEllipse`, `SPEC`: 3-click, Horizontal-on-major-ends optional infer). `sketch_mode.gd` `Tool.ELLIPSE` calls it (drop the 32-gon). `sketch_tool_spec.gd` rail label **Ellipse** (drop “(approx)”); hint “centre, then major, then minor”. `SweepBoss.role` treats an ellipse as a closed profile. Tests: Catch2 + `rung06_ellipse.suite`.

Change: Right sketch, three clicks, Smart Dim 35 (major, world Z in Right view) and 10 (minor, world Y), Horizontal on the two major-axis ends, centre coincident to the path ([t0683.jpg](rung-06-frames/t0683.jpg), [t0715.jpg](rung-06-frames/t0715.jpg), [t0735.jpg](rung-06-frames/t0735.jpg)). `profile_face` is one closed elliptical wire. A 2-click box ellipse is gone. `film_loft_guide_rail.gd` `draw_ellipse` (32-gon helper) — update that **validation/film helper** to the 3-click tool or keep a test-only polygon helper under another name so the hull film still draws; do not leave `Tool.ELLIPSE` as a 32-gon. C-one the hull / loft suite if that helper is shared.

Expected delta: about +450 lines.

Check: red first, Catch2 `test_sketch_ellipse.cpp`: add ellipse 35×10, solve, `profile_face` area \(A_e = 274.889 ± 0.5 %\). Then C-one `rung06_ellipse.suite` (`tier=ci`): Right sketch, 3-click, dims 35 and 10, Horizontal on major ends, one ellipse entity, no 32 lines, DOF 0 after coincident-to-a-point. Then C-one `rung01_replan8_rail.suite` (rail still shows Ellipse) and the loft film suite if its helper moved.

Revert: revert. Do not satisfy A25 with a 32-gon.

### WP6 — Sweep default fuse onto the revolve

Goal: Swept Boss on a part that already has a body fuses the ribbon onto that body. Empty-part sweep stays `new` (rung 4). Follow-path stays the default (always on). Same order as rung 4 WP9 then ★ WP10: fuse/polyline first, circular spine only if the mesh misses the checker.

Files: `sxcore/src/sx_document.cpp` `graph_add_sweep_along_path` sets `op` (`fuse` when a target body exists, else `new`) and `target`. `sweep_boss.gd` / `main.gd` `_apply_swept_boss` pass that op. PropertyPanel `sweep` `op` still editable after. `docs/loop/automation-bridge.md` if Result is a finish-bar field.

Change: candlestick = one body after OK ([t0820.jpg](rung-06-frames/t0820.jpg)). Hex key (no prior body) still one new body. `sweep:Ok` with only the profile selected still refuses (N3).

Expected delta: about +80 lines.

Check: red first, then C-one `rung06_sweep.suite` (`tier=full`): build a stub revolve + a path + an ellipse (WP2–WP5 tools), `sweep:Boss`, one body, export, `check_rung06.py sweep` exits 0. If the checker fails on bbox/volume, start WP7 ★, then re-export once. Then C-one `rung04_sweep.suite` (hex key still one new body, `check_rung04.py final` exits 0).

Revert: revert if the suite is red for a reason other than the checker numbers. A checker miss is the WP7 trigger, not a revert.

### WP7 ★ — Circular sweep spine

Goal: the path’s R150 and R20 stay circular edges, only if WP6’s mesh failed the checker.

Do not start this WP when `check_rung06.py sweep` (or `final`) already passes. A skipped ★ is not a failure and needs no commit. Unlike rung 4, X max sits on the R20 hook ([t0820.jpg](rung-06-frames/t0820.jpg), [t0813.jpg](rung-06-frames/t0813.jpg)); expect this WP to run.

Files if it runs: `sxkernel/src/features.cpp` (`sketch_ordered_polyline` stays for polylines). New `sketch_spine_wire` builds a `TopoDS_Wire` of line edges and `Geom_TrimmedCurve` arcs. `sweep_along_polyline` (or a sibling called from `apply_sweep`) uses that wire. Joints that are tangent use `BRepBuilderAPI_Transformed`. A polyline with a corner keeps `BRepBuilderAPI_RightCorner`. Ellipse profile from WP5 is the section.

Expected delta if it runs: about +250 lines. If skipped: 0.

Check: the same `rung06_sweep.suite` export, `check_rung06.py sweep` exits 0, and a Catch2 case that the path wire has circular edges of radius 150 and 20.

Revert: if the arc solid is invalid or the checker is worse than the polyline numbers, revert and keep the polyline. Do not widen the volume band. WP16 reports the polyline numbers either way.

### WP8 — Extrude Cut draft 15° inward

Goal: Cut Blind 25 with Draft On, 15°, inward, from the Ø30 on the top disc. Not face-draft +Z.

Files: `sxkernel/src/features/ops_solid.cpp` `apply_extrude_revolve` — when `draft_deg` is set and `op == "cut"`, use `BRepFeat_MakeDPrism` (or a loft of the Ø30 and the Ø at depth) instead of `MakePrism`. Sign: inward = taper toward the extrusion direction (smaller at the bottom) ([t0881.jpg](rung-06-frames/t0881.jpg)). `property_panel.gd` `extrude` schema gains `draft_deg` (0 default). Finish-bar `finish:Draft` toggle + `finish:DraftAngle`. `sketch_mode.gd` / `main.gd` pass the param. Face Draft in `ops_panel.gd` `_draft` is untouched. Catch2 `test_rung06_draft.cpp`. `docs/loop/automation-bridge.md` those ids.

Change: Blind 25, draft 15, inward. `R_2 = 8.301` at y = 195. `(13, 195, 0)` is **inside** the solid. Draft 0 / omitted is today’s prism. Outward (larger at the bottom) is a second flag or a negative angle; the walk uses inward. Angle 0 with Draft On is a prism, not a refuse. Angle 75 refused (self-intersecting frustum on this Ø30 × 25).

Expected delta: about +220 lines.

Check: red first, Catch2: Ø30 face at y = 220 on a Ø60 × 40 cylinder, cut Blind 25 draft 15 inward, volume drop 10954 ± 2 %, `(13, 195, 0)` inside. Then C-one `rung06_draft.suite` (`tier=full`): from the swept part (or a stub disc), face sketch Ø30, Cut Blind 25, Draft On 15 inward, `check_rung06.py final` exits 0. Then C-one a rung 1/2/3 extrude suite (no-draft Blind unchanged).

Revert: revert. Do not pass A31 with face-draft or a straight hole.

### WP9 — Survey #1 sketch colours (blue / black / red)

Goal: under-defined entities blue, fully defined near-white (“black” on the dark shop), conflict red. Whole-sketch flip until per-entity DOF exists. Not green.

Files: `game/scripts/sketch_mode.gd` `COLOR_ENTITY` → `Color(0.25, 0.55, 1.0)` (survey: readable blue on dark, or `#1A73E8`). `COLOR_CONSTRAINED` → `Color(0.92, 0.94, 0.96)`. `COLOR_CONFLICT` stays red. `_entity_draw_color`; `game/scripts/main.gd` `_on_sketch_solve` chip (blue digit / green `OK` / red `!` may stay — the chip is not the entity colour). Tests: `game/tests/run_infer_tests.gd` (`"fully constrained draws green"` → draws `COLOR_CONSTRAINED`, message **not** “green”), `run_sketch_fully_defined*.gd`, `run_visual_ux_tests.gd`.

Change: [t0073.jpg](rung-06-frames/t0073.jpg) under-defined stub is blue; [t0350.jpg](rung-06-frames/t0350.jpg) / [t0310.jpg](rung-06-frames/t0310.jpg) fully defined is black/white on shop charcoal. Landing-protocol Visibility line is now the code. **Do not** switch the sketch sheet to light (survey #2 held) so film goldens and `FilmPresentation.FLAT_BG` stay. Rungs 1–5 walks check DOF digits and labels, not RGB — they stay green. The infer suite assertion is rewritten in this commit.

Expected delta: about +40 lines (mostly test message / expected colour).

Check: C-one `infer_tests.suite` (or the suite that owns `run_infer_tests.gd`) and `visual_ux_tests.suite`. Then C-one `rung01_sketch_tests.suite` (geometry unchanged).

Revert: revert, including the test edits.

### WP10 — Survey #3 dimension witness lines + arrows

Goal: each `dimensions[]` record draws extension lines, a dimension line, and filled arrowheads in the sketch plane. Label3D stays. Driving = entity colour (blue/black); driven/reference = `Color(0.55, 0.58, 0.62)`.

Files: `game/scripts/sketch_mode.gd` `_rebuild_dimension_labels` plus new `_rebuild_dimension_geometry` (2 px screen-space ribbon, same trick as `_append_leader_ribbon`). `game/scripts/ui_icons.gd` `"dimension"` is the shape reference (`M5 8v12M19 8v12M5 14h14` plus arrowheads). Tests: `run_rung01_replan9_smart_dim*.gd`, sketch-tools. Drop the heavy black Label3D outline only if a light sheet exists — it does not (WP9 stays on charcoal), so keep a readable outline.

Change: [t0160.jpg](rung-06-frames/t0160.jpg), [t0220.jpg](rung-06-frames/t0220.jpg), [t0310.jpg](rung-06-frames/t0310.jpg) — a dim is a measurement, not a floating HUD number. Walks that read label text (`7.65`, `Ø150`, `40`) still pass; they do not pixel-diff arrows. If a label-restack test fails because arrows occupy the same mm, keep the label stack logic and shorten the witness, do not move the number off the dim.

Expected delta: about +180 lines.

Check: red first, then C-one `rung01_replan9_smart_dim.suite` (or the owning suite) plus `rung04_hex.suite` (AF `7.65` label still there). A length dim on a 40 mm line has two witnesses, a dim line, two arrowheads.

Revert: revert. Do not ship arrows that cover the `220.00` / `90.00` text on the candlestick profile.

### WP11 — Survey #4 green relation glyphs

Goal: relation badges are SW green squares with H/V/∥/⊥/= , matching “little green squares” ([t0309.jpg](rung-06-frames/t0309.jpg), [t0310.jpg](rung-06-frames/t0310.jpg), [t0160.jpg](rung-06-frames/t0160.jpg)). Coincident stays ◉.

Files: `game/scripts/sketch_mode.gd` `COLOR_GLYPH` → `Color(0.20, 0.72, 0.38)`. `_rebuild_constraint_glyphs`: 14×14 rounded-square billboard behind the letter. `COLOR_GLYPH_SELECTED` may stay orange **or** invert to white-on-green. Tests: `game/tests/run_rung01_replan17_glyphs.gd` (positions, not hue — keep G1–G5), `run_rung01_replan15_shaftbadges.gd` and `run_rung01_replan13_measure.gd` (`is_equal_approx(SketchMode.COLOR_GLYPH)` still holds because they compare to the const).

Change: green squares. Hide/Show Sketch Relations is still out of scope (he leaves them on). Glyph **positions** stay the replan-17 contract so wrench badges do not slide.

Expected delta: about +70 lines.

Check: C-one `rung01_replan17_glyphs.suite`, `rung01_replan15_shaftbadges.suite`, `rung01_replan13_measure.suite`. Then C-one `rung04_vertical.suite` (V glyph still shows on the vertex pair).

Revert: revert. Do not leave selected glyphs undrawable.

### WP12 — Survey #5 edge colour and width

Goal: edges are a slightly lighter hairline, 1.5–2.0 px screen-space ribbon, so they read as a drawing not a crack ([t0820.jpg](rung-06-frames/t0820.jpg), [t0813.jpg](rung-06-frames/t0813.jpg)).

Files: `game/scripts/document_view.gd` `EDGE_COLOR` → `Color(0.22, 0.24, 0.28)` on the dark shop. `_rebuild_edges` / `_edge_material`: reuse the glyph leader ribbon instead of `PRIMITIVE_LINES`. Silhouette-only pass is survey #15 — **not** this WP. Tests: `game/tests/run_display_tests.gd`.

Change: shaded-with-edges default looks closer to the finished candlestick iso. Film look (`apply_film_look`) does not change albedo; edges on the pale film body get the same 1.5–2 px ribbon (survey: still thinner/colder than SW on film, but not engraved). `run_display_tests` `DisplayMode` cycle Shade / Edges / Wire still works. Rungs 1–5 do not pin edge RGB.

Expected delta: about +80 lines.

Check: C-one `display_tests.suite`. Then C-one `rung03_part_check.suite` or a shaded-edges film smoke if one exists. Wireframe still shows edges.

Revert: revert. Do not leave `PRIMITIVE_LINES` at the new colour only if the ribbon path is red — colour-only is an acceptable fallback **in the same commit** if the ribbon fails twice; say so. Do not skip the colour change.

### WP13 — Survey #6 hover vs select accents

Goal: face/edge **select** = Onshape yellow `Color(1.0, 0.76, 0.03)` (`#ffc107`). Face/edge **hover** = cooler `Color(0.45, 0.78, 0.95)`. Body select: keep a blue tint or switch to a yellow outline. Kill or dim AABB corners (`Color(0.15, 0.55, 1.0)` → alpha 0, or 4 px ticks only).

Files: `game/scripts/document_view.gd` `SELECTED_FACE_COLOR`, `HOVER_FACE_COLOR`, `_selection_corners`. `game/scripts/viewport_interaction.gd` box-select fill/edge `Color(0.35, 0.6, 0.95, …)` → the new hover cyan (or leave box-select as-is if tests pin it — then say so). Tests: `game/tests/run_select_tests.gd`, `run_visual_ux_tests.gd`, `run_display_tests.gd` `test_selection_corners` (corners node may exist with a null mesh when dimmed).

Change: [t0828.jpg](rung-06-frames/t0828.jpg) green-face language is not copied; the survey picked Onshape yellow select / Fusion cyan hover so orange≈yellow stops competing. Sketch selection colours are WP9, not this WP. Rung 3/5 face picks are `face_normal` + `plane=`, not RGB — walks stay green. `test_selection_corners` “corner mesh built on select” must be updated if corners are dimmed to empty: assert alpha 0 / no mesh, not “mesh != null”.

Expected delta: about +50 lines.

Check: C-one `select_tests.suite`, `visual_ux_tests.suite`, `display_tests.suite`. Then C-one `rung05_fillet.suite` (Shift+face fillet still adds edges).

Revert: revert, including the corners assertion.

### WP14 — Survey #8 grid and origin planes default off

Goal: origin-plane quads **off** until Sketch-on-plane pick. Grid **on in sketch / place**, **off** (or alpha 0.08) in idle part mode. `G` still toggles. [t0820.jpg](rung-06-frames/t0820.jpg) has neither; `hexkey.png` is the failure.

Files: `game/scripts/document_view.gd` `origin_planes_visible := false`. `game/scripts/world_gizmos.gd` `grid_visible` default false in idle; `game/scripts/main.gd` File → New; sketch begin / exit and place-arm toggle grid. `game/scripts/origin_planes.gd` pick still hits the finite quads when a plane is the sketch target (invisible planes must remain pickable as datums — hit test the quad even when `mesh == null`, or keep an invisible collider). Tests: `run_display_tests.gd` (`set_gizmos_visible(true) restores` must not assume `grid_visible` was true — restore the **pre-hide** grid flag, or assert idle New has grid off and sketch-on has grid on), `run_wrench_placement_tests.gd`, `run_rung04_planes.suite` (named Front/Top/Right still clickable).

Change: idle New matches films (`apply_film_presentation` already hides planes — no poster re-shot). `G` toggles grid. Sketch-on-Front shows the grid on XY. Exit Sketch hides it. Datum names stay visible in the tree / View. Rung 4 planes suite clicks Front/Right by datum name, not by seeing a cyan quad — stays green if the hit test remains.

Expected delta: about +70 lines.

Check: C-one `display_tests.suite`, `rung04_planes.suite`, `wrench_placement` / `run_wrench_placement_tests` owning suite. After File → New, `origin_planes_visible == false` and the Grid node is hidden; after Front Sketch, grid visible; after Exit, grid hidden; click datum Right still starts a Right sketch.

Revert: revert. Do not leave origin planes unpickable.

### WP15 — Walk

Goal: `tools/walk_rung06.py` runs the checklist. Registry freezes the row list. Rungs 1–5 stay frozen.

Files: `tools/walk/registry.py` (`RUNG6_ROWS`, `_RUNG_SPEC["rung06"]`, `install`), new `tools/walk/app06.py`, `tools/walk/rung6/ui06.py`, `tools/walk/rung6/rows06_chunk{1,2,3,4}.py`, new `tools/walk_rung06.py` (same CLI as `walk_rung05.py`). `tools/test_walk_registry.py` gains `FROZEN_ROWS_06`. `tools/confirm_all.sh` gains `unit_rung06`, walk 6 on display `:26` / port `47326`, and the summary lines (`rung6`, `check-final-final.txt`). `docs/loop/README.md` lists this plan, the checklist, and `walk_rung06.py`. `docs/loop/automation-bridge.md` for new click forms (`menu:TemporaryAxes`, `finish:Draft`, ellipse 3-click). `tools/walk/chrome.py` `_HEADLESS` row 6.

Change: each checklist row is a method that calls `ui06` helpers and `self.clause(...)`. Chunks and checkpoints are decision 11. Export rows share one 3MF per stage. A36 is the headless evidence row (needs `--a15`; without the flag it is `BLOCKED-by-flag`), same clause names as rung 5 A25.

Expected delta: about +800 lines.

Check: C-dry. Registry test green for six rungs. `walk_rung06.py --rows N1,A1,A2 --dry-run` prints those rows. Do not launch Godot here.

Revert: revert if the registry test is red after two attempts.

### WP16 — The single full pass

Goal: one pass on this VM. Counts only. No product edits unless a count is red, and then only the smallest fix, re-run once.

Change: none expected. Run:

`tools/confirm_all.sh`

That script builds, imports, runs the kernel, the lints, `test_check_rung02/03/04/05/06.py`, the registry test, the headless suites, and the six walks. Do not also run `make test` or a second suite pass.

Report, and nothing else: the confirm summary lines (build, kernel, lint, godot suite count, rung1 77, rung2 44, rung3 46, rung4 32, rung5 36, rung6 46, each checker tail). If WP7 was skipped, one line: `spine: polyline, checker passed`. If it ran, one line: `spine: arc` or `spine: reverted`.

Expected delta: 0.

Check: the summary. A walk row that fails is a product bug; fix it and re-run confirm once. Do not re-run confirm before that fix.

Revert: not this WP. A bad fix-up commit reverts on its own.

## Chunks

| Chunk | Rows | Ends |
|---|---|---|
| 1 | N1 A1 A2 L1 A3 A4 A5 A6 A7 A8 A9 N2 A10 A11 A12 L2 A13 A14 A15 | revolve solid, `revolve.sxp`, bbox 224 × 220 × 224, no handle |
| 2 | A16 A17 A18 A19 A20 A21 A22 L3 A23 | path sketch saved, `path.sxp`, path at y = 10, still one body |
| 3 | N3 A24 A25 A26 A27 A28 L4 A29 | ribbon fused, `sweep.sxp`, bbox 304.1 × 220 × 224 |
| 4 | A30 A31 N4 A32 A33 A34 L5 A35 N5 A36 | `final.sxp`, checker passed, headless evidence |

46 rows: 36 A, 5 L, 5 N. Clause text: [`rung-06-checklist.md`](rung-06-checklist.md).

## Out of scope

- A units dialog, or editing the pinned New sentence.
- Trim-to-closest as a PropertyManager option (Power Trim is the walk path).
- Display/Delete Relations filter. Hide/Show Sketch Relations toggle. Display Pane transparency (survey #12 held).
- Foreshortened radius leaders ([t0524.jpg](rung-06-frames/t0524.jpg) — display only).
- Hidden Lines Removed as a fourth display mode (W cycle stays Shade / Edges / Wire).
- Mouse gestures. Fully-Define command.
- Survey #2 light sketch sheet, #7 SSAO, #9 body albedo, #10 ViewCube, #11 Export Image, #13 rail-icon recolour, #14 gold pads, #15 hidden-line / tangent edges.
- A demo film. `docs/plan/STATUS.md`. Associative sketches beyond Convert / the WP4 silhouette dim.
- Fillet of any candlestick edge.
