# Rung 1 replan 2 — the GUI commits the number the student typed

Status: plan only. No product code in this change.

Baseline: `main` at `fde6d95a` (PR #58). Replan 1 is [`rung-01-replan-1.md`](rung-01-replan-1.md) (WP1–WP7, PRs #52–#58, all merged). The sx-022 critique of local OCCT 8.0.1 build sha256 `850a40c91e7ff6772175a515b98ee3973ddd7e70f89ae7b276cfe69cf8652507` scored 5/10 and failed rung 1. Symptom list: [`rung-01-leftovers-sx022.md`](rung-01-leftovers-sx022.md). This replan names the root cause of each leftover at `fde6d95a`, the fix, and an acceptance check a person can perform with the mouse and the keyboard.

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

The headless walk on this commit passes 163/0 by typing into a field and pressing Enter, then emitting `id_pressed`. A real GUI walk produced nut 2/7 (closed mesh, bbox 12.053 × 10.438 × 20.0, bore Ø 6.089) and never extruded the wrench. The second part was a 5×5×5 box. Up To Surface was not reached.

Rung 1 is done when one GUI critique follows every handout step with the named control, the three checker commands pass on files the export dialog wrote, and the score is at least 9. A package that keeps the checker green by pressing Enter in a helper the student does not press, or by emitting a menu id the mouse never hit, has not finished its step.

## What already exists

Do not reimplement these. Replan 1 landed them. The sx-022 headless reference already runs them.

| Capability | Where it already lives |
|---|---|
| Distance and dim spins at least `UiScale.px(140)`, labels `D` and `Thin`, Thin behind a toggle that defaults off | `SketchContextChrome._build_finish_bar` |
| Dim LineEdit select-all on every click, reject unparseable text, `dim_rejected` | `SketchContextChrome._on_dim_edit_gui_input`, `_on_dim_text_submitted` |
| Polygon variant sticks, default `across_flats`; drag length is AF (`r = drag / √3`) | `SketchMode.set_tool`, polygon arm of `click` |
| Up To Surface clears the face id, disables Extrude, arms a one-shot pick | `SketchContextChrome._on_finish_end_selected`, `ViewportInteraction._input_up_to_face_pick` |
| `cancel_stack()` releases a focused LineEdit, cancels TriBall, clears the selection | `ViewportInteraction.cancel_stack`, `Main._unhandled_input` |
| File → New builds an empty document and does not call `insert_primitive` | `Main._do_new`, `DocumentView.new_document` |
| Export 3MF sets `current_dir` and `current_file` | `Main._show_file_dialog` |
| Closed 3MF mesh, thin-wall sentence, tangent snap, centre-rectangle angle dim | kernel + `SketchMode` from replan 1 |
| Headless handout walk, 163/0 | `game/tests/run_rung01_wrench.gd` |

## Why the GUI walk and the headless walk disagree

| Path | Nut | Wrench | What it actually does |
|---|---|---|---|
| `run_rung01_wrench.gd` at `fde6d95a` | 7/7 | 28/28 | `_type_dim` / `_type_distance` click the LineEdit, type, and press Enter. Enter on the dim blank calls `commit_at_length`. Enter on Distance makes SpinBox apply, so `.value` is 7.5 before Extrude. `_file_new` emits `_file_popup.id_pressed(0)`. Press and release of each sketch click are the same pixel, so travel stays under 12 px. |
| Operator GUI | 2/7, thickness exactly 20 | 5×5×5 box, 9/27 | Distance is read from `_extrude_spin.value`, which is still the constructor default. Polygon and circle commit the pointer distance. Status `Inserted box — drag empty space or Alt-drag to orbit` is the place-commit string. |

Across flats was on. 12.053 / 10.438 = 2/√3, the regular-hex ratio, and in the across-flats arm the stored AF is the drag length. A circumradius of 20 would be AF ≈ 34.6. A typed 20 that was halved would be AF 10.000, not 10.438. A centre-to-flat dimension of 10 would be AF 20. The mesh is the pointer distance. Ø 6.089 is radius 3.0445, the same kind of pointer distance, not a typed 5.

## Leftovers

Numbers match [`rung-01-leftovers-sx022.md`](rung-01-leftovers-sx022.md).

### 1. Finish-bar Distance stays 20 — P0 — WP1, WP5

**Root cause.** `SketchContextChrome._emit_finish_requested` sends `_extrude_spin.value`. `Main._rail_finish_extrude` reads `extrude_distance()`, which returns that same `.value`. The spin is constructed with `value = 20`, `step = 0.5`, and the default `update_on_text_changed = false`. Nothing calls `apply()` or parses the LineEdit before the read. The dim blank has `_on_dim_text_submitted`; the distance spin does not. Typed `7.5` sits in the line edit until Enter or a focus exit that applies. The headless helper presses Enter, so the spin is already 7.5 when Extrude runs. The GUI nut is exactly 20.0 mm thick, the constructor default, and the export reported no extrude error. There is no label of the number Extrude will send, so the line edit can show 7.5 while the feature is built at 20. Widening the spin again does not close this. At 1280×800 and `UiScale` factor 1 the bar fits; sx-020's clipped `0.0 mm` is not this failure. Thin is already behind the toggle and did not run (the solid is 20 mm, not a thin wall).

**Fix.** WP1 only. `extrude_distance()` parses the Distance LineEdit with the same prefix/suffix rules as `_parse_dim_text` and, on success, stores that number on the spin before returning it. `_emit_finish_requested` sends `extrude_distance()`, so the finish-bar button and the rail button both send the typed number with no Enter. On failure it does not emit `finish_requested` and the chrome emits `distance_rejected(raw)`. A label `Extrude <n> mm`, updated from that parsed number on every text change, shows the distance the next Extrude will send. Select-all on every click of the Distance LineEdit stays, including the second click. The `D` label stays.

**Acceptance.** Second click on the Distance LineEdit, type `7.5` with key events, do not press Enter, press the Extrude button. The `finish_requested` distance is 7.5 and the readout contains `7.5`. The spin's `.value` before that press may still be 20; the signal must not be 20. `7.5 mm` is fully visible in the readout. A following extrude of a closed profile is 7.5 ± 0.2 thick in the 3MF.

### 2. Polygon AF and the bore commit the pointer — P0 — WP1, WP2, WP3, WP5

**Root cause.** Two commit paths, and the student hits the one the test does not.

- `ViewportInteraction._sketch_input` on mouse-up, when a draw anchor is pending and the pointer travelled at least `CLICK_SLOP` (12 px), calls `sketch_mode.click(release_point)`. That second point is the cursor. `SketchMode.click` for polygon and circle appends that point and never reads `_length_override` or `effective_hover()`. `commit_at_length` is only reached from Enter → `dim_submitted` → `Main._on_sketch_dim_submitted`.
- The press path calls `release_dim_focus()` and then `click(mouse)`. Releasing focus can apply the spin, but `click` ignores the override the apply just stored.
- `finish_extrude`, if a tip is still pending, calls `click(_hover)`, which is again the cursor.
- The dim spin's `update_on_text_changed` is false, so digits do not set `_length_override` until apply. The circle blank's prefix is `Ø` while the number is the radius (`_sync_dim_affordance`). A rubber-band string that still parses (`Ø 3.044`) commits that radius. Status on the success path is `Length %.4f mm`, which overwrites the polygon arm's `Polygon AF %.4f`. A wrong commit looks like a successful length.

The headless clicks release on the same pixel as the press (travel 0), then press Enter. A shaky click or a drag on a zoomed-out grid commits ~10.4 mm and ~3.04 mm before the student can type.

**Fix.**

- WP1: while the dim LineEdit text parses, each change calls `sketch_mode.set_length_override` with that number. Publish `typed_dim_value() -> Variant` (the parsed number, or null). Drop the `Ø` prefix. Circle keeps a radius number; the `r` cue is a label, not a prefix glued to the digits. Polygon across-flats keeps the ` AF` suffix.
- WP2: for polygon, circle, and the other single-DOF tools, `click` uses `effective_hover()` when `_length_override >= 0`, so the typed length wins over the cursor. `finish_extrude`'s pending-tip commit uses that same point. After a polygon commit the mode remembers `Polygon AF 20.0000`. After a circle commit it remembers `Circle r=5.0000 (Ø10.0000)`. A point-to-line dimension (centre → hex flat) remembers `centre-to-flat 10.0000`, which is the apothem, not the AF.
- WP3: mouse-up does not call `click` for polygon or circle. The second point is a second press or Enter. The preview still tracks the cursor, and it tracks the typed length once the override is set. Line drag-draw is unchanged.

**Acceptance.** Fresh sketch, Polygon, no chip click, variant is `across_flats`. Click the origin (press and release, travel under 12 px). Type `20` into the dim blank. Press Enter. Flats at y = ±10, vertices on ±X, and the status contains `Polygon AF 20.0000`. Repeat with a second canvas click instead of Enter: the same flats. A mouse-up 30 px from the origin does not create the hex. Circle at the origin, type `5`, Enter: radius 5, status contains `Circle r=5.0000 (Ø10.0000)`. These asserts happen before Extrude.

### 3. File → New after a part shows a 5 mm box — P0 — WP4, WP5

**Root cause.** `_do_new` calls `view.new_document()`, cancels TriBall, and sets status `New — empty part, Top plane (XY)…`. It does not insert a body. `DocumentView.DEFAULT_PRIMITIVE_MM` is 5, and `default_primitive_size("box")` is `(5, 5, 5)`, which is the shot's W/H/D. The status string `Inserted box — drag empty space or Alt-drag to orbit` is only `ViewportInteraction._commit_place`. The drag-drop string is different (`Alt-drag or two-finger drag`, no "drag empty space"). So click-to-place ran: `PaletteButton._pressed` armed `_place_kind = "box"`, and a later viewport click committed it. `insert_primitive` then `select_entity`s the new body.

The left rail builds Sketch, a separator, then Box, Cylinder, Sphere, Cone, Torus, each 36 px (`Main` palette construction). Box is the control under Sketch. There is no autosave restore. `_autosave` only writes `user://autosave.sxp`. "Recovery" in the critique is the dirty-document Discard dialog (`Discard unsaved changes?`), not a loader.

`_file_new` in the headless walk emits `id_pressed(0)` and, if the dialog is up, clicks OK. That never moves the pointer onto the Box button, so the test's "second New leaves no bodies" does not see the GUI gesture. The mouse release that closes the File menu or the Discard dialog is delivered to whatever is underneath. If that control is the Box button, place arms after `_do_new` has returned. The next click, the one meant to start the wrench sketch, commits the box. `_do_new` also does not disarm a place that was already armed, so a Box click from before New survives into the empty part.

**Fix.** WP4 only.

- `_do_new` exits the sketch, calls `interaction._disarm_place(false)`, cancels TriBall, and relies on `new_document()` to clear the selection. It still inserts nothing. Status stays the empty-part line.
- Palette insert goes through `_on_palette_insert`. While a file menu or the discard dialog is in the gesture, the handler does not call `insert_at_center`. The flag is set when the File popup is about to show and when the discard dialog pops, and it stays set through the mouse release that closes them (clear it deferred, so the Button `pressed` on that release still sees the flag).
- Move the five primitive buttons below the rail's extrude / revolve / sweep / loft group, under a `Primitives` label. Sketch stays the first rail button. `FilmUI.find_palette_button` still finds them by `kind`. Insert menu entries are not required.

**Acceptance.** Build any solid. Open File with a click on the File button, click the New item at its popup position (not `id_pressed.emit`), click Discard. Body count is 0, TriBall is not active, `_place_kind` is empty, and status contains `New — empty part` and does not contain `Inserted`. A viewport click at the window centre after that still leaves the document empty. Clicking the Box button later, with no menu open, still arms place; that path may say `Inserted box` only after the following viewport click.

### 4. One Esc leaves the rings and the selection — P0 — WP3, WP4, WP5

**Root cause.** The rings in the shot are not `TriBallGizmo`. That gizmo draws one orange ring and is started only from `_ctx_triball` / the marking menu. `insert_primitive` selects the body, and `_draw_selection_gizmos` then draws `_rotate_grips` (red about X, green about Y, blue about Z) and `_draw_lift_grip` (the yellow `lift` label). The selection strip also shows a TriBall button, which is why the top bar says TriBall while `triball.active` can still be false. Cancelling only the gizmo leaves the rings on screen.

`cancel_stack` already releases a focused LineEdit, cancels TriBall when `active or visible`, and `clear_selection()` in one call. `_input` runs it for Esc outside a sketch. The headless check focuses the strip button and `push_input`s Esc into the main viewport with no popup, which is the path that already works.

The shot has the File menu open on top of the selected box. A `PopupMenu` is a subwindow. Godot forwards the key to that window, Esc closes the menu, and `ViewportInteraction._input` does not run. The selection, the rings, and the lift grip stay. `_place_kind` Esc disarms the ghost and returns before `cancel_stack`, which is correct for a ghost and does nothing for a box that is already committed. `cancel_stack` treats "released a LineEdit" as success and still clears the selection in that same call; the GUI failure is the key not arriving, not an early return inside `cancel_stack`.

**Fix.**

- WP3: `cancel_stack` also releases focus when the focus owner is a SpinBox or is inside one (the transform HUD W/H/D row on a selected primitive). Clearing the selection is what hides the rings and the lift grip. Do not call `_ctx_triball` from `insert_primitive` or from body select.
- WP4: each menu popup this file owns (`_file_popup` and the other `MenuButton` popups it builds) connects `window_input`. Esc hides that popup and calls `interaction.cancel_stack()` in the same keypress. The discard dialog does the same.

**Acceptance.** Insert a box by the palette (place armed, then a viewport click). Selection rings and the lift grip are visible. Focus the HUD `W` LineEdit with a click. One `push_input` Esc clears `selected_body`, hides the strip, leaves `triball.active` and `triball.visible` false, and the next draw of the selection gizmos is a no-op because nothing is selected. Repeat with the File menu open (opened by a click, not `id_pressed`): one Esc closes the menu and clears the selection. A second Esc is a no-op. A viewport click that only selects a body leaves `triball.active` false.

### 5. Up To Surface was not exercised — P0 — WP1, WP5

**Root cause.** The face box, the disabled Extrude, and the viewport pick from replan 1 are present and unproven on this build: the walk stopped at the box. One footgun is still in the finish bar. Choosing Cut runs `set_finish_end("through_all")`. `OptionButton.select` does not emit `item_selected`, so `_on_finish_end_selected` does not run. Cut after Up To Surface changes the dropdown to Through All, leaves the face id and the Extrude enabled-state stale relative to the handler, and the next Extrude sends `through_all` from `get_finish_end()` because `selected` is now Through All. The handout order is Cut, then Up To Surface, which still emits and arms the pick. The reverse order, and any Cut clicked after the face is chosen, silently drops Up To Surface.

**Fix.** WP1: delete the Cut → Through All auto-select. End changes only when the student picks an End item, and that pick goes through `_on_finish_end_selected`. Up To Surface still clears the id, shows `Face: none`, disables Extrude, and arms the pick. `property_panel.gd` already has the Pick face row; this replan does not edit it.

**Acceptance.** Sketch on the top face of a 10 mm blank. Choose Cut, then Up To Surface, by the End popup's `index_pressed` / `item_selected` (not `set_finish_end`). Extrude is disabled and `up_to_face_id` is empty. A viewport click on the bottom face sets the id, the label shows a z near 0, and Extrude enables. Extrude. A ray through the jaw is open at z = 0.5 and z = 9.5. Choosing Cut after the face is set leaves End on Up To Surface. Repeating with no face click does not create an extrude. This is part of the WP5 wrench, not a kernel-only test.

### 6. The e2e walk is still not the operator's hands — P1 — WP5

**Root cause.** `run_rung01_wrench.gd` passes 163/0 and still skips the gestures that failed in the GUI. `_type_distance` presses Enter before Extrude. `_type_dim` presses Enter and never commits a typed length with a second canvas click. Sketch clicks release on the press pixel. `_file_new` emits `id_pressed`. `_triball_one_esc` focuses the strip button with no popup and no HUD spin. None of that fails on leftovers 1–4.

**Fix.** WP5 extends that script. It does not replace the checker rows that already pass. The new gestures are the acceptance check for this replan. Earlier packages leave the file alone. Window size, direct `_input`, bare menu emits, and `dlg.current_path` are leftover 11, not this one.

### 7. Status hides a bad radius — P1 — WP2, WP4

**Root cause.** `Main._on_sketch_dim_submitted` always sets `Length %.4f mm` after a successful `commit_at_length`, which replaces `Polygon AF …`. A circle commit has no diameter echo. The Ø 6.089 bore and the AF 10.438 hex were both reported as ordinary lengths if they were reported at all. The pointer-commit path never goes through `dim_submitted`, so a drag-built hex can extrude with no `Cannot read dimension` and no AF line.

**Fix.** WP2 stores the sentence on the mode (`last_commit_text`: `Polygon AF 20.0000`, `Circle r=5.0000 (Ø10.0000)`, or `centre-to-flat 10.0000`). WP4 prints that sentence from `_on_sketch_dim_submitted` when the method exists, and the polygon/circle `click` status is the same sentence so a pointer commit is still explicit. `Length %.4f mm` remains the fallback for tools that do not set a sentence.

**Acceptance.** After Enter on `5` for a circle, status contains `r=5.0000` and `Ø10.0000`. After Enter on `20` for an across-flats hex, status contains `Polygon AF 20.0000` and does not contain `centre-to-flat`.

### 8. Export dialog defaults — P2 — no package

**Root cause.** None left at `fde6d95a`. `_show_file_dialog` for Export 3MF sets `current_dir` from the last export directory, else the document directory, else the home directory, and `current_file` from `_export_3mf_filename()` (`part.3mf` when the document has no name). A successful export stores `_last_export_dir`. The GUI nut did export (`Exported 3MF`, closed mesh). WP5 keeps using the dialog. Do not reopen this.

### 9. Centre-to-flat 10 is not the critique path — P2 — documented here

**Root cause.** The handout's centre-to-flat step (apothem 10 → AF 20) is a Smart Dimension from the hex centre to a flat. `_smart_dim_between` writes a distance whose line ref has role `self`, and `solver_planegcs.cpp` turns that into `addConstraintP2LDistance`. That path was not what produced AF 10.438 (a solved apothem of 10 is AF 20; a solved apothem of 10.438 would be an exact typed value, and 10.438 is not). The critique's required path is Polygon, Across Flats, typed `20`, then a circle with typed radius `5`.

**Fix.** No kernel change. WP2's status sentence distinguishes `centre-to-flat` from `Polygon AF`. WP5 builds the nut with typed AF 20, not with a centre-to-flat dimension of 10. A later critique may use centre-to-flat as an alternate and must expect AF 20 from an apothem of 10.

### 10. Camera number keys swallow typed digits — P0 — WP3, WP6, WP2

This is not leftover 2. Leftover 2 is the mouse-up pointer commit. Typing `20` while the rubber-band is up never reaches that path: the keys are consumed as standard views.

**Root cause.** `ViewportInteraction._input` runs camera navigation before the sketch branch. For an `InputEventKey` it sets `block_nav` only when `_text_field_has_focus()` or `_sketch_keys_blocked()` is true. `_sketch_keys_blocked` is true only when the focus owner is a LineEdit, a TextEdit, or a SpinBox. During a rubber-band the dim blank is not focused yet, so `block_nav` is false.

`OrbitCamera._is_nav_key` returns true for `KEY_1`, `KEY_2`, `KEY_3`, `KEY_5`, and `KEY_7` even when `sketch_orientation_locked` is true. WASD is the key family that lock actually refuses. `_handle_nav_key` then applies the standard view and returns true (`1` front, `2` right, `3` top, `7` iso). `KEY_5` while the sketch lock is on returns true and does not toggle projection, so the digit is swallowed with no view change. `handle_input` therefore marks the key handled, and `_input` returns. `_sketch_input` never runs. The digit arm that already calls `focus_dim_for_typing` when `has_single_dof_preview()` (`_is_length_type_key` includes `0`–`9`, the keypad digits, and `.`) sits after the camera return. A real `InputEventKey` for `2` while rubber-banding frames the right view and never seeds the dim blank. `0`, `4`, `6`, `8`, `9`, and `.` are not nav keys, so a typed `20` loses the `2` and can still deliver the `0`.

`commit_at_length` calls `set_length_override`, which clamps to `0.01`, then `click`. A typed length below `MIN_SEGMENT_MM` (0.5) still commits. The pointer arms already reject that distance (`Too short` / `Too small`). The typed arm does not.

**Fix.** Three owners, because the files already have owners. No new row takes `viewport_interaction.gd` or `sketch_mode.gd`.

- WP3, in `_input`, before `camera.is_nav_event`: when the sketch is active and `has_single_dof_preview()` is true, an `InputEventKey` that `_is_length_type_key` accepts (digits, keypad digits, `.`) is routed to `sketch_chrome.focus_dim_for_typing` and marked handled. Camera nav does not see it. This is the same seed `_sketch_input` already uses; it has to run first.
- WP6 owns `orbit_camera.gd`. While `sketch_orientation_locked` is true, `_is_nav_key` returns false for `KEY_1`, `KEY_2`, `KEY_3`, `KEY_5`, and `KEY_7`, and `_handle_nav_key` does not apply a standard view and does not return true for `KEY_5`. The sketch session, including the rubber-band, keeps the sketch camera. Outside a sketch those keys still frame the standard views. WASD stays as it is.
- WP2: `commit_at_length` and the typed `click` reject `length < MIN_SEGMENT_MM`. No geometry is added. Status contains `Too short`. `set_length_override` is not used to sneak a 0.01 mm segment through.

**Acceptance.** Polygon, first click at the origin so `has_single_dof_preview()` is true, dim blank not focused. `Viewport.push_input` of `KEY_2` then `KEY_0`. The dim blank text contains `20`. The camera basis is unchanged (not the right view, not iso). `KEY_PERIOD` seeds `.`. `KEY_1`, `KEY_3`, `KEY_5`, and `KEY_7` during that preview do not change the camera. With the sketch lock on and no preview, those five keys still do not change the camera, and `KEY_5` is not reported handled by the camera. Outside a sketch, `KEY_1` still frames the front view. Type `0.1` and commit: no new hex, status contains `Too short`. Type `20` and commit: AF 20, as leftover 2.

### 11. The e2e harness still shortcuts the GUI — P0 — WP5

**Root cause.** Leftover 6 is the gesture gap (Enter before Extrude, same-pixel clicks, `id_pressed` for New). The walk also cheats the window and the input path. `_widen` sets the root to `Vector2i(1920, 900)`. The critique desktop is 1280×800, which is where the finish bar and the variant chips collide (leftover 12). `_right_click_uv` and the hover helper call `interaction._input` directly. `_file_new` emits `_file_popup.id_pressed(0)`. The timeline step emits `_view_popup.id_pressed(4)`. `_pick_option` calls `OptionButton.select` and `item_selected.emit`. `_export_via_dialog` assigns `dlg.current_path` and then clicks OK. None of those are a pointer or a key on a widget. A walk that stays green on a 1920×900 window with those shortcuts does not show that the operator's 1280×800 session works.

**Fix.** WP5 only. Root size for the walk is 1280×800. Delete `_widen(1920, 900)` or make it set `Vector2i(1280, 800)` and nothing else. Every pointer and key in `run_rung01_wrench.gd` goes through `Viewport.push_input`. No `interaction._input`. File, View, and OptionButton items are clicked at the popup item's screen rect. `id_pressed.emit` is not used. `item_selected.emit` survives only in the one End helper `_pick_end` (Up To Surface), which this replan already allowed. The export path is typed into the FileDialog name field with key events. `dlg.current_path =` is not used. `tools/lint_rung01_e2e.py` reads that script and exits non-zero if any forbidden shortcut is present. The `Makefile` runs the lint as part of `make test`, before the Godot suites.

**Acceptance.** The lint fails on a copy of today's walk and passes on the edited walk. The walk's root is 1280×800 for the nut, the wrench, and the thick edit. Export status contains the full path the keys typed. Checker rows are unchanged.

### 12. Variant chips overlap the finish bar — P0 — WP1, WP4

**Root cause.** `show_for_session` places the finish bar at `(60, 42)`. `Main._on_sketch_tool_changed` calls `show_variants` with `Vector2(rail_x, 80)`. `show_variants` then places the chip bar at `screen_pos + (12, -chip_h - CHIP_PAD)`. `CHIP_H` is 28 and `CHIP_PAD` is 6, so at `UiScale` factor 1 the chip row lands at y = 46. The finish bar occupies the band that starts at y = 42 and is taller than the 4 px gap, so the chip rect and the finish-bar rect intersect. Polygon has a variant row (`vertex`, `across_flats`) even though `_variant_kind_for` returns `""` for polygon; the chips still show. At 1280×800 and at 1366×768 that intersection sits in the top chrome. A 1920×900 harness never asserts it.

**Fix.** WP1 owns the geometry, in `sketch_context_chrome.gd`. Publish `place_variant_row(rail_x: float)`. It shows the chips on the next row under the finish bar: the chip bar's top is at or below the finish bar's bottom, the two global rects do not intersect, and both lie inside the viewport. `show_variants` uses that same stack and does not honor a caller Y that would pull the chips up into the finish bar. WP4 owns the call site in `main.gd`: `_on_sketch_tool_changed` calls `place_variant_row(rail_x)` and stops passing `Vector2(rail_x, 80)`.

**Acceptance.** `run_rung01_replan2_layout.gd` sets the root to 1280×800, enters a sketch, chooses Polygon, and asserts the finish-bar global rect and the variant-bar global rect do not intersect, the variant bar is below the finish bar, and both are inside the viewport. Repeat at 1366×768. The test does not assign a bar's `position`.

### 13. Exit Sketch is a cancel mark, and an empty sketch vanishes — P1 — WP4, WP2

**Root cause.** The sketch rail's first control is `UIIcons.button("cancel", "", "Exit Sketch: save and return to the previous view")`. An empty `label` is icon-only, so the student sees a cancel mark beside the finish bar and the dim blank, not the words Exit Sketch. `pressed` calls `sketch_mode.exit_sketch()` immediately. For a new sketch with `entity_ids()` empty, `exit_sketch` calls `cancel()` and emits `Empty sketch discarded`. There is no confirm and no sentence that says the part was left unchanged. A sketch that has geometry updates or adds the feature and emits `Sketch saved`. The empty path and the save path share one unmarked button.

**Fix.**

- WP4: the button is `UIIcons.button("ok", "Exit Sketch", ...)` so the check mark and the words `Exit Sketch` are both visible at 1280×800. The rail grows to fit the words; the control is not tooltip-only. On press, if `sketch_mode.is_empty_new_sketch()` is true, a confirm dialog explains that the sketch is empty and exiting discards it without adding a feature. Confirm calls `exit_sketch`. Cancel leaves the sketch active. A sketch that already has entities still exits on one click, so `FilmUI.exit_sketch` on a drawn sketch stays one click.
- WP2: publish `is_empty_new_sketch() -> bool` (active, not editing an existing feature, `entity_ids()` empty). The empty arm of `exit_sketch` still discards, and the status is `Empty sketch discarded — nothing was drawn`. It does not emit `Sketch saved`.

**Acceptance.** In a fresh empty sketch the rail button's text is `Exit Sketch` and its icon is the check, not `cancel` with an empty caption. Click it: a dialog is visible and the sketch stays active until the confirm button is clicked. After confirm, sketch mode is off, no sketch feature was added, and status contains `Empty sketch discarded` and `nothing was drawn`. Draw one line, click Exit Sketch: no empty-sketch dialog, status contains `Sketch saved`.

### 14. The export name field is not a path the student can type — P1 — WP4

Leftover 8 stays closed. `current_dir` and `current_file` on open are already correct. This leftover is what happens after the dialog is up.

**Root cause.** `_show_file_dialog` pops the FileDialog and does not select the filename. The next key appends to `part.3mf` (or to the document stem). A student who pastes or types an absolute path into the name field gets that string joined onto `current_dir`, not a split directory plus file. On success, `_on_file_selected` sets status to `Exported 3MF` with no path. The GUI nut did export; the status did not say where.

**Fix.** WP4 only, in `main.gd`. When the Export 3MF dialog is shown, the filename LineEdit is focused and `select_all()` runs, so the next character replaces the suggested name. If that text is an absolute path when the dialog is accepted, split it into `current_dir` (`get_base_dir`) and `current_file` (`get_file`) before export, and export that full path. Do not concatenate the absolute name onto the previous directory. Success status is `Exported 3MF → ` plus the full path. Failure status stays the existing `3MF export failed` line. Do not change `_export_3mf_start_dir` or `_export_3mf_filename`.

**Acceptance.** Open Export 3MF. The name LineEdit's selected text is the whole suggested name. Type an absolute path with key events (the selection is replaced, not appended) and press OK. The file is written at that path, not under a joined relative name. Status equals `Exported 3MF → ` plus that path. Opening the dialog still uses the landed `current_dir` / `current_file` defaults; the test does not assign `current_path` on the dialog.

## Work packages

Six packages. File owners are exclusive. A leftover that names two files extends the owners those files already have; it does not add a second owner. WP6 is the only new row, and it owns `orbit_camera.gd` only. WP5 merges last and is the only one that edits `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, and the `Makefile`.

| WP | Owns |
|---|---|
| WP1 | `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan2_distance.gd`, `game/tests/run_rung01_replan2_layout.gd` |
| WP2 | `game/scripts/sketch_mode.gd`, `game/tests/run_rung01_replan2_commit.gd` |
| WP3 | `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan2_pointer.gd` |
| WP4 | `game/scripts/main.gd`, `game/tests/run_rung01_replan2_shell.gd` |
| WP5 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` |
| WP6 | `game/scripts/orbit_camera.gd`, `game/tests/run_rung01_replan2_camera.gd` |

Shared rules:

- Tests drive the controls a person uses. Keystrokes use `Viewport.push_input` with `keycode`, `physical_keycode`, `unicode`, and `pressed`, then a release, as `game/tests/run_place_tests.gd` does. Menu items that the test means as a mouse click are clicked at the popup item's screen rect. Buttons use `pressed` or a real click. See `.cursor/rules/gdscript-click-driven-tests.mdc`.
- WP1–WP4 scripts may send a viewport pick through `Interaction._input` or `FilmUI.viewport_click`. The WP5 walk may not. In `run_rung01_wrench.gd` every pointer and key goes through `Viewport.push_input`. `id_pressed.emit` is forbidden there. `item_selected.emit` is allowed only inside `_pick_end` (the End popup). The walk types into the FileDialog; it does not assign `current_path` on the dialog. `tools/lint_rung01_e2e.py` fails `make test` if those shortcuts are present.
- Forbidden in every new test, and in the WP5 edits to the walk: `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text`, and `doc.export_3mf()`. `set_length_override` stays a method the chrome calls. Tests do not call it to commit a dimension.
- Do not change the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (`nav_preset` defaults to `FUSION`), or the known single failures in `run_infer_tests` and `run_icon_tests`.
- Until WP5, run a new Godot script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`.
- `user://` paths passed into `SxDocument` are `ProjectSettings.globalize_path` first.
- Leave `run_rung01_wrench.gd` green until WP5. The Enter-then-Extrude path must keep working after WP1, because applying a parsed `7.5` and applying Enter's `7.5` are the same number.
- No kernel edits. `sxkernel/` and `sxcore/` stay as they are. `property_panel.gd` stays as it is.

### Published calls

WP1 adds these on `SketchContextChrome`. Other packages call them and do not edit that file.

- `extrude_distance() -> float` — parse the Distance LineEdit first; on success store it and return it; on failure return the previous spin value and emit `distance_rejected(raw)`.
- `distance_rejected(raw: String)` — emitted when Extrude is pressed and the Distance text does not parse. No `finish_requested` in that case.
- `typed_dim_value() -> Variant` — the parsed dim LineEdit number while that text is a single float, else null.
- The dim spin calls `sketch_mode.set_length_override` on each parsed change during a single-DOF preview. That method already exists.

WP1 also publishes `place_variant_row(rail_x: float)`. WP4 calls it. `show_variants` stacks the same way, so a caller Y cannot pull the chips into the finish bar.

WP2 adds `SketchMode.last_commit_text() -> String` and `is_empty_new_sketch() -> bool`. WP4 reads both. An empty `last_commit_text` means WP4 keeps `Length %.4f mm`.

WP3 does not add a method. It calls the existing `focus_dim_for_typing` before camera nav. WP4 calls the existing `cancel_stack` and `_disarm_place`.

WP6 does not add a method. The lock is the existing `sketch_orientation_locked` flag: standard-view keys stop being nav keys while it is true.

### WP1 — Distance is the number Extrude sends

Leftovers 1, 2 (the override and the radius label), 5 (Cut must not clear Up To Surface), 12 (the chip row).

**Scope.** The finish bar and the variant-row stack. No viewport pick changes, no `main.gd` status wiring. The call site that stops passing y = 80 is WP4.

**Files.** The WP1 row.

**Behaviour.**

- `extrude_distance()` and the Extrude button, as in leftover 1. Readout label name `ExtrudeReadout`, text `Extrude <n> mm`, updated on distance text changes and after a successful parse. Default readout contains `20` until the student types.
- Dim text changes push a length override when the sketch has a single-DOF preview. `typed_dim_value()` returns the parsed number. Circle dim has no `Ø` prefix. Across-flats suffix stays ` AF`.
- Remove the Cut handler's `set_finish_end("through_all")`.
- Select-all on the second click of the Distance LineEdit stays.
- `place_variant_row(rail_x)` puts the variant chips on the next row under the finish bar. `show_variants` uses that stack and ignores a caller Y that would overlap the finish bar.

**Acceptance.** `run_rung01_replan2_distance.gd`:

- Second click on Distance, key events `7.5`, no Enter, Extrude `pressed`. `finish_requested` distance is 7.5. The readout contains `7.5`. The test source does not contain `set_extrude_distance`.
- Text `20.07.5` (select-all failed, append) emits `distance_rejected` and does not emit `finish_requested`.
- Dim blank, polygon tool, type `20` with key events and no Enter: `typed_dim_value()` is 20 and `sketch_mode.has_length_override()` is true while a preview is active.
- Cut then Up To Surface: Extrude disabled, face id empty. Up To Surface then Cut: End is still Up To Surface.

`run_rung01_replan2_layout.gd`: root 1280×800, sketch, Polygon. Finish-bar and variant-bar global rects do not intersect, the variant bar is below the finish bar, both are inside the viewport. The same asserts at 1366×768. The script does not set either bar's `position`.

**Depends on.** Nothing. Merge any time. The layout script is green once the chrome stacks, even if WP4 still passes `Vector2(rail_x, 80)`, because `show_variants` ignores that Y.

### WP2 — Typed length wins over the cursor

Leftovers 2 (the click geometry), 7 (the sentence), 10 (reject a typed length under `MIN_SEGMENT_MM`), 13 (`is_empty_new_sketch` and the empty-sketch status).

**Scope.** `sketch_mode.gd` only.

**Files.** The WP2 row.

**Behaviour.** As in leftovers 2, 7, 10, and 13. `click` / the pending-tip arm of `finish_extrude` use `effective_hover()` when a length override is set. `last_commit_text` is set for polygon AF, circle radius, and centre-to-flat. `commit_at_length` rejects a length below `MIN_SEGMENT_MM` with status `Too short` and adds no geometry. `is_empty_new_sketch` and the empty-sketch status are as in leftover 13. Construction geometry and the kernel tolerances stay.

**Acceptance.** `run_rung01_replan2_commit.gd`:

- The script sets the override by typing into the dim blank (key events). It does not assign `LineEdit.text`.
- Type `20`, then a viewport click whose sketch point is 4 mm from the origin along +X. The cursor distance is 4 and the override is 20, so the flats are at ±10. `last_commit_text` contains `Polygon AF 20.0000`.
- Type `5`, then a viewport click 2 mm out. Radius is 5. The text contains `r=5.0000` and `Ø10.0000`.
- With the override cleared, a viewport click at 10.438 mm builds a hex of AF 10.438 ± 0.05. That control case is the pointer path, and it must not be the result once an override is set.
- Type `0.1` and commit with Enter. No new polygon entities. Status contains `Too short`.
- `is_empty_new_sketch()` is true on a fresh sketch and false after that hex exists. Calling `exit_sketch` on the fresh sketch sets status to `Empty sketch discarded — nothing was drawn` and does not emit `Sketch saved`.

The script builds the document with File → New and the sketch rail. The second point goes through `ViewportInteraction._input` or `FilmUI.click_sketch` after the digits.

**Depends on.** Nothing to merge. The override API already exists. The dim spin starts feeding it once WP1 has merged. Until then the test can type and press Enter, which already sets the override through `commit_at_length`, and also call the preview path by focusing the blank and relying on `value_changed`. If `typed_dim_value` is missing, the Enter path still has to produce AF 20.

### WP3 — Pointer: no accidental second point, Esc from a spin, digits before the camera

Leftovers 2 (mouse-up), 4 (the spin and the selection rings), 10 (route digits to the dim blank before camera nav). `orbit_camera.gd` is WP6. This package only changes the call order in the file it already owns.

**Scope.** `viewport_interaction.gd` only.

**Files.** The WP3 row.

**Behaviour.**

- Polygon and circle: mouse-up does not call `click`. A second press does. Enter is unchanged (it never went through mouse-up).
- On a canvas press, if `typed_dim_value()` is a number and `has_single_dof_preview()` is true, commit with `commit_at_length` of that number instead of `click(mouse)`. If the method is missing, keep today's `click`.
- `cancel_stack` releases SpinBox focus as in leftover 4. Body select and `insert_primitive` do not call `_ctx_triball`.
- Before `camera.is_nav_event`, a length key (`0`–`9`, keypad digits, `.`) during `has_single_dof_preview()` calls `focus_dim_for_typing` and is marked handled. The camera does not see that event.

**Acceptance.** `run_rung01_replan2_pointer.gd`:

- Polygon, press at the origin, release 40 px away. The sketch has no hex (`entity` count unchanged, or no new lines). A second press 40 px away does create it.
- With a typed `20` in the dim blank (key events) and the anchor down, a canvas click commits AF 20, not the click distance. If `typed_dim_value` is absent the test fails with that gap.
- Palette box, viewport click to commit, click the HUD `W` line edit, one `push_input` Esc. `selected_body` is empty, `triball.active` is false. The test does not call `grab_focus` on Interaction.
- Polygon, press at the origin so a preview is active, dim blank not focused. `push_input` `KEY_2` then `KEY_0`. The dim blank contains `20`. Store the camera basis before the keys and assert it is unchanged after them. `KEY_1`, `KEY_3`, `KEY_5`, and `KEY_7` in that same preview also leave the basis unchanged.

**Depends on.** WP1 for the typed-canvas-click assertion. The mouse-up assertion and the Esc assertion stand alone. Merge the typed-click assertion after WP1, or keep it failing loudly until `typed_dim_value` exists.

### WP4 — New stays empty, Esc reaches the menu, Exit Sketch, and the export path

Leftovers 3, 4 (popup Esc), 7 (status wiring), 12 (stop passing y = 80), 13 (the Exit Sketch button and the empty confirm), 14 (filename select-all, absolute path, status path). Leftover 8 stays closed: do not edit `_export_3mf_start_dir` or `_export_3mf_filename`.

**Scope.** `main.gd` only.

**Files.** The WP4 row.

**Behaviour.** As in leftovers 3, 4, 7, 12, 13, and 14. `_on_sketch_dim_submitted` uses `last_commit_text()` when that method exists and returns a non-empty string. `_on_sketch_tool_changed` calls `place_variant_row(rail_x)`. The Exit Sketch control shows the check icon and the words `Exit Sketch`, and confirms before discarding an empty new sketch. Export 3MF selects the whole filename on open, splits an absolute name into directory plus file, and reports `Exported 3MF → <full path>`.

**Acceptance.** `run_rung01_replan2_shell.gd`:

- A solid exists. Click the File `MenuButton`, click the New item's rect, click Discard's OK button. Bodies empty, status contains `New — empty part`, status does not contain `Inserted`, `_place_kind` is empty. A viewport click at the centre does not insert a box.
- The Box `PaletteButton` is not the next palette child after Sketch. A `Primitives` label exists and the Box button is after the rail extrude button in tree order.
- Box placed, File menu opened by a click, one `push_input` Esc. The menu is hidden and `selected_body` is empty.
- A `last_commit_text` of `Circle r=5.0000 (Ø10.0000)` reached through a real dim Enter shows that sentence on the status line. If the method is absent, Enter still sets status and the test records the missing method as a failure rather than skipping.
- The sketch-rail exit control's text is `Exit Sketch`. On an empty new sketch, clicking it shows a confirm dialog and leaves the sketch active. Clicking the dialog's confirm control turns sketch mode off, adds no sketch feature, and status contains `nothing was drawn`. After one committed line, Exit Sketch does not show that dialog and status contains `Sketch saved`.
- Export 3MF: the name field's selection is the entire suggested name. Key events replace it with an absolute path. OK writes that path. Status is `Exported 3MF → ` plus the path. The test source does not assign the dialog's `current_path`. The dialog still opens on the landed directory and filename defaults.

**Depends on.** Nothing to compile. The specific sentence is complete after WP2. Esc's `cancel_stack` is complete after WP3 and already exists at `fde6d95a`. The chip call is complete after WP1 publishes `place_variant_row`; until then the test fails on the missing method. The empty confirm is complete after WP2 publishes `is_empty_new_sketch`. Each half lands on its own.

### WP6 — Standard-view keys stay out of a sketch

Leftover 10, the camera half. The digit route is WP3. The short-commit reject is WP2.

**Scope.** `orbit_camera.gd` only.

**Files.** The WP6 row.

**Behaviour.** While `sketch_orientation_locked` is true, `KEY_1`, `KEY_2`, `KEY_3`, `KEY_5`, and `KEY_7` are not nav keys. `_handle_nav_key` does not call `apply_standard_view` for them and does not return true for `KEY_5`. Outside a sketch they still frame front, right, top, the projection toggle, and iso. WASD locking is unchanged.

**Acceptance.** `run_rung01_replan2_camera.gd`:

- Enter a sketch so `sketch_orientation_locked` is true. `push_input` each of `KEY_1`, `KEY_2`, `KEY_3`, `KEY_5`, `KEY_7`. `handle_input` does not consume them as views: the camera basis is unchanged after each key, and `KEY_5` does not toggle projection.
- Leave the sketch. `push_input` `KEY_1`. The camera frames the front view.
- The script does not edit `viewport_interaction.gd`. Seeding the dim blank is the WP3 assertion.

**Depends on.** Nothing. Merge any time. The combined "type 20, camera stays, blank reads 20" check is WP3 plus this package, and WP5 repeats it on the walk.

### WP5 — GUI end-to-end

Leftovers 1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14. This is the package that makes nut 7/7, wrench 28/28, and thick 4/4 come from the operator's gestures at 1280×800.

**Scope.** Extend `game/tests/run_rung01_wrench.gd`. Add `tools/lint_rung01_e2e.py`. Append the six `run_rung01_replan2_*.gd` scripts (`distance`, `commit`, `pointer`, `shell`, `layout`, `camera`) to the `test-godot` recipe in the `Makefile`, after the existing `run_rung01_replan_*.gd` lines. Run the lint from `make test` before the Godot suites. `tools/check_rung01.py` stays as it is. No new modelling behaviour. If the walk fails on a bug in a file another package owns, and that package has already merged, WP5 may edit that file to make the walk pass. It does not take the file over for anything else.

**Files.** The WP5 row only.

**Changes to the walk** (keep the rest of the 163 checks):

1. **Nut distance.** Second click on the Distance LineEdit, type `7.5`, do not press Enter, press Extrude. Before export, the body's bbox Z is 7.5 ± 0.2. Export through the File dialog as today.
2. **Nut size before Extrude.** After typing `20` and committing (Enter, and a second run of the hex is not required), read the sketch geometry: flats at ±10 ± 0.2. After typing `5`, radius 5 ± 0.05. Status contains `Polygon AF 20` and `Circle r=5`. Fail the script if the hex AF is near 10.4 or the bore radius is near 3.04, before any extrude.
3. **Second New.** Replace `_file_new`'s `id_pressed.emit(0)` with a click on the File button and a click on the New item, then the existing Discard click. Assert bodies empty and status does not contain `Inserted`. The wrench sketch starts only after that.
4. **Esc.** After a palette box is placed (a dedicated step, not the wrench), focus the HUD `W` field by a click and `push_input` Esc once. Selection clears. Open the File menu by a click and `push_input` Esc once. The menu closes and the selection is clear. Delete that box with New before the wrench, or run this step after the checker so it cannot contaminate `wrench.3mf`.
5. **Up To Surface.** Keep the jaw cut. Choose Cut, then Up To Surface, by `item_selected`. Assert Extrude is disabled, then viewport-click the bottom face, assert Extrude enables, extrude. The wrench checker is the proof the cut went through. Also assert End is still Up To Surface after a later Cut click does not happen; the walk's own order is Cut then Up To Surface, and it must assert `get_finish_end() == "to_face"` and a non-empty `up_to_face_id` immediately before the jaw Extrude.
6. Checker commands unchanged: nut 7/7, wrench 28/28, thick 4/4, plus the existing jaw 21 measurement.
7. **Window and input path (leftover 11).** The root is 1280×800 for the whole walk. `_widen(1920, 900)` is gone. Right-click, hover, and every other pointer or key use `Viewport.push_input`. File → New, the View/timeline item, and FinishOp are clicks on popup rows. Only `_pick_end` may `item_selected.emit`. The 3MF path is typed into the FileDialog name field. No `dlg.current_path =`.
8. **Digits during the hex (leftover 10).** The `20` for across-flats is `push_input` of `KEY_2` and `KEY_0` while the preview is active, before the dim blank is focused. Assert the camera basis is unchanged and the blank contains `20`, then commit. A commit of a length below 0.5 mm is not part of the nut; the unit check is WP2.
9. **Layout (leftover 12).** Before the nut extrude, at 1280×800, the finish bar and the polygon variant chips do not intersect. The layout script covers 1366×768; the walk does not resize away from 1280×800 to hide an overlap.
10. **Exit Sketch (leftover 13).** One empty-sketch step: click `Exit Sketch`, click the confirm control, assert the explanatory status. Drawn sketches still exit on one click.
11. **Export status (leftover 14).** After the typed path and OK, status starts with `Exported 3MF → ` and contains the full path.

**Lint.** `tools/lint_rung01_e2e.py` reads `game/tests/run_rung01_wrench.gd` and exits non-zero when the file contains any of: `interaction._input`, `id_pressed.emit`, `item_selected.emit` outside the function `_pick_end`, an assignment to a dialog `current_path`, or a root size other than `Vector2i(1280, 800)` (in particular `1920` or `900` in `_widen`). It exits zero on the edited walk. `make test` runs it before Godot.

**Forbidden.** The edited helpers do not contain `set_extrude_distance`, `set_finish_end`, `set_finish_op`, `set_up_to_face`, `export_3mf(`, or an assignment to a LineEdit's `text`. Distance for the nut is committed by the Extrude click with no Enter. `_type_distance` may keep Enter for the wrench blank and the slot only if the nut step is the no-Enter path; prefer the no-Enter path for every distance in the walk.

**Depends on.** WP1 through WP4 and WP6 merged. This is the first package that requires the distance parse, the typed polygon commit, the mouse-driven New, the popup Esc, the digit route, the view-key lock, the stacked chrome, the Exit Sketch confirm, and the typed export path at the same time.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | Distance 7.5 without Enter. Readout. Cut does not clear Up To Surface. Chips stacked under the finish bar at 1280×800 and 1366×768. No 3MF. |
| WP2 | Typed 20 beats a 4 mm cursor. Circle sentence. Typed length under 0.5 mm is `Too short`. Empty-sketch status explains the discard. |
| WP3 | Mouse-up does not build the hex. Esc from the HUD spin. Digits and `.` reach the dim blank before the camera while a preview is active. |
| WP4 | Mouse-driven New stays empty. Esc from the File menu. Status sentence. `Exit Sketch` confirms an empty sketch. Export status carries the full path. Variant call site uses `place_variant_row`. |
| WP6 | `1`/`2`/`3`/`5`/`7` do not move the camera while a sketch is open. `KEY_5` does not swallow the key. |
| WP5 | nut 7/7, wrench 28/28, thick 4/4, from those gestures, at 1280×800, with the lint clean. |

## Merge order

```
WP1 ──┐
WP2 ──┤
WP3 ──┼── WP5
WP4 ──┤
WP6 ──┘
```

WP1, WP2, WP3, WP4, and WP6 merge in any order. WP3's typed canvas click is meaningful after WP1. WP4's specific circle sentence is meaningful after WP2. WP4's chip call is meaningful after WP1. WP4's empty confirm is meaningful after WP2. The dim-blank digit check is meaningful after WP3; the view-key lock is WP6 and stands alone. WP5 is last.

## Deferred

- Rungs 2–8, threads, a named jaw parameter, a datum tree beyond Top = XY. Same list as replan 1.
- A kernel change to point-to-line distance. `addConstraintP2LDistance` is already what a centre-to-flat dimension uses. The critique path does not need it.
- Hiding the rotate rings until a rotate drag. They are the selection affordance. Esc clearing the selection is what removes them from the shot.
- Removing palette primitives entirely. They stay on the rail, below the finish tools.
- Reopening export-dialog defaults (`current_dir` / `current_file` on open), the open-mesh refuse, or the thin-wall sentence. Filename select-all, an absolute path typed into the name field, and `Exported 3MF → <path>` are leftover 14, not a reopening of leftover 8.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `850a40c91e7ff6772175a515b98ee3973ddd7e70f89ae7b276cfe69cf8652507`. The next critique is a new build that contains this replan's packages.

## Critique score

The checker is necessary and not sufficient. Rung 1 is done when one build, in one critique, follows every handout step with the named control, scores at least 9, and the three `check_rung01.py` commands pass on files the export dialog wrote. A green checker fed by Enter-before-Extrude, `id_pressed` instead of a menu click, `item_selected.emit` outside `_pick_end`, `Interaction._input` in the walk, a 1920×900 root, `dlg.current_path =`, `set_finish_*`, `set_up_to_face`, `LineEdit.text =`, or `doc.export_3mf()` does not pass this rung. Neither does a walk whose `2` in `20` changes the camera, whose variant chips cover the finish bar at 1280×800, or whose Exit Sketch is still an unmarked cancel.
