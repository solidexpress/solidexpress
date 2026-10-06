# Replan 14 WP4 — Ctrl+Z / Ctrl+Shift+Z undo and redo sketch edits

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time). This is the **only C++ WP** of replan 14 (two small bindings on `SxSketch`); everything else is GDScript. Edit only the files and hunks below and add `game/tests/run_rung01_replan14_undo.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (item 7) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

| File | Hunk (search by name; line numbers are `305dcbff`) |
|---|---|
| `sxcore/src/sx_sketch.hpp`, `sxcore/src/sx_sketch.cpp` | two new methods `snapshot() -> String` and `restore(String) -> bool`, bound in `_bind_methods` |
| `game/scripts/sketch_mode.gd` | new undo history (`_undo_stack`, `_redo_stack`, `_undo_head`, `_undo_restoring`, `_undo_parked`), new public `undo() -> String`, `redo() -> String`, `can_undo()`, `can_redo()`, a call at the **end of `_redraw`** (~5621), `_activate_session` (~496, adopt / clear the history), `_end_sketch_session` (~845, park the history), `cancel` (~567, drop it), short `_undo_note("<op>")` calls at the op entry points (below) |
| `game/scripts/main.gd` | `_unhandled_input` Ctrl+Z / Ctrl+Y (~3625), `edit_undo` / `edit_redo` (~2430) |
| `game/scripts/viewport_interaction.gd` | `_gui_key` `KEY_Z` / `KEY_Y` branch (~3761) |

Do not change `Document` / `SxDocument` undo, the timeline, or `exit_sketch` / `graph_update_sketch`. #151 changes the Slot arm of `click()` and `slot_cc_status*` in `sketch_mode.gd`: you do not edit `click()`'s Slot branch; the one-line `_undo_note` you may add for Slot goes in `_add_slot` (not touched by #151).

## The bug (sx-034 walk-chunk2; leftover 7)

After a Jaw commit (`Jaw committed — …`), Ctrl+Z in the sketch did nothing and printed no status; the walker reopened `blank.sxp` instead. Expected: in an open sketch Ctrl+Z undoes the last sketch operation (entity add, Jaw, Trim, dimension edit, delete, Shaft Lines …) and prints `Undo: Jaw`; Ctrl+Shift+Z (and Ctrl+Y) redoes and prints `Redo: Jaw`; with nothing to undo it prints `Nothing to undo` (`Nothing to redo`).

## Cause (read on `305dcbff`)

`main.gd` `_unhandled_input` (`KEY_Z`: `if view.doc.can_undo(): view.undo(); _on_status("Undo")`), `edit_undo` and `viewport_interaction._gui_key` (`view.undo()` + `status.emit("Undo/redo")`) all act on the **document** history. While a sketch is open the live `SxSketch` is edited in place and is only written to the feature graph by `exit_sketch` / `graph_update_sketch`, so no document history entry exists for the Jaw. The kernel `sx::Sketch` has no snapshot API; `sketch_to_json` / `sketch_from_json` (`sxkernel/src/sketch_json.cpp`, ids preserved) exist and are what `.sxp` persistence uses.

## Decisions (see `rung-01-replan-14.md` 7)

1. **Bindings.** `SxSketch.snapshot() -> String` returns `sx::sketch_to_json(*sketch_).dump()` (empty string on a null sketch). `SxSketch.restore(json: String) -> bool` parses it, calls `sx::sketch_from_json`, and `adopt()`s the result **into the same `SxSketch` object** (the GDScript reference stays valid; entity and constraint ids are preserved, so selection, dimension records and the finish bar keep working). Returns false and leaves the sketch untouched on a parse error. Include `sx/sketch_json.hpp`; `sxcore` already links `sxkernel`. After this change Godot must run against the rebuilt `libsxcore.so` (`make build`).
2. **Stack lives in `SketchMode`.** An entry is `{json: String, dimensions: Array (deep copy), label: String}`: the state **before** the op. `_undo_head` is the snapshot (and `dimensions` copy) after the last recorded state.
3. **One choke point.** At the end of `_redraw()` (called after every geometry change; it already prunes orphan dimensions): compute `snapshot()`; if it differs from `_undo_head` and `_undo_restoring` is false, push `{before-state, _undo_label or the tool name}`, clear the redo stack, set the head, reset `_undo_label`. Changes in the **same frame** (`Engine.get_process_frames()`) merge into the entry already pushed in that frame (one Jaw click redraws several times); while a handle drag is active (`_drag` non-empty) or a Power-Trim drag runs, changes merge into the entry the drag started. Hover and preview redraws change nothing, so they push nothing (assert it).
4. **Labels.** `_undo_note(label)` sets the label for the next push. Entry points (one line each): Jaw commit `Jaw`; `_trim_open_jaw` / `trim_at` `Trim`; `extend` `Extend`; `shaft_lines_selected` `Shaft lines`; `set_dimension_value` and the Smart Dim commit `Dimension`; delete `Delete`; paste `Paste`; mirror / pattern / convert / fillet-corner by name. When no note was set the label is the armed tool's rail name (`Line`, `Circle`, `Rect`, `Polygon`, `Slot`, `Arc`, `Spline`, `Point`) or `Edit`. The exact set of names is free beyond `Jaw`, `Trim`, `Dimension`, `Line`, `Circle` (the test pins those five).
5. **Undo / redo.** `undo() -> String` pops, pushes the current state on the redo stack, restores (`sketch.restore`, `dimensions = deep copy`, `_tool_points.clear()`, `_clear_selection`, `_undo_restoring = true`, `_rebuild_dimension_labels()`, `_redraw()`, `_undo_restoring = false`, `_undo_head` = the restored state, `selection_changed` / `selection_actions_needed` emitted) and returns the label, or `""` when empty. `redo()` mirrors it. Status is printed by the callers: `Undo: <label>` / `Redo: <label>` / `Nothing to undo` / `Nothing to redo`.
6. **Routing.** In `main.gd` and `viewport_interaction.gd`, when `sketch_mode != null and sketch_mode.active`: Ctrl+Z (no shift) → `undo()`, Ctrl+Shift+Z and Ctrl+Y → `redo()`, the event is consumed, the **document is never undone from inside a sketch**. A focused `LineEdit` keeps its own text undo (the existing `numeric_field_focused` / `_text_field_has_focus` guards stay in front). Outside a sketch, behaviour and strings are unchanged (`Undo`, `Undo/redo`). `edit_undo` / `edit_redo` (Edit menu) follow the same rule.
7. **Lifetime.** `_activate_session` clears both stacks and sets the head, **except** when `begin_edit(fid)` re-enters the same sketch the moment after `_end_sketch_session` parked its history (File → Save / Save As exit and re-enter the session, `main._save_current`): `_end_sketch_session` stores `{fid, undo, redo, head_json}` in `_undo_parked`; `begin_edit` adopts it iff `fid` matches and the freshly loaded sketch's `snapshot()` equals `head_json`, otherwise drops it. `cancel()` and a new sketch drop it. Undo therefore survives Save / Save As and does not survive leaving the sketch for real.
8. **Limits.** Stack depth 100 (drop the oldest). No persistence to disk. The dimension label set after an undo equals the one the restored sketch derives (the WP1 builder; this WP does not edit it).

## Failing-first test — `game/tests/run_rung01_replan14_undo.gd` (create)

Template: `run_rung01_replan13_trim.gd` (`_boot`, jaw build) and `run_rung01_replan13_frame.gd` (`_push_key`, `FilmUI`). 1280×800. Setup (entering the sketch, placing the head circle) may use helpers; every click and key under test is real, Ctrl / Shift as modifier flags on `InputEventKey`.

1. Binding round trip (direct API, a plain row): an `SxSketch` with a circle, a line and a `radius` constraint: `s := sk.snapshot()`; add a line; `sk.restore(s)` → same entity ids and constraint ids as before the line was added, `solve()` ok; `restore("{")` returns false and changes nothing.
2. Face sketch (`FilmUI.enter_sketch_on_face`), count `n0 = sm.sketch.entity_ids().size()`. Jaw: rail `Jaw` press, three distinct real clicks → `Jaw committed — …`, count `n1 > n0`. Real `Ctrl+Z`: count `== n0`, `sm.dimensions` has no jaw width / angle record, status `Undo: Jaw`, the sketch is still active, **the document is untouched** (`view.doc.revision()` and the timeline length unchanged).
3. Real `Ctrl+Shift+Z`: the entity id set equals the one after the Jaw (same ids), the width / angle records are back (`dimension_label_screen_rects()` has `20`-type labels if WP1 landed, otherwise the records), status `Redo: Jaw`. Real `Ctrl+Z` then `Ctrl+Y`: same.
4. Empty: after undoing every entry, one more `Ctrl+Z` → status `Nothing to undo`; with an empty redo stack `Ctrl+Shift+Z` → `Nothing to redo`.
5. New op clears redo: undo the Jaw, draw a Line (rail, two clicks), `Ctrl+Shift+Z` → `Nothing to redo`; `Ctrl+Z` → `Undo: Line`.
6. Coalescing: a Circle with a typed radius (centre click, type `5`, Enter) is **one** entry (`Undo: Circle` removes circle and its radius constraint together); pointer moves and hover redraws push no entry (`_undo_stack.size()` unchanged after ten real motion events); a handle drag across many motion events is one entry.
7. Trim and dimension: build the jaw, along-jaw line, cross-jaw centerline; real Trim click → `Trimmed open jaw`; `Ctrl+Z` → `Undo: Trim` and the open-jaw walls are the pre-trim ones. Edit the width label to `18` (real click + type + Enter) → `Ctrl+Z` → `Undo: Dimension`, width reads `20` again.
8. Save keeps history: with an undoable Jaw in the stack press real `Ctrl+S` (absolute temp path as in `run_rung01_replan14_savelabels.gd`); `sm.active` still true; `Ctrl+Z` → `Undo: Jaw` (decision 7).
9. Exit and re-enter the sketch (Exit Sketch button, then timeline double-click): `Ctrl+Z` → `Nothing to undo`.
10. Outside a sketch (part mode) `Ctrl+Z` still undoes the document: extrude a box, `Ctrl+Z` → status `Undo` and the body count drops (regression); Edit ▸ Undo in a sketch follows decision 6.
11. With the sketch's Radius field focused (real click into it), `Ctrl+Z` does not undo the sketch (the field owns the key).

**Expected red** on `305dcbff`: rows 1 (no binding), 2–9 (nothing undone, no status). Record the observed statuses.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
make build
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_undo.gd
make test-kernel
for t in run_rung01_replan13_trim run_rung01_replan13_arm run_rung01_replan12_status run_rung01_replan12_labels \
         run_rung01_replan11_dim run_rung01_replan11_trim run_rung01_replan9_dirty run_rung01_replan13_dirty \
         run_menu_tests; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone
```

Counts equal the whole-suite table. `make test-kernel` is unchanged (this WP adds no kernel case; the binding is covered by row 1 of the Godot suite). The walk's own `Ctrl+Z` uses, if any, must still pass.

## Acceptance

- The new suite is green and was red on the starting ref.
- Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y in an open sketch undo and redo the last operation with the statuses `Undo: <op>` / `Redo: <op>` / `Nothing to undo` / `Nothing to redo`; the document is never touched from inside a sketch.
- Hover, preview and a drag do not flood the stack; one user action is one entry.
- Save / Save As inside a sketch keep the history.
- Kernel suite and walk unchanged; lint clean; CI `linux kernel` green (C++ builds with `-Werror` as configured).
- PR body: item 7 fixed; the list of op labels implemented.

## Do not

- Add a document-level undo for sketches, persist history to `.sxp`, or change the `.sxp` format.
- Touch `Document::undo`, `view.undo()` semantics, the timeline or the Edit menu items' text.
- Add `sx::Sketch` methods (use the existing JSON functions) or change the solver.
- Print any status other than the four listed; change an existing status string.
