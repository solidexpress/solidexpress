class_name SketchSplineEdit
extends RefCounted
## Fit-point / control-polygon editing for the interpolating sketch spline.
## Handles, comb, and tangent pins live here so sketch_mode only forwards.

const MODE_FIT := "fit"
const MODE_POLE := "pole"

var mode := MODE_FIT
var comb_on := false


func toggle_mode() -> String:
	mode = MODE_POLE if mode == MODE_FIT else MODE_FIT
	return mode


func set_mode(next: String) -> void:
	mode = MODE_POLE if next == MODE_POLE else MODE_FIT


func toggle_comb() -> bool:
	comb_on = not comb_on
	return comb_on


static func point_count(info: Dictionary) -> int:
	return int(info.get("point_count", (info.get("fit_points", []) as Array).size()))


func hit(info: Dictionary, pos2: Vector2, tol: float) -> Dictionary:
	if str(info.get("type", "")) != "spline":
		return {}
	var best := ""
	var best_d := tol
	var fits: Array = info.get("fit_points", [])
	var poles: Array = info.get("poles", [])
	if mode == MODE_FIT:
		for i in range(fits.size()):
			var d: float = pos2.distance_to(fits[i] as Vector2)
			if d <= best_d:
				best_d = d
				best = "fit:%d" % i
	else:
		for i in range(poles.size()):
			var d2: float = pos2.distance_to(poles[i] as Vector2)
			if d2 <= best_d:
				best_d = d2
				best = "pole:%d" % i
	var st: Vector2 = info.get("start", Vector2.ZERO) as Vector2
	var et: Vector2 = info.get("end", Vector2.ZERO) as Vector2
	var ts: Vector2 = info.get("start_tangent", Vector2.ZERO) as Vector2
	var te: Vector2 = info.get("end_tangent", Vector2.ZERO) as Vector2
	var d_ts: float = pos2.distance_to(st + ts)
	if d_ts <= best_d:
		best_d = d_ts
		best = "tan_start"
	var d_te: float = pos2.distance_to(et + te)
	if d_te <= best_d:
		best = "tan_end"
	if best == "":
		return {}
	return {"part": best}


static func apply_drag(orig: Dictionary, part: String, pos2: Vector2) -> Dictionary:
	var out: Dictionary = orig.duplicate(true)
	if part.begins_with("fit:"):
		var i := int(part.substr(4))
		var fits: Array = out.get("fit_points", []).duplicate()
		if i >= 0 and i < fits.size():
			fits[i] = pos2
			out["fit_points"] = fits
			out["fit_index"] = i
			out["fit_pos"] = pos2
	elif part.begins_with("pole:"):
		var j := int(part.substr(5))
		out["pole_index"] = j
		out["pole_pos"] = pos2
	elif part == "tan_start":
		var st: Vector2 = orig.get("start", Vector2.ZERO) as Vector2
		out["start_tangent"] = pos2 - st
		out["tangent_start_on"] = true
	elif part == "tan_end":
		var et: Vector2 = orig.get("end", Vector2.ZERO) as Vector2
		out["end_tangent"] = pos2 - et
		out["tangent_end_on"] = true
	return out


static func property_label(info: Dictionary) -> String:
	return "Spline: %d fit points" % point_count(info)
