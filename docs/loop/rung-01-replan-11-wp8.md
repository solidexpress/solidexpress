# Replan 11 WP8 — typed across-flats hex stays horizontal

You are a BUILD agent. Edit only `game/scripts/sketch_mode.gd`:

- the `_length_override` block inside `click()` (around line 3030)
- the `Tool.POLYGON` block (around line 3089, `start_angle` at line 3104)
- the polygon branch of `_update_preview` (around line 5157)

Do not edit trim, dimension labels, or `begin`. Rebase onto WP4 and WP6; those hunks are elsewhere in the file.

## Behaviour

Across-flats only (`tool_variant == "across_flats"`, the default). Vertex mode is unchanged.

- Dragged second point: `start_angle = round(angle / deg_to_rad(30)) * deg_to_rad(30)`. Flats end horizontal or vertical, whichever is nearer.
- Typed AF (the length override consumed in `click`, including Enter in the AF field and `commit_at_length`): `start_angle = 0`. Vertices lie on ±X. Flats are the horizontal edges at y = ±AF/2. The pointer position does not rotate the hex.
- Status, both paths: `Polygon AF %.4f — flats horizontal` where the number is the AF (`drag`), not the circumradius.
- Preview uses the same snap while the pointer moves. When `_length_override >= 0` during preview, preview `start_angle` is 0.

## Code

Add a member next to `_length_override`:

```gdscript
var _point_from_length := false
```

In `click()`, where the override is applied (the block that starts `if _length_override >= 0.0 and has_single_dof_preview()`):

```gdscript
_point_from_length = false
if _length_override >= 0.0 and has_single_dof_preview():
	_point_from_length = true
	# ... existing body, unchanged ...
```

Clear `_point_from_length` at the start of `click()` as well, before the dimension-hit early return, so a normal click is not typed.

In the polygon block, replace `var start_angle := (vertex - c).angle()` and the across-flats radius rewrite with:

```gdscript
var start_angle := (vertex - c).angle()
if tool_variant == "across_flats":
	polygon_sides = 6
	r = drag / sqrt(3.0)
	if _point_from_length:
		start_angle = 0.0
	else:
		var step := deg_to_rad(30.0)
		start_angle = round(start_angle / step) * step
```

Replace the across-flats status emit in that block:

```gdscript
_last_commit_text = "Polygon AF %.4f — flats horizontal" % drag
status.emit(_last_commit_text)
```

In `_update_preview`'s polygon section, after computing `start_angle` from the pointer:

```gdscript
if tool_variant == "across_flats":
	if _length_override >= 0.0:
		start_angle = 0.0
	else:
		var step := deg_to_rad(30.0)
		start_angle = round(start_angle / step) * step
```

The existing `r = r / sqrt(3.0)` and `n = 6` stay.

## Test

`game/tests/run_rung01_replan11_poly.gd`. Boot main, `FilmUI.enter_sketch`, select Polygon (default variant is across_flats). 8 checks:

1. Centre click at `(0, 0)`, then `commit_at_length(20)` while the pointer is at 20° (move the mouse to `Vector2(18, 7)` before the commit, or set the hover so the direction is not along X). Status contains `flats horizontal` and contains `20`.
2. A polygon edge has both endpoints at the same y within 1e-3 and `|y|` within 0.05 of 10 (AF/2). That is a horizontal flat.
3. The bounding box in X is the across-corners size, about `20 / sqrt(3) * 2` = 23.094 ± 0.05, and the Y extent is 20 ± 0.05. (AF is the smaller extent.)
4. A dragged polygon whose second point is at angle 10° (not a multiple of 30) has `start` such that every edge is within 0.5° of horizontal or 60°. Compute edge angles from entity endpoints. At least one edge has `|dy| <= 1e-3` (a horizontal flat).
5. Dragged status also contains `flats horizontal`.
6. Vertex variant (`set_tool_variant("vertex")`) with a second point at 10° does **not** snap: some edge is more than 1° away from both 0° and 60°. Restore across_flats afterwards.
7. Typed AF 20, export is not required. The Y extent check above is the nut checker's AF. State in a comment that the GUI nut row uses this path.
8. `sketch_mode.tool_variant == "across_flats"` after `set_tool(POLYGON)` on a fresh sketch.

Green: `8 checks, 0 failures`.

Red on `b3161bba`: check 2 fails because `start_angle` is the pointer angle (about 20°), so no edge is horizontal. The Y extent is not 20.

`run_rung01_replan` polygon coverage in `run_sketch_tools_tests.gd` may assume the old status `Polygon AF %.4f` without the suffix. If that suite gains a failure whose expected string is exactly `Polygon AF`, update the expected string to contain `Polygon AF` and `flats horizontal`. Do not change a geometric assertion that was already correct for a dragged axis-aligned hex.

## Do not

- Snap vertex mode.
- Change the circumradius formula `drag / sqrt(3)`.
