# Rung 1 replan 6 — cut the trimmed jaw, open the centre dimension, save where the dialog shows

Status: plan only. No product code in this change.

Baseline: `main` at `3eb4f0318980d87636bd6dc0ba3ddab086775e7c` (merge of #85). Replan 5 is [`rung-01-replan-5.md`](rung-01-replan-5.md) (WP1–WP4, PRs #81–#85, all merged). The sx-026 critique of local build sha256 `b0130a670555ace2b0803fec7e8ebaf90d1704bc40e8494e5d5889a888c58bdc` scored **6/10** and failed rung 1. Symptom list, verbatim: [`rung-01-leftovers-sx026.md`](rung-01-leftovers-sx026.md). This replan names why `run_rung01_wrench.gd` can print 359/0 on this commit while that GUI walk fails, the fix for each leftover, and an acceptance check a person can perform with the mouse and the keyboard at 1280×800.

BUILD agents execute one WP each, on grok-4.6 with effort high and fast off. WP1, WP2, and WP3 do not edit the same files and merge in any order. WP4 merges last. Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1.

## Goal

A person using only the GUI, at **1280×800**, finishes UBC ELEC391 Exercise 1 (hex nut) and Exercise 2 (wrench). Replan 5 already states the nut, typed Distance 7.5, `Trimmed open jaw`, `Opposite face` (`Face: z 0.0 mm`), and a document that does not stick on `Failed to update sketch`. Those stay true. This replan makes the rest of the handout reachable:

- After `Trimmed open jaw`, Cut + Up To Surface + `Opposite face` + Extrude cuts the jaw and the Ø10 hole. The sketch may contain the leftover first centreline, the Center Three Point construction datum, the head arc, and the hole circle. If a cut is still refused, the status names the entity that breaks the chain.
- Smart Dimension, second click on the other circle's centre, opens the dimension popup. Typing `200` sets the centre distance. The blank is not left at the click gap (~201.5 mm).
- A bare export name is written in the folder the dialog is showing, including when that folder was typed into the path field and Enter was not pressed there.
- A head circle whose screen click is on the right half of the ground-sketch view stays at model +X through the tangent solve and the extrude. The checker is not relaxed.
- The radius blank and the extrude-distance blank are not the same control. `Exit Sketch` is readable at 1280×800.
- A centreline retry removes the previous centreline. Dimension labels that would occupy the same spot are stacked so each value can be read.

Checker commands are unchanged. Do not edit `tools/check_rung01.py`. Do not pass `--allow-mirror`. On this tip the pass lines are:

```
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Wrench is 28 rows when every conditional slot row runs. Exit code 0 is the pass.

Rung 1 is done when one GUI critique (sx-027) follows the checklist below, the three checker commands pass on files the export dialog wrote, `run_rung01_wrench.gd` prints 0 failures on this OCCT 8.0.1 build, and the score is at least 9. The walk must show the jaw cut, not only `Trimmed open jaw`.

## Situation

sx-026, desktop 1280×800, Godot on llvmpipe, tip `3eb4f031`, real mouse and keyboard. Overall **6/10**, rung 1 **FAIL**. The nut is 7/7. The jaw trims. The cut does not run, so slot, fillets, and the thickness edit were not reached.

| What replan 5 fixed in the GUI | What sx-026 still got |
|---|---|
| Power Trim reports `Trimmed open jaw` (B2.10–11). | Cut refused: `Open-profile cut needs a line chain (Flip Side toggles material)`. No wrench. |
| `Opposite face` stores `Face: z 0.0 mm` (B2.12). | Centre-to-centre Smart Dimension: status `2 sketch entities selected`, relation strip, no popup. Gap stayed ~201.5 mm. Blank bbox **233.97 × 44.88 × 10**, head on −X (`flipX`). |
| Exit / Undo / New clear `Failed to update sketch`. Typed Distance 7.5. Nut **7/7**. | Bare `nut.3mf` after a browse still `Exported 3MF → /tmp/sx-026-home/nut.3mf`. An absolute path saves in the requested folder. |
| Headless walk `run_rung01_wrench.gd` reports **359/0**. | B2.13–B5 not reached. Same export and `flipX` misses as sx-025, which reported **307/0**. |

Do not re-open the rows in "Out of scope" unless a new GUI walk shows they regressed. Do not recritique hash `3eb4f031` / `b0130a67`. The next critique is a build that contains WP4.

## Why 359/0 is not the sx-026 walk

`tools/lint_rung01_e2e.py` already rejects private calls (`trim_at`, `set_up_to_face`, `export_3mf(`, assigning `.text`, a root size other than 1280×800, a yield between press and release inside `_x11_click` / the Power Trim helper / the recovery helper). The walk obeys that lint and still misses every sx-026 failure. Each miss is a different gesture, not a looser tolerance.

### The jaw cut: the walk's sketch is not the GUI sketch

`finish_extrude` in `game/scripts/sketch_mode.gd` emits `Open-profile cut needs a line chain (Flip Side toggles material)` only when `op` is `cut` or `fuse` and `profile_is_closed(sketch)` is false (tolerance 1e-6). A new-body extrude that fails the same test uses `_open_profile_status()`, which names a point. The cut branch does not. sx-026's sentence is that cut branch, so the profile was actually open. It is not a special rejection of "circle plus lines".

`profile_is_closed` ignores construction geometry. A disjoint full circle (the Ø10 hole) does not fail a chain that already closes: circles are listed separately, and the function returns true once every line/arc chain meets. The hole is not, by itself, the refusal. The generic sentence makes it look like it is.

`_trim_open_jaw` emits `Trimmed open jaw` after `run_solve` and `_weld_jaw_profile` without asking `profile_is_closed`. The GUI can show the success sentence and still fail the later cut. The walk checks `profile_is_closed` immediately after trim, on a sketch that does close, and then the cut passes.

What the walk builds (`run_rung01_wrench.gd` `_draw_centre_rect`, `_draw_centreline`, `_power_trim_shaft_click`):

- One Ø10 at the origin, one Ø45 at sketch `(200, 0)`, one Center Three Point rectangle, labels edited to width 20 and angle 45.
- One construction centreline through the head, direction exactly `(-√2/2, √2/2)`, endpoints 25 mm from the centre. 25 mm is outside the Ø45 (radius 22.5), so the endpoints are not on the circle (`INFER_TOL` is 0.5 mm) and `_infer_on_circle` does not attach them.
- The cutter passes through the centre, so `_circle_meets_cutter` (15% of radius, 3.375 mm) matches the sketch Ø45, trim deletes that circle (`circ_id`), and the keep-side arc is the only cap.
- No second centreline.

What sx-026 built (B2.6–12):

- The same hole, the redrawn Ø45, and the Center Three Point datum (construction diagonal and construction +X, stored in `_angle_datum_lines`). Those datum lines are skipped by `_nearest_construction_line`. They are not the cutter.
- A first centreline, then a retry. `Tool.CENTERLINE` in `click()` never deletes the previous construction line, and it does not clear `_tool_points` after the second point, so the next click extends the polyline. The first line stays. Both are construction, so `profile_is_closed` skips them, but `_infer_line` still adds coincident / on-circle constraints when an endpoint lands within 0.5 mm of the Ø45 or a rectangle corner.
- A perpendicular cutter that can miss the sketch-circle gate. If the line is more than 3.375 mm off the head centre, `_circle_meets_cutter` rejects the sketch Ø45. Trim then uses `_model_circles()` (the solid's head edge), still emits `Trimmed open jaw`, and does **not** remove the sketch Ø45.
- `finish_extrude` then runs `run_solve`, `_weld_on_circle_endpoints`, and `_seal_tangent_bosses` **before** the closed test, and it does not call `_weld_jaw_profile` again. `_seal_tangent_bosses` turns a full circle that has two line endpoints on it into a new arc and deletes the circle. The leftover sketch Ø45 is that circle (the jaw walls end on its radius). The new arc is built from float angles. The trim arc is a second cap whose endpoints no longer meet the walls. `profile_is_closed` returns false. The status does not say which entity.

The walk never builds the leftover centreline or a cutter that misses the 15% gate, so seal never sees a second Ø45 and the 1e-6 joints survive the extrude solve. 359/0 counts that cut as a pass. sx-026 stops on B2.12.

### Smart Dimension: the walk's third click is not the GUI's second click

`_click_smart_dim` on the second centre calls `_smart_dim_between`. That function `_set_selected`s both circles, which emits `selection_changed`. `Main._on_sketch_selection` sets the status to `2 sketch entities selected`. `selection_actions_needed` shows the relation strip (`selection_actions` appends coincident, tangent, midpoint, and the rest whenever two entities are selected). The two-circle branch then calls `constrain("distance", current_gap)`. `constrain` records a distance at the current gap (~201.5 mm in the critique) and does **not** emit `dimension_edit_requested`. The popup (`ViewportInteraction._show_dim_edit`) opens only from `dimension_hit` inside `click()`.

`_smart_dim_centres` in the walk does click both centres, then reads `sm._dimension_label_pos2` (a private sketch-plane point, 4 mm off the midpoint) and clicks that label. The popup opens, and the walk types `200`. A person who clicks the two centres and waits for a popup never makes that third click. The gap stays the click distance. The blank comes out ~1.5 mm long (233.97 instead of 232.5). The walk's "popup is visible after the label click" assertion is the cheat.

`_click_uv` still goes through `_pointer_click`, which awaits a frame between mouse-down and mouse-up. Canvas clicks run on the press, so that yield is not what hides the popup. It is still not the X11 burst. The new tests use `_x11_click_screen` for the two centres and must not click the label to open the editor.

### Bare export: the walk updates `current_dir`; the GUI edits the path field

Godot 4.7's `FileDialog` has two line edits. `get_line_edit()` returns `filename_edit`. The other is `directory_edit` (accessibility name `Path:`). `update_dir` writes `dir_access`'s directory into that path field. Typing in the path field does nothing to `current_dir` until Enter runs `_dir_submitted` → `_change_dir`.

`_action_pressed` (OK) joins a non-absolute filename onto `dir_access->get_current_dir()`, then `hide()`, then emits `file_selected`. `Main._on_file_dialog_ok_pressed` runs on the button press, while the dialog is still visible, and stores only the filename (`_export_3mf_accept_name`). The directory is resolved later, in `_on_file_selected`, after the hide.

`_export_3mf_dialog_dir` prefers `file_dialog.current_dir`. It overrides that only when `_export_3mf_displayed_dir` finds another `LineEdit` whose text is an existing absolute directory. That scan skips any edit that is not `is_visible_in_tree()`. After `hide()`, the path field fails the test, the override returns `""`, and a bare name is joined onto `current_dir`.

`_export_3mf_start_dir` is HOME until a previous export or a saved part sets another directory. sx-026's HOME was `/tmp/sx-026-home`. The status `Exported 3MF → /tmp/sx-026-home/nut.3mf` is a bare name joined onto that HOME. An absolute filename still wins inside `_resolve_export_3mf_path`, which is why the full path worked.

`_export_via_dialog(..., bare=true)` never touches the path field. `_click_into_export_dir` double-clicks ItemList rows (and path-segment buttons) until `dlg.current_dir` equals the target. That click path calls `_change_dir`, so `current_dir` is already the target before OK, and the dead visibility override does not matter. `_dialog_dir` reads only `current_dir`. A green bare-export check in 359/0 is that ItemList path. sx-025 failed the same way (307/0).

### The blank mirror: the walk never clicks the right half of the window

`_click_uv(ctx, Vector2(200, 0))` computes `sm.to_model(uv)` and clicks that pixel. `plane_x` on a ground sketch is `Vector3.RIGHT` (`_setup_plane`: normal +Z, so the in-plane X hint falls through to world +X). The click is "wherever kernel +X projects", and the later check `head_c.x > 0` passes because the circle was placed at sketch u = 200. It cannot fail when the thing under test is "a click on the right side of the screen".

The ground-sketch camera, from the code on this commit (not from a screenshot):

- `ModelSpace.basis = Basis(Vector3.RIGHT, -PI/2)` maps kernel +Z to Godot +Y and kernel +Y to Godot −Z. Kernel +X stays Godot +X.
- `enter_sketch_view` sets yaw from `atan2(n.x, -n.y)` and pitch from `asin(n.z)`. For a ground normal `(0, 0, 1)`, `atan2(0, -0)` is π and pitch is 90°. `MAX_PITCH` is 89°, but this path does not clamp. `cos(90°)` is ~0, so yaw does not move the camera; it sits on Godot +Y.
- Up is `model_space.basis * plane_y` = Godot `(0, 0, −1)`. Camera-local X of kernel `(200, 0, 0)` is +200. In this pose, the right half of the window is kernel +X.

So a right-half click in the locked ground-sketch view should not, by itself, produce a head at −X. sx-026 (and sx-025) still exported a blank whose head was on −X. The walk's P2.6 print of a positive head centre does not contradict that, because the walk never placed the head with a right-half click and its shaft lines are the exact contacts `y = ±10`, `far_x = 200 - sqrt(22.5² - 10²)`.

`_restore_flipped_shaft_lines` puts back a line whose midpoint Y changed sign. It does not put back a circle whose centre X changed sign. `_infer_line` runs `run_solve` as soon as a tangent or an on-circle endpoint is inferred, which is before `finish_extrude` locks every sized circle. A tangent click that is not the exact contact can take DogLeg's other solution and carry the unlocked Ø45 to −X. The exact walk never builds that click, so 359/0 reports the head at +X. The checker `flipX` flag is a real mirror (`fx != fy` in `tools/check_rung01.py`), not a 180° rotation. Do not teach the checker to allow it.

The orientation fix is measured, then applied:

1. On a ground sketch, in the view Sketch-on-ground actually installs, click a pixel with screen x greater than half of 1280 and screen y near 400 (`_x11_click_screen`, no yield). Read the new circle's centre in sketch UV and in `to_model`. If that X is negative, the basis or `enter_sketch_view`'s up/right is wrong on the running binary even though the static pose above says otherwise. Fix that transform so the right half is kernel +X. Do not change `plane_x` to a constant that only makes `to_model(Vector2(200, 0))` positive — that is already true.
2. If step 1 is already positive, do not edit `ModelSpace.basis` or `orbit_camera.gd`. Continue on that circle: radius `22.5` typed into the radius blank, a Ø20 at the origin, then two tangent lines whose clicks are 2–4 mm off the exact contact (not `_draw_shaft_line`'s exact `far_x`). Extrude Blind 10. The head centre read from the mesh must stay at +X. If it does not, restore a sized circle whose centre X flipped sign across `run_solve`, the same way `_restore_flipped_shaft_lines` restores a shaft line. Confirm the offset-click assertion fails on `3eb4f031` before that restore. If a 2–4 mm miss still leaves the head at +X, the agent has not reproduced sx-026 and must not ship a camera change "just in case".

### Finish bar: the walk types a named line edit

B1.2 typed `22.5` into the top field and got `Extrude 22.5 mm` because that keystroke hit `DistanceLineEdit` (the spin labelled `D`). The radius blank is the neighbouring `DimLineEdit`. Both are `SpinBox`es with `custom_minimum_size` of `UiScale.px(200)`. The only circle cue is a 16 px `r` label (`DimRadiusCue`), shown for the circle tool only. The walk's `_type_dim` finds the node named `DimLineEdit` and clicks its centre. A person clicking the upper band of the finish bar hits `D`.

`Exit Sketch` is a text button (`UIIcons.button("ok", "Exit Sketch", ...)`) at the top of the left rail. The rail grows with that label. The finish bar is placed at a hardcoded `(60, 42)` (`show_for_session`). The dim spin covers the label. The walk never asserts the two rects are disjoint.

## Work packages

Four packages. File owners are exclusive. WP1, WP2, and WP3 merge in any order.

| WP | Owns | Leftover |
|---|---|---|
| WP1 | `game/scripts/sketch_mode.gd`, `game/tests/run_rung01_replan6_cut.gd`, `game/tests/run_rung01_replan6_smartdim.gd` | P0 cut, P0 Smart Dimension popup, P1 head stays on +X, P2 centreline retry and dimension labels |
| WP2 | `game/scripts/main.gd`, `game/tests/run_rung01_replan6_export.gd` | P1 bare name uses the path field |
| WP3 | `game/scripts/sketch_context_chrome.gd`, `game/tests/run_rung01_replan6_chrome.gd` | P1 radius vs `D`, `Exit Sketch` visible |
| WP4 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | The sx-026 sequence inside the walk. Last |

WP1 is one agent because the four sketch bugs live in one file. Four commits, in the order cut, Smart Dimension, centreline and labels, head sign. Do not split WP1 across agents. WP4 may edit a file another package owns only when the walk fails on a bug that package was supposed to have fixed, and only enough to make that assertion pass.

Shared rules:

- Window for every new script is `Vector2i(1280, 800)` via `FilmUI.ensure_test_viewport`. The same steps must be doable by a person at that size.
- Copy `_x11_click`, `_x11_click_screen`, and `_x11_type` from `game/tests/run_rung01_wrench.gd`. Do not await between button-down and button-up. Do not use `_pointer_click` or `_click_control` for the new assertions; both await a frame between press and release.
- Godot is `tools/godot/godot` (4.7-stable). Until WP4, run a new script directly: `tools/godot/godot --headless --path game --script tests/<name>.gd`.
- `user://` paths passed into `SxDocument` are `ProjectSettings.globalize_path` first.
- Do not edit `tools/check_rung01.py`, `orbit_camera.gd` (unless WP1 step 1 measured a negative X), `property_panel.gd`, `timeline_panel.gd`, `sxkernel/src/sketch.cpp`, or the replan-2 / replan-3 / replan-4 / replan-5 test scripts.
- Do not change the pre-existing failures in `run_camera_tests`, `run_place_tests`, `run_howto_tests` (`nav_preset` defaults to `FUSION`), or the known single failures in `run_infer_tests` and `run_icon_tests`.
- Leave `run_rung01_wrench.gd` unchanged until WP4. WP1–WP3 must keep it compiling and must keep `run_rung01_replan4_numeric.gd`, `run_rung01_replan4_dialog.gd`, `run_rung01_replan4_smartdim.gd`, and the `run_rung01_replan5_*.gd` scripts passing.
- Do not loosen sketch chain tolerances (1e-6) or the 3MF manifold gate. Do not pass `--allow-mirror`.
- Forbidden in every new replan-6 script, and still forbidden in the WP4 walk: `interaction._input`, `id_pressed.emit`, `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text`, assigning `SpinBox.value`, `text_submitted.emit`, `focus_dim_for_typing`, `focus_distance_for_typing`, `doc.export_3mf()`, `infer_enabled = false`, `dlg.current_path =`, `dlg.current_dir =`, `sketch_mode.cancel(`, `sketch_mode.exit_sketch(`, `sketch_mode.trim_at(`, `new_document(`, `graph_update_sketch(`, and `dimension_edit_requested.emit` from the test. The product code calls those. The tests click.
- Each new script is run on `3eb4f031` behaviour first (write the assertion, watch it fail, then change product code). A test that passes before the product change is the old cheat and does not count.

### WP1 — Cut the GUI jaw, open the centre popup, keep the head on +X

**Commit 1 — the cut after `Trimmed open jaw`.**

**Scope.** `finish_extrude`, `_seal_tangent_bosses`, `_trim_open_jaw`, `profile_is_closed`, and the weld helpers they already call. Do not change the 1e-6 tolerance. Do not commit an open profile.

**Behaviour.**

- A cut whose non-construction lines and arcs form one or more closed chains, plus any number of disjoint full circles (the Ø10 hole), is closed. Construction lines, including a leftover centreline and every id in `_angle_datum_lines`, stay out of the chain.
- Before `_seal_tangent_bosses`, if a full sketch circle is concentric with a jaw arc that trim already added (same centre within 0.5 mm, radius within 0.5 mm), delete that circle. It is the redrawn Ø45 that `_circle_meets_cutter` missed. The arc is the cap. Do not seal the hole at the origin when fewer than two line endpoints lie on it.
- After the extrude-time `run_solve`, weld the jaw again (`_weld_jaw_profile` on the floor, the two walls, and the arc, when those entities still exist) before `profile_is_closed`.
- If the profile is still open, the status names the breaker: entity type, entity id, and the open point from `_open_profile_point`, in one sentence that contains `breaks the chain`. Do not emit `Open-profile cut needs a line chain` for that case. Do not extrude.
- Success still cuts. The Ø10 circle is a hole through the blank. The jaw is open toward the pivot.

**Headless acceptance** (`run_rung01_replan6_cut.gd`) at 1280×800. Build the blank the way the wrench walk does only as far as a top face (Ø20 at the origin, Ø45, two tangents, Extrude Blind 10) with viewport clicks and the radius blank. Then, on the top face, this sequence and no shorter one:

- Circle radius 5 at the origin.
- Circle radius 22.5 at the head.
- Center Three Point rectangle at the head, long side along 45°, width edited to 20 if the clicks are only approximate.
- Centerline tool: a first construction line through the head along the jaw (about 45°, the leftover). End that chain (right-click or the Done control) so the next line is not an extension, then draw a second centreline that is perpendicular to the long sides but offset so the line misses the head centre by about 5 mm (more than 0.15 × 22.5). That miss is the point of the test. An exact centreline that deletes the Ø45 is the old walk, and this script must not stop there.
- Power Trim: one `_x11_click_screen` on the shaft side of the perpendicular line, toward the origin. Status contains `Trimmed open jaw`. The first centreline is still present at this moment (commit 3 removes it; this commit must still cut while it is present).
- Finish op Cut, finish end Up To Surface, click `Opposite face`, Extrude. The test does not call `set_up_to_face` or `trim_at`.
- On `3eb4f031` the status contains `Open-profile cut needs a line chain`. After the fix it does not. A jaw cut feature exists (`to_face` is the bottom face). The mesh is open through the jaw at mid-thickness and open through the origin hole. If the status contains `breaks the chain`, the test fails: the handout sketch must cut, not only report a better error.

**GUI acceptance.** The same clicks at 1280×800. `Trimmed open jaw`, then the cut. The jaw is open at the bottom face. The hole is through.

**Commit 2 — the second centre click opens the popup.**

**Scope.** `_smart_dim_between` and `_click_smart_dim` only. Do not change `viewport_interaction.gd` (the popup is already connected to `dimension_edit_requested`). Do not change the nut centre-to-flat path or the failed-coincident revert from replan 5.

**Behaviour.** When both references are circles or arcs, add the distance on the two centre roles (the current `constrain("distance", …)` path already resolves centres through `_closest_endpoints`). Then emit `dimension_edit_requested` for that dimension's index before returning. The popup is visible after the second click, with the current distance selected, so the next digits replace it. The status may still mention the selection; the popup is what the person types into. A failed solve that reverts the constraint does not open a popup on a stale index.

**Headless acceptance** (`run_rung01_replan6_smartdim.gd`) at 1280×800.

- Two circles, centres about 180–220 mm apart, radii 10 and 22.5, ground sketch, clicks on the canvas.
- Smart Dimension. `_x11_click_screen` on the first centre, then on the second. Do not click a dimension label. Do not call `_dimension_label_pos2`.
- On `3eb4f031` the popup is hidden and the status is `2 sketch entities selected`. After the fix, `interaction._dim_edit_popup.visible` is true before any further click.
- `_x11_click` the popup line, `_x11_type` `200`, Enter. Centre distance is 200 ± 0.2. The blank is not left at the original gap.
- `run_rung01_replan4_smartdim.gd` and `run_rung01_replan5_smartdim.gd` still print 0 failures.

**GUI acceptance.** Click both centres. The popup is up. Type 200. The centres are 200 mm apart.

**Commit 3 — one centreline, readable dimensions.**

**Scope.** The centreline arm of `click()`, and `_rebuild_dimension_labels` / `_drop_stale_dimensions`. Do not change angle-datum construction lines.

**Behaviour.**

- A two-point centreline clears `_tool_points` when the segment is committed, so the next click does not extend it.
- Committing a new centreline deletes every other construction line that is not in `_angle_datum_lines`. The previous cutter is gone. Datum diagonal and datum +X stay.
- Dimension labels that would sit within 2 mm of each other (sketch plane) are stacked, the same 2.5 mm step the constraint glyphs already use. Each label's text is one value. A deleted centreline's dimensions are dropped.

**Headless acceptance.** Extend `run_rung01_replan6_cut.gd` (same file, this commit). After the two-centreline sequence above, and before Power Trim, exactly one non-datum construction line remains, and it is the perpendicular one. After trim, no two dimension labels share a position within 2 mm. The cut assertion from commit 1 still passes.

**GUI acceptance.** Draw a centreline, then another. One cutter remains. The jaw dimensions can be told apart. The blob `19442081` is two stacked values, not one string.

**Commit 4 — the head stays on +X.**

**Scope.** The solve path that runs while a tangent is inferred and again inside `finish_extrude` (`_infer_line`, `_restore_flipped_shaft_lines`, `_lock_sized_circles`). Camera and `ModelSpace.basis` change only if the right-half measurement in step 1 is negative.

**Behaviour.** As in "The blank mirror" above. A sized circle whose centre X is positive before `run_solve` and negative after is put back, and the shaft lines stay on the side they were drawn.

**Headless acceptance.** Extend `run_rung01_replan6_smartdim.gd` or add the clicks to the cut script's blank setup — one place, this commit, so the file stays owned here. Ground sketch at 1280×800. Click the right half of the viewport (screen x > 640, y near 400). The circle centre's model X is positive. Type radius `22.5` into `DimLineEdit` (WP3 makes that field obvious; this commit may click the node by name). Circle radius 10 at the origin. Two line clicks 2–4 mm off the exact shaft contacts, inference left on. Extrude Blind 10. Mesh head centre X > 0 and within 5 mm of the sketch head's model X. On `3eb4f031` this last assertion fails if the solve flips the head; if it does not fail, do not invent a camera edit. Record the measured screen X and the model X in the test's printed line so sx-027 can compare.

**GUI acceptance.** Click the head on the right side of the ground sketch. After the tangents and Extrude 10, the head is on +X. `check_rung01.py` would not report `flipX` for that mesh.

**Depends on.** Nothing to compile. Merge any time relative to WP2 and WP3.

### WP2 — A bare name uses the path field, not HOME

P1 export.

**Scope.** `main.gd` only. Do not enable `use_native_dialog`. Do not change Cancel, Escape, or the WM-close guard from replan 4. Absolute filenames and the glued `.3mf` + absolute tail stay on `_resolve_export_3mf_path`.

**Behaviour.**

- `_on_file_dialog_ok_pressed` runs while the dialog is still visible. Snapshot every `LineEdit` that is not `get_line_edit()`, and remember the one whose text is an absolute path of an existing directory. That is Godot 4.7's `directory_edit` (`Path:`).
- A bare name (`_export_3mf_is_bare_name`) is joined onto that snapshot when it is non-empty, even if `current_dir` is still HOME and even if the path field never received Enter. The person does not have to press Enter in the path field for the folder they typed to count.
- If the snapshot is empty, keep today's `current_dir` join (the ItemList double-click path must keep working).
- Do not decide the directory inside `_on_file_selected` by scanning `is_visible_in_tree()` after `hide()`. The dialog is already hidden there; that scan is why sx-026 ignored the folder on screen.

**Headless acceptance** (`run_rung01_replan6_export.gd`) at 1280×800.

- Make a directory under `/tmp` that is not `HOME`. Open File → Export 3MF by clicking the menu row.
- `_x11_click` the path `LineEdit` (the line edit that is not `get_line_edit()`). `_x11_type` that directory. Do not press Enter. Do not double-click an ItemList row. Do not assign `current_dir` or `current_path`.
- `_x11_click` the filename line, `_x11_type` `nut.3mf`, click OK.
- On `3eb4f031` the file is under `HOME` and the status path starts with that HOME. After the fix the file exists in the typed directory, the status is `Exported 3MF → ` plus that directory and `nut.3mf`, and no copy exists only under HOME. The process is still running.
- A second export that types an absolute path still writes that path. One Cancel still leaves the process running (`run_rung01_replan4_dialog.gd` stays green).

**GUI acceptance.** At 1280×800, type a non-HOME folder into the path field, do not press Enter there, type bare `nut.3mf`, OK. The file is in that folder. Process id unchanged.

**Depends on.** Nothing. Merge any time.

### WP3 — Radius and extrude distance are different fields; Exit Sketch is visible

P1 chrome.

**Scope.** `sketch_context_chrome.gd` only. Do not change the first-key replace from replan 4 (`_dim_replace_next`, `_distance_replace_next`). Do not edit `main.gd`; the Exit Sketch button already shows its label. This package moves the finish bar off that label.

**Behaviour.**

- `show_for_session` places the finish bar to the right of the `SketchTools` rail's global rect (the rail that contains `ExitSketch`), with a gap of at least 8 px. The hardcoded `(60, 42)` x is the overlap: the rail is wider than 60 px because the button text is `Exit Sketch`.
- At 1280×800, `ExitSketch`'s global rect does not intersect `DimSpin` or `DistanceSpin`. The button text is fully inside the viewport.
- The radius blank shows a visible label `Radius` while the circle tool is active, not only the 16 px `r` cue. The distance blank's visible label is `Extrude`, not a lone `D`. The two spins are not adjacent: at least 24 px of gap, or another control between them.
- Clicking the radius blank and typing does not change `extrude_distance()`. Clicking the extrude blank and typing does not change the circle radius.

**Headless acceptance** (`run_rung01_replan6_chrome.gd`) at 1280×800.

- Start a ground sketch, choose Circle. `ExitSketch`.get_global_rect() does not intersect the dim spin or the distance spin. Both rects lie inside `(0, 0)–(1280, 800)`.
- The radius label's text is `Radius`. The distance label's text is `Extrude`.
- `_x11_click` the radius blank (not the distance blank), `_x11_type` `22.5`, Enter. A circle of radius 22.5 exists. `extrude_distance()` is still the default (20, or whatever it was before the keystrokes). The status does not contain `Extrude 22.5`.
- On a closed profile, `_x11_click` the extrude blank, type `7.5`, click Extrude. Status contains `Extrude Blind 7.5000 mm`. `run_rung01_replan4_numeric.gd` still passes.

**GUI acceptance.** At 1280×800 the words `Exit Sketch` are readable. Typing 22.5 in the radius field does not extrude 22.5. Typing 7.5 in the extrude field still extrudes 7.5.

**Depends on.** Nothing. Merge any time.

### WP4 — The walk is the sx-026 sequence

Last. This is the only package that edits `run_rung01_wrench.gd`.

**Scope.** Replace the four cheats below. Extend `tools/lint_rung01_e2e.py` so `game/tests/run_rung01_replan6_*.gd` is under the same forbidden list as `run_rung01_replan5_*.gd`, plus `dlg.current_dir =` and a call to `_dimension_label_pos2`. Append the new scripts to the `test-godot` recipe in the `Makefile` after the `run_rung01_replan5_*.gd` lines. `tools/check_rung01.py` stays as it is.

If the walk fails on a bug in a file another package owns, and that package has already merged, WP4 may edit that file so the walk passes. It does not take the file over for anything else. Slot, fillets, and Timeline Distance 10→14 stay in the walk. If they fail once the jaw cut runs, fix the owning file. If they pass, do not edit them.

**Cheats to remove** (these are why 359/0 passed):

1. **Smart Dimension.** `_smart_dim_centres` must not click `_dimension_label_pos2` to open the popup. After the second centre click the popup is already visible. Type `200` into it. Centre distance 200 ± 0.2. Delete the label-click branch.
2. **Head placement.** The Ø45 centre is a `_x11_click_screen` on the right half of the viewport (screen x > 640), not only `_click_uv(Vector2(200, 0))`. Mesh head centre X > 0 after the blank extrude. A negative X fails the walk. Do not add `--allow-mirror`.
3. **Bare export, once.** One export clicks the path `LineEdit`, types a non-HOME directory, does not press Enter in that field, types a bare filename, clicks OK. The file is in that directory. The ItemList double-click helper may remain for other exports; it must not be the only bare-name coverage. Absolute-path exports used by the checker may stay.
4. **Jaw sketch.** On the top face, after the Ø10 and the redrawn Ø45: Center Three Point rectangle, a first centreline along the jaw, end the chain, a second centreline perpendicular but about 5 mm off the head centre, one shaft-side Power Trim with `_x11_click_screen` and no yield between down and up. Status `Trimmed open jaw`. The first centreline is gone (commit 3). Profile closed. Cut, Up To Surface, `Opposite face`, Extrude. Status does not contain `Open-profile cut needs a line chain`. The jaw and the hole are open. The existing slot and fillet checks run on this jaw.

`_click_uv` / `_pointer_click` remain a yield-between-press-and-release. Do not use them for the four steps above. Numeric line edits keep `_x11_click` / `_x11_type`.

**Lint.** Extend `tools/lint_rung01_e2e.py`:

- `run_rung01_replan6_*.gd` fails the lint if it contains any replan-5 forbidden, an assignment to `current_dir`, or `_dimension_label_pos2`.
- The walk fails the lint if `_smart_dim_centres` (or its replacement) contains `_dimension_label_pos2`.
- The walk's new centreline, trim, right-half head click, and path-field export fail the lint if the source awaits between `pressed = true` and the matching `pressed = false`.
- Existing walk forbiddens stay.

**Depends on.** WP1, WP2, and WP3 merged.

**Checker rows.**

| Package | What it is responsible for |
|---|---|
| WP1 | A jaw sketch with a leftover-then-offset centreline, a redrawn Ø45, and a hole cuts after `Trimmed open jaw`. The second Smart Dimension centre click opens the popup and 200 sticks. A centreline retry leaves one cutter. Dimension labels do not share a point. A right-half head click stays at +X through an inexact tangent solve. |
| WP2 | A bare `nut.3mf` typed after the path field (no Enter in that field) is written in that directory, not HOME. |
| WP3 | `Exit Sketch` is not covered at 1280×800. `Radius` and `Extrude` are different fields. 22.5 in the radius field does not extrude. |
| WP4 | The four cheats are gone from `run_rung01_wrench.gd`. nut 7/7, wrench 28/28, thick 4/4. Lint clean. 0 walk failures. |

## Merge order

```
WP1 ──┐
WP2 ──┼── WP4
WP3 ──┘
```

WP1, WP2, and WP3 merge in any order. They do not share files. WP4 is last. sx-027 runs on the build that contains WP4.

## sx-027 GUI critique checklist

One session. Desktop **1280×800**. Mouse and keyboard only. No property JSON, no Box, no Timeline edit on the nut. Record status text after each step. Export only through File → Export 3MF. Note the process id at launch and again after the dialog. If the status becomes `Failed to update sketch`, try Exit, Undo, and New before killing the process.

Pass bar: every row below is WORKS, the three checker commands exit 0, `run_rung01_wrench.gd` prints 0 failures on this OCCT 8.0.1 build, score ≥ 9. A cut whose status contains `Open-profile cut needs a line chain` fails B2. A centre distance that was never typed into a popup fails B1. A bare export that lands in HOME fails D1. A head on −X fails B1. A wrench that never shows both `Trimmed open jaw` and a jaw cut stays under 9.

| # | Do this | Pass |
|---|---|---|
| A1 | File → New | `New — empty part` and no body |
| A2 | Sketch on the ground plane | `Sketch on ground (XY)`. `Exit Sketch` is readable. It does not sit under the radius field |
| A3 | Polygon, type `20` | Status contains `Polygon AF 20`. Flats at ±10 |
| A4 | Circle, type `5` into the field labelled `Radius` | Status contains `Circle r=5` and `Ø10`. It does not contain `Extrude 5` |
| A5 | Smart Dimension, centre to a flat, then the bore circle | Centre-to-flat near 10. Bore diameter 10. Solve is not left `failed` |
| A6 | Click the field labelled `Extrude`, type `7.5`, do not press Enter, Extrude | Status contains `Extrude Blind 7.5000 mm`. Thickness 7.5. No Timeline edit |
| D1 | Export. Click the path field, type a folder that is not HOME, do not press Enter in that field. Click the name field, type bare `nut.3mf`, OK. Also Cancel once | File is in that folder. Status `Exported 3MF → <path>`. Process id unchanged. Checker nut 7/7 |
| B1 | New. Circle radius `10` at the origin. Circle radius `22.5` with the centre clicked on the right half of the window. Smart Dimension: click both centres, type `200` in the popup that opened on the second click. Upper and lower tangents, a few millimetres off the exact contact. Extrude Blind 10. Thin off | Popup appeared without a third click on a label. Centres 200 apart. Bbox 232.5 × 45 × 10. Head centre at +X. Checker would not report `flipX` |
| B2 | Top face: Ø10 hole, redraw Ø45 at the head, Center Three Point jaw width 20 at 45°. Draw a centreline, then draw a perpendicular one (the first must disappear). Power Trim on the shaft side. Cut, Up To Surface, `Opposite face`, Extrude | Status `Trimmed open jaw`, then a cut. It does not contain `Open-profile cut needs a line chain`. One centreline. Dimension labels are readable. Jaw open at z = 0.5 and z = 9.5. Hole through |
| B3 | Slot 160 × 10 × 2.5 blind | Slot floor at z = 7.5 |
| B4 | Fillet R10 at the neck, R1 on top, bottom, and slot floor. Then R1.5 on the slot floor | R1 commits. R1.5 status contains `1.25` and the solid does not change |
| B5 | Timeline, base extrude Distance `14`, Enter, click away, export `wrench-t14.3mf`. Then jaw width 20 → 21 | Thick 4/4 (Z = 14). Angle still 45°. Wrench checker 28/28 |
| H | `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` | `0 failures`. Lint clean. The log shows the right-half head click, the popup after the second centre click with no label click, the path-field bare export, the centreline retry, `Trimmed open jaw`, and a jaw cut whose status does not contain `Open-profile cut needs a line chain` |

Score the jaw cut, the centre popup, the export folder, and the head sign separately from the 359/0 count. A walk that only trims, or that opens the popup by clicking a label the test computed, stays under 9.

## Out of scope

- Typed numeric replace, finish-bar Distance 7.5 once the extrude field is the one being typed, and dialog Cancel / Escape / window-close survival (replan 4). WP3 does not change the replace rule. WP2 does not change the quit guard.
- Nut centre-to-flat, bore diameter, and the failed-coincident revert (replan 5). The new popup is the blank's centre-to-centre click.
- `Trimmed open jaw` on a perpendicular shaft-side click, and `Opposite face` / `Face: z 0.0 mm` (replan 5). This replan starts after that status.
- Session recovery after a failed regenerate (replan 5). Do not return `Failed to update sketch` as the final status.
- Camera number keys versus sketch digits, variant chips under the finish bar, and empty-sketch Exit confirm (replan 2).
- Insert Box as the wrench blank.
- A kernel change to chain tolerance, a new constraint type, `use_native_dialog`, or committing an open profile.
- Editing `tools/check_rung01.py` or passing `--allow-mirror`.
- Rungs 2–8, threads, and a datum tree beyond Top = XY.
- The known `nav_preset` mismatches and the single `run_infer_tests` / `run_icon_tests` failures.
- Recritique of hash `3eb4f031` / `b0130a67`.
