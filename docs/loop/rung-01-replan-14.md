# Rung 1 replan 14 — leftovers after sx-034: saved labels, field focus, context bar, sketch undo, framing, rail highlight, timeline pencil

Status: plan only. No product code in this change.

Baseline: `main` at `93d31af` (replan-13 WP1–WP9 plus #148, #149, #150, #152) when this plan was written; line numbers in the WP docs are `305dcbff` or `93d31af` as each says, so search hunks by name. Launch every BUILD agent from the **full 40-character sha of `main` at launch time** (never a short sha). The sx-034 GUI critique of `d3cff60a` scored **8.5/10 and failed rung 1**. The condensed critique and the eighteen leftovers, with verbatim evidence, are in [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md). Do not re-critique sha256 `61e652514f738147c9ab54e4e9c2626a72eb0dc945469183cd0b94293e58602d`.

Everything geometric is already green from a real GUI build (blank 5/5, wrench 28/28, thick 7/7, nut 7/7, walk 551/0). What stopped the pass is five rows that already have their own fixes and a tail of UI defects no row named. This plan removes that tail so **sx-035 passes every row with score ≥ 9**.

**How this plan was measured.** The planning VM has no OCCT 8.0.1 build output, so nothing here was run. Every cause below was read from `main` and from the open #151 diff, and is labelled a *hypothesis*. Each WP starts with a **reproduce-first gate**: write the failing test, run it on the starting ref, paste the output in the PR. A test that is green on baseline stays as a regression net and the PR says the leftover is soft-GL or already fixed. Red counts are recorded by the BUILD agent, never edited to match this document.

## Already spun out — not planned here (verify after merge)

| Row | Fix | State at planning time | Planned here? |
|---|---|---|---|
| A8 Jaw zero-width on repeated click 2 | [#148](https://github.com/solidexpress/solidexpress/pull/148) | merged | no; re-verify row A8 |
| A9 sketch Frame puts the origin under the rail | [#149](https://github.com/solidexpress/solidexpress/pull/149) | merged | no; re-verify row A9 |
| A9b Up To Surface status depth | [#150](https://github.com/solidexpress/solidexpress/pull/150) | merged | no; re-verify row A9b |
| A11a Slot typed-length status (`Slot c-c 150.0000 R5.0000 — typed`) and the `c-c` field label | [#151](https://github.com/solidexpress/solidexpress/pull/151) | open | no; re-verify row A11a |
| L3 Fillet Radius strip / panel / status sync after Tab | [#152](https://github.com/solidexpress/solidexpress/pull/152) | merged (`93d31af`) | no; re-verify row L3 |

**What #151 and #152 touch (do not collide):**

- #151: `sketch_context_chrome.gd` `_sync_dim_affordance` (the Slot label becomes `c-c`, the `r` cue hides, `label_text` / `show_cue` locals); `sketch_mode.gd` `click` (Slot arm), new `slot_cc_status` and `slot_cc_status_for_dim`, `last_commit_text`; `viewport_interaction.gd` `_apply_dim_edit` (status after a dimension edit); the tests `run_rung01_replan12_status.gd`, `run_rung01_replan12_slotarm.gd`, `run_rung01_wrench.gd` (B13.1).
- #152 (merged; WPs read its code on `main`, never edit these hunks): `ops_panel.gd` Radius spin construction in `_build_body_ops`, `_arm_dressup`, `set_dressup_radius`, new `_commit_panel_radius` / `_notify_dressup_radius` / `_emit_armed_dressup_status` / `_radius_committing`; `viewport_interaction.gd` `_build_selection_strip` (the `_strip_radius` spin: `value_changed`, `focus_entered`, `update_on_text_changed = false`), `_on_dressup_radius_changed`, `_strip_line_focused` (replaces `_strip_radius_text_dirty`), `_write_strip_radius`, `_commit_strip_radius`, `_sync_strip_dressup_radius`; `run_rung01_replan13_radius.gd`.

**Rule for every WP:** do not edit a line #151 or #152 changes. Where a WP needs a hook in those functions it adds a **new function** and one call line elsewhere (see WP2). Whichever of #151 or a WP merges second rebases; #152 is already on `main`. A WP never changes a status string #151/#152 print, and never relies on the strip / panel Radius internals those PRs rewrite.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and every first try works: the labels stay put when the file is saved, the view keys work while a fillet is armed, the Fillet button is where it was a click ago, Ctrl+Z recovers a wrong Jaw, `F` and the wheel behave, Jaw lights its own button, and nothing prints a stale or missing status.

**Pass bar.** Score ≥ 9 and every checklist row PASS (or classified soft-GL with evidence). blank 5/5, nut 7/7, wrench **28/28**, thick **7/7**, walk **0 failures** (≥ 551 checks, plan target ≥ 590), `run_rung01_wrench.gd` and every `run_rung01_replan13_*.gd` / `run_rung01_replan14_*.gd` at 0 failures, lint clean. 3MF dimensions within 0.2 mm. The part is made in the real GUI with no script-side shortcut and a real Slot.

Checker commands (unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf          # 5/5
python3 tools/check_rung01.py nut    nut.3mf            # 7/7
python3 tools/check_rung01.py wrench wrench.3mf         # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14  # 7/7
```

Do not pass `--allow-mirror`. Exit code 0 is the pass. Godot stays `tools/godot/godot` (4.7-stable); put `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` before every Godot command and run scripts as `--script res://tests/<name>.gd` from `--path game`; the first run on a fresh checkout bakes `game/.godot` (`tools/godot/godot --headless --path game --import`). Do not commit `.gd.uid` files. The walk clicks real X11 widgets: also `export DISPLAY=:1`, and run it alone.

## BUILD agents (read before launching any)

- **Model:** grok-4.6, `effort: high`, `fast: false`.
- **starting_ref:** the full sha of `main` at launch time. WP8 starts only after its dependencies are merged (table below).
- **Prompt:** one file per agent: `rung-01-replan-14-wpN.md`. The prompts are the implementation; this file holds the decisions, the order, the suite table and the checklist. Do not redesign what a prompt specifies.
- **Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. A red quick check is a product failure: reopen the WP, do not merge. The same sentence is in every WP prompt.
- **Branches / PRs:** one WP per PR, titles below. Repository `github.com/solidexpress/solidexpress` only (never the snadrus fork). Each PR body lists the leftover numbers fixed / skipped, with the reason for every skip.
- **Reproduce first.** Each prompt says what the test is expected to show on baseline; the agent records the real run before changing product code (decision 12).
- **Tests are real-input.** Each WP adds `game/tests/run_rung01_replan14_<x>.gd` (validation suite). Setup (placing geometry, entering a sketch, arming a body) may use the sketch / document API and `tests/lib/film_ui.gd`; **every press, key and motion under test is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed through the viewport**. No `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` on a path under test. Layout assertions run at 1280×800. WP8 adds `_lint_replan14` to `tools/lint_rung01_e2e.py` (same needles as replan 13) and the Makefile loop; until it lands each agent greps its own suite for those needles.
- **Before opening a PR** run: the new suite, `python3 tools/lint_rung01_e2e.py`, `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` (0 failures, nut 7/7, wrench 28/28, thick 7/7, blank 5/5), every `run_rung01_replan13_*.gd` one at a time, and the suites each prompt names.

## Leftover → work package (all eighteen)

| # | Leftover | Sev | WP |
|---|---|---|---|
| 1 | Save As in a sketch adds duplicate / extra dimension labels | **B** | WP1 |
| 13 | Dimension labels drawn on the constraint-glyph cluster | U | WP1 |
| 17 | Δ overlay draws while a label editor is open | C | WP1 |
| 2 | View hotkey `3` typed into the focused Fillet strip / panel Radius field | **B** | WP2 |
| 5 | Ctrl+A in a sketch numeric field also selects all sketch entities | U | WP2 |
| 6 | First Esc in a focused sketch numeric field only blurs it | U | WP2 |
| 3 | Part context bar shifts ~54 px between states | **B** | WP3 |
| 4 | Part context bar overlaps the menu / Snap row, clips at the right edge | U | WP3 |
| 7 | Ctrl+Z in a sketch does not undo sketch edits | U (high) | WP4 |
| 8 | Part-mode `F` does nothing | U | WP5 |
| 9 | Wheel zoom is not cursor-anchored | U | WP5 |
| 10 | Jaw press highlights Rect; one `Center Three Point` chip | U | WP6 |
| 11 | Slot length field labelled `Radius r` | U | WP6 (verify #151 only) |
| 12 | Circle centre click prints no status | U | WP6 |
| 14 | Timeline pencil opens Rename, not Edit Sketch | U | WP7 |
| 15 | File → Open: Open button stays disabled | U | WP7 |
| 16 | First body named `extrude 3` | C | closed, no code; sx-035 rule 37 (WP8 documents) |
| 18 | DIAG checker note at T=14 | C | WP8 |

Blocks-pass items (1, 2, 3) are all in Wave A.

## Work packages

| WP | Prompt | What | Leftovers | Test | Depends on |
|---|---|---|---|---|---|
| WP1 | [`rung-01-replan-14-wp1.md`](rung-01-replan-14-wp1.md) | Saving never changes the dimension labels; labels clear of glyphs; no Δ overlay under an open editor | 1, 13, 17 | `run_rung01_replan14_savelabels.gd` | none |
| WP2 | [`rung-01-replan-14-wp2.md`](rung-01-replan-14-wp2.md) | Numeric fields release focus on commit so view keys work; Ctrl+A and Esc in a sketch field | 2, 5, 6 | `run_rung01_replan14_focuskeys.gd` | none (#152 is on `main`) |
| WP3 | [`rung-01-replan-14-wp3.md`](rung-01-replan-14-wp3.md) | Part context bar: left-anchored, below the menu row, wraps inside the window | 3, 4 | `run_rung01_replan14_ctxbar.gd` | none (#152 is on `main`) |
| WP4 | [`rung-01-replan-14-wp4.md`](rung-01-replan-14-wp4.md) | Ctrl+Z / Ctrl+Shift+Z undo and redo sketch edits | 7 | `run_rung01_replan14_undo.gd` | none. **Only C++ WP** (one small `SxSketch` binding) |
| WP5 | [`rung-01-replan-14-wp5.md`](rung-01-replan-14-wp5.md) | Part-mode `F` frames and says so; wheel zoom keeps the point under the cursor | 8, 9 | `run_rung01_replan14_camera.gd` | WP2 merged (the first measurement must run without a stale field focus) |
| WP6 | [`rung-01-replan-14-wp6.md`](rung-01-replan-14-wp6.md) | Jaw has its own rail highlight and no Rect chips; Circle centre status; Slot `c-c` label regression | 10, 11, 12 | `run_rung01_replan14_railstatus.gd` | #151 merged (item 11 assertion) |
| WP7 | [`rung-01-replan-14-wp7.md`](rung-01-replan-14-wp7.md) | Timeline pencil edits a sketch; File → Open enables on an existing `.sxp` | 14, 15 | `run_rung01_replan14_polish.gd` | none |
| WP8 | [`rung-01-replan-14-wp8.md`](rung-01-replan-14-wp8.md) | Walk rows, `_lint_replan14`, Makefile loop, DIAG note in the checker, STATUS | 18 + walk / lint / Makefile for all | the walk, lint, `test_check_rung01.py` | **Everything merged:** WP1–WP7, #151, #152 |

### Waves

| Wave | WPs | Why |
|---|---|---|
| 0 (running now) | #151 | The open spin-out (#152 already merged). Not ours; do not duplicate it |
| A | WP1, WP2, WP3 | **Blocks-pass** (items 1, 2, 3). Disjoint hunks; launch in parallel, immediately. WP2 and WP3 start from a `main` that already has #152 |
| B | WP4, WP5, WP6, WP7 | Usability and polish. Disjoint hunks. Launch with Wave A (rebase if a Wave A WP lands first) except the dependencies in the table: WP5 waits for WP2; WP6 waits for #151 |
| C | WP8 | The walk needs every product change and both spin-outs |

Merge order inside a wave is free; merge Wave A first (so sx-035 can start with the three blocks-pass fixes), WP8 last. Expected totals once everything is merged: `make test-godot` runs seven more suites; `make test-kernel` = current count (WP4 adds no kernel case; see WP4).

### File ownership (so parallel WPs do not conflict; search hunks by name, line numbers are `305dcbff`)

| File | Owner and hunks |
|---|---|
| `sketch_mode.gd` | **WP1**: `_restore_dimensions_from_sketch` (~4914), `_rebuild_dimension_labels` (~5341), `_dimension_label_pos2` / `_dimension_label_rect` (~5326), constraint-glyph placement (`_constraint_anchor`, ~5390). **WP4**: new undo history (`_undo_stack`, `snapshot_for_undo`, `undo`, `redo`), a call in `_redraw`, `_activate_session` / `_end_sketch_session` (clear the history). **WP6**: `variants_for_tool` (RECT arm), `start_jaw_tool` area (new `is_jaw_armed()`), `_click_circle` first-click status. #151 owns `click` Slot arm + `slot_cc_status*`. No shared lines |
| `sketch_context_chrome.gd` | **WP2**: `_on_dim_edit_gui_input` Esc branch (~1111), the Ctrl+A path of the same handler. #151 owns `_sync_dim_affordance` (~961). No other WP |
| `viewport_interaction.gd` | **WP1**: `_update_sketch_measure` entry (~2893, one guard). **WP2**: `_input` Ctrl+A / digit gates (~4660), `_gui_key` view-digit guard (~3646), `block_nav` lines in `_input` / `_unhandled_input` (~4482, ~4512), `_sketch_input` Ctrl branch (~2767), new `_wire_numeric_focus_release` + one call line right after `_build_selection_strip()` in `_ready` (~240). **WP3**: `_build_selection_strip` outer panel / row container (~293–307, **not** the `_strip_radius` block), `_refresh_selection_strip` (~4714), new `_layout_selection_strip`. **WP4**: `_gui_key` `KEY_Z` / `KEY_Y` branch (~3761). **WP5**: the marking-menu Frame items (`20` / `21`, ~5177–5181) only; no change to the `block_nav` lines. #152 owns the strip radius block and `_on_dressup_radius_changed` … `_sync_strip_dressup_radius` |
| `main.gd` | **WP1**: `_save_current` (~3293). **WP4**: `_unhandled_input` Ctrl+Z / Ctrl+Y (~3625), `edit_undo` / `edit_redo` (~2430). **WP5**: `fit_requested` handler (~722) and one `camera` signal connect. **WP6**: the rail build (`JawTool`, ~835), `_sync_sketch_rail_highlight` (~1514), `_on_sketch_tool_changed` (~1525). **WP7**: `_show_file_dialog` tail and a new `_sync_open_button` (~3260), `_build_ui` file dialog block (~517, one connect line) |
| `ops_panel.gd` | **WP2**: one call line `SxUi.release_focus_on_commit(_radius_spin)` in `_ready` right after `_build_body_ops()` (~104), not inside `_build_body_ops`. #152 owns the rest |
| `ui_spin.gd` | **WP2** only (new `release_focus_on_commit`) |
| `orbit_camera.gd` | **WP5** only (`zoom_at`, `_nudge_pivot_on_zoom_out`, `frame_selection_or_all`, new `framed` signal) |
| `measure_overlay.gd` | none (WP1 suppresses the call from `viewport_interaction.gd`) |
| `timeline_panel.gd` | **WP7** only |
| C++ | **WP4** only: `sxcore/src/sx_sketch.hpp`, `sxcore/src/sx_sketch.cpp` (two bindings). After WP4 Godot must run against the rebuilt `libsxcore.so` |
| `tools/lint_rung01_e2e.py`, `Makefile`, `tools/check_rung01.py`, `tools/test_check_rung01.py`, `game/tests/run_rung01_wrench.gd`, `docs/plan/STATUS.md` | **WP8** only |

PR titles:

- `Rung 1 replan 14 WP1: saving never changes the dimension labels`
- `Rung 1 replan 14 WP2: numeric fields give focus back so view keys work`
- `Rung 1 replan 14 WP3: the part context bar stays put and stays on screen`
- `Rung 1 replan 14 WP4: Ctrl+Z undoes sketch edits`
- `Rung 1 replan 14 WP5: F frames in part mode; wheel zoom keeps the cursor point`
- `Rung 1 replan 14 WP6: Jaw lights its own rail button; Circle centre says so`
- `Rung 1 replan 14 WP7: timeline pencil edits a sketch; Open enables on a typed file`
- `Rung 1 replan 14 WP8: walk, lint, Makefile and the DIAG note`

## Decisions (nothing left open)

1. **Dimension labels are a pure function of the sketch.** One builder derives the label records from the kernel sketch's `distance | radius | diameter | angle` constraints, **deduplicated** by `(type, sorted entity ids, value rounded to 1e-4)`, and both the live session and the re-entry after Save / Open use it. Typed circle radii (`5`, `22.5`) are labelled **both** live and after a reload (the only stateless choice; nothing is persisted). Save, Save As and Open never change the set. WP1.
2. **Label layout avoids glyphs.** A label rect never intersects another label rect or a constraint-glyph rect; the layout nudges the label (not the glyph) along its stack axis. WP1.
3. **A numeric field gives focus back on commit.** Enter, Tab, a spinner arrow click and a viewport click release a strip / panel Radius field to the viewport; Esc already does. Digits go to the field only while the user's caret is in it. The helper is opt-in (`SxUi.release_focus_on_commit(spin)`), not a change to `configure_spin`. WP2.
4. **Ctrl+A in a field is the field's.** No canvas select-all fires, no status changes. If a guard exists and still fails, the missing branch is found by the reproduce-first test, not guessed. WP2.
5. **First Esc in a focused sketch field drops the pending point** and prints `First point dropped — Esc again exits the sketch` (the A6 ladder stays two presses). WP2.
6. **The part context bar is `SelectionStrip`, left-anchored.** Its x is `max(ChromeDock.rail_right, LeftStack right + 8)` (fixed for a given left panel: never a function of the bar's own width), its y is `max(ChromeDock.top_inset, top_chrome bottom + 4)`, its width is capped at `viewport width − x − 8` and it wraps (`HFlowContainer`). The bar never intercepts clicks outside its own rect. State-specific items (`R` field, `Sketch`, `Look at`, `Active plane`) are appended after the common ones. WP3.
7. **Sketch undo is a snapshot stack, not a document undo.** `SxSketch.snapshot() -> String` / `restore(String) -> bool` (JSON through the existing `sketch_to_json` / `sketch_from_json`, same entity ids) back a GDScript stack of `{sketch_json, dimensions, label}` entries inside `SketchMode`. Ctrl+Z in an open sketch undoes one op and prints `Undo: <op>`; Ctrl+Shift+Z / Ctrl+Y prints `Redo: <op>`; empty → `Nothing to undo` / `Nothing to redo`. Outside a sketch the document undo is unchanged. A drag is one entry. The stack is cleared when a session starts and ends. WP4.
8. **`F` always says what it framed.** Part mode: `Framed selection` or `Framed all` (the HUD's strings, now shared), emitted by the camera so the key, the HUD button and the marking menu agree. Wheel zoom keeps the world point under the pointer: the pivot nudge toward content on zoom-out is removed when the pointer anchor is on the model plane. WP5.
9. **Jaw is a tool of its own on the rail.** `JawTool` joins the rail `ButtonGroup` (or `_sync_sketch_rail_highlight` lights it) while `SketchMode.is_jaw_armed()`; Rect is not lit then. The Jaw arm shows **no variant chips** (the one `Center Three Point` chip was Rect's). Rect's own chips are unchanged. WP6.
10. **Circle's centre click says so:** `Circle — centre set, click the rim or type a radius`. Every other circle string is byte-identical. WP6.
11. **The timeline pencil edits a sketch.** On a `sketch` row it calls `_edit_sketch_feature` (tooltip `Edit sketch`); on every other row it still renames. Rename also on F2 (selected row) and a right-click `Rename`. WP7.
12. **Reproduce first, classify honestly.** A green reproduction test is not a failure of the WP: it is the evidence that the leftover is soft-GL or already fixed (items 5, 8, 9, 15 are the likely candidates), and the PR says so. The regression test is kept either way.
13. **Item 16 is closed without code.** Body names are `<type> <timeline index>`; rule 37 tells the walker. Item 18 is a checker note + a printed DIAG header (WP8); `thick` and every probe stay.
14. **Lint without a hard count.** `_lint_replan14` globs `run_rung01_replan14_*.gd`, applies the replan-13 camera needles (with `_zoom_model` allowed), prints `<N> replan14 scripts are clean`, asserts `N ≥ 1`. WP8.
15. **Out of scope per WP.** Each prompt has a "Do not" list; none changes a replan 10–13 status string, and none touches what #151 / #152 own.
16. **Walk.** `run_rung01_wrench.gd` gains the rows in WP8 (real input only).

## Failing-first tests (red = on the starting ref, **hypotheses until a BUILD agent runs them**)

| Test | Expected red on `305dcbff` | Expected green |
|---|---|---|
| `run_rung01_replan14_savelabels.gd` | second `45°` label, extra `22.5` / `5` after Save As; label rects overlap a glyph rect; Δ overlay anchored while the editor is open | all |
| `run_rung01_replan14_focuskeys.gd` | key `3` after the strip spinner / typed `10` Enter does not change the view (field text gains a digit); panel Radius same; Ctrl+A / Esc rows may already be green (then they are the regression net) | all |
| `run_rung01_replan14_ctxbar.gd` | Fillet / Chamfer x differ by ~54 px between body / face / armed; bar rect intersects the menu or Snap rect; right edge > 1280 in face + armed | all |
| `run_rung01_replan14_undo.gd` | Jaw still present after Ctrl+Z; no `Undo` status | all |
| `run_rung01_replan14_camera.gd` | `F` prints nothing (or does nothing); the unprojected point under the pointer moves by > 2 px after wheel notches | all; a green `F` is classified (item 2's stale focus) |
| `run_rung01_replan14_railstatus.gd` | Rect button pressed after the Jaw press; chip label `Center Three Point`; Circle status unchanged after the centre click; the Slot `c-c` row is green once #151 is merged | all |
| `run_rung01_replan14_polish.gd` | pencil on a sketch row opens the rename editor; Open disabled with a typed existing name (if red) | all; a green Open row is classified soft-GL |
| `python3 tools/test_check_rung01.py` | new DIAG-expectation test errors (helper absent) | pass |
| `run_rung01_wrench.gd` (WP8) | new `B14.*` rows red until the product WPs are merged | 0 failures |

## Whole-suite check (every WP, and WP8 last)

Baseline is the critique's headless numbers for `d3cff60a` plus whatever #148–#152 changed: walk **551/0**; replan13 suites arm 135/0, chrome 53/0, dirty 21/0, frame 68/0, measure 76/0, radius 39/0 (more after #152), trim 28/0, typed 34/0; kernel 336 cases / 7966 assertions; lint `8 replan13 scripts are clean`. Run every `game/tests/run_*.gd` one at a time with `timeout 120`, nothing else running (`make test-godot` stops at the first failure; the pre-existing failures listed in `AGENTS.md` stay exactly as they are; do not flip `nav_preset`).

Deltas this plan requires (everything else identical before and after, after #151 / #152's own deltas):

| Suite | Change |
|---|---|
| `run_rung01_replan14_{savelabels,focuskeys,ctxbar,undo,camera,railstatus,polish}` | 7 new files, 0 failures each (counts recorded by the BUILD agents) |
| `run_parse_sweep_tests` | parses every `game/tests/*.gd`: +7 files |
| `run_rung01_wrench` | 551/0 → 551 + WP8 rows / 0 (plan target ≥ 590) |
| `python3 tools/lint_rung01_e2e.py` | adds `<N> replan14 scripts are clean` |
| `python3 tools/test_check_rung01.py` | one more test |
| `make test-kernel` | unchanged (WP4's binding lives in `sxcore`, covered by the Godot suite) |
| existing suites that assert Jaw chips or the Jaw / Rect highlight (`run_rung01_replan12_rail`, `run_rung01_replan13_arm`, `run_rung01_replan10_*` — grep `center_three_point` and `JawTool`) | WP6 updates only those assertions and says which in the PR |

## sx-035 GUI checklist (delta on the sx-034 checklist)

Take the sx-034 checklist ([`rung-01-replan-13.md`](rung-01-replan-13.md) "sx-034 GUI checklist", with its A/L rows and rules 1–36) and apply this delta. Keep every row id. New rows are **N**; the five failed rows come back as **re-verify** rows with their own pass text.

**Walk order** = sx-034's with the N rows inserted where they happen: A1, A2, **N7**, L1, A3, L5, A4, L6, A5, L10, A5b, L8, L11, A7, L2, A6, **N4**, A7b, A8 (re-verify, #148), A8b, **N8a**, A9 (re-verify, #149), L4, **N1a**, L12, A17, **N5**, A9c, **N1b**, A9b (re-verify, #150), A16, **N6**, A11a (re-verify, #151), A11b (now with real key `3`), **N2**, L3 (re-verify, #152), **N3**, A11c, A11d, A11e, A12, A13, A13b, A13c (DIAG note, **N9**), L7, A10, A10b, A14, L9, **N8b**, A15. Keep the blank open through A13c. A10 and A14 start a new document.

### Re-verify rows (the five failed rows)

| Row | Fix | Action | Pass looks like |
|---|---|---|---|
| A8 | #148 | Jaw: click 1, click 2, **click 2 again at the same pixel**, click 3; one click on the first glyph of the width label and of the angle label; type 20 and 45 | The repeated click 2 does **not** print `Jaw committed`; the entity count is unchanged; the status names the next step. Click 3 commits `Jaw committed — width …` with a non-zero width. Labels open on the first click |
| A9 | #149 | After `F` in the sketch, click the pivot circle centre at the origin, **30 px right of the visible rail, without moving the view** | The click lands (`Circle r=5.0000 …`). `Trimmed open jaw`, then `Jaw is already open — nothing left to trim here`. No pan (rule 28) |
| A9b | #150 | Cut, Up To Surface, opposite face | Closed jaw cut; status `Extrude Up To Surface 10.0000 mm` (the real depth, not the Blind spin) |
| A11a | #151 | Press the rail **Slot**; type radius 5 Enter; click the first centre; **read the entry field label**; type 150 Enter | Slot highlighted; status `Slot — …`; stadium preview; after the first centre the field label reads `c-c` (not `Radius r`); typed 150 → `Slot c-c 150.0000 R5.0000 — typed`; cut blind 2.5 → `Extrude Blind 2.5000 mm` |
| L3 | #152 | While Fillet is armed read **both** Radius fields and the status; type 10 in the panel then **Tab**; type 1.5 in the strip then Tab | Strip `R`, panel Radius and the status `Fillet r=` show the same number each time (never `0.0` / `1.0` against `10`). Enter uses the number on screen |

### New rows

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| N1a | WP1 | In the jaw sketch right after Trim, zoom the canvas so the head is ~150 px across; list every dimension label (text and place) | One `20`, one `45°`, plus `5` and `22.5` for the two typed circles (decision 1). No two labels overlap; no label sits on a constraint glyph; the first glyph of `20` and of `45°` is clickable |
| N1b | WP1 | File → Save As `pre-cut.sxp` with the sketch open, then list the labels again | `Saved <path>`. The list is **identical** to N1a (no second `45°`, no new `5` / `22.5`). Hover a label while its editor is open: no Δ overlay |
| N2 | WP2 | Fillet armed (key `3` first), click the strip `R` ▲ then ▼, type `10` Enter, press `3`; then the same with the panel Radius | After each commit key `3` prints `Top view` and the camera is Top; the field still reads `10` (no extra digit). Typing into a field after clicking its text still works |
| N3 | WP3 | Body selected: note the x of `Fillet` and `Chamfer`; click a face; arm Fillet; at 1280×800 | `Fillet` and `Chamfer` x are identical (±1 px) in all three states. The bar is fully below the menu row, does not touch `Snap`, ends inside the window (wraps if needed). Clicking the noted x arms **Fillet** every time |
| N4 | WP2 | Polygon AF 20 at the origin; Circle tool, click the centre, click into the Radius field: (a) Ctrl+A; (b) Esc | (a) The field text is selected; no `Selected … sketch entities`; the sketch selection is unchanged. (b) The first Esc prints `First point dropped — Esc again exits the sketch` and the rubber band stops; the second Esc exits |
| N5 | WP4 | After the jaw sketch is built (before Trim): Jaw commit, Ctrl+Z, Ctrl+Shift+Z, Ctrl+Z, Ctrl+Z … until empty | `Undo: Jaw` removes the Jaw; `Redo: Jaw` restores it; with nothing left `Nothing to undo`. A recovery without reopening the file |
| N6 | WP5 | Part mode: key `3`, wheel-in three notches with the pointer on the head, wheel-out three notches, then `F`, then `Shift+F` | The point under the pointer stays under it (±2 px) through the wheel; `F` prints `Framed selection` (body selected) or `Framed all`; the part lands right of the left panel inside the window. The HUD `Frame` button gives the same view |
| N7 | WP6 | Press rail **Jaw**; then rail **Rect**; then **Circle** and click one centre | Jaw's own button is highlighted and Rect is not; no `Center Three Point` chip for Jaw; Rect then lights Rect with its own chips; the Circle centre click prints `Circle — centre set, click the rim or type a radius` |
| N8a | WP7 | Timeline: click the **pencil** next to `sketch 2` | The sketch opens for editing (`Editing sketch`), no rename field. F2 on the row still renames |
| N8b | WP7 | File → Open, single-click `blank.sxp` (or type it) | The Open button is enabled; one press opens it (the Discard dialog if the document is unsaved). If the button stays disabled after one retry it is a product failure; a dropped click is rule 2 |
| N9 | WP8 | `python3 tools/check_rung01.py wrench wrench-t14.3mf` (DIAG) | Prints the `DIAG:` header; the failures are **exactly four**: `bbox Z (thickness)`, `grip slot present at y=0,z=8.75`, `1mm fillet top outer edge`, `1mm fillet on jaw top edge`. Record every fillet row. thick is the pass |
| A15 | WP8 | lint and `run_rung01_wrench.gd` | lint prints `<N> replan14 scripts are clean` (and the replan13 line); walk `0 failures` |

Changed text on carried rows: **A2** — pressing Jaw shows **no** variant chips; Rect shows Center / Three Point etc. **A11b** — the action uses the real key `3` and `4` with Fillet armed (item 2 is fixed), not HUD View ▸ Top. **A11d** — "one click on the Fillet button position" is stable (N3). **A13c** — the DIAG line above replaces "exactly three".

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 7/7, walk 0 failures, every A / L / N row passed or classified soft-GL **with evidence**, first-try fillets from the views the app offers, a real Slot.

## Soft-GL protocol additions (sx-035 walker)

Rules 1–36 stay (replan 10, 11, 12, 13). New:

37. **Body names are timeline indices.** `extrude 3` for the first extrude in a document that has a datum plane and a sketch is by design (item 16). Do not fail a row on it.
38. **Read the labels, not the picture.** For N1a / N1b list each label's text from the screenshot at the same zoom before and after the save; a one-frame ghost that the next frame removes is rule 36.
39. **After a commit the viewport owns the keys.** For N2 press the view key right after the commit (Enter / Tab / spinner). If the field takes the digit after one retry it is a product failure; a dropped key (rule 1) shows as *no change anywhere*, not as a digit in the field.
40. **Undo reads the status.** For N5 trust `Undo: <op>` and the entity count, not a lagging screenshot (rule 8).

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer; switching Godot off 4.7-stable.
- Checker formulas or tolerances (item 18 adds a note and a printed header only); `thick` and every wrench probe stay.
- #148–#152's own behaviour; `docs/plan/*` features other than the STATUS entry; the snadrus fork; PR #11.
- Renaming bodies (item 16); a document-level undo for sketches saved to disk; per-feature naming counters in the kernel.
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection on a path under test in the walk or the replan14 suites.
