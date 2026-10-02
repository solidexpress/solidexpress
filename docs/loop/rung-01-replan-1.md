# Rung 1 replan 1 — a person can build the nut and the wrench

Status: plan only. No product code in this change.

Baseline: `main` at `63fc39f` (PR #49, the v0.0.12 recut). The first plan is [`rung-01-plan.md`](rung-01-plan.md) (WP1–WP4, all merged). The sx-020 critique of build `4b8ca9cf` scored 5/10 and failed rung 1. Leftovers, with the suggested fixes: [`rung-01-leftovers-sx020.md`](rung-01-leftovers-sx020.md). This replan turns each leftover into a root cause at `63fc39f`, a fix, and an acceptance check, then splits the work so parallel agents do not edit the same files.

## Goal

A person using only the GUI follows the UBC ELEC391 handout:

- Exercise 1, hex nut. Polygon across flats 20, circle bore Ø10 (radius typed as 5), extrude Blind 7.5.
- Exercise 2, wrench. Circles Ø20 at the origin (radius typed as 10) and Ø45 at (200, 0) (radius typed as 22.5), tangent shaft, extrude Blind 10. The blank is 232.5 × 45 × 10. Top-face sketch: Ø10 hanging hole, open jaw across flats 20 at 45° cut Up To Surface (the bottom face, picked in the viewport), grip slot 160 × 10 × 2.5, fillets R10 at the neck and R1 on the top, bottom, and slot floor.
- Timeline edits. Base extrude distance 10 → 14. Jaw width dimension 20 → 21, angle still 45°.

The 3MF files are written by File → Export 3MF. Tolerance ±0.2 mm:

```
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

The headless walk on this commit passes 81/81 (nut 7/7, wrench 28/28, thick 4/4) by writing state in code. A real GUI walk produced nut 1/7 (circumradius 20, thickness 20, no Ø10 bore, open mesh) and never extruded the wrench blank. The blank sat as one circle with the status line from the screenshot:

`Extrude failed — is the profile closed? — extrude 2: profile: no usable open line chain for thin profile`

The finish-bar spins are clipped, so `20.0 mm` reads `0.0 mm`. This replan does not add a new solid feature. The kernel path from the first plan stays. The hole is the path from the handout's clicks and keystrokes to that kernel.

Rung 1 is done when one GUI critique follows every handout step with the named control, the three checker commands pass, and the score is at least 9. A package that keeps the checker green by injecting finish-bar state has not finished its step.

## What already exists

Do not reimplement these. The sx-020 headless reference (`nut` 7/7, `wrench` 28/28, `thick` 4/4) already runs them.

| Capability | Where it already lives |
|---|---|
| Closed profile, hole, multi-region blank, tangent seal, jaw trim, centre-3-pt rectangle, straight slot | `SketchMode` in `game/scripts/sketch_mode.gd`, `Sketch::contour_faces` in `sxkernel/src/sketch.cpp` |
| Extrude blind / through_all / to_face / midplane, cut and fuse, signed to-face depth | `FeatureGraph::apply` extrude arm, `sxkernel/src/features.cpp` |
| Up To Surface param stored on the feature after the extrude exists | `SketchMode._store_up_to_face`, `SketchContextChrome.up_to_face_id` |
| Fillet R10 neck, R1 face sets, slot-floor radius limit | `sxkernel/src/features/ops_dress.cpp`, fillet tests |
| Smart Dimension labels, diameter on a circle, angle between two lines, label popup | `SketchMode.click` when the tool is Select, `dimension_hit`, `ViewportInteraction._show_dim_edit` |
| PlaneGCS angle is radians; a typed value greater than π is read as degrees | `SketchMode._dimension_value_for_solver` |
| 3MF millimeters, menu id 11 → `SxDocument.export_3mf` | `sxkernel/src/interop.cpp`, `Main._on_file_menu` / `_on_file_selected` |
| One Esc while Interaction has focus cancels TriBall and clears the selection | `ViewportInteraction._gui_key` |
| Dim blank selects all on the click that gives focus; `release_dim_focus()` exists | `SketchContextChrome` |

## Why the GUI walk and the headless walk disagree

| Path | Wrench | Thick | Nut | What it actually does |
|---|---|---|---|---|
| `game/tests/run_rung01_wrench.gd` as merged | 28/28 | 4/4 | 7/7 | `_commit_dim` assigns `LineEdit.text` and emits `text_submitted`. Op, End, and distance go through `set_finish_op` / `set_finish_end` / `set_extrude_distance`. The bottom face is `chrome.set_up_to_face(bottom)`. Width 20 and 45° are click coordinates. The jaw edit assigns `_dim_edit_line.text`. Export is `doc.export_3mf()`. |
| Same walk, face left as the GUI sets it | 19/28 | 2/4 | 7/7 | `_on_finish_end_selected` copies `view.selected_face`, the sketch host, so the cut has no depth. |
| Operator GUI | cylinder 9/27 | not a wrench | 1/7 | Dim blank appends, spins are clipped, thin wall runs on a circle, Up To Surface has no pick, Esc and Ctrl+A miss the focused control. |

`OptionButton.select` does not emit `item_selected`. The setters used by the test therefore never run `_on_finish_end_selected`. The test cannot see the host-face bug, the append bug, or the clipped spins.

## Leftovers

Numbers match [`rung-01-leftovers-sx020.md`](rung-01-leftovers-sx020.md).

### 1. Up To Surface cannot pick its face — P0 — WP1, WP2, WP3, WP6

**Root cause.** `SketchContextChrome._on_finish_end_selected` (`sketch_context_chrome.gd`) on End = Up To Surface copies `sketch_mode.view.selected_face` when `up_to_face_id` is empty. A sketch on the top face already has that face selected, so the cut targets the host and the depth is zero. Canvas clicks during the sketch are consumed by `ViewportInteraction._input` → `_sketch_input`, so there is no second gesture that can choose the bottom face. `up_to_face_id` is not cleared when a session starts or when End changes, so a stale id survives. The extrude schema in `property_panel.gd` lists `to_face` and has no face row. `SketchMode.finish_extrude` will still extrude with whatever id is sitting on the chrome object.

**Fix.**

- WP1: a `Face:` box on the finish bar. Choosing Up To Surface clears the id, shows `Face: none`, arms a one-shot pick, and disables Extrude. It does not read `selected_face`. `show_for_session(true)` clears the id. Changing End away from Up To Surface clears it. `set_up_to_face` updates the label from the face midpoint (z, so the bottom reads near 0 and the top reads near the blank thickness) and enables Extrude.
- WP3: while the chrome reports a pick armed, the next model-face click (same shape as `_picking_active_plane`) calls `set_up_to_face` with that face, highlights it, and does not place a sketch point. This runs during an active sketch.
- WP2: `finish_extrude` with `end == "to_face"` and an empty id emits `Up To Surface needs a face` and returns before `graph_add_extrude`. It does not fall back to `selected_face`.
- WP6: the extrude property panel grows a Pick face row that calls the chrome `arm_face_pick()`.

**Acceptance.** Start a sketch on the top face of a 10 mm blank. Select Cut, then Up To Surface, by `item_selected` (not `set_finish_end`). Extrude is disabled and `up_to_face_id` is empty. A viewport click on the bottom face sets the id to that face, the label shows a z near 0, and Extrude enables. Extrude. A ray through the jaw is open at z = 0.5 and z = 9.5. Repeating the step with no face click does not create an extrude. A new sketch session starts with an empty id even if the previous session had one.

### 2. Dim blank appends, and bad text commits the rubber band — P0 — WP1, WP3, WP4

**Root cause.** `_dim_spin.select_all_on_focus` runs on the click that gives focus. A second click on the focused LineEdit places the caret at the end, so typing appends (`23.22.5`, reproduced on the Ø45 circle). `ViewportInteraction._input` marks sketch canvas clicks handled, so the blank keeps focus while the user draws. `text_submitted` calls `SpinBox.apply()`. An unparseable string is dropped, `dim_submitted` emits the spin's previous number, and `Main._on_sketch_dim_submitted` calls `commit_at_length` on that rubber-band value. Status even reports a length. The circle stays wrong with no error.

**Fix.**

- WP1: every mouse click in the dim LineEdit selects all, including the click that finds the field already focused. A new tool preview that focuses the blank selects all. `text_submitted` parses the raw string first. On failure it does not call `apply()`, does not emit `dim_submitted`, emits `dim_rejected(raw)`, and sets status `Cannot read dimension: <raw>`. On success it emits `dim_submitted` and releases focus.
- WP3: a sketch canvas click calls `release_dim_focus()` before the click is consumed.
- WP4: connect `dim_rejected` to the status line. `_on_sketch_dim_submitted` stays the success path and does not read the LineEdit to repair a failed parse.

**Acceptance.** Focus the blank, click it again, type `22.5`, press Enter. The committed value is 22.5, not a concatenation. Type `23.22.5`, press Enter. Status contains `Cannot read dimension`, and the in-progress circle keeps its previous radius. Focus the blank, click the canvas, press `1`. The blank is not focused and its text does not gain a `1`.

### 3. Finish-bar fields are unreadable, and Thin looks like Distance — P0 — WP1

**Root cause.** `_build_finish_bar` sizes the dim and distance spins at 88 px and the thin spin at 72 px, each with a `mm` suffix and arrow buttons. The line edit scrolls to the tail, so `20.0 mm` shows as `0.0 mm` (the screenshot's distance and thin fields, and the dim field's `.22 mm`). There is no D or Thin label. Thin defaults to a visible spin at 0, identical in shape to Distance, so a keystroke meant for the blank thickness lands in Thin. `features.cpp` then takes the thin-wall branch. The nut's 20 mm thickness is the distance spin's default (`value = 20`), which the clipped field does not show, so 7.5 never replaced it.

**Fix.** WP1 only. Size the dim and distance spins to at least `UiScale.px(140)` (the floor is `UiScale.px(110)`). Put a `D` label on the distance spin and a `Thin` label on the thin spin. Hide the thin spin, the One Side / Midplane dropdown, and Flip behind a `Thin feature` check that defaults off. When that check is on and the value is greater than 0, show a badge `Thin <n> mm`. Distance keeps its own label so the two numbers cannot be confused. The full string `20.0 mm` fits in the distance line edit without horizontal scroll.

**Acceptance.** Open a sketch. The thin spin is not visible, and Extrude sends `thin_thickness == 0`. The distance spin reads `20.0` (the default) in its LineEdit text, and the control is at least `UiScale.px(110)` wide. Turn Thin feature on, set 1.5, and the badge contains `1.5`. Turn it off and the next Extrude sends 0.

### 4. The e2e walk proves the kernel, not the GUI — P0 — WP7

**Root cause.** `game/tests/run_rung01_wrench.gd` never types a digit, never emits `item_selected`, never clicks a face for Up To Surface, never clicks a dimension label, and never opens the export dialog. Helpers `_commit_dim`, `set_finish_*`, `set_up_to_face`, `_set_extrude_distance`, and `_export_3mf` are the steps the critic could not perform.

**Fix.** WP7 rewrites that script. The walk in WP7 is the acceptance check. Earlier packages leave this file alone so their merges do not depend on the rewrite.

### 5. Thin wall runs on a circles-only sketch, and the banner blames a closed profile — P1 — WP5, WP2

**Root cause.** `FeatureGraph::apply` (`features.cpp`, the extrude arm) calls `Sketch::thin_profile_face` whenever `thin_thickness > 0`. That function (`sketch.cpp`) collects line entities only. A sketch of one circle has no line chain, so the error is `no usable open line chain for thin profile`. `SketchMode.finish_extrude` always prefixes `Extrude failed — is the profile closed?`, which is the screenshot string. The region builder is not the code that failed. Closed circles already extrude when thin is 0 (the headless blank).

**Fix.**

- WP5: if thin is greater than 0 and `thin_profile_face` fails while a closed contour exists (a circle or `profile_face` succeeds), the kernel error is `Thin wall is on (<n> mm) — set 0 for a solid`. The empty line-chain string in `thin_profile_face` says the same thing when the sketch has circles or arcs and no lines. Do not build a thin wall from a circle in this rung.
- WP2: when `last_graph_error()` contains `Thin wall`, the status is that sentence alone. The closed-profile question stays for a genuine open profile with thin at 0.

**Acceptance.** Kernel: a circle sketch extruded with `thin_thickness = 1` fails, the error contains `Thin wall is on`, and no body is added. The same circle with thin 0 extrudes. GUI: with the thin toggle off (leftover 3), one circle extrudes Blind 10. Forcing thin on and pressing Extrude shows the thin-wall sentence and leaves the sketch session up.

### 6. 3MF export writes an open mesh and says Exported 3MF — P1 — WP5, WP4

**Root cause.** `sx::interop::export_3mf` (`interop.cpp`) tessellates and writes the zip. It never checks edge manifoldness. The GUI nut was 29/55 edges not shared twice (`tools/check_rung01.py` `manifold_report`). `SxDocument::export_3mf` (`sx_document.cpp`) drops the `err` string and returns only a bool. On true, `Main._on_file_selected` sets status `Exported 3MF`.

**Fix.**

- WP5: after tessellation, weld vertices at 1e-6 mm (the checker's `np.round(V, 6)`) and count edges. An edge whose count is not 2 fails the export. `err` is `3MF mesh is open (<bad>/<total> edges not shared twice)`. Do not leave a zip behind. Do this in `export_3mf` and `export_3mf_for_body`. Store `err` on `SxDocument` and expose `last_export_error()`. A closed solid still returns true. No other `sx_document.cpp` / `.hpp` edits.
- WP4: a false return sets status `3MF export failed — ` plus `last_export_error()`. A true return stays `Exported 3MF`.

**Acceptance.** Kernel: the headless nut mesh exports; a mesh with a boundary edge does not, `last_export_error()` contains `open`, and the path is absent. GUI: export of a closed blank says `Exported 3MF`. Export of an open mesh says `3MF export failed` and does not say `Exported 3MF`.

### 7. The GUI nut is circumradius 20 and the bore is not a circle — P1 — WP2, WP7

**Root cause.** The exported hex has circumradius 20 (AF 34.641, AC 40). `SketchMode.click` for `Tool.POLYGON` uses the drag or typed length as circumradius unless `tool_variant == "across_flats"`, in which case it divides by √3 and reports AF. `tool_variant` is initialized to `"corner"`. `set_tool(POLYGON)` does not assign a polygon variant (the match falls through). `set_tool(CIRCLE)` assigns `"center"` and `set_tool(RECT)` assigns `"corner"`, so returning to Polygon after either tool is no longer across-flats. The Across Flats chip is the only writer. The clipped blank hides the ` AF` suffix (`_sync_dim_affordance`), so a missed chip is invisible. The inner loop is a polygon at about r = 12.5–14, not a Ø10 circle. The session notes do not say which clicks produced that loop, so this plan does not invent a second bug for it. What the GUI must do is place a circle by typing `5` into the dim blank and keep the polygon variant on across-flats while that circle is drawn afterwards.

**Fix.** WP2: `set_tool(POLYGON)` defaults to `across_flats` and remembers the last polygon variant across re-arms. Switching to Circle or Rect may reset those tools; switching back to Polygon restores the polygon variant. The second click still treats the typed length as AF, puts vertices on ±X, and flats at y = ±AF/2. WP1 already shows a readable ` AF` suffix while that variant is active. WP7 types `20` for the hex and `5` for the bore and runs the nut checker.

**Acceptance.** Fresh sketch, Polygon tool, no chip click: `tool_variant` is `across_flats` and the blank suffix contains `AF`. Type `20` at the origin with the second point on +X. Flats at y = ±10, vertices on ±X. Switch to Circle and back to Polygon: the variant is still `across_flats`. Circle at the origin, type `5`: solved radius 5. Extrude Blind 7.5. Checker nut 7/7, including bore Ø10 ± 0.2 and a closed mesh.

### 8. One Esc leaves the selection and the gizmo — P1 — WP3, WP4

**Root cause.** Two Esc paths. `ViewportInteraction._gui_key` cancels TriBall and clears the selection, and `_input` calls it only when Interaction `has_focus()`. The strip TriBall button takes focus when it is pressed (`_ctx_triball` → `triball.begin`). Esc then falls through to `Main._unhandled_input`, which calls `triball.cancel()` and returns before `clear_selection()`. Handles and the selection stay. A focused LineEdit receives the key in GUI input, because `_input` does not handle Esc without Interaction focus, so neither path runs. Body select does not call `triball.begin` at this commit (`begin` is only `_ctx_triball`). The strip still appears on select, and the next click on that button is what arms the gizmo. The old test presses Esc by `grab_focus()` on Interaction and then `_input`, which is the path that already works.

**Fix.**

- WP3: `cancel_stack()` releases a focused LineEdit, calls `triball.cancel()` when the gizmo is active or visible, and `view.clear_selection()`. One call does all three. Outside an active sketch, `_input` runs `cancel_stack()` on Esc before GUI handling, with or without Interaction focus, and marks the event handled. During a sketch, Esc stays the sketch cancel (length override, tool chain). Clicking a body does not call `_ctx_triball`.
- WP4: `_unhandled_input` on Esc calls `cancel_stack()` when Interaction is present. It does not return after cancelling only the gizmo. The selection clears in that same keypress.

**Acceptance.** Select a body, click the strip TriBall button, and do not move focus back to Interaction. Push Esc with `Viewport.push_input` (the place-test pattern: keycode, physical_keycode, pressed, then release). `triball.active` and `triball.visible` are false, `selected_body` is empty, and the selection strip is hidden. Repeat with a property-panel spin focused: the same key clears the spin focus, the gizmo, and the selection. A second Esc is a no-op. A viewport click on a body leaves `triball.active` false.

### 9. Tangent lines miss the circle by more than the region builder allows — P1 — WP2

**Root cause.** `snap_point` snaps to endpoints, midpoints, centres, the sketch origin, and H/V of the last tool point. It has no tangent snap and no on-circle snap. `_infer_line` will add a tangent and an on-circle constraint inside `INFER_TOL` (0.5 mm) and then `run_solve()`. `_seal_tangent_bosses` only treats an endpoint as on the circle within 0.05 mm. `profile_is_closed` chains at 1e-6 mm and treats a point as on a circle within 1e-4 mm. `contour_faces` splits at 1e-6. A hand-placed upper tangent on Ø45, off the circle by more than 0.5 mm, never gets a constraint, so the blank reports an open loop. The headless blank passes because its endpoints are exact. Loosening `contour_faces` would accept a real gap; the first plan rejected that, and this replan does too.

**Fix.** WP2, in `sketch_mode.gd` only. While the line tool has an anchor, snap the free end to a circle tangent (the segment perpendicular to the radius at the contact) and, otherwise, project onto the circle when the cursor is within the snap radius of the circumference. After those constraints are added, `run_solve()` runs before `_seal_tangent_bosses` and before the profile check inside `finish_extrude`. The solver writes the endpoint onto the circle, so the 1e-6 chain sees a closed wire. `sxkernel/src/sketch.cpp` tolerances stay as they are (WP5's only edit there is leftover 5's error string).

**Acceptance.** Two circles, Ø20 at the origin and Ø45 at (200, 0). Draw each shaft line from the small circle to the large one by clicking near the tangent, not on the exact point. After Extrude Blind 10 with thin off, the bbox is about 232.5 × 45 × 10 (x from −10 to 222.5, ±0.2). Status does not contain `open profile` or `open loop`.

### 10. Ctrl+A in a property-panel spin does not select the text — P2 — WP6, WP3

**Root cause.** `PropertyPanel._add_spin_row` builds a SpinBox by hand: no `select_all_on_focus`, and it does not call `SxUi.configure_spin`. The timeline panel that hosts it is transparent, so the left dock (Spacing / Count, Selection) shows through and a click can focus the control underneath. `ViewportInteraction._gui_key` returns early for a focused spin only when Ctrl is not held, then `KEY_A` with Ctrl calls `_select_all()` on the scene. The cylinder row's double-click starts a rename; the extrude row's double-click does call `_focus_extrude_distance`, which `grab_focus`es the first spin and would select the text if the spin had `select_all_on_focus`. The handout edit is that extrude row (distance 10 → 14), not the cylinder the operator fell back to.

**Fix.**

- WP6: `SxUi.configure_spin` sets `select_all_on_focus`. `_add_spin_row` uses it. `PropertyPanel` and `TimelinePanel` get an opaque background and `MOUSE_FILTER_STOP` so the dock cannot take the click. `_focus_extrude_distance` still focuses the distance spin; select-all-on-focus makes the digits selected.
- WP3: Ctrl+A while `SxUi.numeric_field_focused` or `_text_field_has_focus` does not call `_select_all`.

**Acceptance.** Double-click an extrude timeline row. The distance LineEdit has focus and the text is selected. Typing `14` and Enter stores distance 14 (the spin's value, then the feature param). Ctrl+A with that spin focused selects the line-edit text and does not change the body selection. A click on the panel does not focus a dock control behind it.

### 11. No single-line angle to horizontal, and the label edit is untested — P2 — WP2, WP7

**Root cause.** `ConstraintType::Angle` (`solver_planegcs.cpp`) is a line-to-line angle. `_click_smart_dim` on one line adds a length. An angle requires a second line. The jaw's 45° therefore exists in the test only as the second click of the centre rectangle (`along * 30`). The label path is real for the Select tool: `dimension_hit` emits `dimension_edit_requested`, and `_show_dim_edit` opens `DimEditPopup`. The test assigns `_dim_edit_line.text` and emits `text_submitted`, so a caret or parse bug in that popup never fails the walk. Width 20 and Ø are the same kind of gap.

**Fix.** WP2: committing a `center_three_point` rectangle adds two driving dimensions. The short side is a distance (the 20 mm jaw width). The long side is an angle to a construction line along sketch +X through the rectangle centre. The construction line stays construction so the jaw profile is unchanged. Smart Dimension on a single line, with Select, grows an angle-to-horizontal dimension the same way (a construction +X line plus the existing two-line angle). The label text for an angle is degrees. A typed `45` is greater than π, so `_dimension_value_for_solver` already stores radians. Do not add a kernel constraint type. WP3 already owns the popup; it selects all on every click of `_dim_edit_line` and keeps the popup wide enough to show `45.0`. WP7 clicks the labels and types.

**Acceptance.** Build the centre rectangle, switch to Select, click the width label (viewport click at the label's sketch position, not `dimension_edit_requested` from the test), type `20`, Enter. Click the angle label, type `45`, Enter. The width is 20 ± 0.2 and the long side is 45° ± 0.2. Click the Ø10 circle's diameter label, type `10`, Enter. Solved diameter is 10. Later, the same width label edited from `20` to `21` changes the jaw AF to 21 ± 0.2 and leaves the angle at 45°.

### 12. Export 3MF opens in the app directory with an empty name — P2 — WP4, WP7

**Root cause.** `Main._show_file_dialog` sets the filter and pops the dialog. It never sets `current_dir` or `current_file`. The dialog opens in the process cwd with a blank name. The test never opens it.

**Fix.** WP4: remember the last export directory. For Export 3MF, `current_dir` is that directory, else the document's directory, else the home directory. `current_file` is `<document name>.3mf`, or `part.3mf` when the document has no name. A successful export updates the remembered directory. WP7 opens the dialog from the File menu and confirms it.

**Acceptance.** With no prior export, File → Export 3MF shows a visible FileDialog whose `current_file` ends in `.3mf` and whose `current_dir` is the home directory (or the document directory when the part has a path). Confirming the dialog writes the file through `_on_file_selected`. The next export opens in that file's directory.

## Work packages

Seven packages. File owners are exclusive. WP7 merges last and is the only one that edits `game/tests/run_rung01_wrench.gd` and the `Makefile`.

| WP | Owns |
|---|---|
| WP1 | `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan_finishbar.gd` |
| WP2 | `game/scripts/sketch_mode.gd`, `game/tests/run_rung01_replan_sketch.gd` |
| WP3 | `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan_input.gd` |
| WP4 | `game/scripts/main.gd`, `game/tests/run_rung01_replan_shell.gd` |
| WP5 | `sxkernel/src/features.cpp`, `sxkernel/src/sketch.cpp`, `sxkernel/src/interop.cpp`, `sxcore/src/sx_document.cpp`, `sxcore/src/sx_document.hpp`, `sxkernel/tests/test_rung01_replan.cpp` |
| WP6 | `game/scripts/property_panel.gd`, `game/scripts/ui_spin.gd`, `game/scripts/timeline_panel.gd`, `game/tests/run_rung01_replan_panel.gd` |
| WP7 | `game/tests/run_rung01_wrench.gd`, `Makefile` |

Shared rules:

- Tests drive the controls a person uses. Keystrokes use `Viewport.push_input` with `keycode`, `physical_keycode`, `unicode`, and `pressed`, then a release, as `game/tests/run_place_tests.gd` does. Menu items use the popup's `id_pressed`. OptionButtons use `item_selected`. Buttons use `pressed`. Viewport picks go through `Interaction._input` or `FilmUI.viewport_click`. See `.cursor/rules/gdscript-click-driven-tests.mdc`.
- Forbidden in every new test, and in the rewritten walk: `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text`, and `doc.export_3mf()`. `set_up_to_face` remains a method other packages call from the pick path. Tests do not call it.
- Do not change the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (`nav_preset` defaults to `FUSION`), or the known single failures in `run_infer_tests` and `run_icon_tests`.
- Kernel tests are picked up by `file(GLOB)` in `sxkernel/CMakeLists.txt`. Until WP7, run a new Godot script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`.
- `user://` paths passed into `SxDocument` are `ProjectSettings.globalize_path` first.
- Leave `run_rung01_wrench.gd` green until WP7. `OptionButton.select` does not emit `item_selected`, so the old setters keep working while WP1 clears the face id only inside the signal handler and on session start.
- `sxkernel/src/sketch.cpp` chain tolerances (1e-6) stay. WP5's only change in that file is leftover 5's error text.

### Published calls

WP1 adds these on `SketchContextChrome`. Other packages call them and do not edit that file.

- `arm_face_pick()` — clear nothing else; show `Face: none` if the id is empty; remember that the next model-face click is the target.
- `wants_face_pick() -> bool`
- `set_up_to_face(id)` — store the id, disarm the pick, set the label from the face midpoint z, enable Extrude when the id is non-empty.
- `clear_up_to_face()` — empty id, `Face: none`, disable Extrude while End is Up To Surface.
- `dim_rejected(raw: String)` — emitted instead of `dim_submitted` when the blank text does not parse.

WP3 adds `ViewportInteraction.cancel_stack() -> bool`. WP4 calls it.

WP5 adds `SxDocument.last_export_error() -> String`. WP4 reads it.

### WP1 — Finish bar a person can read and type into

Leftovers 1 (the bar), 2 (the blank), 3, and the ` AF` suffix leftover 7 needs.

**Scope.** The finish bar only. No pick handling, no extrude guard, no status-bar wiring in `main.gd`.

**Files.** The WP1 row of the table above.

**Behaviour.**

- Dim, distance, and thin spins are at least `UiScale.px(140)` wide. Labels `D` and `Thin`. `Thin feature` defaults off and hides the thin spin, the thin-type dropdown, and Flip. Badge `Thin <n> mm` when the toggle is on and the value is greater than 0. Extrude emits `thin_thickness` 0 while the toggle is off.
- Dim LineEdit: select all on every click and on focus. Reject an unparseable `text_submitted` as specified in leftover 2. Successful submit releases focus.
- End = Up To Surface runs the face-box behaviour in leftover 1. The signal handler does not copy `view.selected_face`. `show_for_session(true)` calls `clear_up_to_face()`.
- While the polygon tool is `across_flats`, the suffix stays ` AF` and the wider field shows it.

**Acceptance.** `run_rung01_replan_finishbar.gd`, headless, through the chrome controls:

- Second click then `22.5` commits 22.5. `23.22.5` emits `dim_rejected` and does not emit `dim_submitted`.
- Distance LineEdit text for the default contains `20.0`, width at least `UiScale.px(110)`, thin controls hidden, Extrude's thin argument is 0.
- `item_selected` for Up To Surface disables the Extrude button, leaves `up_to_face_id` empty, shows `Face: none`, and `wants_face_pick()` is true. The viewport click that fills the id is WP3's test.
- Polygon tool variant `across_flats` shows suffix `AF`.

**Depends on.** Nothing. Merge any time.

### WP2 — Sketch commit: AF, snaps, angle, extrude guards

Leftovers 1 (refuse a faceless cut), 5 (status wording), 7, 9, 11 (the dimension).

**Scope.** `sketch_mode.gd` only. Do not edit the chrome, the viewport, or the kernel.

**Files.** The WP2 row.

**Behaviour.**

- Polygon variant sticks, default `across_flats`, as in leftover 7.
- `finish_extrude`: run `run_solve()` before `_seal_tangent_bosses` and the profile check. `to_face` with an empty `chrome.up_to_face_id` aborts with `Up To Surface needs a face`. When the kernel error contains `Thin wall`, status is that error without the closed-profile prefix.
- Tangent and on-circle snaps, as in leftover 9.
- `center_three_point` writes the width distance and the angle-to-+X construction dimension, as in leftover 11. Smart Dimension on one line can add that angle dimension. Construction geometry stays out of the profile.

**Acceptance.** `run_rung01_replan_sketch.gd`:

- Polygon, type `20` via `push_input` into the dim blank (not `LineEdit.text =`), flats at ±10, vertices on ±X. Circle, type `5`, radius 5. Switch tools and return: variant is still `across_flats`.
- Near-tangent shaft lines, then Extrude with thin 0: bbox 232.5 × 45 × 10 ± 0.2.
- Centre rectangle: width label value 20 after typing `20`, angle label 45° after typing `45`.
- `to_face` with an empty chrome id does not add an extrude. Status contains `needs a face`.
- A circle extruded with thin forced on (the kernel message from WP5, or a test double that sets the spin only after WP1) surfaces `Thin wall` when that message exists. Until WP5 merges, asserting the prefix is absent is enough when the error text contains `Thin wall`.

The script may build the document with File → New and the sketch rail. It does not call `sm.click` as the only driver.

**Depends on.** Nothing to merge. The face id it reads already exists. The thin-wall sentence is fully worded once WP5 has merged; the guard still lands on its own.

### WP3 — Viewport: face click, focus, Esc, Ctrl+A

Leftovers 1 (the click), 2 (release focus), 8, 10 (the key), 11 (popup select-all).

**Scope.** `viewport_interaction.gd` only.

**Files.** The WP3 row.

**Behaviour.**

- If `sketch_chrome.wants_face_pick()`, the next left click on a model face calls `set_up_to_face` with the picked face id and highlights it through `view.select_entity` without `exit_sketch`. The click does not call `sketch_mode.click`. Right click or Esc cancels the arm. The pick works while a sketch is active. Pattern: `_picking_active_plane`.
- A sketch canvas click calls `sketch_chrome.release_dim_focus()` before the event is consumed.
- `cancel_stack()` and the Esc path in leftover 8. Sketch Esc is unchanged.
- Ctrl+A does not scene-select while a text field is focused.
- `_dim_edit_line` selects all on every click. The popup is wide enough to show `45.0`.

**Acceptance.** `run_rung01_replan_input.gd`:

- Sketch on the top face, arm the pick through the chrome API (`arm_face_pick`, which WP1 owns; if the method is missing the test fails). Viewport click the bottom face. `up_to_face_id` is the bottom face, not the host top face. No new sketch point was added.
- Dim blank focused, canvas click, the focus owner is not that LineEdit.
- TriBall armed from the strip button, focus left on the button, one `push_input` Esc clears the gizmo and the selection. Same with a spin focused. Body click does not arm TriBall.
- Ctrl+A in a focused spin does not call scene select-all.

**Depends on.** WP1 for a meaningful face-pick test. Esc, focus release, and Ctrl+A do not need WP1 (`release_dim_focus` already exists). Merge the face-pick test after WP1, or keep it failing loudly until `arm_face_pick` exists.

### WP4 — Document shell: status, Esc backup, export dialog

Leftovers 2 (status wiring), 6 (status text), 8 (the `_unhandled_input` path), 12.

**Scope.** `main.gd` only.

**Files.** The WP4 row.

**Behaviour.**

- Connect `dim_rejected` to `_on_status` with `Cannot read dimension: `.
- Esc in `_unhandled_input` calls `interaction.cancel_stack()` when the method exists, and otherwise cancels TriBall and clears the selection in the same handler. It does not return between those two.
- `_show_file_dialog` sets `current_dir` and `current_file` for Export 3MF as in leftover 12. Remember the directory after a successful export.
- 3MF status uses `last_export_error()` when export returns false.

**Acceptance.** `run_rung01_replan_shell.gd`:

- File menu id 11 opens a visible FileDialog. `current_file` ends in `.3mf`. `current_dir` is the home directory on a nameless document. Pressing the dialog's OK button with `current_path` pointed at a globalized `user://` file writes that file, and the test source does not contain `export_3mf(`. Status on a closed solid contains `Exported 3MF`.
- A `dim_rejected` emission reaches the status line once WP1 has added the signal. If the signal is absent, the test fails with that gap rather than skipping.
- Esc via `push_input` after the TriBall button, without `grab_focus` on Interaction, clears the selection even when the key is delivered as an unhandled key.

**Depends on.** Nothing to compile. The export error string is complete after WP5. The face of Esc is complete after WP3. Each half is still a behaviour change on its own.

### WP5 — Kernel: thin-wall sentence and a closed mesh

Leftovers 5 and 6. Leftover 9 does not change this package's tolerances.

**Scope.** The files in the WP5 row. In `sx_document.cpp` / `.hpp`, only the export error string. In `sketch.cpp`, only the thin-profile error text.

**Files.** The WP5 row.

**Behaviour.** As in leftovers 5 and 6. Weld tolerance 1e-6 mm, matching `manifold_report`. A good solid from the existing rung-1 kernel tests still exports.

**Acceptance.** `sxkernel/tests/test_rung01_replan.cpp`:

- Circle, thin 1 mm: failure text contains `Thin wall is on` and `set 0 for a solid`. Circle, thin 0: a solid.
- `export_3mf` of that solid returns true. A mesh missing one face returns false, the error contains `open`, and the output path does not exist.
- `last_export_error()` is empty after success and equals the open-mesh sentence after failure.

**Depends on.** Nothing. Merge any time.

### WP6 — Property panel: face re-pick, select-all, opaque panel

Leftovers 1 (the row) and 10.

**Scope.** The three UI files in the WP6 row. Find the chrome with `find_child("SketchContextChrome")` and call `arm_face_pick`. Do not edit the chrome.

**Files.** The WP6 row.

**Behaviour.** As in leftover 10. Extrude schema gains a face row, shown when `end` is `to_face`, whose button calls `arm_face_pick`. Double-click on an extrude row keeps focusing the distance spin.

**Acceptance.** `run_rung01_replan_panel.gd`:

- Double-click the base extrude row. The distance LineEdit is focused and its text is selected. Keystrokes `14` and Enter leave the feature distance at 14. This test may build the extrude through the sketch UI; it does not call `graph_set_params` to perform the edit.
- Ctrl+A does not select scene bodies while that spin is focused.
- The panel's `mouse_filter` is STOP and its background alpha is 1.
- With an extrude whose end is `to_face`, the Pick face control is visible. Its `pressed` signal leaves `wants_face_pick()` true.

**Depends on.** WP1 for `arm_face_pick`. The spin and opacity checks stand alone.

### WP7 — GUI end-to-end and the checker

Leftover 4. This is the package that makes nut 7/7, wrench 28/28, and thick 4/4 come from the GUI.

**Scope.** Rewrite `game/tests/run_rung01_wrench.gd`. Append the five `run_rung01_replan_*.gd` scripts to the `test-godot` recipe in the `Makefile`. `tools/check_rung01.py` stays as it is. No new modelling behaviour. If the walk fails on a bug in a file another package owns, and that package has already merged, WP7 may edit that file to make the walk pass. It does not take the file over for anything else.

**Files.** The WP7 row only.

**The walk** (one `SceneTree` script, the handout's controls):

1. File → New (`id_pressed` 0). No bodies. Sketch on the ground plane. Camera normal is along Z.
2. **Nut.** Polygon. Assert the variant is across-flats without a setter. Origin click, second point toward +X, type `20` into the dim blank with `push_input`. Circle at the origin, type `5`. Finish bar: End Blind and Op New via `item_selected`, distance by keystrokes `7.5` into the D spin (click the spin first so the text is selected). Thin feature is off. Extrude via the button's `pressed`. Export `user://rung01/nut.3mf` through the File menu and the FileDialog (leftover 12). Quit the sketch.
3. File → New.
4. **Blank.** Circle, origin, type `10`. Circle at (200, 0). Click the dim blank a second time, then type `22.5` (the append repro). Two lines snapped near the tangents of the Ø20. Contour chips stay on. End Blind, distance `10`, thin off. Extrude. Bbox about 232.5 × 45 × 10.
5. **Hole and jaw.** Sketch on the top face. Circle on the Ø20 centre. Select tool, click the diameter label, type `10`. Centre-3-pt rectangle. Select tool, click the width label, type `20`. Click the angle label, type `45`. Construction centreline. Trim to the open jaw. Op Cut via `item_selected`, then End Up To Surface via `item_selected`. Viewport click the bottom face. Extrude enables. Extrude.
6. **Slot.** New sketch on the top face. Straight slot, radius 5, centres 150 apart at x = 18.5 and 168.5. Those numbers are typed into the dim blank, not assigned. Op Cut, End Blind (this `item_selected` clears the previous face), distance `2.5`. Extrude.
7. **Fillets.** Neck edges R10, one feature. Top face R1, bottom face R1, slot floor R1. The fillet controls are the ones the first plan's e2e already clicks; keep those clicks. Do not call `graph_add_fillet` from this script.
8. Export `wrench.3mf` through the FileDialog. Open the timeline, double-click the base extrude, type `14` into the focused distance spin, Enter. Export `wrench-t14.3mf` through the FileDialog.
9. Shell out to `python3 tools/check_rung01.py` for `nut`, `wrench`, and `thick 14`. A non-zero exit fails the script.
10. Select the jaw width label, type `21`, rebuild, export `wrench-af21.3mf` through the dialog. The script measures AF 21 ± 0.2 and angle 45° ± 0.2. The `wrench` checker still wants AF 20, so this file is not passed to `check_rung01.py wrench`. Fillet 1.5 on the slot floor is refused. New did not arm TriBall. One Esc after the strip button, without `grab_focus` on Interaction, clears the gizmo and the selection.

**Forbidden.** The script, after the rewrite, contains none of: `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, `export_3mf(`, an assignment to a LineEdit's `text`. Dimension edits go through the popup LineEdit's key events.

**Depends on.** WP1 through WP6 merged. This is the first package that requires Up To Surface, the dim blank, the thin toggle, the export dialog, and the label editor at the same time.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | Spins readable, thin off, face box armed and empty until a pick, dim parse. No 3MF rows. |
| WP2 | Polygon AF, bore circle, tangent blank, angle and width dims. Nut geometry can pass here; the file is still exported by WP7. |
| WP3 | Bottom-face click, Esc, focus. |
| WP4 | Dialog defaults, export status, Esc backup. |
| WP5 | Open mesh fails export. Thin-wall sentence. |
| WP6 | Timeline distance 14 typed into the spin. Face re-pick row. |
| WP7 | nut 7/7, wrench 28/28, thick 4/4, plus the 20 → 21 edit, from the GUI walk alone. |

## Merge order

```
WP1 ──┐
WP2 ──┤
WP5 ──┼── WP7
WP3 ──┤
WP4 ──┤
WP6 ──┘
```

WP1, WP2, and WP5 merge in any order. WP3's face-pick test and WP6's Pick face button need WP1's chrome methods. WP4's export sentence needs WP5's `last_export_error`. WP4's Esc backup and WP3's `cancel_stack` meet in the middle and can merge in either order. WP7 is last.

## Deferred

- Rungs 2–8, threads, a named jaw parameter, a datum tree beyond Top = XY. Same list as the first plan.
- A kernel angle-to-horizontal constraint. The construction +X line uses the angle constraint that already solves.
- Loosening `contour_faces`, `_seal_tangent_bosses`, or `INFER_TOL` so a gap extrudes. Snaps and the solver close the gap.
- Teaching `thin_profile_face` to offset circles. The handout parts are solids. Thin stays opt-in and line-based.
- Replacing the cylinder primitive, or making double-click on a primitive skip rename. The handout edits the extrude row.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `4b8ca9cf`. The next critique is a new build that contains this replan's packages.

## Critique score

The checker is necessary and not sufficient. Rung 1 is done when one build, in one critique, follows every handout step with the named control, scores at least 9, and the three `check_rung01.py` commands pass on files the export dialog wrote. A green checker fed by `set_finish_*`, `set_up_to_face`, `LineEdit.text =`, or `doc.export_3mf()` does not pass this rung.
