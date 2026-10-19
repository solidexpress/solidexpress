# Rung 7 checklist — combination spanner (Mahtabalam)

Row list for `tools/walk_rung07.py`. How to build each row: [`rung-07-plan.md`](rung-07-plan.md). Numbers come from `check_rung07.py params` after WP1 (`VOLUME 38782`, bbox `281.4 × 54.6 × 10.0`, min `(−24.95, −27.30, −5.00)`). Until WP1’s OCCT replica, volume ± **1 %**; then 0.5 %. Bbox edges ± 0.2 mm.

**A** action (the video step, named tool). **L** look. **N** negative. Clauses are bridge reads or one checker line. Statuses are `[status-trace]` result lines since the row's mark.

**Frames are mandatory.** Every view, plane, dimension, click target and expected on-screen state cites a still in `docs/loop/rung-07-frames/` that was opened for this checklist. Where frames and narration disagree, follow the frames (notes in the row). Prep put the 55-axis along 17°; the stills put **50 along 17°** and **55 on the steep axis** — frames win.

Mutants (90° neck, swapped ellipse axes / Y 50.4, one-face recess, offset 3, hex across-corners, handle on −X, extruded lettering) are checker mutations, not walk rows.

## Chunk 1 — Front, ellipse, C (13)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| N1 | Window first: size ≥ 1272 × 750 or maximized; status bar, File menu, and the rail inside the window | Chrome inside the window | — | `window`; `chrome inside` |
| A1 | File → New. Status is the pinned sentence (`New — empty part, Top plane (XY)…`). `state.units` is `mmgs`. No second dialog. Empty part, no seed box | Empty shop. Origin planes exist as datums | [t0021.jpg](rung-07-frames/t0021.jpg) intro drawing only (not a sketch); [t0022.jpg](rung-07-frames/t0022.jpg) still that drawing while he says *select front plane* | `new`; `units mmgs`; `no dialog` |
| A2 | Click datum **Front** (not empty ground), Sketch. Session is the ground-sketch path. Origin `(0,0,0)`, normal `+Z`, `x = +X`, `y = +Y`. View Normal-To Front. Status `*Front` | 2D Front sheet. Origin on screen. Handle will run +X | [t0031.jpg](rung-07-frames/t0031.jpg) `*Front`, origin triad, Line Properties | `datum Front`; `sketch`; `ground status`; `normal`; `basis` |
| L1 | Rail labels Line, Centerline / construction, Ellipse, Arc (3-Point), Smart Dim, Trim, Mirror Entities, Polygon visible, none clipped. Plane names Front, Top, Right visible | Same rail density as rungs 4–6 | [t0031.jpg](rung-07-frames/t0031.jpg) Sketch tab; [t0042.jpg](rung-07-frames/t0042.jpg) Ellipse tool | `rail labels`; `plane names`; `not clipped` |
| A3 | Line + construction: horizontal through the origin, to **+X**. Infer-horizontal. Pointer heading 180° while dragging is the +X side | Dashed centerline on Y = 0, through the red origin, long to the right | [t0031.jpg](rung-07-frames/t0031.jpg) `194.07, 180°`, origin, `*Front` | `centerline`; `through origin`; `plus x`; `construction` |
| A4 | Ellipse, **three clicks**: centre at the origin, then major, then minor. Entity type Ellipse, not a 32-gon. Centre coincident with the origin. Axes still free | Full ellipse around the origin, under defined | [t0042.jpg](rung-07-frames/t0042.jpg) Ellipse PM, centre on the origin, `R = 39.46, r = 39.46` while dragging | `three click`; `ellipse entity`; `centre origin` |
| A5 | Construction line through the origin. Smart Dim / Angle chip **17.00°** to the horizontal CL. Small angle on the **left**. Construction toward +X is at **+17°**. Opening toward −X, slightly −Y | `17°` label on the −X side of the origin | [t0068.jpg](rung-07-frames/t0068.jpg) `17.00deg`, construction below the CL on the left | `construction`; `angle 17`; `left side` |
| A6 | Line for the first jaw, **Parallel** to the 17° construction. Endpoint **Coincident** to the **ellipse curve** (Ellipse1 + Point13), not to the centre | One jaw line, Parallel glyph, point sits on the ellipse, not at (0,0) | [t0078.jpg](rung-07-frames/t0078.jpg) Parallel5, Line3+Line4; [t0084.jpg](rung-07-frames/t0084.jpg) Selected Entities Ellipse1, Point13, Coincident6 | `parallel`; `coincident ellipse`; `not centre` |
| A7 | Smart Dim, in this order: steep ellipse axis **55** (he types 60 then replaces it); ellipse axis **along 17°** **50**; axis-to-jaw **12.50**; jaw length **20** (19.05 → 20). **55 is the steep chord**, not along 17°. **50 is along 17°** | Labels `55`, `50`, `12.50`, `20`, `17°`. 60 gone. Open-end gap is 25, not 10 | [t0096.jpg](rung-07-frames/t0096.jpg) `60.00mm` on the steep chord; [t0100.jpg](rung-07-frames/t0100.jpg) **55** on that same steep chord; [t0108.jpg](rung-07-frames/t0108.jpg) `50.00mm` along 17° at the bottom; [t0117.jpg](rung-07-frames/t0117.jpg) `12.50mm`; [t0123.jpg](rung-07-frames/t0123.jpg) `19.05` → 20, Existing Relations Parallel5 | `major 55 steep`; `minor 50 along 17`; `offset 12.5`; `length 20`; `60 gone` |
| A8 | Mirror Entities: select the jaw, axis = the **17° construction**. Copy appears. **Symmetric** on the corresponding endpoints | Both flanks, labels 20 / 12.50 / 55 / 50 | [t0135.jpg](rung-07-frames/t0135.jpg) Mirror Entities highlighted, both jaws, Fully Defined, Total Length 45mm | `mirror jaws`; `axis 17`; `symmetric`; `two jaws` |
| A9 | Arc variant `three_point` at the inner jaw ends. Smart Dim **R15**. Ends coincident with the inner jaw points | Throat arc `R15` / `15.00mm` | [t0147.jpg](rung-07-frames/t0147.jpg) `15.00mm`, R15 label on the inner arc | `variant three_point`; `radius 15`; `inner ends` |
| A10 | Trim (Power Trim) the **outer ellipse** on the opening side (between the jaws, −X). Remaining entity is an **elliptical arc**, the C. Not a polyline, not a 3-point arc stand-in | Opening gone. C. Full ellipse entity gone | [t0150.jpg](rung-07-frames/t0150.jpg) Trim Entities highlighted, full ellipse still there, Fully Defined, labels 20 / 12.50 / 55 / 50 / R15 / 17°; [t0156.jpg](rung-07-frames/t0156.jpg) C ready, opening on −X | `trimmed`; `elliptical arc`; `c opening`; `no full ellipse` |
| L2 | C reads as the lesson still: 17°, 20, 12.50, 55 (steep), 50 (along 17°), R15. No ring yet. Sketch on Front | Same as [t0156.jpg](rung-07-frames/t0156.jpg) | [t0156.jpg](rung-07-frames/t0156.jpg) | `c visible`; `labels`; `no ring` |

## Chunk 2 — 12-point, handle, finished sketch (11)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| A11 | Circle, centre on the CL (Y = 0), X still free. Smart Dim **Ø33** | `Ø33` / `33.00mm` on the +X side | [t0175.jpg](rung-07-frames/t0175.jpg) `33.00mm`, circle on the CL, C already open | `circle`; `diameter 33`; `on cl` |
| A12 | Polygon, **6** sides, **Inscribed circle** (across-flats). Centre concentric with Ø33. Smart Dim AF **25**. Point-up: the 25 dim is **horizontal**. Vertices **inside** Ø33 (wall ~2 mm), not on it | Hex inside Ø33, label `25`. Not across-corners | [t0181.jpg](rung-07-frames/t0181.jpg) Polygon PM: Number of Sides 6, **Inscribed circle** on; [t0192.jpg](rung-07-frames/t0192.jpg) `25.00mm`, 25 dim under the hex, point-up | `polygon 6`; `inscribed`; `af 25`; `inside ring` |
| A13 | Second hex, AF **25**, same centre, rotated ~**30°** relative (point-flat vs point-up) | Two hexes, both 25, 12-point star before trim | [t0208.jpg](rung-07-frames/t0208.jpg) Modify 25mm, second hex; [t0235.jpg](rung-07-frames/t0235.jpg) both 25 dims | `second hex`; `af 25`; `rotated 30` |
| A14 | Trim (Power Trim) the segments **inside** both hexes → 12-point box. Trim-away-inside is visible in the PM and **unused**. Power Trim is the path | 12-point inner, Ø33 outer, both 25 dims remain | [t0235.jpg](rung-07-frames/t0235.jpg) Trim PM: Power trim, Trim away inside unused; 12-point already, two 25 dims | `trimmed`; `12 point`; `ring remains` |
| A15 | Smart Dim origin → Ø33 centre **240.00** | Label `240` along the CL | [t0248.jpg](rung-07-frames/t0248.jpg) `240.00mm` | `dim 240`; `centres` |
| A16 | Line for the handle edge. **Horizontal** (Existing Relations `Horizontal1`). Narrator “make vertical” — the stills win. Smart Dim **10.00** from the CL (half-width; full width 20). Status Y = 10 | Horizontal line at y = +10. Label `10`. Not a 10 mm open-end gap | [t0264.jpg](rung-07-frames/t0264.jpg) Horizontal1, line across C to ring; [t0270.jpg](rung-07-frames/t0270.jpg) `10.00mm` | `horizontal`; `dim 10`; `y 10`; `not vertical` |
| A17 | Mirror Entities: handle line about the **CL**. **Symmetric** present (Symmetric3). Second 10 mm dim not required | Copy at y = −10. Symmetric glyph | [t0294.jpg](rung-07-frames/t0294.jpg) Existing Relations Coincident46, **Symmetric3**; labels 10, 12.50, 55, 50, R15 | `mirror handle`; `axis cl`; `symmetric`; `y minus 10` |
| A18 | Coincident: handle-line end to **Ø33** (Arc2 + Point59 at the left chord, status `X:226.87mm Y:−10.00mm` — **not** the ellipse; prep called t0285 ellipse, the still is the ring). Other end coincident to the **ellipse curve**. Trim leftovers so the strip stops at those hits | Ends on the curves. No overrun past the C or the ring | [t0285.jpg](rung-07-frames/t0285.jpg) Selected Arc2, Point59, status 226.87, −10.00; [t0290.jpg](rung-07-frames/t0290.jpg) coincident on the circle; [t0315.jpg](rung-07-frames/t0315.jpg) strip trimmed | `coincident ring`; `coincident ellipse`; `x 226.9`; `trimmed` |
| L3 | One Front sketch: C + 12-point ring + handle strip. Labels 17° / 20 / 12.50 / 55 / 50 / R15 / 240 / Ø33 / 25 / 10. May stay **Under Defined** — do not require Fully Defined | Same as the lesson still | [t0315.jpg](rung-07-frames/t0315.jpg) Under Defined, those labels, handle connected | `three regions`; `labels`; `front` |
| A19 | Exit Sketch. Sketch consumed. Three closed regions (C, ring, strip) | Iso / trimetric of the 2D sketch on Front, no solid yet | [t0315.jpg](rung-07-frames/t0315.jpg); [t0321.jpg](rung-07-frames/t0321.jpg) after exit | `exit`; `three regions` |
| A20 | Save As `sketch.sxp`. File exists. Title shows `sketch` | — | — | `saved`; `file exists`; `title` |

## Chunk 3 — two mid-plane extrudes, neck fillets (9)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| N2 | `extrude:Boss` with **no** selected contour, OK: refused, still no body, timeline unchanged | Refuse status | — (command armed at [t0332.jpg](rung-07-frames/t0332.jpg)) | `refused`; `no body`; `timeline unchanged` |
| A21 | Extruded Boss. Selected contours = both **heads** (`Region<1>` + `Region<2>`). Direction **Mid Plane** **10.00** (he starts Blind 10 in [t0332.jpg](rung-07-frames/t0332.jpg); the locked still is Mid Plane). Merge off. OK | Two 10 mm pads: C and 12-point ring, straddling Z = 0. Handle not solid | [t0332.jpg](rung-07-frames/t0332.jpg) Region\<1\>+\<2\>, Blind 10.00 then; [t0335.jpg](rung-07-frames/t0335.jpg) **Mid Plane 10.00mm**, both heads, trimetric | `contours heads`; `midplane`; `10`; `two pads`; `z pm 5` |
| A22 | Extruded Boss on the **same** Sketch1. Selected contour = **handle** region. Mid Plane **6.00**. **Merge result** on. OK. One body | Handle 6 mm thick, fused to both heads. Neck still sharp | [t0347.jpg](rung-07-frames/t0347.jpg) Mid Plane 6.00mm, Merge result checked, Region\<1\> | `contour handle`; `midplane`; `6`; `merge`; `one body` |
| A23 | Export `boss.3mf`. `check_rung07.py boss` PASS: bbox 281.4 × 54.6 × 10.0, min `(−24.95, −27.30, −5.00)`, volume `V_BOSS` 41705 within the band, handle on +X, open end on −X, one body | Spanner boss, no fillets, no recess | [t0347.jpg](rung-07-frames/t0347.jpg) after merge | `exported`; `boss`; `bbox`; `handle plus x`; `open minus x` |
| A24 | Fillet. Pick both **open-end neck** Z-edges (handle-to-C crotch, length 6). Radius **30**. OK | R30 blend both faces at the C neck | [t0366.jpg](rung-07-frames/t0366.jpg) Fillet1, status Length 6mm | `fillet 30`; `open neck`; `one body` |
| A25 | Fillet. Pick both **box-end neck** Z-edges (handle-to-ring crotch). Radius **20**. OK | R20 blend both faces at the ring neck | [t0380.jpg](rung-07-frames/t0380.jpg) Fillet2, status Length 6mm | `fillet 20`; `box neck`; `one body` |
| A26 | Export `neck.3mf`. `check_rung07.py neck` PASS: same bbox, volume `V_NECK` 42733 within the band | Neck fillets on; no recess yet | [t0380.jpg](rung-07-frames/t0380.jpg) | `exported`; `neck`; `bbox`; `volume` |
| L4 | Timeline: Sketch1, Boss-Extrude1 (heads 10), Boss-Extrude2 (handle 6), Fillet1 R30, Fillet2 R20. Names distinct. Handle on +X, C on −X | Clay + hairline edges | [t0380.jpg](rung-07-frames/t0380.jpg) tree Fillet2 selected | `order`; `names distinct`; `one body` |
| A27 | Save As `neck.sxp`. File exists. Title shows `neck` | — | — | `saved`; `file exists`; `title` |

## Chunk 4 — recess, mirror, 1 mm, save, evidence (13)

| Row | Does | Expected on-screen | Frame | Clauses |
|---|---|---|---|---|
| A28 | Select the **top face of the handle** (the 6 mm +Z face, cyan). Sketch. Convert Entities: the filleted outline — **two lines + R30 arc + R20 arc**. Convert of circular **arcs**, not pierce points, not full circles | Four converted entities on that face, closed racetrack | [t0385.jpg](rung-07-frames/t0385.jpg) handle face cyan, Sketch2, Fillet1+2 in the tree | `face selected`; `is handle top`; `sketch on face`; `convert arcs`; `four entities` |
| N3 | Offset distance **0**: refused, no new entities, sketch otherwise unchanged. Esc if a tool is armed | Refuse status | — (Offset armed at [t0400.jpg](rung-07-frames/t0400.jpg) / [t0415.jpg](rung-07-frames/t0415.jpg)) | `refused`; `no offset`; `timeline unchanged` |
| A29 | Offset Entities **5.00** inward (he tries 1 / 3; **5** sticks). Select chain / multi-select of the converted edges. Arcs stay arcs. Closed region. Status area ~**1895.51 mm²**, perimeter ~402.35. Exit. Extrude Cut, End **Blind**, Distance **1** (PM leftover 6.00 in [t0430.jpg](rung-07-frames/t0430.jpg) while he types — depth is **1**). OK. Recess on **one** face | Inward racetrack 5 mm from the outline. 1 mm pocket on +Z | [t0400.jpg](rung-07-frames/t0400.jpg) Select chain, Length 180.63; [t0415.jpg](rung-07-frames/t0415.jpg) `5.00mm`, yellow inward chain, Arcs on; [t0430.jpg](rung-07-frames/t0430.jpg) Area 1895.51 Perimeter 402.35, Region\<1\>; [t0438.jpg](rung-07-frames/t0438.jpg) Cut-Extrude1 | `offset 5`; `inward`; `arcs`; `area 1895`; `cut blind 1`; `one face` |
| A30 | Fillet. Both **recess-end** edges (Edge\<1\> + Edge\<2\>), radius **3.00**. Status Length 1 mm. OK | R3 at both pocket ends, still one face | [t0462.jpg](rung-07-frames/t0462.jpg) Radius 3mm, Edge\<1\>+\<2\>, Length 1mm; [t0471.jpg](rung-07-frames/t0471.jpg) Fillet3, Total Length 3mm | `fillet 3`; `both ends`; `one body` |
| A31 | Feature Mirror. Mirror Face/Plane = origin **Front Plane** (cyan datum rectangle through the part, not a body face). Features = **Fillet3 + Cut-Extrude1**. OK. Recess on **both** faces, R3 on the mirrored ends | Mirror1 in the tree. Pockets both Z sides | [t0483.jpg](rung-07-frames/t0483.jpg) Mirror Face/Plane = Front Plane, cyan Front Plane rectangle; [t0492.jpg](rung-07-frames/t0492.jpg) Mirror1, recess both faces | `plane front datum`; `features fillet3 cut`; `recess both`; `one body` |
| A32 | Fillet **1**: first the **C outer** ([t0498.jpg](rung-07-frames/t0498.jpg) Edge\<1\>, tangent-propagated, Arc Length 139.23), then the **12-point outer** as Edge\<2\> in the same feature ([t0500.jpg](rung-07-frames/t0500.jpg) both heads highlighted). Then Fillet **1** all remaining (Total Length 539.98). `_fillet_all` is allowed for the second set. Not R3 | 1 mm on both head outers and remaining edges | [t0498.jpg](rung-07-frames/t0498.jpg) Radius 1mm, Edge\<1\>, Tangent propagation; [t0500.jpg](rung-07-frames/t0500.jpg) Edge\<1\>+\<2\>, C and ring outers; [t0516.jpg](rung-07-frames/t0516.jpg) Fillet5, Total Length 539.98mm | `fillet 1 heads`; `fillet 1 remaining`; `one body` |
| A33 | Export `final.3mf`. `check_rung07.py final`: `bbox` PASS. Min `(−24.95, −27.30, −5.00)`, size `281.4 × 54.6 × 10.0`, each edge within 0.2. Handle +X, open end −X | Finished spanner, recess both faces, 1 mm edges | [t0516.jpg](rung-07-frames/t0516.jpg); [t0492.jpg](rung-07-frames/t0492.jpg) form | `exported`; `bbox`; `handle plus x`; `open minus x` |
| A34 | Same file: `volume` PASS, `38782` within the band (`params` after WP1; 1 % until the OCCT replica, then 0.5 %) | — | — | `volume` |
| A35 | Same file: `inside` PASS at `(0, 18, 0)`, `(120, 0, 0)`, `(240, 15, 0)`; `outside` PASS at `(−30, 0, 0)`, `(240, 0, 0)`, `(270, 0, 0)`, `(0, 0, 8)`, `(120, 0, 4)`, `(120, 0, 2.5)`, `(120, 0, −2.5)`; `recessBoth` PASS; `watertight` PASS (one closed solid) | Recess empty on both faces; 12-point bore empty | [t0492.jpg](rung-07-frames/t0492.jpg) both-face recess; [t0516.jpg](rung-07-frames/t0516.jpg) 12-point | `inside`; `outside`; `recess both`; `watertight` |
| L5 | Timeline order `Sketch1, Boss-Extrude1, Boss-Extrude2, Fillet1, Fillet2, Sketch2, Cut-Extrude1, Fillet3, Mirror1, Fillet4, Fillet5`. Names distinct. No material feature. No extruded “CAD CAM TUTORIAL” | — | [t0516.jpg](rung-07-frames/t0516.jpg) tree through Fillet5 | `order`; `names distinct`; `no material`; `no lettering` |
| A36 | Save As `final.sxp`. File exists. Title shows `final` | — | — | `saved`; `file exists`; `title` |
| N4 | File → New, File → Open `final.sxp`. One body, no status error. Re-export: `bbox` and `volume` PASS again | — | — | `reopened`; `one body`; `no error`; `bbox`; `volume` |
| A37 | Headless evidence, needs `--a15` (without it: `BLOCKED-by-flag`). Kernel, godot suites `0 failed`, lint, `test_check_rung07.py`, registry. Engine noise only as rung 1 R9 allows | — | — | `kernel`; `godot`; `lint`; `unit`; `registry`; `errors` |

Total: 13 + 11 + 9 + 13 = **46** (37 A, 5 L, 4 N).

Pass bar: `PASS 46`, no `FAIL`, `PARTIAL`, `BLOCKED`, or `runner-gap`. Every `check-*.txt` has no `FAIL`. The walk's `[ERROR]` list is empty apart from rung 1 R9 engine noise and the refusals in N2 and N3.

Material / Cast Stainless Steel ([t0523.jpg](rung-07-frames/t0523.jpg)–[t0540.jpg](rung-07-frames/t0540.jpg)) is viewing only — not a row.

## `check_rung07.py` spec

CLI like `check_rung06.py`: `params` | `boss` | `neck` | `mirror` | `final` plus optional probe names. Exit 0 iff every named probe PASSes. `params` prints `PART` / `VOLUMES` as JSON; the walk reads those, not this file, after WP1.

| Stage | Bbox min | Size | Volume |
|---|---|---|---|
| `boss` | `(−24.95, −27.30, −5.00)` | 281.4 × 54.6 × 10.0 | 41705 |
| `neck` | same | same | 42733 |
| `mirror` | same | same | 38957 |
| `final` | same | same | **38782** |

Probes: `bbox` (edges ± 0.2 mm), `volume` (1 % until WP1 OCCT replica, then 0.5 %), `watertight` (one closed component), `inside` / `outside` (points above), `handleSide` (`boss` onward: X max ≥ 250), `openEnd` (`xmin ≤ −24.5`), `recessBoth` (`mirror`/`final`: `(120, 0, 2.5)` and `(120, 0, −2.5)` outside).

`PART` millimetres (locked from frames): ellipse 55 × 50 (55 steep, 50 along 17°), 17°, jaw 12.50 / 20, R15, Ø33, AF 25, centre 240, handle half 10, head T 10, handle T 6, R30 / R20, offset 5, cut 1, R3, R1. Void angles (resolved, not 90°): ellipse junction 112.42°, circle junction 127.31°. Recess area 1895.51 from [t0430.jpg](rung-07-frames/t0430.jpg).

Mutations that must fail: Y 50.4 as `final` (`bbox`); 90°-neck volume 41102 as `final` (`volume`); one-face recess (`recessBoth`); handle on −X (`handleSide`); two bodies (`watertight`); hex across-corners (`bbox` or `inside` at `(240, 15, 0)`).
