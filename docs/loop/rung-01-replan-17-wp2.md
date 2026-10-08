# Rung 1 replan 17 — WP2: sketch tool behaviour — Jaw preview shape, Polygon pointer on a vertex, DOF chip after undo

Status: planned. Plan: [`rung-01-replan-17.md`](rung-01-replan-17.md). Next walk: [`rung-01-replan-17-checklist.md`](rung-01-replan-17-checklist.md) (sx-038). Baseline: `main` `1a1cc6ac40303fb747bd2a14d8e8ec98f1d5f705`.

Triage items fixed: **T2** (A8 Jaw preview is lines, not the jaw shape), **T9** (Polygon vertex not under the pointer), **T6** (DOF chip stale after `Undo: Jaw`). Walk rows unblocked: **A8, N5, N25 (new), L9, A14**.

Files you may edit: `game/scripts/sketch_mode.gd` (functions named below only), `game/scripts/main.gd` (**only** `_on_sketch_solve`), new `game/tests/run_rung01_replan17_tools.gd`, new `packaging/ci/suites.d/rung01_replan17_tools.suite`, and the existing polygon suites listed in Step 8 (expectation edits only).
Do not edit (other WPs): `viewport_interaction.gd`, `sketch_context_chrome.gd`, `main.gd` anything but `_on_sketch_solve`; in `sketch_mode.gd` leave `_ref_pos`, `_constraint_anchor`, `_rebuild_constraint_glyphs`, `_separate_glyph_screen`, `_glyph_block_score`, `_label_rect_hits`, `_redraw_contour_highlight`, `CONTOUR_*` (WP1) and the `select_all_entities` neighbourhood (WP3).

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

- **Jaw preview.** `_append_jaw_preview(im, tip)` (`sketch_mode.gd` ~7675): after click 1 it draws **one segment** `ctr -> tip`; after click 2 it draws the rotated rectangle with `half_w = |(tip - ctr) . nrm|`. In the walk (A8) the walker repeats click 2 at the same pixel, so the pointer is on the axis, `half_w = 0`, and the rectangle collapses to a doubled line. Result: "rotated lines, not the jaw shape". Commit (`_click_rect`, variant `"center_three_point"`, ~4746) builds the same 4-line rectangle; `JAW_ZERO_WIDTH` refuses a width below `MIN_SEGMENT_MM`.
- **Polygon.** `_polygon_ring_vertices(c, tip)` (~7727): for `across_flats` the pointer distance `drag = |tip - c|` **is the across-flats size** and the circumradius is `drag / sqrt(3)`; vertices start at angle 0. The pointer is therefore 1.73x farther from the centre than any vertex (never under a vertex). Typed size goes through `commit_at_length` -> `set_length_override` -> `effective_hover()` (~1793, tip = last + dir * AF) and in `click()` (~4520) the `_length_override` block rewrites `pos2` the same way (`_point_from_length = true`).
- **DOF chip.** `_restore_undo_entry` (~1117) restores the snapshot and calls `_redraw()` but never `run_solve()` (~5260), so `last_dofs`, `last_solve_status` and the `dof_label` (`main.gd` `_on_sketch_solve` ~1156) keep the pre-undo values (`3` on an empty sketch). `run_infer_tests.gd` `test_dof_chip_and_hint` does not cover undo (its known failure is a different row).

## Decisions (final)

1. **Jaw preview draws the committed shape at every stage.** Stage 1 (one point set): rotated rectangle with long axis `ctr -> tip`, `half_len = |tip - ctr|`, `half_w = JAW_PREVIEW_ASPECT * half_len`, `const JAW_PREVIEW_ASPECT := 0.4`. Stage 2 (two points set): the existing rectangle, with `half_w = max(|(tip-ctr).nrm|, JAW_PREVIEW_MIN_HALF_W_MM)`, `const JAW_PREVIEW_MIN_HALF_W_MM := 1.5`, so a pointer on the axis still shows a thin **rectangle** (4 edges, two across) instead of a doubled line. Commit and `JAW_ZERO_WIDTH` are unchanged (a click 3 below `MIN_SEGMENT_MM` is still refused). No new status strings.
2. **Polygon: the pointer sits on the circumscribed circle** (a vertex lies at the pointer's distance from the centre). Across flats stays flats-horizontal (start angle 0). For a **pointer** click or hover, `AF = sqrt(3) * |pointer - centre|`; for a **typed** size `AF` is the typed number (unchanged, so the nut `AF 20` is unchanged). Implemented by mapping the pointer to an "AF tip" `c + (p - c) * sqrt(3.0)` before `_polygon_ring_vertices` sees it. The `vertex` variant is unchanged (pointer is the vertex already).
3. **Status strings stay verbatim.** Hover (one point down, across flats): `Polygon AF %.4f — flats horizontal — click to place (or type the size)` where `%.4f` is the new AF (`sqrt(3) * distance`). Commit: `Polygon AF %.4f — flats horizontal`. Initial: `Polygon — click the centre, then a vertex (or type the size)`.
4. **DOF chip always reflects the live sketch.** After an undo/redo restore: non-empty sketch -> `run_solve()`; empty sketch -> `last_dofs = -1`, `last_solve_status = ""`, `solve_updated.emit(-1, "", 0)`, and `_on_sketch_solve` shows `—` (the text a fresh sketch shows) for `dofs < 0`.

## Steps

1. **Constants** (own block next to `JAW_HINT`, ~1864): `const JAW_PREVIEW_ASPECT := 0.4`, `const JAW_PREVIEW_MIN_HALF_W_MM := 1.5`.
2. **`_append_jaw_preview`** — replace the body:
```gdscript
func _append_jaw_preview(im: ImmediateMesh, tip: Vector2) -> void:
	if _tool_points.is_empty():
		return
	var ctr: Vector2 = _tool_points[0]
	var along: Vector2
	var half_w: float
	if _tool_points.size() == 1:
		along = tip - ctr
		if along.length() <= 1e-6:
			return
		half_w = along.length() * JAW_PREVIEW_ASPECT
	else:
		along = _tool_points[1] - ctr
		if along.length() <= 1e-6:
			_append_preview_seg(im, ctr, tip)
			return
		var n0 := Vector2(-along.y, along.x).normalized()
		half_w = maxf(absf((tip - ctr).dot(n0)), JAW_PREVIEW_MIN_HALF_W_MM)
	var dir := along.normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var u := dir * along.length()
	var v := nrm * half_w
	var ra := ctr - u - v
	var rb := ctr + u - v
	var rc := ctr + u + v
	var rd := ctr - u + v
	_append_preview_seg(im, ra, rb)
	_append_preview_seg(im, rb, rc)
	_append_preview_seg(im, rc, rd)
	_append_preview_seg(im, rd, ra)
```
3. **Polygon helper** (new, next to `_polygon_ring_vertices`):
```gdscript
## Pointer -> the across-flats "tip" `_polygon_ring_vertices` expects: its
## distance from the centre is the AF, so the circumscribed circle passes
## through the pointer. A typed length bypasses this (effective_hover()).
func _polygon_pointer_tip(c: Vector2, p: Vector2) -> Vector2:
	if tool_variant != "across_flats":
		return p
	return c + (p - c) * sqrt(3.0)
```
4. **Use it in exactly three places**, only when `_tool_points.size() == 1` and the position is a pointer (not typed):
   - `effective_hover()`: in the `_length_override < 0.0 or not has_single_dof_preview()` early return, return `_polygon_pointer_tip(_tool_points[0], _hover)` when `tool == Tool.POLYGON and _tool_points.size() == 1`, else `_hover`. The preview (`_update_preview`, `Tool.POLYGON` branch ~7817) and the hover status both read `effective_hover()` / the same tip, so both follow. In `hover()` (~6342) compute `af` from `effective_hover()` (it already does `distance_to(effective_hover())`); it now prints the new AF.
   - `click()`: after the `_length_override` block (which sets `_point_from_length = true`), add `elif tool == Tool.POLYGON and _tool_points.size() == 1 and not _point_from_length: pos2 = _polygon_pointer_tip(_tool_points[0], pos2)`.
   - `preview_distance()` (~1709): when `tool == Tool.POLYGON and tool_variant == "across_flats"` and `_length_override < 0.0`, return `_tool_points[0].distance_to(_polygon_pointer_tip(_tool_points[0], _hover))` so the dimension blank shows the same AF as the status.
   - Nothing in `commit_at_length`, `set_length_override` or the typed path changes.
5. **`_restore_undo_entry`**: after `dimensions = dims.duplicate(true)` and the selection/drag resets, before `_redraw()`:
```gdscript
	if sketch.entity_ids().is_empty():
		last_dofs = -1
		last_solve_status = ""
		solve_updated.emit(-1, "", 0)
	else:
		run_solve()
```
   (`_undo_restoring` is still `true`, so no undo entry is captured; `_undo_head` is taken after, as today.)
6. **`main.gd` `_on_sketch_solve`**: first branch `if dofs < 0: dof_label.text = "—"; dof_label.remove_theme_color_override("font_color"); _on_sketch_selection_chips(); return`.
7. **Walk-through checks to keep**: `Jaw — width is zero — click 3 again for half the width`, `Jaw committed — width …, long side …° — click a label to edit it`, nut `Polygon AF 20.0000 — flats horizontal`, `Circle r=5.0000 (Ø10.0000)`.
8. **Existing suites that click a polygon with the pointer** and assert an AF or vertex positions (`grep -n "Polygon AF\|_polygon\|POLYGON" game/tests/*.gd`): `run_rung01_replan11_poly.gd`, `run_rung01_replan16_sketchvis.gd` (`POLY_LIVE` / `POLY_COMMIT`), `run_rung01_replan16_walk.gd` (L9), `run_rung01_replan5_smartdim.gd`, `run_rung01_replan13_typed.gd`, `run_rung01_sx036_fields.gd`, `run_rung01_sx037_fields.gd`, `run_rung01_replan16_fields.gd`, `run_rung01_wrench.gd`, and the three that are red on `main` for this reason: `run_rung01_replan2_commit.gd` (`hex vertices for AF 10.4380`), `run_rung01_replan2_pointer.gd` (`second press 40px away creates the hex`), `run_rung01_replan3_input.gd` (only `polygon is committed (preview off, points=1)`; its two Distance rows belong to WP5 and are fixed in product code). Update **only** expectations that derive AF from a pointer distance (new AF = `sqrt(3)` x distance); typed-size expectations stay. For those three, read the failing check; if the cause is this semantics fix the expectation to the new rule and say so in the PR; if it is not (for example the 40 px press is below the minimum polygon size), fix the real cause and say so. WP5 does not touch them.

## Acceptance (exact)

- New suite `run_rung01_replan17_tools.gd`, `tier=ci`, `N checks, 0 failures`:
  - J1 Jaw click 1 then pointer moves: the preview has exactly 4 segments, none axis-aligned for a 37 degree axis, and `ctr` is the rectangle centre (`_preview_segs` helper as in `run_rung01_replan12_jaw.gd`).
  - J2 Jaw click 1, click 2, pointer **on the axis** (same pixel as click 2): 4 segments, two parallel to the axis and two across (`|sdir . nrm| > 0.97`), length across `== 2 * JAW_PREVIEW_MIN_HALF_W_MM` (+-0.05). Repeat click 2 still prints `Jaw — width is zero — click 3 again for half the width`, entity count unchanged, then a real click 3 commits `Jaw committed — width …`.
  - P1 Polygon (across flats) centre click, pointer at distances 20, 30, 40 mm and bearings 20, 70, 110 degrees: every preview vertex lies on the circle of radius `|pointer - centre|` (+-0.05 mm); one vertex is at bearing 0; hover status is `Polygon AF <sqrt(3)*d to 4 decimals> — flats horizontal — click to place (or type the size)`; second click commits `Polygon AF <same 4 decimals> — flats horizontal`; the committed shape has horizontal flats (`horizontal` constraints on the two flat edges).
  - P2 Typed `20` Enter after the centre click commits `Polygon AF 20.0000 — flats horizontal` and the hex across flats measures 20.000 +-0.01 (nut path unchanged).
  - D1 draw a Line (`add` via real clicks), Ctrl+Z (`Undo: Line`... whatever the status is) until `Nothing to undo`: `main.dof_label.text == "—"`; Ctrl+Shift+Z: the chip equals `sm.last_dofs` formatted (`%d`, `OK` or `!`). Repeat with a Jaw: `Undo: Jaw` -> `—`; `Redo: Jaw` -> same text as before the undo.
- `run_rung01_replan12_jaw.gd`, `run_rung01_replan12_status.gd`, `run_rung01_replan15_jawstub.gd`, `run_rung01_replan16_walk.gd` (L9 + nut), `run_rung01_wrench.gd` green. `run_rung01_replan14_undo.gd` is red on `main` (2 checks, WP5 owns it): your PR must not add a third failing check there.

## Also run

`run_rung01_replan12_jaw.gd`, `run_rung01_replan11_poly.gd`, `run_rung01_replan16_sketchvis.gd`, `run_rung01_replan16_fields.gd`, `run_rung01_replan14_undo.gd` (red on `main` for a different reason: WP5 owns it; do not make it worse), `run_infer_tests.gd`, `run_sketch_tools_tests.gd`, `run_rung01_sx037_fields.gd`.

## Rows unblocked

A8 (preview is the shape; no lines), N5 / **N25** (DOF chip after `Undo: Jaw`), L9 (preview radius follows the pointer, vertex on the pointer circle), A14 (nut path unchanged), checklist note: polygon pointer AF is `sqrt(3) x` the pointer distance.
