# Rung 1 replan 18 — WP3: Ctrl+Z stays with a focused numeric field (product fix, one function)

Status: planned. Plan: [`rung-01-replan-18.md`](rung-01-replan-18.md). Next walk: **sx-039** (the checklist embedded in the plan). Baseline: `main` `f81c1e5491e9e835ec9322ef542dda2ea6aee5ed` (re-PLAN 17 complete plus the spin-outs #216–#225).

Start from `main`. Open one PR. Stay until quick CI (linux kernel, godot-smoke, website-demos) is green. Never wait for `macos-kernel` or `windows-export`. Do not edit `docs/plan/STATUS.md`. This WP is independent of the other WPs of the plan: start it now.

Triage items covered: **T5** (full-tier red `run_rung01_replan14_undo`). Walk rows unblocked: L10, A3, N4 (Ctrl+Z in a field), A15.

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

`run_rung01_replan14_undo` (check `Ctrl+Z in the Radius field does not undo the sketch`, and `focused field does not print Undo: Jaw`) is red on `main`: with the sketch Radius field focused and untouched, Ctrl+Z ran the **sketch undo** and took the whole jaw away (`entities 7→0`, status `Undo: Jaw`). Bisect: green at `0dc693e`, red at `f81c1e5` (#217). #217 changed `ViewportInteraction._shortcut_blocked_by_numeric_edit` so that a focused numeric field that nobody has typed in (`SxUi.mid_entry(line)` is false) lets **every** Ctrl shortcut through, to keep Ctrl+Shift+Z (redo) working in an armed or just-opened field (`run_rung01_sx038_focuskeys` pins that). Redo is the intended change. **Undo is not**: a field the user clicked into owns Ctrl+Z (replan14 test 11, "focused Radius field owns Ctrl+Z"); undoing the geometry from under a number box is data loss the user did not ask for.

## Decisions (final)

1. **Ctrl+Z without Shift stays with a focused numeric field even when it is untouched.** Ctrl+Shift+Z, Ctrl+Y and the other Ctrl keys keep #217's behaviour (they pass to the sketch while the field is untouched; they stay blocked once a digit has landed). A non-numeric `LineEdit` / `TextEdit` / `CodeEdit` stays blocked for every key (unchanged).
2. **Files you may edit:** `game/scripts/viewport_interaction.gd`, **only** the function `_shortcut_blocked_by_numeric_edit` and its three call sites inside `_sketch_input` (the `InputEventKey ... ctrl_pressed` branch) and `_gui_key` (the `KEY_Z` branch; the `KEY_Y` call keeps passing no argument). No other file, no new test.
3. Apply this diff exactly (it was applied and verified on the PLAN box: `run_rung01_replan14_undo` `119 checks, 0 failures`, `run_rung01_sx038_focuskeys` `109 checks, 0 failures`):

```diff
diff --git a/game/scripts/viewport_interaction.gd b/game/scripts/viewport_interaction.gd
index 8c9ab58..abc9e87 100644
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -2834,7 +2834,7 @@ func _sketch_keys_blocked() -> bool:
 
 ## Redo / undo stay with the sketch unless the focused line already has a
 ## typed character. An armed or just-opened field must not swallow Ctrl+Shift+Z.
-func _shortcut_blocked_by_numeric_edit() -> bool:
+func _shortcut_blocked_by_numeric_edit(ke: InputEventKey = null) -> bool:
 	var vp := get_viewport()
 	if vp == null:
 		return false
@@ -2844,7 +2844,9 @@ func _shortcut_blocked_by_numeric_edit() -> bool:
 	if focus is LineEdit:
 		var line := focus as LineEdit
 		if _line_is_tracked_numeric(line):
-			return SxUi.mid_entry(line)
+			if SxUi.mid_entry(line):
+				return true
+			return ke != null and ke.keycode == KEY_Z and not ke.shift_pressed
 		return true
 	if focus is TextEdit or focus is CodeEdit:
 		return true
@@ -3868,7 +3870,7 @@ func _sketch_input(event: InputEvent) -> void:
 			if measure_overlay != null:
 				measure_overlay.update_sketch_hover("", Vector3.ZERO)
 	elif event is InputEventKey and event.pressed and event.ctrl_pressed:
-		if _shortcut_blocked_by_numeric_edit():
+		if _shortcut_blocked_by_numeric_edit(event as InputEventKey):
 			return
 		var ke := event as InputEventKey
 		match ke.keycode:
@@ -4974,7 +4976,7 @@ func _gui_key(event: InputEventKey) -> bool:
 				return true
 		KEY_Z:
 			if event.ctrl_pressed:
-				if _shortcut_blocked_by_numeric_edit():
+				if _shortcut_blocked_by_numeric_edit(event):
 					return false
 				if sketch_mode != null and sketch_mode.active:
 					if event.shift_pressed:
```

## Acceptance (exact)

- `tests/run_rung01_replan14_undo.gd`: before `119 checks, 2 failures`; after `119 checks, 0 failures`.
- `tests/run_rung01_sx038_focuskeys.gd`: `109 checks, 0 failures` before and after (redo in an untouched field still works).
- Also run, each `0 failures`: `tests/run_rung01_replan16_fields.gd`, `tests/run_rung01_sx037_l10.gd`, `tests/run_rung01_sx038_a13.gd`, `tests/run_rung01_sx038_sketch.gd`, `tests/run_rung01_replan15_extrude.gd` (its B1 check is WP2's: it may still print the 3 B1 failures on your branch, say so, nothing else may fail).
- Run the **full tier once** at the end: `KEEP_GOING=1 GODOT_BIN=tools/godot/godot packaging/ci/run_suites.sh --tier full --keep-going` and paste the final `suites: <n> run, <k> failed` line and the names of the failing suites. Allowed failing suites on your branch: only those that WP2 and WP4 own (`run_film_manifest_smoke`, `run_rung01_replan11_ux`, `run_rung01_replan15_extrude`, `run_rung01_replan14_savelabels`). Anything else red: stop and say so.

## Rows unblocked

L10 (Ctrl+Z note), A15.
