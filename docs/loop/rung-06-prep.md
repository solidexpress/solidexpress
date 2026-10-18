# Rung 6 prep — candlestick, Revolve & Sweep (Fully Defined)

Analysis only, against `main` `a7f4227` (includes rung 5 #270). Video: [SolidWorks Tutorials – Revolve & Sweep](https://www.youtube.com/watch?v=m7GuVfPN164) (Fully Defined, 15:56, 2024-06-27; oEmbed author *Fully Defined*). It narrates the SOLIDWORKS built-in *Basic Techniques → Revolves and Sweeps* candlestick. Official help [t_tut_revolve_createsweep.htm](https://help.solidworks.com/2025/English/swconntutorial/t_tut_revolve_createsweep.htm) is JS-rendered and was not readable. Transcript: `sx-loop/sources/subs/m7GuVfPN164.txt`.

**Frames (this pass).** 412 JPEGs in [`docs/loop/rung-06-frames/`](rung-06-frames/) plus [`index.md`](rung-06-frames/index.md). `tSSSS.jpg` is the frame at SSSS seconds. Every *as shown* value, plane, view and click target below is taken from those stills; the file is cited at the point of use (e.g. `docs/loop/rung-06-frames/t0350.jpg`). Spoken numbers that the stills contradict are called out.

**Axis map** (same as rungs 3–5). Front = XY (normal +Z). Right = YZ (normal +X). Sketch Y on Front/Right is world +Y (up). Revolve axis = world +Y.

**Units.** MMGS. Millimetre values on the stills.

## Locked values (from frames)

| Item | Locked value | Frame |
|---|---|---|
| First-sketch plane / view | **Front**, sketch opens Normal-To (2D) | [docs/loop/rung-06-frames/t0052.jpg](rung-06-frames/t0052.jpg) tutorial step 3 *Select the Front plane* |
| First-sketch lines | Vertical from the origin; top horizontal; bottom horizontal. **No** extra 20 mm step | [docs/loop/rung-06-frames/t0052.jpg](rung-06-frames/t0052.jpg) lesson still; [docs/loop/rung-06-frames/t0081.jpg](rung-06-frames/t0081.jpg) after Smart Dim |
| First-sketch dims | Top radial **20.00**; height **220.00**; base radial **90.00** | [docs/loop/rung-06-frames/t0052.jpg](rung-06-frames/t0052.jpg), [docs/loop/rung-06-frames/t0081.jpg](rung-06-frames/t0081.jpg). Narrator “90, 220 and 20” ([docs/loop/rung-06-frames/t0075.jpg](rung-06-frames/t0075.jpg)) |
| Tangent-arc click (top) | Endpoint of the **top horizontal**, pointer **right then down** | [docs/loop/rung-06-frames/t0104.jpg](rung-06-frames/t0104.jpg) yellow coincident on that end; tutorial *right, then downward* |
| Top rim | **R10.00**, ~90° quarter (flat top after revolve, not a sphere) | [docs/loop/rung-06-frames/t0132.jpg](rung-06-frames/t0132.jpg), [docs/loop/rung-06-frames/t0137.jpg](rung-06-frames/t0137.jpg), [docs/loop/rung-06-frames/t0385.jpg](rung-06-frames/t0385.jpg) |
| ~150 mm vertical | Typed while dragging from the R10 end; **deleted** when Equal + 40 overdefine | [docs/loop/rung-06-frames/t0186.jpg](rung-06-frames/t0186.jpg) 150.00 on that line; [docs/loop/rung-06-frames/t0242.jpg](rung-06-frames/t0242.jpg) delete |
| 3-point arc | Centre and ends on that vertical; **R20.00**, ~180° | [docs/loop/rung-06-frames/t0186.jpg](rung-06-frames/t0186.jpg), [docs/loop/rung-06-frames/t0220.jpg](rung-06-frames/t0220.jpg) |
| Upper vertical | **40.00** (R10 end → R20 start) | [docs/loop/rung-06-frames/t0220.jpg](rung-06-frames/t0220.jpg), [docs/loop/rung-06-frames/t0288.jpg](rung-06-frames/t0288.jpg), [docs/loop/rung-06-frames/t0350.jpg](rung-06-frames/t0350.jpg) |
| Equal | The two verticals on each side of the R20 | [docs/loop/rung-06-frames/t0233.jpg](rung-06-frames/t0233.jpg) tutorial step 2. **Not** on the finished fully-defined sketch — see note below |
| Lower tangent arc | From the lower-vertical end, pointer **down**; ~90°, **R60** | [docs/loop/rung-06-frames/t0288.jpg](rung-06-frames/t0288.jpg); tutorial [docs/loop/rung-06-frames/t0343.jpg](rung-06-frames/t0343.jpg) step 4 |
| Connecting tangent arc | To the **endpoint of the bottom 90 horizontal**, then Tangent on the two arcs | [docs/loop/rung-06-frames/t0297.jpg](rung-06-frames/t0297.jpg), [docs/loop/rung-06-frames/t0343.jpg](rung-06-frames/t0343.jpg) step 5 |
| Image 7 (rest of the profile) | **20** top, **220** height, **R10**, **40** upper vertical, **R20**, **R60**, **R12.50** rim, **80** (bottom → R60 start), **90** base | Lesson still [docs/loop/rung-06-frames/t0343.jpg](rung-06-frames/t0343.jpg) step 7; viewport [docs/loop/rung-06-frames/t0350.jpg](rung-06-frames/t0350.jpg) fully defined |
| Revolve axis click | The **long vertical** of the profile (the 220 line). Blind, **360°** | [docs/loop/rung-06-frames/t0371.jpg](rung-06-frames/t0371.jpg) PropertyManager *Axis of Revolution* + tutorial step 3 |
| Revolve view after OK | Isometric, shaded | [docs/loop/rung-06-frames/t0385.jpg](rung-06-frames/t0385.jpg), [docs/loop/rung-06-frames/t0432.jpg](rung-06-frames/t0432.jpg) |
| Path plane / view | **Front** again, **Front** standard view, **Hidden Lines Removed**, **Temporary Axes** | [docs/loop/rung-06-frames/t0492.jpg](rung-06-frames/t0492.jpg) tutorial steps 1–4 |
| Path start click | Coincident to the **temporary axis** (revolve axis), then a **horizontal 60.00** to **+X** | [docs/loop/rung-06-frames/t0483.jpg](rung-06-frames/t0483.jpg), [docs/loop/rung-06-frames/t0519.jpg](rung-06-frames/t0519.jpg). Lesson still draws it at the upper stem; the 10 mm dim later drops it |
| Path R150 | Tangent arc from the 60 mm end, **R150.00**, foreshortened leader | [docs/loop/rung-06-frames/t0519.jpg](rung-06-frames/t0519.jpg), [docs/loop/rung-06-frames/t0555.jpg](rung-06-frames/t0555.jpg) |
| Path 65 | Vertical between the **R150 endpoints** → **65.00** (arc goes **up**) | [docs/loop/rung-06-frames/t0555.jpg](rung-06-frames/t0555.jpg), [docs/loop/rung-06-frames/t0570.jpg](rung-06-frames/t0570.jpg) |
| Path “20” | **R20.00 hook** (tangent-arc scroll), **not** a 20 mm line | [docs/loop/rung-06-frames/t0582.jpg](rung-06-frames/t0582.jpg), [docs/loop/rung-06-frames/t0670.jpg](rung-06-frames/t0670.jpg) |
| Path Horizontal | The **R20 hook’s two endpoints** (Ctrl+click), not the R150 pair | [docs/loop/rung-06-frames/t0584.jpg](rung-06-frames/t0584.jpg) |
| Path 10 | Distance from the **60 mm path line** to the **bottom edge of the revolve** → **10** | [docs/loop/rung-06-frames/t0666.jpg](rung-06-frames/t0666.jpg) placing it; [docs/loop/rung-06-frames/t0670.jpg](rung-06-frames/t0670.jpg) tutorial still shows **10** at the base. Path fully defined. |
| Handle side | **+X** (Front, same side as the profile) | [docs/loop/rung-06-frames/t0820.jpg](rung-06-frames/t0820.jpg), [docs/loop/rung-06-frames/t0010.jpg](rung-06-frames/t0010.jpg), [docs/loop/rung-06-frames/t0015.jpg](rung-06-frames/t0015.jpg) |
| Section plane / view | **Right** plane, **Normal To**, Ellipse tool | [docs/loop/rung-06-frames/t0683.jpg](rung-06-frames/t0683.jpg) tutorial steps 1–3 |
| Ellipse | Full axes **35.00 × 10.00**. Major is **horizontal in Right view** (world **Z**); minor is **vertical** (world **Y**). Horizontal on the two major-axis ends. Centre dragged coincident to the path start | Lesson still [docs/loop/rung-06-frames/t0683.jpg](rung-06-frames/t0683.jpg) step 6; viewport [docs/loop/rung-06-frames/t0715.jpg](rung-06-frames/t0715.jpg), [docs/loop/rung-06-frames/t0735.jpg](rung-06-frames/t0735.jpg) |
| Sweep | Profile = ellipse sketch; Path = path sketch; Follow path (default). **Shaded With Edges** | [docs/loop/rung-06-frames/t0765.jpg](rung-06-frames/t0765.jpg), [docs/loop/rung-06-frames/t0813.jpg](rung-06-frames/t0813.jpg), [docs/loop/rung-06-frames/t0820.jpg](rung-06-frames/t0820.jpg) |
| Cut host / view | **Top face of the revolve** (the r=20 disc). Sketch **Normal To** that face (Top view) | [docs/loop/rung-06-frames/t0828.jpg](rung-06-frames/t0828.jpg) click; [docs/loop/rung-06-frames/t0834.jpg](rung-06-frames/t0834.jpg) Ø30 on that face |
| Cut | Circle **Ø30**, Extruded Cut **Blind 25**, **Draft On**, **15° inward** (not outward) | [docs/loop/rung-06-frames/t0867.jpg](rung-06-frames/t0867.jpg), [docs/loop/rung-06-frames/t0878.jpg](rung-06-frames/t0878.jpg), [docs/loop/rung-06-frames/t0881.jpg](rung-06-frames/t0881.jpg) |
| Fillets | **None** | Finished solid [docs/loop/rung-06-frames/t0820.jpg](rung-06-frames/t0820.jpg) — only the sketched radii |

**Equal vs 80.** [docs/loop/rung-06-frames/t0233.jpg](rung-06-frames/t0233.jpg) applies Equal to the two verticals beside the R20 (with 40 already on the upper). That would make the lower vertical 40 and put the R60 start at y = 220 − 10 − 40 − 40 − 40 = 90. Image 7 / [docs/loop/rung-06-frames/t0350.jpg](rung-06-frames/t0350.jpg) then puts **80.00** from the bottom to that same junction, and the status bar says *Fully Defined* (black, not overdefined). R10 90° + R20 180° + Equal 40 + 80 cannot coexist. The finished sketch keeps **40** and **80**; the lower vertical is therefore **50** (220 − 10 − 40 − 40 − 80). Equal from step 9 is not in the finished set.

**Rim reconstruction.** R10 90° puts the stem at x = 30. R60 tangent to that vertical at y = 80 has centre (90, 80). R12.50 tangent to R60 and ending at (90, 0) then has centre ≈ (99.49, 8.13) (external). The outer bulge’s rightmost x ≈ **112.0**; a 4.4 mm circular-segment toe sits below y = 0. [docs/loop/rung-06-frames/t0350.jpg](rung-06-frames/t0350.jpg) and [docs/loop/rung-06-frames/t0820.jpg](rung-06-frames/t0820.jpg) read as a rim on the baseline. Checker volume below **clips y ≥ 0** so the part sits on the y = 0 disc; the unclipped toe is called out as the reconstruction residue.

The ~150 mm vertical is a sketching aid. Tutorial: *Do not dimension the line at this time.* He types 150, then deletes it.

## 1. Demands (video order)

Lesson: new part; revolve the candlestick; sweep a ribbon handle; extruded cut with draft. Mouse gestures are optional (Line / Smart Dim). Either Boss-Revolve-then-sketch or sketch-then-feature.

1. **New part, MMGS.** Empty part.
2. **Front plane, Sketch** ([docs/loop/rung-06-frames/t0052.jpg](rung-06-frames/t0052.jpg)). View is Normal-To Front.
3. **Lines, then dimension as shown: 20, 220, 90.** Line tool. Smart Dim. Vertical from the origin (this is the revolve axis). Top horizontal 20 to +X; bottom horizontal 90 to +X. Closed on the axis, profile does not cross it.
4. **Tangent Arc** from the endpoint of the top horizontal: pointer right, then down ([docs/loop/rung-06-frames/t0104.jpg](rung-06-frames/t0104.jpg)). **R10.**
5. **Vertical line ~150** from that arc’s end (typed 150 is later deleted). Coincident to the arc centre shows up automatically in SW ([docs/loop/rung-06-frames/t0157.jpg](rung-06-frames/t0157.jpg)).
6. **3 Point Arc.** Centre and both ends coincident with that vertical. Approx. length 40, angle 180°, radius 20. **R20.**
7. **Trim Entities → Trim to closest.** Remove the diameter span inside the 3-point arc. Esc.
8. **Upper vertical = 40** ([docs/loop/rung-06-frames/t0220.jpg](rung-06-frames/t0220.jpg)).
9. **Equal** on the two verticals either side of the R20 ([docs/loop/rung-06-frames/t0233.jpg](rung-06-frames/t0233.jpg)). Delete the 150 if it fights Equal ([docs/loop/rung-06-frames/t0242.jpg](rung-06-frames/t0242.jpg)).
10. **Tangent Arc** from the bottom of the lower vertical, drag down: **~90°, R~60** ([docs/loop/rung-06-frames/t0288.jpg](rung-06-frames/t0288.jpg)). (Narrator also shows 3-point + Tangent as the same result.)
11. **Another Tangent Arc** to the endpoint of the bottom horizontal, coincident, then **Tangent** on the two arcs ([docs/loop/rung-06-frames/t0297.jpg](rung-06-frames/t0297.jpg), [docs/loop/rung-06-frames/t0302.jpg](rung-06-frames/t0302.jpg)).
12. **View → Hide/Show → Sketch Relations** (optional; he leaves them on).
13. **Remaining dimensions as shown** (lesson image 7, [docs/loop/rung-06-frames/t0343.jpg](rung-06-frames/t0343.jpg)): R60, R12.50, 80, and the 20 / 220 / R10 / 40 / R20 / 90 already on the sketch. Fully defined ([docs/loop/rung-06-frames/t0350.jpg](rung-06-frames/t0350.jpg)).
14. **Exit Sketch** (optional if Revolve was not pre-armed). He does not exit: Features → Revolve uses the active sketch ([docs/loop/rung-06-frames/t0364.jpg](rung-06-frames/t0364.jpg)).
15. **Features → Revolved Boss/Base.** Axis = the long vertical ([docs/loop/rung-06-frames/t0371.jpg](rung-06-frames/t0371.jpg)). Direction Blind, **360°** default. OK. Save `Cstick`. View after: isometric shaded ([docs/loop/rung-06-frames/t0385.jpg](rung-06-frames/t0385.jpg)).
16. **Sweep path, Front plane, Sketch.** Standard view **Front**, **Hidden Lines Removed**. **View → Hide/Show → Temporary Axes** (the revolve axis) ([docs/loop/rung-06-frames/t0492.jpg](rung-06-frames/t0492.jpg)).
17. **Horizontal line** coincident to that temporary axis, **60**, to +X ([docs/loop/rung-06-frames/t0519.jpg](rung-06-frames/t0519.jpg)).
18. **Tangent Arc** from that end, **R150**, curving **up**. (Leaders → foreshorten: display only.)
19. **Vertical dimension 65** between that arc’s endpoints ([docs/loop/rung-06-frames/t0555.jpg](rung-06-frames/t0555.jpg)).
20. **Another tangent arc, R20**, a scroll hook ([docs/loop/rung-06-frames/t0582.jpg](rung-06-frames/t0582.jpg)).
21. **Horizontal** on the endpoints of the **R20** hook ([docs/loop/rung-06-frames/t0584.jpg](rung-06-frames/t0584.jpg)).
22. **Display/Delete Relations** (filter All; review only). A coincident path-to-revolve was added automatically in SW.
23. **Dimension 10** from the path’s 60 mm line to the **bottom edge of the revolve** ([docs/loop/rung-06-frames/t0666.jpg](rung-06-frames/t0666.jpg), [docs/loop/rung-06-frames/t0670.jpg](rung-06-frames/t0670.jpg)). Path sketch fully defined. Exit.
24. **Right plane, Sketch. Normal To.** **Ellipse**: centre, major, minor (three clicks). **Horizontal** on the two major-axis ends. **35.00** (major, world Z) and **10.00** (minor, world Y) ([docs/loop/rung-06-frames/t0683.jpg](rung-06-frames/t0683.jpg), [docs/loop/rung-06-frames/t0715.jpg](rung-06-frames/t0715.jpg)). **Coincident** ellipse centre to the path start (drag until coincident, [docs/loop/rung-06-frames/t0735.jpg](rung-06-frames/t0735.jpg)). Hide temporary axes.
25. **Swept Boss/Base.** Profile = ellipse sketch; Path = path sketch. Options **Follow path** (default). OK. Shaded With Edges ([docs/loop/rung-06-frames/t0820.jpg](rung-06-frames/t0820.jpg)). Save. The handle is a **flat ribbon** on +X, not a round tube.
26. **Top face of the revolve, Extruded Cut, Sketch.** Normal-To that face (Top, [docs/loop/rung-06-frames/t0834.jpg](rung-06-frames/t0834.jpg)). **Circle Ø30.** Exit. Cut **Blind 25**, **Draft On**, **15°**, inward (not outward) ([docs/loop/rung-06-frames/t0881.jpg](rung-06-frames/t0881.jpg)). OK.
27. **Viewing only:** Display Pane → transparency on the part to see the taper. Not geometry.

No fillet feature in this video.

UI along the way: origin-plane pick, Sketch, Line / Centerline, Arc flyout (Tangent / 3-Point), Smart Dim (length, radius, two-point vertical, line-to-edge), Trim to closest, Equal, Tangent, Horizontal (two points), relations visibility, Exit, Revolve (axis line, 360°), Temporary Axes, silhouette dim to a body edge, Ellipse, Swept Boss (profile then path), face sketch, Extrude Cut with draft.

## 2. Gap critique

Grep / read on `a7f4227`. HAVE = the named tool does this step. PARTIAL = pieces exist, the video step does not. MISSING = no such tool.

| # | Demand | Mark | What the code does |
|---|---|---|---|
| 1 | New, MMGS, empty | HAVE | `document_view.gd` `new_document`: `units = mmgs`, `OriginPlanes.seed`. No seed box. |
| 2 | Front + Sketch | HAVE | Origin Front quad (`origin_planes.gd` BASIS, `entry: ground`). Click starts XY. |
| 3 | Lines, centreline, dims 20 / 220 / 90 | HAVE | Line, Centerline (construction), Smart Dim `line_length`. Auto-close defaults **on** — uncheck for an open chain; the revolve profile must still close. |
| 4 | Tangent Arc, R10 | PARTIAL | Arc variant `tangent` (`sketch_mode.gd` `_click_arc`) drops a free arc; **no tangent constraint**. Radius dim exists. Infer-tangent is for **lines** to circles (`_infer_line`), not this tool. |
| 5 | Vertical ~150, coincident to arc centre | PARTIAL | Typed length while drawing. Coincident to an arc centre is not automatic. |
| 6 | 3 Point Arc, centre+ends on the line, R20 | PARTIAL | Variant `three_point` commits an arc, no coincident / point-on-line. `point_on_line` is in `constrain()` but **not** on the selection-chip row. |
| 7 | Trim to closest | PARTIAL | Power Trim (`trim_entity`) click/drag. No Trim-to-closest option in a property manager. |
| 8 | Upper vertical 40 | HAVE | Smart Dim line length. |
| 9 | Equal on two verticals | HAVE | `constrain("equal")`; solver `EqualLength` (`solver_planegcs.cpp`). |
| 10–11 | Tangent Arc R60 90°, second arc R12.50 + Tangent | PARTIAL | Same as 4. Two-entity **Tangent** chip works (`line-arc` / `arc-arc` in the solver). 3-point + Tangent is the workable path. |
| 12 | Hide sketch relations | PARTIAL | Glyphs exist; no Hide/Show Sketch Relations view toggle. |
| 13 | Rest of image-7 dims, fully defined | PARTIAL | Length / radius / two-point distance work. Line–line parallel distance exists (`smart_dim_table.gd`). Fully-Define command is not this video’s step. |
| 14 | Exit Sketch | HAVE | `exit_sketch`. |
| 15 | Revolve 360° about the centreline | HAVE | Finish-bar / rail Revolve. `finish_revolve`: selected **line** is the axis (forced construction), else sketch Y through the origin. Angle default τ. `apply_extrude_revolve` → `BRepPrimAPI_MakeRevol`. Property panel edits ° after. |
| 16 | Front sketch + Temporary Axes | MISSING | No temporary-axis overlay. Origin / Y-axis snap is `Vector2.ZERO` and H/V infer only. |
| 17 | Horizontal 60, coincident to the axis | PARTIAL | Line + length. Coincident to a temp axis: snap to origin if the axis is Y through 0, **not** to an arbitrary centreline. |
| 18 | Tangent Arc R150 | PARTIAL | Same as 4. |
| 19 | Vertical 65, two R150 ends | HAVE | Two-point Smart Dim. Two-point **Vertical** is `SketchVertical`. |
| 20 | Tangent-arc R20 hook | PARTIAL | Same as 4. |
| 21 | Horizontal on two R20 endpoints | MISSING | Chip is offered on an endpoint pick (`selection_actions`). `constrain("horizontal")` only adds line-horizontal. Two-point Horizontal is a **no-op** on arcs. Kernel already accepts two-point Horizontal. |
| 22 | Display/Delete Relations | MISSING | No relations property manager / filter. |
| 23 | Dim 10, path line to revolve bottom | PARTIAL | Convert of a circular edge is **face-sketch only** (`sketch_convert_edge.gd`: line or circle on the host face). Origin-plane Convert falls back to pierce **points**. Smart Dim point–line can use those. Silhouette-edge dim as in SW is not there. |
| 24 | Right plane, Ellipse 35×10, H, coincident to path | PARTIAL / MISSING | Right origin plane **HAVE** (`OriginPlanes.begin`). Ellipse tool is a **32-gon of lines** (`sketch_mode.gd` two clicks: centre + box corner). Rail label “Ellipse (approx)”. Kernel `SketchEntityType` is Point/Line/Circle/Arc/Spline — **no ellipse**. No major/minor, no 3-click, no Horizontal-on-axis-points. Inter-sketch coincident to the Front path end is **MISSING** (snap is current-sketch + origin + body-edge centres/pierces, not other sketches). |
| 25 | Swept Boss, profile then path, Follow path | PARTIAL | `sweep_boss.gd` + rail `sweep:Boss`: pick profile pad, path pad, OK. `MakePipeShell` `withCorrection=true` is Frenet-like. Path is `sketch_ordered_polyline`: arcs → chords (`samples = max(8, ceil(span/(π/12)))`). `BRepBuilderAPI_RightCorner`. No Follow-path checkbox (always on). Fuse onto the revolve is `op` new vs fuse: a new sweep body unless Result=fuse in the panel. |
| 26 | Face sketch Ø30, Cut Blind 25, draft 15° inward | PARTIAL / MISSING | Face sketch, circle, diameter, Extrude Cut Blind **HAVE**. Extrude schema has no draft (`property_panel.gd` `extrude`). Face **Draft** (`ops_panel.gd` `_draft`) pulls **+Z**, neutral **bbox min Z** — wrong axis for a hole along **Y**. Not a stand-in. |
| 27 | Transparency / display pane | MISSING | Viewing only. W cycles shaded / edges / wireframe. |

**Readiness.** A named-tool click-through of this video gets through New, Front, lines, Smart Dim, Trim, Equal, and **Revolve 360°** (axis = selected centreline, or Y at the origin). It **stops at Tangent Arc as a tangent-creating tool** if that button must do what the lesson says. A user who 3-point-arcs and clicks Tangent can continue until **the ellipse section**: there is no ellipse entity, so 35×10, orientation, and coincident-to-path cannot be placed as drawn. A 32-gon can still be swept; it will not be this ribbon. **Extrude-cut draft** is a separate miss at the end; a straight Ø30×25 cut is not this hole.

**Risks, largest first.**

- **No ellipse.** The official section is a 35×10 ellipse on Right, fully defined, pierced to the path. A 32-gon has no centre or axes, so the lesson’s relations have nothing to hold. Sweep of a polygon is not this ribbon.
- **Draft-on-cut.** Kernel extrude is a prism (`BRepPrimAPI_MakePrism`). 15° inward on Ø30 × 25 is a frustum. Face draft cannot be aimed along −Y from the UI.
- **Tangent Arc does not tangent.** The first new sketch skill this rung adds is auto-tangent arcs (R10, R60, R12.50, R150, R20 hook). Without it the profile and path will not fully define the way the stills show.
- **Sweep spine is faceted.** Same as rung 4: R150 / R20 → chords, right corners. Handle is a polygonal ribbon, not a circular sweep.
- **Temporary axes / inter-sketch coincident.** Path coincident to the revolve axis, ellipse centre coincident to the path, dim-to-bottom-edge: all SW model/sketch references. SX snap does not see another sketch’s endpoints.
- **Two-point Horizontal no-op.** Lesson uses it on the R20 hook ends ([docs/loop/rung-06-frames/t0584.jpg](rung-06-frames/t0584.jpg)). Chip lies.
- **Sweep Result=new.** Default new body; the handle must **fuse**. Easy to miss; not a missing feature.
- **Auto-close** on the open path sketch. Footgun, not a missing tool.

## 3. Checker numbers

Locked solid from the stills. Axis: Front XY, revolve about +Y through the origin. Profile in x ≥ 0. Handle in Front toward +X. Cut down −Y from y = 220. y ≥ 0 clip on the R12.50 rim (see Locked values).

**Revolve profile** (x = radius, y = height), closed on the axis:

- (0, 220) → (20, 220)
- R10, centre (20, 210), 90° to (30, 210)
- (30, 210) → (30, 170)  *(upper vertical 40)*
- R20 semicircle, centre (30, 150), through (50, 150), to (30, 130)
- (30, 130) → (30, 80)  *(lower vertical 50, from the 80 dim)*
- R60, centre (90, 80), CCW from (30, 80) to the R12.50 tangent ≈ (97.85, 20.52)
- R12.50, centre ≈ (99.49, 8.13), outer bulge (rightmost x ≈ 111.99), clipped at y = 0, to (90, 0)
- (90, 0) → (0, 0) → (0, 220)

Pappus: \(V = 2\pi A \bar{x}\). Shoelace on the contour with arcs sampled at 24–48 segments (throwaway Python, not committed):

\[
A = 9587.799\ \mathrm{mm}^2,\quad \bar{x} = 28.062\ \mathrm{mm}
\]

\[
V_\mathrm{rev} = 2\pi A \bar{x} = 1\,690\,536\ \mathrm{mm}^3
\]

Unclipped tangent-chain (4.4 mm toe below y = 0): \(A = 9645.415\), \(\bar{x} = 28.488\), \(V_\mathrm{rev} = 1\,726\,501\). Difference ≈ 2.1 %.

**Cut.** Ø30 at y = 220, Blind 25, 15° inward ([docs/loop/rung-06-frames/t0881.jpg](rung-06-frames/t0881.jpg)). \(R_1 = 15\), \(R_2 = 15 - 25\tan 15° = 8.301270\). Frustum:

\[
V_\mathrm{cut} = \frac{\pi h}{3}(R_1^2 + R_1 R_2 + R_2^2) = 10954.475\ \mathrm{mm}^3
\]

Fits in the top: at y = 195 the solid is still the r = 30 stem (below the R10).

**Handle** (ellipse 35×10 full axes, semi 17.5×5; path as locked). Area \(A_e = \pi\cdot 17.5\cdot 5 = 274.889357\). Path, after the 10 mm dim:

- (0, 10) → (60, 10)
- R150, centre (60, 160), CCW from (60, 10) to (183.592, 75) (ΔY 65, tangent +X at the start); arc 55.482°, length 145.251
- R20 hook, internal tangent, centre ≈ (167.113, 86.333), CCW 249.036° to (150.634, 75) (Horizontal on the hook ends); length 86.930

Centreline length 60 + 145.251 + 86.930 = 292.181 mm. Gross \(A_e L = 80318\). Path centre inside the revolve: 108.659 mm. Net add \(A_e L_\mathrm{out} = 50448\) (section centroid on the path, follow-path, centre-outside test, no self-intersection credit on the scroll).

\[
V = V_\mathrm{rev} + V_\mathrm{handle} - V_\mathrm{cut} = 1\,730\,030\ \mathrm{mm}^3
\]

| | min | max | size |
|---|---:|---:|---:|
| X | −112.0 | 192.1 | 304.1 |
| Y | 0 | 220 | 220 |
| Z | −112.0 | 112.0 | 224.0 |

X max is the R20 hook’s rightmost (~187.1) plus the 5 mm in-plane semi-minor. Z is the revolved rim (r ≈ 112), which dominates the ribbon’s ±17.5 mm in Z. Handle Y stays below 220 (hook top ≈ 106, plus 5 mm).

**Tolerance.** Pappus sampling error ≪ 0.1 %. The **rim clip** (2.1 % of \(V_\mathrm{rev}\)) and the **handle fuse** (centre-outside vs a true boolean) dominate. Treat \(V = 1.730\times 10^6\) mm³ as a **±2 %** band until an OCCT replica of this locked profile; then a 0.5 % band like rung 5.

**Mutants, not targets.** Top radial 10 (would not admit Ø30). Ellipse 12×6 (the pre-frame guess; [docs/loop/rung-06-frames/t0715.jpg](rung-06-frames/t0715.jpg) is 35×10). Path starting at the outer rim rather than the axis. Path “20” as a straight line instead of the R20 hook. Handle on −X. Body-sweep without fuse (second body). Straight cut, no draft (\(V_\mathrm{cut} = \pi 15^2 25 = 17671\)). Equal kept so the R60 starts at y = 90.

Inside (final, locked): `(0, 100, 0)` (axis, in the stem), `(40, 10, 0)` (base), `(0, 210, 0)` (in the top cylinder, below the hole). Outside: `(113, 10, 0)` (past the rim), `(0, 221, 0)`, `(0, 205, 0)` (in the frustum), `(193, 86, 0)` (past the scroll).

## 4. Ranked gaps

Most blocking for *this* video’s named tools first. Size is a gut order-of-magnitude (S < 1 WP, M ~1–2, L several).

| # | Gap | Size | Subsystem |
|---|---|---|---|
| 1 | Real ellipse (3-click, 35×10 major/minor, orientation, coincident to a path end) | L | kernel (`SketchEntityType`), sketch solver, UI (`sketch_mode.gd`) |
| 2 | Extrude Cut draft angle (inward 15°), not face-draft +Z | M | kernel (`apply_extrude_revolve` / prism), feature params, UI finish/property |
| 3 | Tangent Arc actually adds Tangent; 3-point centre/ends on a line | M | sketch UI + infer; solver Tangent/point-on-line already exist |
| 4 | Sweep path as circular edges, not chords | M | kernel (`sketch_ordered_polyline`, `MakePipeShell` corners) |
| 5 | Inter-sketch coincident / temp axis / dim to a body silhouette | M | UI snap + Convert; kernel pierce is body-edge only |
| 6 | Two-point Horizontal on arc ends (chip is a no-op) | S | UI (`constrain`); kernel Horizontal two-point exists |
| 7 | Sweep default fuse onto the revolve; Follow-path chrome | S | UI (`SweepBoss` / Result) |
| 8 | Trim-to-closest option (Power Trim is close) | S | UI |
| 9 | Display/Delete Relations, Hide relations, Display Pane transparency | S | UI / tests not needed for the solid |
| 10 | Checker + walk + `check_rung06.py` | M | tests |

Already in the product, no package: New MMGS, Front/Right origin planes, Line/Centerline, Smart Dim length/radius/two-point, Equal, Tangent chip, Trim, Exit, Revolve 360° about a selected line, Swept Boss profile+path chrome, face sketch, circle Ø, Extrude Cut Blind.

Frame-grab list from the first pass is **done**. Remaining uncertainty is the R12.50/y=0 clip (stated) and the handle boolean, not missing stills.
