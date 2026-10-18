# Rung 7 prep — combination spanner (Mahtabalam)

Analysis only, against `main` `24a8306` (Rung 6 #275). Video: [How to Sketch Combination Spanner in Solidworks](https://www.youtube.com/watch?v=RZB8m9li098) (CAD CAM Tutorial / Mahtabalam, 9:19, 2016-08-01; oEmbed verified). Transcript: `sx-loop/sources/subs/RZB8m9li098.txt` (YouTube auto-captions; numbers are garbled — stills win).

**Frames (this pass).** 296 JPEGs in [`docs/loop/rung-07-frames/`](rung-07-frames/) plus [`index.md`](rung-07-frames/index.md). `tSSSS.jpg` is the frame at SSSS seconds. Every *as shown* value, plane, view, relation and click target below is taken from those stills; the file is cited at the point of use (e.g. [t0123.jpg](rung-07-frames/t0123.jpg)). Spoken numbers the stills contradict are called out. The intro drawing ([t0021.jpg](rung-07-frames/t0021.jpg)) is a map, not a second source of truth: the modeling pass wins where they conflict.

**Axis map** (same as rungs 3–6). Front = XY (normal +Z). Sketch Y on Front is world +Y (up). Origin = open-end ellipse centre. Handle runs +X. Mid-plane extrude straddles Z = 0.

**Units.** MMGS. Millimetre values on the stills.

## Locked values (from frames)

| Item | Locked value | Frame |
|---|---|---|
| First-sketch plane / view | **Front**, sketch opens on Front (`*Front` status) | [t0022.jpg](rung-07-frames/t0022.jpg) *select front plane sketch*; [t0031.jpg](rung-07-frames/t0031.jpg) |
| Centerline | Horizontal construction through the origin, +X | [t0031.jpg](rung-07-frames/t0031.jpg) 180°, through the red origin |
| Ellipse | Centre at origin; 3-click ellipse. Major along the 17° construction | [t0042.jpg](rung-07-frames/t0042.jpg) tool; [t0068.jpg](rung-07-frames/t0068.jpg) |
| Handle-axis angle | **17.00°** between the horizontal CL and the construction line. Opening toward −X, slightly −Y (major at **−17°** from +X) | [t0068.jpg](rung-07-frames/t0068.jpg) `17.00deg` |
| Spoken “60 55 50” | **60** is typed on the major, then replaced by **55**. **50** is the minor. Ellipse **55 × 50** (full axes) | [t0096.jpg](rung-07-frames/t0096.jpg) `60.00mm` on the major; [t0100.jpg](rung-07-frames/t0100.jpg) **55** on the major; [t0108.jpg](rung-07-frames/t0108.jpg) **50** on the minor; [t0117.jpg](rung-07-frames/t0117.jpg) both on the sketch |
| Jaw line | Parallel to the 17° construction; endpoint **coincident** on the ellipse ([t0084.jpg](rung-07-frames/t0084.jpg) Ellipse1 + Point13) | [t0078.jpg](rung-07-frames/t0078.jpg)–[t0084.jpg](rung-07-frames/t0084.jpg) |
| Jaw offset | **12.50** from the 17° axis to the jaw (half-gap). Open-end gap = **25** | [t0117.jpg](rung-07-frames/t0117.jpg) `12.50mm` |
| Jaw length | **20**. Spoken “10 mm gap” is **not** this | [t0123.jpg](rung-07-frames/t0123.jpg) 19.05 → 20; [t0135.jpg](rung-07-frames/t0135.jpg) **20** |
| Mirror Entities (jaws) | Copy the jaw about the 17° construction | [t0135.jpg](rung-07-frames/t0135.jpg) both flanks |
| 3-point arc | **R15** throat at the inner jaw ends | [t0147.jpg](rung-07-frames/t0147.jpg) `15.00mm` / R15 |
| Trim (open end) | Trim the **outer ellipse** between the jaws → C | [t0150.jpg](rung-07-frames/t0150.jpg) scissors on the outer; [t0156.jpg](rung-07-frames/t0156.jpg) C ready |
| Ring | Circle on the CL, **Ø33** | [t0175.jpg](rung-07-frames/t0175.jpg) `33.00mm` |
| Hex 1 | Polygon, across-flats **25**, point-up, inside Ø33 | [t0192.jpg](rung-07-frames/t0192.jpg) `25.00mm` |
| Hex 2 | Second hex AF **25**, rotated ~30° rel. (SW 90° on a hex) | [t0208.jpg](rung-07-frames/t0208.jpg) `25mm` |
| Trim (box end) | Trim inside both hexes → 12-point | [t0235.jpg](rung-07-frames/t0235.jpg) 12-point, both 25 dims remain |
| Center distance | **240** origin → Ø33 centre | [t0248.jpg](rung-07-frames/t0248.jpg) `240.00mm` |
| Handle line | Horizontal (caption “vertical” is wrong). Relation **Horizontal1** | [t0264.jpg](rung-07-frames/t0264.jpg) |
| Spoken “Gap 10 mm” | **10.00** from the CL to the handle edge (half-width). Full handle width **20**. Status Y = 10 | [t0270.jpg](rung-07-frames/t0270.jpg) `10.00mm`; [t0294.jpg](rung-07-frames/t0294.jpg) |
| Mirror Entities (handle) | Copy the handle line about the CL; **Symmetric** shows up in SW | [t0294.jpg](rung-07-frames/t0294.jpg) Symmetric3 |
| Coincident + trim (handle) | Line ends coincident to the ellipse and to Ø33; trim leftovers | [t0285.jpg](rung-07-frames/t0285.jpg)–[t0315.jpg](rung-07-frames/t0315.jpg) |
| Finished sketch | One Front sketch: C + 12-point ring + handle strip. Exit | [t0315.jpg](rung-07-frames/t0315.jpg) |
| Boss-Extrude1 | Selected contours = both **heads**. Mid Plane **10**. Merge off (first solid) | [t0332.jpg](rung-07-frames/t0332.jpg) regions 1+2; [t0335.jpg](rung-07-frames/t0335.jpg) Mid Plane 10.00mm |
| Boss-Extrude2 | Same Sketch1, **handle** region. Mid Plane **6**. **Merge result** on | [t0347.jpg](rung-07-frames/t0347.jpg) 6.00mm, Merge, Region\<1\> |
| Fillet1 | **R30**, open-end neck, both Z-edges (status length 6 = handle thickness) | [t0366.jpg](rung-07-frames/t0366.jpg) Fillet1 |
| Fillet2 | **R20**, box-end neck, both Z-edges | [t0380.jpg](rung-07-frames/t0380.jpg) Fillet2 |
| Face sketch | Top face of the **handle**, Convert Entities (the filleted handle outline: two lines + two arcs) | [t0385.jpg](rung-07-frames/t0385.jpg) |
| Offset Entities | Tried 10 / 2 / 1 / **3** then locked **5.00** inward, Select chain | [t0400.jpg](rung-07-frames/t0400.jpg) 3 mm “this is more”; [t0415.jpg](rung-07-frames/t0415.jpg) `5.00mm` |
| Cut-Extrude1 | Blind **1** mm, region area **1895.51 mm²**, perimeter 402.35 mm | [t0430.jpg](rung-07-frames/t0430.jpg) area in the status bar; [t0438.jpg](rung-07-frames/t0438.jpg) Cut-Extrude1 |
| Fillet3 | **R3** on both ends of the recess (Edge\<1\>, Edge\<2\>) | [t0462.jpg](rung-07-frames/t0462.jpg) 3.00mm; [t0471.jpg](rung-07-frames/t0471.jpg) Fillet3 |
| Mirror1 | Mirror Face/Plane = **Front Plane**. Features = Fillet3 + Cut-Extrude1 | [t0483.jpg](rung-07-frames/t0483.jpg) Front Plane; [t0492.jpg](rung-07-frames/t0492.jpg) Mirror1 |
| Fillet4 | **R1**, C outer, tangent-propagated, both faces | [t0498.jpg](rung-07-frames/t0498.jpg) Radius 1mm, Arc Length 139.23 |
| Fillet5 | **R1** on all remaining edges | [t0510.jpg](rung-07-frames/t0510.jpg)–[t0516.jpg](rung-07-frames/t0516.jpg) Fillet5, Total Length 539.98 |
| Material | Cast Stainless Steel, viewing only. No text extrude of “CAD CAM TUTORIAL” | [t0523.jpg](rung-07-frames/t0523.jpg)–[t0540.jpg](rung-07-frames/t0540.jpg) |

**Spoken vs frames.** Auto-caption “assign distance 60 mm 55 mm 50 mm” is three keystrokes on two ellipse axes: 60 is discarded ([t0096.jpg](rung-07-frames/t0096.jpg) → [t0100.jpg](rung-07-frames/t0100.jpg)). “Gap 10 mm” is the handle **half-width**, not the open-end gap (that gap is 2 × 12.50 = 25, equal to the hex AF). “Make vertical” on the handle line is **Horizontal** ([t0264.jpg](rung-07-frames/t0264.jpg)). Offset “make 3 mm / this is more / 5m” is him hunting; **5** sticks ([t0415.jpg](rung-07-frames/t0415.jpg)).

**Drawing vs video.** [t0021.jpg](rung-07-frames/t0021.jpg) already has 17°, 12.50, 50, 20, 55, 10, 240, R15, R30, R20, Ø33, 25/25, side 6/10, offset 5. The **R3** on the drawing is the recess-end fillet (video Fillet3 = 3 mm), not the later 1 mm all-edge set. The handle lettering is drawing-only.

**Unpinned (reasoned).** (1) Exact SW polygon inscribed/circumscribed flag — AF **25** is on the stills, and the hex sits inside Ø33 with a ~2 mm vertex wall (`R_hex = 25/√3 ≈ 14.43`, ring 16.5), so across-flats not across-corners. (2) Second-hex rotation is 30° relative; SW’s 90° spin on a hex is that 30°. (3) Recess cut depth is spoken “1 mm” and the feature exists at [t0438.jpg](rung-07-frames/t0438.jpg); the PM in [t0430.jpg](rung-07-frames/t0430.jpg) still shows a leftover 6.00 while he types. Treat depth as **1**. (4) Neck-fillet included angle is not dimensioned; checker uses 90° (see §3).

## 1. Demands (video order)

Lesson: new part; one Front sketch of a combination wrench; two mid-plane extrudes (heads 10, handle 6); neck fillets; offset recess both faces via feature-mirror; 1 mm edge fillets; assign steel (viewing).

1. **New part, MMGS.** Empty part. Intro drawing only ([t0021.jpg](rung-07-frames/t0021.jpg)).
2. **Front plane, Sketch** ([t0022.jpg](rung-07-frames/t0022.jpg), [t0031.jpg](rung-07-frames/t0031.jpg)). Status `*Front`.
3. **Centerline** through the origin, +X ([t0031.jpg](rung-07-frames/t0031.jpg)).
4. **Ellipse**, centre at the origin ([t0042.jpg](rung-07-frames/t0042.jpg)). Construction line from the ellipse out through the origin side, then **angle 17°** to the horizontal CL ([t0068.jpg](rung-07-frames/t0068.jpg)).
5. **Line** for the first jaw. **Parallel** to the 17° construction ([t0078.jpg](rung-07-frames/t0078.jpg)). **Coincident** jaw endpoint to the ellipse ([t0084.jpg](rung-07-frames/t0084.jpg)).
6. **Smart Dim** ellipse **55** (major, along 17°) and **50** (minor) ([t0100.jpg](rung-07-frames/t0100.jpg), [t0108.jpg](rung-07-frames/t0108.jpg)). **12.50** axis-to-jaw ([t0117.jpg](rung-07-frames/t0117.jpg)). **20** jaw length ([t0123.jpg](rung-07-frames/t0123.jpg)).
7. **Mirror Entities**: jaw about the 17° construction ([t0135.jpg](rung-07-frames/t0135.jpg)).
8. **3 Point Arc, R15** at the inner jaw ends ([t0147.jpg](rung-07-frames/t0147.jpg)).
9. **Trim Entities**: outer ellipse between the jaws ([t0150.jpg](rung-07-frames/t0150.jpg) → [t0156.jpg](rung-07-frames/t0156.jpg) C).
10. **Circle Ø33** on the CL, centre still free in X ([t0175.jpg](rung-07-frames/t0175.jpg)).
11. **Polygon** hexagon, AF **25**, inscribed in Ø33 ([t0192.jpg](rung-07-frames/t0192.jpg)). Second hex AF **25**, rotated ~30° ([t0208.jpg](rung-07-frames/t0208.jpg)).
12. **Trim Entities** inside both hexes → 12-point box ([t0235.jpg](rung-07-frames/t0235.jpg)).
13. **Smart Dim 240** origin to Ø33 centre ([t0248.jpg](rung-07-frames/t0248.jpg)).
14. **Line** along the handle, **Horizontal**, dim **10** from the CL ([t0264.jpg](rung-07-frames/t0264.jpg), [t0270.jpg](rung-07-frames/t0270.jpg)). **Mirror Entities** about the CL ([t0294.jpg](rung-07-frames/t0294.jpg)). **Coincident** ends to the ellipse and to Ø33; **trim** leftovers ([t0285.jpg](rung-07-frames/t0285.jpg)–[t0315.jpg](rung-07-frames/t0315.jpg)).
15. **Exit Sketch** ([t0315.jpg](rung-07-frames/t0315.jpg)).
16. **Extruded Boss**, pick both head regions, **Mid Plane 10** ([t0335.jpg](rung-07-frames/t0335.jpg)).
17. **Extruded Boss** on Sketch1 again, handle region, **Mid Plane 6**, Merge ([t0347.jpg](rung-07-frames/t0347.jpg)).
18. **Fillet 30** open-end neck ([t0366.jpg](rung-07-frames/t0366.jpg)). **Fillet 20** box-end neck ([t0380.jpg](rung-07-frames/t0380.jpg)).
19. **Face Sketch** on the handle top. **Convert Entities** ([t0385.jpg](rung-07-frames/t0385.jpg)). **Offset Entities 5** inward, chain ([t0415.jpg](rung-07-frames/t0415.jpg)).
20. **Extruded Cut Blind 1** mm ([t0430.jpg](rung-07-frames/t0430.jpg), [t0438.jpg](rung-07-frames/t0438.jpg)).
21. **Fillet 3** both recess ends ([t0462.jpg](rung-07-frames/t0462.jpg)).
22. **Mirror** about **Front Plane**, features Fillet3 + Cut-Extrude1 ([t0483.jpg](rung-07-frames/t0483.jpg), [t0492.jpg](rung-07-frames/t0492.jpg)).
23. **Fillet 1** C outer both faces ([t0498.jpg](rung-07-frames/t0498.jpg)). **Fillet 1** all remaining edges ([t0516.jpg](rung-07-frames/t0516.jpg)).
24. **Edit Material → Steel → Cast Stainless Steel.** Viewing only ([t0540.jpg](rung-07-frames/t0540.jpg)).

UI along the way: origin-plane pick, Sketch, Centerline, Ellipse (3-click), Line, Smart Dim (length, angle, diameter, parallel-offset), Parallel, Coincident (point-on-ellipse), Mirror Entities + Symmetric, 3-Point Arc, Trim (ellipse and line-line), Polygon AF hex, Horizontal, Exit, Extrude selected contours + Mid Plane + Merge, Fillet (edge pick and all-edges), face Convert, Offset chain, Extrude Cut Blind, Feature Mirror about an origin plane (cut + fillet).

## 2. Gap critique

Grep / read on `24a8306`. HAVE = the named tool does this step. PARTIAL = pieces exist, the video step does not. MISSING = no such tool.

| # | Demand | Mark | What the code does |
|---|---|---|---|
| 1 | New, MMGS, empty | HAVE | `document_view.gd` `new_document`: `units = mmgs`, `OriginPlanes.seed`. |
| 2 | Front + Sketch | HAVE | Origin Front quad. Click starts XY. |
| 3 | Centerline through origin | HAVE | Line + construction. Infer-horizontal on +X. |
| 4 | Ellipse at origin, 17° construction | HAVE | Real 3-click ellipse (`sketch_ellipse.gd`, `SketchEntityType::Ellipse`). Angle chip / Smart Dim angle (`ConstraintType::Angle`, two lines). |
| 5 | Jaw line, Parallel, coincident to ellipse | PARTIAL | Parallel chip HAVE. Coincident is **endpoint-to-endpoint** (`_closest_endpoints`); ellipse `self` maps to the **centre** (`solver_planegcs.cpp` `point_of`). No `PointOnEllipse`. The video click ([t0084.jpg](rung-07-frames/t0084.jpg)) is point-on-curve. |
| 6 | Dims 55 / 50 / 12.50 / 20 | HAVE | Ellipse major/minor via Smart Dim (`_apply_diameter_dim` ellipse axis). Line length. Parallel-offset distance. |
| 7 | Mirror Entities about the 17° line | PARTIAL | `mirror_selected()` copies line/arc/circle about a selected line. **No Symmetric constraint** is added. SW shows Symmetric on the handle copy ([t0294.jpg](rung-07-frames/t0294.jpg)). Kernel `ConstraintType::Symmetric` exists; the tool does not emit it. |
| 8 | 3-Point Arc R15 | HAVE | Arc variant `three_point` + radius dim. |
| 9 | Trim outer ellipse | **MISSING** | `trim_entity` only Line and Circle (`sketch_tools.cpp`). No elliptical-arc type (`SketchEntityType` is Point/Line/Circle/Arc/Spline/Ellipse). `collect_line_intersections` also ignores Ellipse, so a jaw **line** cannot use the ellipse as a cutter either. **First named-tool stop** ([t0150.jpg](rung-07-frames/t0150.jpg)). |
| 10 | Circle Ø33 | HAVE | Circle + diameter. |
| 11 | Two hexes AF 25, 30° rel. | HAVE | Polygon `across_flats`, 6 sides. Drag sets rotation. |
| 12 | Trim inside hexes → 12-point | HAVE | Hex sides are lines; line-line Power Trim works. No Trim-away-inside option; click-by-click is enough. |
| 13 | 240 centre distance | HAVE | Two-point Smart Dim. |
| 14 | Handle Horizontal, 10, Mirror, coincident, trim | PARTIAL | Horizontal + length HAVE. Mirror copy PARTIAL (no Symmetric). Coincident line-end to **circle** can be faked via trim (line-circle intersections exist). Coincident / trim line-to-**ellipse** MISSING (same as 5 and 9). |
| 15 | Exit Sketch | HAVE | `exit_sketch`. |
| 16 | Extrude heads, selected contours, Mid Plane 10 | HAVE | Contour checkboxes (`selected_contours`). `end=midplane` → kernel `symmetric`. |
| 17 | Extrude handle Mid Plane 6, Merge | HAVE | Second extrude on the same sketch, `op=fuse`. |
| 18 | Fillet 30 / 20 on neck edges | HAVE | Edge-pick fillet. Radius 30/20. |
| 19 | Face Convert of handle outline (lines **and arcs**), Offset 5 chain | **MISSING** / PARTIAL | Convert projects **line or full circle** only (`sketch_convert_edge.gd` `PROJECTORS`; `NOT_SUPPORTED` for other types). After Fillet 30/20 the handle-end edges are **arcs**. Offset `kOffsetters` is Line + Circle; **Arc skipped** (`sketch_tools.cpp`). A 5 mm inward racetrack cannot be built from the converted chain. |
| 20 | Cut Blind 1 mm | HAVE | Extrude Cut Blind. (Unreachable if 19 fails.) |
| 21 | Fillet 3 recess ends | HAVE | Edge-pick. (Unreachable if 20 fails.) |
| 22 | Feature Mirror about **Front** of Fillet3 + Cut | **PARTIAL / MISSING** | Kernel Cut of an extrude-cut **HAVE** (`FeatureMirror::POLICY` Extrude/`cut` → Cut). **Fillet is Skip** (warning, no replay). UI plane pick is **a planar body face** (`_resolve_mirror_pick`); origin Front is not offered. After mid-plane extrude the Front plane sits *inside* the solid (Z = 0) — there is no Front face to click. |
| 23 | Fillet 1 C outer; Fillet 1 all edges | HAVE | Edge pick + `_fillet_all`. |
| 24 | Cast stainless material | MISSING | Viewing only. No material library. Harmless. |

**Readiness.** A named-tool click-through gets through New, Front, centerline, ellipse, 17°, Parallel, 55×50, 12.50, 20, 3-point R15, Ø33, both AF-25 hexes, 12-point trim, 240, handle 10, mid-plane 10/6, neck fillets 30/20, and (later) 1 mm all-edges. It **stops at Trim of the outer ellipse** ([t0150.jpg](rung-07-frames/t0150.jpg)): the C never opens, mixed contours keep a full ellipse, and the open-end head is the wrong solid.

A user who fakes the C (construction lines instead of a trimmed ellipse, or a polyline stand-in) can continue through the hex 12-point and both extrudes, then **stops again at Convert/Offset of the filleted handle chain** ([t0385.jpg](rung-07-frames/t0385.jpg)–[t0415.jpg](rung-07-frames/t0415.jpg)), and **again at Feature Mirror about origin Front of a fillet** ([t0483.jpg](rung-07-frames/t0483.jpg)). Those are downstream of the first stop.

**Risks, largest first.**

- **No elliptical trim / no elliptical arc.** The open end *is* a trimmed ellipse. Without it the C, the jaw coincident, and handle-line trim against the ellipse all fail. This is the rung.
- **Convert + Offset skip arcs.** The recess sketch is the filleted handle outline offset 5 mm. Line/circle-only convert and offset cannot place that racetrack.
- **Feature Mirror cannot pick origin Front**, and **fillet-mirror is POLICY Skip.** Even a scripted plane at Z = 0 would skip Fillet3; the mirrored recess would have sharp ends.
- **Point-on-ellipse coincident is a no-op / wrong (snaps to centre).** Jaw-on-ellipse ([t0084.jpg](rung-07-frames/t0084.jpg)) and handle-on-ellipse ([t0285.jpg](rung-07-frames/t0285.jpg)) are this relation.
- **Sketch Mirror copies without Symmetric.** Workable with a second 12.50 / 10 dim; not what the stills show.
- **Trim-to-closest / Trim-away-inside** chrome. Power Trim can still cut the hexes. S.
- **Display/Delete Relations, material.** Viewing. S.

## 3. Checker numbers

Locked solid from the stills. Front XY, origin = ellipse centre, handle +X, mid-plane about Z = 0. Ellipse full axes 55 × 50, major at α = −17°. Throwaway Python (not committed); shoelace N = 96 on the C; hex union analytic.

**C contour** (open end). Jaw–ellipse at local y′ = ±12.5, x′ < 0:

\[
x'_\mathrm{jaw} = -27.5\sqrt{1-(12.5/25)^2} = -23.816
\]

Inner jaw x′ = x′_jaw + 20 = −3.816. R15 centre toward the opening, x′ = −12.107; throat at x′ = 2.893 (just past the origin along the major). Remaining ellipse is the long arc θ = 150° → −150° through 0°. Shoelace:

\[
A_C = 1478.68\ \mathrm{mm}^2
\]

(full ellipse π·27.5·25 = 2159.84; the bite is 681). C xy sample: X ∈ [−26.430, 27.295], Y ∈ [−25.223, 25.221].

**Ring.** Ø33 minus the union of two AF-25 hexes. Regular hex area \( (3\sqrt{3}/2)(25/\sqrt{3})^2 = 541.266 \). Intersection of two hexes at 30° is the inscribed dodecagon, inradius 12.5, area \( 12·12.5^2\tan(\pi/12) = 502.405 \). Union 580.127. Outer π·16.5² = 855.299.

\[
A_\mathrm{ring} = 275.17\ \mathrm{mm}^2
\]

**Handle strip.** Horizontal y = ±10 from the +X ellipse hits (≈ 24.45 and 25.60) to the left chord of Ø33 (x = 226.876). Trapezoid shoelace \( A_h = 4037.05 \). True ends follow the ellipse / circle arcs (the trapezoid overcounts the circular segment ≈ 46 mm² and a similar ellipse cap). Used as-is; see tolerance.

**Boss volumes** (no fillets, no recess):

\[
V_C = 1478.68 \times 10 = 14787,\quad
V_\mathrm{ring} = 275.17 \times 10 = 2752,\quad
V_h = 4037.05 \times 6 = 24222
\]

**Neck fillets.** Concave, edge length = handle thickness 6, ~90° in XY (the ellipse tangent at the handle hit is not exactly 90° — unpinned). Area per 90° concave fillet \( R^2(1-\pi/4) \). Two Z-edges each:

\[
V_{30} \approx 2·30^2·(1-\pi/4)·6 = 2318,\quad
V_{20} \approx 2·20^2·(1-\pi/4)·6 = 1030
\]

**Recess.** SW status area **1895.51 mm²** ([t0430.jpg](rung-07-frames/t0430.jpg)), depth 1, both faces after Mirror1. R3 concave corners add back \( 8·3^2(1-\pi/4)·1 \approx 15.5 \).

\[
V_\mathrm{recess} = 1895.51 \times 1 \times 2 = 3791
\]

**1 mm all-edge (convex).** Perimeter estimate of C + ring outer + handle sides + 12-point + verticals, both faces: P ≈ 1938 mm. Remove \( P·1^2(1-\pi/4) \approx 416 \).

\[
V = 14787 + 2752 + 24222 + 2318 + 1030 - 3791 + 16 - 416 = 40918\ \mathrm{mm}^3
\]

| | min | max | size |
|---|---:|---:|---:|
| X | −26.43 | 256.50 | 282.93 |
| Y | −25.22 | 25.22 | 50.45 |
| Z | −5.00 | 5.00 | 10.00 |

X min is the rotated lower jaw–ellipse point `to_world(−23.816, −12.5)`. X max is the ring 240 + 16.5. Y is the remaining ellipse AABB (`sqrt((27.5 sin 17°)^2 + (25 cos 17°)^2) ≈ 25.22`). Z is mid-plane 10. 1 mm edge fillets sit *inside* that box (they do not grow it). Neck fillets add material inside it. Recess is 1 mm into the handle faces (Z still ±5 at the heads).

**Tolerance.** Analytic hex/ring and the SW recess area are solid. C shoelace sampling error ≪ 0.2 %. Dominant uncertainty is the **90° neck-fillet angle** (ellipse tangent at y = ±10 is ~118° from +X) and the handle-end chord-vs-arc caps (~0.7 % of V). Treat

\[
V = 4.09 \times 10^4\ \mathrm{mm}^3,\quad
\mathrm{bbox}\ 282.9 \times 50.4 \times 10.0
\]

as a **±5 %** band until an OCCT replica of this locked profile; then a 0.5 % band like rung 5.

**Mutants, not targets.** Ellipse 60 × 50 (the discarded 60). Open-end gap 10 (the ladder misread; frames are 25). Handle width 10 overall instead of 10 half. Hex 25 as across-corners (would sit at Ø25 inside Ø33). Offset 3 mm (he tried it; [t0415.jpg](rung-07-frames/t0415.jpg) is 5). Recess on one face only (skip Mirror1). Drawing R3 as the all-edge set (video is 1 mm). “CAD CAM TUTORIAL” extruded.

Inside metal (final, locked): `(0, 18, 0)` (C body, above the 12.5 jaw), `(120, 0, 0)` (handle core), `(240, 15, 0)` (ring wall, between the 12-point and Ø33). Outside: `(−30, 0, 0)` (past the jaws), `(240, 0, 0)` (12-point bore centre, empty), `(270, 0, 0)` (past the ring), `(0, 0, 8)` (above the 10 mm head), `(120, 0, 4)` (above the 6 mm handle).

## 4. Ranked gaps

Most blocking for *this* video’s named tools first. Size is a gut order-of-magnitude (S < 1 WP, M ~1–2, L several).

| # | Gap | Size | Subsystem |
|---|---|---|---|
| 1 | Trim ellipse → elliptical arc (and line/ellipse intersections so jaws and handle trim against it) | L | kernel (`sketch_tools` trim + `SketchEntityType`), sketch solver, regions, UI |
| 2 | Convert + Offset of **arc** chains (filleted handle outline, 5 mm inward racetrack) | M–L | kernel `sketch_tools` `kOffsetters` + `sketch_convert_edge.gd` / `sketch3d` projectors |
| 3 | Feature Mirror plane = **origin Front** (not a body face) | M | UI (`ops_panel.gd` `_resolve_mirror_pick`); kernel already takes `plane_point` / `plane_normal` |
| 4 | Feature Mirror of **Fillet** (POLICY Skip) | M | kernel `ops_transform.cpp` `FeatureMirror::POLICY` |
| 5 | Point-on-ellipse coincident (chip today snaps the point to the ellipse **centre**) | M | solver (PlaneGCS `PointOnEllipse`) + UI (`constrain("coincident")` / `_closest_endpoints`) |
| 6 | Sketch Mirror Entities emits **Symmetric** | S–M | UI `mirror_selected`; kernel Symmetric exists |
| 7 | Trim-to-closest / Trim-away-inside (Power Trim can still do the hexes) | S | UI |
| 8 | Display/Delete Relations, material library | S | UI / not needed for the solid |
| 9 | Checker + walk + `check_rung07.py` | M | tests |

Already in the product, no package: New MMGS, Front origin plane, Centerline, real 3-click ellipse, Angle, Parallel, Smart Dim length/diameter/ellipse-axis/offset, 3-point arc, Polygon AF hex, line-line and line-circle trim, Horizontal, Exit, selected-contour extrude, Mid Plane, Merge, edge fillet, all-edge fillet, Extrude Cut Blind, Feature Mirror of an extrude-cut (once a plane exists).

Frame-grab list from this pass is **done**. Remaining uncertainty is the neck-fillet included angle (stated) and the handle-end chord/arc caps, not missing stills.

## Keep or swap

**Keep.** The ladder marked this rung conditional on a frame-grab to pin “60 / 55 / 50” and the 10 mm gap. That pass is done: 55 × 50 ellipse, 17°, open-end gap 25 (not 10), handle half-width 10, everything else as the ladder already had. The part is extractable enough to be the shop-tool graduation: two head types, 12-point from two hexes, mixed mid-plane thickness, recess mirrored about Front, several fillet sets.

It is a **large** rung (elliptical trim is new kernel surface, convert/offset arcs, origin-plane feature mirror, fillet-mirror). That is scope, not a reason to swap the video. If a single WP cannot land all of §4 rows 1–5, split the *implementation* (sketch + two extrudes first, dress later) rather than replace the part. Alternates are only for a different *shape* if this one is dropped; they are not needed now.
