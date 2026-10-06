# Replan 11 WP5 — Esc drops the first point before the measure anchor

You are a BUILD agent. Edit only the `KEY_ESCAPE` arm inside `ViewportInteraction._sketch_input` (`game/scripts/viewport_interaction.gd`, lines 2646-2669). Add `game/tests/run_rung01_replan11_esc.gd`.

Do not edit `_rebuild_orient_popup` (WP1), `_show_dim_edit` (WP6), `_sync_strip_dressup_radius` or the Delete key (WP10). If those hunks are already in your tree, leave them.

## The bug

A Circle centre click calls `sketch_mode.click`, which appends the first point (`has_pending_draw_point()` is true for Circle, Line, Centerline, Rect, Polygon, Slot, Ellipse, Arc). The motion that preceded the click often sets `measure_overlay.anchor_point` via `_update_sketch_measure`. The Esc arm tests `has_anchor()` first, so the first press emits `Measure cleared` and the draw point stays. Exiting then takes three presses.

## The change

Move the pending-draw rung above the measure-anchor rung. On that press, clear the measure anchor too.

```gdscript
KEY_ESCAPE:
	if sketch_mode.has_pending_draw_point():
		if measure_overlay != null and measure_overlay.has_anchor():
			measure_overlay.clear_pair()
		sketch_mode.cancel_pending_draw()
		status.emit("First point dropped — Esc again exits the sketch")
	elif measure_overlay != null and measure_overlay.has_anchor():
		measure_overlay.clear_pair()
		status.emit("Measure cleared")
	elif sketch_mode.has_length_override():
		sketch_mode.clear_length_override()
		status.emit("Length unlock")
	elif sketch_mode.has_open_chain():
		sketch_mode.end_chain()
		status.emit("Chain ended")
	elif sketch_mode.has_pending_dim_pick():
		sketch_mode.cancel_pending_dim_pick()
		status.emit("Smart Dim pick dropped — Esc again exits the sketch")
	else:
		var kept := sketch_mode.esc_keep_sketch()
		if kept != "":
			status.emit(kept)
		else:
			sketch_mode.cancel()
```

`cancel_pending_draw` already clears `_tool_points`. Do not change it. The second press, with no pending point, hits `esc_keep_sketch`. An empty new sketch with the Select tool returns `""` and `cancel()` exits. A sketch that already has geometry and a draw tool active returns `Tool dropped — Esc again exits the sketch` (replan 10, keep it). So "exactly two presses to exit" holds for a first point in an otherwise empty sketch: press 1 drops the point, press 2 exits. In a sketch that already has the jaw, press 2 drops the tool and press 3 exits; that is the existing ladder and must stay. The sx-031 failure was the empty-sketch Circle case (three presses because Measure cleared stole the first one).

## Test

`game/tests/run_rung01_replan11_esc.gd`. Boot main at 1280×800 the same way as `run_rung01_replan10_esc.gd` (`FilmUI.enter_sketch`). For each tool in Circle, Line, Rect, Polygon:

1. Select the tool with `FilmUI.select_sketch_tool`.
2. Click once on the canvas (`FilmUI.click_sketch`).
3. Force a measure anchor the way a real motion does: `ctx.main.measure_overlay.anchor_point = Vector3.ZERO` and `anchor_entity` if that field exists, or call `update_sketch_hover` on an existing entity. If the click already set an anchor, leave it.
4. Push `KEY_ESCAPE` through the viewport (`push_input` on the viewport, pressed, not echo).
5. Assert status is exactly `First point dropped — Esc again exits the sketch`.
6. Assert `measure_overlay.has_anchor()` is false.
7. Assert `sketch_mode.has_pending_draw_point()` is false and `sketch_mode.active` is true.
8. Push Esc again. Assert `sketch_mode.active` is false.

That is 4 tools × 2 checks after the first Esc (status + anchor cleared) plus one "still active" shared and one "exited" per tool. Write exactly these 10 checks so the summary is stable:

1. Circle: first Esc text is `First point dropped — Esc again exits the sketch`.
2. Circle: anchor is clear.
3. Circle: sketch still active.
4. Circle: second Esc leaves the sketch.
5. Line: first Esc is `First point dropped`.
6. Line: second Esc exits. (Re-enter the sketch between tools.)
7. Rect: first Esc is `First point dropped`.
8. Rect: anchor clear and sketch still active.
9. Polygon: first Esc is `First point dropped`.
10. Polygon: second Esc exits.

Green: `10 checks, 0 failures`.

Red on `b3161bba`: the Circle row's first status is `Measure cleared` whenever the anchor was set. Set the anchor explicitly before Esc so the red result does not depend on hover.

Also run, and do not edit unless a row fails for the reason below:

```
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan10_esc.gd
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_esc.gd
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dim.gd
```

Expected: replan10 esc `25 checks, 0 failures`. The other two stay at 0 failures at whatever check count they print today.

Update one of those files only if it plants a pending draw point and an anchor and asserts the first Esc is `Measure cleared`. Change that expected string to `First point dropped — Esc again exits the sketch` and assert the anchor is clear. Say so in the commit message. Do not change a row whose sketch has an anchor and no pending draw point: that row must still see `Measure cleared`.

## Do not

- Remove the measure-anchor rung.
- Change `esc_keep_sketch`.
