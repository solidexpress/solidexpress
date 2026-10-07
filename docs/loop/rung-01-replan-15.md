# Rung 1 replan 15 — leftovers after sx-035: Fillet stays armed on Enter, Contours highlight, the open-jaw chain re-verified, export name, Extrude click, strings

Status: merged: WP1–WP7 on main at PENDING_SHA

Baseline: `main` at `d534765cf39b6418e889a72248b3d528775629ad` (replan-14 WP1–WP8 plus the seven sx-035 spin-outs #163–#169, all merged) when this plan was written; line numbers in the WP docs are `d534765c` and are marked `~`, so search hunks by name. Launch every BUILD agent from the **full 40-character sha of `main` at launch time** (never a short sha). The sx-035 FULL GUI critique of linux-test-build `d408a8c7` scored **~6.5/10 and failed rung 1**. The condensed critique and the ten leftovers, with verbatim evidence, are in [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md). Do not re-critique sha256 `bccb500819c39690218e6ebfdaed01fc79f00d6b4cc1de2c3b2965456dc8cfb8`. Replan 14 is [`rung-01-replan-14.md`](rung-01-replan-14.md).

Geometry went red in sx-035 almost entirely because **A9 Power Trim did not open the jaw**. [#165](https://github.com/solidexpress/solidexpress/pull/165) fixes that; A9b, A11e, A12 and A13c were knock-ons with no spin of their own. What is left is one new regression the replan-14 test masked (N2: Enter in the Radius field disarms Fillet), one UX defect that hides the right contour (Contours highlight), and a tail of small defects. This plan removes them so **sx-036 passes every row with score ≥ 9**.

**How this plan was measured.** The planning VM has no OCCT 8.0.1 build, no `libsxcore.so` and no Godot run, so nothing here was executed. Every cause below was read from `main` at `d534765c` and is labelled a *hypothesis*. Each WP starts with a **reproduce-first gate**: write the failing test, run it on the starting ref, paste the output in the PR. A test that is green on baseline stays as a regression net and the PR says the leftover is already fixed or soft-GL. Red counts are recorded by the BUILD agent, never edited to match this document.

## Already spun out — merged, not planned here (verify only)

| Row | Fix | State | What it touched (do not edit these hunks) |
|---|---|---|---|
| A9 Power Trim opens the jaw from a profile Line | [#165](https://github.com/solidexpress/solidexpress/pull/165) `81a6910` | merged | `sketch_mode.gd`: `_trim_open_jaw`, `_jaw_cutter_for_click`, `_jaw_long_sides`, `_cutter_crosses_both_sides`, `_jaw_no_cap_status`; `run_rung01_replan14_trim.gd` |
| N1a / N1b dim labels at 150 px and after Save As | [#164](https://github.com/solidexpress/solidexpress/pull/164) `73a2bfd` | merged | `sketch_mode.gd`: `click` (the `dimension_hit` first-glyph path), `dimension_hit`, `_rebuild_dimension_labels`, `_dimension_label_pos2`, `_dimension_label_rect`, `reapply_dimension_records`, `_enter_camera` / `_leave_camera`; `main.gd` `_save_current`; `run_rung01_replan14_savelabels.gd` |
| A11a Slot radius typing steals Extrude focus | [#163](https://github.com/solidexpress/solidexpress/pull/163) `18eb043` | merged | `sketch_context_chrome.gd` `_sync_dim_affordance`, `focus_dim_for_typing`, `release_dim_focus`; `sketch_mode.gd` `has_single_dof_preview`; `viewport_interaction.gd` `_sketch_input`, `_try_*_length_key`; `run_rung01_replan12_slotarm.gd` |
| N4 Esc from a focused sketch field: two presses | [#167](https://github.com/solidexpress/solidexpress/pull/167) `1007303` | merged | `sketch_mode.gd` `drop_pending_draw_esc`, `esc_keep_sketch`, `set_tool`, `_activate_session`; `viewport_interaction.gd` (4 lines) |
| A11c Fillet edge re-click toggles | [#166](https://github.com/solidexpress/solidexpress/pull/166) `8c5be4c` | merged | `ops_panel.gd` `_toggle_dressup_edge`, `_accumulate_dressup_edge`, `handle_viewport_miss`; `document_view.gd`; `run_rung01_replan11_fillet_ui.gd`, `run_rung01_replan12_pick.gd` |
| N6 HUD Frame = `F` | [#169](https://github.com/solidexpress/solidexpress/pull/169) `f73c8e2` | merged | `orbit_camera.gd` `_frame_world_aabb`, `_frame_radius_in_chrome_canvas`, `sketch_fit_canvas_rect`; `view_hud.gd`; `main.gd` `_build_ui` (1 line); `run_rung01_replan14_camera.gd` |
| L3 Fillet strip `R` shows the committed radius; Tab / Enter return viewport keys | [#168](https://github.com/solidexpress/solidexpress/pull/168) `d534765` | merged | `ops_panel.gd` `_build_body_ops` (Radius spin), `_commit_panel_radius`, `_reveal_radius`, `set_dressup_radius`; `ui_spin.gd`; `viewport_interaction.gd` `_build_selection_strip` (`_strip_radius` block), `_commit_strip_radius`, `_write_strip_radius`, `_sync_strip_dressup_radius`, `_on_numeric_canvas_press`, `_input`; `run_rung01_replan13_radius.gd`, `run_rung01_replan14_focuskeys.gd` |

**Rule for every WP:** read these functions on `main`; edit one only where the WP doc names it, and then only the hunk it names (WP1 owns a two-line change inside the #168 strip block and the matching panel lambda; nothing else is allowed in them). A WP never changes a status string any of these PRs print.

## Goal

A person using only the GUI, at 1280×800, builds the rung-1 wrench from the handout and every first try works: the open jaw trims with a plain Line, the Contours chips show which region each is, the view keys work with Fillet armed after any commit (Enter included), the slot-floor fillet picks the slot floor, the export keeps the `.3mf` the user typed, a click on Extrude extrudes once and says only `Extrude Blind 10.0000 mm`, and no status shows an entity id.

**Pass bar.** Score ≥ 9 and every checklist row PASS (or classified soft-GL with evidence). blank **5/5**, nut **7/7**, wrench **28/28**, thick **7/7**, walk **0 failures** (≥ 646 checks today; plan target ≥ 690 after WP7), every `run_rung01_*.gd` suite at 0 failures (`run_rung01_wrench.gd`, `replan2` … `replan15`), lint clean, 3MF dimensions within 0.2 mm, the part made in the real GUI with no script-side shortcut and a real Slot.

Checker commands (unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf          # 5/5
python3 tools/check_rung01.py nut    nut.3mf            # 7/7
python3 tools/check_rung01.py wrench wrench.3mf         # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14  # 7/7
```

**Reading the wrench total.** The wrench checker prints **28 rows when it finds the grip slot and 22 rows when it does not** (`wrench_tests` adds the slot-floor / width / length / X-centre / floor-fillet / below-solid rows only when `xs` is non-empty; `rung-01-leftovers-sx033.md` already recorded "22 rows … full handout with slot is still 28"). The sx-035 critique's "22 probes, not 28" is therefore the missing-slot signal, not a tooling change. Every checker assertion in this plan is `28/28`; a `22` total fails the WP. Do not edit `check_rung01.py` probes, rows or tolerances.

Do not pass `--allow-mirror`. Exit code 0 is the pass. Godot stays `tools/godot/godot` (4.7-stable); put `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` before every Godot command and run scripts as `--script tests/<name>.gd` from `--path game`; the first run on a fresh checkout bakes `game/.godot` (`tools/godot/godot --headless --path game --import`). Build first (`make build`: OCCT 8.0.1 at `/opt/occt-8.0.1`, per `AGENTS.md`); WP2 changes C++, so Godot must run against the rebuilt `game/bin/libsxcore.so`. Do not commit `.gd.uid` files. Never pass `user://` / `res://` into GDExtension C++ (`ProjectSettings.globalize_path` first). The walk clicks real X11 widgets: also `export DISPLAY=:1`, and run it alone.

## BUILD agents (read before launching any)

- **Model:** grok-4.7, medium effort, standard speed (not fast).
- **starting_ref:** the full 40-character sha of `main` **at launch time**. WP7 starts only after its dependencies are merged (table below); if one is missing it stops and reports which.
- **Prompt:** one file per agent: `rung-01-replan-15-wpN.md`. The prompts are the implementation; this file holds the decisions, the order, the suite table and the checklist. Do not redesign what a prompt specifies; if a hypothesis is falsified by the reproduce gate, say so in the PR and follow the WP's "if the gate says otherwise" paragraph.
- **Merge gate (tell every BUILD agent, and the parent applies it):** a PR is mergeable when **the agent has FINISHED and the quick CI checks are green: linux kernel, godot-smoke, website-demos.** Never wait for `windows-export`; `macos-kernel` is skippable. A red quick check is a product failure: reopen the WP, do not merge. **A BUILD agent never merges its own PR** (the parent merges); it marks the PR ready for review and stops.
- **Branches / PRs:** one WP per PR, titles below. Repository `github.com/solidexpress/solidexpress` only (never the snadrus fork). Each PR body lists the leftover numbers fixed / skipped with the reason for every skip, and pastes the **reproduce-first run** (red or green) from the starting ref.
- **Reproduce first.** Each prompt says what the new suite is expected to show on baseline. The agent writes the suite, runs it on the starting ref **before** any product edit, and pastes the real output. Green on baseline = the suite stays as a regression net and the PR says so (decision 11).
- **Tests are real-input.** Each WP adds `game/tests/run_rung01_replan15_<x>.gd`. Setup (placing geometry, entering a sketch, adding sketch entities, arming a body) may use the sketch / document API and `tests/lib/film_ui.gd`; **every press, key, motion and wheel under test is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed through the viewport**. `FilmUI.click_control` is **not** a real click (it animates a pointer cue and then calls `button.pressed.emit()`): any click under test is `Viewport.push_input` of a motion + press + release (`_x11_click_screen`). No `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =` on a path under test. Layout assertions run at 1280×800. WP7 adds `_lint_replan15` to `tools/lint_rung01_e2e.py` (same needles as replan 14) and the Makefile loop; until it lands each agent greps its own suite for those needles.
- **Before opening a PR** run: the new suite, `python3 tools/lint_rung01_e2e.py`, `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` (0 failures, blank 5/5, nut 7/7, wrench 28/28, thick 7/7), every `run_rung01_replan14_*.gd` one at a time, and the suites each prompt names. `make test-godot` stops at its first failure; the pre-existing failures listed in `AGENTS.md` (`nav_preset` Alt-orbit rows in camera / place / howto, one DOF row in infer, one icon row) stay exactly as they are; do not flip `nav_preset`.

## Leftover → work package (all ten)

| # | Leftover | Sev | Verdict (read from `d534765c`) | WP |
|---|---|---|---|---|
| 9 | N2: Fillet disarmed / view keys lost after the strip or panel Radius Enter | **B** | **Not covered by #168.** Enter in either Radius field calls `try_commit_pending()`, which with no edge selected sets `_pending = NONE` and prints `No edges selected — cancelled`. The replan-14 suites mask it (`focuskeys` 3b re-arms when disarmed; the walk's `_b14_fillet_tab` re-arms with a comment saying so). #168 fixed arm → `3` and Tab → `4` | WP1 |
| 2 | Contours 1 / 2 toggles have no highlight | **B** | Real gap: `refresh_contours` builds plain `CheckButton`s; nothing draws a region. The kernel has `contour_faces` but no geometry API | WP2 |
| 1 | A9 → A9b → A11e → A12 / A13 chain | **B** | **#165 fixes the cause (A9).** No test builds the wrench with a **profile Line** cutter through trim → cut → slot → fillets → export; the walk uses a Centerline. Re-verify with a headless test; a geometry fix only if it goes red | WP3 (+ conditional WP3b) |
| 3 | Export 3MF name truncates | U | Hypothesis; the walk types the full path and is green. `EXPORT_3MF` in `_on_file_selected` never normalises the extension (Save As and the SVG / DXF / PDF exports do) | WP4 |
| 7 | Finish-bar Extrude click no-op | U | Reproduce first. **Found while planning: the walk never sends a real click to Extrude** (`_press_extrude` uses `FilmUI.click_control`, which animates a cue and calls `pressed.emit()`), so the 646 green checks say nothing about a real press on the focused button. Replan-10's `_x11_click` cut works, so soft-GL stays likely; stray-chip hypothesis shared with item 10 | WP5 (+ WP7 makes the walk press Extrude for real) |
| 10 | `jaw_af = 10 (config 10)` after Extrude | C | `_ctx_jaw_af` prints exactly that; reachable only by pressing the strip `AF 10` chip (hypothesis: a second click at the Extrude pixel lands on the chip the new selection strip shows) | WP5 |
| 8 | UUID in the chain-break status | U | `_chain_breaker_status` formats `"%s %s at (…) breaks the chain" % [breaker_type, breaker_id, …]` | WP6 |
| 5 | View key `0` is a no-op | U | `0` is not a nav key; nothing handles it | WP6 |
| 4 | `applied` vs `Feature created` | U | **Decision: `applied` stays** (replan-12 WP6 made it the lead on purpose); update the checklist and pin it in a headless test | WP6 |
| 6 | Jaw armed: label click starts a new Jaw | U | **Already fixed by #164** (`click` runs `dimension_hit(pos2, …)` before any tool). Pin with a real click right after a real Jaw commit | WP6 |

Blocks-pass items (9, 2, 1) are all in Wave A.

## Work packages

| WP | Prompt | What | Leftovers | Test | Depends on |
|---|---|---|---|---|---|
| WP1 | [`rung-01-replan-15-wp1.md`](rung-01-replan-15-wp1.md) | Enter in a Radius field commits the number and returns the keys but never disarms Fillet / Chamfer | 9 | `run_rung01_replan15_armedkeys.gd` | none |
| WP2 | [`rung-01-replan-15-wp2.md`](rung-01-replan-15-wp2.md) | Contours chips highlight their region in the viewport and name it in the status. **C++ binding** | 2 | `run_rung01_replan15_contours.gd` + a kernel case | none. **Only C++ WP** |
| WP3 | [`rung-01-replan-15-wp3.md`](rung-01-replan-15-wp3.md) | Wrench chain regression net: Line cutter → Trim → UTS cut → slot → fillets → export → checkers. Conditional geometry fix (WP3b) only on red | 1 | `run_rung01_replan15_chain.gd` | none (#165 is on `main`) |
| WP4 | [`rung-01-replan-15-wp4.md`](rung-01-replan-15-wp4.md) | Export 3MF keeps `.3mf` | 3 | `run_rung01_replan15_export.gd` | none |
| WP5 | [`rung-01-replan-15-wp5.md`](rung-01-replan-15-wp5.md) | A click on Extrude extrudes once; the success status is only `Extrude Blind …` | 7, 10 | `run_rung01_replan15_extrude.gd` | none |
| WP6 | [`rung-01-replan-15-wp6.md`](rung-01-replan-15-wp6.md) | Chain-break status without an id; key `0` status; the `applied` wording pinned; Jaw-armed label click pinned | 8, 5, 4, 6 | `run_rung01_replan15_strings.gd` | none |
| WP7 | [`rung-01-replan-15-wp7.md`](rung-01-replan-15-wp7.md) | Walk rows, `_lint_replan15`, Makefile loop, UUID guard in the walk's bad-status check, STATUS | all (walk / lint) | the walk, lint | **Everything merged:** WP1–WP6 (and WP3b if it was launched) |

### Waves

| Wave | WPs | Why |
|---|---|---|
| A | WP1, WP2, WP3 | **Blocks-pass** (items 9, 2, 1). Disjoint hunks; launch in parallel, immediately. WP3 is a test-only PR unless its gate goes red |
| B | WP4, WP5, WP6 | Usability and polish. Disjoint hunks; launch with Wave A (rebase if a Wave A WP lands first). No dependency between them |
| C | WP7 | The walk needs every product change |
| conditional | WP3b | Launched by the parent **only** if WP3's reproduce gate reports red on `main`; WP7 then waits for it too |

Merge order inside a wave is free; merge Wave A first (so sx-036 can start with the three blocks-pass fixes), WP7 last. Expected totals once everything is merged: `make test-godot` runs six more suites; `make test-kernel` = current count + the WP2 cases.

### File ownership (so parallel WPs do not conflict; search hunks by name, line numbers are `d534765c`)

| File | Owner and hunks |
|---|---|
| `ops_panel.gd` | **WP1**: the `radius_le.text_submitted` lambda in `_build_body_ops` (~237–241), new `commit_radius_field_enter()` next to `try_commit_pending` (~1961). No other WP |
| `viewport_interaction.gd` | **WP1**: the `strip_le.text_submitted` lambda in `_build_selection_strip` (~500–505) only. **WP5**: `_ctx_jaw_af` (~5442), new `_post_finish_chip_guard` state + new `_wire_post_finish_guard()` and **one call line** right after the existing `_wire_numeric_focus_release()` call in `_ready`. **WP6**: `_emit_view_key_status` (~329) only |
| `sketch_mode.gd` | **WP2**: new `_contour_node` / `_contour_fill_material` / tag labels created in `_ready` right after the `_selected_node` block (~228–234), new `set_contour_highlight`, `contour_label`, `_redraw_contour_highlight`, a one-line call in `_sync_contour_bar` (~1189) and in `_clear_meshes`. **WP6**: `_chain_breaker_status` (~3629) only. WP3b (if launched) names its own hunks |
| `sketch_context_chrome.gd` | **WP2**: `refresh_contours` (~1262) and the `else` branch of `show_for_session` (~1337–1341, the highlight clear) only. **WP5**: `_emit_finish_requested` (~626) only if the reproduce gate points there |
| `orbit_camera.gd` | **WP6**: `_is_nav_key` and `_handle_nav_key` (a `KEY_0` arm only) |
| `main.gd` | **WP4**: the `FileAction.EXPORT_3MF` arm of `_on_file_selected` (~3510), `_resolve_export_3mf_path` (~3045), new `_with_3mf_extension`. **WP5**: `_on_sketch_finish` status block (~1690) only if the gate points there |
| `sxcore/src/sx_sketch.hpp`, `sxcore/src/sx_sketch.cpp`, `sxkernel/include/sx/sketch.hpp`, `sxkernel/src/sketch.cpp`, `sxkernel/tests/test_features.cpp` (the contour kernel cases live there) | **WP2** only |
| `game/tests/run_rung01_wrench.gd` | **WP1**: the two hunks `_b14_focuskeys_fillet` (~4092) and `_b14_fillet_tab` (~4146) **only** (they encode the old disarm). **WP7**: everything else (new `B15.*` rows, the UUID guard in `_on_sketch_status` / `_take_bad_status`, an `applied` assertion in `_fillet_face`) |
| `game/tests/run_rung01_replan14_focuskeys.gd`, `run_rung01_replan13_radius.gd` | **WP1** only, and only the rows the reproduce gate shows depend on the old Enter-disarm (see WP1) |
| `tools/lint_rung01_e2e.py`, `Makefile`, `docs/plan/STATUS.md`, `docs/loop/linux-test-build.md` (no change expected) | **WP7** only |

PR titles:

- `Rung 1 replan 15 WP1: Enter in a Radius field keeps Fillet armed`
- `Rung 1 replan 15 WP2: Contours chips highlight their region`
- `Rung 1 replan 15 WP3: wrench chain regression net (Line cutter to export)`
- `Rung 1 replan 15 WP4: Export 3MF keeps the .3mf extension`
- `Rung 1 replan 15 WP5: Extrude click extrudes once and says only Extrude`
- `Rung 1 replan 15 WP6: chain-break status without ids; key 0; applied wording; Jaw-armed label click`
- `Rung 1 replan 15 WP7: walk rows, lint, Makefile, UUID guard`

## Decisions (nothing left open)

1. **Enter in a Radius field never disarms Fillet / Chamfer by itself.** In the strip `R` field and the Modify-panel Radius, Enter commits the typed number, returns the keys to the viewport, and **applies only when an edge, edge set or face is already selected** (then the existing `applied` path runs and disarms, as before). With nothing selected it stays armed and re-prints `Fillet r=10.00 — edit Radius, click edges, Enter` (`_emit_armed_dressup_status`). Tab, spinner arrows and an empty-canvas click already commit-and-stay-armed (#168) and keep doing so. The **viewport** Enter (`_gui_key` → `ops_panel.try_commit_pending()`) and the second press of the strip Fillet button are unchanged: with nothing selected they still say `No edges selected — cancelled`. WP1.
2. **Contour highlight.** Each region gets a stable colour from a four-colour palette by index. A region whose chip is **on** draws a translucent fill (alpha 0.28) plus an opaque outline; an **off** region draws a grey outline only. The region the pointer hovers on its chip (or whose chip has keyboard focus, or that was toggled last) draws a stronger fill (alpha 0.5) and a `Label3D` tag with its number at the region's centroid. Toggling a chip prints `Contour 2 of 2 — 41.0 × 10.0 mm at (93.5, 0.0) — included` / `… — skipped`. The words "jaw" and "slot" are **not** derived (the kernel does not know them); size and position are. The highlight exists only while the Contours bar is visible (two or more regions). Outlines come from a new `SxSketch.contour_outlines()` binding in the same order as `contour_faces()` (area descending, ties by centroid x then y), so chip `i` is region `i`. WP2.
3. **A9 chain: re-verify first, fix only on red.** #165 addresses the cause. WP3 adds the headless chain test with a **profile Line** cutter and asserts a closed shell and 28/28 / 7/7. The geometry-fix contingency (WP3b) is documented in the WP3 prompt and launched by the parent only if WP3 reports a red stage. WP3 itself never edits product code.
4. **Export 3MF keeps its extension.** After the path is resolved (typed name, path-field snapshot, or `FileDialog` result), `_with_3mf_extension(path)` makes it end in `.3mf`: unchanged if it already does (case-insensitive); an extension that is a strict prefix of `3mf` (`.3`, `.3m`, the observed truncation) is completed; any other name gets `.3mf` appended (the Save As rule). Status `Exported 3MF → <path>` always names the real path. WP4.
5. **A click on Extrude extrudes exactly once and nothing else answers it.** The part context bar's `AF 10 / 12 / 14` chips ignore a press for 600 ms after a sketch finish (`SketchMode.finished`), so a second click at the Extrude pixel cannot set `jaw_af`. The Extrude success status is `Extrude <End> <depth> mm` and is the last status printed. If the gate shows the click itself fails on a headless press, the WP fixes that instead and says which hypothesis was right. WP5.
6. **`applied` is the Fillet / Chamfer success wording** (`Fillet 6 edges 1.00 applied — View ▸ Timeline to edit parameters`, or `… — adjust parameters (Esc cancels, deselect keeps)` when the Timeline is open). `Feature created` stays for every other feature. The checklist A11d pass text changes; the walk asserts `applied` on the top-face, bottom-face and slot-floor fillets. WP6 + WP7.
7. **Key `0` prints `No view for key 0 — use 1 2 3 4 6 7 8`** in part mode and does nothing else. In a sketch the digit keeps typing into the dim blank (`sketch_orientation_locked` and `_sketch_keys_blocked` already gate it). Key `5` (projection) is unchanged. WP6.
8. **A label click opens its editor whatever tool is armed** (already true since #164). The Jaw commit status keeps `click a label to edit it`; WP6 pins the real click right after a real commit. WP6.
9. **No user-facing status contains an entity id.** `_chain_breaker_status` reads `Line at (187.5, 18.7) breaks the chain — delete or trim it` (kind capitalised, `Entity` when none). The walk's bad-status check fails on any status that matches `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-`. WP6 + WP7.
10. **Extrude success names the feature and depth only** (decision 5).
11. **Reproduce first, classify honestly.** A green reproduction test is not a failure of the WP: it is the evidence that the leftover is soft-GL or already fixed (items 3, 6, 7 and the Enter-less half of 9 are the likely candidates), and the PR says so. The regression test is kept either way.
12. **Lint without a hard count.** `_lint_replan15` globs `run_rung01_replan15_*.gd`, applies the replan-13 camera needles (with `_zoom_model` allowed), prints `<N> replan15 scripts are clean`, asserts `N ≥ 1`. WP7.
13. **Out of scope per WP.** Each prompt has a "Do not" list; none changes a replan 10–14 status string except where a decision above says so (decisions 1, 4, 5, 7, 9), and none touches what the spin-outs table lists.
14. **Walk.** `run_rung01_wrench.gd` gains the `B15.*` rows in WP7 (real input only).

## Failing-first tests (red = on the starting ref, **hypotheses until a BUILD agent runs them**)

| Test | Expected red on `d534765c` | Expected green |
|---|---|---|
| `run_rung01_replan15_armedkeys.gd` | after the strip / panel Radius Enter with nothing selected: `_pending == NONE`, status `No edges selected — cancelled`, so key `3` changes the view but Fillet is gone; a re-arm click then cancels again. The Tab / arrow / arm rows are green (the regression net for #168) | all; Enter with an edge selected still applies and prints `applied` |
| `run_rung01_replan15_contours.gd` | `sketch.has_method("contour_outlines")` false, `_contour_node` absent, no status on a chip toggle. (Kernel case: `contour_outlines` does not compile) | all |
| `run_rung01_replan15_chain.gd` | **expected green** (the net). Red at a stage = the stage name, the status log and the checker table in the PR, and the parent launches WP3b | all stages; blank 5/5, wrench 28/28, thick 7/7; closed shell at every stage |
| `run_rung01_replan15_export.gd` | typed `wrench.3` (truncated) or a bare `wrench` writes a file without `.3mf`; the typed `wrench.3mf` row may already be green (then item 3 is soft-GL + the normaliser) | all |
| `run_rung01_replan15_extrude.gd` | a second click at the Extrude pixel after the extrude prints `jaw_af = 10 (config 10)` and sets the variable (if a chip sits under the pixel); the single-click rows may already be green (then item 7 is soft-GL) | all |
| `run_rung01_replan15_strings.gd` | chain-break status contains a UUID; key `0` prints nothing; the `applied` and Jaw-armed rows are green (nets) | all |
| `run_rung01_wrench.gd` (WP7) | new `B15.*` rows red until the product WPs are merged | 0 failures |

## Whole-suite check (every WP, and WP7 last)

Baseline is whatever the starting ref prints; record it in the PR before editing. Known from STATUS at `d534765c`: walk **646 checks / 0 failures**, nut 7/7, wrench 28/28, thick 7/7, blank 5/5; lint `7`+ replan14 scripts clean (the count grew with #165: eight `replan14` suites on `main`). Run every `game/tests/run_*.gd` one at a time with `timeout 120`, nothing else running.

Deltas this plan requires (everything else identical before and after):

| Suite | Change |
|---|---|
| `run_rung01_replan15_{armedkeys,contours,chain,export,extrude,strings}` | 6 new files, 0 failures each (counts recorded by the BUILD agents) |
| `run_parse_sweep_tests` | parses every `game/tests/*.gd`: +6 files |
| `run_rung01_wrench` | 646 → 646 + WP7 rows (plan target ≥ 690) / 0 |
| `run_rung01_replan14_focuskeys`, `run_rung01_replan13_radius` | WP1 changes only the rows that encode the old Enter-disarm |
| `make test-kernel` | + the WP2 contour-outline cases; everything else unchanged |
| `python3 tools/lint_rung01_e2e.py` | adds `<N> replan15 scripts are clean` |

## sx-036 GUI checklist (delta on the sx-035 checklist)

Take the sx-035 checklist ([`rung-01-replan-14.md`](rung-01-replan-14.md) "sx-035 GUI checklist", on top of [`rung-01-replan-13.md`](rung-01-replan-13.md)'s sx-034 rows, with rules 1–40) and apply this delta. Keep every row id. New rows are **N10–N14**; the failed and knock-on rows come back as **re-verify** rows with their own pass text.

**GUI testers download the Linux build** from the rolling `linux-test-build` prerelease ([`linux-test-build.md`](linux-test-build.md)) built from a `main` that contains WP1–WP7 (read `BUILDINFO.txt`; do not test an older sha). Do not use a box-local export.

**sx-036 walk is the full handout once** (the geometry rows need it) plus the lean re-verify rows. Order (the order they happen on the handout): A2 / **N7**, A3, A4, A5 (**N12**), A5b, L8, A7, A6, **N4**, A8 (re-verify, item 6), A8b, **N8a**, A9 (re-verify, #165, **a plain Line cutter**), **N1a**, **N5**, A9c, **N1b**, A9b (re-verify), **N10**, **N6**, A11a (re-verify, #163), A11b + **N2** (re-verify, item 9), L3 (re-verify, #168), A11c (re-verify, #166), **N3**, A11d (changed text), A11e (re-verify), **N13**, A12 (**N11**), A13 / A13b, A13c / **N9**, **N8b**, **N14**, **A15**. A10 / A14 / L7 / L9 stay headless / CI.

### Re-verify rows

| Row | Fix | Action | Pass looks like |
|---|---|---|---|
| A8 | #164 (item 6) | Jaw: click 1, 2, 3 commit; **with Jaw still armed** click the first glyph of the width label (`20`); then of `45°` | `Jaw committed — width 20.0000 …`; the click opens the dimension editor, not `Jaw — centre set…`; entity count unchanged; Esc closes the editor |
| A9 | #165 | After `F`, click the pivot centre; draw a **plain Line** across the head (not Centerline); Power Trim; drag across the jaw outside the Line | `Trimmed open jaw`; the Line is gone; `Jaw is already open — nothing left to trim here` on a second drag; no pan |
| A9b | #165 chain | Cut, Up To Surface, opposite face | `Extrude Up To Surface 10.0000 mm`; no `breaks the chain`; no open-shell refusal; closed jaw cut |
| A11a | #163 | Slot: type radius 5 Enter, first centre, type 150 Enter | `Slot c-c 150.0000 R5.0000 — typed`; Extrude Distance still 20 until the Blind 2.5 is set; cut `Extrude Blind 2.5000 mm` |
| A11b / N2 | #168 + item 9 | Fillet armed (key `3`). (a) strip `R` ▲ then ▼ then `3`; (b) type `10` **Enter** then `3` then `4`; (c) panel Radius type `10` **Enter** then `3`; (d) Tab on each | After every commit the next key prints `Top view` / `Back view`; **Fillet is still armed** (strip `R` visible, status `Fillet r=10.00 — edit Radius, click edges, Enter`); the field reads `10 mm`; no extra digit. Clicking the neck corners then Enter applies |
| L3 | #168 | strip type 10 Tab; panel type 10 Tab | strip `R`, panel Radius and status show the same number; Tab lands in the viewport (not `AF 10`) |
| A11c | #166 | re-click a picked edge | the edge is removed (`— removed … mm`), no duplicate |
| A11d | item 4 | Top face, then bottom face, R1 | `Fillet <n> edges 1.00 applied — …` (**not** `Feature created`); never `No edges selected` |
| A11e | item 1 | Fillet armed, key `3`, **one click on the slot floor** (inside the slot outline, away from the rim); then R1.5 on the same floor | the click selects the slot floor loop (status `Fillet: <n> edge(s) — … — click more, Enter to apply, Esc cancel` listing the floor's ≈150 mm lines and ≈15.7 mm arcs, not the neck loop `175.4 line, 42.2 line`); Enter → `Fillet … applied`; R1.5 refuses with the floor-depth limit (`1.25`) |
| A12 | #165 chain | File → Export 3MF, type `wrench.3mf` | status `Exported 3MF → …/wrench.3mf`; `check_rung01.py wrench` **28/28** (a `22` total means the slot is missing) |
| A13c / N9 | replan-14 | Distance 10 → 14, export `wrench-t14.3mf`; `thick … 14` and DIAG | thick **7/7**; DIAG prints `DIAG:` and exactly the four by-design failures |

### New rows

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| N10 | WP2 | In a sketch with two closed regions (the Slot beside the jaw, or Polygon + Circle apart) the `Contours` chips appear. Hover chip `2`; click chip `1` off, then on | Hover: that region fills (translucent) with a `2` tag on it; the other region is outline only. Click: `Contour 1 of 2 — W × H mm at (x, y) — skipped` / `— included`; the off region loses its fill. An Extrude with the wrong contour still refuses honestly |
| N11 | WP4 | File → Export 3MF; select all in the name field; type `wrench.3mf`; OK | file `…/wrench.3mf` exists; status names it. Typing `wrench` (no extension) also ends in `.3mf` |
| N12 | WP5 | A5: type `10` in Distance, **click** Extrude once with the mouse | `Extrude Blind 10.0000 mm` (and only that); one body; no `jaw_af` text. A second click at the same pixel does nothing |
| N13 | WP6 | Part mode, no field focused: press `0`, then `3` | `No view for key 0 — use 1 2 3 4 6 7 8`; the camera did not move; `3` → `Top view` |
| N14 | WP6 | Leave one open vertex in a cut profile and press Extrude | the refusal reads `Line at (x, y) breaks the chain — delete or trim it`; **no UUID anywhere** in the status |

Changed text on carried rows: **A11d** — `applied`, not `Feature created` (item 4). **A9** — the cutter is a plain Line (the walker's own choice in sx-035) and Centerline both work. **A11b** — Enter on the Radius field no longer ends the pick.

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 7/7, walk 0 failures, every A / L / N row passed or classified soft-GL **with evidence**, first-try fillets from the views the app offers, a real Slot.

## Soft-GL protocol additions (sx-036 walker)

Rules 1–40 stay (replan 10–14). New:

41. **One click, then read.** After pressing Extrude with the mouse wait two frames and read the status line before pressing anything else. A second press at the same pixel after the sketch closed hits whatever the new selection bar shows there. If the first click did nothing after one retry on a fresh frame it is a product failure; a screenshot that still shows the sketch is rule 8 (lag), not a no-op.
42. **Name the slot by its content.** Contour chips are numbered by region size (largest first). Read the status line (`Contour N of M — W × H mm at (x, y)`) and the tag drawn on the region; do not infer the region from the chip number.
43. **A typed export name is read back.** For N11 read the status path; if the file name differs from what was typed and the status matches the file on disk it is a product failure (rule 1 covers keys that never arrived: the name field then shows the missing letters before OK).
44. **Enter in a Radius field is not "apply".** Apply needs edges selected. If Fillet disarmed after Enter with no edges selected, N2 fails; the status `No edges selected — cancelled` after a *viewport* Enter with nothing selected is correct.

## Out of scope

- Soft-GL / llvmpipe / Mesa / Godot renderer; switching Godot off 4.7-stable; screenshot lag; dropped keys.
- The checker probe-count "tooling" item (22 vs 28 is the missing-slot signal, see "Reading the wrench total"); checker formulas or tolerances; `thick` and every wrench probe stay.
- Nut / A10 / L7 / L9 (headless / CI); the spin-outs table above; `docs/plan/*` features other than the STATUS entry; the snadrus fork; PR #11.
- Naming regions "jaw" / "slot" in the Contours status; a document-level undo for sketches; changing `nav_preset`.
- Test-only cameras, `_look_along`, `set_view(`, writing `camera.yaw` / `camera.pitch`, `select_entity` or script-side selection on a path under test in the walk or the replan15 suites.
