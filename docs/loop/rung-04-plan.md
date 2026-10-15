# Rung 4 plan — Pano Central hex key (Swept Boss)

**PLAN only, no product code.** One BUILD agent implements this in order, one commit per work package, on the branch it is given. Push that branch. Do not open a PR. Source: [Solidworks Hex Key using Swept Boss](https://www.youtube.com/watch?v=8IfR-YH6Ghw) (Pano Central, 7:33). Everything from the video is in [`rung-04-prep.md`](rung-04-prep.md) and below. Do not re-watch it. The row text is [`rung-04-checklist.md`](rung-04-checklist.md); do not restate it.

Model: `rung-03-plan.md` for the part, the frame, and the walk. Package shape from the post-rung-3 cleanup: goal, files, change, line delta, one cheap check, revert. Same walk machinery (`tools/walk/` `Rung`, `automation-bridge.md`).

## Where we are

Baseline: `main` `d0a734e` (this branch is cut from there, after post-rung-3 cleanup). Rung 1 walk 77/77. Rung 2 walk 44/44. Rung 3 walk 46/46. `tools/test_walk_registry.py` freezes those three row lists.

The prep was written against `f0de099`. The symbols it names still match this branch: `_polygon_ring_vertices`, `SketchOriginAnchor.RULES`, `begin_on_plane`, `datum::plane_yz`, `OrbitCamera.standard_view_table`, `collect_circle_intersections`, `_sketch_pad_role`, `sketch_ordered_polyline`, `sweep_along_polyline`.

Rung 4 goal: build the hex key with the **named tools in the video's order**, by clicking, and end on a solid that passes `tools/check_rung04.py`.

Pass bar (all of):

- One solid. Bbox **7.650 × 98.417 × 41.417** mm, min corner `(−3.825, −4.416730, 0)`.
- Volume **6313.045** mm³ within 0.5 %. The other two spines are fails, not targets: path on the top vertex **6664.665**, path on the bottom vertex **5961.424**.
- Across flats **7.65** along X, centre on the origin, point-up (a vertex pair on the Y axis). Spine through the centroid.
- Every checklist row PASS (no `FAIL`, `PARTIAL`, `BLOCKED`, `runner-gap`). Critique ≥ 9 (rule at the end).
- On the same build: rung 1 walk 77/77, rung 2 44/44, rung 3 46/46, `check_rung01/02/03/04.py` at their bars, headless `0 failed`.

Whole-plan acceptance is **WP12 only**. Earlier packages run the one cheap check they name. They do not run `make test`, `make test-godot`, `confirm_all.sh`, or a walk without `--dry-run`.

## Frame (decision, not a question)

Same axis map as rung 3. **7.65 is across flats** (prep assumption; an across-corners reading is 8.833 and is a failing mutant). He never types 195; the model is 37, 94, and Ø30.

| Item | Video | SolidExpress |
|---|---|---|
| Units | MMGS, OK | Lengths stay millimetres. No converter and no extra dialog (File → New is already one click in rungs 1–3). New document field `units = mmgs`, bridge `state.units`. The pinned sentence `New — empty part, Top plane (XY). View ▸ Timeline to edit features` stays byte-identical. |
| Profile plane | Front, then Sketch | Named datum **Front** = XY, normal +Z. Clicking it takes the existing ground-sketch path (`_start_sketch_on_ground`), same status as today. Basis `x = +X`, `y = +Y`. |
| Hex | 6 sides, from the origin, inscribed, width 7.65 | Polygon variant `across_flats` (already 6, drag = AF). Commit stays **flats-horizontal** so the nut test (`_assert_hex_flats`: flats at `y = ±10`, vertices on ±X) does not move. Centre anchored. One driving flat-to-flat distance. A later Vertical on the vertex pair turns it point-up. Construction inscribed circle, diameter = AF, not in the profile wire. |
| Point-up | Vertical on a vertex pair | Opposite vertices that lie on X become a vertical pair (same X, on ±Y). `R = 7.65/√3 = 4.416730`. |
| Path plane | Right, then Sketch | Named datum **Right** = the YZ plane. Sketch basis is **not** `PlaneBasis.for_face(+X)` and **not** `datum::plane_yz`'s `x_dir` (+Y): those put screen-horizontal on world +Y. Basis row: `x = +Z`, `y = +Y`. UV `(37, 0)` → world `(0, 0, 37)`; UV `(0, 94)` → world `(0, 94, 0)`. |
| Normal To | Ctrl+8 | Ctrl+8 (and `menu:NormalTo`) re-faces the active sketch. Key **8 alone stays Bottom**. |
| Path | Horizontal 37, vertical 94, both construction; Ø30 circle tangent to both; trim; two solid legs | Corner `(0, 0, 37)`. Tangent points 15 mm back: `(0, 0, 22)` and `(0, 15, 37)`. Circle centre `(0, 15, 22)`. Solid legs length 22 and 79. Arc is a quarter circle, R15, not construction. |
| Solid | Swept Boss/Base, profile + path, OK | A Swept Boss command that asks for the two sketches. The Ctrl+click pad path stays for films. |

Top is seeded too (XZ, normal +Y, display name **Top**) so a new part has the three origin planes. Nothing in this video sketches on it. The status sentence that says "Top plane (XY)" is the camera sentence, not this datum; do not edit it.

Spine, centred key: `(0,0,0)` → `(0,0,22)` → quarter circle, centre `(0,15,22)`, to `(0,15,37)` → `(0,94,37)`.

| | min | max | size |
|---|---:|---:|---:|
| X | −3.825 | 3.825 | 7.650 |
| Y | −4.416730 | 94 | 98.416730 |
| Z | 0 | 41.416730 | 41.416730 |

`A = √3/2 · (7.65)² = 50.681972`. `L = 22 + 79 + 15·π/2 = 124.561945`. `V = A·L = 6313.045`. Inner radius `15 − R = 10.583`, so the section does not cross the bend centre. X does not rotate (the bend is in YZ). Z max is `37 + R` on the long arm.

Inside: `(0, 0, 5)`, `(0, 4.393, 32.607)` (arc at 45°), `(0, 50, 37)`. Outside: `(3.9, 0, 5)`, `(0, −4.5, 5)`, `(0, 50, 42)`, `(0, 95, 37)`.

These constants are copied into the checker's `PART` table in WP1. After that the walk reads `check_rung04.py params`, not this file.

## The video, step by step → SolidExpress

Rows are in the checklist.

| # | Video | SolidExpress | Rows |
|---|---|---|---|
| 1 | New part, MMGS, OK | File → New. Pinned sentence unchanged. `state.units` is `mmgs`. | N1, A1 |
| 2 | Front plane, Sketch | Click datum Front, Sketch. Ground path, plane XY. | A2, L1 |
| 3 | Polygon, 6, from the origin, inscribed, 7.65 across | `rail:Polygon`, variant `across_flats`, centre `(0,0)`. Smart Dim the two opposite flats → `7.65`. | A3, A4, N2 |
| 4 | Vertical vertex pair. Fully defined. | Vertical on the two vertices that lie on X. Point-up, DOF 0. | A5, L2 |
| 5 | Exit sketch | Exit Sketch. | A6 |
| 6 | Right plane, Sketch | Click datum Right, Sketch. Basis above. | A7 |
| 7 | Normal To (Ctrl+8) | Ctrl+8. Key 8 alone is still Bottom. | A8, L3 |
| 8 | Horizontal 37, vertical 94 | Line tool. World `(0,0,0)→(0,0,37)` then `(0,0,37)→(0,94,37)`. | A9 |
| 9 | Both construction | Construction toggle (X / the construction action). | A10, L4 |
| 10 | Perimeter circle, tangent to each line, Ø30 | Circle variant `perimeter`: first two picks are the lines, third click is the elbow side. Smart Dim `Ø30`. | A11, N3 |
| 11 | Trim to closest. The circle becomes the bend arc. | Trim the outer part of the circle. One arc, R15, span 90°. Construction lines remain. | A12, L5 |
| 12 | Solid line through each pair of points | Line tool, twice. Lengths 22 and 79. | A13 |
| 13 | Exit sketch | Exit Sketch. Path is a rail. Hex sketch is still the profile. | A14 |
| 14 | Swept Boss/Base. Profile, path, OK. | `sweep:Boss`, profile pick, path pick, `sweep:Ok`. One solid. | N4, A15–A19, L6 |
| 15 | (save is implied by the walk, not narrated) | Save As `final.sxp`, reopen. | A20, N5, A21 |

Already in the product, no package: Exit Sketch, the line tool with horizontal/vertical inference, Smart Dim line length, the construction toggle, redrawing a solid line through two points.

## Gaps → packages

| Prep | Mark | Package |
|---|---|---|
| 1 MMGS | PARTIAL | WP2. Field only. No dialog, no inch conversion. |
| 2 Front plane + Sketch | PARTIAL | WP5. Named Front, existing ground path. |
| 3 Hex 6 / 7.65 AF / origin / inscribed circle | PARTIAL | WP4. Pose stays flats-horizontal until WP3's relation. |
| 4 Vertical vertex pair | MISSING | WP3. |
| 5, 13 Exit | HAVE | — |
| 6 Sketch on Right | MISSING | WP5. |
| 7 Ctrl+8 Normal To | PARTIAL | WP6. Key 8 stays Bottom. |
| 8 Lines 37 and 94 | HAVE | — |
| 9 Construction | HAVE | — |
| 10 Ø30 tangent to both legs | PARTIAL | WP7. Not the fillet tool. |
| 11 Trim to closest | PARTIAL | WP8. Construction cuts only when nothing else does. |
| 12 Redraw solid legs | HAVE | — |
| 14 Swept Boss, profile + path | PARTIAL | WP9. Ctrl+click path stays. |
| Faceted spine | risk | WP10 ★, only if WP9's solid fails the checker. |

## Design rules

New behaviour is a row in a table or a value object. `sketch_mode.gd` and `main.gd` only call the helper. A new file starts with a two-line header that says what it owns.

Tables: `SketchOriginAnchor.RULES` (one new row), `PolygonPose` (one vertical-pair edit), `SmartDimTable._RULES` (parallel lines → distance), `OriginPlanes.BASIS` (Front / Top / Right), `SketchCircleTangent` (pick sequence → builder), checker `PART` / `STAGES`, walk `Rung`.

Click-driven UI tests (`.cursor/rules/gdscript-click-driven-tests.mdc`). A new suite is one `packaging/ci/suites.d/<name>.suite` file. Do not edit `packaging/ci/run_godot_suites.sh` or the Makefile `test-godot` recipe. Never pass `user://` or `res://` into GDExtension.

Do not edit `docs/plan/STATUS.md`. Do not commit `.webm`, `.mp4`, `.avi`, `.mov`, `.vtt`. The four `known-red` manifests stay known-red. `run_film_caption_tests.gd` and `run_ui_scroll_tests.gd` stay unregistered.

`export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}` before any `tools/godot/godot` call.

## Decisions (the BUILD agent does not choose)

1. **AF commit stays flats-horizontal.** `start_angle = 0` and the horizontal constraints on the flat edges stay. The nut at the origin (`run_rung01_sketch_tests.gd` `_assert_hex_flats`) must still pass. Point-up is the Vertical relation, not a new polygon variant.
2. **One driving dimension, the flat-to-flat distance 7.65.** Two parallel lines take `parallel_distance` (point-to-line, which the solver already has). Two non-parallel lines stay an angle. The inscribed circle is construction, centre at the origin, diameter equal to that distance; it is not a second driving dimension. It must not enter `profile_face`.
3. **Vertical on two endpoints.** Solver `Vertical` gains the two-point form `Horizontal` already has. `PolygonPose` then drops Horizontal constraints on the closed loop that owns those two vertices, and no others. The glyph shows for two endpoints; the two-circle case stays hidden (T14).
4. **Front click = ground sketch.** Same function, same status. Right and Top use `begin_on_plane` with `OriginPlanes.BASIS`. Hit test is the finite datum quad, not the infinite plane, so a click in empty space still starts the ground sketch. A body face still wins over a datum.
5. **Right basis.** `x = +Z`, `y = +Y`. The red test is the world points in the frame table. If screen-right comes out as −Z, flip `x` in that one row and re-run the test. Do not change the checker.
6. **Trim.** If a circle or arc has two or more intersections with non-construction geometry, those win (today's behaviour, wrench centreline included). If it has fewer than two, construction lines count as cutters. Construction entities are not themselves deleted. Power-trim jaw code in `sketch_mode.gd` is not rewritten.
7. **Circle perimeter.** Three points in empty space stay a circumcircle. The tangent builder runs only when the first two picks hit lines. Side is the third click. The elbow for this part is the side toward +Y and −Z from the corner, centre `(0, 15, 22)`.
8. **Sketch role.** Ignore construction. A closed non-construction loop is a profile (the hex, and a circle). An open chain is a rail (two lines + arc). A construction circle does not by itself make a profile.
9. **Sweep command.** `sweep:Boss` / `sweep:Profile` / `sweep:Path` / `sweep:Ok` calls the existing `graph_add_sweep_along_path`. Status stays `Sweep solid created along path` if that is what the function already emits. Ctrl+click pads still work.
10. **Spine.** WP9 uses today's polyline sweep. Chord error on this quarter circle is about 0.04 mm of length (~2 mm³, ~0.03 %). Bbox extrema sit on the straight legs, not on the arc. WP10 runs only when that solid fails `check_rung04.py`. Do not widen `TOL` or the 0.5 % volume band to skip WP10.
11. **No pierce constraint.** The path starts at the origin and the hex is centred, so the spine meets the centroid. If the solid is empty or translated, WP9 tries `withContact` once. It does not add a sketch relation and it does not move the path off the centroid.
12. **Critique.** The walk and the checker are necessary, not sufficient. Done means one build follows every video step with the named tool, scores ≥ 9, and the checker passes. A fillet instead of circle + trim, a flats-horizontal hex, a ground sketch instead of Front / Right, key 8 instead of Ctrl+8, or Ctrl+click instead of Swept Boss caps the critique at 8.
13. **Checkpoints.** `hex.sxp` after A6, `path.sxp` after A14, `final.sxp` after A20.

## BUILD agent rules

- One commit per WP: `Rung 4 WP<n>: <title>`. Push after each commit. Do not open a PR.
- **Revert.** If that WP's cheap check is still red after two honest attempts, `git revert` the commit, write one line in `docs/plan/roadmap.md` §9 naming the check, and continue. Do not loosen a tolerance, drop a `--only`, or edit the tier to get green. WP10 is the exception in its own section: skip it when the checker already passes; revert it when the arc spine is worse than the polyline.
- **★** Only WP10. Do not start it unless WP9's exported solid fails `check_rung04.py`.
- No new third-party dependency.

Cheap checks (not the full pass):

| Check | Command |
|---|---|
| C-py | the `python3 tools/test_….py` the WP names |
| C-one | `GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --jobs 1 --only '<suite>'` |
| C-dry | `python3 tools/walk_rung04.py --dry-run` plus `python3 tools/test_walk_registry.py` |

## Work packages

### WP1 — Checker `check_rung04.py`

Goal: one stage, `final`, with the numbers in the frame table. Unit tests use a stub, not the app.

Files: new `tools/check_rung04.py`, `tools/test_check_rung04.py`, `tools/implicit_key.py` (tests only). `Makefile` `test-tools` gains `python3 tools/test_check_rung04.py`. `tools/solid.py` is reused, not moved.

Change: `PART` holds `AF = 7.65`, `R = 4.416730`, `LEG_Z = 37`, `LEG_Y = 94`, `BEND_D = 30`, `AREA = 50.681972`, `LENGTH = 124.561945`, `VOLUME = 6313.045`, bbox min/max as the table, the three inside points and four outside points, `VOL_TOP = 6664.665`, `VOL_BOT = 5961.424`. `TOL = 0.2` mm. Volume band 0.5 %. Probes: `Bbox`, `Volume`, `Watertight` (one closed component), `Inside`, `Outside`. `STAGES = {"final": [those]}`. `params` prints `PART` as JSON.

`ImplicitKey.inside`: distance to the spine (segment, then quarter circle, then segment) in the plane normal to the tangent; local X is world X; local +Y starts as world +Y and rotates to world −Z on the long arm. Inside the hex when `|x| ≤ AF/2` and `|y| ≤ R − |x|/√3`. `volume()` returns `VOLUME` (mutants override it). `bbox()` returns the table.

Outside point `(0, −4.5, 5)` is only 0.083 mm past the vertex. If a real 3MF tessellation of that vertex includes it, move **that one** probe to `(0, −4.8, 5)` and record the point in `PART`. Do not move the others.

Expected delta: about +450 lines.

Check: C-py `test_check_rung04.py` is red on the missing module, then green. Mutations that must fail the named check: AF 8 (`bbox`), length 195 (`bbox`), flats-horizontal extents (`bbox`), translated off the origin (`bbox`), volume 6664.665 (`volume`), volume 5961.424 (`volume`), the 45° point outside (`inside`), a second body (`watertight`). `test_check_rung02.py` and `test_check_rung03.py` stay green.

Revert: revert the commit if C-py is still red after two attempts.

### WP2 — MMGS field

Goal: a new part reports millimetres without a dialog and without touching the pinned New sentence.

Files: document init (the C++ or GDScript new-document path that already exists — one field `units`, default `mmgs`), `automation_bridge.gd` `state.units`, `docs/loop/automation-bridge.md` one row.

Change: additive bridge field only. No new status text. No unit conversion.

Expected delta: about +40 lines.

Check: C-one on the automation-bridge suite if it lists state keys; otherwise a new `rung04_units.suite` (`tier=full`) that only asserts `state.units == mmgs` after File → New and that the status label still equals the pinned sentence in `run_rung01_wrench.gd`.

Revert: revert. A1 then has no units clause; do not invent a dialog in a later WP.

### WP3 — Vertical vertex pair

Goal: Vertical on two points, and that relation turns an origin AF hex point-up without moving a hex that never receives it.

Files: `sxkernel/src/solver_planegcs.cpp` `ConstraintType::Vertical` (two-point branch, same shape as `Horizontal`). `game/scripts/sketch_polygon_pose.gd` (`class_name PolygonPose`, one function `vertical_pair(sketch, endpoint_a, endpoint_b)`). `sketch_mode.gd` `constrain` calls it when the selection is two endpoints; a click nearer an endpoint than a line midpoint stores the endpoint. Glyph: draw point-point vertical; keep hiding the two-centre case (`_constraint_refs_a_line` / T14).

Change: `vertical_pair` adds the two-point Vertical, then removes Horizontal constraints whose entity lies on the closed loop through those vertices. It does not remove Horizontal on any other line. Solver call is PlaneGCS `addConstraintVertical` on the two points.

Expected delta: about +180 lines.

Check: red first, then C-one `rung04_vertical.suite` (`tier=ci`): AF hex centred at the origin, flats still at ±Y before the relation; Vertical on one pick refuses and does not move it; Vertical on the ±X vertices solves to `x = 0`, `y = ±R` for that pair, AF unchanged. Then C-one `rung01_sketch_tests.suite` (the nut: flats at `y = ±10`, vertices on ±X). Kernel Catch2 can lock the two-point equation if the GDScript test cannot reach the solver alone; one of the two is enough.

Revert: revert the commit. Do not "fix" the nut by rotating the default AF pose.

### WP4 — Origin, driving 7.65, inscribed circle

Goal: the hex the video dimensions. Centre on the origin, one driving across-flats distance, construction inscribed circle. Commit pose still flats-horizontal.

Files: `game/scripts/sketch_origin_anchor.gd` (`RULES` row `polygon.af`, lock `centre`). `game/scripts/smart_dim_table.gd` (parallel line pair → `parallel_distance`; non-parallel stays `angle`). `sketch_mode.gd` polygon commit calls the anchor when the centre is within `ORIGIN_PIN_TOL` (0.5). New helper in `sketch_polygon_pose.gd` for the circle.

Change: anchor is a construction segment between the opposite vertices, midpoint coincident to the origin point (the rect diagonal, applied to the vertex pair). Inscribed circle: construction, centre on that origin, diameter = the flat distance, tangent so it follows that one driving dimension. Equal length on the six edges so the hex stays regular after WP3 drops the horizontals. `profile_face` must still see six lines and no circle. Status at commit stays `Polygon AF %.4f — flats horizontal` (pinned by `run_rung01_sx036_fields.gd`).

Expected delta: about +220 lines.

Check: red first, then C-one `rung04_hex.suite` (`tier=ci`): after anchor + Smart Dim `7.65` + Vertical, DOF 0, X extent 7.65, vertices on ±Y, one driving distance, construction circle radius 3.825, profile loop is six lines. A centre at `(30, 0)` is not anchored. Then C-one `rung01_sketch_tests.suite`. If the circle makes that nut test red, delete the circle only, keep the anchor and the distance, and say so in the commit message. Do not delete the anchor to save the circle.

Revert: revert the whole commit if the nut is still red after the circle is removed.

### WP5 — Front, Top, Right

Goal: a new part has three named origin planes. Front sketches like the ground. Right sketches in the basis above.

Files: new `game/scripts/origin_planes.gd` (`class_name OriginPlanes`, `BASIS` table, `seed(doc)`). Call `seed` from the new-document path. `viewport_interaction.gd` `_commit_pick_sketch_host`: finite-quad hit before the ground fallback; a face still wins. Front → `_start_sketch_on_ground`. Right / Top → `_start_sketch_on_plane` with the basis row. Bridge `click(datum="Front"|"Top"|"Right")`. `docs/loop/automation-bridge.md`.

`BASIS`: Front `(x=+X, y=+Y)`; Right `(x=+Z, y=+Y)`; Top `(x=+X, y=+Z)`. Display names `Front`, `Top`, `Right`. Stored datum `x_dir` may stay whatever `datum::plane_xy` / `plane_yz` / `plane_xz` already write; the sketch uses `BASIS`, not that `x_dir`.

`game/tests/run_ui_tests.gd` pins `datum_list` size 0 (`new document has no datums`) and `run_menu_tests.gd` pins size 0 then 1 on offset. Update those counts by +3 (the offset confirm adds one more on top of the three). `film_datum_offset.gd` records the size and compares a delta; leave it if the delta still holds.

Expected delta: about +280 lines, plus the two test-count edits.

Check: red first, then C-one `rung04_planes.suite` (`tier=ci`): after New, three datums named Front, Top, Right; click Front → XY sketch, status is the ground-sketch status (not `Sketch on plane`); click Right → UV `(37,0)` is world `(0,0,37)` and UV `(0,94)` is world `(0,94,0)`; a click that misses the quads still starts the ground sketch. Then C-one `ui_tests.suite` and `menu_tests.suite`.

Revert: revert, including the count edits (one commit).

### WP6 — Normal To

Goal: Ctrl+8 faces the active sketch. Key 8 still selects Bottom.

Files: `orbit_camera.gd` or `main.gd` input: chord Ctrl+8 calls `enter_sketch_view` on the active sketch plane (normal and `plane_y`). No sketch and a datum selected: frame that datum's `BASIS` the same way. View menu item id `menu:NormalTo`. Do not edit `standard_view_table`'s key 8 row.

Expected delta: about +80 lines.

Check: C-one `rung04_normal_to.suite` (`tier=ci`): on a Right sketch, Ctrl+8 leaves the camera looking along the sketch normal with up = plane Y; key 8 alone still applies view id `bottom`.

Revert: revert. The walk's A8 would then be blocked; do not rebind key 8.

### WP7 — Tangent perimeter circle

Goal: a circle tangent to two lines, on the side of a click, then Ø30.

Files: new `game/scripts/sketch_circle_tangent.gd` (`class_name SketchCircleTangent`: pick sequence → builder). `sketch_mode.gd` `_click_circle` variant `perimeter` calls it. Three point picks that miss lines keep `_circumcenter`.

Change: two line picks (construction allowed) plus a side click add two `Tangent` constraints (solver line–circle already exists) and a circle whose centre is inset from both lines. Smart Dim diameter uses today's diameter path. For perpendicular lines, Ø30 puts the centre 15 mm off each line. This part's elbow centre is world `(0, 15, 22)`.

Expected delta: about +200 lines.

Check: red first, then C-one `rung04_tangent_circle.suite` (`tier=ci`): two construction lines, tangent circle, Smart Dim `Ø30`, centre inset 15 on the clicked side, both tangents present, lines still construction. A 3-point perimeter pick still makes a circumcircle. Diameter `0` refuses and adds nothing.

Revert: revert. Do not satisfy A11 with `fillet_selected`.

### WP8 — Trim sees construction when it has to

Goal: the Ø30 circle trims against the two construction legs. A trim that already has solid cutters does not change.

Files: `sxkernel/src/sketch_tools.cpp` `collect_circle_intersections`, `collect_line_intersections`. The `other.construction` skip becomes: count non-construction hits first; use construction hits only when that count is below 2. `sketch_mode.gd` `trim_at` comment matches the new rule. Jaw power-trim is not edited.

Expected delta: about +50 lines.

Check: red first, Catch2 next to the existing trim test (or a new case in `test_sketch_tools.cpp`): circle tangent to two construction lines, trim the outer pick, one arc remains, radius 15, span 90° ± 1°, endpoints at the tangent points, both lines still there. A second case: a circle crossed by a solid line and a construction line still trims at the solid line only. Then C-one on the wrench sketch suite that trims the jaw (`rung01_sketch_tests.suite`). If that suite goes red, the construction fallback applies to circles and arcs only, not to line trims, and the jaw suite is re-run once. If it is still red, revert.

Revert: revert the commit.

### WP9 — Swept Boss

Goal: one command takes a profile sketch and a path sketch. A closed hex is a profile. An open line-and-arc chain is a path. The solid is the centred key.

Files: new `game/scripts/sweep_boss.gd` (button `sweep:Boss`, picks `sweep:Profile` and `sweep:Path`, ok `sweep:Ok`). `main.gd` `_sketch_pad_role` uses the closed-loop rule in decision 8 and the button calls `_sweep_profile_along_path`'s existing graph call. `docs/loop/automation-bridge.md`.

Change: role ignores construction; closed loop → `profile`; open chain → `rail`. The button does not require Ctrl and does not depend on a circle being present. Films that Ctrl+click a circle profile and a line rail still get those roles (a circle is a closed loop).

Expected delta: about +220 lines.

Check: red first, then C-one `rung04_sweep.suite` (`tier=full`): build the hex and the path through the tools of WP3–WP8, `sweep:Boss`, one body, export 3MF, `check_rung04.py final` exits 0. Swept Boss with only the profile selected refuses and adds no body. Then C-one `sketch_to_3d_ui_tests.suite` (circle stays profile, guide stays rail).

If the solid is empty or the bbox is translated, set `withContact` true once and re-export. If the checker then passes, stop. If it fails, leave the polyline sweep in place and start WP10. Do not move the spine onto a vertex.

Revert: revert if the suite is red for a reason other than the checker numbers. A checker miss is the WP10 trigger, not a revert.

### WP10 ★ — Circular spine

Goal: the path arc stays a circular edge, only if WP9's mesh failed the checker.

Do not start this WP when `check_rung04.py final` already passes. A skipped ★ is not a failure and needs no commit.

Files if it runs: `sxkernel/src/features.cpp` (`sketch_ordered_polyline` stays for polylines). New `sketch_spine_wire` builds a `TopoDS_Wire` of line edges and one `Geom_TrimmedCurve` arc. `sweep_along_polyline` (or a sibling called from `apply_sweep`) uses that wire. Joints that are tangent use `BRepBuilderAPI_Transformed`. A polyline with a corner keeps `BRepBuilderAPI_RightCorner`. `commands_sweep.cpp` already uses `MakePipe` for a single edge; a three-edge G1 wire is this WP, not that branch.

Expected delta if it runs: about +250 lines. If skipped: 0.

Check: the same `rung04_sweep.suite` export, `check_rung04.py final` exits 0, and a Catch2 case that the path wire has one circular edge of radius 15.

Revert: if the arc solid is invalid or the checker is worse than the polyline numbers, revert and keep the polyline. Do not widen the volume band. WP12 reports the polyline numbers either way.

### WP11 — Walk

Goal: `tools/walk_rung04.py` runs the checklist. Registry freezes the row list. Rungs 1–3 stay frozen.

Files: `tools/walk/registry.py` (`RUNG4_ROWS`, `_RUNG_SPEC["rung04"]`, `install`), new `tools/walk/app04.py`, `tools/walk/rung4/ui04.py`, `tools/walk/rung4/rows04_chunk{1,2,3}.py`, new `tools/walk_rung04.py` (same CLI as `walk_rung03.py`). `tools/test_walk_registry.py` gains `FROZEN_ROWS_04`. `tools/confirm_all.sh` gains `unit_rung04`, walk 4 on display `:24` / port `47324`, and the summary lines (`rung4`, `check-final-final.txt`). `docs/loop/README.md` lists this plan, the checklist, and `walk_rung04.py`. `docs/loop/automation-bridge.md` for any new click form.

Change: each checklist row is a method that calls `ui04` helpers and `self.clause(...)`. Chunks and checkpoints are decision 13. Export rows A16–A19 share one 3MF and read one checker line each. A21 is the headless evidence row (needs `--a15`; without the flag it is `BLOCKED-by-flag`), same clause names as rung 3 A26: `kernel`, `godot`, `lint`, `unit`, `registry`, `errors`.

Expected delta: about +700 lines.

Check: C-dry. Registry test green for four rungs. `walk_rung04.py --rows N1,A1,A2 --dry-run` prints those rows. Do not launch Godot here.

Revert: revert if the registry test is red after two attempts.

### WP12 — The single full pass

Goal: one pass on this VM. Counts only. No product edits unless a count is red, and then only the smallest fix, re-run once.

Change: none expected. Run:

`tools/confirm_all.sh`

That script builds, imports, runs the kernel, the lints, `test_check_rung02/03/04.py`, the registry test, the headless suites, and the four walks. Do not also run `make test` or a second suite pass.

Report, and nothing else: the confirm summary lines (build, kernel, lint, godot suite count, rung1 77, rung2 44, rung3 46, rung4 32, each checker tail). If WP10 was skipped, one line: `spine: polyline, checker passed`. If it ran, one line: `spine: arc` or `spine: reverted`.

Expected delta: 0.

Check: the summary. A walk row that fails is a product bug; fix it and re-run confirm once. Do not re-run confirm before that fix.

Revert: not this WP. A bad fix-up commit reverts on its own.

## Chunks

| Chunk | Rows | Ends |
|---|---|---|
| 1 | N1 A1 A2 L1 A3 A4 N2 A5 L2 A6 | hex sketch saved, `hex.sxp`, no body, flats point-up, nothing selected |
| 2 | A7 A8 L3 A9 A10 L4 A11 N3 A12 L5 A13 A14 | path sketch saved, `path.sxp`, no body |
| 3 | N4 A15 A16 A17 A18 A19 L6 A20 N5 A21 | `final.sxp`, checker passed, headless evidence |

32 rows: 21 A, 6 L, 5 N. Clause text: [`rung-04-checklist.md`](rung-04-checklist.md).

## Out of scope

- A units dialog, inch conversion, or editing the pinned New sentence.
- Driving 8.833 (across corners) or typing 195.
- A pierce / path-on-profile constraint.
- Rebinding key 8. Changing the default AF pose to point-up.
- Fillet as a stand-in for the tangent circle.
- A demo film, `docs/plan/STATUS.md`, associative sketches.
