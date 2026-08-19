class_name ChromeDock
extends RefCounted
## Floating chrome placement for Timeline / Variables.
## Remembers nearest corner + fractional offset so window resizes keep the
## rough location. Layout lives in user://chrome_layout.cfg.

const CFG_PATH := "user://chrome_layout.cfg"
const CORNERS := ["tl", "tr", "bl", "br"]

## Optional left inset so docks never cover the icon rail.
static var rail_right: float = 56.0
static var top_inset: float = 48.0
static var bottom_inset: float = 42.0


static func load_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	return cfg


static func save_section(section: String, corner: String, fx: float, fy: float,
		w: float, h: float) -> void:
	var cfg := load_cfg()
	cfg.set_value(section, "corner", corner)
	cfg.set_value(section, "fx", clampf(fx, 0.0, 1.0))
	cfg.set_value(section, "fy", clampf(fy, 0.0, 1.0))
	cfg.set_value(section, "w", maxf(w, 160.0))
	cfg.set_value(section, "h", maxf(h, 120.0))
	cfg.save(CFG_PATH)


static func has_saved(section: String) -> bool:
	var cfg := load_cfg()
	return cfg.has_section_key(section, "corner")


static func default_for(section: String) -> Dictionary:
	# Tight left column — immediately right of the icon rail, not over the plate.
	if section == "timeline":
		return {"corner": "tl", "fx": 0.0, "fy": 0.0, "w": 240.0, "h": 180.0}
	# Variables stacks under timeline in the same left band when both shown.
	return {"corner": "tl", "fx": 0.0, "fy": 0.35, "w": 240.0, "h": 200.0}


static func read_layout(section: String) -> Dictionary:
	var d := default_for(section)
	if not has_saved(section):
		return d
	var cfg := load_cfg()
	d["corner"] = str(cfg.get_value(section, "corner", d["corner"]))
	d["fx"] = float(cfg.get_value(section, "fx", d["fx"]))
	d["fy"] = float(cfg.get_value(section, "fy", d["fy"]))
	d["w"] = float(cfg.get_value(section, "w", d["w"]))
	d["h"] = float(cfg.get_value(section, "h", d["h"]))
	if not CORNERS.has(str(d["corner"])):
		d["corner"] = "bl"
	return d


## Compute top-left position for a dock given viewport size and layout dict.
static func position_for(layout: Dictionary, vp: Vector2) -> Vector2:
	var w: float = maxf(float(layout.get("w", 260.0)), 160.0)
	var h: float = maxf(float(layout.get("h", 200.0)), 120.0)
	# Shrink to fit tiny/headless viewports so math still separates docks.
	w = minf(w, maxf(vp.x - rail_right - 8.0, 80.0))
	h = minf(h, maxf(vp.y - top_inset - bottom_inset - 8.0, 80.0))
	var fx: float = clampf(float(layout.get("fx", 0.0)), 0.0, 1.0)
	var fy: float = clampf(float(layout.get("fy", 0.0)), 0.0, 1.0)
	var corner := str(layout.get("corner", "bl"))
	var min_x := rail_right
	var min_y := top_inset
	var max_x := maxf(vp.x - w - 4.0, min_x)
	var max_y := maxf(vp.y - h - bottom_inset, min_y)
	var fw := maxf(max_x - min_x, 1.0)
	var fh := maxf(max_y - min_y, 1.0)
	var x := min_x
	var y := min_y
	match corner:
		"tl":
			x = min_x + fx * fw
			y = min_y + fy * fh
		"tr":
			x = max_x - fx * fw
			y = min_y + fy * fh
		"br":
			x = max_x - fx * fw
			y = max_y - fy * fh
		_:  # bl
			x = min_x + fx * fw
			y = max_y - fy * fh
	return Vector2(clampf(x, min_x, max_x), clampf(y, min_y, max_y))


## Apply saved/default layout to a Control (top-left anchored).
static func apply(control: Control, section: String, vp_size: Vector2 = Vector2.ZERO) -> void:
	if control == null:
		return
	var vp := vp_size
	if vp.x <= 1.0 or vp.y <= 1.0:
		var v := control.get_viewport()
		if v != null:
			vp = v.get_visible_rect().size
	# Headless default window is 64×64 — treat as a desktop canvas for chrome.
	if vp.x < 400.0 or vp.y < 300.0:
		vp = Vector2(1280, 720)
	var layout := read_layout(section)
	var w: float = minf(float(layout["w"]), maxf(vp.x - rail_right - 16.0, 160.0))
	var h: float = minf(float(layout["h"]), maxf(vp.y - top_inset - bottom_inset - 16.0, 120.0))
	layout = layout.duplicate()
	layout["w"] = w
	layout["h"] = h
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.grow_horizontal = Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_END
	control.custom_minimum_size = Vector2(w, minf(h, 160.0))
	control.size = Vector2(w, h)
	var pos := position_for(layout, vp)
	control.position = pos
	control.offset_left = pos.x
	control.offset_top = pos.y
	control.offset_right = pos.x + w
	control.offset_bottom = pos.y + h


## From a control's current rect, pick nearest corner + fractions and save.
static func remember(control: Control, section: String) -> void:
	if control == null:
		return
	var v := control.get_viewport()
	if v == null:
		return
	var vp := v.get_visible_rect().size
	var r := control.get_global_rect()
	var w := maxf(r.size.x, 160.0)
	var h := maxf(r.size.y, 120.0)
	var min_x := rail_right
	var min_y := top_inset
	var max_x := maxf(vp.x - w - 4.0, min_x)
	var max_y := maxf(vp.y - h - bottom_inset, min_y)
	var cx := r.position.x + w * 0.5
	var cy := r.position.y + h * 0.5
	var mid_x := (min_x + max_x + w) * 0.5
	var mid_y := (min_y + max_y + h) * 0.5
	var corner := "bl"
	if cy < mid_y and cx < mid_x:
		corner = "tl"
	elif cy < mid_y:
		corner = "tr"
	elif cx >= mid_x:
		corner = "br"
	var fw := maxf(max_x - min_x, 1.0)
	var fh := maxf(max_y - min_y, 1.0)
	var fx := 0.0
	var fy := 0.0
	match corner:
		"tl":
			fx = (r.position.x - min_x) / fw
			fy = (r.position.y - min_y) / fh
		"tr":
			fx = (max_x - r.position.x) / fw
			fy = (r.position.y - min_y) / fh
		"br":
			fx = (max_x - r.position.x) / fw
			fy = (max_y - r.position.y) / fh
		_:
			fx = (r.position.x - min_x) / fw
			fy = (max_y - r.position.y) / fh
	save_section(section, corner, fx, fy, w, h)


## Wire a title Control as a drag handle. Returns the press callable bookkeeping.
static func enable_drag(panel: Control, handle: Control, section: String) -> void:
	if panel == null or handle == null:
		return
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	var state := {"dragging": false, "grab": Vector2.ZERO}
	handle.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					state["dragging"] = true
					state["grab"] = mb.global_position - panel.global_position
					handle.accept_event()
				elif state["dragging"]:
					state["dragging"] = false
					remember(panel, section)
					handle.accept_event()
		elif ev is InputEventMouseMotion and state["dragging"]:
			var mm := ev as InputEventMouseMotion
			var dest: Vector2 = mm.global_position - state["grab"]
			var v := panel.get_viewport()
			var vp := v.get_visible_rect().size if v != null else Vector2(1280, 720)
			var w := panel.size.x
			var h := panel.size.y
			dest.x = clampf(dest.x, rail_right, maxf(vp.x - w - 4.0, rail_right))
			dest.y = clampf(dest.y, top_inset, maxf(vp.y - h - bottom_inset, top_inset))
			panel.global_position = dest
			panel.position = dest
			panel.offset_left = dest.x
			panel.offset_top = dest.y
			panel.offset_right = dest.x + w
			panel.offset_bottom = dest.y + h
			handle.accept_event()
	)
