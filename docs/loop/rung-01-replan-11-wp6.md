# Replan 11 WP6 — one click edits a dimension, including the angle; the floor is perpendicular

You are a BUILD agent. Two files, disjoint from the other viewport and sketch hunks:

- `game/scripts/sketch_mode.gd`: `_dimension_label_pos2`; `_rebuild_dimension_labels`; `dimension_hit`; the floor rewrite inside `_trim_open_jaw` starting at `_snap_jaw_hits_through_centre` (line 2466) through the perpendicular constraint. Do not change the cutter chooser above that line (WP4). Do not edit the `_length_override` block in `click()` (WP8 sets a flag there).
- `game/scripts/viewport_interaction.gd`: `_show_dim_edit` only (line 517). Do not touch the Esc arm (WP5) or the orientation popup (WP1).

Rebase onto WP4 if both are in flight. WP4 does not edit this region.

## Why the angle label missed

`dimension_hit` (line 4968) uses a 2.5 mm disk around `_dimension_label_pos2`. For an angle, that function uses `_closest_endpoints`. The jaw angle is between a construction +X datum and the wall; those lines do not share an endpoint, so the anchor is not where the glyphs are. `_rebuild_dimension_labels` then nudges overlapping labels by 2.5 mm and the hit test ignores the nudge. `Label3D` is fixed-size, so the glyphs extend past 2.5 mm when the sketch is zoomed out. A single click therefore misses. A double-click sometimes lands on the un-nudged anchor.

The 89.71° floor is not a PlaneGCS bug. Trim snaps the floor along the cutter (`_snap_jaw_hits_through_centre`) and then adds `perpendicular` (line 2518). The sx-031 floor was exactly 135° and the walls were 45.2868°, so the included angle was 89.71° while the constraint existed. The solver started from the cutter-locked floor and never reached 90°. Rewrite the floor geometry so it is already perpendicular, then add the constraint.

## 1. Angle anchor

In `_dimension_label_pos2`, before the generic two-id branch, handle angles:

```gdscript
if type == "angle" and ids.size() >= 2:
	var ia: Dictionary = sketch.entity_info(str(ids[0]))
	var ib: Dictionary = sketch.entity_info(str(ids[1]))
	if str(ia.get("type", "")) == "line" and str(ib.get("type", "")) == "line":
		var hit = _line_line_intersect(ia["start"], ia["end"] - ia["start"], ib["start"], ib["end"] - ib["start"])
		if hit != null:
			var da: Vector2 = (ia["end"] - ia["start"]).normalized()
			var db: Vector2 = (ib["end"] - ib["start"]).normalized()
			var bis := da + db
			if bis.length_squared() < 1e-8:
				bis = Vector2(-da.y, da.x)
			return (hit as Vector2) + bis.normalized() * (DIM_LABEL_OFFSET * 2.0)
```

`_line_line_intersect` is at line 2226 and returns a point or null. If it returns null, fall through to the existing closest-endpoint path.

## 2. Store the drawn position

In `_rebuild_dimension_labels`, after the overlap nudge and before creating the Label3D:

```gdscript
dim["label_pos"] = pos
```

`dim` is the dictionary inside `dimensions`. Writing the key updates it.

## 3. Hit test

Replace `dimension_hit`:

```gdscript
func dimension_hit(pos2: Vector2) -> int:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var screen := Vector2(INF, INF)
	if cam != null:
		screen = cam.unproject_position(to_model(pos2))
	var best := -1
	var best_px := 22.0
	var best_mm := 6.0
	for i in range(dimensions.size()):
		var dim: Dictionary = dimensions[i]
		var lp: Variant = dim.get("label_pos", null)
		if lp == null:
			lp = _dimension_label_pos2(dim)
		if lp == null:
			continue
		var p: Vector2 = lp
		var dmm := pos2.distance_to(p)
		var win := false
		if cam != null:
			var sp := cam.unproject_position(to_model(p))
			var dpx := screen.distance_to(sp)
			if dpx < best_px:
				best_px = dpx
				best = i
				win = true
		if not win and dmm < best_mm:
			best_mm = dmm
			best = i
	return best
```

Screen distance wins when it is under 22 px. Otherwise a 6 mm sketch-space disk around the stored point still hits. `click()` already calls `dimension_hit` before `snap_point` when the tool is Select or Smart Dim, and it emits `dimension_edit_requested`. Do not add a double-click requirement.

## 4. Popup

`_show_dim_edit`: the popup position must be in screen pixels, and the text must be selected.

```gdscript
var at := Vector2i(get_viewport().get_mouse_position()) + Vector2i(8, 8)
var win := get_window()
if win != null:
	at += win.position
_dim_edit_popup.popup(Rect2i(at, Vector2i(240, 40)))
```

The deferred `_focus_dim_edit_line_if_gen` already calls `select_all`. Leave that. Do not clear the text.

`set_dimension_value` already treats a number greater than π as degrees (`_dimension_display_value` shows degrees). Typing `45` and Enter must emit `Dimension updated` via the existing `_apply_dim_edit`. Do not change that function.

## 5. Floor perpendicular before solve

Inside `_trim_open_jaw`, immediately after `_snap_jaw_hits_through_centre(walls, cc, dir)` and the loop that writes `keep` and `set_entity_geometry`, the code builds `h0`, `h1` and `floor_id`. Before `sketch.add_line` for the floor, rebuild `h0` and `h1` so the floor is perpendicular to wall 0 and centred on `cc`:

```gdscript
var w0: Vector2 = walls[0]["keep"] - walls[0]["hit"]
if w0.length_squared() > 1e-8:
	var fdir := Vector2(-w0.y, w0.x).normalized()
	var across: Vector2 = walls[1]["hit"] - walls[0]["hit"]
	if fdir.dot(across) < 0.0:
		fdir = -fdir
	var half := across.length() * 0.5
	if half < 0.1:
		half = 10.0
	h0 = cc - fdir * half
	h1 = cc + fdir * half
	walls[0]["hit"] = h0
	walls[1]["hit"] = h1
	sketch.set_entity_geometry(str(walls[0]["id"]), {"start": h0, "end": walls[0]["keep"]})
	sketch.set_entity_geometry(str(walls[1]["id"]), {"start": h1, "end": walls[1]["keep"]})
```

Then the existing `add_line(h0, h1)` and the existing `perpendicular` constraint run on geometry that is already 90°. Do not remove the constraint. Do not change the angle constraint that follows (it records the wall's angle against the horizontal datum).

After `run_solve()` at the end of `_trim_open_jaw`, the included angle between wall 0 and the floor must be 90° ± 0.05°. If a later solve pulls it off, call `run_solve()` once more only — do not loop.

## Test

`game/tests/run_rung01_replan11_dim.gd`. Reuse the jaw builder from `run_rung01_replan10_trim.gd` (`_build_jaw` with offset 12). 11 checks:

1. After a successful trim, the absolute dot product of the wall-0 direction and the floor direction is ≤ sin(0.05°) (`abs(dot) <= 0.0009`).
2. Enter sketch, Smart Dim or the jaw's existing angle dimension: `dimension_hit` on the stored `label_pos` of the angle dimension returns that index, not -1.
3. `dimension_hit` on `label_pos + Vector2(0, 2.5)` still returns the angle index (the old test missed this).
4. Calling `_emit_dimension_edit` on that index makes `DimEditPopup` visible. One call, not two.
5. `DimEditLine.text` contains the current angle (the string starts with the displayed degrees, not empty, not `0`).
6. `DimEditLine` has a selection (`get_selected_text().length() > 0`) after two idle frames.
7. Submit `45` through `_apply_dim_edit("45")`. Status contains `Dimension updated`.
8. After that solve, the wall-to-horizontal angle is 45° ± 0.05°.
9. The wall-to-floor included angle is 90° ± 0.05°.
10. A linear width label (the distance dimension) also returns a non-negative `dimension_hit` at its `label_pos`.
11. Submitting that width's current value still returns `Dimension updated` (editing must work for linear labels, not only angles).

Green: `11 checks, 0 failures`.

Red on `b3161bba`: check 1 fails (included angle near 89.7° when the drawn jaw is not exactly 45°; build the rectangle at 45.3° so this is visible: use `JAW_DIR` rotated by 0.3° from 45°). Check 3 fails because the hit disk is 2.5 mm and the nudge equals the tolerance (`d < best_d` is strict). Check 6 fails if the popup never selects.

Also run `run_rung01_replan9_dim.gd` and `run_rung01_replan10_trim.gd`. Both stay at 0 failures. The floor rewrite must not turn a 12 mm cutter trim into `Trim failed`.

## Do not

- Change PlaneGCS or `solver_planegcs.cpp`.
- Require a double click.
- Edit the cutter chooser.
