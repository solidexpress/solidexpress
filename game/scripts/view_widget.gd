class_name ViewWidget
extends Control
## Compact ViewCube-style orientation widget (~92×92). Clickable zones jump
## the linked OrbitCamera to standard views (matching keys 1/2/3/7).

@export var camera: OrbitCamera
## When true, click_zone / gui clicks use duration 0 (instant snap).
var snap := false

const WIDGET_SIZE := 92.0
const ZONE_EPS := 0.08


func _ready() -> void:
	custom_minimum_size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	size = Vector2(WIDGET_SIZE, WIDGET_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if camera != null:
		camera.view_changed.connect(queue_redraw)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Hit-test a local point; returns zone name or "" if outside / empty cell.
func zone_at(local_pos: Vector2) -> String:
	if local_pos.x < 0.0 or local_pos.y < 0.0 or local_pos.x >= size.x or local_pos.y >= size.y:
		return ""
	var cell_w := size.x / 3.0
	var cell_h := size.y / 3.0
	var col := clampi(int(local_pos.x / cell_w), 0, 2)
	var row := clampi(int(local_pos.y / cell_h), 0, 2)
	# 3×3 face grid: center FRONT, N/S/E/W cardinals, corners iso / back.
	match Vector2i(col, row):
		Vector2i(1, 1):
			return "front"
		Vector2i(1, 0):
			return "top"
		Vector2i(1, 2):
			return "bottom"
		Vector2i(0, 1):
			return "left"
		Vector2i(2, 1):
			return "right"
		Vector2i(0, 0):
			return "iso"
		Vector2i(2, 0):
			return "iso"
		Vector2i(2, 2):
			return "iso"
		Vector2i(0, 2):
			return "back"
	return ""


func click_zone(zone: String) -> void:
	if camera == null or not has_zone(zone):
		return
	if camera.sketch_orientation_locked:
		return
	var angles: Vector2 = angles_for(zone)
	camera.apply_standard_view(angles.x, angles.y, not snap)


func has_zone(zone: String) -> bool:
	return zone in ["front", "back", "right", "left", "top", "bottom", "iso"]


## Standard view angles matching OrbitCamera keys 1/2/3/7 (and opposites).
func angles_for(zone: String) -> Vector2:
	match zone:
		"front":
			return Vector2(deg_to_rad(0.0), deg_to_rad(0.0))
		"back":
			return Vector2(PI, deg_to_rad(0.0))
		"right":
			return Vector2(deg_to_rad(90.0), deg_to_rad(0.0))
		"left":
			return Vector2(deg_to_rad(-90.0), deg_to_rad(0.0))
		"top":
			return Vector2(deg_to_rad(0.0), deg_to_rad(89.0))
		"bottom":
			return Vector2(deg_to_rad(0.0), deg_to_rad(-89.0))
		"iso":
			return Vector2(deg_to_rad(-35.0), deg_to_rad(40.0))
	return Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var zone := zone_at(mb.position)
			if zone != "":
				click_zone(zone)
				accept_event()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cell_w := w / 3.0
	var cell_h := h / 3.0
	var active := _current_zone()

	# Background.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.2, 0.24, 0.92), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.5, 0.55, 1.0), false, 1.0)

	var zones: Array[Array] = [
		["iso", 0, 0], ["top", 1, 0], ["iso", 2, 0],
		["left", 0, 1], ["front", 1, 1], ["right", 2, 1],
		["back", 0, 2], ["bottom", 1, 2], ["iso", 2, 2],
	]
	for entry: Array in zones:
		var z: String = str(entry[0])
		var col: int = int(entry[1])
		var row: int = int(entry[2])
		var rect := Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		var fill := Color(0.28, 0.32, 0.38, 1.0)
		if z == active:
			fill = Color(0.35, 0.55, 0.75, 1.0)
		elif z == "front":
			fill = Color(0.32, 0.36, 0.42, 1.0)
		draw_rect(rect.grow(-1.5), fill, true)
		draw_rect(rect.grow(-1.5), Color(0.55, 0.6, 0.65, 1.0), false, 1.0)

		var label := z.substr(0, 1).to_upper() if z != "front" else "F"
		if z == "front":
			label = "FRONT"
		elif z == "iso":
			label = "ISO"
		elif z == "top":
			label = "TOP"
		elif z == "bottom":
			label = "BOT"
		elif z == "left":
			label = "L"
		elif z == "right":
			label = "R"
		elif z == "back":
			label = "BK"
		var font := ThemeDB.fallback_font
		var font_size := 9 if z == "front" else 10
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos := rect.get_center() - text_size * 0.5 + Vector2(0, text_size.y * 0.35)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.94, 0.96))


func _current_zone() -> String:
	if camera == null:
		return ""
	for z in ["front", "back", "right", "left", "top", "bottom", "iso"]:
		var a: Vector2 = angles_for(z)
		var dyaw := absf(wrapf(camera.yaw - a.x, -PI, PI))
		if dyaw < ZONE_EPS and absf(camera.pitch - a.y) < ZONE_EPS:
			return z
	return ""
