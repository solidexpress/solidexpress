# Replan 12 WP2 — dimension labels: smaller, stacked on screen, clickable where they are drawn

You are a BUILD agent. Edit only `game/scripts/sketch_mode.gd` (label hunks below) and the `_labels_are_stacked` function of `game/tests/run_rung01_replan6_cut.gd`. Add `game/tests/run_rung01_replan12_labels.gd`.

`sketch_mode.gd` hunks you own (search by name; line numbers are `2606160c`): the constants after `DIM_LABEL_OFFSET` (~142); new functions inserted directly **before** `_rebuild_dimension_labels` (~5035): `_dimension_label_text`, `_label_px_scale`, `_dimension_label_size_px`, `_dimension_label_rect`, `_rect_gap`; `_rebuild_dimension_labels`; `dimension_hit` (~5213). Do **not** edit `set_tool`, `click` or `_click_rect` (WP4), `_dimension_label_pos2`, the Select/Smart-Dim early dimension check in `click()` (~3231-3235) or the `_sketch_input` drag guard (`viewport_interaction.gd` ~2549): they keep calling `dimension_hit` and need no change.

## The bug

`_rebuild_dimension_labels` draws `Label3D` with `fixed_size`, `pixel_size 0.004`, `font_size 28`. A fixed-size label's on-screen size follows the window, not the zoom: at 1280×800 it is 55–60 px tall and 200–300 px wide. `dimension_hit` tests a 22 px circle around the label anchor, so a click on the first or last glyph of a wide label is outside the circle. The sx-032 walker needed a second click on both jaw labels. Labels that share a point are nudged by 2.5 mm in sketch space, which at a fixed pixel size is no separation at all.

## Decisions (see `rung-01-replan-12.md` 1 and 2)

- Font 18, `pixel_size` 0.004, `outline_size` 4.
- Screen px per font px: `k = pixel_size × viewport_height / 2`, divided by `tan(fov/2)` for a perspective camera (an orthographic camera uses `k`). Text size on screen = `ThemeDB.fallback_font` string width and `get_height(18)` times `k`.
- Stacking is by sketch-space proximity: a label whose anchor is within 14 mm of `n` earlier anchors gets `label_stack = n` and is drawn `n × 28` label px higher (`Label3D.offset`). The hit rectangle accounts for the same shift.
- The hit: the label rect grown by 8 px. Smallest gap wins; ties go to the nearer rect centre. Fallbacks, in this order: the 22 px circle around the anchor, then the 6 mm sketch-space radius.
- `label_pos`, `label_stack` and `label_text` are stored on the dimension dict so the hit test uses what is drawn.

## Diff (measured; apply by function name)

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index 4d85905..39ca4d6 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -140,6 +140,11 @@ var _line_material: StandardMaterial3D
 var _preview_material: StandardMaterial3D
 
 const DIM_LABEL_OFFSET := 4.0  # sketch-plane units perpendicular to a distance dim
+const DIM_LABEL_FONT := 18  # Label3D font px (fixed_size: screen size follows the window, not the zoom)
+const DIM_LABEL_PIXEL := 0.004  # Label3D.pixel_size
+const DIM_LABEL_PAD_PX := 8.0  # extra screen px around the text that still count as a click
+const DIM_LABEL_STACK_MM := 14.0  # labels anchored closer than this stack upward on screen
+const DIM_LABEL_STACK_PX := 28.0  # label-space px between stacked labels (> the 18 px font height)
 const COLOR_ENTITY := Color(0.95, 0.95, 1.0)
 const COLOR_CONSTRUCTION := Color(0.45, 0.45, 0.48)  # dimmer/desaturated
 const COLOR_CONSTRAINED := Color(0.35, 0.85, 0.45)  # fully constrained sketch
@@ -5032,6 +5051,47 @@ func _dimension_label_pos2(dim: Dictionary) -> Variant:
 	return mid + perp * DIM_LABEL_OFFSET
 
 
+func _dimension_label_text(dim: Dictionary) -> String:
+	var shown := snappedf(_dimension_display_value(dim), 0.0001)
+	var text := _format_dimension(shown)
+	if str(dim.get("type", "")) == "diameter":
+		text = "Ø" + text
+	if str(dim.get("type", "")) == "angle":
+		text = text + "°"
+	return text
+
+
+## Screen px per Label3D font px for a fixed_size label seen by `cam`.
+func _label_px_scale(cam: Camera3D) -> float:
+	var h := cam.get_viewport().get_visible_rect().size.y
+	var k := DIM_LABEL_PIXEL * h * 0.5
+	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
+		k /= tan(deg_to_rad(cam.fov) * 0.5)
+	return k
+
+
+func _dimension_label_size_px(text: String) -> Vector2:
+	var font: Font = ThemeDB.fallback_font
+	return Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, DIM_LABEL_FONT).x,
+			font.get_height(DIM_LABEL_FONT))
+
+
+## Screen rectangle of the drawn text. `anchor` is the projected label_pos.
+func _dimension_label_rect(dim: Dictionary, anchor: Vector2, k: float) -> Rect2:
+	var text := str(dim.get("label_text", ""))
+	if text == "":
+		text = _dimension_label_text(dim)
+	var size := _dimension_label_size_px(text) * k
+	var centre := anchor - Vector2(0.0, float(dim.get("label_stack", 0)) * DIM_LABEL_STACK_PX * k)
+	return Rect2(centre - size * 0.5, size)
+
+
+func _rect_gap(r: Rect2, p: Vector2) -> float:
+	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
+	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
+	return sqrt(dx * dx + dy * dy)
+
+
 func _rebuild_dimension_labels() -> void:
 	_clear_dimension_labels()
 	if _dimension_labels == null or sketch == null:
@@ -5045,24 +5105,22 @@ func _rebuild_dimension_labels() -> void:
 		if pos2 == null:
 			continue
 		var pos := pos2 as Vector2
-		# Same 2 mm / 2.5 mm stack the constraint glyphs already use.
-		var guard := 0
-		while guard < 8 and taken.any(func(t: Vector2) -> bool: return t.distance_to(pos) < 2.0):
-			pos += Vector2(0, 2.5)
-			guard += 1
+		var stack := 0
+		for t in taken:
+			if t.distance_to(pos) < DIM_LABEL_STACK_MM:
+				stack += 1
 		taken.append(pos)
+		var text := _dimension_label_text(dim)
 		dim["label_pos"] = pos
+		dim["label_stack"] = stack
+		dim["label_text"] = text
 		var label := Label3D.new()
 		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 		label.fixed_size = true
-		label.pixel_size = 0.004
-		label.font_size = 28
-		var shown := snappedf(_dimension_display_value(dim), 0.0001)
-		var text := _format_dimension(shown)
-		if str(dim.get("type", "")) == "diameter":
-			text = "Ø" + text
-		if str(dim.get("type", "")) == "angle":
-			text = text + "°"
+		label.pixel_size = DIM_LABEL_PIXEL
+		label.font_size = DIM_LABEL_FONT
+		label.outline_size = 4
+		label.offset = Vector2(0.0, float(stack) * DIM_LABEL_STACK_PX)
 		label.text = text
 		label.position = _to3(pos)
 		_dimension_labels.add_child(label)
@@ -5209,14 +5267,22 @@ func delete_selected_constraint() -> bool:
 	return true
 
 
-## Index of the dimension whose label sits within PICK_TOLERANCE of pos2 (-1 = none).
+## Index of the dimension whose label text is under pos2 (-1 = none). The test is
+## the label's screen rectangle plus DIM_LABEL_PAD_PX; the 22 px circle around
+## the stored anchor and the 6 mm sketch-space radius stay as fallbacks.
 func dimension_hit(pos2: Vector2) -> int:
 	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
 	var screen := Vector2(INF, INF)
+	var k := 0.0
 	if cam != null:
 		screen = cam.unproject_position(to_global(to_model(pos2)))
-	var best := -1
+		k = _label_px_scale(cam)
+	var rect_hit := -1
+	var rect_gap := INF
+	var rect_centre_d := INF
+	var anchor_hit := -1
 	var best_px := 22.0
+	var mm_hit := -1
 	var best_mm := 6.0
 	for i in range(dimensions.size()):
 		var dim: Dictionary = dimensions[i]
@@ -5226,19 +5292,29 @@ func dimension_hit(pos2: Vector2) -> int:
 		if lp == null:
 			continue
 		var p: Vector2 = lp
-		var dmm := pos2.distance_to(p)
-		var win := false
 		if cam != null:
 			var sp := cam.unproject_position(to_global(to_model(p)))
+			var rect := _dimension_label_rect(dim, sp, k)
+			var gap := _rect_gap(rect, screen)
+			var centre_d := screen.distance_to(rect.get_center())
+			if gap <= DIM_LABEL_PAD_PX and (gap < rect_gap - 0.01
+					or (absf(gap - rect_gap) <= 0.01 and centre_d < rect_centre_d)):
+				rect_hit = i
+				rect_gap = gap
+				rect_centre_d = centre_d
 			var dpx := screen.distance_to(sp)
 			if dpx < best_px:
 				best_px = dpx
-				best = i
-				win = true
-		if not win and dmm < best_mm:
+				anchor_hit = i
+		var dmm := pos2.distance_to(p)
+		if dmm < best_mm:
 			best_mm = dmm
-			best = i
-	return best
+			mm_hit = i
+	if rect_hit >= 0:
+		return rect_hit
+	if anchor_hit >= 0:
+		return anchor_hit
+	return mm_hit
 
 
 ## Live inference hint while drawing: which constraint the LINE tool would add
```

## Update `run_rung01_replan6_cut.gd`

`_labels_are_stacked` compared sketch-space UV distances under 2 mm. It must compare the screen rectangles instead (the labels are now separated on screen, not in the sketch plane). Replace the function and the one caller line; the check count is unchanged (100).

```diff
diff --git a/game/tests/run_rung01_replan6_cut.gd b/game/tests/run_rung01_replan6_cut.gd
index fce9652..07de089 100644
--- a/game/tests/run_rung01_replan6_cut.gd
+++ b/game/tests/run_rung01_replan6_cut.gd
@@ -147,7 +147,7 @@ func test_offset_cutter_jaw_cut() -> void:
 	var status_text := str(ctx.main.status_label.text)
 	check(status_text.contains("Trimmed open jaw") or _status_has("Trimmed open jaw"),
 			"status contains Trimmed open jaw (got '%s')" % status_text)
-	check(_labels_are_stacked(sm), "no two dimension labels share a point within 2 mm")
+	check(_labels_are_stacked(ctx, sm), "no two dimension label rectangles overlap on screen")
 	check(_hole_circle_present(sm), "Ø10 circle is still in the sketch")
 	chrome = ctx.main.sketch_chrome
 	await _pick_option(ctx, _finish_op(chrome), 1, "Cut")
@@ -719,19 +719,18 @@ func _non_datum_construction_ids(sm: SketchMode) -> Array[String]:
 	return out
 
 
-func _labels_are_stacked(sm: SketchMode) -> bool:
-	var uvs: Array[Vector2] = []
-	if sm == null or sm._dimension_labels == null:
-		return true
-	for child in sm._dimension_labels.get_children():
-		if not (child is Label3D):
+func _labels_are_stacked(ctx: FilmContext, sm: SketchMode) -> bool:
+	var cam: Camera3D = ctx.main.camera
+	var k := sm._label_px_scale(cam)
+	var rects: Array[Rect2] = []
+	for dim in sm.dimensions:
+		if typeof(dim) != TYPE_DICTIONARY or dim.get("label_pos", null) == null:
 			continue
-		var p3: Vector3 = (child as Label3D).position
-		var rel := p3 - sm.plane_origin
-		uvs.append(Vector2(rel.dot(sm.plane_x), rel.dot(sm.plane_y)))
-	for i in range(uvs.size()):
-		for j in range(i + 1, uvs.size()):
-			if uvs[i].distance_to(uvs[j]) < 2.0:
+		var anchor: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(dim["label_pos"] as Vector2))
+		rects.append(sm._dimension_label_rect(dim, anchor, k))
+	for i in range(rects.size()):
+		for j in range(i + 1, rects.size()):
+			if rects[i].intersects(rects[j]):
 				return false
 	return true
 
```

## Test — `game/tests/run_rung01_replan12_labels.gd` (create)

Builds a jaw sketch with the width and angle labels, then pushes real mouse motion, press and release through `Viewport.push_input` at 1280×800 on a perspective and an orthographic camera: one click on the first and the last glyph of both labels opens the editor; a click 40 px right of a label does not.

`game/tests/run_rung01_replan12_labels.gd`

```gdscript
# Rung 1 replan 12 WP2 — one click on the first or last glyph of a dimension label opens
# the editor, with the label text drawn at 18 px and stacked on screen.
# Real events: Viewport.push_input (motion, press, release), never ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_labels.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
const HEAD := Vector2(200.0, 0.0)

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
	print("rung01 replan12 WP2 label glyph clicks")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _jaw_dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(45.3))


func _jaw_across() -> Vector2:
	var d := _jaw_dir()
	return Vector2(-d.y, d.x)


func _build_jaw(sm: SketchMode, offset: float) -> void:
	var sk = sm.sketch
	var jaw_dir := _jaw_dir()
	var jaw_across := _jaw_across()
	sk.add_circle(0.0, 0.0, 5.0)
	sk.add_circle(HEAD.x, HEAD.y, 22.5)
	var p0 := HEAD - jaw_dir * 30.0 - jaw_across * 10.0
	var p1 := HEAD + jaw_dir * 30.0 - jaw_across * 10.0
	var p2 := HEAD + jaw_dir * 30.0 + jaw_across * 10.0
	var p3 := HEAD - jaw_dir * 30.0 + jaw_across * 10.0
	sk.add_line(p0.x, p0.y, p1.x, p1.y)
	sk.add_line(p1.x, p1.y, p2.x, p2.y)
	sk.add_line(p2.x, p2.y, p3.x, p3.y)
	sk.add_line(p3.x, p3.y, p0.x, p0.y)
	var cc := HEAD + jaw_dir * offset
	var c0 := cc - jaw_across * 25.0
	var c1 := cc + jaw_across * 25.0
	sk.set_construction(sk.add_line(c0.x, c0.y, c1.x, c1.y), true)
	sm.run_solve()


func _dim_index(sm: SketchMode, type: String) -> int:
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == type:
			return i
	return -1


## Screen px per font px of a fixed_size Label3D with pixel_size 0.004.
func _k(cam: Camera3D) -> float:
	var k := 0.004 * float(cam.get_viewport().get_visible_rect().size.y) * 0.5
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
		k /= tan(deg_to_rad(cam.fov) * 0.5)
	return k


## Screen rect of the drawn text, from the numbers the plan fixes (font 18, stack 28).
func _text_rect(ctx: FilmContext, sm: SketchMode, i: int) -> Rect2:
	var dim: Dictionary = sm.dimensions[i]
	var anchor: Vector2 = FilmUI.model_to_screen(ctx, sm.to_model(dim["label_pos"] as Vector2))
	var k := _k(ctx.main.camera)
	var font: Font = ThemeDB.fallback_font
	var text := str(dim.get("label_text", ""))
	var size := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x,
			font.get_height(18)) * k
	var centre := anchor - Vector2(0.0, float(dim.get("label_stack", 0)) * 28.0 * k)
	return Rect2(centre - size * 0.5, size)


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
	await process_frame


## Sketch view centred on the jaw head, about 90 mm across (the walk's _zoom).
func _frame_head(ctx: FilmContext, sm: SketchMode) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var ms: Node3D = ctx.main.model_space
	cam.sketch_orientation_locked = true
	cam.pivot = ms.to_global(sm.to_model(HEAD)) if ms != null else sm.to_model(HEAD)
	cam.distance = 90.0 / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame


func _popup_up(ix: ViewportInteraction) -> bool:
	return ix._dim_edit_popup != null and ix._dim_edit_popup.visible


func _reset(ix: ViewportInteraction, sm: SketchMode) -> void:
	if ix._dim_edit_popup != null:
		ix._dim_edit_popup.hide()
	sm._set_selected([] as Array[String])
	sm.set_tool(SketchMode.Tool.SELECT)
	await process_frame


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
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	var ix: ViewportInteraction = main.interaction
	_build_jaw(sm, 12.0)
	sm.trim_at(HEAD + _jaw_dir() * 3.0 + _jaw_across() * 8.0)
	sm.set_tool(SketchMode.Tool.SELECT)
	sm._rebuild_dimension_labels()
	await _frame_head(ctx, sm)

	var wi := _dim_index(sm, "distance")
	var ai := _dim_index(sm, "angle")
	check(wi >= 0 and ai >= 0, "jaw has a width label and an angle label (w=%d a=%d)" % [wi, ai])
	if wi < 0 or ai < 0:
		main.queue_free()
		await process_frame
		return
	var font_sizes := []
	for child in sm._dimension_labels.get_children():
		if child is Label3D:
			font_sizes.append((child as Label3D).font_size)
	check(font_sizes.size() >= 2 and font_sizes.all(func(f): return f == 18),
			"labels are drawn at font size 18 (got %s)" % str(font_sizes))

	var rw := _text_rect(ctx, sm, wi)
	var ra := _text_rect(ctx, sm, ai)
	check(not rw.intersects(ra),
			"width and angle text rectangles do not overlap on screen (%s vs %s)" % [str(rw), str(ra)])

	await _glyph_clicks(ctx, sm, ix, wi, ai, "perspective")
	main.camera.toggle_projection()
	await _frame_head(ctx, sm)
	await _glyph_clicks(ctx, sm, ix, wi, ai, "orthographic")
	main.queue_free()
	await process_frame
	await process_frame


func _glyph_clicks(ctx: FilmContext, sm: SketchMode, ix: ViewportInteraction, wi: int, ai: int,
		mode: String) -> void:
	for pair in [["width", wi], ["angle", ai]]:
		var name: String = pair[0]
		var i: int = pair[1]
		var r := _text_rect(ctx, sm, i)
		var on_screen := Rect2(Vector2.ZERO, Vector2(ROOT_SIZE)).encloses(r)
		check(on_screen, "%s %s label is on screen (%s)" % [mode, name, str(r)])
		if not on_screen:
			continue
		var y := r.get_center().y
		for glyph in [["first glyph", r.position.x + 4.0], ["last glyph", r.end.x - 4.0]]:
			await _reset(ix, sm)
			await _push_click(Vector2(float(glyph[1]), y))
			check(_popup_up(ix), "%s: one click on the %s of the %s label opens the editor" % [
					mode, glyph[0], name])
		await _reset(ix, sm)
		await _push_click(Vector2(r.end.x + 40.0, y))
		check(not _popup_up(ix), "%s: a click 40 px right of the %s label does not" % [mode, name])
```

## Commands and expected output

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_labels.gd
#   20 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan6_cut.gd
#   100 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan11_dimhit.gd
#   6 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan11_dim.gd
#   11 checks, 0 failures
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan9_dim.gd
#   35 checks, 0 failures
```

**Red on `2606160c`:** `20 checks, 5 failures` — `labels are drawn at font size 18 (got [28, 28])` and the four `a click 40 px right of the … label does not` checks (the 22 px circle plus a 56 px wide label puts the pointer inside the old hit region on both cameras). The first/last glyph checks already pass at their own zoom on `2606160c` because the anchor circle is large; the **walk** (WP7) is what catches the sx-032 miss, by clicking the first glyph of the width label after `_zoom_uv(lp, 50.0)`.

## Do not

- Change `_dimension_label_pos2`, the label anchors, `set_dimension_value` or the editor popup (`_show_dim_edit`).
- Raise the font back above 18 or drop the 8 px pad.
- Click label centres in tests. First glyph and last glyph only.
