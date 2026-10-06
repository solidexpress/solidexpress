# Replan 14 WP2 — numeric fields give focus back so the view keys work; Ctrl+A and Esc in a sketch field

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only the files and hunks below and add `game/tests/run_rung01_replan14_focuskeys.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (items 2, 5, 6) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Hunk (search by name; line numbers are `305dcbff` and will have shifted) |
|---|---|
| `game/scripts/ui_spin.gd` | new `static func release_focus_on_commit(spin: SpinBox) -> void` |
| `game/scripts/viewport_interaction.gd` | new `_wire_numeric_focus_release()` + **one call line right after `_build_selection_strip()` in `_ready`** (~240); `_gui_key` view-digit guard (~3646); `block_nav` lines in `_input` / `_unhandled_input` (~4482, ~4512); `_input` Ctrl+A gate (~4666); `_sketch_input` Ctrl branch (~2767) and its Esc case (~2811) only if the reproduction needs it |
| `game/scripts/ops_panel.gd` | **one call line** in `_ready` right after `_build_body_ops()` (~104): `SxUi.release_focus_on_commit(_radius_spin)` |
| `game/scripts/sketch_context_chrome.gd` | `_on_dim_edit_gui_input` (~1096–1121): the Esc branch (item 6) and the Ctrl+A path (item 5) |

## Do not collide with #152 (merged) and #151 (open)

#152 (merged, on `main`) rewrote the strip radius spin inside `_build_selection_strip` (`value_changed`, `focus_entered`, `update_on_text_changed = false`), `_on_dressup_radius_changed`, `_write_strip_radius`, `_commit_strip_radius`, `_sync_strip_dressup_radius`, `_strip_line_focused`, `_strip_user_typed`, and the panel Radius spin construction in `ops_panel.gd` (`_radius_committing`, `_commit_panel_radius`). #151 (open) edits `_sync_dim_affordance` (~961) in `sketch_context_chrome.gd` and `_apply_dim_edit` in `viewport_interaction.gd`. **You edit none of those lines.** The strip spin is reached through the existing member `_strip_radius` (a `SpinBox` named `StripRadius`) in your own new function; the panel spin through the one call line above. If #152 merges first, rebase and re-run its suite (`run_rung01_replan13_radius.gd`); if you merge first, #152 rebases over two added lines. Do not "fix" #152's code if a rebase is awkward: report it.

## The bugs (sx-034 A11b / A11e / walk-chunk3 / walk-chunk6; leftovers 2, 5, 6)

**Item 2 — view hotkeys swallowed by the strip `R` field (blocks-pass).** With Fillet armed the selection-strip `R` field keeps keyboard focus after the spinner ▲/▼ or after typing a value and Enter. A later `3` is typed into the field and the camera does not move. The tutorial needs `3` / `4` / `8` while Fillet is armed ("Fillet armed, key `3`, click each neck corner, key `4` …"); the walker had to use HUD View ▸ Top, and skipped key `3` in A11e. Same expected for the Modify panel Radius.

Repro: open a wrench part. Click the body → Fillet (`Fillet r=1.00 — edit Radius, click edges, Enter`). Click the strip `R` spinner ▲ then ▼, or type `10` Enter. Press `3` → a digit lands in the field, the camera does not move.

**Item 5 — Ctrl+A in a sketch numeric field also selects all sketch entities.** With a polygon in the sketch, Ctrl+A in the Circle **Radius** field printed `Selected 6 sketch entities`. Guards already exist (`_sketch_input` Ctrl branch ~2767 and `_gui_key` KEY_A ~3745 both return when `SxUi.numeric_field_focused(...)` or `_text_field_has_focus()`), so some other path fires or the sketch Radius field is not recognised.

Repro: new doc, sketch on XY, Polygon AF 20 at the origin. Circle tool, click the centre, click into the Radius field, Ctrl+A.

**Item 6 — Esc in a focused sketch numeric field only blurs it.** Circle centre placed, Radius field focused: the first Esc releases the field (`_on_dim_edit_gui_input` Esc → `clear_length_override()` + `release_dim_focus()`) and the rubber band keeps following; the ladder becomes three presses (blur, `First point dropped — Esc again exits the sketch`, exit).

## Cause (hypotheses; **reproduce first**)

- Item 2: the strip / panel `SpinBox` line edit keeps focus after a commit. `block_nav = _text_field_has_focus() or _sketch_keys_blocked()` then stops `camera.handle_input`, and `_gui_key`'s guard (`SxUi.numeric_field_focused`) returns false for `KEY_3` (the field gets the digit). Esc already works because `cancel_stack()` releases the field.
- Item 5: candidates, in the order to test: (a) a sketch path before `_sketch_input` (`_gui_input` / `_unhandled_input` → `_sketch_input`) runs while the chrome field's `LineEdit` did not yet own focus (the first click landed, focus arrives a frame later); (b) the `Interaction` control regrabs focus on the canvas press; (c) a different caller of `select_all_entities` (`main.gd` `edit_select_all` ~2535, `viewport_interaction._select_all` ~3851) is reached by the Ctrl+A event after the field consumed it; (d) the Radius field is the finish-bar / dim field whose focus owner is a `SpinBox` child that `numeric_field_focused` does not see (it checks `f is LineEdit or f is SpinBox or f.get_parent() is SpinBox`). The reproduction picks one; do not guess.
- Item 6: the chrome Esc handler consumes the event (`accept_event()`), so `_sketch_input`'s Esc ladder (`cancel_pending_draw`, `First point dropped …`) never sees it.

## Decisions (see `rung-01-replan-14.md` 3, 4, 5)

- **`SxUi.release_focus_on_commit(spin)`** (opt-in, in `ui_spin.gd`): connects, once per spin (guard with a meta flag), (1) the spin's `LineEdit.text_submitted` → `release_focus()` (deferred one frame so the owner of Enter has already read the text: the panel's Enter-commits-the-fillet handler and #152's strip commit run first); (2) `spin.value_changed` → if the change came from an arrow click (the left mouse button is down and the pointer is over the spin: `Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)` and `spin.get_global_rect().has_point(spin.get_global_mouse_position())` at emit time, **not** from the user typing: `LineEdit.has_focus()` with `text` unequal to the formatted value means typing) → deferred `release_focus()`; (3) the line edit's `focus_exited`/`text_submitted` never re-grabs. Tab already moves focus away: nothing to add. It does not change `configure_spin`, so property panels, dimension fields and the extrude Distance keep today's behaviour.
- **`_wire_numeric_focus_release()`** in `viewport_interaction.gd` calls it for `_strip_radius` (member, built by `_build_selection_strip`) and adds one `gui_input` hook on `Interaction` itself: a left press anywhere on the canvas calls `get_viewport().gui_release_focus()` when the focus owner is a `LineEdit` / `SpinBox` child (a click in the viewport releases the field). The part-mode pick must still run on that press (do not `accept_event()`).
- After a release, `1`–`8` change the view (status `Top view` etc. from `main.gd`), `F` / wheel / WASD work; digits go to a field only while the user has clicked its text (focus owner is the line edit).
- **Ctrl+A** in any focused `LineEdit` / `SpinBox` line edit selects the field's text, changes no status, and does not change `sketch_mode.selected`. Add the missing guard at the path the reproduction finds; keep the existing ones.
- **Esc in a focused sketch field** (chrome handler): after `release_focus` it also calls the same pending-draw drop `_sketch_input`'s Esc does (`sketch_mode.cancel_pending_draw()`; clear the measure pair) and emits `First point dropped — Esc again exits the sketch` **only if** `has_pending_draw_point()`; with nothing pending the first Esc just releases (no new status). Share a helper with `_sketch_input`'s branch so the sentence lives in one place. The second Esc is the existing ladder (exits a blank sketch / `Selection cleared — …`).
- No new status strings other than the existing `First point dropped — …`.

## Failing-first test — `game/tests/run_rung01_replan14_focuskeys.gd` (create)

Template: `run_rung01_replan12_pick.gd` / `run_rung01_replan13_radius.gd` (box, arm Fillet) and `run_rung01_replan13_frame.gd` (`_boot`, `FilmUI`, `_push_key`). 1280×800. Setup (placing the box, selecting the body with `FilmUI.select_face`-style helpers, entering the sketch) may use helpers; **every click, key and motion below is a real event** (`Viewport.push_input`).

Part mode (item 2):

1. Place a box, select the body, press the strip `Fillet` button with a real click (`FilmUI.click_control`): `Fillet r=… — edit Radius, click edges, Enter`.
2. Real click on the strip `StripRadius` ▲ arrow (right edge, upper half of its rect), then ▼ (lower half). Then a real `KEY_3` press/release. Assert: `camera` is at the Top preset (`absf(camera.pitch − Top pitch) < 0.01`; read, do not write), the status log has `Top view`, the strip text parses to the same number as before the key (no stray `3`).
3. Real click into the strip's text, Ctrl+A, `1`, `0`, Enter (through `_push_key`), then `KEY_4`: Back view (`Back view` status), strip and panel read `10` (`_parses_to`), no stray digit.
4. After step 3 press `KEY_8`, `KEY_3` again: each changes the view.
5. Caret rule: real click into the strip text, real `KEY_3` → the field text contains `3` (digits still type while the caret is in the field) and the camera did not move.
6. A real left click on an empty viewport point releases the field: `get_viewport().gui_get_focus_owner()` is not a `LineEdit` afterwards; `KEY_7` → Iso.
7. The same rows 2–4 for the Modify panel Radius (`ops_panel._radius_spin`; scroll it into view with `FilmUI.ensure_control_visible`; click its arrows and text with real events).
8. Esc still clears the armed fillet (`Edge pick cancelled`) with the field focused (regression).

Sketch (items 5, 6):

9. `FilmUI.enter_sketch` on the ground. Polygon AF 20 at the origin (rail press, centre click, type `20` Enter through the real dim field). Circle tool (rail press). Click the centre; click into the Radius field (the chrome dim field; find it as the replan 12 suites do). Real `Ctrl+A` (`InputEventKey` with `ctrl_pressed`). Assert `LineEdit.get_selected_text() == LineEdit.text` and non-empty, `sm.selected.is_empty()` (or unchanged from before the key), and no status entry begins `Selected` (item 5).
10. Real `Esc` with the field focused: `sm.has_pending_draw_point()` is false, the last status is `First point dropped — Esc again exits the sketch`, the preview circle is gone (`sm.preview_distance()` unavailable / the preview node hidden), the field no longer has focus (item 6). A second real `Esc` follows the existing ladder.
11. Repeat 10 with the field **not** focused: exactly the same two-press ladder as A6 (regression for `run_rung01_replan12_*`).

**Expected red** on `305dcbff`: rows 2, 3, 4 (a digit in the field, no camera move), 7; 6 may already be green; rows 9 and 10: 10 red (no `First point dropped` on the first Esc); 9 is a **reproduce-first** row: if it is green the PR classifies item 5 as already fixed / soft-GL (the walker's Ctrl+A may have landed before the field had focus) and keeps the row as the regression net. Record the real focus owner class and the status you observe.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_focuskeys.gd
for t in run_rung01_replan13_radius run_rung01_replan12_pick run_rung01_replan12_fillet run_rung01_fillet_tests \
         run_rung01_replan11_fillet_ui run_rung01_replan12_status run_rung01_replan12_slotarm run_rung01_replan10_esc \
         run_rung01_replan13_measure run_menu_tests run_icon_tests; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
```

Counts equal the whole-suite table (`run_menu_tests` keeps its pre-existing failures; `run_icon_tests` keeps its one). `run_rung01_replan13_radius.gd` must stay green with and without #152 merged.

## Acceptance

- The new suite is green and was red on the starting ref (row by row in the PR).
- After a spinner click, typed value + Enter, Tab or a viewport click the keys `1`–`8` change the view, with Fillet armed, for the strip and the panel field.
- Typing digits into a field after clicking its text still works.
- Ctrl+A in a focused sketch field never changes the sketch selection or the status.
- The first Esc in a focused sketch field with a pending point prints `First point dropped — Esc again exits the sketch`.
- Walk 0 failures; replan 12 / 13 Esc, fillet and radius suites unchanged; lint clean.
- PR body: items 2, 5, 6 fixed / skipped (item 5 may be "already green on baseline, classified soft-GL, regression row added").

## Do not

- Change `SxUi.configure_spin` or the focus behaviour of property-panel, dimension-blank and extrude-Distance fields.
- Change Enter's meaning (the panel's Enter still commits an armed fillet), the Esc ladder strings, the face-click rule or any #151 / #152 behaviour.
- Edit the strip radius block or `_write_strip_radius` / `_commit_strip_radius` / `_sync_strip_dressup_radius`.
- Add a global "release focus on every click" for docks and dialogs.
