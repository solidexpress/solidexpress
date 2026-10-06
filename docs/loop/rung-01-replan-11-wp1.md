# Replan 11 WP1 — end-on fillet pick, View menu, Back/Left/Bottom, orbit through the pole

You are a BUILD agent. Implement only this WP. Base: `main` at `b3161bba` or later replan-11 WPs. Do not edit `sketch_mode.gd`, `ops_panel.gd`, `ops_dress.cpp`, or the checker.

Read `docs/loop/rung-01-replan-11.md` decisions 2, 3 and 4 if you need the why. The code below is the what.

Godot: `tools/godot/godot` 4.7-stable. `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` before every Godot command. Do not commit `.gd.uid`.

## Files

| File | What |
|---|---|
| `game/scripts/document_view.gd` | `edge_near_point`, `_edge_near_point`, `select_ray` |
| `game/scripts/view_hud.gd` | View word button, chevron, popup position, `DEFAULT_VIEWS` |
| `game/scripts/orbit_camera.gd` | keys 4/6/8, `_is_nav_key`, `_orbit_by`, two-finger orbit |
| `game/scripts/shortcuts.gd` | three new rows |
| `game/scripts/command_registry.gd` | three new rows |
| `game/scripts/main.gd` | `_on_default_view` only |
| `game/scripts/viewport_interaction.gd` | `_rebuild_orient_popup` list and `_on_orient_id` only |

No other hunks in `main.gd` or `viewport_interaction.gd`. WP5, WP6 and WP10 own the rest of `viewport_interaction.gd`. WP9 and WP10 own the rest of `main.gd`.

## 1. Edge pick

`EDGE_PICK_TOLERANCE` stays `2.5`. Add next to it:

```gdscript
const EDGE_PICK_SCREEN_TIE_PX := 8.0
```

Replace `edge_near_point` (today at line 1255) with:

```gdscript
func edge_near_point(body_id: String, point: Vector3, tolerance_mm: float = EDGE_PICK_TOLERANCE, camera: Camera3D = null) -> String:
	var lines: Dictionary = doc.get_edge_lines(body_id)
	if camera == null:
		var best_id := ""
		var best_d := tolerance_mm
		for edge_id in lines:
			var pts: PackedVector3Array = lines[edge_id]
			for i in range(pts.size() - 1):
				var d := _point_segment_distance3(point, pts[i], pts[i + 1])
				if d < best_d:
					best_d = d
					best_id = edge_id
		return best_id
	var ray := (-camera.global_transform.basis.z).normalized()
	var screen := camera.unproject_position(point)
	var best_id := ""
	var best_px := INF
	var best_align := -1.0
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		var d3 := INF
		for i in range(pts.size() - 1):
			d3 = minf(d3, _point_segment_distance3(point, pts[i], pts[i + 1]))
		if d3 > tolerance_mm:
			continue
		var px := _polyline_screen_distance(camera, screen, pts)
		var align := absf(edge_direction(body_id, str(edge_id)).dot(ray))
		var closer := px < best_px - EDGE_PICK_SCREEN_TIE_PX
		var tie := absf(px - best_px) <= EDGE_PICK_SCREEN_TIE_PX
		if best_id == "" or closer or (tie and align > best_align + 0.05):
			best_id = str(edge_id)
			best_px = px
			best_align = align
	return best_id


func _polyline_screen_distance(camera: Camera3D, screen: Vector2, pts: PackedVector3Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		if camera.is_position_behind(pts[i]) and camera.is_position_behind(pts[i + 1]):
			continue
		var a := camera.unproject_position(pts[i])
		var b := camera.unproject_position(pts[i + 1])
		best = minf(best, _point_segment_distance2(screen, a, b))
	return best


func _point_segment_distance2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
```

`_edge_near_point` (line 1249) passes the viewport camera:

```gdscript
func _edge_near_point(body_id: String, point: Vector3) -> String:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return edge_near_point(body_id, point, EDGE_PICK_TOLERANCE, cam)
```

`select_ray` already calls `_edge_near_point`. Leave that call. The 12 mm fallback in `ops_panel.gd` is not yours.

## 2. View HUD

`DEFAULT_VIEWS` (line 17) becomes:

```gdscript
const DEFAULT_VIEWS := [
	{"id": "front", "label": "Front"},
	{"id": "back", "label": "Back"},
	{"id": "right", "label": "Right"},
	{"id": "left", "label": "Left"},
	{"id": "top", "label": "Top"},
	{"id": "bottom", "label": "Bottom"},
	{"id": "iso", "label": "Isometric"},
]
```

Replace the `Label` named by text `View` (line 104) with a button:

```gdscript
var view_word := Button.new()
view_word.name = "ViewWord"
view_word.text = "View"
view_word.flat = true
view_word.tooltip_text = "Show default and saved views"
view_word.pressed.connect(_toggle_views_popup)
strip_row.add_child(view_word)
```

Chevron button, replacing the current assignment (line 108):

```gdscript
_views_drop_btn = Button.new()
_views_drop_btn.name = "ViewsDrop"
_views_drop_btn.text = "▼"
_views_drop_btn.icon = UIIcons.get_icon("down", 14)
_views_drop_btn.tooltip_text = "Show default and saved views"
_views_drop_btn.custom_minimum_size = Vector2(28, 28)
_compact_icon_btn(_views_drop_btn)
_views_drop_btn.pressed.connect(_toggle_views_popup)
strip_row.add_child(_views_drop_btn)
```

`run_visual_ux_tests.gd` line 357 requires `_views_drop_btn.text == "▼"`. Setting that text is required. Do not leave it `""`.

In `_toggle_views_popup`, the `popup(Rect2i(...))` call must use screen coordinates. After computing `pos` and `w`/`h`:

```gdscript
var origin := Vector2i.ZERO
var win := get_window()
if win != null:
	origin = win.position
_views_popup.popup(Rect2i(Vector2i(pos) + origin, Vector2i(int(w), int(h))))
```

`_rebuild_views_popup` already emits `default_view_requested` with the id from `DEFAULT_VIEWS`. No change there besides the longer list.

## 3. Camera keys and the pole

`_is_nav_key` line 213, change the key list to:

```gdscript
KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
	return not k.alt_pressed and not sketch_orientation_locked
```

`_handle_nav_key`, after the `KEY_3` arm and before `KEY_7`:

```gdscript
KEY_4:  # back: looking along +Y
	if sketch_orientation_locked:
		return false
	apply_standard_view(deg_to_rad(180.0), deg_to_rad(0.0))
	return true
KEY_6:  # left: looking along +X
	if sketch_orientation_locked:
		return false
	apply_standard_view(deg_to_rad(-90.0), deg_to_rad(0.0))
	return true
KEY_8:  # bottom: looking up model +Z
	if sketch_orientation_locked:
		return false
	apply_standard_view(deg_to_rad(0.0), deg_to_rad(-89.0))
	return true
```

Replace `_orbit_by` (line 100):

```gdscript
func _orbit_by(dx: float, dy: float) -> void:
	if sketch_orientation_locked:
		return
	yaw -= dx * ORBIT_SPEED
	_fold_pitch(pitch + dy * ORBIT_SPEED)
	_update_transform()


func _fold_pitch(next: float) -> void:
	if next > MAX_PITCH:
		var over := next - MAX_PITCH
		yaw += PI
		pitch = clampf(MAX_PITCH - over, MIN_PITCH, MAX_PITCH)
	elif next < MIN_PITCH:
		var over := MIN_PITCH - next
		yaw += PI
		pitch = clampf(MIN_PITCH + over, MIN_PITCH, MAX_PITCH)
	else:
		pitch = next
```

Two-finger orbit (line 288) replaces the `pitch = clampf(...)` line with:

```gdscript
yaw -= pg.delta.x * scale
_fold_pitch(pitch + pg.delta.y * scale)
_update_transform()
```

Do not change `_want_pan` or `nav_preset`. Fusion middle-drag stays pan.

## 4. Shortcut tables

In `shortcuts.gd` after the `"7"` row (line 28), add:

```gdscript
{"keys": "4", "context": "View", "desc": "Back view"},
{"keys": "6", "context": "View", "desc": "Left view"},
{"keys": "8", "context": "View", "desc": "Bottom view"},
```

In `command_registry.gd` after the `"7"` row (line 42), add:

```gdscript
{"keys": "4", "context": "View", "desc": "Back view + zoom extents"},
{"keys": "6", "context": "View", "desc": "Left view + zoom extents"},
{"keys": "8", "context": "View", "desc": "Bottom view + zoom extents"},
```

## 5. main.gd `_on_default_view` only

Inside the `match`, add:

```gdscript
"back":
	camera.set_view(deg_to_rad(180.0), deg_to_rad(0.0), false)
	_on_status("Back view")
"left":
	camera.set_view(deg_to_rad(-90.0), deg_to_rad(0.0), false)
	_on_status("Left view")
"bottom":
	camera.set_view(deg_to_rad(0.0), deg_to_rad(-89.0), false)
	_on_status("Bottom view")
```

## 6. Space orientation popup

`_rebuild_orient_popup` entry list (line 447) becomes:

```gdscript
["Front", 1], ["Back", 4], ["Right", 2], ["Left", 6], ["Top", 3], ["Bottom", 8], ["Isometric", 7],
["Frame selection", 20], ["Frame all", 21], ["Ortho/Persp", 5],
```

`_on_orient_id` gains:

```gdscript
4:
	camera.set_view(deg_to_rad(180.0), deg_to_rad(0.0), true)
6:
	camera.set_view(deg_to_rad(-90.0), deg_to_rad(0.0), true)
8:
	camera.set_view(deg_to_rad(0.0), deg_to_rad(-89.0), true)
```

## Test

Create `game/tests/run_rung01_replan11_views.gd` with this exact script. Commit the test first and run it: on `b3161bba` it fails (missing Back/Left/Bottom, chevron text `""`, orbit from pitch 89° does not change pitch, corner pick returns a horizontal edge). Then apply the product edits.

```gdscript
extends SceneTree
## Rung 1 replan 11 WP1. Run:
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_views.gd

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
	print("rung01 replan11 WP1 views and end-on pick")
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

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
	check(root.size == ROOT_SIZE, "root is 1280×800")
	var cam: OrbitCamera = main.camera
	await _tap(main, KEY_4)
	check(absf(wrapf(cam.yaw - PI, -PI, PI)) < 0.05, "key 4 is Back yaw (got %.3f)" % cam.yaw)
	check(absf(cam.pitch) < 0.05, "key 4 pitch is 0")
	await _tap(main, KEY_6)
	check(absf(wrapf(cam.yaw - deg_to_rad(-90.0), -PI, PI)) < 0.05, "key 6 is Left yaw")
	await _tap(main, KEY_8)
	check(absf(cam.pitch - deg_to_rad(-89.0)) < 0.02, "key 8 is Bottom pitch")
	await _tap(main, KEY_3)
	check(absf(cam.pitch - deg_to_rad(89.0)) < 0.02, "key 3 still Top")
	var before_pitch := cam.pitch
	var before_yaw := cam.yaw
	cam._orbit_by(0.0, 40.0)
	check(absf(cam.pitch - before_pitch) > 0.05 or absf(wrapf(cam.yaw - before_yaw, -PI, PI)) > 0.2,
			"vertical orbit off Top moves the camera")
	var hud = main.view_hud
	var word := hud.find_child("ViewWord", true, false)
	check(word is Button, "View word is a button")
	if word is Button:
		(word as Button).pressed.emit()
	await process_frame
	check(hud._views_popup.visible, "View menu opened")
	check(hud._views_drop_btn.text == "▼", "chevron text is ▼")
	var labels: Array = []
	for c in hud._views_list.get_children():
		if c is Button:
			labels.append(str(c.text))
	check(labels.has("Back") and labels.has("Left") and labels.has("Bottom"),
			"menu lists Back Left Bottom (got %s)" % str(labels))
	hud._views_popup.hide()
	var body: String = main.view.insert_primitive("box", Vector3(0, 0, 0))
	await process_frame
	await _tap(main, KEY_3)
	var vertical := _vertical_edge(main.view, body)
	var corner := _top_of(main.view, body, vertical) + Vector3(0.3, 0.3, 0.0)
	var picked := main.view.edge_near_point(body, corner, 2.5, cam)
	check(picked == vertical, "top-view corner picks the vertical edge (got %s want %s)" % [picked, vertical])
	var dir := main.view.edge_direction(body, picked)
	check(absf(dir.z) > 0.9, "picked edge is vertical")
	main.queue_free()
	await process_frame

func _tap(main, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	main.camera.handle_input(ev)
	await process_frame

func _vertical_edge(view, body: String) -> String:
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) > 5.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			return str(id)
	return ""

func _top_of(view, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return pts[0] if pts[0].z > pts[pts.size() - 1].z else pts[pts.size() - 1]
```

The script has 18 `check()` calls. Green output:

```
18 checks, 0 failures
```

Command:

```
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_views.gd
```

Also run `run_visual_ux_tests.gd`. The `▼` assertion must pass. `run_viewcube_tests.gd` must stay at 0 failures.

## Do not

- Change `nav_preset`.
- Add numpad bindings.
- Edit the fillet kernel or `ops_panel.gd`.
