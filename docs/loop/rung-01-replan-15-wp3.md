# Replan 15 WP3 — wrench chain regression net: profile Line cutter → Trim → Up To Surface cut → slot → fillets → export → checkers (leftover 1)

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` at launch time). This WP is **test-only**: you add one suite and edit nothing under `game/scripts/`, `sxcore/`, `sxkernel/` or `tools/`. Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 3, 11, 13) and [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md) (item 1) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

| File | Hunk |
|---|---|
| `game/tests/run_rung01_replan15_chain.gd` | new (the only file this WP adds or changes) |

Everything you need from `run_rung01_wrench.gd` (helpers for fillet picks and the export dialog) is **copied** into the new suite, not imported and not edited there (WP1 owns two hunks of that file, WP7 owns the rest).

## Why this WP exists (sx-035 leftover 1)

sx-035's verdict: geometry went red because **A9 Power Trim did not open the jaw** (the walker's cutter was a plain profile **Line**, not a Centerline). Everything after it was a knock-on:

- A9b: Cut → Opposite face refused; status `Line 77d1a0c0-… breaks the chain` (item 8, WP6).
- A11e: the first slot-floor Fillet click selected the neck corner loop (`175.4 line, 42.2 line`), not the slot floor.
- A12: the exported 3MF had no slot: the checker printed **22** rows (the missing-slot signal, see "Reading the wrench total" in the plan) and failed the geometry rows.
- A13c: the T = 14 DIAG header was absent.

[#165](https://github.com/solidexpress/solidexpress/pull/165) (`81a6910`) fixes the cause (`_trim_open_jaw`, `_jaw_cutter_for_click`, `_cutter_crosses_both_sides`). `run_rung01_replan14_trim.gd` proves the **trim** for a profile Line. **Nothing builds the rest of the wrench from a profile-Line jaw**: `run_rung01_wrench.gd` uses a **Centerline** (`_draw_centreline`), and `run_rung01_replan10_cut.gd` uses a Centerline / hand-added rectangle. This WP closes that gap: if the whole chain is green on `main`, items A9b / A11e / A12 / A13 are knock-ons already fixed by #165 and the PR says so; if a stage is red it is a real second defect and the parent launches **WP3b** (below).

## The suite (`run_rung01_replan15_chain.gd`)

Template and helpers: `run_rung01_replan14_trim.gd` (`_boot`, `_open_line_cutter_scene`, `_add_profile_cutter`, `_drag_between`, `_x11_click_screen`, `_zoom_model`), `run_rung01_replan10_cut.gd` (`_face_at`, `_extrude_count`, Opposite face via `chrome.opposite_face_button()`, `doc.export_3mf_for_body`), and `run_rung01_wrench.gd` (`_arm_fillet`, `_view_key`, `_click_model`, `_commit_fillet`, `_fillet_face`, `_refuse_slot_floor`, `_export_via_dialog`, `_type_export_name`, `_checker`: copy the ones you need verbatim). Boot at 1280×800.

**Setup (API allowed, not under test):** the blank. In a ground sketch add circle `(0,0) r10`, circle `(200,0) r22.5`, the two shaft lines at `y = ±10` ending on the Ø45 (as the replan10 test's `tangent_x` lines), `sm.finish_extrude(10.0, "new", "blind")` (the replan10 setup). One body, bbox `232.5 × 45 × 10` (±0.2).

**Under test (real events through the viewport / real X11 clicks; no script shortcut):**

| Stage | What | Assertions (each is a `check`; name the stage in the message) |
|---|---|---|
| S1 jaw sketch | `ctx.main._start_sketch_on_face(top, body)` (setup); circle Ø45 at the head and the Ø10 pivot added by API; the Jaw tool (`sm.start_jaw_tool()` + three `sm.click`, snap off, then `set_dimension_value` 20 and 45, the `_open_line_cutter_scene` recipe); a **plain Line** cutter across the head (`_add_profile_cutter(sm, "perp")`, `is_construction == false`) | cutter is not construction; `sm.sketch.contour_count()` ≥ 1 |
| S2 trim | `FilmUI.select_sketch_tool(TRIM)`; **a real drag** across the jaw outside the Line (`_drag_between`) | status log has `Trimmed open jaw`; `SketchMode.profile_is_closed(sm.sketch)`; the cutter Line is gone; no pan (`sm` plane origin and camera target unchanged within 0.5 mm) |
| S2b trim twice | a second drag | log has `Jaw is already open` |
| S3 cut | Finish bar: Op = Cut, End = Up To Surface, **a real click on `chrome.opposite_face_button()`** with the bottom face, then **a real click on the Extrude button** | `chrome.up_to_face_id == bottom`; Extrude enabled; status has `Extrude Up To Surface 10.0000 mm`; **no** status contains `breaks the chain`, `open profile`, `Open-profile cut needs a line chain`, `left an open shell`; one more extrude feature; `doc.export_3mf_for_body(body, tmp)` is `true` (closed shell) |
| S3b geometry | mesh from the body | `_inside` tests: jaw interior open at the head `(HEAD + JAW_DIR·15, z=5)`; wall solid at `(HEAD − JAW_DIR·30, z=5)` (same probes as the walk's `_assert_jaw` / `_assert_pivot`: copy them) |
| S4 slot | `_start_sketch_on_face(top, body)`; Slot tool; `sm.slot_radius` typed through the dim blank (a real `5` key through the viewport, as `B13.1`) ; first centre click `(18.5, 0)`; second centre typed `150` Enter or clicked at `(168.5, 0)`; Finish bar Op = Cut, End = Blind, Distance `2.5` typed into the Distance field with real keys, **real Extrude click** | status `Extrude Blind 2.5000 mm`; no bad status; slot open at `(93.5, 0, 8.75)`, pocket floor solid at `(93.5, 0, 6.5)`; closed-shell export true |
| S5 fillets | the walk's order via the real Fillet strip: neck R10 (`_fillet_neck`), top face R1 (`(200,-16,10)`), bottom face R1 (`(50,0,0)`, view key `8`), **slot floor R1 (`(93.5,0,7.5)`)**, then slot floor **R1.5 refused** | each of the four fillets adds one `fillet` feature and `doc.last_graph_error() == ""`; every success status contains `applied`; after the slot-floor R1 the body has strictly more triangles than before; **the slot-floor click selected the floor loop**: `ctx.view.selected_edges` of the slot-floor pick contains ≥ 2 lines each with length within 1 mm of 150 (floor straight edges) and none of length 175.4 or 42.2 (the neck loop of sx-035); R1.5 leaves the feature count and body volume unchanged (±1e-3) and `last_graph_error()` contains `1.25`; closed-shell export true after every fillet |
| S6 export | `_export_via_dialog(ctx, "wrench.3mf")` (real menu click, name typed per key, real OK click) | file exists; status starts `Exported 3MF → ` and names the path |
| S7 thick | Timeline: base extrude 10 → 14 (the walk's `_show_timeline`, `_boss_extrude_id`, `_type_timeline_distance`, `_timeline_panel_dismiss`), `_export_via_dialog(ctx, "wrench-t14.3mf")` | file exists; `doc.graph_warnings()` does not contain `lost on rebuild` |
| S8 checkers | `OS.execute("python3", [tools/check_rung01.py, "wrench", path])`, `thick … 14` | `wrench` exit 0 **and** the output contains `28/28` **and not `22/22`**; `thick` exit 0 and `7/7`; print the whole table into the run log |
| S9 print | at the end print `CHAIN-SUMMARY stages=<n> first_red=<stage or none>` so the parent can read the first red stage from the PR log | |

Everything in S2–S7 is real input except the setup lines named above. Do not use `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =` on those paths. If a stage fails, record it and **keep going to the next stage that does not depend on it** (a failed S3 skips S4–S8 with a `check(false, "skipped: S3 red")` per skipped stage, so the first red stage is obvious). Counts are what the run prints.

Time budget: the suite runs one GUI session; allow ≤ 300 s (`timeout 360`). It needs a display like the walk: `export DISPLAY=:1`, run it alone.

## Reproduce-first gate

Write the suite and run it on the starting ref (there is no product edit to do first). Paste the full output, including the checker tables and the `CHAIN-SUMMARY` line.

- **Expected: all stages green** (hypothesis: #165 fixed the cause; the Line cutter + the rest of the chain were never red once the jaw opens). Then the PR states: *leftover 1 (A9 → A9b → A11e → A12 / A13) is fixed by #165; this suite is the regression net.* No WP3b.
- **A red stage** is not a failure of this WP: it is the finding. The PR lists, in this shape, and the parent launches WP3b with it:
  1. the first red stage id (S1–S8) and the exact `check` message;
  2. the `_status_log` of that stage;
  3. the sketch snapshot (`sm.sketch.snapshot()`) at the start of S3 / S4 (the entity count and which have `construction`);
  4. for S5: `ctx.view.selected_edges` with lengths (`doc.get_edge_lines(body)` for those ids) and the status line after the click;
  5. for S8: the full checker table; a `22` total (not 28) means S4 or S5 lost the slot.

## WP3b (conditional; the parent launches it **only** if S1–S8 above reports red; same starting-ref rule, same merge gate, WP3's suite is its test)

A separate PR titled `Rung 1 replan 15 WP3b: <stage> after a profile-Line jaw`. Each hypothesis below is **read from code on `d534765c` and unverified**; take the one the gate's evidence selects, say which in the PR, and change only the named hunk.

| Red stage | Hypothesis | Where (search by name) |
|---|---|---|
| S2 trim | #165's `_jaw_cutter_for_click` / `_cutter_crosses_both_sides` rejects the Line when the drag starts on the far side, or `_jaw_long_sides` mis-chooses the sides after the Jaw dims are edited to 20 / 45. Compare with `run_rung01_replan14_trim.gd` cases that are green | `sketch_mode.gd` `_trim_open_jaw`, `_jaw_cutter_for_click`, `_jaw_long_sides`, `_cutter_crosses_both_sides`, `_jaw_no_cap_status` (owned by #165; touch only the failing predicate) |
| S3 cut refuses with `breaks the chain` / `open profile` | the trim leaves a sub-tolerance gap or a stray arc end at the shaft (`_trim_open_jaw` rebuilds the arc / joins; the chain tolerance is `1e-6` while the joins are `1e-4`), so `profile_is_closed` says closed but `profile_face` does not chain. Fix: join the ends exactly in `_trim_open_jaw` (reuse `_try_close_open_chain(tol, force)` or the equivalent endpoint-coincidence step already in `_trim_open_jaw`), never by loosening the kernel tolerance | `sketch_mode.gd` `_trim_open_jaw`; `sxkernel/src/sketch.cpp` `Sketch::profile_face` only if the gap is in the kernel's chain tolerance (then a kernel test beside `"contour_faces keeps nested wire as a hole"`) |
| S3 `left an open shell` | the Up To Surface cut from the profile Line sketch reaches the bottom face at a different `to_face` than the Centerline path (face id resolved before the sketch regenerates). Compare `FeatureGraph` extrude `to_face` and the `Extrude::up_to_face` resolution with the green `run_rung01_replan10_cut.gd` handout case | `sxkernel/src/features.cpp` the Extrude regenerate branch that handles `end == "to_face"` (`to_face_back`, ~1066–1139) |
| S4 / S5 slot floor selects the neck loop | after a profile-Line jaw the body has an extra seam / edge id order, and the face-first pick maps the click to the wrong face (the sx-035 symptom). Capture `selected_edges` and the face id under the click and compare with the face the pick should hit (the slot floor at `z = 7.5`) | `ops_panel.gd` `_dressup_pick_status`, `_accumulate_dressup_edge`, `_toggle_dressup_edge` and `document_view.gd` (owned by #166; touch only the branch the evidence names) |
| S5 R1 fillet refused | the slot pocket edge ids moved after the jaw cut (`lost on rebuild`) | kernel `FeatureGraph` fillet edge remap |
| S8 `22` | the slot is not in the exported mesh: bisect by exporting after S4 (`export_3mf_for_body`) | whichever stage lost it |

WP3b's PR must add its failing case to `run_rung01_replan15_chain.gd` (or a new `_chain_<stage>.gd`) **before** the fix, paste red → green, and rerun the whole suite plus `run_rung01_wrench.gd`.

## Do not

- Do not edit `run_rung01_wrench.gd`, `run_rung01_replan14_trim.gd`, `run_rung01_replan10_cut.gd`, `tools/check_rung01.py` (probes, rows, tolerances, `--allow-mirror`), or any file under `game/scripts/`, `sxcore/`, `sxkernel/` in WP3.
- Do not substitute a Centerline for the Line cutter (that is what the walk already covers).
- Do not turn a red stage green by changing an assertion; report it.
- Do not use `--allow-mirror`.

## Run before the PR

The new suite (paste: stage table, checker output, `CHAIN-SUMMARY`); `python3 tools/lint_rung01_e2e.py` (the new file is picked up by WP7's lint later; grep the needles yourself now); `run_rung01_replan14_trim.gd`; `run_rung01_replan10_cut.gd`; `run_parse_sweep_tests.gd`. PR title: `Rung 1 replan 15 WP3: wrench chain regression net (Line cutter to export)`. PR body: leftover 1 verdict (already fixed by #165 / red at stage X), the pasted run, and the exact stage list.
