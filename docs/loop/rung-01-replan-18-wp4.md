# Rung 1 replan 18 — WP4: dimension labels settle on every layout path (product fix, one line)

Status: planned. Plan: [`rung-01-replan-18.md`](rung-01-replan-18.md). Next walk: **sx-039** (the checklist embedded in the plan). Baseline: `main` `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed` (re-PLAN 17 complete plus the spin-outs #216–#225).

Start from `main`. Open one PR. Stay until quick CI (linux kernel, godot-smoke, website-demos) is green. Never wait for `macos-kernel` or `windows-export`. Do not edit `docs/plan/STATUS.md`. This WP is independent of the other WPs of the plan: start it now.

Triage items covered: **T6** (full-tier red `run_rung01_replan14_savelabels`). Walk rows unblocked: N1a, N21, N26, L8 (Save never moves labels), A15.

## Rules for every BUILD agent (read first)

- **Repository:** `github.com/solidexpress/solidexpress` only. Never the `snadrus` fork. Do not touch PR #11.
- **Model / start:** grok-4.7, medium effort. Start from `main` (`starting_ref` = the full 40-character sha of `main` at launch; the plan was written against `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed`). If `main` has moved, say so in the PR body and carry on from the new tip. Function names below are stable; line numbers are not quoted.
- **One PR per WP, to `main`.** Open it **ready for review** (not draft). Never merge it yourself. Stay with the PR until quick CI is green: **linux kernel, godot-smoke, website-demos**. **Never wait for `macos-kernel` or `windows-export`.**
- **Do NOT edit `docs/plan/STATUS.md`** (take `main`'s version on any conflict). Put your notes (what changed, red-first output, skipped items with the reason) in the **PR body**.
- **Reproduce first.** Run the named suite(s) on the starting ref **before** any edit and paste the real output (the `FAIL -` lines) in the PR body. If a suite that the plan says is red is already green, stop, say so, change nothing, and open no PR.
- **Tests are real input.** Setup (placing geometry, entering a sketch, adding entities) may use the document / sketch API and `tests/lib/film_ui.gd`. Every press, key, motion and wheel **under test** is a real `InputEventMouseButton` / `InputEventMouseMotion` / `InputEventKey` pushed with `Viewport.push_input`. Forbidden on a path under test (the e2e lint fails the PR for `run_rung01_replan16_*` and later): `select_entity`, `.text =`, `.value =`, `.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =` / `.pitch =` / `.basis =`. Boot at 1280x800 (`FilmUI.ensure_test_viewport(ctx, Vector2i(1280, 800))`).
- **Register a suite** only by adding one new file `packaging/ci/suites.d/<name>.suite` (`<name>` = script basename without `run_` and `.gd`; keys `script=tests/<file>.gd`, `tier=ci|full`, optional `timeout=<s>`). **Never edit** `packaging/ci/run_godot_suites.sh`, `packaging/ci/run_suites.sh`, the Makefile `test-godot` recipe, `tools/lint_rung01_e2e.py` or `AGENTS.md`. Do not commit `.gd.uid` files.
- **Run suites one at a time** with `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` (and `DISPLAY=:1` for X11 suites): `tools/godot/godot --headless --path game --script tests/<file>.gd`. A suite passes when it prints `<n> checks, 0 failures` (films: `65 films, 0 failures`).
- **Before opening the PR run, one at a time:** the suites your WP names; `python3 tools/lint_rung01_e2e.py`; `python3 tools/lint_suites.py`; and the "Also run" list of your WP. Paste the last line of each in the PR body.
- **Never** pass `user://` or `res://` into GDExtension C++ (`SxDocument` / kernel I/O); `ProjectSettings.globalize_path(...)` first.
- **Parallel-safe edits.** The other WPs of this plan run at the same time on the same `main`. Edit **only** the files and functions your WP names. No reformatting, no moved code, no renames, no new status strings, no new top-of-file constants.
- **No design decisions are left to you.** Every choice is in the `Decisions` section of your WP. If the code on `main` contradicts a stated fact, stop, say so in the PR body, and implement the closest reading of the decision.

## Why

`run_rung01_replan14_savelabels` is red on `main` (6 failures: `after Ctrl+S rect '20' / '22.5' / '45°' within 1 px` and the same three after Save As; the labels move by 5.17 / 6.00 / 5.17 px). Bisect: green at `f263dce`, red at `dec9fb0` (#222, which added the 12 px label-to-glyph gap `GLYPH_LABEL_GAP_PX` and `_open_label_glyph_gap`). **Root cause (measured on the PLAN box):** two code paths lay labels out against **different glyph positions**.

- `SketchMode._rebuild_dimension_labels` calls `_rebuild_constraint_glyphs()` first and **then** `_resolve_label_overlaps()`: labels see the current glyphs.
- `SketchMode._on_sketch_camera_moved` (runs on every zoom / fit / pan) calls `_resolve_label_overlaps()` first and rebuilds the glyphs **after**: labels see the glyphs of the previous layout.

After a zoom the labels sit at the camera-path layout. The next `_redraw()` (any Save, selection change or edit) re-lays them out the other way and they jump: `label_clamp` for `45°` went `(7.516, 0.0)` → `(10.748, 0.0)`, for `22.5` `(−37.375, 38.003)` → `(−37.375, 34.253)`, for `20` `(88.608, 0.0)` → `(91.840, 0.0)`. The user sees dimension numbers shift a few pixels when they press Ctrl+S. A second `_redraw()` changes nothing, so the layout is a fixed point once both paths agree.

## Decisions (final)

1. **Make the camera path do what the redraw path does:** rebuild the glyphs **before** resolving the label overlaps. One added line in `_on_sketch_camera_moved`; nothing else.
2. **Files you may edit:** `game/scripts/sketch_mode.gd`, **only** the function `_on_sketch_camera_moved`. No other file, no new test (`run_rung01_replan14_savelabels` is the pin: 229 checks).
3. Apply this diff exactly (applied and verified on the PLAN box: `run_rung01_replan14_savelabels` `229 checks, 0 failures`):

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index 505a71e..71f3a46 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -763,6 +763,7 @@ func _on_sketch_camera_moved() -> void:
 		return
 	var hold := _label_restack_hold != 0 and _label_restack_hold == _camera_reassert_gen
 	if not hold and not dimensions.is_empty() and _dimension_labels != null:
+		_rebuild_constraint_glyphs()
 		_resolve_label_overlaps()
 		var li := 0
 		for dim in dimensions:
```

## Acceptance (exact)

- `tests/run_rung01_replan14_savelabels.gd`: before `229 checks, 6 failures`; after `229 checks, 0 failures`.
- Each `0 failures` before **and** after (these pin the glyph / label layout the same code builds): `tests/run_rung01_replan17_n21.gd`, `tests/run_rung01_replan17_glyphs.gd`, `tests/run_rung01_replan17_walk.gd` (`WALK-SUMMARY stages=8 first_red=none`), `tests/run_rung01_sx038_sketch.gd`, `tests/run_rung01_replan16_sketchvis.gd`, `tests/run_rung01_replan12_labels.gd`, `tests/run_rung01_jaw_label_hit.gd`.
- Run the **full tier once** at the end (`KEEP_GOING=1 GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --tier full --keep-going`) and paste the final `suites: <n> run, <k> failed` line and the failing suite names. Allowed failing suites on your branch: only those that WP2 and WP3 own (`run_film_manifest_smoke`, `run_rung01_replan11_ux`, `run_rung01_replan15_extrude`, `run_rung01_replan14_undo`). Anything else red: stop and say so.

## Rows unblocked

N1a, N21, N26 (labels and glyphs measured after Save), L8, A15.
