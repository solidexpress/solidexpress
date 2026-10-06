# Replan 13 WP1 — every armed tool names itself; the finish bar belongs to its sketch (post-spin-out audit)

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main` **after #134, #135 and #136 are merged**; if `git log origin/main` does not contain `Fix Slot rail arming` stop and report, do not re-implement it). Edit only the files below and add `game/tests/run_rung01_replan13_arm.gd`.

| File | Hunk (search by name; line numbers are `0573dea2` and will have shifted) |
|---|---|
| `game/scripts/sketch_mode.gd` | `set_tool` and, **after #136**, `tool_arm_hint` (one line per tool); `start_jaw_tool`; `shaft_lines_selected` (status only); `variants` arming (`set_tool_variant`) |
| `game/scripts/main.gd` | `_on_sketch_session_started`, `_on_sketch_tool_changed` (and `_on_status` only to log, never to change what it ignores; see decision 2) |
| `game/scripts/sketch_context_chrome.gd` | `reset_finish_for_new_sketch` (added by #136), `show_for_session`; a `finish_owner` string (the sketch feature id the Op/End/distance belong to) |

This WP is the **verification of leftovers 1 and 2 against the merged spin-outs**, plus the residual gap each leaves. Do **not** re-do what #136 did: `tool_arm_hint` for every tool, the Slot rail highlight, the Slot radius in the dim blank, `reset_finish_for_new_sketch`. Do not touch the Slot preview, the chip row (#134) or the Jaw preview and click statuses (#135).

## The bugs (sx-033, A8/A11a walker notes)

1. **Stale status on arm.** Pressing Line, Smart Dim or Trim on the rail left the previous tool's sentence on the status bar (for example `Jaw committed — …` or `Trimmed open jaw` while Smart Dim was armed). The walker could not tell a dead press from an armed tool. #136 adds `tool_arm_hint` for every `Tool` value; nothing proves that **every rail button** and every other arming path ends with a sentence that names the new tool, or that a later signal does not overwrite it.
2. **Empty status is a no-op (observation, not a decision to change it).** `main._on_status("")` keeps the old text (`if text != "": status_label.text = text`). Callers that emit `""` to clear (`viewport_interaction.cancel_stack` emits `status.emit("")` after clearing a measure pair) therefore never clear anything. That is the contract the replan 10/11/12 Esc suites rely on, so this WP does **not** change it. It only matters here if an arm path emits `""` (or a signal that ends in `_on_status` with the previous text) after the arm sentence.
3. **Finish bar carries the previous sketch.** sx-033 saw Cut / Up To Surface / a typed distance on a freshly opened sketch. #136 resets Blind / New / 20 for a brand-new sketch (`editing_fid == ""`) and deliberately keeps the values when the **same** sketch is re-entered after Save As. The residual: re-entering a **different** existing sketch (timeline double-click, yellow pad click, `begin_edit(other_fid)`) keeps the values of the sketch that was open before it.

## Decisions (see `rung-01-replan-13.md` 1 and 2)

- The tool sentence is emitted by `set_tool` only (never by the chip or rail code) and is the **last** status written by the arm: `_on_sketch_tool_changed` and the chrome sync must not emit a status.
- `_on_status` keeps ignoring `""`. If the audit finds an arm path whose last emit is not the tool sentence, fix that emitter (reorder or delete it); do not change `_on_status`.
- Arming by chip variant (`Center / Three Point`, `Across Flats / Vertex`, Slot variants) re-emits the tool sentence with the variant name appended: `Circle · Three Point — click 3 points on the rim`. One sentence per variant is allowed to be the base sentence if the variant has no distinct gesture.
- Finish-bar ownership: `sketch_context_chrome` stores `_finish_owner` (sketch fid or `""` for a new sketch). `show_for_session` is told the fid; when it differs from `_finish_owner`, the bar resets through `reset_finish_for_new_sketch()` and takes the new owner; when equal (Save As re-entry), nothing changes. File → New still calls `reset_finish_defaults()` and clears the owner.
- No new status strings other than those listed; every existing `status.emit` text stays byte-identical (the replan 10/11/12 suites assert many of them).

## Failing-first test — `game/tests/run_rung01_replan13_arm.gd` (create)

Real input only for the rail (press the buttons through `Viewport.push_input` at the button centre, as `run_rung01_replan12_rail.gd` does). Validation suite: it may enter the sketch with `FilmUI.enter_sketch`.

1. For **each button in `main._sketch_rail_buttons`** (#136) in rail order, after first pressing a *different* tool that ends with a distinctive status (Jaw, then a Trim): press the button, `await process_frame`, assert `main.status_label.text` starts with the tool's own word (`Select`, `Line`, `Arc`, `Circle`, `Rect`, `Polygon`, `Ellipse`, `Slot`, `Spline`, `Point`, `Trim`, `Extend`, `Smart Dim`, `Convert`, `Mirror`, `Pattern`, `Centerline`) and does not contain the previous tool's sentence. One check per button (about 20).
2. The same for the keyboard shortcuts the rail tooltips advertise (`S`, `L`, `C` …): one real key tap each, status starts with the tool word.
3. After arming Circle, `main._on_status("")` leaves `Circle — …` in place (the arm sentence is not erased by an empty emit); the chip variant press (`Three Point`) leaves a sentence that still starts with `Circle`.
4. Finish bar: open sketch A on the top face, set Cut + Up To Surface + distance 7; Exit Sketch; open a **new** sketch B on another plane: Blind, New, 20 (this is #136's row, asserted again). Exit; re-open sketch A through its timeline row (`begin_edit`): the bar shows A's session defaults only if A is the owner; re-open sketch B: Blind / New (**red on `0573dea2` and, if #136 is merged, red only here**).
5. Save As inside sketch A (the replan-12 flow) keeps Cut / Up To Surface / 7 (no reset on the same owner).

**Expected red** (not measured on the planning VM; record it): on `main` after #136, items 1–3 may already be green (then keep them as the regression net) and item 4 fails on the re-entry of a different sketch. If every item is green, the PR is the test file only, and says so.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_arm.gd
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_status.gd      # 9/0
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_slotarm.gd     # #136's suite
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan10_new.gd         # File → New resets
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan_finishbar.gd
```

## Do not

- Change the Slot, Jaw or chip-row code of #134/#135/#136.
- Reword an existing status string.
- Make a status clear after a timer. The status is the walker's read-back; it stays until the next event.

## Files not to touch

`ops_panel.gd`, `viewport_interaction.gd` (the Esc `status.emit("")` call sites are unchanged), `orbit_camera.gd`, C++.
