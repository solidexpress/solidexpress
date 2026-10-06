# Replan 11 WP7 — Centerline chips stack under the Contours row

You are a BUILD agent. Edit only `game/scripts/sketch_context_chrome.gd`. Add `game/tests/run_rung01_replan11_chrome.gd`.

## The overlap

`refresh_contours` places `_contour_bar` at `_finish_bar_bottom() + 4` (line 1182). `place_variant_row` places `_variant_bar` at `_finish_bar_bottom() + CHIP_PAD` (6) (line 1288). Both use the same left edge. Chip height is `UiScale.px(28)`, so the rows occupy the same band at 1280×800. A click meant for Centerline hits Contour 1.

`_process` (line 1356) repositions the finish bar every frame and does not move the chip rows, so a one-time place drifts.

## The layout

Add one function and call it from `refresh_contours` (instead of the direct `_place_bar` at the end), from `place_variant_row` (instead of its own `_place_bar` + `_keep_variant_below_finish`), and from `_process` after `_place_finish_session`.

```gdscript
func _stack_sketch_rows() -> void:
	var x := _finish_session_pos().x
	var y := _finish_bar_bottom() + 4.0
	if _contour_bar != null and _contour_bar.visible:
		_place_bar(_contour_bar, Vector2(x, y))
		_contour_bar.reset_size()
		var h := maxf(_contour_bar.size.y, _contour_bar.get_combined_minimum_size().y)
		if h < 1.0:
			h = float(_chip_h())
		y += h + 4.0
	if _variant_bar != null and _variant_bar.visible:
		_place_bar(_variant_bar, Vector2(x, y))
	if _action_bar != null and _action_bar.visible:
		_action_bar.reset_size()
		var ah := maxf(_action_bar.size.y, _action_bar.get_combined_minimum_size().y)
		_place_bar(_action_bar, Vector2(x, y + float(_chip_h()) + 4.0))
		# Selection chips sit under the variant row, not on the contour row.
		if _variant_bar != null and _variant_bar.visible:
			var vh := maxf(_variant_bar.size.y, float(_chip_h()))
			_place_bar(_action_bar, Vector2(x, _variant_bar.position.y + vh + 4.0))
```

`_keep_variant_below_finish` may stay; `_stack_sketch_rows` is the authority. Do not change chip contents, the Centerline tool, or contour selection.

After stacking, the global rects of a visible contour bar and a visible variant bar must not intersect. Assert with `Rect2.intersects` and also reject a mere touch (`intersects` is true for a shared edge in Godot 4; inflate neither rect). If `intersects` is true, the test fails.

## Test

`game/tests/run_rung01_replan11_chrome.gd`. Boot main at `Vector2i(1280, 800)` via `FilmUI.ensure_test_viewport`. `FilmUI.enter_sketch`. Add two disjoint circles on the sketch (`sketch.add_circle`) so `contour_count() > 1`, call `refresh_contours` (or `_redraw` if that is what syncs the bar). Select the Line tool with `FilmUI.select_sketch_tool` so the Line/Centerline chips exist. Wait two frames so `_process` has stacked them.

6 checks:

1. Root size is 1280×800.
2. `_contour_bar.visible` is true.
3. `_variant_bar.visible` is true.
4. Both global rects have height ≥ 20.
5. The two global rects do not intersect.
6. The variant bar's `global_position.y` is greater than the contour bar's `global_position.y + size.y - 1` (it is strictly below).

Green: `6 checks, 0 failures`.

Red on `b3161bba`: checks 5 and 6 fail because both bars share `_finish_bar_bottom()`.

Also run `run_rung01_replan9_chip.gd`. It must stay at 0 failures. The Centerline chip must still highlight when the tool is Centerline (`sync_variant_highlight` is unchanged).

## Do not

- Hide the Contours row to avoid the overlap.
- Move the finish bar.
