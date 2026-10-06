# Replan 12 WP4 — sketch tool statuses: Slot c-c readback, Jaw committed, Circle, Select, Centerline

You are a BUILD agent. Edit only `game/scripts/sketch_mode.gd`, in the four places below, and add `game/tests/run_rung01_replan12_status.gd`.

`sketch_mode.gd` hunks you own (search by name; line numbers are `2606160c`): `set_tool` (~932; the `if t == Tool.RECT:` status at its end), `click` — the Centerline commit (~3284) and the Slot arm (~3387) — and the jaw arm of `_click_rect` (~3465). Do **not** edit the dimension-label constants, helpers, `_rebuild_dimension_labels` or `dimension_hit` (WP2). The two WPs share no lines; if WP2 merged first, rebase and expect line numbers ~15 lines further down.

## The bug

The sx-032 walker typed or dragged a slot and read `150.3466` instead of `150` only after the cut, because the Slot tool says nothing when the second click lands. The jaw commit, the Circle tool, the Select tool and a Centerline commit are also silent, and the Circle press still showed the Rect hint. A walker cannot tell a dropped click from a committed shape.

## Decisions (see `rung-01-replan-12.md` 16)

- `set_tool` emits one status per tool: Rect (unchanged), Circle `Circle — click the centre, then the rim (or type a radius)`, Select `Select — click geometry, or a dimension label to edit it`, Centerline `Centerline — click 2 points (construction, never part of the profile)`. Other tools keep their existing text.
- A Centerline commit emits `Centerline added — construction, not part of the profile`.
- The Slot's second click emits `Slot c-c <len %.4f> R<r %.4f>` plus ` — typed` when `_point_from_length` is set. Four decimals on purpose: `150.3466` must be visible.
- The jaw commit emits `Jaw committed — width <w %.4f>, long side <deg %.1f>° — click a label to edit it`.
- Statuses only. No geometry, constraint or selection change.

## Diff (measured; apply by function name)

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index 4d85905..39ca4d6 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -961,8 +966,15 @@ func set_tool(t: Tool) -> void:
 	# visible/selectable (polygon/circle vanishing after another tool was a bug).
 	_update_preview()
 	tool_changed.emit(int(t))
-	if t == Tool.RECT:
-		status.emit("Rect — click 1 first corner, click 2 the opposite corner")
+	match t:
+		Tool.RECT:
+			status.emit("Rect — click 1 first corner, click 2 the opposite corner")
+		Tool.CIRCLE:
+			status.emit("Circle — click the centre, then the rim (or type a radius)")
+		Tool.SELECT:
+			status.emit("Select — click geometry, or a dimension label to edit it")
+		Tool.CENTERLINE:
+			status.emit("Centerline — click 2 points (construction, never part of the profile)")
 
 
 ## Rail "Jaw" button: Rectangle tool, Center Three Point variant.
@@ -3295,6 +3307,8 @@ func click(pos2: Vector2) -> void:
 				_redraw()
 				# Propose chips follow new geometry even when infer did not solve.
 				selection_actions_needed.emit()
+				if as_centreline:
+					status.emit("Centerline added — construction, not part of the profile")
 		Tool.RECT:
 			_click_rect(pos2)
 		Tool.CIRCLE:
@@ -3385,6 +3399,9 @@ func click(pos2: Vector2) -> void:
 			_tool_points.append(pos2)
 			if _tool_points.size() == 2:
 				_add_slot(_tool_points[0], _tool_points[1], slot_radius)
+				status.emit("Slot c-c %.4f R%.4f%s" % [
+						_tool_points[0].distance_to(_tool_points[1]), slot_radius,
+						" — typed" if _point_from_length else ""])
 				_tool_points.clear()
 				_redraw()
 		Tool.SMART_DIM:
@@ -3463,6 +3480,8 @@ func _click_rect(pos2: Vector2) -> void:
 						# to a construction +X through the centre. Construction
 						# stays out of the profile.
 						_add_centre_rect_dimensions(q1, q2, q3, ctr, pt)
+						status.emit("Jaw committed — width %.4f, long side %.1f° — click a label to edit it" % [
+								half_w * 2.0, fposmod(rad_to_deg(dir.angle()), 180.0)])
 				_tool_points.clear()
 		"parallelogram":
 			if _tool_points.size() == 3:
```

## Test — `game/tests/run_rung01_replan12_status.gd` (create)

`game/tests/run_rung01_replan12_status.gd`

```gdscript
# Rung 1 replan 12 WP4 — sketch statuses: Slot c-c readback, Jaw commit, Centerline, Circle and
# Select tool hints.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_status.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 WP6 sketch statuses")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _last() -> String:
	return "" if _log.is_empty() else _log[_log.size() - 1]


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
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	sm.status.connect(func(m): _log.append(str(m)))

	sm.set_tool(SketchMode.Tool.CIRCLE)
	check(_last().begins_with("Circle — click the centre"), "Circle tool status is its own hint (got `%s`)" % _last())
	check(not _last().contains("Rect"), "Circle status no longer carries the Rect hint")
	sm.set_tool(SketchMode.Tool.SELECT)
	check(_last().begins_with("Select — click geometry"), "Select tool press has a status (got `%s`)" % _last())
	sm.set_tool(SketchMode.Tool.CENTERLINE)
	check(_last().begins_with("Centerline — click 2 points"), "Centerline tool status (got `%s`)" % _last())
	sm.click(Vector2(-60.0, 40.0))
	sm.click(Vector2(-20.0, 40.0))
	check(_last().begins_with("Centerline added"), "Centerline commit has a status (got `%s`)" % _last())

	sm.set_tool(SketchMode.Tool.SLOT)
	sm.slot_radius = 5.0
	sm.click(Vector2(0.0, 0.0))
	sm.click(Vector2(150.0, 0.0))
	check(_last() == "Slot c-c 150.0000 R5.0000", "Slot status reads back the length (got `%s`)" % _last())
	sm.set_tool(SketchMode.Tool.SLOT)
	sm.click(Vector2(0.0, -30.0))
	sm.set_length_override(150.0)
	sm.click(Vector2(100.0, -30.0))
	check(_last() == "Slot c-c 150.0000 R5.0000 — typed", "typed Slot length is marked typed (got `%s`)" % _last())
	sm.set_tool(SketchMode.Tool.SLOT)
	sm.click(Vector2(0.0, -60.0))
	sm.click(Vector2(150.3466, -60.0))
	check(_last() == "Slot c-c 150.3466 R5.0000", "a rubber-band 150.35 is visible in the status (got `%s`)" % _last())

	sm.start_jaw_tool()
	sm.click(Vector2(200.0, 0.0))
	sm.click(Vector2(230.0, 0.0))
	sm.click(Vector2(230.0, 10.0))
	check(_last().begins_with("Jaw committed — width 20.0000, long side 0.0°"), "Jaw commit has a status (got `%s`)" % _last())
	main.queue_free()
	await process_frame
	await process_frame
```

## Commands and expected output

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_status.gd
#   9 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan11_slot.gd
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan6_cut.gd
#   100 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan10_cut.gd
```

The slot, cut and replan-10 suites must print the same counts as on `2606160c` (whole-suite table).

**Red on `2606160c`:** `9 checks, 8 failures` — Circle, Select, Centerline, Centerline commit and the three Slot statuses are empty strings, and the Jaw commit status is still `Jaw — click 1 centre, click 2 end of the long side, click 3 half the width`.

## Do not

- Round the slot status to fewer than four decimals.
- Add statuses to tools other than the five above.
- Change `_add_slot`, `_add_centre_rect_dimensions` or any dimension value.
