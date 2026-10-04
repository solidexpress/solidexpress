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

**Fix.** WP5 extends that script. It does not replace the checker rows that already pass. The new gestures are the acceptance check for this replan. Earlier packages leave the file alone.

### 7. Status hides a bad radius — P1 — WP2, WP4

**Root cause.** `Main._on_sketch_dim_submitted` always sets `Length %.4f mm` after a successful `commit_at_length`, which replaces `Polygon AF …`. A circle commit has no diameter echo. The Ø 6.089 bore and the AF 10.438 hex were both reported as ordinary lengths if they were reported at all. The pointer-commit path never goes through `dim_submitted`, so a drag-built hex can extrude with no `Cannot read dimension` and no AF line.

**Fix.** WP2 stores the sentence on the mode (`last_commit_text`: `Polygon AF 20.0000`, `Circle r=5.0000 (Ø10.0000)`, or `centre-to-flat 10.0000`). WP4 prints that sentence from `_on_sketch_dim_submitted` when the method exists, and the polygon/circle `click` status is the same sentence so a pointer commit is still explicit. `Length %.4f mm` remains the fallback for tools that do not set a sentence.

**Acceptance.** After Enter on `5` for a circle, status contains `r=5.0000` and `Ø10.0000`. After Enter on `20` for an across-flats hex, status contains `Polygon AF 20.0000` and does not contain `centre-to-flat`.

### 8. Export dialog defaults — P2 — no package

**Root cause.** None left at `fde6d95a`. `_show_file_dialog` for Export 3MF sets `current_dir` from the last export directory, else the document directory, else the home directory, and `current_file` from `_export_3mf_filename()` (`part.3mf` when the document has no name). A successful export stores `_last_export_dir`. The GUI nut did export (`Exported 3MF`, closed mesh). WP5 keeps using the dialog. Do not reopen this.

### 9. Centre-to-flat 10 is not the critique path — P2 — documented here

**Root cause.** The handout's centre-to-flat step (apothem 10 → AF 20) is a Smart Dimension from the hex centre to a flat. `_smart_dim_between` writes a distance whose line ref has role `self`, and `solver_planegcs.cpp` turns that into `addConstraintP2LDistance`. That path was not what produced AF 10.438 (a solved apothem of 10 is AF 20; a solved apothem of 10.438 would be an exact typed value, and 10.438 is not). The critique's required path is Polygon, Across Flats, typed `20`, then a circle with typed radius `5`.

**Fix.** No kernel change. WP2's status sentence distinguishes `centre-to-flat` from `Polygon AF`. WP5 builds the nut with typed AF 20, not with a centre-to-flat dimension of 10. A later critique may use centre-to-flat as an alternate and must expect AF 20 from an apothem of 10.

## Work packages

Five packages. File owners are exclusive. WP5 merges last and is the only one that edits `game/tests/run_rung01_wrench.gd` and the `Makefile`.

| WP | Owns |
|---|---|
| WP1 | `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan2_distance.gd` |
| WP2 | `game/scripts/sketch_mode.gd`, `game/tests/run_rung01_replan2_commit.gd` |
| WP3 | `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan2_pointer.gd` |
| WP4 | `game/scripts/main.gd`, `game/tests/run_rung01_replan2_shell.gd` |
| WP5 | `game/tests/run_rung01_wrench.gd`, `Makefile` |

Shared rules:

- Tests drive the controls a person uses. Keystrokes use `Viewport.push_input` with `keycode`, `physical_keycode`, `unicode`, and `pressed`, then a release, as `game/tests/run_place_tests.gd` does. Menu items that the test means as a mouse click are clicked at the popup item's screen rect. `id_pressed.emit` is allowed only where this replan names it (the End popup's `index_pressed`, which is how `item_selected` fires). OptionButtons the student changes go through `item_selected`. Buttons use `pressed` or a real click. Viewport picks go through `Interaction._input` or `FilmUI.viewport_click`. See `.cursor/rules/gdscript-click-driven-tests.mdc`.
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

WP2 adds `SketchMode.last_commit_text() -> String`. WP4 reads it. Empty string means WP4 keeps `Length %.4f mm`.

WP3 does not add a method. WP4 calls the existing `cancel_stack` and `_disarm_place`.

### WP1 — Distance is the number Extrude sends

Leftovers 1, 2 (the override and the radius label), 5 (Cut must not clear Up To Surface).

**Scope.** The finish bar only. No viewport pick changes, no `main.gd` status wiring.

**Files.** The WP1 row.

**Behaviour.**

- `extrude_distance()` and the Extrude button, as in leftover 1. Readout label name `ExtrudeReadout`, text `Extrude <n> mm`, updated on distance text changes and after a successful parse. Default readout contains `20` until the student types.
- Dim text changes push a length override when the sketch has a single-DOF preview. `typed_dim_value()` returns the parsed number. Circle dim has no `Ø` prefix. Across-flats suffix stays ` AF`.
- Remove the Cut handler's `set_finish_end("through_all")`.
- Select-all on the second click of the Distance LineEdit stays.

**Acceptance.** `run_rung01_replan2_distance.gd`:

- Second click on Distance, key events `7.5`, no Enter, Extrude `pressed`. `finish_requested` distance is 7.5. The readout contains `7.5`. The test source does not contain `set_extrude_distance`.
- Text `20.07.5` (select-all failed, append) emits `distance_rejected` and does not emit `finish_requested`.
- Dim blank, polygon tool, type `20` with key events and no Enter: `typed_dim_value()` is 20 and `sketch_mode.has_length_override()` is true while a preview is active.
- Cut then Up To Surface: Extrude disabled, face id empty. Up To Surface then Cut: End is still Up To Surface.

**Depends on.** Nothing. Merge any time.

### WP2 — Typed length wins over the cursor

Leftovers 2 (the click geometry), 7 (the sentence).

**Scope.** `sketch_mode.gd` only.

**Files.** The WP2 row.

**Behaviour.** As in leftovers 2 and 7. `click` / the pending-tip arm of `finish_extrude` use `effective_hover()` when a length override is set. `last_commit_text` is set for polygon AF, circle radius, and centre-to-flat. Construction geometry and the kernel tolerances stay.

**Acceptance.** `run_rung01_replan2_commit.gd`:

- The script sets the override by typing into the dim blank (key events). It does not assign `LineEdit.text`.
- Type `20`, then a viewport click whose sketch point is 4 mm from the origin along +X. The cursor distance is 4 and the override is 20, so the flats are at ±10. `last_commit_text` contains `Polygon AF 20.0000`.
- Type `5`, then a viewport click 2 mm out. Radius is 5. The text contains `r=5.0000` and `Ø10.0000`.
- With the override cleared, a viewport click at 10.438 mm builds a hex of AF 10.438 ± 0.05. That control case is the pointer path, and it must not be the result once an override is set.

The script builds the document with File → New and the sketch rail. The second point goes through `ViewportInteraction._input` or `FilmUI.click_sketch` after the digits.

**Depends on.** Nothing to merge. The override API already exists. The dim spin starts feeding it once WP1 has merged. Until then the test can type and press Enter, which already sets the override through `commit_at_length`, and also call the preview path by focusing the blank and relying on `value_changed`. If `typed_dim_value` is missing, the Enter path still has to produce AF 20.

### WP3 — Pointer: no accidental second point, Esc from a spin

Leftovers 2 (mouse-up), 4 (the spin and the selection rings).

**Scope.** `viewport_interaction.gd` only.

**Files.** The WP3 row.

**Behaviour.**

- Polygon and circle: mouse-up does not call `click`. A second press does. Enter is unchanged (it never went through mouse-up).
- On a canvas press, if `typed_dim_value()` is a number and `has_single_dof_preview()` is true, commit with `commit_at_length` of that number instead of `click(mouse)`. If the method is missing, keep today's `click`.
- `cancel_stack` releases SpinBox focus as in leftover 4. Body select and `insert_primitive` do not call `_ctx_triball`.

**Acceptance.** `run_rung01_replan2_pointer.gd`:

- Polygon, press at the origin, release 40 px away. The sketch has no hex (`entity` count unchanged, or no new lines). A second press 40 px away does create it.
- With a typed `20` in the dim blank (key events) and the anchor down, a canvas click commits AF 20, not the click distance. If `typed_dim_value` is absent the test fails with that gap.
- Palette box, viewport click to commit, click the HUD `W` line edit, one `push_input` Esc. `selected_body` is empty, `triball.active` is false. The test does not call `grab_focus` on Interaction.

**Depends on.** WP1 for the typed-canvas-click assertion. The mouse-up assertion and the Esc assertion stand alone. Merge the typed-click assertion after WP1, or keep it failing loudly until `typed_dim_value` exists.

### WP4 — New stays empty, and Esc reaches the menu

Leftovers 3, 4 (popup Esc), 7 (status wiring).

**Scope.** `main.gd` only.

**Files.** The WP4 row.

**Behaviour.** As in leftovers 3, 4, and 7. `_on_sketch_dim_submitted` uses `last_commit_text()` when that method exists and returns a non-empty string.

**Acceptance.** `run_rung01_replan2_shell.gd`:

- A solid exists. Click the File `MenuButton`, click the New item's rect, click Discard's OK button. Bodies empty, status contains `New — empty part`, status does not contain `Inserted`, `_place_kind` is empty. A viewport click at the centre does not insert a box.
- The Box `PaletteButton` is not the next palette child after Sketch. A `Primitives` label exists and the Box button is after the rail extrude button in tree order.
- Box placed, File menu opened by a click, one `push_input` Esc. The menu is hidden and `selected_body` is empty.
- A `last_commit_text` of `Circle r=5.0000 (Ø10.0000)` reached through a real dim Enter shows that sentence on the status line. If the method is absent, Enter still sets status and the test records the missing method as a failure rather than skipping.

**Depends on.** Nothing to compile. The specific sentence is complete after WP2. Esc's `cancel_stack` is complete after WP3 and already exists at `fde6d95a`. Each half lands on its own.

### WP5 — GUI end-to-end

Leftovers 1, 2, 3, 4, 5, 6. This is the package that makes nut 7/7, wrench 28/28, and thick 4/4 come from the operator's gestures.

**Scope.** Extend `game/tests/run_rung01_wrench.gd`. Append the four `run_rung01_replan2_*.gd` scripts to the `test-godot` recipe in the `Makefile`, after the existing `run_rung01_replan_*.gd` lines. `tools/check_rung01.py` stays as it is. No new modelling behaviour. If the walk fails on a bug in a file another package owns, and that package has already merged, WP5 may edit that file to make the walk pass. It does not take the file over for anything else.

**Files.** The WP5 row only.

**Changes to the walk** (keep the rest of the 163 checks):

1. **Nut distance.** Second click on the Distance LineEdit, type `7.5`, do not press Enter, press Extrude. Before export, the body's bbox Z is 7.5 ± 0.2. Export through the File dialog as today.
2. **Nut size before Extrude.** After typing `20` and committing (Enter, and a second run of the hex is not required), read the sketch geometry: flats at ±10 ± 0.2. After typing `5`, radius 5 ± 0.05. Status contains `Polygon AF 20` and `Circle r=5`. Fail the script if the hex AF is near 10.4 or the bore radius is near 3.04, before any extrude.
3. **Second New.** Replace `_file_new`'s `id_pressed.emit(0)` with a click on the File button and a click on the New item, then the existing Discard click. Assert bodies empty and status does not contain `Inserted`. The wrench sketch starts only after that.
4. **Esc.** After a palette box is placed (a dedicated step, not the wrench), focus the HUD `W` field by a click and `push_input` Esc once. Selection clears. Open the File menu by a click and `push_input` Esc once. The menu closes and the selection is clear. Delete that box with New before the wrench, or run this step after the checker so it cannot contaminate `wrench.3mf`.
5. **Up To Surface.** Keep the jaw cut. Choose Cut, then Up To Surface, by `item_selected`. Assert Extrude is disabled, then viewport-click the bottom face, assert Extrude enables, extrude. The wrench checker is the proof the cut went through. Also assert End is still Up To Surface after a later Cut click does not happen; the walk's own order is Cut then Up To Surface, and it must assert `get_finish_end() == "to_face"` and a non-empty `up_to_face_id` immediately before the jaw Extrude.
6. Checker commands unchanged: nut 7/7, wrench 28/28, thick 4/4, plus the existing jaw 21 measurement.

**Forbidden.** The edited helpers do not contain `set_extrude_distance`, `set_finish_end`, `set_finish_op`, `set_up_to_face`, `export_3mf(`, or an assignment to a LineEdit's `text`. Distance for the nut is committed by the Extrude click with no Enter. `_type_distance` may keep Enter for the wrench blank and the slot only if the nut step is the no-Enter path; prefer the no-Enter path for every distance in the walk.

**Depends on.** WP1 through WP4 merged. This is the first package that requires the distance parse, the typed polygon commit, the mouse-driven New, and the popup Esc at the same time.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | Distance 7.5 without Enter. Readout. Cut does not clear Up To Surface. No 3MF. |
| WP2 | Typed 20 beats a 4 mm cursor. Circle sentence. |
| WP3 | Mouse-up does not build the hex. Esc from the HUD spin. |
| WP4 | Mouse-driven New stays empty. Esc from the File menu. Status sentence. |
| WP5 | nut 7/7, wrench 28/28, thick 4/4, from those gestures. |

## Merge order

```
WP1 ──┐
WP2 ──┤
WP3 ──┼── WP5
WP4 ──┘
```

WP1, WP2, WP3, and WP4 merge in any order. WP3's typed canvas click is meaningful after WP1. WP4's specific circle sentence is meaningful after WP2. WP5 is last.

## Deferred

- Rungs 2–8, threads, a named jaw parameter, a datum tree beyond Top = XY. Same list as replan 1.
- A kernel change to point-to-line distance. `addConstraintP2LDistance` is already what a centre-to-flat dimension uses. The critique path does not need it.
- Hiding the rotate rings until a rotate drag. They are the selection affordance. Esc clearing the selection is what removes them from the shot.
- Removing palette primitives entirely. They stay on the rail, below the finish tools.
- Reopening export-dialog defaults, the open-mesh refuse, or the thin-wall sentence.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `850a40c91e7ff6772175a515b98ee3973ddd7e70f89ae7b276cfe69cf8652507`. The next critique is a new build that contains this replan's packages.

## Critique score

The checker is necessary and not sufficient. Rung 1 is done when one build, in one critique, follows every handout step with the named control, scores at least 9, and the three `check_rung01.py` commands pass on files the export dialog wrote. A green checker fed by Enter-before-Extrude, `id_pressed` instead of a menu click, `set_finish_*`, `set_up_to_face`, `LineEdit.text =`, or `doc.export_3mf()` does not pass this rung.
