# Replan 11 WP4 — trim cutter crosses the jaw

You are a BUILD agent. Edit only `game/scripts/sketch_mode.gd`, and only these functions: new helpers next to `_nearest_construction_line`, the cutter choice at the start of `_trim_open_jaw`, the `walls.size() != 2` refusal, and `toggle_construction_selected`.

Do not edit `_snap_jaw_hits_through_centre` or anything after the walls are collected. WP6 owns the floor rewrite from that call downward. Do not edit the polygon block (WP8) or `begin` (WP9).

The replan-10 success path stays: a single cross-jaw cutter still emits `Trimmed open jaw`, and a second click emits `Jaw is already open — nothing left to trim here`. `run_rung01_replan10_trim.gd` must stay `38 checks, 0 failures`.

## Cutter choice

`_trim_open_jaw` (line 2389) starts with:

```gdscript
var cutter := _nearest_construction_line(pos2, 40.0)
```

Replace that one line with:

```gdscript
var cutter := _jaw_cutter_for_click(pos2)
```

Add the helpers above `_trim_open_jaw`. They use `_dirs_within_deg`, `_longest_profile_dir`, `_point_line_distance`, and `_point_segment_distance`, which already exist.

```gdscript
## Two longest non-construction lines within 2° of the longest profile line.
func _jaw_long_sides() -> Array:
	var dir := _longest_profile_dir()
	if dir.length_squared() < 1e-8:
		return []
	var sides: Array = []
	for id in sketch.entity_ids():
		if sketch.is_construction(id):
			continue
		var info: Dictionary = sketch.entity_info(id)
		if str(info.get("type", "")) != "line":
			continue
		var a: Vector2 = info["start"]
		var b: Vector2 = info["end"]
		var d := b - a
		if d.length() < 1.0:
			continue
		if not _dirs_within_deg(d, dir, 2.0):
			continue
		sides.append({"id": id, "a": a, "b": b, "len": d.length()})
	sides.sort_custom(func(x, y): return float(x["len"]) > float(y["len"]))
	if sides.size() > 2:
		sides = sides.slice(0, 2)
	return sides


## Proper segment-segment intersection, or null.
func _segment_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	var r := b - a
	var s := d - c
	var denom := r.x * s.y - r.y * s.x
	if absf(denom) < 1e-9:
		return null
	var t := ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / denom
	var u := ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / denom
	if t < -1e-4 or t > 1.0 + 1e-4 or u < -1e-4 or u > 1.0 + 1e-4:
		return null
	return a + r * t


func _cutter_crosses_both_sides(a: Vector2, b: Vector2, sides: Array) -> bool:
	if sides.size() != 2:
		return false
	return _segment_intersect(a, b, sides[0]["a"], sides[0]["b"]) != null \
			and _segment_intersect(a, b, sides[1]["a"], sides[1]["b"]) != null


func _jaw_aabb_expanded(sides: Array, pad: float) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for s in sides:
		mn = mn.min(s["a"]).min(s["b"])
		mx = mx.max(s["a"]).max(s["b"])
	return Rect2(mn - Vector2(pad, pad), (mx - mn) + Vector2(pad, pad) * 2.0)


## True when this line is a jaw cutter candidate: crosses both long sides,
## or runs along the jaw inside the jaw box.
func _line_is_jaw_cutter_candidate(a: Vector2, b: Vector2, sides: Array) -> bool:
	if sides.size() != 2:
		return false
	var dir: Vector2 = sides[0]["b"] - sides[0]["a"]
	if _cutter_crosses_both_sides(a, b, sides):
		return true
	var mid := (a + b) * 0.5
	return _dirs_within_deg(b - a, dir, 2.0) and _jaw_aabb_expanded(sides, 2.0).has_point(mid)


func _jaw_cutter_for_click(pos2: Vector2) -> Dictionary:
	var sides := _jaw_long_sides()
	var jaw_dir := _longest_profile_dir()
	var best: Dictionary = {}
	var best_d := INF
	if sides.size() == 2:
		for id in sketch.entity_ids():
			if not sketch.is_construction(id) or _angle_datum_lines.has(id):
				continue
			var info: Dictionary = sketch.entity_info(id)
			if str(info.get("type", "")) != "line":
				continue
			var a: Vector2 = info["start"]
			var b: Vector2 = info["end"]
			if jaw_dir.length_squared() > 1e-8 and _dirs_within_deg(b - a, jaw_dir, 2.0):
				continue
			if not _cutter_crosses_both_sides(a, b, sides):
				continue
			var d := _point_segment_distance(pos2, a, b)
			if d < best_d:
				best_d = d
				best = {"id": id, "a": a, "b": b}
	if not best.is_empty():
		return best
	return _nearest_construction_line(pos2, 40.0)
```

## Refusal

At the `walls.size() != 2` return (line 2460), replace the emit with:

```gdscript
if walls.size() != 2:
	var a: Vector2 = cutter["a"]
	var b: Vector2 = cutter["b"]
	status.emit("Trim failed — the construction line nearest your click runs along the jaw (from %.1f,%.1f to %.1f,%.1f); draw a centreline across the jaw or delete the along-jaw line" % [a.x, a.y, b.x, b.y])
	return true
```

Also replace the earlier parallel-cutter return (`Trim failed — draw the centreline across the jaw`, around line 2411) with the same sentence, using that cutter's endpoints. One sentence, so a test can match `runs along the jaw`.

Leave `Jaw is already open — nothing left to trim here` and `Trimmed open jaw` exactly as they are.

## Toggle / Construction chip / X key

`toggle_construction_selected` (line 2938) is the only production path for the chip and for X. When the call turns at least one line on, and a jaw exists, delete other jaw-candidate construction lines. Do **not** call `_delete_other_non_datum_construction_lines` from here.

After the loop that flips flags, before `_redraw()`:

```gdscript
var removed := 0
if any_on:
	var sides := _jaw_long_sides()
	if sides.size() == 2:
		var drop: Array[String] = []
		for id in sketch.entity_ids():
			if id in selected:
				continue
			if not sketch.is_construction(id) or _angle_datum_lines.has(id):
				continue
			var info: Dictionary = sketch.entity_info(id)
			if str(info.get("type", "")) != "line":
				continue
			if _line_is_jaw_cutter_candidate(info["start"], info["end"], sides):
				# Only drop when the line we just turned on is itself a jaw candidate.
				var turned_on_is_candidate := false
				for sel in selected:
					if not sketch.is_construction(sel):
						continue
					var si: Dictionary = sketch.entity_info(sel)
					if str(si.get("type", "")) != "line":
						continue
					if _line_is_jaw_cutter_candidate(si["start"], si["end"], sides):
						turned_on_is_candidate = true
				if turned_on_is_candidate:
					drop.append(id)
		for id in drop:
			sketch.remove_entity(id)
			removed += 1
if removed > 0:
	status.emit("Removed %d jaw construction line(s) — one cutter at a time" % removed)
else:
	status.emit("Construction " + ("on" if any_on else "off"))
```

A construction line that does not cross the jaw and is not along the jaw inside the jaw box is never deleted. The Centerline tool's call at line 3071 stays.

## Test

`game/tests/run_rung01_replan11_trim.gd`. Build the jaw the way `run_rung01_replan10_trim.gd` does (`_build_jaw` in that file: hole, Ø45 head, 20 mm rectangle at 45°, perpendicular cutter). Then add a second construction line along the jaw, closer to the shaft-side click than the cross-jaw cutter is. Call `trim_at` on the shaft-side point (validation; the geometry is what is under test). 12 checks.

Required assertions:

1. With both construction lines present, `trim_at` status contains `Trimmed open jaw`.
2. Status does not contain `does not cross two jaw sides`.
3. The along-jaw construction line is still in the sketch if it was not the chosen cutter (it must not have been used).
4. Profile is closed (`SketchMode.profile_is_closed`).
5. A second `trim_at` contains `Jaw is already open`.
6. Delete the cross-jaw cutter, leave only the along-jaw line, `trim_at` status contains `runs along the jaw` and contains `delete the along-jaw line`.
7. Profile is not closed after that refusal.
8. A sketch with a construction line far from the jaw (a 10 mm line at `(0, 40)`–`(10, 40)`) plus a jaw and a cross-jaw cutter: toggling the cross-jaw profile line... simpler: select the along-jaw construction line is already construction. Select a new profile line that crosses the jaw, call `toggle_construction_selected`, and assert the previous along-jaw construction line is gone and the status contains `Removed 1 jaw construction line`.
9. A construction line at `(0, 80)`–`(30, 80)` survives that toggle.
10. `run` still emits `Construction on` when the toggle is outside a jaw (no long sides). Build a sketch with one line only, toggle it, status is `Construction on`, entity count unchanged aside from the flag.
11. Datum lines in `_angle_datum_lines` are not removed. If the jaw trim has not created one yet, add a construction line, put its id in `_angle_datum_lines`, toggle another jaw line to construction, and assert the datum id still exists.
12. `FilmUI.fail_count == 0` if you click; if the test calls `trim_at` directly, this check is `true` with the note `validation path`.

Green: `12 checks, 0 failures`.

Red on `b3161bba`: assertion 1 fails with `Trim failed — centreline does not cross two jaw sides` because `_nearest_construction_line` picks the along-jaw line. Assertion 6 fails because the old text is `draw the centreline across the jaw` or `does not cross two jaw sides`, which does not contain `delete the along-jaw line`.

Also run:

```
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan10_trim.gd
```

Expected: `38 checks, 0 failures`.

## Do not

- Change `JAW_CUTTER_MAX_RIM_FRACTION` or the cap-circle gate.
- Delete construction geometry that fails `_line_is_jaw_cutter_candidate`.
