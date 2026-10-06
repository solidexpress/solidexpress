# Replan 11 WP10 — strip, timeline, save, and dimension UX

You are a BUILD agent. Implement only this WP. No C++. No checker. No fillet kernel.

Files and hunks:

| File | Hunks |
|---|---|
| `game/scripts/viewport_interaction.gd` | `_sync_strip_dressup_radius`; the sketch `KEY_DELETE` / `KEY_BACKSPACE` arm in `_sketch_input` (line 2642); `_commit_property_panel_on_deselect` |
| `game/scripts/property_panel.gd` | end of `open`; new `_unhandled_input` |
| `game/scripts/main.gd` | the `sketch_mode.cancelled` connect (line 895); `_open_document`; `_save_current` |
| `game/scripts/sketch_mode.gd` | end of `set_tool`; the two-circle arm of `_smart_dim_between` |

Rebase onto WP1, WP5, WP6, and WP9. Those own other functions in the same files. Do not edit `_on_default_view`, the Esc arm, `_show_dim_edit`, `_start_sketch_on_face`, or the support-face fields.

## Strip radius

`_sync_strip_dressup_radius` (line 4665) calls `set_value_no_signal` and leaves the line edit showing `0.0`. Enter then re-parses that text. After the `set_value_no_signal` line:

```gdscript
var le := _strip_radius.get_line_edit()
if le != null:
	le.text = str(_strip_radius.value) + " mm"
	le.caret_column = le.text.length()
```

The spin's `suffix` is already `mm`. Do not change the min, max, or the Enter handler.

## Delete

Only the sketch arm in `_sketch_input` (line 2642). The 3D arm at line 3526 calls `_delete_selection` and stays as it is.

```gdscript
KEY_DELETE, KEY_BACKSPACE:
	if not sketch_mode.delete_selected_constraint():
		var n := sketch_mode.delete_selected_entities()
		if n == 0:
			status.emit("Nothing to delete")
		else:
			status.emit("Deleted %d" % n)
```

`delete_selected_entities` emits `Sketch selection cleared` through the selection signal. The `Deleted %d` emit comes after that call returns, so it overwrites the cleared sentence. Zero stays `Nothing to delete`.

## Rect prompt

At the end of `set_tool`, after `tool_changed.emit`:

```gdscript
if t == Tool.RECT:
	status.emit("Rect — click 1 first corner, click 2 the opposite corner")
```

`start_jaw_tool` calls `set_tool(RECT)` and then `set_tool_variant("center_three_point")`, which emits `JAW_HINT`. Jaw still wins. Do not emit the Rect sentence from `set_tool_variant`.

## Smart Dim horizontal

Yes. In `_smart_dim_between`, in the two-circle / two-arc arm (line 3555), after both `_pin_circle_at_sketch_origin` calls and before `constrain("distance", ...)`:

```gdscript
var dxy := cb - ca
if absf(dxy.x) > 1e-9 and absf(dxy.y) <= tan(deg_to_rad(2.0)) * absf(dxy.x):
	var lid := sketch.add_line(ca.x, ca.y, cb.x, cb.y)
	sketch.set_construction(lid, true)
	sketch.add_constraint("coincident", [
		{"entity": ida, "role": "center"},
		{"entity": lid, "role": "start"}], 0.0)
	sketch.add_constraint("coincident", [
		{"entity": idb, "role": "center"},
		{"entity": lid, "role": "end"}], 0.0)
	sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
```

Then the existing `constrain("distance", ca.distance_to(cb))` and the edit emit. Both constraints stay. A second centre more than 2° off X does not get the construction line. `ConstraintType::Horizontal` applies to a line, which is why the helper line exists.

## Timeline panel

`PropertyPanel.open` (line 179) returns true after `visible = true` without focusing Distance. A single click on the extrude row uses this path. The double-click path in `timeline_panel.gd` already calls `focus_schema_key`. At the end of the successful `open` path, before `return true`:

```gdscript
if _params.has("distance"):
	focus_schema_key("distance")
```

`focus_schema_key` already grabs the line edit and queues `select_all`.

Esc while the panel is up must not depend on the viewport ladder. Add:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.pressed and ke.keycode == KEY_ESCAPE:
		cancel_edits()
		get_viewport().set_input_as_handled()
```

`cancel_edits` undoes the live previews and hides the panel.

A click that misses the solid currently calls `_commit_property_panel_on_deselect`, which calls `commit()`. Replace the body so a click outside the panel hides it and keeps the previews already applied:

```gdscript
func _commit_property_panel_on_deselect() -> void:
	var main_n := _find_main()
	if main_n == null or main_n.timeline == null:
		return
	var pp = main_n.timeline.property_panel
	if pp == null or not pp.visible:
		return
	pp.dismiss_keep_preview()
```

On `PropertyPanel`:

```gdscript
func dismiss_keep_preview() -> void:
	_close()
```

Do not call `commit()` and do not call `cancel_edits()` from that path. Typed Distance already previewed through `value_changed` stays. An unparsed line edit is not flushed; that is this path. Esc is the path that undoes.

## Sketch cancelled

Line 895. The finished signal stays `_on_sketch_session_ended` only.

```gdscript
sketch_mode.cancelled.connect(func() -> void:
	_on_sketch_session_ended()
	_on_status("Sketch cancelled")
)
```

`esc_keep_sketch` does not call `cancel()`, so "Tool dropped" and "Selection cleared" are not overwritten. An empty sketch's second Esc calls `cancel()` and the status becomes `Sketch cancelled`.

## Open and save

`_open_document` (line 2630). Discard was already confirmed by the caller. Cancel the session so it does not survive onto the loaded file. Do not call `exit_sketch` here; that would commit into the document being replaced.

```gdscript
func _open_document(path: String) -> void:
	if sketch_mode != null and sketch_mode.active:
		sketch_mode.cancel()
	if view.load_from(path):
		...
```

`_save_current` (line 3117), before `view.save`:

```gdscript
if sketch_mode != null and sketch_mode.active:
	sketch_mode.exit_sketch()
```

`exit_sketch` commits a sketch that has entities and cancels an empty one. WP9 writes support keys on that `graph_add_sketch` path.

## Test

`game/tests/run_rung01_replan11_ux.gd`. Boot main at 1280×800. Twelve `check()` calls, in this order:

1. `set_tool(RECT)` status is exactly `Rect — click 1 first corner, click 2 the opposite corner`.
2. `start_jaw_tool()` status is `JAW_HINT` (the constant on `SketchMode`). The Rect sentence does not stick.
3. Ground sketch, two circles, centres `(0,0)` r=5 and `(30, 0.4)` r=8. Call `_smart_dim_between` with the two centre picks the production path uses (`entity` plus `role` `center`). After `run_solve`, the second centre's y is within 0.05 of the first, and one construction line has a horizontal constraint.
4. A third circle at `(30, 20)` against the origin circle does not add a horizontal constraint (20° is past 2°).
5. Select one line, simulate the sketch Delete key the way the viewport handles it (`_sketch_input` or by calling the same branch). Status is `Deleted 1`. With nothing selected, status is `Nothing to delete`.
6. Arm fillet so the strip is visible (`ops_panel` pending `FILLET_EDGES`, radius 1). Set the line edit text to `0.0`, call `_sync_strip_dressup_radius`. The line edit text contains `mm` and is not `0.0`.
7. Insert a box, open the timeline, call `property_panel.open` on the primitive only if it has no `distance` key — then extrude a sketch 10 mm and `open` that extrude feature. After two frames the Distance line edit has `get_selected_text().length() > 0`.
8. With that panel visible and the Distance field focused, send `KEY_ESCAPE` through the viewport. The panel's `visible` is false.
9. Open the extrude panel again, change Distance via the spin so a preview exists (`_edits > 0`), then call `_commit_property_panel_on_deselect`. The panel is hidden and the distance param is still the previewed value (not undone).
10. `FilmUI.enter_sketch`, then `sketch_mode.cancel()`. Status is `Sketch cancelled`. `active` is false.
11. Start a sketch, `add_line(0, 0, 10, 0)`, set `current_path` to a temp `.sxp`, call `_save_current()`. The file's text contains a sketch feature (`"type": "sketch"` or the kernel's saved token — read the file and accept either `"sketch"`). The session is not active.
12. `exit_sketch` on a fresh sketch that has one line emits `Sketch saved` and the following status is not `Sketch cancelled` from that call. (The cancelled connect must not run on the finished path.)

Red on `b3161bba` before the product edit: checks 1, 3, 5, 6, 7, 9, and 10 fail. Check 2 passes (Jaw already emits `JAW_HINT`). Check 8 may already pass through `_gui_key`; if it passes on the baseline, keep the new `_unhandled_input` anyway and do not delete the check. Green line:

```
12 checks, 0 failures
```

Command:

```
LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_ux.gd
```

Do not commit `.gd.uid`.

## Do not

- Change `_fillet_all`, `_round_targets`, or the 3D Delete arm.
- Change `esc_keep_sketch`.
- Infer horizontal for a line-to-point dimension or for an angle.
- Call `exit_sketch` from `_open_document`.
