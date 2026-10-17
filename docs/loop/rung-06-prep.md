# Rung 6 prep — candlestick, Revolve & Sweep (Fully Defined)

Analysis only, against `main` `a7f4227` (includes rung 5 #270). Video: [SolidWorks Tutorials – Revolve & Sweep](https://www.youtube.com/watch?v=m7GuVfPN164) (Fully Defined, 15:56, 2024-06-27; oEmbed author *Fully Defined*). It narrates the SOLIDWORKS built-in *Basic Techniques → Revolves and Sweeps* candlestick. Official help [t_tut_revolve_createsweep.htm](https://help.solidworks.com/2025/English/swconntutorial/t_tut_revolve_createsweep.htm) is JS-rendered and was not readable. Transcript: `sx-loop/sources/subs/m7GuVfPN164.txt` (not in this worktree; full auto-captions were supplied with the ladder entry). **No lesson frames were opened.** A YouTube title-card JPEG was fetched (`maxresdefault.jpg`); it shows a revolved body **with no handle** and is not a tutorial still.

**Do not promote to Current** until a frame-grab pass fills every *as shown* value below.

**Axis map** (same as rungs 3–5). Front = XY (normal +Z). Right = YZ (normal +X). Sketch Y on Front/Right is world +Y (up). Revolve axis = world +Y.

**Units.** MMGS. Spoken millimetre values.

## Assumptions (reasoned; replace on frame grab)

Spoken values are used as-is. *As shown* values are guessed from the construction sequence plus the Ø30 top cut (the top face must be wider than the hole).

| Item | Reasoned value | Why |
|---|---|---|
| Top / stem radial from centreline | **20** | First spoken 20. A Ø30 cut needs r ≥ 15 on the top face. Title-card “20.00” across the knob is a **different** body (no handle) and would not admit Ø30. |
| Second spoken 20 | **unused in the solid** | Could be a second radial, a short height, or a diameter-style dim to the centreline. Frame grab. |
| Base radial | **90** | Spoken 90 on the first line sketch; title-card 90 from the axis onto the base. Matches the R60 90° ending at x = 20+10+60 = 90. |
| 3-point arc | **R20, 180°** | Narrator types 20; tutorial approx. 40 / 180° / 20 (diameter 40). |
| Upper then lower stem verticals | **40** and **Equal** | Spoken 40; Equal copies it. Typed 150 is deleted. |
| Top tangent arc | **R10, 90°** | Spoken R10; “right then down”. |
| Lower tangent arc | **R60, 90°** | Spoken. |
| Overall height | **230** | 10+40+40+40+60+40 from that stack. Title-card 230 agrees. Not spoken. |
| Base outer vertical | **40** | Remainder after the R60 lands at y = 40. Title-card 80 and 2.50 are unused. |
| Connecting tangent arc (R60 → bottom horizontal) | **none; a vertical at x = 90** | The R60 already ends at (90, 40). A further arc is *as shown* in the lesson stills; the reasoned solid uses a straight drop so the stack closes. Frame grab. |
| Path offset from revolve bottom | **10** | Spoken. Path horizontal at y = 10. |
| Path | line **60**, R**150**, ΔY **65** on that arc’s ends, then **20** | Spoken. Horizontal relation is on a later tangent-arc pair (not the R150 ends — ΔY 65 and Horizontal on the same pair would conflict). |
| Ellipse (official section) | **12 × 6** full axes (semi 6 × 3) | *As shown*; never spoken. Common SW ellipse demo pair. Frame grab. |
| Handle side | **+X** (Front, same side as the profile) | *As shown*. |
| Fillets | **none** | This video never fillets. Older Getting Started text did; ignore until a frame shows them. |
| Draft | **15° inward** on the Ø30 cut, not outward | Spoken. Depth **25**, Blind. |

The ~150 mm vertical is a sketching aid. Tutorial: *Do not dimension the line at this time.* He types 150, then deletes it when Equal + 40 overdefines.

## 1. Demands (video order)

Lesson: new part; revolve the candlestick; sweep the handle; extruded cut with draft. Mouse gestures are optional (Line / Smart Dim). Either Boss-Revolve-then-sketch or sketch-then-feature.

1. **New part, MMGS.** Empty part.
2. **Front plane, Sketch.** Profile on Front.
3. **Lines, then dimension as shown: 90, 20, 20.** Line tool. Smart Dim. Vertical centreline (construction) as the axis. Profile to the +X side of it, closed, not crossing the axis.
4. **Tangent Arc** from the endpoint of the top horizontal: pointer right, then down. **R10.**
5. **Vertical line ~150** from that arc’s end (typed 150 is later deleted). Coincident to the arc centre shows up automatically in SW.
6. **3 Point Arc.** Centre and both ends coincident with that vertical. Approx. length 40, angle 180°, radius 20. **R20.**
7. **Trim Entities → Trim to closest.** Remove the diameter span inside the 3-point arc. Esc.
8. **Upper vertical = 40.**
9. **Equal** on the two verticals either side of that lower arc. Delete the 150 if it fights Equal.
10. **Tangent Arc** from the bottom of the lower vertical, drag down: **~90° , R~60.** (Narrator also shows 3-point + Tangent as the same result.)
11. **Another Tangent Arc** to the endpoint of the bottom horizontal, coincident, then **Tangent** on the two arcs.
12. **View → Hide/Show → Sketch Relations** (optional; he leaves them on).
13. **Remaining dimensions as shown** (lesson image 7) until fully defined. Spoken leftovers are only the path/cut numbers below; the rest of the profile is this still.
14. **Exit Sketch** (optional if Revolve was not pre-armed).
15. **Features → Revolved Boss/Base.** Axis = the long vertical (centreline). Direction Blind, **360°** default. OK. Save `Cstick`.
16. **Sweep path, Front plane, Sketch.** Hidden Lines Removed. **View → Hide/Show → Temporary Axes** (the revolve axis).
17. **Horizontal line** coincident to that temporary axis, **60**.
18. **Tangent Arc** from that end, **R150.** (Leaders → foreshorten: display only.)
19. **Vertical dimension 65** between that arc’s endpoints.
20. **Another tangent / line, 20.**
21. **Horizontal** on the endpoints of the (second) tangent arc.
22. **Display/Delete Relations** (filter All; review only). A coincident path-to-revolve was added automatically in SW.
23. **Dimension 10** from the path’s horizontal to the **bottom edge of the revolve.** Path sketch fully defined. Exit.
24. **Right plane, Sketch.** **Ellipse**: centre, major, minor (three clicks). **Horizontal** on centre + one major-axis end (stops the ellipse rotating). **Dimension major and minor** (*as shown*). **Coincident** ellipse centre to the path endpoint (drag until coincident). Hide temporary axes.
25. **Swept Boss/Base.** Profile = ellipse sketch; Path = path sketch. Options **Follow path** (default). OK. Shaded With Edges. Save.
26. **Top face of the revolve, Extruded Cut, Sketch.** **Circle Ø30.** Exit. Cut **Blind 25**, **Draft On**, **15°**, inward (not outward). OK.
27. **Viewing only:** Display Pane → transparency on the part to see the taper. Not geometry.

No fillet feature in this video.

UI along the way: origin-plane pick, Sketch, Line / Centerline, Arc flyout (Tangent / 3-Point), Smart Dim (length, radius, two-point vertical, line-to-edge), Trim to closest, Equal, Tangent, Horizontal (two points), relations visibility, Exit, Revolve (axis line, 360°), Temporary Axes, Convert/silhouette dim to a body edge, Ellipse, Swept Boss (profile then path), face sketch, Extrude Cut with draft.

## 2. Gap critique

Grep / read on `a7f4227`. HAVE = the named tool does this step. PARTIAL = pieces exist, the video step does not. MISSING = no such tool.

| # | Demand | Mark | What the code does |
|---|---|---|---|
| 1 | New, MMGS, empty | HAVE | `document_view.gd` `new_document`: `units = mmgs`, `OriginPlanes.seed`. No seed box. |
| 2 | Front + Sketch | HAVE | Origin Front quad (`origin_planes.gd` BASIS, `entry: ground`). Click starts XY. |
| 3 | Lines, centreline, dims 90 / 20 / 20 | HAVE | Line, Centerline (construction), Smart Dim `line_length`. Auto-close defaults **on** — uncheck for an open chain; the revolve profile must still close. |
| 4 | Tangent Arc, R10 | PARTIAL | Arc variant `tangent` (`sketch_mode.gd` `_click_arc`) drops a free arc; **no tangent constraint**. Radius dim exists. Infer-tangent is for **lines** to circles (`_infer_line`), not this tool. |
| 5 | Vertical ~150, coincident to arc centre | PARTIAL | Typed length while drawing. Coincident to an arc centre is not automatic. |
| 6 | 3 Point Arc, centre+ends on the line, R20 | PARTIAL | Variant `three_point` commits an arc, no coincident / point-on-line. `point_on_line` is in `constrain()` but **not** on the selection-chip row. |
| 7 | Trim to closest | PARTIAL | Power Trim (`trim_entity`) click/drag. No Trim-to-closest option in a property manager. |
| 8 | Upper vertical 40 | HAVE | Smart Dim line length. |
| 9 | Equal on two verticals | HAVE | `constrain("equal")`; solver `EqualLength` (`solver_planegcs.cpp`). |
| 10–11 | Tangent Arc R60 90°, second arc + Tangent | PARTIAL | Same as 4. Two-entity **Tangent** chip works (`line-arc` / `arc-arc` in the solver). 3-point + Tangent is the workable path. |
| 12 | Hide sketch relations | PARTIAL | Glyphs exist; no Hide/Show Sketch Relations view toggle. |
| 13 | Rest of image-7 dims, fully defined | PARTIAL | Length / radius / two-point distance work. Line–line parallel distance exists (`smart_dim_table.gd`). Fully-Define command is not this video’s step. |
| 14 | Exit Sketch | HAVE | `exit_sketch`. |
| 15 | Revolve 360° about the centreline | HAVE | Finish-bar / rail Revolve. `finish_revolve`: selected **line** is the axis (forced construction), else sketch Y through the origin. Angle default τ. `apply_extrude_revolve` → `BRepPrimAPI_MakeRevol`. Property panel edits ° after. |
| 16 | Front sketch + Temporary Axes | MISSING | No temporary-axis overlay. Origin / Y-axis snap is `Vector2.ZERO` and H/V infer only. |
| 17 | Horizontal 60, coincident to the axis | PARTIAL | Line + length. Coincident to a temp axis: snap to origin if the axis is Y through 0, **not** to an arbitrary centreline. |
| 18 | Tangent Arc R150 | PARTIAL | Same as 4. |
| 19 | Vertical 65, two arc ends | HAVE | Two-point Smart Dim. Two-point **Vertical** is `SketchVertical`. |
| 20 | Line / tangent 20 | HAVE / PARTIAL | Line HAVE. Auto-tangent PARTIAL. |
| 21 | Horizontal on two arc endpoints | MISSING | Chip is offered on an endpoint pick (`selection_actions`). `constrain("horizontal")` only adds line-horizontal. Two-point Horizontal is a **no-op** on arcs. Kernel already accepts two-point Horizontal. |
| 22 | Display/Delete Relations | MISSING | No relations property manager / filter. |
| 23 | Dim 10, path line to revolve bottom | PARTIAL | Convert of a circular edge is **face-sketch only** (`sketch_convert_edge.gd`: line or circle on the host face). Origin-plane Convert falls back to pierce **points**. Smart Dim point–line can use those. Silhouette-edge dim as in SW is not there. |
| 24 | Right plane, Ellipse, H, major/minor, coincident to path | PARTIAL / MISSING | Right origin plane **HAVE** (`OriginPlanes.begin`). Ellipse tool is a **32-gon of lines** (`sketch_mode.gd` two clicks: centre + box corner). Rail label “Ellipse (approx)”. Kernel `SketchEntityType` is Point/Line/Circle/Arc/Spline — **no ellipse**. No major/minor, no 3-click, no Horizontal-on-axis-points. Inter-sketch coincident to the Front path end is **MISSING** (snap is current-sketch + origin + body-edge centres/pierces, not other sketches). |
| 25 | Swept Boss, profile then path, Follow path | PARTIAL | `sweep_boss.gd` + rail `sweep:Boss`: pick profile pad, path pad, OK. `MakePipeShell` `withCorrection=true` is Frenet-like. Path is `sketch_ordered_polyline`: arcs → chords (`samples = max(8, ceil(span/(π/12)))`). `BRepBuilderAPI_RightCorner`. No Follow-path checkbox (always on). Fuse onto the revolve is `op` new vs fuse: a new sweep body unless Result=fuse in the panel. |
| 26 | Face sketch Ø30, Cut Blind 25, draft 15° inward | PARTIAL / MISSING | Face sketch, circle, diameter, Extrude Cut Blind **HAVE**. Extrude schema has no draft (`property_panel.gd` `extrude`). Face **Draft** (`ops_panel.gd` `_draft`) pulls **+Z**, neutral **bbox min Z** — wrong axis for a hole along **Y**. Not a stand-in. |
| 27 | Transparency / display pane | MISSING | Viewing only. W cycles shaded / edges / wireframe. |

**Readiness.** A named-tool click-through of this video gets through New, Front, lines, Smart Dim, Trim, Equal, and **Revolve 360°** (axis = selected centreline, or Y at the origin). It **stops at Tangent Arc as a tangent-creating tool** if that button must do what the lesson says. A user who 3-point-arcs and clicks Tangent can continue until **the ellipse section**: there is no ellipse entity, so major/minor, orientation, and coincident-to-path cannot be placed as drawn. A 32-gon can still be swept. **Extrude-cut draft** is a separate miss at the end; a straight Ø30×25 cut is not this hole.

**Risks, largest first.**

- **No ellipse.** The official section is an ellipse on Right, fully defined, pierced to the path. A 32-gon has no centre or axes, so the lesson’s relations have nothing to hold. Sweep of a polygon is not the part.
- **Draft-on-cut.** Kernel extrude is a prism (`BRepPrimAPI_MakePrism`). 15° inward on Ø30 × 25 is a frustum. Face draft cannot be aimed along −Y from the UI.
- **Tangent Arc does not tangent.** The first new sketch skill this rung adds is auto-tangent arcs. Without it the profile will not fully define the way the stills show.
- **Sweep spine is faceted.** Same as rung 4: R150 → ~8–15 chords, right corners. Handle is a polygonal tube, not a circular sweep.
- **Temporary axes / inter-sketch coincident.** Path coincident to the revolve axis, ellipse centre coincident to the path, dim-to-bottom-edge: all SW model/sketch references. SX snap does not see another sketch’s endpoints.
- **Two-point Horizontal no-op.** Lesson uses it on arc ends. Chip lies.
- **Sweep Result=new.** Default new body; the handle must **fuse**. Easy to miss; not a missing feature.
- **Auto-close** on the open path sketch. Footgun, not a missing tool.

## 3. Checker numbers

Reasoned solid, not the official Cstick, until image 7 and the ellipse stills are grabbed. Axis: Front XY, revolve about +Y through the origin. Profile in x ≥ 0. Handle in Front toward +X. Cut down −Y from y = 230.

**Revolve profile** (x = radius, y = height), closed on the axis:

- (0,0) → (90,0) → (90,40)
- R60, centre (90, 100), 90° from (90,40) to (30,100)
- (30,100) → (30,140)
- R20 semicircle, centre (30, 160), through (50, 160), to (30,180)
- (30,180) → (30,220)
- R10, centre (20, 220), 90° to (20,230)
- (20,230) → (0,230) → (0,0)

Pappus: \(V = 2\pi A \bar{x}\). Shoelace on the contour with arcs sampled at 32–64 segments (throwaway Python, not committed):

\[
A = 10679.425\ \mathrm{mm}^2,\quad \bar{x} = 28.524\ \mathrm{mm}
\]

\[
V_\mathrm{rev} = 2\pi A \bar{x} = 1\,913\,991\ \mathrm{mm}^3
\]

**Cut.** Ø30 at y = 230, Blind 25, 15° inward. \(R_1 = 15\), \(R_2 = 15 - 25\tan 15° = 8.301270\). Frustum:

\[
V_\mathrm{cut} = \frac{\pi h}{3}(R_1^2 + R_1 R_2 + R_2^2) = 10954.475\ \mathrm{mm}^3
\]

Fits in the top: at y = 205 the solid is still the r = 30 stem.

**Handle** (as-shown ellipse 12×6; path as spoken). Area \(A_e = \pi\cdot 6\cdot 3 = 56.548668\). Path: (0,10) → (60,10); R150, centre (60,160), to (183.592, 75) (ΔY 65, tangent +X at the start); then 20 along the CCW tangent to (194.925, 91.479). Lengths 60 + 145.251 + 20 = 225.251 mm. Gross \(A_e L = 12737.658\). Path inside the r = 90 base until x = 90: 90.204 mm. Net add \(A_e(L - L_\mathrm{in}) = 7636.760\) (section centroid on the path, follow-path, no self-intersection credit).

\[
V = V_\mathrm{rev} + V_\mathrm{handle} - V_\mathrm{cut} = 1\,910\,673\ \mathrm{mm}^3
\]

| | min | max | size |
|---|---:|---:|---:|
| X | −90 | 200.925 | 290.925 |
| Y | 0 | 230 | 230 |
| Z | −90 | 90 | 180 |

X max is path+20+ellipse semi-major 6. Z is the revolved base. Handle Y stays below 230.

**Tolerance.** Pappus sampling error ≪ 0.1 %. **As-shown dims dominate.** Until the frame grab: treat \(V = 1.911\times 10^6\) mm³ as a **±5 %** band (ellipse size, connecting arc, second 20, handle side). After the grab: lock the profile and retune with an OCCT replica; then a 0.5 % band like rung 5.

**Mutants, not targets.** Top radial 10 (title-card Ø20 knob): Ø30 cut no longer sits on the top face. Connecting R~21 from (80,40) to (90,0) instead of the vertical at x = 90. Ellipse 8×4. Path starting at the outer rim rather than the axis (SW temp-axis coincident is the axis). Body-sweep without fuse (second body). Straight cut, no draft (\(V_\mathrm{cut} = \pi 15^2 25 = 17671\)).

Inside (final, reasoned): `(0, 100, 0)` (axis, in the stem), `(40, 10, 0)` (base), `(0, 220, 0)` (below the hole). Outside: `(91, 10, 0)`, `(0, 231, 0)`, `(0, 217, 0)` (in the frustum), `(201, 91, 0)` (past the handle).

## 4. Ranked gaps

Most blocking for *this* video’s named tools first. Size is a gut order-of-magnitude (S < 1 WP, M ~1–2, L several).

| # | Gap | Size | Subsystem |
|---|---|---|---|
| 1 | Real ellipse (3-click, major/minor, orientation, coincident to a path end) | L | kernel (`SketchEntityType`), sketch solver, UI (`sketch_mode.gd`) |
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

Frame-grab list (blocks Current): image-7 profile dims (second 20, connecting arc, any extra radials/heights); ellipse major and minor; which path arc gets Horizontal vs 65; handle side; whether a 2.5 mm rim exists; confirm no fillets.
