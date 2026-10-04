# Rung 1 replan 3 — thickness 7.5, a closed wrench blank, an honest walk

Status: plan only. No product code in this change.

Baseline: `main` at `c967f4e5` (merge of #67). Replan 2 is [`rung-01-replan-2.md`](rung-01-replan-2.md) (WP1–WP6, PRs #59–#67, all merged). The sx-023 critique of local OCCT 8.0.1 build sha256 `4719c4313cd7a64f440105e0652b3b2b453b1cc7787ab919fa787dc33f808180` scored 6/10 and failed rung 1. Symptom list: [`rung-01-leftovers-sx023.md`](rung-01-leftovers-sx023.md). This replan names the root cause of each leftover at `c967f4e5`, the fix, and an acceptance check a person can perform with the mouse and the keyboard at 1280×800.

BUILD agents execute one WP each. Packages do not edit the same files. WP7 merges last.

## Goal

A person using only the GUI, at **1280×800**, follows the UBC ELEC391 handout:

- Exercise 1, hex nut. Polygon across flats 20, circle bore Ø10 (radius typed as 5), extrude Blind 7.5. The solid is 7.5 mm thick, not 20.
- Exercise 2, wrench. Circles Ø20 at the origin (radius typed as 10) and Ø45 at (200, 0) (radius typed as 22.5), upper and lower tangent lines, extrude Blind 10. The blank is 232.5 × 45 × 10. No Thin wall. No Insert Box. Top-face sketch: Ø10 hanging hole, open jaw across flats 20 at 45° cut Up To Surface (the bottom face, picked in the viewport), grip slot 160 × 10 × 2.5, fillets R10 at the neck and R1 on the top, bottom, and slot floor. R1.5 on the slot floor is refused and the body does not change.
- Timeline edits. Base extrude Distance 10 → 14, kept after Enter and after clicking away. Jaw width dimension 20 → 21, angle still 45°.

The 3MF files are written by File → Export 3MF. Tolerance ±0.2 mm. Do not edit `tools/check_rung01.py`. On this tip the checker prints nut 7 rows, wrench 22 rows, thick 4 rows. Pass is exit code 0:

```
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # all rows, exit 0
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Rung 1 is done when one GUI critique follows every handout step with the named control, those three commands pass on files the export dialog wrote, the headless walk prints 0 failures, and the score is at least 9. A package that keeps the checker green by turning inference off, assigning a fillet radius, or emitting `text_submitted` has not finished its step.

## Situation

sx-023, desktop 1280×800, Godot on llvmpipe, tip `c967f4e5`. Overall **6/10**, rung 1 **FAIL**. A student still cannot finish the handout: the nut is 20 mm thick, and the wrench blank never becomes a solid.

| What replan 2 fixed in the GUI | What sx-023 still got |
|---|---|
| Digits `20` / `5` reach the dim blank with no pre-click. Status `Polygon AF 20.0000`, `Circle r=5.0000 (Ø10.0000)`. Nut AF / AC / bore / closed mesh pass (6/7). | Finish-bar Distance never became 7.5. Extrude built thickness **20.0**. Status never showed a committed distance. |
| Chips sit under the finish bar. Empty-sketch Exit confirms. Export status is `Exported 3MF → <path>`. | Wrench circles + tangent lines: `Extrude failed — open profile. Close it (or set Thin wall > 0)`. Walker inserted a Box 232.5×45×10. Jaw, Up To Surface, slot, and fillets were not reached. |
| Headless walk claims the operator's gestures at 1280×800. #66 claimed 238/0. | Local OCCT 8.0.1 run of `run_rung01_wrench.gd` is **238 checks, 20 failures**. Fillet `limit 1.250` on top, bottom, and slot floor. Wrench / t14 / af21 3MF refused as an open mesh (`744/1731 edges not shared twice` on the wrench). Jaw long-side angle `0.000` after the AF21 edit. Timeline fillet count short. |
| | Thick edit on the fallback Box: `wrench-t14.3mf` still Z=10 (thick 1/4). |
| | Up To Surface bottom-face pick: not reached. |
| | Typing a full path in the export name field still sometimes appends. Preselected basename replace works. |

Do not re-open the rows in "Out of scope" unless a new GUI walk shows they regressed.

## Why the GUI nut is still 20

`SketchContextChrome._on_distance_text_changed` refreshes `ExtrudeReadout` and does not write the parsed number onto `_extrude_spin.value`. The spin is constructed at 20, `update_on_text_changed` stays false, and `.value` stays 20 until SpinBox applies. `_emit_finish_requested` and `extrude_distance()` parse the LineEdit, so a field that actually contains `7.5` is sent. The GUI field never contained `7.5`.

Unfocused digits are routed only while `has_single_dof_preview()` is true (`ViewportInteraction._try_consume_preview_length_key` → `focus_dim_for_typing`). That is how AF 20 and radius 5 landed without a click. After the bore is committed there is no preview. Typing `7.5` does not enter the Distance spin. The sketch lock no longer treats `7` as a camera key, so the digit is dropped. Readout stays `Extrude 20 mm`. Status is unchanged because `_finish_feature` emits nothing on success.

`Main._rail_finish_extrude` starts from 20. If `extrude_distance()` cannot parse, it returns that 20 and still extrudes. The finish-bar button refuses a bad parse. The rail button does not.

The sx-022 "press Enter in the test, not in the GUI" gap is closed for a field that already holds `7.5`. This failure is the digit never arriving, and a stale 20 still being a legal extrude.

## Why the wrench blank is still open

`finish_extrude` solves, calls `_seal_tangent_bosses` (endpoints must already lie within 0.05 mm of the circle), then `profile_is_closed` at 1e-6 mm. The GUI draws with inference on. `_infer_line` adds horizontal, tangent, and on-circle, then `run_solve()`. The Ø20 and Ø45 circles are not locked, so the solver is free to move a boss to satisfy the tangent. The line ends leave the circles, the seal does not see them, and the status is exactly:

`Extrude failed — open profile. Close it (or set Thin wall > 0)`

The headless blank does not take that path. `run_rung01_wrench.gd` sets `sm.infer_enabled = false` for the two shaft segments, with the comment that a tangent constraint on an under-defined circle drags the Ø20 off the origin. Clicks are 0.35 mm off the rim so snap closes them. Inference off is why the walk can extrude and the GUI cannot.

`_try_close_open_chain` only joins two open line ends. It does not weld a tangent onto a circle. Do not loosen the 1e-6 chain tolerance in `sxkernel/src/sketch.cpp`.

The same sentence offers Thin wall as the recovery. The walker then inserted a Box. That is not a closed blank.

## Why 238/20 and the thick edit

`apply_fillet_chamfer` (`sxkernel/src/features/ops_dress.cpp`) refuses when `asked > limit`. R1 is under the slot-wall half-span of 1.25, so that check does not fire. `BRepFilletAPI_MakeFillet::IsDone()` is still false (seams and tangent junctions on the face). The failure string is then `fillet failed (limit 1.250)` even though the asked radius was legal. `fillet_unified` does not recover. The walk's R1 top, bottom, and slot-floor fillets fail, the timeline fillet count stays short, and the 3MF gate correctly refuses the open mesh (`3MF mesh is open (744/1731 edges not shared twice)`). R1.5 on a 2.5 mm slot floor must still fail, and that message must still contain `1.25`.

The walk never types the fillet radius. `_arm_fillet` assigns `spin.value = radius`. `_commit_fillet` emits `text_submitted`. `tools/lint_rung01_e2e.py` does not see either call. #66 can be green on a harness that skips the gesture the GUI uses, and this tip's OCCT 8.0.1 run fails the product checks that the harness does perform. Do not delete those checks. Do not relax `tools/check_rung01.py` or the edge-count gate in `export_3mf`.

After the width label is set to 21, `_long_side_angle_deg` is 0. The centre-rectangle angle-to-horizontal does not stay driving when only the width distance changes, so the jaw flattens.

The thick file is Z=10 because the walker edited the fallback Box. A primitive has W/H/D (`a`/`b`/`c`), not Distance. `_focus_extrude_distance` focuses `_first_spin`, which is W. The handout edit is the base extrude feature's `distance` param. Property spins still leave `update_on_text_changed` false (`SxUi.configure_spin`). `_set_param` runs from `value_changed`, which waits for SpinBox apply on Enter or focus exit. Export can take focus and drop the spin in the same turn, so the graph param stays 10.

## Work packages

Seven packages. File owners are exclusive.

| WP | Owns | Leftover |
|---|---|---|
| WP1 | `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan3_distance.gd` | P0.1 chrome half |
| WP2 | `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan3_input.gd` | P0.1 unfocused digits, P0.4 face pick |
| WP3 | `game/scripts/sketch_mode.gd`, `game/tests/run_rung01_replan3_blank.gd` | P0.2 closed blank, jaw angle held at 45° |
| WP4 | `game/scripts/property_panel.gd`, `game/scripts/timeline_panel.gd`, `game/tests/run_rung01_replan3_timeline.gd` | P0.5 Distance 10→14 |
| WP5 | `sxkernel/src/features/ops_dress.cpp`, `sxkernel/src/interop.cpp`, `sxkernel/tests/test_rung01_replan3_fillet.cpp`, `game/tests/run_rung01_replan3_fillet.gd` | P0.3 fillets and closed mesh |
| WP6 | `game/scripts/main.gd`, `game/tests/run_rung01_replan3_shell.gd` | P0.1 rail and status, P1.6 absolute export path |
| WP7 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | P0.3 harness, P1.7, full walk. Last. |

Shared rules:

- Window for every new script is `Vector2i(1280, 800)` via `FilmUI.ensure_test_viewport`. The same steps must be doable by a person with the mouse and the keyboard at that size. Headless is the recording of that GUI, not a second path.
- Keys and clicks go through `Viewport.push_input` (`keycode`, `physical_keycode`, `unicode`, `pressed`, then a release), as `game/tests/run_place_tests.gd` does. Menu and OptionButton rows are clicked at the popup item's screen rect.
- Forbidden in every new replan-3 script, and in the WP7 walk: `interaction._input`, `id_pressed.emit`, `item_selected.emit` outside the walk's existing `_pick_end`, `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text`, assigning `SpinBox.value`, `text_submitted.emit`, `doc.export_3mf()`, `infer_enabled = false`, and `dlg.current_path =`.
- `user://` paths passed into `SxDocument` are `ProjectSettings.globalize_path` first.
- Until WP7, run a new Godot script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`. Godot is `tools/godot/godot` (4.7-stable). Do not switch to 4.7.1.
- Kernel tests are picked up by `file(GLOB)` in `sxkernel/CMakeLists.txt`.
- Leave `run_rung01_wrench.gd` unchanged until WP7. WP1–WP6 must keep it compiling. The Enter-then-Extrude path and the second-click Distance path in the current walk must keep working.
- Do not change the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (`nav_preset` defaults to `FUSION`), or the known single failures in `run_infer_tests` and `run_icon_tests`.
- Do not edit `orbit_camera.gd`, `tools/check_rung01.py`, or the replan-2 test scripts.
- Do not loosen sketch chain tolerances (1e-6) or the 3MF manifold gate.

### Published calls

WP1 adds these on `SketchContextChrome`. Other packages call them and do not edit that file.

- `focus_distance_for_typing(seed: String = "") -> void` — focus the Distance LineEdit, select all, and if `seed` is a single float replace the text with it. Stores that number on the spin and on `ExtrudeReadout`.
- `distance_line_parses() -> bool` — true when the Distance LineEdit is one float after prefix/suffix stripping.

`extrude_distance()` stays: on success it stores and returns the parsed number; on failure it emits `distance_rejected(raw)` and returns the previous spin value. WP6 must not extrude when `distance_line_parses()` is false.

WP2 calls `focus_distance_for_typing`. If the method is missing, the no-preclick assertion fails with that gap. The face-pick assertion does not need the method.

WP4 does not add a cross-package method. Double-click on an extrude row already opens the property panel.

WP5 does not add a GDScript method. The fillet radius stays the selection-strip spin. The GUI test types into it.

WP6 reads `distance_line_parses()` and the existing `extrude_distance()`. It does not parse with a second copy of the suffix rules.

### WP1 — Distance stores the number Extrude will send

P0.1, the chrome half. The unfocused-digit route is WP2. The rail and the status sentence are WP6.

**Scope.** `sketch_context_chrome.gd` only.

**Behaviour.**

- Every left click on the Distance LineEdit, including the second click, selects all. Deferred `select_all` runs after the caret click, and a second deferred `select_all` runs on the next frame so the caret cannot win. This is the same pattern as the dim blank, which already works in the GUI.
- Each Distance `text_changed` that parses writes that number onto `_extrude_spin.value` immediately and sets the readout to `Extrude <n> mm`. `.value` must not stay 20 while the line shows 7.5. A later focus-exit apply then rewrites the line as 7.5, not 20.
- Enter (`text_submitted` on the Distance LineEdit) commits that parse, updates the readout, and leaves the spin at the typed number. An unparseable string (`20.07.5`) does not change `.value`, does not emit `finish_requested`, and emits `distance_rejected`.
- `focus_distance_for_typing` and `distance_line_parses` as above.
- Readout name stays `ExtrudeReadout`. Its minimum width fits `Extrude 20 mm` and `Extrude 7.5 mm` without clipping. At 1280×800 the readout's global rect lies inside the viewport and does not intersect the variant-chip bar. The finish-bar Extrude button stays inside the viewport. Do not move the chip row; `place_variant_row` stays as replan 2 left it.
- Do not bring back Cut → Through All. Do not put a `Ø` prefix on the dim blank.

**Headless acceptance.** `run_rung01_replan3_distance.gd` at 1280×800:

- Second click on Distance, key events `7.5`, no Enter. Readout contains `7.5`. `_extrude_spin.value` is 7.5 before Extrude is pressed. Extrude `pressed` sends `finish_requested` distance 7.5. The test source does not contain `set_extrude_distance`.
- Enter after `7.5` leaves the spin at 7.5 and the readout containing `7.5`.
- Text that does not parse (`20.07.5`, select-all failed) emits `distance_rejected` and does not emit `finish_requested`. The spin stays 20.
- Readout global rect is inside the 1280×800 viewport and does not intersect the polygon variant bar. Extrude's global rect is inside the viewport.

**GUI acceptance (same steps, mouse and keys).** Sketch anything closed. Click Distance twice so the digits highlight. Type `7.5`. Do not press Enter. The readout reads `Extrude 7.5 mm`, fully visible, not covered by the chips. Press Extrude. The solid's thickness is 7.5 ± 0.2. Repeat with Enter before Extrude. Repeat by typing `7.5` with Distance not yet focused; that route is WP2, and this package's GUI check is the click path.

**Depends on.** Nothing. Merge any time.

### WP2 — Unfocused 7.5 reaches Distance, and Up To Surface picks the bottom face

P0.1 digit route and P0.4. The chrome method is WP1. The wrench jaw that uses the pick is WP7, after WP3 has a closed blank. This package proves the pick on a rectangular solid so it is not blocked by the open profile.

**Scope.** `viewport_interaction.gd` only.

**Behaviour.**

- While a sketch is active, `has_single_dof_preview()` is false, and no LineEdit / SpinBox has focus, a length key (`0`–`9`, keypad digits, `.`) calls `sketch_chrome.focus_distance_for_typing` with that seed and is marked handled. Further digits in that same unfocused burst append, the same way `_try_append_focused_dim_length_key` appends for the dim blank. Camera nav does not see these keys.
- While `has_single_dof_preview()` is true, digits still go to the dim blank (`focus_dim_for_typing`). Do not send them to Distance. Polygon AF 20 and circle radius 5 without a pre-click stay as they are.
- Outside a sketch, `KEY_1` / `KEY_2` / `KEY_3` / `KEY_5` / `KEY_7` still frame the standard views. Do not edit `orbit_camera.gd`.
- Up To Surface: `_input_up_to_face_pick` already runs before sketch clicks. Keep that order. A left click on a model face while the pick is armed calls `set_up_to_face` with that face and does not call `sketch_mode.click`. A click that misses stays armed and does not start a line. Esc cancels the pick and does not exit the sketch. If a bottom-face click on a 10 mm block still draws sketch geometry or leaves `up_to_face_id` empty, fix `_commit_up_to_face_pick` in this file. The test does not call `set_up_to_face`.

**Headless acceptance.** `run_rung01_replan3_input.gd` at 1280×800:

- Fresh sketch, polygon committed so no preview remains, Distance not focused. `push_input` of `7`, `.`, `5`. The Distance LineEdit text parses as 7.5 and the readout contains `7.5`. The camera basis is unchanged.
- Polygon, first click, preview active, Distance not focused. `push_input` of `2` then `0`. The dim blank contains `20`. Distance still parses as the default 20. Camera basis unchanged.
- Leave the sketch. `push_input` `KEY_1`. The camera frames the front view.
- Build a 40 × 30 rectangle and extrude Blind 10 (typed distance, finish-bar Extrude). Sketch the top face. Draw a circle. Choose Cut, then Up To Surface, by clicking the End popup row (not `set_finish_end`). Extrude is disabled and `up_to_face_id` is empty. A viewport click on the bottom face sets the id, the face label contains `z 0`, and Extrude enables. Extrude. A point at the circle's centre is outside the solid at z = 0.5 and at z = 9.5. Repeating with no face click does not create a cut. Choosing Cut after the face is set leaves End on Up To Surface.

**GUI acceptance.** Same gestures. The critique records the face label and a through hole on this rectangular blank. The wrench jaw is WP7. If `focus_distance_for_typing` is missing, the 7.5 assertion fails and names the missing method. The face-pick assertion stands alone.

**Depends on.** WP1 for the unfocused-digit assertion. Face pick merges any time.

### WP3 — Tangent inference leaves a closed blank, and the jaw angle stays 45°

P0.2. The jaw-angle half of P0.3 (long side reads 0 after width 21). Fillet radius and the open mesh are WP5.

**Scope.** `sketch_mode.gd` only. No edit to `sxkernel/src/sketch.cpp` tolerances.

**Behaviour.**

- Drawing the two shaft lines with inference left on must extrude. Lock each circle's centre and radius before the tangent solve when that circle already has a radius (the typed 10 and 22.5). The solver may slide the line's contact along the circle. It may not translate the Ø20 off the origin or change either radius.
- After that solve, an endpoint that inference marked on a circle is welded onto the circle so the 1e-6 chain and `_seal_tangent_bosses` (0.05 mm) both see a closed wire. `_seal_tangent_bosses` still replaces each boss with its outer arc.
- If the profile is still open, status names the open vertex in sketch millimetres, for example `Extrude failed — open profile at (200.0, 10.4). Close that vertex.` It does not offer Thin wall as the way to finish the wrench blank, and it does not mention Insert Box. Thin wall remains the toggle it already is; the failure sentence is not the place that suggests it.
- A centre-3-point rectangle's angle-to-horizontal stays a driving constraint when the width distance changes. Editing the width label from 20 to 21 leaves the long side at 45° ± 0.2. The width becomes 21 ± 0.2.
- Do not turn inference off inside the product. Do not auto-insert a Box. Construction geometry and the empty-sketch status stay as replan 2 left them. Polygon AF and circle radius commits stay as they are.

**Headless acceptance.** `run_rung01_replan3_blank.gd` at 1280×800. Inference stays on (`infer_enabled` is not assigned).

- Circle radius 10 at the origin, circle radius 22.5 at (200, 0), typed into the dim blank with key events. Line tool. Two segments clicked near the upper and lower external tangents (on the order of a few tenths of a millimetre off the exact contact, not on the exact point). Extrude Blind 10, thin off, no Box. Status does not contain `open profile`. Bbox is 232.5 × 45 × 10 ± 0.2 (x from −10 to 222.5). Both circle radii are still 10 and 22.5 ± 0.05 and the small centre is still the origin ± 0.2.
- A deliberate gap (one tangent missing) fails extrude, status contains `open profile at` and a coordinate, and does not contain `Insert Box` or `Thin wall`.
- Centre rectangle, width label 20, angle label 45, then the width label edited to 21 through the dimension popup (click the label, type, Enter). Long side is 45° ± 0.2. Width is 21 ± 0.2.

**GUI acceptance.** Handout B1 with the mouse: the two circles, then the two tangents snapped by eye, then Extrude Blind 10. The solid matches the bbox above. No Thin feature. No palette Box. A broken tangent shows the open vertex in the status line.

**Depends on.** Nothing to compile. The walk that combines this blank with the nut and the jaw is WP7.

### WP4 — Timeline Distance 14 survives Enter and a click away

P0.5. The feature under test is the base extrude, not the fallback Box.

**Scope.** `property_panel.gd` and `timeline_panel.gd` only.

**Behaviour.**

- The extrude Distance spin selects all on every click, including the second, and when `_focus_extrude_distance` runs. Double-click on an extrude row focuses the spin whose schema key is `distance`, not whichever spin happens to be first.
- The Distance LineEdit commits on Enter and on focus exit by parsing its text and calling `_set_param("distance", n)` before the spin can be freed. A click on empty viewport or on File is a focus exit, so the param is already 14 when Export runs. Partial junk (`10.014` from a failed select-all) does not write. A parsed 14 does.
- Status on a successful write contains `Preview: distance = 14`.
- Cancel still rolls back edits that were previewed. A committed Enter is a preview write, so Cancel undoes it. Clicking away does not Cancel.
- Do not retarget the primitive W/H/D schema. The thick check is extrude `distance`. A Box has no Distance row; the test must not edit W and call it thickness.

**Headless acceptance.** `run_rung01_replan3_timeline.gd` at 1280×800.

- Rectangle extruded Blind 10 through the finish bar (typed distance). Open Timeline from the View menu by clicking the popup row. Double-click the extrude row. The Distance LineEdit is focused and its text is selected. Type `14`, press Enter. The feature param `distance` is 14 ± 0.05. Body bbox Z is 14 ± 0.2. Status contains `distance = 14`.
- Rebuild at 10. Type `14` and do not press Enter. Click empty viewport. Param and bbox Z are 14. Export through the FileDialog (typed path, no `current_path` assignment). `check_rung01.py thick <file> 14` exits 0.
- Type `10.014` into a field that did not select all. Param stays 10. Status does not claim `distance = 14`.

**GUI acceptance.** Same double-click, type `14`, Enter, click empty space, export. The 3MF Z is 14 ± 0.2. Deselect without Enter also keeps 14.

**Depends on.** Nothing. The wrench thick file in the full walk is WP7.

### WP5 — R1 fillets succeed, R1.5 still refuses, the 3MF stays closed

P0.3, the product half. The harness cheats are WP7.

**Scope.** The WP5 row. `interop.cpp` only if a solid that `shape::is_valid` accepts still tessellates with an edge not shared twice. The manifold check stays: an edge whose count is not 2 fails the export, `err` still contains `open`, and no zip is left behind. Do not lower the weld tolerance to hide a gap. Do not edit `tools/check_rung01.py`.

**Behaviour.**

- When `BRepFilletAPI_MakeFillet::IsDone()` is false and the asked radius is less than or equal to the departure limit, recover. Seam-split edges on one smooth boundary are already the `fillet_unified` path; if that returns false, fillet the resolved edges as one smooth chain (unify, then one `Add` per unique curve) or drop the seam duplicate before `Build`. A legal R1 on the top face, the bottom face, and a 2.5 mm slot floor must produce a fillet feature.
- The failure string `fillet failed (limit 1.250)` is only for a radius that exceeds the limit. R1 must not report limit 1.250. R1.5 on a slot floor whose departure limit is 1.25 still fails, the error contains `1.25`, and the body volume is unchanged.
- R10 on the two concave neck edges of a wrench-shaped blank still succeeds.
- A filleted solid that is a valid OCCT solid exports a closed 3MF. If the mesh is open only because of unwelded tessellation, weld at the checker's 1e-6 mm and, if needed, `ShapeFix` the solid before the existing edge count. If the count is still not all 2s, the export fails. Do not return true for an open mesh.

**Kernel acceptance.** `test_rung01_replan3_fillet.cpp`:

- A plate with a 2.5 mm deep slot: fillet radius 1 on the slot-floor edges succeeds. Radius 1.5 fails, the error contains `1.25`, the solid is unchanged.
- Radius 1 on the top outer edges succeeds and does not fail with `limit 1.250`.
- Export of that filleted solid returns true and the mesh report has 0 bad edges. A mesh with a boundary edge still fails and the path is absent.

**Headless GUI acceptance.** `run_rung01_replan3_fillet.gd` at 1280×800. Build a plate and a blind slot through the sketch UI (not `graph_add_fillet` from the test). Arm fillet from the selection strip. Type `1` into the radius spin with key events and press Enter. Click the top face. One fillet feature is added and `last_graph_error()` is empty. Type `1.5`, click the slot floor, Enter. No new fillet, error contains `1.25`, volume unchanged. Type `1`, click the slot floor, Enter. A fillet is added. Export through the FileDialog. The file exists and `check_rung01.py` is not required for this plate; a local manifold count on the 3MF has 0 bad edges (the same rule as `manifold_report`). The test does not assign `spin.value`.

**GUI acceptance.** The same strip, the same typed radii, the same faces, at 1280×800. R1 changes the solid. R1.5 does not.

**Depends on.** Nothing. A full wrench fillet set is WP7, which needs WP3's blank. This package's plate is enough to land the kernel.

### WP6 — Rail Extrude cannot send a stale 20, and an absolute export path replaces

P0.1 status and the rail. P1.6.

**Scope.** `main.gd` only. Do not change `_export_3mf_start_dir` or `_export_3mf_filename`.

**Behaviour.**

- `_rail_finish_extrude` calls `extrude_distance()` only when `distance_line_parses()` is true. When it is false, status is `Cannot read distance: ` plus the raw text, and `finish_extrude` is not called. A typed `7.5` that parses is the distance both the rail button and the finish-bar button send.
- After `finish_extrude` returns with the sketch no longer active, status is `Extrude Blind 7.5000 mm` (the end name and the distance, four decimals). A failure leaves the sketch active and keeps the failure sentence (`open profile at …`, `Up To Surface needs a face`, thin-wall). Do not overwrite a failure with the success sentence.
- Export 3MF: the name LineEdit selects all on open and on every later click, including a deferred select that survives the caret. The first typed character replaces `part.3mf`. If the text is an absolute path, export that path. Do not join it onto `current_dir`. If the line is the suggested name with an absolute path glued on the end (`part.3mf/tmp/nut.3mf` or `part.3mf` plus a path that starts with `/`), take the absolute portion and export that, so a missed select-all cannot append. Success status stays `Exported 3MF → ` plus the full path that was written.

**Headless acceptance.** `run_rung01_replan3_shell.gd` at 1280×800.

- Closed profile, Distance text `7.5` with no Enter, rail Extrude button pressed (the palette/rail control, not only the finish-bar button). Bbox Z is 7.5 ± 0.2. Status contains `Extrude Blind 7.5000 mm`.
- Distance text `20.07.5`, rail Extrude. No new body. Status contains `Cannot read distance`.
- Export dialog: suggested name is fully selected. Key events type an absolute path. The file is written there, not under `current_dir` joined with that path. Status is `Exported 3MF → ` plus that path. The test does not assign `current_path`.

**GUI acceptance.** Type 7.5, click the rail Extrude, read the status line, measure thickness 7.5. In Export, type a full path over the suggested name and confirm the file lands on that path.

**Depends on.** `distance_line_parses` from WP1. Until that method exists, the rail test fails and names the gap. The absolute-path assertion stands alone.

### WP7 — The walk is the GUI, and it does not cheat

P0.3 harness, P1.7, and the combined handout. This is the only package that edits `run_rung01_wrench.gd`.

**Scope.** Extend the walk. Extend `tools/lint_rung01_e2e.py`. Append the six `run_rung01_replan3_*.gd` scripts to the `test-godot` recipe after the `run_rung01_replan2_*.gd` lines. If the walk fails on a bug in a file another package owns, and that package has already merged, WP7 may edit that file to make the walk pass. It does not take the file over for anything else. `tools/check_rung01.py` stays as it is.

**Cheats to remove from `run_rung01_wrench.gd`.**

| Cheat | Where | What the GUI does instead |
|---|---|---|
| `sm.infer_enabled = false` around the shaft lines | blank setup | Inference stays on. Clicks near the tangents. |
| `spin.value = radius` | `_arm_fillet` | Type the radius into the strip spin with key events. |
| `text_submitted.emit` | `_commit_fillet` | Press Enter on that spin. |
| `btn.show_popup()` after the menu click | `_click_menu_item` | The click opens the menu. If it does not, the test fails. |

The lint fails the walk when the file contains any of: `infer_enabled`, `text_submitted.emit`, an assignment to `.value`, `interaction._input`, `id_pressed.emit`, `item_selected.emit` outside `_pick_end`, an assignment to `current_path`, or a root size other than `Vector2i(1280, 800)`. It also scans `game/tests/run_rung01_replan3_*.gd` for `interaction._input`, `id_pressed.emit`, `set_extrude_distance`, `set_up_to_face`, `export_3mf(`, and `text_submitted.emit`. `make test` runs the lint before the Godot suites. The script already `quit(1)` when `failures > 0`. Do not swallow that exit. Do not drop a failing check to shrink 20 failures to 0.

**Changes to the walk** (keep the checks that already describe the handout):

1. **Nut distance, no pre-click.** After the bore is committed and no preview is active, `push_input` `7`, `.`, `5` with Distance not focused. Readout contains `7.5`. Do not press Enter. Press the finish-bar Extrude. Bbox Z is 7.5 ± 0.2 before export. Status contains `Extrude Blind 7.5000 mm`. Export through the dialog. Checker nut exits 0.
2. **Blank with inference on.** Delete the `infer_enabled = false` block. Draw the two tangents with clicks near the contacts. Thin stays off. No Box. Bbox 232.5 × 45 × 10 ± 0.2. Status does not contain `open profile`. The walk does not mention Insert Box as a recovery, in a comment or a status expect.
3. **Up To Surface on the wrench.** Cut, then Up To Surface, by clicking the End row. Extrude disabled, face id empty, pick armed. Viewport-click the bottom face. Label contains `z 0`. Extrude enables. `get_finish_end() == "to_face"` and `up_to_face_id` is the bottom face immediately before Extrude. The wrench checker row `jaw open through full depth` is the proof.
4. **Fillets.** Type R10, R1, and the refused R1.5. Do not assign the spin. R1 top, R1 bottom, and R1 slot floor add a fillet and leave `last_graph_error()` empty. R1.5 adds none, the error contains `1.25`, volume unchanged. Timeline fillet count stays `n_fil >= 2` after the cuts. Do not lower that number.
5. **Thick.** Double-click the base extrude, type `14`, Enter, export `wrench-t14.3mf`. Checker thick exits 0. Also type `14` and click away on a second run, or do the click-away in the WP4 script only and Enter in the walk. The exported Z is 14.
6. **Jaw 21.** Width label 20 → 21. Long side stays 45° ± 0.2 in the sketch and in the af21 3MF. `got 0.000` fails the walk.
7. **Exports.** Each 3MF goes through the dialog. Status starts with `Exported 3MF → `. The mesh gate is unchanged. An open mesh fails the walk.
8. Checker invocations stay `nut`, `wrench`, and `thick` with `14`. Exit code 0. Do not add `--allow-mirror` to hide a mirrored jaw.

**Depends on.** WP1 through WP6 merged.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | Click Distance, type 7.5, spin value and readout are 7.5 before Extrude. No 3MF. |
| WP2 | Unfocused `7.5` fills Distance. Rectangular blank: Up To Surface pick, through hole, Extrude gated on the face. |
| WP3 | Inference-on tangents extrude to 232.5×45×10. Open vertex is named. Jaw width 21 keeps 45°. |
| WP4 | Extrude Distance 14 sticks on Enter and on click-away. Thick checker 4/4. |
| WP5 | R1 fillets succeed. R1.5 refuses with `1.25`. Closed 3MF of that solid. |
| WP6 | Rail Extrude sends 7.5 and status says so. Absolute export path replaces. |
| WP7 | nut 7/7, wrench exit 0, thick 4/4, from those gestures, at 1280×800, lint clean, 0 walk failures. |

## Merge order

```
WP1 ──┐
WP2 ──┤
WP3 ──┤
WP4 ──┼── WP7
WP5 ──┤
WP6 ──┘
```

WP1 through WP6 merge in any order. WP2's unfocused `7.5` is meaningful after WP1. WP6's rail refusal is meaningful after WP1. WP7 is last. sx-024 critique runs on the build that contains WP7.

## sx-024 GUI critique checklist

One session. Desktop **1280×800**. Mouse and keyboard only. No `infer_enabled` toggle, no property JSON, no Box unless a later step of a different part asks for a primitive. Record status text after each step. Export only through File → Export 3MF.

Pass bar: every row below is WORKS, the three checker commands exit 0, `run_rung01_wrench.gd` prints 0 failures, score ≥ 9.

| # | Do this | Pass |
|---|---|---|
| A1 | File → New | `New — empty part` and no body |
| A2 | Sketch on the ground plane | `Sketch on ground (XY)` |
| A3 | Polygon, type `20` with no blank click | Status contains `Polygon AF 20`. Flats at ±10 |
| A4 | Circle, type `5` with no blank click | Status contains `Circle r=5` and `Ø10` |
| A5 | Smart Dimension centre-to-flat | Not this critique. The mandatory nut path is A3 then A4 |
| A6 | Type `7.5` into Distance. Pre-click optional. Do not press Enter. Extrude | Readout `Extrude 7.5 mm` before the click. Status contains `Extrude Blind 7.5000 mm`. Solid thickness 7.5, not 20 |
| A7 | Export `nut.3mf` | Status `Exported 3MF → <path>`. Checker nut 7/7 |
| B1 | New. Circles Ø20 at origin and Ø45 at (200, 0). Upper and lower tangents. Extrude Blind 10. Thin off | No `open profile`. No Box. Bbox 232.5 × 45 × 10 |
| B2 | Top face: Ø10 hole, jaw AF 20 at 45°, Cut, Up To Surface, click the bottom face, Extrude | Extrude disabled until the click. Label `z 0`. Jaw open at z = 0.5 and z = 9.5 |
| B3 | Slot 160 × 10 × 2.5 blind | Slot floor at z = 7.5 |
| B4 | Fillet R10 at the neck, R1 on top, bottom, and slot floor. Then R1.5 on the slot floor | R1 commits. R1.5 status contains `1.25` and the solid does not change |
| B5 | Timeline, base extrude Distance `14`, Enter, click away, export `wrench-t14.3mf`. Then jaw width 20 → 21 | Thick 4/4 (Z = 14). Angle still 45°, not 0 |
| H | `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` on this OCCT 8.0.1 build | `0 failures`. Lint clean. Not a claimed 238/0 from a run that turned inference off |

Score the nut thickness, the closed blank, the face pick, the fillets, the thick edit, and the headless count separately. A Box substituted for B1 caps the score under 9 even if the Box is the right size.

## Out of scope

- Camera number keys versus sketch digits (replan 2 WP6 / #60). Standard views outside a sketch stay.
- Variant chips versus the finish bar at 1280×800 (replan 2 WP1 / #63). WP1 only keeps the new readout from covering that row.
- Empty-sketch Exit confirm (replan 2 WP4 / #64 / #67).
- Nut AF 20, AC 23.094, bore Ø10, and the nut's closed mesh. Those passed at sx-023. Thickness is the nut work in this replan.
- Export status prefix `Exported 3MF → <path>`, dialog `current_dir` / `current_file` on open, and preselected basename replace. P1.6 is the absolute path that still appends.
- Insert Box as a sized primitive. The palette stays. It is not the wrench blank and not the recovery for an open profile.
- A kernel change to chain tolerance, a new constraint type, or a named jaw parameter.
- Rungs 2–8, threads, and a datum tree beyond Top = XY.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `4719c4313cd7a64f440105e0652b3b2b453b1cc7787ab919fa787dc33f808180`. The next critique is a new build that contains WP7.
