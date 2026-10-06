# Replan 14 WP1 — saving never changes the dimension labels; labels clear of the glyphs; no Δ overlay under an open editor

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = the full 40-character sha of `main` at launch time). Edit only `game/scripts/sketch_mode.gd` (the hunks below), `game/scripts/main.gd` (`_save_current` only), `game/scripts/viewport_interaction.gd` (one guard in `_update_sketch_measure`) and add `game/tests/run_rung01_replan14_savelabels.gd`. Read [`rung-01-replan-14.md`](rung-01-replan-14.md) and [`rung-01-leftovers-sx034.md`](rung-01-leftovers-sx034.md) (items 1, 13, 17) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable.

Hunks you own (search by name; line numbers are `305dcbff`):

| File | Hunk |
|---|---|
| `sketch_mode.gd` | `_restore_dimensions_from_sketch` (~4914), `_rebuild_dimension_labels` (~5341), `_dimension_label_pos2` / `_dimension_label_rect` / `_dimension_label_size_px` (~5248–5335), `_rebuild_constraint_glyphs` / `_constraint_anchor` (~5390–5470), `dimension_hit` (read-only, to keep hit-testing in step), new public helpers `dimension_label_screen_rects()` and `constraint_glyph_screen_rects()` |
| `main.gd` | `_save_current` (~3293): only if the fix needs it (see decision 1) |
| `viewport_interaction.gd` | `_update_sketch_measure` (~2893): one early-return guard for item 17 |

Do **not** touch the Slot code (#151), `_trim_open_jaw` (replan 13 WP2), the Jaw click path (#148) or anything in `ops_panel.gd` / the strip radius (#152).

## The bugs (sx-034 A9c / L4 notes; leftovers 1, 13, 17)

**Item 1 — Save As inside a sketch adds labels (blocks-pass).** Before File → Save As the jaw sketch has exactly one `20` and one `45°`. After it (`Saved …/pre-cut.sxp`, sketch still open) there is a second `45°` that overlaps a new `22.5` at the head top, and a `5` at the pivot circle. They persist. A re-verify of L4 ("no overlapping labels") read after A9c fails.

**Item 13 — labels on the glyph cluster.** The jaw width `20` sits on the constraint-glyph cluster at the head centre; the angle label's first glyph is under the ⊥ icon, and rule 27 tells users to click the first glyph.

**Item 17 — Δ overlay while an editor is open.** Select tool, click the angle label (editor opens), hover over it: the Δu / Δv / length measure overlay draws.

## Cause (read on `305dcbff`; **reproduce first**)

- `main.gd` `_save_current`: `exit_sketch()` → `view.save(path)` → `sketch_mode.begin_edit(fid)`. `begin_edit` → `_activate_session` clears `dimensions` and calls `_restore_dimensions_from_sketch`, which appends one record per `distance | radius | diameter | angle` constraint in the kernel sketch (`ids` from the refs, value from the constraint). The live session never had records for the typed circle radii (`5`, `22.5` are `radius` constraints made by the chrome field) and may hold the jaw angle / width twice in the kernel after Trim (the live list holds one record per fact because replan 13 WP2 drops stale ones). So the same sketch yields a different label set live and after a reload — exactly what File → Open shows too.
- `_rebuild_dimension_labels` places labels by `_dimension_label_pos2` (circle radius label at `c + (0.7071 r, 0.7071 r)`, angle label at the line intersection + the bisector offset, distance label at the mid point + a perpendicular offset). Nothing compares label rects with each other or with the constraint glyphs (`_rebuild_constraint_glyphs`).
- The hover overlay: `_update_sketch_measure` runs for the Select tool whenever the pointer moves; it does not know a label editor (`_dim_edit_popup`) is open.

## Decisions (see `rung-01-replan-14.md` 1 and 2)

1. **One builder, one policy.** Extract `_dimension_records_from_sketch() -> Array` (the loop in `_restore_dimensions_from_sketch`) and make it **deduplicate** by `(type, sorted ids, value rounded to 1e-4)`, keeping the first. `_restore_dimensions_from_sketch` calls it. Typed circle radii are labelled **both** live and after a reload: when the chrome field commits a typed radius (the code path that adds the `radius` constraint) it also appends the record through the same builder (`dimensions` is a pure function of the sketch's dimensional constraints; do not persist anything new). Records created by Smart Dim, Jaw and Trim keep their `label_text`, `cid` and drag override fields; the builder merges by `cid` so a rebuild never replaces a record the user positioned.
2. **Save does not rebuild what it can keep.** If `_save_current`'s exit / re-enter cycle can carry the live `dimensions` list across (capture before `exit_sketch()`, re-apply after `begin_edit`, mapping by constraint id), do that and the label set cannot change. If it cannot be done cleanly, decision 1 alone must make the before / after sets identical (that is what the test asserts). Either way **File → Open of the saved file shows the same set** (decision 1 is what guarantees it).
3. **No label rect intersects another label rect or a glyph rect.** After placing labels, resolve overlaps by nudging the **label** (never the glyph) along its `label_stack` axis in `DIM_LABEL_STACK_PX` steps, deterministic (sort by dimension index) so a rebuild gives the same layout. Anchors in the sketch plane stay as they are; the nudge is a pixel offset (`label.offset`) so zoom changes do not reshuffle. `dimension_hit` keeps working on the nudged rect (it already reads `label_stack`).
4. **Public rect helpers for tests and hit-testing.** `dimension_label_screen_rects() -> Array` returns `[{text, rect, index}]` in viewport pixels; `constraint_glyph_screen_rects() -> Array` returns `[{type, rect}]`. Both use the same camera projection and `_dimension_label_rect` the click hit-test uses.
5. **Δ overlay is suppressed while a label editor is open.** `_update_sketch_measure` returns early (and clears a hover pair) when `_dim_edit_owns_keys()`. No other measure behaviour changes (replan 13 WP6: Select tool only).

## Failing-first test — `game/tests/run_rung01_replan14_savelabels.gd` (create)

Template: `run_rung01_replan13_frame.gd` (`_boot`, `FilmUI`) and `run_rung01_replan13_trim.gd` (the jaw build). 1280×800. Setup may use the API; the **Save**, the **label clicks** and the **hover** are real events.

1. Boot; New doc; sketch on XY through `FilmUI.enter_sketch`: Ø20 at the origin, Ø45 at (200, 0), Smart Dim the centres to 200 (`FilmUI.set_sketch_dim` / the dim blank), Shaft Lines, `FilmUI.apply_extrude(ctx, 10)`. Enter a sketch on the top face (`FilmUI.enter_sketch_on_face`).
2. Circle at the origin with a **typed** radius `5` (press the centre, type through the real dim field, Enter), Circle at (200, 0) with typed `22.5`. Jaw with three distinct real clicks (`start_jaw_tool`, as the trim suite does); real clicks on the width label (type `20`, Enter) and the angle label (type `45`, Enter); the along-jaw construction line and the cross-jaw Centerline; real Trim click on the shaft side → `Trimmed open jaw`.
3. Snapshot `before := sm.dimension_label_screen_rects()` (sorted by text) and `glyphs := sm.constraint_glyph_screen_rects()`. Assert: exactly one label `20`, exactly one `45°`, exactly one `5`, exactly one `22.5`; no two label rects intersect; no label rect intersects a glyph rect (item 13). (Red on baseline for the glyph row.)
4. Save: set `main.current_path` to `<globalized temp dir>/pre-cut.sxp` (absolute, via `ProjectSettings.globalize_path`; never `user://`) and press the real `Ctrl+S` key; then once more through File → Save As (menu id 3, type the name with real keys, press OK). After each, `await process_frame` twice; the sketch is still open (`sm.active`), status `Saved <path>`.
5. `after := sm.dimension_label_screen_rects()`: equal to `before` as a sorted multiset of texts, same count, **the rects equal within 1 px** (the layout is deterministic), still no overlaps, still exactly one `20` / `45°`. (Red on baseline: a second `45°`, `22.5`, `5`.)
6. `File → Open` the saved file (`main._open_document(path)`), enter the jaw sketch through the timeline row (`FilmUI.edit_sketch_pad`): the label text multiset equals `before`'s (item 1: reopened file shows the same set).
7. Open a label editor with a real click on the `45°` label (the editor shows), move the pointer over the label with a real motion event: `main.interaction.measure_overlay.has_anchor()` is false and no Δ label exists (item 17). Esc closes the editor; Select tool + hover over a jaw line still shows the ✕ (`has_anchor()` true) — the replan 13 WP6 behaviour is unchanged.

**Expected red** on `305dcbff`: step 3 (glyph overlap), step 5 (extra labels), step 6 (maybe), step 7 (overlay). Record the real counts and the constraint list (`sketch.constraint_ids()` / `constraint_info`) you observe in the PR: which constraints produced the extra `45°`, `22.5` and `5`.

## Commands

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan14_savelabels.gd
for t in run_rung01_replan13_trim run_rung01_replan13_measure run_rung01_replan12_labels run_rung01_replan12_dialog \
         run_rung01_replan11_dim run_rung01_replan11_dimhit run_rung01_replan11_trim; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
python3 tools/lint_rung01_e2e.py
tools/godot/godot --headless --path game --script res://tests/run_rung01_wrench.gd   # alone: 0 failures, nut 7/7, wrench 28/28, thick 7/7, blank 5/5
```

Every count equals the whole-suite table (trim 28/0, measure 76/0, labels 20/0, dialog 3/0 …). If a replan 11 / 12 / 13 assertion counts `dimensions.size()` after a typed circle, update only that assertion (typed circles now carry a record) and say so in the PR.

## Acceptance

- The new suite is green and was red on the starting ref (or the PR says which rows were green and why).
- Save, Save As and Open leave the label multiset and layout unchanged (steps 4–6).
- No label overlaps a label or a glyph at 1280×800 in the item-1 sketch.
- No Δ overlay while a label editor is open; the Select-tool hover ✕ is unchanged.
- Walk 0 failures; replan 13 suites 0 failures; lint clean.
- PR body: items 1, 13, 17 fixed / skipped with reasons, plus the observed constraint dump.

## Do not

- Change what a dimension edit commits or any status string (replan 10–13, #151).
- Persist a new field in the `.sxp` (the label set is derived).
- Move the glyphs or change their colours.
- Edit `ops_panel.gd`, the strip radius, `sketch_context_chrome.gd` or `orbit_camera.gd`.
