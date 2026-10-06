# Replan 12 WP5 — the timeline edit panel closes on Esc and on an empty-viewport click

You are a BUILD agent. Edit only `game/scripts/viewport_interaction.gd`, in the two places below, and add `game/tests/run_rung01_replan12_panel.gd`.

`viewport_interaction.gd` hunks you own (line numbers are `2606160c`): the **first rung** at the top of `cancel_stack` (~1574) and **one line** inside the `if _press_empty:` branch of `_on_release` (~3376). WP6 later adds a second rung right after yours and edits the condition and the armed branch of the same `_on_release`; **merge WP5 first**.

## The bug

After the walk types `14` into the first extrude's Distance in the timeline panel, the panel stays open. One Esc does not close it: Esc outside a sketch reaches `viewport_interaction._input` → `cancel_stack()`, which releases the focused `LineEdit` and then clears the selection, but never asks `main.cancel_property_panel()` (only the TriBall path called it, from script). An empty-viewport click clears the selection but leaves the panel and its previewed value; the hand walk had to close the panel by hand every time.

## Decisions (see `rung-01-replan-12.md` 12 and 13)

- Esc cancels first: if `main.cancel_property_panel()` returns true, release the focused field, status `Edits cancelled`, return true (nothing else is cleared). The preview is rolled back.
- A click on empty viewport **keeps** the previewed value and closes the panel: `_commit_property_panel_on_deselect()` (already defined at ~3440) is called right after `view.clear_selection()`.
- Both only fire when the panel is open. With no panel the ladder is unchanged (`run_rung01_replan10_esc`, `run_rung01_replan11_esc` stay green).

## Diff (measured)

```diff
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -1574,6 +1574,12 @@
 func cancel_stack() -> bool:
 	var acted := false
 	var vp := get_viewport()
+	var main_pp := _find_main()
+	if main_pp != null and main_pp.has_method("cancel_property_panel") and main_pp.cancel_property_panel():
+		if vp != null and _should_release_cancel_focus(vp.gui_get_focus_owner()):
+			vp.gui_get_focus_owner().release_focus()
+		status.emit("Edits cancelled")
+		return true
 	if vp != null:
 		var focus := vp.gui_get_focus_owner()
 		if _should_release_cancel_focus(focus):
@@ -3376,6 +3382,7 @@
 	if _press_empty:
 		if not _additive_click:
 			view.clear_selection()
+			_commit_property_panel_on_deselect()
 			status.emit("")
 			_box_drag = false
 			_additive_click = false
```

## Test — `game/tests/run_rung01_replan12_panel.gd` (create)

Places a box, extrudes, opens the timeline panel on the extrude, types `14` Enter into Distance with the field still focused, then pushes a real Esc key through the viewport and checks the panel closed, the distance returned to 10 and the status is `Edits cancelled`. It reopens, types 14 again and pushes a real mouse click on a background pixel; the panel closes and the distance stays 14.

`game/tests/run_rung01_replan12_panel.gd`

```gdscript
# Rung 1 replan 12 WP5 — the timeline edit panel closes on Esc and on an empty-viewport click
# with the Distance field focused (the GUI state), through real pushed events.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_panel.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 WP5 timeline panel dismiss")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_key(code: int, unicode: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = unicode
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _push_click(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev)
		await process_frame
	await process_frame


func _empty_point(main) -> Vector2:
	for p in [Vector2(1150, 150), Vector2(1100, 600), Vector2(900, 120), Vector2(700, 650)]:
		var ray: Array = main.interaction._model_ray(p)
		if main.view.pick_info(ray[0], ray[1]).is_empty():
			return p
	return Vector2.INF


func _distance(doc, fid: String) -> float:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			var p = JSON.parse_string(str(f.get("params", "{}")))
			if typeof(p) == TYPE_DICTIONARY:
				return float((p as Dictionary).get("distance", -1.0))
	return -1.0


## Open the panel on `fid`, type 14 + Enter into Distance, and return the focused LineEdit.
func _open_and_type(main, fid: String) -> LineEdit:
	var pp = main.timeline.property_panel
	pp.open(fid)
	await process_frame
	await process_frame
	var spin: SpinBox = pp._spin_for_key("distance")
	var le: LineEdit = spin.get_line_edit()
	le.grab_focus()
	le.select_all()
	await process_frame
	await _push_key(KEY_1, 49)
	await _push_key(KEY_4, 52)
	await _push_key(KEY_ENTER)
	return le


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	var pp = main.timeline.property_panel
	await FilmUI.enter_sketch(ctx)
	sm.sketch.add_circle(0.0, 0.0, 8.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	main.show_timeline = true
	main._update_panel_visibility()
	await process_frame
	var ex_fid := ""
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			ex_fid = str(f.get("id", ""))
	check(ex_fid != "", "extrude feature exists")
	check(absf(_distance(view.doc, ex_fid) - 10.0) < 0.01, "distance starts at 10")

	var le := await _open_and_type(main, ex_fid)
	check(pp.visible, "panel is open after typing 14 + Enter")
	check(absf(_distance(view.doc, ex_fid) - 14.0) < 0.01, "Enter previews distance 14 (got %.3f)" % _distance(view.doc, ex_fid))
	check(le.has_focus(), "the Distance field keeps focus after Enter (the GUI state)")
	await _push_key(KEY_ESCAPE)
	check(not pp.visible, "one Esc closes the panel with Distance focused")
	check(absf(_distance(view.doc, ex_fid) - 10.0) < 0.01, "Esc cancels the preview (distance %.3f)" % _distance(view.doc, ex_fid))
	check(str(main.status_label.text) == "Edits cancelled", "status is `Edits cancelled` (got `%s`)" % str(main.status_label.text))

	le = await _open_and_type(main, ex_fid)
	check(pp.visible and absf(_distance(view.doc, ex_fid) - 14.0) < 0.01, "panel reopened with distance 14 previewed")
	var empty := _empty_point(main)
	check(empty != Vector2.INF, "found a background pixel off the solid and off the chrome (%s)" % str(empty))
	await _push_click(empty)
	check(not pp.visible, "one click on empty viewport closes the panel")
	check(absf(_distance(view.doc, ex_fid) - 14.0) < 0.01, "click-away keeps the previewed distance (got %.3f)" % _distance(view.doc, ex_fid))

	main.queue_free()
	await process_frame
	await process_frame
```

## Commands and expected output

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_panel.gd
#   12 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan10_esc.gd
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan11_esc.gd
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan3_timeline.gd
#   105 checks, 1 failures   (pre-existing, identical on 2606160c)
tools/godot/godot --headless --path game --script res://tests/run_critic_walk_tests.gd
#   46 checks, 0 failures
```

**Red on `2606160c`:** `12 checks, 4 failures` — `one Esc closes the panel with Distance focused`, `Esc cancels the preview (distance 14.000)`, `status is Edits cancelled (got Preview: distance = 14.0)`, `one click on empty viewport closes the panel`.

**Why the old suites missed it:** `run_rung01_replan11_ux.gd` and the walk's `_triball_one_esc` called `main.cancel_property_panel()` directly from script, which is the function that works; the Esc key path never reached it. The WP7 walk replaces that script call with an assertion that no panel is open.

## Do not

- Make Esc also clear the selection when it closes the panel (one rung per press; the second Esc is the existing ladder).
- Call `cancel_property_panel()` on a click: a click keeps the value.
- Touch `_input`'s Esc dispatch.
