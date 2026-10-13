class_name SketchOffset
extends RefCounted
## Offset Entities rail tool: distance + reverse, then a click.
## Circles and lines go through the kernel OFFSETTERS table. A model edge
## of the sketch face is Converted first, then offset.


## Entity kinds this tool builds. A new kind is one row; sketch_mode does not
## branch on type.
const BUILDERS := {
	"circle": true,
	"line": true,
}

const ARM_HINT := "Offset — click an entity or a face edge"
const ZERO_REFUSED := "Offset: distance must be greater than 0"
const TOO_FAR := "Offset: inward distance is at least the radius"
const NOTHING := "Offset: nothing there — click an entity or a face edge"
const APPLIED_CIRCLE := "Offset: circle r = %.4f"
const APPLIED_LINE := "Offset: line"


class Context:
	var doc: SxDocument
	var view: DocumentView
	var plane: PlaneBasis
	var sketch
	var host_face_id := ""
	var support_host := ""
	var support_normal := Vector3.ZERO
	var ensure_feature: Callable
	var nearest_entity: Callable
	var commit: Callable
	var status: Callable
	var adopt: Callable
	var pick_tol := 2.5


var distance := 5.0
var reverse := false
var panel: PanelContainer
var _distance_spin: SpinBox
var _reverse: CheckButton
var _ok: Button
## Last Convert refusal, so a miss is not always the generic "nothing there".
var _convert_note := ""


func build(parent: Control) -> void:
	panel = PanelContainer.new()
	panel.name = "OffsetPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 20
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var dist_lbl := Label.new()
	dist_lbl.text = "Distance"
	box.add_child(dist_lbl)
	_distance_spin = SpinBox.new()
	_distance_spin.name = "OffsetDistance"
	_distance_spin.min_value = 0.0
	_distance_spin.max_value = 10000.0
	_distance_spin.step = 0.1
	_distance_spin.value = distance
	_distance_spin.suffix = "mm"
	_distance_spin.custom_minimum_size = Vector2(UiScale.px(120), 0)
	_distance_spin.set_meta("sx_auto", "offset:Distance")
	_distance_spin.value_changed.connect(_on_distance)
	box.add_child(_distance_spin)
	_reverse = CheckButton.new()
	_reverse.name = "OffsetReverse"
	_reverse.text = "Reverse"
	_reverse.set_meta("sx_auto", "offset:Reverse")
	_reverse.toggled.connect(_on_reverse)
	box.add_child(_reverse)
	_ok = Button.new()
	_ok.name = "OffsetOk"
	_ok.text = "OK"
	_ok.set_meta("sx_auto", "offset:Ok")
	_ok.pressed.connect(hide_panel)
	box.add_child(_ok)


func show_panel() -> void:
	if panel == null:
		return
	_distance_spin.set_value_no_signal(distance)
	_reverse.set_pressed_no_signal(reverse)
	panel.visible = true
	panel.reset_size()
	var want := panel.get_combined_minimum_size()
	panel.size = want
	var vp := panel.get_viewport().get_visible_rect().size
	var pos := Vector2(UiScale.px(56) + 8.0, UiScale.px(48))
	if pos.x + want.x > vp.x - 4.0:
		pos.x = maxf(4.0, vp.x - want.x - 4.0)
	if pos.y + want.y > vp.y - 4.0:
		pos.y = maxf(4.0, vp.y - want.y - 4.0)
	panel.global_position = pos


func hide_panel() -> void:
	if panel != null:
		panel.visible = false


func is_panel_visible() -> bool:
	return panel != null and panel.visible


func signed_distance() -> float:
	var d := absf(distance)
	return -d if reverse else d


func click(ctx: Context, uv: Vector2) -> void:
	if ctx == null or ctx.sketch == null:
		return
	# The distance SpinBox keeps typed text until focus leaves. A rim click
	# in the 3D view does not commit it, so read the line edit first.
	_pull_typed_distance()
	if distance <= 1e-9:
		ctx.status.call(ZERO_REFUSED)
		return
	var prior := {}
	for id in ctx.sketch.entity_ids():
		prior[str(id)] = true
	_convert_note = ""
	var source := _resolve_source(ctx, uv)
	if source == "":
		ctx.status.call(_convert_note if _convert_note != "" else NOTHING)
		return
	var converted := not prior.has(source)
	var info: Dictionary = ctx.sketch.entity_info(source)
	var kind := str(info.get("type", ""))
	if not bool(BUILDERS.get(kind, false)):
		_rollback_convert(ctx, source, converted)
		ctx.status.call(NOTHING)
		return
	if kind == "circle" and reverse:
		var r := float(info.get("radius", 0.0))
		if distance >= r - 1e-9:
			_rollback_convert(ctx, source, converted)
			ctx.status.call(TOO_FAR)
			return
	var ids := PackedStringArray([source])
	var new_ids: PackedStringArray = ctx.sketch.offset_entities(ids, signed_distance())
	if new_ids.is_empty():
		_rollback_convert(ctx, source, converted)
		if kind == "circle" and reverse:
			ctx.status.call(TOO_FAR)
		else:
			ctx.status.call(NOTHING)
		return
	ctx.commit.call("Offset")
	if kind == "circle":
		var created: Dictionary = ctx.sketch.entity_info(str(new_ids[0]))
		ctx.status.call(APPLIED_CIRCLE % float(created.get("radius", 0.0)))
	else:
		ctx.status.call(APPLIED_LINE)


func _rollback_convert(ctx: Context, source: String, converted: bool) -> void:
	if converted and source != "" and ctx.sketch != null:
		ctx.sketch.remove_entity(source)


func _resolve_source(ctx: Context, uv: Vector2) -> String:
	if ctx.nearest_entity.is_valid():
		var hit := str(ctx.nearest_entity.call(uv))
		if hit != "":
			var info: Dictionary = ctx.sketch.entity_info(hit)
			if bool(BUILDERS.get(str(info.get("type", "")), false)):
				return hit
	return _convert_edge(ctx, uv)


func _convert_edge(ctx: Context, uv: Vector2) -> String:
	var convert_ctx := SketchConvertEdge.Context.new()
	convert_ctx.doc = ctx.doc
	convert_ctx.view = ctx.view
	convert_ctx.plane = ctx.plane
	convert_ctx.host_face_id = ctx.host_face_id
	convert_ctx.support_host = ctx.support_host
	convert_ctx.support_normal = ctx.support_normal
	convert_ctx.ensure_feature = ctx.ensure_feature
	convert_ctx.adopt = ctx.adopt
	convert_ctx.commit = func(_label: String) -> void: pass
	convert_ctx.status = func(text: String) -> void:
		_convert_note = text
	convert_ctx.fallback = func() -> void: pass
	var edge := SketchConvertEdge.new(convert_ctx)
	var id := edge.click(uv)
	ctx.host_face_id = convert_ctx.host_face_id
	return id


func _pull_typed_distance() -> void:
	if _distance_spin == null:
		return
	var edit := _distance_spin.get_line_edit()
	if edit != null:
		var typed := str(edit.text).strip_edges()
		if typed.is_valid_float():
			_distance_spin.set_value_no_signal(float(typed))
	distance = _distance_spin.value


func _on_distance(v: float) -> void:
	distance = v


func _on_reverse(on: bool) -> void:
	reverse = on
