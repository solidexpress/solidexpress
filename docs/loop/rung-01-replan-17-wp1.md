# Rung 1 replan 17 — WP1: constraint glyphs sit on their geometry; stronger hovered contour fill

Status: planned. Plan: [`rung-01-replan-17.md`](rung-01-replan-17.md). Next walk: [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md) (sx-038). Baseline: `main` `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`.

Triage items fixed: **T7** (glyphs off their vertices, one off-part below the shaft, `5` label touching an `H`) and **T5** (N10 hovered contour fill too weak). Walk rows unblocked: **N21, N26 (new), N1a, N10, L6**.

Files you may edit: `game/scripts/sketch_mode.gd` (functions named below only), `game/tests/run_rung01_replan15_contours.gd` (alpha expectations only), new `game/tests/run_rung01_replan17_glyphs.gd`, new `packaging/ci/suites.d/rung01_replan17_glyphs.suite`.
Files you must not edit (other WPs own them): `viewport_interaction.gd`, `main.gd`, `sketch_context_chrome.gd`, and in `sketch_mode.gd` anything outside the functions below (WP2 owns `_append_jaw_preview`, `_polygon_ring_vertices`, `effective_hover`, `click` Polygon branch, `hover`, `_restore_undo_entry`; WP3 owns a new `select_in_screen_rect` block placed after `select_all_entities`).

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

## Why (verified on `main` 1a1cc6a)

- `_ref_pos` (`sketch_mode.gd` ~7342) returns `info["center"]` for **every** circle/arc ref, ignoring `role` `start`/`end`. A coincident between an arc end and a line end therefore anchors at the mean of the line end and the arc **centre**.
- `_constraint_anchor` (~7363) anchors every multi-ref relation at the **mean of the ref positions**. A `tangent` between a shaft line (`role self` = line midpoint) and a circle (`role self` = centre) lands halfway between the line middle and the circle centre: inside the head, or below the shaft ("off the part"). `parallel`/`equal`/`perpendicular` between two far-apart lines land in empty space.
- `_rebuild_constraint_glyphs` (~7387) de-stacks with `_separate_glyph_screen` (~7298): 16 rings, step = glyph size + 2 px, **no cap**, so a glyph can end 300+ px from its anchor, and there is **no leader**.
- Label-vs-glyph tests use `Rect2.intersects` (`_glyph_block_score` ~7273, `_label_rect_hits` ~7072). Rects that merely touch do not intersect, and the drawn glyph is wider than its rect, so `5` (full-circle radius label, never stacked: `_full_circle_dimension` branch in `_resolve_label_overlaps`) visibly touches an `H`.
- `CONTOUR_FILL_ALPHA 0.28` vs `CONTOUR_FOCUS_ALPHA 0.50` (~4264) read as the same tint on soft GL. `_redraw_contour_highlight` (~4324) adds one inset outline (0.35 mm) on the focused region.

## Decisions (final)

1. **Anchor on the geometry.** `_ref_pos` for `arc` with role `start`/`end` returns `info["start"]` / `info["end"]` (the kernel already supplies both as `Vector2`); circle/arc with any other role stays `info["center"]`.
2. **Per-type anchor** in `_constraint_anchor`: `horizontal`, `vertical`: unchanged (line midpoint + 2.5 mm perpendicular). `coincident`: mean of refs (unchanged). `point_on_line`: `_ref_pos(refs[0])` (the point). `tangent`: the **contact point** = foot of the perpendicular from the circle/arc centre on the line, clamped to the segment (helper below). `parallel`, `perpendicular`, `equal`: `_ref_pos(refs[0])`, plus the same 2.5 mm perpendicular nudge when `refs[0]` is a line. Any other type with a glyph keeps the mean.
3. **Cap and leader.** New consts (in your own block next to `GLYPH_SYMBOLS`): `GLYPH_MAX_OFFSET_PX := 40.0`, `GLYPH_LEADER_MIN_PX := 12.0`, `GLYPH_LABEL_GAP_PX := 4.0`. `_separate_glyph_screen` only considers candidates whose centre is within `GLYPH_MAX_OFFSET_PX` of `natural` (rings stop at `floori(GLYPH_MAX_OFFSET_PX / step)`); if every candidate collides, return the lowest-score one inside the cap. When the final offset is `>= GLYPH_LEADER_MIN_PX` a 1 px leader line is drawn from the true anchor to the glyph.
4. **Gap.** `_glyph_block_score` inflates each label rect by `GLYPH_LABEL_GAP_PX` (`lr.grow(GLYPH_LABEL_GAP_PX)`) before `intersects`; `_label_rect_hits` inflates each glyph rect the same way. Labels keep their current placement rules (full-circle and slot-cap radius labels are still never stacked); the **glyph yields**.
5. **N10 fill.** `CONTOUR_FILL_ALPHA := 0.20`, `CONTOUR_FOCUS_ALPHA := 0.70`. A focused region draws its outline at the outline plus two insets (0.35 mm and 0.70 mm). Included = light fill, hovered = strong fill, skipped = outline only (unchanged).

## Steps

1. **`_ref_pos`**: add before the existing circle/arc branch
```gdscript
		"arc":
			if role == "start" and info.has("start"):
				return info["start"]
			if role == "end" and info.has("end"):
				return info["end"]
			return info["center"]
		"circle":
			return info["center"]
```
(replace the combined `"circle", "arc"` match arm).
2. **Helper** (new, after `_constraint_anchor`):
```gdscript
func _tangent_contact(line: Dictionary, circ: Dictionary) -> Variant:
	var a: Vector2 = line["start"]
	var ab: Vector2 = (line["end"] as Vector2) - a
	if ab.length_squared() < 1e-12:
		return null
	var c: Vector2 = circ["center"]
	var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t
```
3. **`_constraint_anchor`**: after reading `refs`, `match str(cinfo.get("type", ""))`: `"tangent"` → find the ref whose entity is a `line` and the ref whose entity is `circle`/`arc` (`sketch.entity_info`), return `_tangent_contact(line_info, circ_info)` (fall back to the mean when either is missing); `"point_on_line"` → `_ref_pos(refs[0])`; `"parallel"|"perpendicular"|"equal"` → `_ref_pos(refs[0])` plus `Vector2(-d.y, d.x).normalized() * 2.5` when that entity is a line (`d = end - start`). Keep the existing mean / single-line code for everything else.
4. **`_separate_glyph_screen`**: add `var max_ring := maxi(1, floori(GLYPH_MAX_OFFSET_PX / step))` and loop `for ring in range(max_ring + 1)`; compute candidates as today. Return `best` (lowest score) when the loop ends.
5. **`_glyph_block_score`**: `for lr in labels: var lg := lr.grow(GLYPH_LABEL_GAP_PX); if rect.intersects(lg): var inter := rect.intersection(lg) ...`.
6. **`_label_rect_hits`**: compare against `gr.grow(GLYPH_LABEL_GAP_PX)`.
7. **`_rebuild_constraint_glyphs`**: record `natural` (screen) and `centre` (screen) for each glyph; store `{"cid", "pos", "type", "anchor": <sketch pos before de-stack>, "offset_px": natural.distance_to(centre)}` in `_glyph_anchors`. After the loop, when any `offset_px >= GLYPH_LEADER_MIN_PX`, add one child `MeshInstance3D` named `GlyphLeaders` to `_constraint_glyphs` with an `ImmediateMesh` (`PRIMITIVE_LINES`, unshaded vertex-colour material, `COLOR_GLYPH` at alpha 0.6) holding one segment `_to3(anchor)` -> `_to3(pos)` per such glyph. Free it with the other children (the existing `while get_child_count() > 0` loop already does).
8. **New accessor** `glyph_debug() -> Array` returning `[{ "cid": String, "type": String, "offset_px": float, "leader": bool, "anchor": Vector2, "pos": Vector2 }, ...]` from `_glyph_anchors`.
9. **N10**: set the two consts; in `_redraw_contour_highlight` focused block add `_inset_loop(outer, 0.70)` (and holes) outlines after the 0.35 ones; bump nothing else. Update `run_rung01_replan15_contours.gd` A2 expectations (`fills[focus] ~ 0.70`, other `~ 0.20`).

## Acceptance (exact)

- New suite `run_rung01_replan17_glyphs.gd`, `tier=ci`, prints `N checks, 0 failures`:
  - G1: arc with a coincident to a line end: `sm._constraint_anchor(sm.sketch.constraint_info(cid))` equals the arc `start` (or `end`) within 1e-6 mm (was the mean with the centre).
  - G2: head circle r 22.5 + pivot circle r 10 + `shaft_lines_selected()` (both circles selected, same setup as `run_rung01_replan16_sketchvis.gd`): for every `tangent` constraint the anchor lies within 0.05 mm of the line and within 0.05 mm of the circle rim (`absf(anchor.distance_to(center) - r) < 0.05`).
  - G3: at ~150 px per Ø45 head (zoom as in `run_rung01_replan16_sketchvis.gd` V1) every entry of `glyph_debug()` has `offset_px <= GLYPH_MAX_OFFSET_PX + 0.5`; any entry with `offset_px >= GLYPH_LEADER_MIN_PX` has `leader == true`, and a `GlyphLeaders` child exists.
  - G4: no glyph rect from `constraint_glyph_screen_rects()` comes within `GLYPH_LABEL_GAP_PX - 0.5` px of any dimension label rect (`_projected_label_rect`), including the `5` pivot radius label, after a Trim (`Trimmed open jaw`) so `5` and `22.5` exist.
  - G5: with two closed regions and chip `2` hovered, `contour_highlight_state()` has `fills[1] - fills[0] >= 0.45`, `fills` of a skipped region `== 0.0`, `tag == "2"`.
- `run_rung01_replan16_sketchvis.gd`, `run_rung01_replan14_savelabels.gd`, `run_rung01_jaw_label_hit.gd`, `run_rung01_replan12_labels.gd`, `run_sketch_tools_tests.gd`, `run_rung01_replan15_contours.gd`, `run_rung01_replan15_jawstub.gd`, `run_rung01_wrench.gd` stay green.
- No status string changes.

## Also run

`run_rung01_replan16_sketchvis.gd`, `run_rung01_replan15_shaftbadges.gd`, `run_rung01_replan15_contours.gd`, `run_rung01_jaw_label_hit.gd`, `run_rung01_replan14_savelabels.gd`, `run_rung01_replan12_labels.gd`, `run_sketch_tools_tests.gd`, `run_infer_tests.gd` (its one known DOF-chip failure stays as is).

## Rows unblocked

N21 (glyphs spread and on their geometry), **N26** (new: tangent / coincident badge within 40 px of its vertex; `5` clear of every `H`), N1a (labels not under glyphs), N10 (hover fill clearly stronger), L6.
