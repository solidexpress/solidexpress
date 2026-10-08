# Rung 1 replan 17 — WP6 (serial, last): the sx-038 headless walk and the final gates

Status: planned. Plan: [`rung-01-replan-17.md`](rung-01-replan-17.md). Next walk: [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md) (sx-038). Baseline: `main` after WP1–WP5 are merged.

**Start this WP only when WP1, WP2, WP3, WP4 and WP5 are merged into `main`** (`starting_ref` = that `main`'s full sha). If one is missing, stop and say which in the PR body; do not stub its API.

Triage items covered: **T3** (A8b Timeline numbering: a checklist error, pinned here by a test), plus the integration of **T1, T2, T5–T14** into one continuous walk. Walk rows unblocked: the whole of sx-038 (the replan17 walk is the headless twin of the checklist).

Files you may edit: new `game/tests/run_rung01_replan17_walk.gd`, new `packaging/ci/suites.d/rung01_replan17_walk.suite`, `docs/loop/rung-01-replan-17-checklist.md` (only a row whose pass text turns out to contradict `main`; list each edit in the PR body). **No product code.** If a walk assertion is red because of a product bug, do not fix it here: mark the stage red, say which WP owns it (table in `rung-01-replan-17.md`), and open the PR as ready only after the owner's fix is in `main` (re-run after rebase). A red walk is never merged.

## Rules for every BUILD agent (read first)

- **Repository:** `github.com/solidexpress/solidexpress` only. Never the `snadrus` fork. Do not touch PR #11.
- **Model / start:** grok-4.7, medium effort. `starting_ref` = the full 40-character sha of `main` at launch (the plan was written against `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`; function names below are stable, line numbers are for that sha).
- **One PR per WP, to `main`.** Mark it **ready for review** (not draft). Never merge it yourself. Quick CI must be green: **linux kernel, godot-smoke, website-demos**. **Do not wait for `windows-export` or `macos-kernel`.**
- **Do NOT edit `docs/plan/STATUS.md`** (take `main`'s version on any conflict). Put your notes (what changed, reproduce-first output, skipped items with the reason) in the **PR body**.
- **Reproduce first.** Write the new suite, run it on the starting ref **before** any product edit, paste the real red/green output in the PR body. Green on baseline = keep the suite as a regression net and say the item was already fixed or is soft-GL.
- **Tests are real input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`. Every press, key, motion and wheel **under test** is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed with `Viewport.push_input`. Forbidden on a path under test (the e2e lint fails the PR): `select_entity`, `.text =`, `.value =`, `.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =`. Boot at 1280x800 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))`). Templates to copy: `game/tests/run_rung01_sx037_chipclick.gd` (`_boot`, `_x11_click`, `_x11_click_screen`, `_click_uv`, `_push_key`), `run_rung01_sx037_exit.gd`, `run_rung01_l12_measure.gd`.
- **Register a suite** by adding one new file `packaging/ci/suites.d/<name>.suite` (`<name>` = script basename without `run_` and `.gd`). Keys: `script=tests/run_rung01_replan17_<x>.gd`, `tier=ci` (when it runs in <= 60 s measured; say so in the PR) or `tier=full`, optional `timeout=<s>`. **Never edit** `packaging/ci/run_godot_suites.sh`, the Makefile `test-godot` recipe or `tools/lint_rung01_e2e.py` (WP5 is the only exception, and only for the files its own text names). Do not commit `.gd.uid` files.
- **Before opening the PR run, one at a time:** your new suite; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; `tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd` (0 failures, >= 729 checks); `tools/godot/godot --headless --path game --script tests/run_rung01_replan16_walk.gd` (0 failures, `WALK-SUMMARY stages=8 first_red=none`); every suite in your "Also run" list. Environment: `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib`, `DISPLAY=:1` for X11 suites; run suites alone. The known-red suites in `AGENTS.md` stay exactly as they are unless WP5 changes their tier.
- **Never** pass `user://` or `res://` into GDExtension C++ (`SxDocument` / kernel I/O); `ProjectSettings.globalize_path(...)` first.
- **Parallel-safe edits.** Other WPs run at the same time on the same files in *different functions*. Edit only the functions your WP names. No reformatting, no moved code, no new top-of-file constants outside your own block, no renames of existing status strings unless your WP says so.
- **No design decisions are left to you.** Every choice is in the `Decisions` section of your WP. If the code on `main` contradicts a stated fact, stop, say so in the PR body, and implement the closest reading of the decision.

## Why

`run_rung01_replan16_walk.gd` replays the sx-037 checklist in one continuous document (8 stages, ~29 s). It proves geometry (nut, blank, wrench, thick) and the GUI path, but it asserts nothing about the sx-038 deltas (marquee, glyph anchors, DOF chip after undo, Timeline vs chip row, hover hint after the hold, polygon vertex under the pointer, window rect). The replan17 walk is the same path with those assertions added, so one run says whether a fresh agent's `main` would pass sx-038.

## Decisions (final)

1. **Copy, do not refactor.** `run_rung01_replan17_walk.gd` starts as a verbatim copy of `run_rung01_replan16_walk.gd` (same 8 stages `S1`..`S8`, same helpers). Change only: the header comment, `OUT := "/tmp/sx-038-out"`, the `print` title (`rung01 replan17 GUI-order walk`), and the additions below. The replan16 walk stays unchanged and green. `WALK-SUMMARY stages=8 first_red=none` is the pass line (the checklist A15 row says so).
2. **Only real input under test.** The e2e lint covers `run_rung01_replan17_*.gd`: no `select_entity`, `.text =`, `.value =`, `.emit`, `set_view(`, `_look_along(`, `.yaw =`, `.pitch =`, `.basis =` on a tested path. Reading state (`sm.selected`, `glyph_debug()`, `last_click_disposition`, `contour_highlight_state()`, `get_global_rect()`) is allowed.
3. **Tier and timeout.** `tier=ci`, `timeout=240`. If the measured run is above 90 s on the reference box, set `tier=full` and say so in the PR body (godot-smoke must stay under its budget). `SX_WALK_ONLY=S1` keeps working.
4. **No sleeps except the two the rows need** (N16: 3.0 s after the key; N8b: 3.0 s after `Opened …`). Use `await process_frame` / the helpers otherwise.

## Additions per stage (exact; every one is a `check(...)` with the checklist string)

**S1 (chunk 1)**
- N22: `Main.window_fit_rect(Rect2i(0, 0, 1280, 800), Vector2i(1072, 620), Vector2i(0, 28)) == Rect2i(0, 0, 1280, 772)`.
- A2: after rail **Jaw** then rail **Rect**: the chip buttons' texts in order are `Corner`, `Center`, `Three Point`, `Center Three Point`, `Parallelogram`; status begins `Rect — click 1`.
- N7: the armed rail button has a child `RailAccentBar`; no other rail button has one lit.
- A3 / T14: after the two circles and the Smart Dim picks, no `point` entity exists in the sketch (`entity_info(id)["type"]`).
- A5: after the Extrude click: `Extrude Blind 10.0000 mm`; `ctx.main.sketch_mode` shows no pad lines (`ctx.main.sketch_pad_overlay` has no visible child meshes, or the overlay's `visible == false`; use the accessor the extrude-frame suite `run_extrude_frame_tests.gd` uses); the camera frames the body (`_assert_framed`).
- N12 unchanged.

**S2 (chunk 2)**
- A7: right after the sketch opens on the top face the head circle position (model `HEAD`) projects inside the canvas rect (right of the rail, inside the window) **without** any `F` press.
- A6 / N4: after `Sketch cancelled` and after `Sketch saved` the part selection is empty (`ctx.view.selected_face == ""`, `selected_body == ""`).
- A8: read the preview mesh the way `run_rung01_replan17_tools.gd` (WP2) does: 4 segments after click 1 and after click 2; with the pointer on the axis still 4.
- N25: after `Undo: Jaw` takes the sketch to empty, `ctx.main.dof_label.text == "—"`; after `Redo: Jaw` it equals the text from before the undo.
- **T3 / A8b**: after the part-mode Ctrl+Shift+Z the Timeline row of the jaw sketch reads `sketch 3` (read the row name button text, helper `_row_name_button`; the base rows read `sketch 1` and `extrude 2`), and the list of feature names is exactly `["sketch 1", "extrude 2", "sketch 3"]` in order. Also assert it **before** the throwaway: opening the N4 throwaway names it `sketch 3`, and after its Ctrl+Z the next sketch is again `sketch 3` (names are indices, not counters).

**S3 (chunk 3)**
- A9: the Line tool's Length blank is not `22.5` after the Circle (`sm.length_blank_text() != "22.5"`; use the field the sx-037 fields suite reads in `run_rung01_sx037_fields.gd`); no trim trail node after the drag release.
- N1a / N26: `glyph_debug()` entries all have `offset_px <= SketchMode.GLYPH_MAX_OFFSET_PX + 0.5`, and no glyph rect is within `GLYPH_LABEL_GAP_PX - 0.5` px of a label rect.
- L12: Select hover shows the measure (`ctx.main.interaction.measure_active()` or the accessor `run_rung01_l12_measure.gd` reads) with Δ; after `F` it is gone.
- N24: throwaway circle r 3 in empty canvas; window drag `Selected 1 sketch entity`; crossing drag `Selected 1 sketch entity`; a window drag that only cuts the rim `No sketch entities`; Delete → `Deleted 1`; the entity count equals the count before the circle.
- A17: a Centerline chip click adds no entity; Ctrl+Z then Ctrl+Shift+Z adds no phantom line (entity count identical before / after).
- A9b: `Extrude Up To Surface 10.0000 mm`; no pad lines over the body; `_pose` equals the pose taken before the pencil (±5 px equivalent: `_pose_close`).

**S4 (chunk 4)**
- A16: keys `1`, `2`, `4`, `6`, `7`, `8`, `3` print `Front view`, `Right view`, `Back view`, `Left view`, `Isometric view`, `Bottom view`, `Top view`; the menu-bar View popup lists seven Orientation items.
- N10: with two regions and chip `2` hovered `contour_highlight_state()["fills"][1] - ["fills"][0] >= 0.45`.

**S5 (chunk 5)**
- N2: Enter in strip `R` / panel Radius leaves `ctx.main.ops_panel._pending == OpsPanel.Pending.FILLET` (still armed) and adds **no** fillet feature; the viewport Enter adds one and prints `Fillet 2 edges 10.00 applied — View ▸ Timeline to edit parameters`.
- N16: nothing selected; key `0` → `No view for key 0 — use 1 2 3 4 6 7 8`; one motion onto the body, then wait 3.0 s with **no** further events: the label begins `Face — ` or `Body — ` or `Edge — `. Second run: motion off the body during the hold: the label stays `No view for key 0 …` at 3.0 s.
- N23: Timeline on, body selected: `timeline.get_global_rect().intersects(interaction.selection_strip_global_rect())` is false, both inside the window rect; after Esc the Timeline top equals `ChromeDock.top_inset` (±1).

**S6 (chunk 6, with S7 / S8 as they are)**
- A13: with the Timeline Distance preview at 14 the preview mesh has a pivot-hole: the previewed solid's triangle count is within 5 % of the committed 14 mm solid (read both through the accessors `run_rung01_preview_rebuild.gd` uses).
- N8b: after `Opened <path>`, with one motion onto the body, 3.0 s later the label is a hover hint (same prefixes as N16).
- L9 / A14: centre click, then pointer at 20 / 70 / 110 degrees: every preview vertex lies on the circle through the pointer (±0.05 mm), status `Polygon AF <√3·d, 4 decimals> — flats horizontal — click to place (or type the size)`; then Escape and the typed `20` Enter path still gives `Polygon AF 20.0000 — flats horizontal`; nut checker 7/7.

If an accessor named above does not exist on `main` (WP authors may have chosen another name), use the one WP1–WP4's own test uses; the **assertion** is the contract, the accessor is not.

## Step 3b: re-run the polygon suites WP5 left red

After WP2 and WP3 are merged, run `run_rung01_replan2_commit.gd`, `run_rung01_replan2_pointer.gd` and `run_rung01_replan3_input.gd`. All three must be green. If `second press 40px away creates the hex` or `polygon is committed` is still red, set `SX_INPUT_TRACE=1` and read the `[input-trace]` line of the second press: `drop:dim-label` means WP3's halo rule is incomplete (fix it there); a `Too small` status means the test's 40 px is under `MIN_SEGMENT_MM` at its zoom (fix the test's distance). Anything else: classify as product or stale and fix; do not re-tier these into `known-red`.

## Final gates (run in this order, paste each result in the PR body)

1. `tools/godot/godot --headless --path game --script tests/run_rung01_replan17_walk.gd` → `0 failures`, `WALK-SUMMARY stages=8 first_red=none`, checker lines for blank 5/5, wrench 28/28, thick 7/7, nut 7/7.
2. `tools/godot/godot --headless --path game --script tests/run_rung01_replan16_walk.gd` and `tests/run_rung01_wrench.gd` (0 failures, >= 729 checks).
3. `python3 tools/lint_rung01_e2e.py` (prints `<n> replan17 scripts are clean`, n >= 6: glyphs, tools, input, chrome, walk and any extra a WP added), `python3 tools/lint_suites.py` (`<n> suites ok`), `python3 tools/test_lint_suites.py`.
4. `make test-godot` → `suites: <n> run, 0 failed` (WP5 made the full tier green; `make test-godot-known-red` prints the remaining reasons and exits 0).
5. `docs/plan/STATUS.md` is **not** edited. Paste the run times of gates 1 and 4 in the PR body.

## Acceptance (exact)

- `run_rung01_replan17_walk.gd`: `N checks, 0 failures`, `WALK-SUMMARY stages=8 first_red=none`.
- The `sketch 3` assertion fails on a build where the Timeline names by a monotonically increasing counter (prove it once by temporarily making the assertion expect `sketch 4`; do not commit that).
- Registered by `packaging/ci/suites.d/rung01_replan17_walk.suite`.

## Rows unblocked

All 69 sx-038 rows have a headless twin; A15 (gates 1–4), A8b (`sketch 3`), N22–N26.
