# Rung 1 implementation plan — UBC ELEC391 hex nut + open-end wrench

Status: plan only. No product code in this change.

Baseline: SolidExpress 0.0.12, `main` at `1ebaf98` (PR #44). Requirements: the rung-1 gap list (tutorial steps, dimensions, and `check_rung01.py`). This plan covers rung 1 only. Later rungs are listed under Deferred so they are not rebuilt here.

Pass for this rung is the tutorial's own tools, then:

```
python3 check_rung01.py nut    nut.3mf
python3 check_rung01.py wrench wrench.3mf
python3 check_rung01.py thick  wrench-t14.3mf 14
```

Tolerance ±0.2 mm. A substitute tool (Box + Hex opening for the jaw, Blind 10 for Up To Surface) caps the critique at 8. sx-019 leftovers (pocket panel, AF clamp, move, TriBall) ship in the same cut because they eat the clicks the tutorial needs.

## What already exists

Do not reimplement these. The critic never reached them, or the headless tests call private helpers the viewport does not.

| Capability | Where it already lives |
|---|---|
| Sketch entities (line, circle, arc, polygon, slot, rect variants), PlaneGCS, coincident/tangent/midpoint/diameter/concentric | `sxkernel/include/sx/sketch.hpp`, `sxkernel/src/solver_planegcs.cpp` |
| Closed profile, nested inner loop as a hole, multi-region contours | `Sketch::contour_faces` / `profile_face_selected` in `sxkernel/src/sketch.cpp`. Kernel cases in `sxkernel/tests/test_features.cpp` (`selected contours`, `nested wire as a hole`) |
| Extrude `blind` / `through_all` / `to_face` / `to_next` / `symmetric`, cut and fuse | `FeatureGraph::apply` extrude arm in `sxkernel/src/features.cpp` (~923–1069). `through_all` test in `sxkernel/tests/test_wave0.cpp` |
| Sketch-on-face plane from a picked face | `SketchMode.derive_face_plane`, `Main._start_sketch_on_face` |
| Power trim, Smart Dimension chrome, finish bar (Blind / Through All / Midplane, New/Cut/Fuse, contour toggles) | `SketchMode.trim_at`, `SketchContextChrome` |
| Hex place clamp, depth 0 = through, expression `=jaw_af+clearance` | `OpsPanel._hole_place_position`, `OpsPanel._stamp_hole_expressions`, hole tool in `features.cpp` `FeatureType::Hole` |
| 3MF in model millimeters | `sx::interop::export_3mf` (`sxkernel/src/interop.cpp`), menu `FileAction.EXPORT_3MF` → `SxDocument.export_3mf` |
| Timeline rows for sketch and extrude (names `sketch N`, `extrude N`) | `FeatureGraph::add` in `sxkernel/src/features.cpp` |

The hole is the path from a viewport click to those functions.

## Root causes

### 1. Sketch → solid looks broken (since 0.0.11)

`SketchMode.finish_extrude` (`game/scripts/sketch_mode.gd`) does two different failures, and both were reported as "sketch doesn't extrude":

1. **Open-profile gate before the kernel.** `profile_is_closed` (same file, ~2965) chains endpoints at 1e-4 mm. `Sketch::contour_faces` chains at 1e-6 mm (`sxkernel/src/sketch.cpp`, `tol = 1e-6`). A polygon the UI calls closed still dies in the kernel as `profile has an open loop`. The UI then says `Extrude failed — open profile` and keeps the session, or, if it got as far as `graph_add_extrude`, says `Extrude failed — is the profile closed?`.
2. **Whole-graph rollback, error thrown away.** `SxDocument::graph_add_sketch` / `graph_add_extrude` (`sxcore/src/sx_document.cpp`) go through `apply_graph_edit`. Any regenerate failure restores the previous graph and returns `""`. `SketchMode._ensure_sketch_feature` turns that into `Failed to add sketch` and does not append `last_graph_error()`. `exit_sketch` does the same with `Failed to save sketch`. That is the 0.0.11 string (sx-014). A sketch feature itself is a no-op in `FeatureGraph::apply` (`case FeatureType::Sketch` returns true). The rollback is some other feature on the same timeline (the New-part Box, a later extrude, a failed solve written into the sketch). The critic never sees which one.
3. **Extrude failure deletes the sketch and the session.** `_finish_feature` calls `graph_remove` on the new sketch and emits `cancelled`, so the next attempt starts over. The only successful critique (sx-012 / PR #35) was a nearly-closed outline that happened to chain.

Polygon and rectangle corners are separate line entities. `SketchMode.click` for `Tool.POLYGON` adds coincident constraints and `run_solve()`, but a failed or partial solve leaves a gap above 1e-6 and the kernel refuses the wire. Inner-loop holes and "select all 3 contours" already work once `contour_faces` returns faces (`selected_contours` on the extrude feature, contour chips in `SketchContextChrome.refresh_contours`).

### 2. Two-click sketch tools are drag-only

`ViewportInteraction._sketch_input` (`game/scripts/viewport_interaction.gd`, mouse-up branch ~2115) treats a release closer than `CLICK_SLOP` as `SketchMode.reject_tiny_draw`. That function **clears `_tool_points`** when the release is within `MIN_SEGMENT_MM` (0.5 mm) of the anchor (`sketch_mode.gd` ~669). A click at A and a click at B never share an anchor: the mouse-up of the first click discards A. A drag (press at A, move, release at B) commits because the press calls `click` and the release calls `click` again. That matches sx-015: line is drag-only, two clicks are two unrelated picks. Circle, polygon, rectangle, and slot share `has_pending_draw_point`, so they lose the first click the same way.

There is no origin magnet. `snap_point` snaps to endpoints, midpoints, centers, and H/V of the last tool point. It never snaps to sketch `(0,0)`, and `SNAP_RADIUS` is 1.25 mm, which is unusable on a 232 mm part.

### 3. Hex unclamped on AF regen and resize (sx-019 #2)

Place clamps. Regen and resize do not.

- Place: `OpsPanel._hole_place_position` calls `_clamp_point_on_face` with margin `AF/√3 + 0.5` (circumradius). Only while `Pending.HEX_PLACE` or the type dropdown is already Hex.
- AF regen: `SxDocument::set_variable` (`sxcore/src/sx_document.cpp` ~1107) writes `jaw_af` and regenerates in place. `FeatureType::Hole` rebuilds the prism at the stored `position` with diameter `=jaw_af+clearance`. `BRepAlgoAPI_Cut` succeeds when the hex crosses the boundary, so the result is an open notch and `last_graph_error` stays empty. `game/tests/run_wrench_through_tests.gd` `test_af_grows_existing` only checks that volume dropped.
- Resize: `DocumentView.resize_primitive_aabb` remaps the hole center by its fraction of the old AABB and clamps that fraction to `[0,1]`. The center stays inside the box. The circumradius does not. Status text says "holes remapped" either way.

### 4. Pocket click does not open Type / Diameter / Depth (sx-019 #1)

`OpsPanel.show_hole_feature` is the panel (`_hole_type`, `_hole_diameter`, `_hole_diam_expr`, `_hole_depth`). The through-cut test never clicks. It calls `show_hole_feature(hid)` itself.

The viewport path is `DocumentView.select_ray`:

- A click in the through-hole misses `doc.pick` (there is no surface). `select_ray` clears the selection. Status becomes `Selection cleared`. That is critique step C, hole click.
- A click on the rim uses `hole_feature_near_point`. The accept radius is `max(diameter * 0.55, 3)`. A numeric AF of 10.3 gives r ≈ 5.67 mm. The hex vertex sits at `AF/√3` ≈ 5.95 mm, so a vertex click misses and falls through to body select (`# Box`). An expression diameter is hardcoded to 20 mm inside that function, which is why a unit test aimed at the stored axis point passes and a rim click does not.
- After a real pick, `Main.open_feature_params` returns immediately because `_do_new` sets `show_timeline = false`. The property-panel schema for holes (`property_panel.gd`, type `hole`) never opens. The status line promises a panel the click does not show.

### 5. Hex move only sticks right after place (sx-019 #3)

`OpsPanel._on_picked` relocates only when `_selected_hole_fid` is already set. `_resolve_hex_place` deliberately does not arm `HOLE_MOVE` (that arming was the 1.5 mm blind pocket). `_commit_hole` does not set `_selected_hole_fid`. The id is set only by `show_hole_feature`, which the missed pocket click never calls. `_on_selection_changed` clears the id whenever the body selection goes empty. `graph_changed` (resize, undo, variable regen that refreshes the view) clears the selection. After that, the same face click selects the body and does not move the hex.

### 6. TriBall auto-arm and two Escs (sx-019 #4)

`TriBallGizmo.begin` is only called from `ViewportInteraction._ctx_triball`. New does not call it. `_do_new` selects the plate and calls `triball.cancel()` twice. `test_new_matte_no_triball` only asserts `triball.active == false` after that helper. It never presses Esc and never checks the next click.

What the critic hits:

- New selects the body, so the selection strip shows the TriBall button (`_refresh_selection_strip`, `_strip_triball.visible`).
- Escape is a stack, handled in both `ViewportInteraction._gui_key` and `Main._unhandled_input`: pending pick, then property panel, then TriBall if `active or visible`, then clear selection. One keypress consumes one layer. Two Escs to get back to an empty viewport.
- `_on_press` returns immediately when `triball.active`, so the first face/edge click becomes a ring drag. That eats every sketch and fillet pick while the gizmo is up.

### 7. Up To Surface collapses a top-face cut

`end == "to_face"` in `FeatureGraph::apply` measures from the sketch origin along the sketch normal and keeps `max(1e-3, dot)`. A sketch on the top face has normal +Z. The bottom face is −Z. The dot is negative, so the depth becomes 0.001 mm. `through_all` does honor the sign of `distance` (`finish_extrude` negates it for cuts). `graph_add_extrude` stores `end` and does not store a `to_face` face id. The finish bar offers Blind, Through All, and Midplane only (`SketchContextChrome._build_finish_bar`). Choosing Cut already flips the bar to Through All, which is why a kernel through-all cut survives a thickness edit and a face-targeted cut does not.

## Gap → change

Tutorial frame: Top plane = XY, origin at the pivot, +Z up, millimeters. Nut: hex AF 20 (centre-to-flat 10), bore Ø10, thickness 7.5, flats top/bottom (vertices on ±X). Wrench: Ø20 at origin, Ø45 at (200, 0), tangent shaft 20 wide, extrude 10, jaw 20 at 45° with the floor through the head centre, grip slot width 10 (R5), 150 between arc centres, blind 2.5, R10 at both neck edges, R1 on top, bottom, and slot floor. Overall 232.5 × 45 × 10. Slot X is not in the source; use arc centres at x = 18.5 and 168.5 (figure scale in the gap list) and treat X as informational.

| Gap | Change |
|---|---|
| 1. Sketch → solid, inner hole, 3 contours | In `finish_extrude`, stop dropping `last_graph_error()`. On kernel failure, keep the sketch feature and the session. Weld or share polygon/rect corners so `contour_faces` sees a closed wire at 1e-6, or chain at the same tolerance as the solver write-back. Inner loop and `selected_contours` stay as they are; the finish bar must leave all three contour chips on for the wrench blank. Timeline names stay `sketch N` / `extrude N`. |
| 2. Circle, two-click line, polygon AF, origin snap | `_sketch_input`: a stationary mouse-up leaves the anchor in `_tool_points`. `reject_tiny_draw` only rejects a second point that is actually &lt; 0.5 mm away, and it must not clear the first anchor. `snap_point` includes sketch `(0,0)` and existing circle centres; scale the radius with the view span (a 1.25 mm magnet cannot hit the origin on a 232 mm part). Polygon: numeric across-flats at the second click (the dim blank already locks length via `set_length_override` / `commit_at_length`). `across_flats` must report AF, not the drag distance after dividing by √3, and the second click to +X must put vertices on ±X (flats top/bottom). Today `tool_variant == "across_flats"` forces `start_angle = 30°`, which puts a vertex on +Y. Default the hex tool to that AF orientation. |
| 3. Smart Dimension | `SketchMode._click_smart_dim` / `constrain`: circle → `diameter` (kernel `ConstraintType::Diameter` already solves), not `radius`. Two lines → the measured angle, then the dim blank edits it (45°). The current code passes `PI * 0.5`. Centre-to-flat and centre-to-centre: point-to-line and point-to-point. Solver `ConstraintType::Distance` is only `addConstraintP2PDistance`. Add `addConstraintP2LDistance` (already on PlaneGCS, `GCS.h`) for a point to a line, and use it for centre → flat. Double-click uses the existing `dimension_edit_requested` → `set_dimension_value` path; it must call `graph_update_sketch` and regenerate downstream extrudes when the sketch is already a feature. |
| 4. Relations | `constrain("midpoint")` must add `ConstraintType::Midpoint` (solver already implements it). The current body adds `point_on_line` plus a distance of 1 mm, which is not a midpoint. `constrain("concentric")` should add `concentric`, not a center-coincident pair that fails when roles differ. Tangent stays `ConstraintType::Tangent`; the line tool must offer it when the new endpoint lies on a circle (inference today is H/V and coincident only, `INFER_TOL`). Horizontal/vertical already exist. |
| 5. Empty part, Top plane, Normal To | `Main._do_new` inserts `box` 50×50×5 and selects it. New part: empty document, sketch plane XY through the origin, camera normal to that plane (`SketchMode._enter_camera` / `OrbitCamera.enter_sketch_view`). The plate primitive stays on the palette for the old tests that call `insert_primitive`. A full datum tree is not required for this rung: Top = the XY plane at z = 0. `Look at` (`_ctx_look_at`) stays the Normal To action for a selected face. |
| 6. Sketch on a face, snap to model | `derive_face_plane` puts the sketch origin at the face bbox centre, so sketch `(0,0)` is not the part origin and not the Ø20 centre. For a face sketch, project the part origin onto the plane and snap to it. `refresh_sketch_intersections` only adds edge pierces. Also project circle/arc centres of the face's edges (the Ø20 and Ø45 centres) into `intersection_points`, and snap to them. `target_fid` is already set, so the later cut has a body. |
| 7. Extruded cut Blind / Through All / Up To Surface | Finish bar gains Up To Surface. It stores `end=to_face` and the picked face id. Kernel: measure along the signed extrude direction (the cut's negated distance), not along the outward normal with `max(1e-3, dot)`. `graph_add_extrude` must persist `to_face`. Editing the base extrude distance 10 → 14 regenerates the cut (already how `graph_set_params` works) and the cut must still exit the bottom. Blind 10 on a 14 mm body is the failure the thick checker looks for. |
| 8. 3-point centre rectangle, centreline, trim | Add a rect variant `center_three_point`: click 1 = centre, click 2 = direction and half-length of the long side, click 3 = width. Width and angle are then driving dims (20 mm, 45°). Centreline is `Tool.CENTERLINE` (construction line); the jaw centreline is one construction line through the rectangle centre, perpendicular to the long sides. `trim_at` / power-trim drag already shorten lines and turn circles into arcs. The jaw result is one open profile: the outer half of the 20 mm slot plus the head arc that remains after the trim. Extend trim so a drag across the construction half removes those edges and leaves the arc. Do not add an "open-end jaw" feature. The hex opening stays a hex. |
| 9. Pocket Type / Diameter / Depth | `select_ray` on a through-void: if the ray passes near a hole axis (same test as `hole_feature_near_point`, radius = circumradius `AF/√3 + 0.5`, expression diameters evaluated, not replaced with 20), emit `hole_feature_picked` instead of clearing the selection. `show_hole_feature` runs. Diameter shows `=jaw_af+clearance`. Editing it writes `graph_set_params` (already `_on_hole_diam_expr_submitted`). Depth 0 stays through. This panel is how AF = 20 and clearance = 0 are typed on the hex tool. The wrench jaw itself is the sketch cut in gap 8, at AF 20 with no clearance term. |
| 10. AF regen and resize stay on the face | After `jaw_af` changes and inside `resize_primitive_aabb`, run the same `_clamp_point_on_face` margin as place (`AF/√3 + 0.5`) before regenerate. If the face cannot hold the hex, do not cut a notch: leave the previous position and set `last_graph_error` so the AF chip toasts it (`viewport_interaction._ctx_jaw_af` and `variables_panel.gd` already read that string). |
| 11. Fillet sets | One fillet feature, many edges: `graph_add_fillet` already takes an edge list. Face pick: resolve every edge of that face (new helper next to `get_edge_ids` / `get_face_ids`) and add them, including hole, jaw, and slot rims. R10 on the two concave neck edges is two edge picks, one commit. Radius check in `feature_ops::apply_fillet_chamfer` (`sxkernel/src/features/ops_dress.cpp`): if the radius is greater than half the local wall or slot depth, fail with a reason that includes the limit (slot floor 2.5 → "max 1.25"). `mk.IsDone() == false` must stay a hard failure (`fillet failed` plus the OCCT reason). The soft-skip that returns true is only for a missing edge id after an upstream regen, not for a radius the user just typed. |
| 12. Straight slot + blind 2.5 | `SketchMode._add_slot` hardcodes `half_w = 4` and builds the caps from 8 line segments. Replace with two lines and two real arcs (`add_arc`), radius and centre-distance driven by the dim blank (R5, 150). The slot sketch is on the top face; Cut + Blind 2.5 uses the existing extrude distance. Floor at z = 7.5 on a 10 mm body. |
| 13. Numeric hole placement | Face sketch plus a coincident/concentric relation to the projected Ø20 centre (gap 6) places the Ø10 hole. The hex panel is not the way to put that hole on the arc centre. A typed X/Y on the hole feature is enough for the hex tool (params `position` already exist) and is the fallback the pocket panel exposes. |
| 14. Hex move stays available | Selecting the pocket sets `_selected_hole_fid` and does not clear it on regen or resize. Move is a strip/panel action that arms `HOLE_MOVE` until Esc, using `_hole_move_position` (already projects onto the entry face). A later face click moves again. An empty-body selection change is what clears it today; stop clearing the id across `graph_changed` that was caused by the move itself (`_set_hole_position` already re-calls `show_hole_feature`). |
| 15. TriBall | `_do_new` does not select the new body. Body select does not call `_ctx_triball`. One Esc in `_gui_key` drops the gizmo and the selection together; `Main._unhandled_input` must not handle that same key again. `_on_press` does not start a ring drag unless the user pressed the TriBall button. |
| 16. Timeline | Rows already exist. The rung-1 walk opens View → Timeline (`show_timeline`) and sees Sketch / Extrude / Cut-Extrude / Slot / Fillet in order. Double-click a sketch row calls `SketchMode.begin_edit`. Double-click an extrude row opens the distance (and end) in `PropertyPanel`. Editing regenerates downstream. Do not force the timeline on for every New; the empty-part status line tells the user how to open it. |
| 17. 3MF at z = 0 | `export_3mf` already writes model coordinates and `unit="millimeter"`. The sx-017 mesh at z −2.5…7.5 was the hole parked at mid-thickness, which PR #44 fixed for the hex. The extrude of a sketch on z = 0 must prism along +Z so the bbox minimum z is 0. No bed offset in the exporter. Assert this in the e2e export. |

## Work packages

Four packages. File owners are exclusive so three agents can run together. WP4 merges last and is the only one that edits the `Makefile`.

Shared rules for every package:

- Tests drive the same controls a user uses (`FilmUI` / viewport `_input` / the rail button's `pressed` signal). Private helpers are for assertions after the click, not instead of the click. See `.cursor/rules/gdscript-click-driven-tests.mdc`.
- Do not "fix" the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (they assume `nav_preset == SOLIDEXPRESS`; the default is `FUSION`), or the one known failure in `run_infer_tests` and `run_icon_tests`.
- Kernel tests are picked up by `file(GLOB)` in `sxkernel/CMakeLists.txt`. Godot scripts are not. Until WP4, run a new script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`.
- `user://` paths passed into `SxDocument` must be `ProjectSettings.globalize_path` first.

### WP1 — Empty part, TriBall, hex edit/clamp

Unblocks critique leftovers sx-019 #1–#4 and gap 5's empty document. Does not by itself pass `check_rung01.py` (the nut and wrench are sketch solids). It stops the click-eaters so WP2's tools can be used.

**Scope.** Gaps 5 (empty part + XY sketch entry), 9, 10, 13 (typed X/Y on the existing hole params only), 14, 15. Face→edges for fillets is WP3; WP1 only stops TriBall from eating the edge click.

**Files.**

- `game/scripts/main.gd` — `_do_new` only (empty document, no `insert_primitive`, no `select_entity`, no second Esc handler for the same keypress).
- `game/scripts/viewport_interaction.gd` — `_sketch_input` stationary-release, `_gui_key` Escape, `_on_press` TriBall, `_ctx_triball`, `_refresh_selection_strip`. The stationary-release fix lives here because this file owns the mouse-up. `reject_tiny_draw` itself stays in WP2's file; WP1 stops calling it for a zero-travel release.
- `game/scripts/ops_panel.gd` — `show_hole_feature`, `_on_picked`, `_on_selection_changed`, `_resolve_hex_place`, `_ctx` is not here; the AF reclamp helper called from the jaw chip.
- `game/scripts/document_view.gd` — `select_ray`, `hole_feature_near_point`, `resize_primitive_aabb`.
- `game/scripts/variables_panel.gd` — call the same reclamp WP1 adds, after `set_variable("jaw_af")`.
- Tests: extend `game/tests/run_wrench_through_tests.gd` and `game/tests/run_triball_hex_polish_tests.gd`. Add `game/tests/run_rung01_chrome_tests.gd`.

**Acceptance.**

- File → New leaves `body_ids()` empty and `triball.active == false`. The next viewport click is not a ring drag.
- One Esc from a selected body clears the selection. A second Esc is a no-op.
- Place a hex by Insert → Hex opening and a viewport click. Click the pocket void and the rim. Both open Type = hex, Diameter text contains `jaw_af`, Depth = 0. Neither click reports `Selection cleared` or selects only `Box`.
- Set clearance to 0 and diameter to 20 (expression or number). The cut AF is 20 ± 0.2, still through (z samples only the plate min and max).
- AF 14 with the hex near a short edge: the hex stays fully on the face, or `last_graph_error` is non-empty and the notch is not written. Volume-only growth is not enough.
- Resize W on that plate: the hex stays fully on the face.
- Move, change AF, then move again with a face click. The second move changes XY and keeps Z on the entry face.
- `run_wrench_through_tests.gd` and `run_triball_hex_polish_tests.gd` still pass, including the cases that currently call `show_hole_feature` directly — add the click path beside them, do not delete the volume checks.

**Depends on.** Nothing. Merge any time.

### WP2 — Sketch tools the tutorial names

Unblocks the nut solid and the wrench blank, jaw profile, and slot profile. `check_rung01.py nut` should pass from this package plus the kernel that already extrudes a closed face. Wrench bbox, jaw AF, pivot hole, and slot width/depth/length pass once the cuts use Through All or a fixed Up To Surface. R10 / R1 checks stay red until WP3. `thick` passes if the jaw cut's `end` is `through_all` or a working `to_face`.

**Scope.** Gaps 1 (UI half), 2, 3, 4, 6, 8, 12, and the finish-bar half of 7. Gap 16's double-click dim edit while a sketch session is open.

**Files.**

- `game/scripts/sketch_mode.gd` — tools, snap, constraints, `finish_extrude`, `profile_is_closed`, `reject_tiny_draw`, slot, rect variant, trim.
- `game/scripts/sketch_context_chrome.gd` — Up To Surface item, AF/diameter presentation on the dim blank. Do not change the `finish_requested` signal arity (`Main._on_sketch_finish` is WP1's file). Stash the up-to face on the chrome object; `finish_extrude` reads it.
- `sxkernel/src/solver_planegcs.cpp` — `addConstraintP2LDistance` for point-to-line distance only.
- `sxkernel/tests/test_sketch.cpp` — one case: point-to-line distance solves (centre to a hex flat = 10 → AF 20).
- Tests: `game/tests/run_rung01_sketch_tests.gd`.

**Acceptance.** Headless, through the rail buttons and viewport clicks:

- Two clicks place a line between them. A drag still places one line, not two.
- Circle centre on the origin, dim Ø10. Solved radius 5.
- Polygon, 6 sides, second point on +X, AF typed as 20. Flats at y = ±10, vertices on ±X. Extrude 7.5. One solid, bbox min XY 20 ± 0.2, max XY 23.09 ± 0.2, z 7.5, and a Ø10 inner loop is a hole (ray through the axis misses solid; a point at r = 8 is solid). Export is WP4; this test may call `export_3mf` only as an assertion helper after the UI built the body.
- Two circles, Ø20 at origin and Ø45 at (200, 0), two lines tangent to the small circle. Extrude 10 with all contours selected. Bbox about 232.5 × 45 × 10 before cuts (x from −10 to 222.5).
- Face sketch on the top: snap to the Ø20 centre, Ø10 circle, 3-point centre rectangle width 20 at 45°, midpoint of rectangle centre to the Ø45 centre, construction centreline, trim to the open jaw. Cut, end Through All or Up To Surface. Jaw ray checks from `check_rung01.py` (open at u = 3/11/18 for z = 0.5, 5, 9.5; floor at u = −1; AF 20 at z = 2/5/8).
- Slot R5, 150 between centres, centres at x = 18.5 and 168.5, blind cut 2.5. Width 10, length 160, floor z = 7.5.
- Double-click the jaw width 20 → 21, rebuild, jaw AF 21 ± 0.2, angle still 45°.
- `Failed to add sketch` / `Failed to save sketch`, if they still happen, include `last_graph_error()` in the status and the test fails with that string.

**Depends on.** WP1 for a usable empty part and for Esc/TriBall not eating sketch clicks. The sketch tests can build the document by the New menu once WP1 has merged. Until then, the sketch script may start from an empty `SxDocument` only inside a setup that still presses the Sketch tool and clicks the viewport; do not call `sm.click` as the only driver.

**Up To Surface wiring.** Pass `end=to_face` through the existing `graph_add_extrude` argument. Also store the bottom-face id on the feature (`params.to_face`) via `graph_set_params` after the add. Current kernel math collapses that id to a 0.001 mm cut (root cause 7). WP2's own jaw test should use Through All, which already survives a later thickness edit, and should assert the `to_face` param is stored. WP3 makes the face id actually cut to that face. WP4's e2e uses Up To Surface only after WP3 has merged.

### WP3 — Cut to a face, fillets, profile weld

Unblocks `check_rung01.py` R10 (both signs), R10 not oversized, the four R1 checks, the slot-floor fillet, and `thick` when the cut is Up To Surface rather than Blind. Also the kernel side of gap 1 if a solved hex still fails `contour_faces`.

**Scope.** Gaps 1 (kernel tolerance), 7 (signed `to_face`), 11, 17 (only if an export is not at z = 0).

**Files.**

- `sxkernel/src/features.cpp` — extrude `to_face` distance sign; do not change hole clamping (WP1).
- `sxcore/src/sx_document.cpp` / `sxcore/src/sx_document.hpp` — `graph_add_extrude` persists an optional `to_face` id. Default `""` so current GDScript calls keep working.
- `sxkernel/src/sketch.cpp` — only if a coincident hex from `test_sketch.cpp` / a new `sxkernel/tests/test_rung01_profile.cpp` still returns `profile has an open loop`. Fix is a weld at the solver's written tolerance, not a looser silent accept of a real gap.
- `sxkernel/src/features/ops_dress.cpp` — radius limit message; soft-skip stays limited to missing edge ids.
- `sxkernel/include` face-edge query if one does not exist, plus the GDExtension binding in `sx_document.cpp`.
- `game/scripts/fillet_sets.gd` (new) — given a face id, collect its edges and call the existing fillet command. `Main` already connects fillet through `OpsPanel`; this script is invoked from `OpsPanel._accumulate_dressup_edge` **only if** that edit is done in WP1. To avoid sharing `ops_panel.gd`, WP3 exposes `FilletSets.edges_of_face(doc, body, face)` and a headless test calls `graph_add_fillet` with that list. WP4's e2e performs the face click. WP1 does not edit fillet functions.
- `game/scripts/timeline_panel.gd` — double-click a sketch row enters `begin_edit`; double-click an extrude row opens `PropertyPanel` on distance and end. This file is otherwise unowned.
- Tests: `sxkernel/tests/test_rung01_extrude.cpp`, `game/tests/run_rung01_fillet_tests.gd`.

**Acceptance.**

- Kernel: plate extruded 10 from a sketch, cut with `end=to_face` and the bottom face id, then the base distance edited to 14. Solid z extent 14. A ray through the cut is open at z = 0.5, 7, and 13.5. The same cut with `end=blind` and distance 10 fails that ray on the 14 mm body (locks the checker's intent).
- Kernel: hexagon plus inner circle extrudes to a solid with a hole (if this fails on current `contour_faces`, the weld fix lands here).
- Fillet R10 on the two neck edges of a sketch-built wrench blank: material at (179, ±10.5, 5), none at (174, 12.5, 5). One feature, both edges.
- Face fillet R1 on the top face: no material at (−9.9, 0, 9.9), solid at (−9.7, 0, 5). Same for the bottom face and the slot floor (material at the floor corner `(x_slot, 4.9, 7.6)`).
- Fillet R1.5 on the slot floor is refused. `last_graph_error` contains a numeric limit (1.25). The body is unchanged.
- Export of a sketch extrude from z = 0 has minimum z = 0 ± 0.01. If it does not, the fix is `export_3mf`, not a camera offset.

**Depends on.** Nothing for the kernel tests (they build sketches in C++). The Godot fillet script needs a body; it may construct that body through the kernel binding and then click Fillet in the UI. It does not need WP2's rectangle tool. Merge any time. The face-id cut is what WP4's Up To Surface step requires.

### WP4 — Rung-1 end-to-end and the checker in CI

**Scope.** The tutorial walk as one headless test, both 3MF files, the thickened file, and `check_rung01.py`. No new modelling behaviour except a bug found by that walk.

**Files.**

- `tools/check_rung01.py` — the critic's checker, unchanged.
- `game/tests/run_rung01_wrench.gd` — the walk below.
- `Makefile` — append `run_rung01_chrome_tests.gd`, `run_rung01_sketch_tests.gd`, `run_rung01_fillet_tests.gd`, and `run_rung01_wrench.gd` to the `test-godot` recipe. This is the only `Makefile` edit.

**The walk** (same controls as the tutorial; one `SceneTree` script):

1. File → New. Assert no bodies. Start sketch. Camera normal is along Z (Top).
2. **Nut.** Polygon 6 at the origin, AF 20 by dimension (centre-to-flat 10). Circle at the origin, Ø10. Extrude Blind 7.5. Export `user://rung01/nut.3mf` via `export_3mf` (globalize the path). Quit sketch.
3. File → New again.
4. **Blank.** Circle Ø20 at origin, circle Ø45 at (200, 0), two lines tangent to the Ø20. Select all three contours. Extrude Blind 10.
5. **Hole + jaw.** Sketch on the top face. Circle Ø10 concentric with the Ø20. 3-point centre rectangle, width 20, long side 45°, centre midpoint-locked to the Ø45 centre. Construction centreline. Trim to the open jaw. Extruded Cut, Up To Surface, bottom face.
6. **Slot.** New sketch on the top face. Straight slot, R5, centres 150 apart at x = 18.5 and 168.5. Extruded Cut Blind 2.5.
7. **Fillets.** One fillet, both neck edges, R10. One fillet, top face, R1. One fillet, bottom face, R1. One fillet, slot floor, R1.
8. Export `wrench.3mf`. Open the timeline, set the base extrude distance from 10 to 14 only, export `wrench-t14.3mf`.
9. Shell out to `python3 tools/check_rung01.py` for `nut`, `wrench`, and `thick 14`. Non-zero exit fails the Godot script.
10. Process assertions inside the Godot script: timeline order contains a sketch, an extrude, two cuts, and two fillets; jaw dim 20 edited to 21 changes the 3MF AF to 21 ± 0.2 at 45°; fillet 1.5 on the slot floor is refused; New did not arm TriBall; one Esc clears it if the user armed it.

**Depends on.** WP1, WP2, and WP3 all merged. This is the package that turns the three red checker groups green together.

**`check_rung01.py` mapping.**

| Package | Checker rows it is responsible for |
|---|---|
| WP1 | None of the 3MF rows. Process: TriBall, pocket panel, AF stays on the plate. |
| WP2 | `nut` 7/7. `wrench` bbox, closed mesh, orientation, pivot hole, jaw open / floor / AF, grip slot presence, floor, width, length, solid below. `thick` if the cut was Through All. |
| WP3 | R10 ±Y, R10 not oversized, R1 top, R1 bottom, outer wall mid-z, R1 jaw top edge, slot-floor fillet. `thick` for Up To Surface. |
| WP4 | All of the above, in one script, plus the 20 → 21 edit. |

## Merge order

```
WP1 ──┐
WP2 ──┼── WP4
WP3 ──┘
```

WP1, WP2, and WP3 are independent. WP2's jaw test uses Through All so it does not depend on WP3's `to_face` sign fix. WP4 is the first consumer of Up To Surface with a face id.

## Deferred

Recorded here so the next rung does not get built into this cut.

- Rungs 2–8: shell, sketch on a side face, swept boss, revolve, circular pattern, mirror, assemblies and mates. The pipe (rung 5) and the pipeline assembly (rung 8) reuse this nut and this wrench; they are not part of the wrench file.
- Threads, clearance added to the jaw, a named AF parameter, configurations. The tutorial is zero clearance. `jaw_af+clearance` stays the hex-tool default; the wrench jaw dimension is the number 20.
- A general datum FeatureManager (Front / Right planes, offset planes) beyond Top = XY.
- An open-end-jaw feature that skips the rectangle and the trim.
- Shell, draft, sweep, loft, patterns, and mirror, except where a fillet or an extrude already calls them.
- The known `nav_preset` test mismatches and the single `run_infer_tests` / `run_icon_tests` failures.

## Critique score

The checker is necessary and not sufficient. Rung 1 is Done only when one build, in one critique, follows every tutorial step with the named tool, scores ≥ 9, and the three `check_rung01.py` commands pass. A package that turns checker rows green by extruding a hand-built kernel sketch has not finished that step.
