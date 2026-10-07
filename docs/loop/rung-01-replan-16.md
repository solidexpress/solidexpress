# Rung 1 replan 16 — leftovers after sx-036: pad clicks that open sketches, numeric field edges, sketch visuals, chrome/status/camera, a GUI-order replay, and parallel-safe suite registration

Status: planned

Baseline: `main` at `463ffe5b21f5604a0ed677338de257c7d2172b16` (sx-036 spin-outs #180–#188 all merged). Launch every BUILD agent from the **full 40-character sha of `main` at launch time**. sx-036 (build of `12582d27`, Linux 1280×800, soft GL) scored **FAIL 7/10**: 41 PASS / 11 FAIL / 4 PARTIAL / 1 BLOCKED of 57 rows. Prior plan: [`rung-01-replan-15.md`](rung-01-replan-15.md). Next walk checklist: [`rung-01-replan-16-checklist.md`](rung-01-replan-16-checklist.md) (sx-037).

The eight sx-036 spin-outs fixed the geometry (head 31.3 wide, face fillets refused, open 3MF, thick 5/7), the Esc ladder, the label click, the rail, the shaft badges, the numeric-field garble and N12. What is left is **a click that opens a sketch**, **three numeric fields that still drop the first key**, a **tail of sketch/chrome defects**, a **headless-green / GUI-red gap**, and a **process defect** (every parallel PR conflicts on the suite lists). This plan removes them so **sx-037 passes every row with score ≥ 9**.

**How this plan was measured.** The planning VM has no OCCT 8.0.1, no `libsxcore.so` and no Godot run. Nothing here was executed. Every cause is read from `main` at `463ffe5` and is a *hypothesis* until the BUILD agent's reproduce-first run (below) says otherwise; the PR records the real red/green counts.

## Pass bar (rung 1)

Score ≥ 9. Checkers (`python3 tools/check_rung01.py …`, never `--allow-mirror`, never edit probes): **nut 7/7, blank 5/5, wrench 28/28 (a `22` total = slot missing = FAIL), thick 7/7** (`thick wrench-t14.3mf 14`). Headless walk `run_rung01_wrench.gd` **0 failures** (729 checks on `12582d27`; only grows). Every A / L / N checklist row PASS (or soft-GL **with evidence**). Fillets succeed first try from the views the app offers. A real Slot (`Extrude Blind 2.5000 mm`).

## Already merged — verify only, do not re-plan or re-edit

| PR | Row(s) | What it fixed (functions) | Suite on main |
|---|---|---|---|
| #180 | sketch_tools | across-flats + kernel dimension labels in the suite | `run_sketch_tools_tests.gd` |
| #181 | N12 | `viewport_interaction.gd`: finish click shield (`_arm_finish_click_shield`, `_release_finish_click_shield_on_motion`), `_layout_selection_strip` keeps the AF chips off the Extrude pixel, `_ctx_jaw_af` 600 ms guard | `run_rung01_n12_extrude.gd` |
| #182 | A3, L5, A8 editor, N4 AF, L-11 | `ui_spin.gd` `arm_replace_on_focus` / `write_typed_text` / `replace_armed`; `sketch_context_chrome.gd` `arm_dim_replace`, `replace_dim_with_char`; `sketch_mode.gd` `circle_radius` (apart from `slot_radius`), `_apply_sketch_frame`, `_contour_geom_sig` (stale disc); `orbit_camera.gd` `frame_sketch_rect`; viewport dim-editor key router | `run_rung01_sx036_fields.gd` |
| #183 | L6 | `sketch_mode.gd` `_pin_shaft_line_pair`, `_restore_flipped_shaft_lines`; `solver_planegcs.cpp` | `run_rung01_replan15_shaftbadges.gd` |
| #184 | A8b, A6, N1b, Save As undo | `viewport_interaction.gd` Esc rung (`esc_keep_sketch` → `exit_sketch()` when committed geometry, else `cancel()`), `_chrome_face_pick_explicit`, `_sketch_draw_tool_beats_face_pick`, `_clear_select_click_measure`; `main.gd` part-mode `Ctrl+Shift+Z` / `Ctrl+Y` redo, Save keeps sketch undo; `measure_overlay.gd` | `run_rung01_sx036_esc.gd` |
| #185 | A1 | `main.gd` `_build_ui`, `_update_left_rail`, `_left_stack_top` (19 rail labels fit 1280×800) | `run_rung01_sx036_rail.gd` |
| #186 | A8, L4, N1a placement | `sketch_mode.gd` `_dimension_label_offset_px`, `_dimension_label_world`, `JAW_LABEL_MAX_STACK`, `_is_jaw_callout`, `_separate_capped_jaw_labels`, `_clamp_dimension_labels_into_view`, `callout` tag in `_record_dimension` | `run_rung01_jaw_label_hit.gd` |
| #187 | A13, A13c, N9 | `features.cpp` / `ops_dress.cpp`: fillet cues re-resolve on distance edit; slot follows the top | `run_rung01_replan15_thick.gd` (thick 7/7) |
| #188 | A9b bbox, A11d, A12 | `sketch_mode.gd` `_trim_open_jaw`, `_weld_jaw_profile`; `sketch.cpp` `add_arc` / `contour_faces_impl` (outer-stub trim cut the complementary arc) | `run_rung01_replan15_jawstub.gd` |

**Rule for every WP:** read these functions on `main`; edit one only where the WP names the hunk. A WP never changes a status string above.

## BUILD agents (read before launching any)

- **Model:** grok-4.7, medium effort, standard speed. **starting_ref:** full 40-char sha of `main` at launch. WP1 runs alone and merges first; WP2–WP5 launch from WP1's merge in parallel; WP6 launches after WP2–WP5 merge. A WP that finds its dependency missing stops and reports it.
- **Merge gate (parent applies; tell every agent):** mergeable when the agent has FINISHED and quick CI is green: **linux kernel, godot-smoke, website-demos**. Never wait for `windows-export`; `macos-kernel` is skippable. **A BUILD agent never merges its own PR**: it marks it ready for review and stops.
- **One PR per WP**, repository `github.com/solidexpress/solidexpress` only. PR body: leftover numbers fixed / skipped with the reason, plus the **reproduce-first run** (red or green) pasted from the starting ref.
- **Reproduce first.** Write the suite, run it on the starting ref **before** any product edit, paste the real output. Green on baseline = the suite stays as a regression net and the PR says the leftover was already fixed or is soft-GL.
- **Tests are real-input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`; **every press, key, motion and wheel under test is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed through the viewport** (`Viewport.push_input`; `FilmUI.click_control` is not a real click). No `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =` on a path under test. Boot at 1280×800 (`FilmUI.ensure_test_viewport`). Templates: `run_rung01_sx036_esc.gd`, `run_rung01_sx036_fields.gd`, `run_rung01_jaw_label_hit.gd` (`_boot`, `_x11_click`, `_click_uv`, `_zoom`).
- **Registering a suite (after WP1):** add **one new file** `packaging/ci/suites.d/<name>.suite` (see WP1). **Never edit `packaging/ci/run_godot_suites.sh`, the Makefile `test-godot` recipe or `tools/lint_rung01_e2e.py`** in a WP other than WP1. New `run_rung01_replan16_*.gd` suites are linted automatically (WP1).
- **Before opening a PR:** the new suite; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` (0 failures); every suite in the WP's "also run" list, one at a time (`make test-godot` stops at its first failure; the pre-existing failures in `AGENTS.md` — `nav_preset` Alt-orbit rows, one infer DOF row, one icon row — stay exactly as they are). Env: `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib`, `DISPLAY=:1` for X11 suites, run them alone. Never pass `user://` / `res://` into GDExtension C++. Do not commit `.gd.uid` files.
- **Parallel-safe edits.** WP2–WP5 touch a few shared files in **different functions**. Edit only the functions named; no reformatting, no moved code, no new top-of-file consts outside the WP's own block.

| File | WP2 | WP3 | WP4 | WP5 |
|---|---|---|---|---|
| `viewport_interaction.gd` | `_click_hits_pad` | `_build_selection_strip` strip block | — | hover-hint emits (~`update_hover` tail), new `hover_hint` signal |
| `main.gd` | `_on_sketch_pad_clicked` | `_save_current` | — | `_on_status`, `_unhandled_input` Esc, `_open_document`, `_apply_chrome_docks`, `_compact_sketch_rail_button` / rail armed style |
| `ops_panel.gd` | `_accumulate_dressup_edge` | `_build_body_ops` Radius block | — | — |
| `sketch_mode.gd` | `begin_edit`, `exit_sketch` | — | everything else (labels, glyphs, polygon, trim, slot) | — |
| `sketch_context_chrome.gd` | — | all | — | — |
| `sketch_pad_overlay.gd` | `pick_pad_visible` | — | — | — |
| `orbit_camera.gd` | — | — | — | `enter_sketch_view` |
| `ui_spin.gd` | — | all | — | — |

## Triage of the 25 leftovers (verified against `main` `463ffe5`)

Verdicts: **FIXED-BY #nnn**; **OPEN** (a WP fixes it); **RE-VERIFY** (no defect found in code, a walk row or test covers it); **DESIGN** (behaviour is intended, the checklist text changes); **SOFT-GL** (environment, classify on hardware GL).

| # | Leftover | Verdict | Evidence / root-cause hypothesis | WP |
|---|---|---|---|---|
| 1 | Click on a face / Fillet chip enters sketch edit (`Editing sketch`) | **OPEN, blocks-pass** | `viewport_interaction.gd` `_click_hits_pad()` runs for every plain click when no fillet pick is armed (after Esc → `Edge pick cancelled` nothing is armed) and emits `sketch_pad_clicked`; `main.gd` `_on_sketch_pad_clicked` → `sketch_mode.begin_edit()` → `Editing sketch`. `sketch_pad_overlay.gd` `pick_pad_visible()` applies its ink-distance test **only when the ray hits the solid at the pad plane** (`t >= solid_t − PAD_FACE_EPS_MM`); a ray that crosses the pad plane **above** a deeper solid (slot floor 2.5 mm below the z=10 plane) or **misses the solid** (chip click that fell through the reflowed bar) is accepted anywhere inside the pad's bounding box. Pads exist for every sketch with entities, consumed or not (`refresh`) | WP2 |
| 2 | L7: `Discard unsaved changes?` after Save + refused fillet + Esc | **RE-VERIFY + guard** | Cause is #1: the accidental `Editing sketch` → `Exit Sketch` ran `exit_sketch()` → `graph_update_sketch()` → revision bump → `_document_is_dirty()`. A refused fillet is already clean (`run_rung01_replan13_dirty.gd`). Guard: an unchanged re-entered sketch must not bump the revision | WP2 (guard), WP6 (replay) |
| 3 | N1a: `22.5` label missing on first pass | **RE-VERIFY (not a defect)** | `22.5` (head radius) and `5` (pivot, only for a circle within 1 mm of the origin) are recorded **by `_trim_open_jaw`** (`_record_dimension("radius", [arc_id], …)`, `_record_dimension("radius", [id], hole_r, …)`). The walker's first A9 trim failed (cutter misplaced), so no `22.5` existed; it appeared after the retry. Placement/overlap at ~150 px is covered by #186 for 20 / 45° only | WP4 (test), checklist |
| 4 | Face clicks pick edges at default zoom | **OPEN** | `ops_panel.gd` `_accumulate_dressup_edge`: the first-pick decision uses `view.edge_near_point(body, point, 2.5, cam)` — **2.5 mm in model space** (≈10 px at the default frame, and the whole width of the 5 mm strip between slot rim and shaft edge). `edge_near_screen` / `DRESSUP_SNAP_PX` only apply after the first edge. A +Y-wall click after an edge is armed snapping to an edge is by design (`DRESSUP_SNAP_PX`), not a bug | WP2 |
| 5 | First viewport click after arming a tool lost; digits go into Extrude | **PARTIAL** | Circle/Polygon centre click case **FIXED-BY #182** (`arm_dim_replace`); Up To Surface eating a draw click **FIXED-BY #184**. Not proven fixed: the A10 sequence (File → New → ground sketch → rail tool → first click → type). Candidates: `_finish_click_shield` (#181) still armed after `New`/a new session; `release_distance_focus` ordering in `_sketch_input` press branch; focus left in the Extrude `LineEdit` after a finish. Reproduce first | WP3 |
| 6 | Strip / panel `R` drops the first typed char; first Tab dropped | **OPEN** | #182 armed replace-on-focus for the sketch Radius/AF blank and the dim editor only. The Fillet strip `R` (`viewport_interaction.gd` `_build_selection_strip`: `strip_le.focus_entered` rewrites the text with `_write_strip_radius(model, true)` and never calls `SxUi.arm_replace_on_focus`) and the Modify-panel Radius (`ops_panel.gd` `_build_body_ops`, `radius_le`) have no replace path: a deferred `select_all` loses the race with the first key under soft GL, and `1` of `1.5` is dropped | WP3 |
| 7 | Camera jumps after the slot-cut Extrude | **OPEN** | `orbit_camera.gd` `enter_sketch_view()` does `_sketch_pose = capture_pose()` on **every** call. `frame_sketch_rect()` (new in #182) and `F` / `_reassert_camera()` call it while already locked, so the saved pose becomes the zoomed sketch pose and `leave_sketch_view()` restores that | WP5 |
| 8 | Stray `5` label left of the slot | **OPEN (low)** | It is the slot cap radius label (`_add_slot`: `_record_dimension("radius", [cap_a], r, "")`) drawn at the cap-A arc by the generic arc rule in `_dimension_label_pos2`, not near the slot body | WP4 |
| 9 | Esc on a menu passes through (clears selection; left panel Selection → rail) | **OPEN** | `main.gd` `_unhandled_input` Esc → `interaction.cancel_stack()` / `view.clear_selection()` + `_update_panel_visibility()` run for the same Esc that closed a `PopupMenu`; nothing records that a popup consumed it | WP5 |
| 10 | Jaw lit vs hover indistinguishable | **OPEN (cosmetic)** | `main.gd` rail buttons are plain `toggle_mode` buttons in one `ButtonGroup`; pressed and hover share the theme hue (`_compact_sketch_rail_button` sets no pressed style) | WP5 |
| 11 | Circle Radius prefilled from another tool | **FIXED-BY #182** | `sketch_mode.gd` `circle_radius`, `sketch_context_chrome.gd` `sync_for_tool`. Re-verified by checklist L1 / L12 | checklist |
| 12 | Timeline overlay hides left-panel fields | **OPEN** | `main.gd` `_apply_chrome_docks` pins the Timeline at `dock_left = _CHROME_PAD + _RAIL_ICON_W + 8` (right of the icon rail, **over** `left_stack` / the Modify card where Radius lives) | WP5 |
| 13 | Mixed number formats `10` / `10.0` / `10 mm` | **OPEN (cosmetic)** | Strip uses `SxUi.reveal_committed_spin` (`compact_number` + suffix); the panel Radius `SpinBox` has no suffix and Godot reformats it (`10.0`) on focus exit / arrow | WP3 |
| 14 | Polygon status static; preview pointy-up vs committed flats-horizontal | **OPEN** | `sketch_mode.gd` `click` (Polygon) and the `Tool.POLYGON` preview snap `start_angle` to 30° steps from the pointer unless `_point_from_length` / `_length_override` (then 0). Off-axis pointer → vertex up in the preview; typed AF → 0 → flats horizontal. No status is emitted from `hover` | WP4 |
| 15 | Status overwritten by hover hints (`Opened …`, `Framed all`) | **OPEN** | `viewport_interaction.gd` `update_hover` tail emits `status` (`Face — click selects body first …`) on every hover-target change; `main.gd` `_on_status` has no hold | WP5 |
| 16 | Open lands extremely zoomed | **OPEN** | `main.gd` `_open_document` loads and never frames (`camera.frame_contents()` is not called) | WP5 |
| 17 | Constraint glyph pile-up at head centre | **OPEN** | `sketch_mode.gd` `_rebuild_constraint_glyphs` de-stacks in **sketch millimetres** (2 mm test, 2.5 mm step); at 150 px per Ø45 (≈3.3 px/mm) that is ≈8 px against a 22 px glyph | WP4 |
| 18 | Save As inside a sketch resets the Up To Surface target | **OPEN** | `main.gd` `_save_current` → `exit_sketch()` / `begin_edit()` → `_on_sketch_session_started` → `reset_finish_for_new_sketch`; nothing snapshots the finish bar around the Save | WP3 |
| 19 | Stray loft status with no tool armed | **RE-VERIFY** | Only `main.gd` `_loft_selected_sketches` prints it (chrome action `loft_*` with < 2 pad profiles). Probably reached through the pad path (#1) or a click that fell through a hidden panel (#12). Fix #1 / #12 first; if it still reproduces, the agent finds the caller with `print_stack()` and gates it | WP2 |
| 20 | Trim says `Trimmed` when nothing changed | **OPEN** | `sketch_mode.gd` `trim_at` generic branch: `sketch.trim_entity()` returned true, then `_undo_note`, `run_solve()` (nudges nodes) and `status "Trimmed"` with no geometry comparison | WP4 |
| 21 | N10: non-hovered region keeps a lighter fill | **DESIGN** | `_redraw_contour_highlight`: an **included** region fills at `CONTOUR_FILL_ALPHA` 0.28, the hovered one at `CONTOUR_FOCUS_ALPHA` 0.50, a **skipped** region is outline-only (replan 15 decision 2). The checklist row text was wrong; corrected in the sx-037 checklist | checklist |
| 22 | Export 3MF menu stall | **SOFT-GL** | One ~10 s File-menu freeze under llvmpipe; the walk's `_export_via_dialog` is green headless. Classify on hardware GL; no code | — |
| 23 | Small orbit drag, large tilt | **SOFT-GL** | `orbit_camera.gd` `ORBIT_SPEED = 0.008 rad/px` (≈0.46°/px, unchanged for many rounds). Classify on hardware GL; no code | — |
| 24 | Re-verify N11, N12 second click, N2 ▲/▼ | **RE-VERIFY** | N11 was blocked by the open mesh (#188); N12 second click is guarded by #181; N2 ▲ moves by `custom_arrow_step 0.5` (2 → 2.5 → 2; the walk expected "3.0" from an old step) | checklist, WP6 |
| 25 | Process: every parallel PR conflicts on `run_godot_suites.sh` / Makefile list | **OPEN** | Both files are append-only lists (16 + 153 scripts); #180–#188 each appended a line | **WP1** |

**Scope-check items from the critique, resolved:** stale ✕ at an old width endpoint / ✕ left on the `5` label after the editor, live Δu/Δv on a Select hover, `Measure cleared` with chips still showing, Up To Surface eating the first click, the contextual `Sketch` opening on the bottom face the UTS pick selected → all **FIXED-BY #184** (`_clear_select_click_measure`, `_chrome_face_pick_explicit`, `esc_keep_sketch`). Orange ✕ near circle1, stale disc, loose fit, ~130 px grid patch, HUD Frame / Shift+F in a sketch → **FIXED-BY #182** (`_contour_geom_sig`, `_apply_sketch_frame`, grid LOD). Label far from the jaw / `45°` under the menu → **FIXED-BY #186**. All re-verified by the checklist.

## Decisions (nothing left open)

1. **A plain click never opens a sketch.** Sketch edit starts only from the Timeline pencil / double-click (`_edit_sketch_feature`), the rail **Sketch** pick (`_picking_sketch_host`, status `Select a face or existing sketch (Esc to cancel)`), or **Ctrl/Cmd+click on pads** (multi-select, `%d sketch pad(s) selected — Merge sketches…`). A plain click on a pad falls through to normal body/face selection. Pad picking by ray is always strict: the hit must be within `PAD_INK_TOL_MM` of the sketch's ink. WP2.
2. **Exit Sketch with no change is a no-op for the document.** `begin_edit` remembers `sketch.snapshot()`; `exit_sketch` with an unchanged snapshot skips `graph_update_sketch`, ends the session, prints `Sketch saved`, and leaves `doc.revision()` alone. WP2.
3. **The first fillet click selects the face loop unless the pointer is within 6 screen px of an edge** (`DRESSUP_FIRST_PICK_EDGE_PX := 6.0`, tested with `view.edge_near_screen`). Later picks keep today's rules (`DRESSUP_SNAP_PX 14`). WP2.
4. **Replace-on-first-key for every numeric field the walk types into:** strip `R`, panel Radius, finish-bar Distance, using the #182 helpers (`SxUi.arm_replace_on_focus`, `write_typed_text`). Number format for the same value is identical in strip and panel: `SxUi.compact_number(v) + " mm"` (`10 mm`, `1.5 mm`, `2 mm`). One Tab leaves the field and the keys return to the viewport. WP3.
5. **Save As inside a sketch keeps the finish bar** (op, end, distance, thin, flip, Up To Surface target, selected contours) via `finish_snapshot()` / `finish_restore()` on `SketchContextChrome`. WP3.
6. **`enter_sketch_view` keeps the first saved pose** while `sketch_orientation_locked`; leaving a sketch (Extrude, Exit, Esc) returns the camera to the pose from before the session (±1e-3). WP5.
7. **Results hold; hints yield.** `ViewportInteraction` gets `signal hover_hint(text: String)`; the four hover emits become `hover_hint`. `main.gd` `_on_status` stamps `_status_hold_until = now + STATUS_HOLD_MS (2500)` for non-empty text; `_on_hover_hint` writes the label only after the hold. Every other status path is unchanged. WP5.
8. **A menu-closing Esc is consumed by the menu.** `main.gd` records the frame a menu-bar / HUD `PopupMenu` hid (`popup_hide`) and treats an Esc in that frame (or while any such menu is visible) as handled before `_unhandled_input` / `cancel_stack`. WP5.
9. **Open frames the part** (`camera.frame_contents()`, silent) and the status stays `Opened <path>` (decision 7). WP5.
10. **Armed rail tool is unmistakable:** the pressed / hover_pressed style of the sketch rail buttons has an accent fill and a 3 px left accent bar that the hover style lacks. WP5.
11. **Timeline never covers the Modify panel:** `_apply_chrome_docks` puts the Timeline at `max(dock_left, left_stack right + 8)` when the left stack is visible. WP5.
12. **Polygon across-flats is always flats-horizontal** (start angle 0) in preview and commit; while one point is set and the pointer moves, the status is `Polygon AF <size> — flats horizontal — click to place (or type the size)`; the commit string `Polygon AF 20.0000 — flats horizontal` is unchanged. WP4.
13. **Trim reports the truth:** unchanged sketch → `Nothing trimmed — no crossing at that point`, no undo entry, no solve. WP4.
14. **N10 fills:** included regions keep the light fill; only the hovered region is stronger; skipped regions are outline-only. No code change; checklist text fixed.
15. **Suite registration is one file per suite** (WP1); `run_godot_suites.sh` and the Makefile never list suites again.

## Work packages

Order: **WP1 alone, first.** Then **WP2, WP3, WP4, WP5 in parallel** (non-overlapping functions, table above). Then **WP6** (serial, last). Every WP adds `packaging/ci/suites.d/<name>.suite` for its suite (tier `ci` when the suite runs ≤ 60 s measured, else `full`; say which in the PR).

### WP1 — Parallel-safe suite registration (serial, first)

**Goal.** Adding a suite never edits a shared file. No currently gated suite is dropped.

**Today.** `packaging/ci/run_godot_suites.sh` lists **16** scripts (CI gate). `Makefile` `test-godot` lists **94** explicit scripts plus `for f in game/tests/run_rung01_replan{7..15}_*.gd` loops = **153 unique** scripts (`run_clearance_tests.gd` is listed twice) plus `run_rung01_sx036_rail.gd`. `run_rung01_n12_extrude.gd` is in the CI list but **not** in the Makefile. Not gated anywhere: `run_film_caption_tests.gd`, `run_ui_scroll_tests.gd` (leave unregistered). Every sx-036 PR appended to both files and conflicted.

**Design.**
- **Manifests:** `packaging/ci/suites.d/<name>.suite`, `<name>` = script basename without `run_` and `.gd` (`rung01_replan15_jawstub.suite`). Two keys, `key=value`, `#` comments: `script=tests/run_rung01_replan15_jawstub.gd` (relative to `game/`), `tier=ci|full`. Optional `timeout=<seconds>` (default 900). `ci` suites run in CI **and** `make test-godot`; `full` only in `make test-godot`. **154 files** = 153 Makefile scripts ∪ `run_rung01_n12_extrude.gd`; the 16 scripts now in `run_godot_suites.sh` are `tier=ci`, everything else `tier=full`. Generate them with a one-shot script from `git show 463ffe5:Makefile` + `git show 463ffe5:packaging/ci/run_godot_suites.sh` (expand the loops with the tree's `game/tests/run_rung01_replan{7..15}_*.gd`); do not hand-type. Add `packaging/ci/suites.d/README.md` (3 lines: how to add a suite, never edit the runners).
- **Runner:** new `packaging/ci/run_suites.sh [--tier ci|full] [--keep-going] [--only <glob>] [--list]`. Reads `${SX_SUITES_DIR:-packaging/ci/suites.d}/*.suite` sorted by file name, validates keys (unknown key / missing script / bad tier → exit 2), runs `"${GODOT_BIN:-tools/godot/godot}" --headless --path game --script <script>` under `timeout`, stops at the first failure (as today) unless `--keep-going` / `KEEP_GOING=1`, then prints `suites: <run> run, <failed> failed` and the failed names; exit 1 on any failure. `--tier ci` = tier ci only; `--tier full` = ci + full. `--list` prints the script paths it would run.
- `packaging/ci/run_godot_suites.sh`: keep the file and name (`ci.yml` calls it, do not edit `ci.yml`). Body: the import warm-up, `python3 tools/lint_suites.py`, then `exec packaging/ci/run_suites.sh --tier ci`. Keep the header comment, drop the list.
- `Makefile`: `test-godot: build import preflight` runs `GODOT_BIN=$(GODOT) packaging/ci/run_suites.sh --tier full $(if $(KEEP_GOING),--keep-going)`; delete every explicit line and the replan7–15 loops. `test-tools` also runs `python3 tools/lint_suites.py`. Everything else in the Makefile stays.
- `tools/lint_suites.py` (honours `SX_SUITES_DIR`): fails on a manifest with a missing / duplicate `script`, a missing script file, a bad tier, a name that is not derived from the script, any `game/tests/run_rung01_*.gd` **without** a manifest, and any script in the frozen `packaging/ci/suites.baseline` (154 basenames, the pre-WP1 union) that lost its manifest. Prints `lint_suites: <n> suites ok (<ci> ci, <full> full)`.
- `tools/lint_rung01_e2e.py`: replace `_lint_replan13/14/15` and their print lines by one `_lint_replan_n(errors)` that globs `run_rung01_replan(\d+)_*.gd` for **N ≥ 13**, applies the same `_lint_replan11_camera(..., extra_yaw_pitch_ok=("_zoom_model",))`, requires ≥ 1 script for 13, 14, 15 only, and prints `lint_rung01_e2e: <n> replan<N> scripts are clean` for every N found (same text as today, e.g. `6 replan15 scripts are clean`). Replan 3–12 functions stay untouched.
- `AGENTS.md` "Building and testing": one paragraph — `make test-godot` runs every manifest in `packaging/ci/suites.d/`; add a suite by adding a `.suite` file; `KEEP_GOING=1 make test-godot` shows every failure.

**Files.** New: `packaging/ci/run_suites.sh`, `packaging/ci/suites.d/*.suite` (154) + `README.md`, `packaging/ci/suites.baseline`, `tools/lint_suites.py`, `tools/test_lint_suites.py`, `game/tests/run_rung01_replan16_suites.gd`, `packaging/ci/suites.d/rung01_replan16_suites.suite`. Edited: `packaging/ci/run_godot_suites.sh`, `Makefile`, `tools/lint_rung01_e2e.py`, `AGENTS.md`.

**Acceptance (exact).**
- `packaging/ci/run_suites.sh --tier ci --list` prints exactly the 16 old CI scripts **plus** `tests/run_rung01_replan16_suites.gd` (17 lines); `--tier full --list` prints ≥ 155 lines and contains every basename in `suites.baseline`.
- `python3 tools/lint_suites.py` → `lint_suites: 155 suites ok (17 ci, 138 full)`.
- `python3 tools/lint_rung01_e2e.py` still prints `6 replan15 scripts are clean` and exits 0.
- `packaging/ci/run_godot_suites.sh` ends `Gated suites completed.` with the same pass/fail meaning as before; `make -n test-godot` shows no `run_*.gd` line.
- **Merge-cleanliness proof in the PR body:** create two throwaway branches off WP1's head, each adding one `suites.d/zz_<x>.suite` and one `game/tests/run_rung01_replan16_<x>.gd`, merge both into a third branch → `git merge` reports no conflict; paste the output. Delete the branches.
- Test `game/tests/run_rung01_replan16_suites.gd` (`tier=ci`): `DirAccess` over `<project>/../packaging/ci/suites.d`: every manifest parses; the baseline basenames ⊆ manifest scripts; the 16 old CI scripts are `tier=ci` (hard-coded list in the test); `OS.execute("python3", ["tools/lint_suites.py"])` exit 0; with `SX_SUITES_DIR` pointing at a temp dir holding one manifest whose script does not exist, the same call exits 1 and prints `missing script`; `OS.execute("bash", ["packaging/ci/run_suites.sh","--tier","ci","--list"])` line count equals the number of `tier=ci` manifests. Prints `N checks, 0 failures`.

**Unblocks.** Every later WP merges without a suite-list conflict (hard requirement for WP2–WP6).

### WP2 — Clicks never open sketches; clean dirty flag; first fillet click selects the face (leftovers 1, 2, 4, 19)

**Goal.** A single click on a face, a slot floor, empty space or a chip never prints `Editing sketch`; Save → refused fillet → Esc → File → New shows no Discard dialog; one click inside a face selects its whole loop.

**Files / functions.**
- `game/scripts/viewport_interaction.gd` `_click_hits_pad()` only: return `false` unless `_additive_click` (Ctrl/Cmd multi-select) — `_commit_pick_sketch_host` (rail Sketch pick) is a separate path and stays. When it does run, call `view.sketch_pads.pick_pad_visible(..., true)` (strict).
- `game/scripts/sketch_pad_overlay.gd` `pick_pad_visible(ray_origin, ray_dir, solid_t := INF, strict := false)`: when `strict`, **always** require `_ink_distance(...) ≤ PAD_INK_TOL_MM` (also when `solid_t` is INF and when the ray crosses the plane above the solid). Default behaviour (`strict == false`) unchanged for the host pick.
- `game/scripts/main.gd` `_on_sketch_pad_clicked()`: no change to logic; keep the Ctrl/Cmd branch. (File listed because tests call it.)
- `game/scripts/sketch_mode.gd` `begin_edit()` stores `_edit_baseline := loaded.snapshot()`; `exit_sketch()` — when `editing_fid != ""` and `sketch.snapshot() == _edit_baseline`: skip `view.doc.graph_update_sketch`, `_end_sketch_session()`, `status.emit("Sketch saved")`, return `editing_fid`. A changed sketch takes today's path. `_edit_baseline` cleared in `_end_sketch_session` / `cancel`.
- `game/scripts/ops_panel.gd` `_accumulate_dressup_edge()`: replace `view.edge_near_point(body, point, 2.5, cam)` in the first-pick decision by `view.edge_near_screen(body, cam, view.model_to_screen(cam, point), DRESSUP_FIRST_PICK_EDGE_PX)` with new `const DRESSUP_FIRST_PICK_EDGE_PX := 6.0`; the `edge == ""`-fallbacks below it stay.

**Acceptance (exact).** `game/tests/run_rung01_replan16_picks.gd` (`tier=ci`):
- P1 (leftover 1): body with a consumed sketch pad (build the shaft + slot as `run_rung01_replan15_chain.gd` S4). Real click at the slot floor (ray crosses the z=10 pad plane inside the pad box, floor 2.5 mm lower, no ink within 1.5 mm): `sm.active == false`; no status in the log contains `Editing sketch`; status begins `Selected `. Same with a click on empty ground inside the pad's box, and with a click at the screen pixel of the contextual `Fillet` chip after a fillet pick was cancelled (`Edge pick cancelled`): arms Fillet (`Fillet r=`), never `Editing sketch`.
- P2: Ctrl+click on a pad → status `1 sketch pad(s) selected — Merge sketches…`, `sm.active == false`. Rail Sketch (`Select a face or existing sketch (Esc to cancel)`) then a click on the pad ink → `Editing sketch`. Timeline pencil → `Editing sketch` (unchanged).
- P3 (leftover 2): save (`main._save_current()` after `current_path` set), `begin_edit` through the pencil, **no edit**, Exit Sketch → status `Sketch saved`, `doc.revision()` equal to before, `main._document_is_dirty() == false`. Then a real edit (move a dimension) → `_document_is_dirty() == true`. Then the L7 order: Save; Fillet R1.5 slot floor refused (`… exceeds the 1.250 mm limit set by the 150.000 mm line edge …`); Esc → `Edge pick cancelled`; File → New (real menu click) → `confirm_dialog.visible == false` and status `New — empty part, Top plane (XY). View ▸ Timeline to edit features`.
- P4 (leftover 4): wrench-like top face; real click ≥ 8 px from every edge → status begins `Fillet: ` with `n ≥ 6` edges and contains no `0.0 mm line`; real click ≤ 3 px from an edge → `Fillet: 1 edge(s) — `; Enter at R1 → `Fillet <n> edges 1.00 applied`; closed-shell export true.
- P5 (leftover 19): after P1–P4 clicks, no status contains `loft`. If it still reproduces, the PR names the caller.
- Also run: `run_rung01_replan13_dirty.gd`, `run_rung01_replan14_polish.gd`, `run_rung01_replan5_face.gd`, `run_rung01_replan11_fillet_ui.gd`, `run_rung01_replan12_pick.gd`, `run_rung01_sx036_esc.gd`, `run_rung01_wrench.gd`.

**Unblocks.** N15 (new), L7, N3 anomaly, A11b / A11d / A11e first-try, N8a, A13.

### WP3 — Numeric fields: first key replaces, one format, Save As keeps the finish bar (leftovers 5, 6, 13, 18)

**Goal.** Typing into strip `R`, panel Radius, finish-bar Distance replaces the whole value with every key; the same value reads the same in strip and panel; Save As inside a sketch does not touch the finish bar; the A10 sequence puts digits in the tool's own field.

**Files / functions.**
- `game/scripts/viewport_interaction.gd` `_build_selection_strip()` strip block only: at the end of the `strip_le.focus_entered` lambda call `SxUi.arm_replace_on_focus(strip_le)`; add a `strip_le.gui_input` key handler (extend the existing Tab one): a numeric key (digit, `.`, `-`) while `SxUi.replace_armed(strip_le)` → `SxUi.write_typed_text(strip_le, ch)`, `accept_event()` (same shape as `_on_dim_edit_gui_input` in `sketch_context_chrome.gd`). Tab stays: commit, `return_viewport_keys()`.
- `game/scripts/ops_panel.gd` `_build_body_ops()` Radius block only: same for `radius_le`; give `_radius_spin` the suffix `mm` so `SxUi.reveal_committed_spin` writes the same text as the strip.
- `game/scripts/ui_spin.gd`: add `static func numeric_key_char(k: InputEventKey) -> String` (move the body of `sketch_context_chrome._numeric_key_char`; leave a one-line wrapper there) and `static func fmt_mm(v: float) -> String` (`compact_number(v) + " mm"`). Nothing else.
- `game/scripts/sketch_context_chrome.gd`: new `finish_snapshot() -> Dictionary` and `finish_restore(d: Dictionary)` (op, end, distance text/value, thin on/type/thickness, flip, `up_to_face_id`, `_selected_contours`); Distance `LineEdit` uses the same replace-on-first-key path (`_distance_replace_next` already exists — make it call `SxUi.arm_replace_on_focus`/`write_typed_text`); `release_distance_focus()` is called by `main._on_sketch_session_started` for a **new** session only.
- `game/scripts/main.gd` `_save_current()` only: `var fin := sketch_chrome.finish_snapshot()` before `exit_sketch()`, `sketch_chrome.finish_restore(fin)` after `_on_sketch_session_started("Editing sketch")`; the `Saved <path>` status stays last.

**Acceptance (exact).** `game/tests/run_rung01_replan16_fields.gd` (`tier=ci`):
- F1 (leftover 6): Fillet armed on a box; real triple-click in strip `R`, real keys `1` → field reads `1` (never `10`, never empty); then `.` `5` → `1.5`; Enter → status `Fillet r=1.50 — edit Radius, click edges, Enter`. Same for panel Radius. Type `10` after a click that selects (reads `10`, not `100` / `.0`). One real Tab: `get_viewport().gui_get_focus_owner()` is not a `LineEdit`/`SpinBox`, then real key `3` → `Top view`.
- F2 (leftover 13): for values `10`, `1.5`, `2`, `0.25` reached by (typing + Enter), (Tab), (▲ then ▼ from 2: `2.5 mm` then `2 mm`), (focus exit), (`ops_panel.set_dressup_radius`): `strip_le.text == panel_le.text == SxUi.fmt_mm(v)` and no `10.0` / bare `10` variants.
- F3 (leftover 5): rail Circle press, **first** real canvas click → status `Circle — centre set, click the rim or type a radius`, Radius `LineEdit` has focus, Extrude Distance `LineEdit` does not; keys `5` `0` → Radius reads `50`, Distance text unchanged (`20.0 mm`); Enter → `Circle r=50.0000 (Ø100.0000)`. Repeat for Polygon (`Polygon AF 20.0000 — flats horizontal`) and Slot (`Slot radius 5.0000 — …`) and for the **A10 order**: Extrude click on a first body → File → New (real menu) → rail Sketch on ground → rail Circle → first click → type. Each placement must happen on the **first** click; if one is lost the PR names the cause (shield, focus, order) and fixes it in `_finish_click_shield` handling / `_sketch_input` press branch **only**.
- F4 (leftover 18): finish bar Cut / Up To Surface / `Opposite face` (`Face: z 0.0 mm`) / Distance `7` / flip on → `main.current_path` set → real Ctrl+S (`_save_current`) → `finish_snapshot()` equals the one taken before; status `Saved <path>`; the Extrude button still reads enabled; Ctrl+Z → status begins `Undo:` (undo kept, #184).
- Also run: `run_rung01_sx036_fields.gd`, `run_rung01_replan13_radius.gd`, `run_rung01_replan14_focuskeys.gd`, `run_rung01_replan15_armedkeys.gd`, `run_rung01_replan2_distance.gd`, `run_rung01_replan3_distance.gd`, `run_rung01_replan12_panel.gd`, `run_rung01_n12_extrude.gd`, `run_rung01_wrench.gd`.

**Unblocks.** L3, N2, A11d / A11e (R typing), A10, A3, L2, A9c, N20 (new).

### WP4 — Sketch visuals and honest Trim (leftovers 3, 8, 14, 17, 20) — `sketch_mode.gd` only

**Goal.** At a ~150 px head the labels are `20`, `45°`, `5`, `22.5` with no overlap and no glyph pile-up; the slot radius label sits on the slot; Polygon preview matches the commit; Trim never says `Trimmed` for no change.

**Functions.** `_rebuild_constraint_glyphs` (px-space de-stack + re-run from `_on_sketch_camera_moved`; keep `_glyph_anchors["pos"]` in sketch units so `constraint_hit` / `GLYPH_PICK_RADIUS` still work), `constraint_glyph_screen_rects`, `_dimension_label_pos2` (arc/slot-cap radius label placed outside the slot body, within `1.5 × r + 6` mm of the slot AABB), `click` Polygon branch + `Tool.POLYGON` preview (across-flats start angle 0), `hover` (new live status), `trim_at` generic branch. New public `polygon_preview_vertices() -> Array[Vector2]` (read-only, for the test).

**Acceptance (exact).** `game/tests/run_rung01_replan16_sketchvis.gd` (`tier=ci`):
- V1 (leftover 3): face sketch with Jaw 20 / 45°, pivot `Circle r=5.0000 (Ø10.0000)`, head circle Ø45, a **plain Line** cutter; real Trim drag → `Trimmed open jaw`. Zoom (real wheel) until the Ø45 head projects to 150 ± 10 px. `dimension_label_screen_rects()` texts, sorted, equal `["20", "22.5", "45°", "5"]`; no two rects intersect; no label rect intersects any `constraint_glyph_screen_rects()` rect; every label rect is inside `_label_safe_screen_rect()`.
- V2 (leftover 17): at that zoom, pairwise glyph overlap area ≤ 20 % of the smaller glyph; a real Select click on a glyph still selects its constraint (`Constraint selected: …`).
- V3 (leftover 8): Slot (radius 5, c-c 150 typed): label `5` centre within `1.5 × 5 + 6` mm of the slot AABB; label `150` likewise.
- V4 (leftover 14): Polygon (variant `across_flats`), centre click, then three real pointer moves at 20°, 70°, 110° from the centre: `polygon_preview_vertices()` has ≥ 2 vertex pairs with equal y (flats horizontal) at every move; status after each move matches `^Polygon AF \d+\.\d{4} — flats horizontal — click to place \(or type the size\)$`; before the first move status is still `Polygon — click the centre, then a vertex (or type the size)`; after typing `20` Enter: `Polygon AF 20.0000 — flats horizontal`, committed vertices equal the preview's.
- V5 (leftover 20): jaw sketch with the cutter **not** across the jaw (walker error case): real Trim drag → `Nothing trimmed — no crossing at that point`, never bare `Trimmed`; `sketch.snapshot()` identical before / after; no new undo entry (`Ctrl+Z` status is the previous action's, not `Undo: Trim`).
- Also run: `run_rung01_jaw_label_hit.gd`, `run_rung01_replan12_labels.gd`, `run_rung01_replan14_savelabels.gd`, `run_rung01_replan14_trim.gd`, `run_rung01_replan13_trim.gd`, `run_rung01_replan11_poly.gd`, `run_rung01_replan11_slot.gd`, `run_rung01_replan15_jawstub.gd`, `run_sketch_tools_tests.gd`, `run_rung01_wrench.gd`.

**Unblocks.** N1a, L4, L9, A9, A14, N21 (new), A11a label rows.

### WP5 — Chrome, status hold, camera (leftovers 7, 9, 10, 12, 15, 16)

**Goal.** Extrude returns the camera; menu Esc is consumed; the armed rail tool is visible; the Timeline stays off the Modify panel; command results stay readable; Open frames the part.

**Files / functions.** `orbit_camera.gd` `enter_sketch_view()` (`if not sketch_orientation_locked: _sketch_pose = capture_pose()`; `leave_sketch_view` unchanged). `main.gd`: `_on_status` (+ `_status_hold_until`, `STATUS_HOLD_MS := 2500`), new `_on_hover_hint` connected next to `interaction.status.connect(_on_status)`; `_unhandled_input` Esc (menu guard, new `_esc_closed_menu()` fed by `popup_hide` on the menu-bar and HUD popups); `_open_document` (`camera.frame_contents()` after a successful load, before the status); `_apply_chrome_docks` (Timeline / Variables x); rail style in `_compact_sketch_rail_button` (pressed / hover_pressed `StyleBoxFlat`: accent fill + `border_width_left = 3`). `viewport_interaction.gd`: `signal hover_hint(text: String)`, the four hover `status.emit` calls in `update_hover` become `hover_hint.emit`; `cancel_stack()` first line returns `true` when `main._esc_closed_menu()`.

**Acceptance (exact).** `game/tests/run_rung01_replan16_chrome.gd` (`tier=ci`):
- C1 (7): Top view, body, rail Sketch + top face, `F` (`Sketch view fit`), Slot + Cut / Blind / `2.5`, one real Extrude click → `Extrude Blind 2.5000 mm`; camera `yaw`, `pitch`, `distance`, `pivot`, `projection` equal the pre-sketch values within 1e-3 (read, never written).
- C2 (9): real click on menu-bar View → popup visible; body selected before; real `Esc` → popup hidden, `view.selected_body` unchanged, left-panel mode unchanged, no status `Selection cleared`. Same for the HUD View ▼ popup. A second `Esc` with no popup → `Selection cleared` (unchanged behaviour).
- C3 (10): rail `ToolJaw` armed: `get_theme_stylebox("pressed")` is a `StyleBoxFlat` whose `bg_color` differs from the `hover` one by ≥ 0.12 luminance and `border_width_left == 3`; the same button not armed has neither; Rect armed shows Rect lit and Jaw not (N7).
- C4 (12): Fillet armed (panel Radius visible), View ▸ Timeline on: `timeline.get_global_rect()` does not intersect `_radius_spin.get_global_rect()`; both inside the window; real click on the panel Radius line → it has focus.
- C5 (15): `Open` of a saved `.sxp` via the real dialog → status label `Opened <path>`; 40 real pointer moves over the body (hover hints fire) for 1.5 s → label still `Opened <path>`; after 3 s a hover shows `Face — click selects body first, click again for face · then Pull arrow`. HUD Frame click → `Framed all`, same hold.
- C6 (16): after C5's open, the body's projected AABB lies inside the chrome-free canvas and spans ≥ 40 % of its width.
- Also run: `run_rung01_replan14_camera.gd`, `run_rung01_replan13_frame.gd`, `run_rung01_replan2_camera.gd`, `run_rung01_replan11_views.gd`, `run_rung01_replan12_rail.gd`, `run_rung01_sx036_rail.gd`, `run_rung01_replan14_railstatus.gd`, `run_menu_tests.gd`, `run_layout_tests.gd`, `run_timeline_ux_tests.gd`, `run_rung01_wrench.gd`.

**Unblocks.** A11a, A9b camera, N6, N7, N8b, L11, A16, A13 / A13b, N2(c), N16–N19 (new).

### WP6 — GUI-order replay: the honesty gap (serial, last; needs WP2–WP5 merged)

**Goal.** One headless suite that performs sx-036 chunks 1–6 in the **same order and with the same transitions** as the human walk, so a GUI-red / headless-green split cannot recur. sx-036's headless walk was 729 / 0 while the GUI head was 31.3 wide.

**File.** New `game/tests/run_rung01_replan16_walk.gd` (+ `suites.d` file; `tier=ci` if measured ≤ 150 s, else `full` and the PR says so; allow `timeout 420`; `DISPLAY=:1`, run alone). Copy helpers from `run_rung01_wrench.gd`, `run_rung01_replan15_chain.gd`, `run_rung01_sx036_esc.gd`, `run_rung01_jaw_label_hit.gd`. It edits no product file and **no existing suite**. After it passes, it ticks `docs/plan/STATUS.md` (one line under a new "Rung 1 replan 16" heading).

**Stages** (each `check` names its stage; a red stage skips only dependants and prints `WALK-SUMMARY stages=<n> first_red=<stage|none>`; `no status in the whole run contains "Editing sketch" except at S5 / S9 pencil steps`, and none matches a UUID):
- **S1 blank (chunk 1):** ground sketch; circles `Circle r=10.0000 (Ø20.0000)`, `Circle r=22.5000 (Ø45.0000)` typed with real keys (Radius field reads `22.5`, Distance unchanged); Smart Dim centres, popup reads `200`, `Dimension updated`; `F` → `Sketch view fit`; `Shaft lines: 2 added`; Distance `10`; **one** Extrude click → `Extrude Blind 10.0000 mm`, a second click at the same pixel changes nothing (no `jaw_af`, feature count equal); export via dialog `blank.3mf` → checker **blank 5/5**; `Save As blank.sxp` → `Saved …`.
- **S2 face sketch (chunk 2):** top face; Cut / Up To Surface / 7; Circle first click lands, Esc → `First point dropped — Esc again exits the sketch`, Esc → `Sketch cancelled`; throwaway Polygon + Circle centre, Esc, Esc → `Sketch saved`, part-mode Ctrl+Z → `Undo`, sketch count back; Jaw (3 clicks, repeated click 2 → `Jaw — width is zero — click 3 again for half the width`), label clicks open the editor, `20` / `45` → `Dimension updated`; Ctrl+Z ×5 / Ctrl+Shift+Z ×3 statuses as the checklist N5; Select + jaw line + Esc → `Selection cleared — Esc again exits the sketch`, Esc → `Sketch saved`; part-mode Ctrl+Z `Undo`, Ctrl+Shift+Z `Redo`, jaw sketch still listed.
- **S3 trim and cut (chunk 3):** pencil → `Editing sketch`; pivot `Circle r=5.0000 (Ø10.0000)`; plain Line cutter; Trim drag **from the outer stub** → `Trimmed open jaw`, again → `Jaw is already open — nothing left to trim here`; labels at 150 px = `["20","22.5","45°","5"]`, no overlap; Cut / UTS / `Opposite face`; Save As `pre-cut.sxp` **twice** (overwrite): finish bar identical after each, Ctrl+Z status begins `Undo:`; one Extrude click → `Extrude Up To Surface 10.0000 mm`; body bbox `232.5 × 45.0 × 10.0` (±0.3); a real click inside the head → `Selected `; camera equals the pre-sketch pose (C1).
- **S4 slot (chunk 4):** views `4`/`6`/`8`/`3`, `F`, HUD Frame; Slot radius `5`, centre `(18.5, 0)`, `150`; `Slot c-c 150.0000 R5.0000 — typed`; Cut 2.5 → `Extrude Blind 2.5000 mm`; Save As `wrench-wip.sxp`.
- **S5 fillets (chunk 5):** Fillet armed; strip ▲ `2.5 mm`, ▼ `2 mm`, key `3` → `Top view`; strip `10` Enter, `3`, `4`, panel `10` Enter, `3` (Fillet still armed each time); neck corners → `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters`; top face R1, bottom face R1 (`8`), slot floor R1 (**each on the first click**, `Fillet <n> edges 1.00 applied`), slot floor R1.5 refused (`exceeds the 1.250 mm limit`), Esc → `Edge pick cancelled`; clicking the Fillet chip afterwards arms Fillet (`Fillet r=`); key `0` → `No view for key 0 — use 1 2 3 4 6 7 8`.
- **S6 export (chunk 6):** dialog `wrench.3mf` → checker **wrench 28/28** (`flipX=False flipY=False`); dialog `wrench-noext` → file `wrench-noext.3mf` exists, no `wrench-noext`, status `Exported 3MF → …/wrench-noext.3mf` (N11), 28/28; Timeline Distance 14 Enter → `Preview: distance = 14.0`, no `lost on rebuild`; Esc → `Edits cancelled`; export `wrench-t14.3mf` → **thick 7/7**; DIAG prints exactly the four by-design fails.
- **S7 L7 / N8b:** Save As `wrench-t14.sxp`; slot-floor R1.5 refused; Esc; File → New → no `confirm_dialog`; then Open `blank.sxp` (single click on the name, Open enabled): status `Opened …/blank.sxp` still on the label after 1.5 s of hovering, body framed (C6); a real edit (new primitive) then File → New → `confirm_dialog.visible == true`.
- **S8 nut:** Polygon AF 20, hole r5, extrude 7.5 → export → **nut 7/7** (the rest of A10 / A10b / N14 / L9 stay in `run_rung01_wrench.gd`).

**Acceptance.** All stages green on the merged tree; checker tables printed into the run log; `0 failures`. A red stage is a **finding**, not a WP failure: the PR lists the first red stage, its status log, `sm.sketch.snapshot()` and the checker table, and the parent launches a WP6b with it.

**Unblocks.** The N11, N12-second-click, N2-arrow, N1a-22.5, L7 re-verifies and confidence in every GUI row.

## Row → WP map (what each WP must turn green in sx-037)

| WP | Rows |
|---|---|
| WP1 | process (no row) |
| WP2 | N15, L7, N3, A11b, A11d, A11e, N8a, A13 |
| WP3 | L3, N2, A3, A10, L2, A9c, A11d, A11e, N20 |
| WP4 | N1a, L4, L9, A9, A14, A11a, N21 |
| WP5 | A9b, A11a, N6, N7, N8b, L11, A16, A13, A13b, N16, N17, N18, N19 |
| WP6 | A12, N11, N12, N2, N1a, L7, N8b, A13c, N9, every GUI row (replay) |
| already merged | A1, A3, A4, A5, A6, A8, A8b, A9, A9b, A11d, A12, A13, A13c, L5, L6, N4, N5, N9, N12 |

## Risks

- WP2 changes a behaviour two older suites may assert (plain pad click opens the sketch). The agent greps `Editing sketch` / `sketch_pad_clicked` in `game/tests/` first; the two hits found on `main` (`run_rung01_replan14_polish.gd:146`, `run_rung01_wrench.gd:4298`) go through the Timeline pencil and must stay green.
- WP5 `hover_hint` touches a signal tests may listen on (`interaction.status`). The agent greps for `Face — click selects body first` first (none on `main`).
- WP1 is the only WP that edits `Makefile` / `run_godot_suites.sh` / `lint_rung01_e2e.py`; if a sibling PR lands first with a suite line, WP1 rebases and converts that line to a manifest.
- Soft-GL items (22, 23) are never fixed in code; the walker classifies them with evidence (screenshot + status) per the checklist rules.
