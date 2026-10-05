# Rung 1 replan 8 — name the jaw, connect the blank with one chip, refuse the wrecking cut

Status: plan only. No product code in this change.

Baseline: `main` at `33672f7b` (merge of #95; replan 7 WP1–WP4 are all in). Replan 7 is [`rung-01-replan-7.md`](rung-01-replan-7.md). The sx-028 critique of that build scored **6/10** and failed rung 1. Symptom list: [`rung-01-leftovers-sx028.md`](rung-01-leftovers-sx028.md).

Every claim below was measured on `33672f7b` on a VM with Godot 4.7-stable and OCCT 8.0.1, headless, at 1280×800. Every code block in the WPs was run: the product diffs, the five new test files, the lint and Makefile edits and the walk edit were applied together, the whole `game/tests/run_*.gd` list was run before and after, and `run_rung01_wrench.gd` printed `397 checks, 0 failures` with the real `check_rung01.py` inside it (nut 7/7, wrench 28/28, thick 4/4). The BUILD agent copies, it does not design.

BUILD agents execute one WP each. WP1–WP4 touch different functions and merge in any order; `game/scripts/main.gd` and `game/scripts/sketch_mode.gd` are edited by more than one of them in different hunks, so rebase on `main` before opening the PR and re-run your WP's test. WP5 (the walk) merges last, rebased on `main` after WP1–WP4. Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1. Set `LD_LIBRARY_PATH=<occt prefix>/lib` (for example `/opt/occt-8.0.1/lib`) before every Godot command or `libsxcore.so` does not load.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and gets what the checker wants:

- The sketch rail shows a text label under every icon, and has a `Jaw` button. Pressing it selects the Rectangle tool in its `Center Three Point` variant and says what the three clicks are. Nobody has to know that the jaw is a rectangle variant.
- After the two bosses are dimensioned, one chip, `Shaft Lines`, adds the two lines that join the Ø20 pivot circle to the Ø45 head (parallel to the centre line, tangent to the Ø20, ending on the Ø45). The blank is then one connected solid, not two discs, without typing a number or drawing a line.
- A cut that would remove more than half of the body, or nothing at all, is refused with a named status and rolled back. The sketch stays open so the contour can be fixed. The body is never left mangled.
- `Esc` with one point placed drops the point and keeps the sketch. A second `Esc` exits.
- The headless walk uses the `Jaw` rail button and the `Shaft Lines` chip, so what it does is what a person can do.

Checker commands on files the export dialog wrote (all unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf               # 5/5, run right after Extrude 10
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Do not pass `--allow-mirror`. Exit code 0 is the pass.

**Pass bar (unchanged).** Rung 1 is done when sx-029 follows the checklist at the end of this file, the four checker commands pass on files exported from the GUI (nut 7/7, blank 5/5, wrench 28/28, thick 4/4), `run_rung01_wrench.gd` prints 0 failures, the part was made in the real GUI without `select_entity` or any other script-side shortcut, and the score is at least 9.

## What the investigation found

### F1. P1 — the jaw is reachable only through a chip nobody can find

Code:

- `game/scripts/main.gd` `_build_ui` builds the sketch rail with `UIIcons.button(entry[1], "", entry[2])`: icon only, the name only in a tooltip. Four glyph names are shared: `circle` (Circle and Ellipse), `rect` (Rectangle and Slot), `dimension` (Smart Dimension and Auto-define). A person cannot tell the pairs apart without hovering.
- The jaw exists as `SketchMode.variants_for_tool(Tool.RECT)` → `Center Three Point`, a chip that appears beside the rail only after Rectangle is pressed. `FilmUI._find_button_match` finds buttons by text or tooltip, so the headless walk finds the chip. A human looking for "jaw" finds nothing: WALK_LOG B2.4 says "No jaw / Center-Three-Point-jaw tool found (rail, Insert menu, scrolled rail; Circle only offers Center/Perimeter/Three Point)".

Measured on `33672f7b`: the new rail test (`run_rung01_replan8_rail.gd`, WP1) prints `87 checks, 39 failures` plus `SCRIPT ERROR: Cannot call method 'get_global_rect' on a null value.` (no `Jaw` button to click). Every rail button has an empty `text`; only the 44 px column keeps the layout suites quiet (they stay green with labels: `run_layout_tests` 33/0, `run_rung01_replan2_layout` 22/0 after WP1).

### F2. P1 — the blank has no one-action way to get its shaft, and the shaft is not a common tangent

Code: the headless walk draws each shaft line with five clicks (`_draw_shaft_line`: zoom, click 0.3 mm off the contact, zoom, click, right-click). WALK_LOG B1.4: "Two tangent lines: NOT DONE (skipped to reach SPOT-93; line/tangent input not attempted)". The result in the GUI was `Extrude Blind 10.0000 mm (two discs, no web)`.

Two measured facts shape the fix:

1. The lines the handout needs are **not** the outer common tangents of the two circles. They are parallel to the centre line at y = ±10 (tangent to the Ø20 at its top and bottom) and end on the Ø45 at x = 200 − √(22.5² − 10²) = 179.844. The checker row `R10 fillet not oversized (174,12.5)` requires that point to be outside the solid; with common tangents the half-width at x = 174 is 10 + 12.5·174/200 = 20.9, so it is inside and the row fails. Measured volumes after Extrude 10: 53127.99 mm³ for the handout shape, 74649.9 mm³ for the common-tangent web.
2. After `Smart Dimension` between the two centres, **both circles are still selected** (measured: `selected.size() == 2` entering the shaft step of the walk). Pressing Select and clicking the two circle edges therefore *toggles them off*: the first click leaves one selected, the second leaves none and the status reads `Sketch selection cleared`. The walk step must click empty canvas first. A human who simply keeps the selection sees the chip right away.

Product facts used: `SketchMode._infer_line(lid, a, b)` adds `horizontal`, `tangent` (to the circle the first end touches) and a distance-to-centre constraint (the second end on the other circle), exactly what a hand-drawn shaft line gets. Calling it from a chip gives identical constraints. Measured on the chip's output: constraints `horizontal`, `tangent`, `distance 10` (start to Ø20 centre), `distance 22.5` (end to Ø45 centre) per line; `profile_is_closed` true; `Extrude Blind 10` gives bbox (−10, −22.5, 0)–(222.5, 22.5, 10), one body; `check_rung01.py blank` 5/5.

### F3. P2 — a cut that boolean-succeeds can wreck the body, and nothing says so

`FeatureGraph::apply` (`sxkernel/src/features.cpp`) accepts any valid result of the cut. It does not judge the volume. The GUI walk (WALK_LOG B2.6) cut with Up To Surface on a wrong contour set and got a body whose bbox label went 232.44 → 210.30 and whose export spanned X 1.20..145.16: a valid solid, no error. Measured on `33672f7b` with a 10 mm Ø100 disc and a Ø90 circle drawn on its top face (cut, blind): the cut succeeds and leaves 14922.6 mm³ of 78539.8 (81 % gone). A circle drawn off the body (centre (200, 0), r 5) also "succeeds" and adds a cut feature that removes nothing.

The guard goes in the GUI path (`SketchMode.finish_extrude`), where the sketch session is still open, not in the kernel, because a person can fix the contour and press Extrude again, and because kernel cuts through programmatic callers (thickness edits, replay) must keep behaving as they do. Thresholds: remove more than 50 % of the body, or less than 0.001 mm³, is refused. The walk's own hole, jaw and slot cuts all pass the guard (the walk is green with it in: 397/0), and the whole `game/tests/run_*.gd` list is unchanged with the guard in (table below).

### F4. P2 — Esc and the face pick

- Real bug: `Esc` with a circle's first point placed fell through to `SketchMode.cancel()` and **discarded the whole sketch** (WALK_LOG B1.1: "Esc during rubber-band EXITED the sketch entirely"). Only an open Line chain was protected. Measured on `33672f7b`: `run_rung01_replan8_esc.gd` prints `20 checks, 3 failures` — the failures are `Esc with a pending first point keeps the sketch open`, the status text, and the fresh two-click circle that follows.
- Not reproducible in the headless scene: `Esc` after Extrude clears the body selection (measured: `selected_body` goes from the new body to `""`, with and without a focused button; `cancel_stack` in `viewport_interaction.gd`). The one-click path from replan 7 (palette `Sketch` with nothing selected, then ONE click on the top face) passes (`run_rung01_replan7_facepick.gd` 31/0, repeated in the new esc test).
- The sx-028 status text `Face — click selects body first, click again for face · then Pull arrow` is the **hover** hint (`ViewportInteraction._update_hover`), not a selection result; the hover highlight also tints the body. So "click 1" in SPOT-93 B2.1 may have been only a hover. SPOT-93 B2.2 (second click still selects the body, third selects the face) is what two real clicks do if the first one was lost. Soft-GL drops clicks (F5). The plan therefore does not change `select_ray`; it keeps the replan-7 one-click path as the documented human route and adds an assertion on it (WP4).

### F5. P2 — soft-GL field typing (environmental)

Digits drop or reorder on llvmpipe (`10` → `0.01`). It is not a product bug and no product code is planned for it. What the plan does about it: (a) the blank no longer needs any typed number after the two circles, because `Shaft Lines` replaces the drawn lines (WP2); (b) the walker protocol below, which is the same rule the headless walk already follows; (c) `Auto Dim` and the mouse-drawn circle remain available when a field refuses to take a value.

### F6. Carries

- Timeline Distance 14: headless `thick` is 4/4; the GUI re-test is a row in the sx-029 checklist (steps below).
- Dim auto-popup after the second centre pick: the headless walk asserts the popup is visible after the second centre click. Flaky in the GUI; observed, not planned (below).

## Work packages

| WP | What | Files | Test | Red on `33672f7b` | Green after |
|---|---|---|---|---|---|
| WP1 | Rail text labels; `Jaw` button; Center Three Point hint | `game/scripts/main.gd`, `game/scripts/sketch_mode.gd` | `run_rung01_replan8_rail.gd` (new) | 87 checks, 39 failures + 1 script error | 89 checks, 0 failures |
| WP2 | `Shaft Lines` selection chip | `game/scripts/sketch_mode.gd`, `game/scripts/main.gd` | `run_rung01_replan8_shaft.gd` (new) | 33 checks, 16 failures | 37 checks, 0 failures |
| WP3 | Named refusal for a cut that removes >50 % or ~0 | `game/scripts/sketch_mode.gd` | `run_rung01_replan8_cut.gd` (new) | 13 checks, 7 failures | 13 checks, 0 failures |
| WP4 | `Esc` drops a pending first point; regression on Esc-after-Extrude and the one-click face | `game/scripts/viewport_interaction.gd`, `game/scripts/sketch_mode.gd` | `run_rung01_replan8_esc.gd` (new) | 20 checks, 3 failures | 20 checks, 0 failures |
| WP5 | Walk uses `Jaw` and `Shaft Lines`; lint and Makefile cover replan 8 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | the walk | 391 checks, 0 failures | 397 checks, 0 failures |

Order of work: WP1, WP2, WP3, WP4 in any order, each its own PR; WP5 last. Product fixes come before the walk. If any of WP1–WP4 is not merged, WP5 does not start.

How each new test was measured red: the same file was copied into a tree at `33672f7b` (no product change) and run; the red counts above are those runs. The `shaft` count includes the `check_rung01.py blank` row, which fails there for lack of a connected blank.

All four new tests use the same `FilmUI` rules the walk uses: sketch clicks are pushed as motion + press + release with no `await` between press and release, nothing calls `select_entity`, and `tools/lint_rung01_e2e.py` (extended in WP5) is clean on them.

---

### WP1 — Rail labels and the `Jaw` button

**Files.** `game/scripts/main.gd` (`_build_ui`, the sketch rail loop), `game/scripts/sketch_mode.gd` (`start_jaw_tool`, `set_tool_variant`, the `JAW_HINT` constant), new `game/tests/run_rung01_replan8_rail.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan8_rail.gd` with exactly this content.

```gdscript
# Rung 1 replan 8 WP1 — every sketch rail tool shows a text label; Jaw starts the Center Three Point rectangle.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_rail.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

const RAIL_LABELS := ["Exit Sketch", "Select", "Line", "Arc", "Circle", "Rect", "Jaw", "Polygon",
		"Ellipse", "Slot", "Spline", "Point", "Trim", "Extend", "Smart Dim", "Convert", "Mirror",
		"Pattern", "Auto Dim"]

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan8 WP1 rail labels and Jaw")
	FilmUI.reset_fail_count()
	await test_rail()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_rail() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var rail: Control = ctx.main.sketch_toolbar
	check(sm.active and rail.is_visible_in_tree(), "sketch rail is visible in a sketch")

	var texts: Array[String] = []
	for b in rail.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn is OptionButton or btn is CheckBox:
			continue
		texts.append(btn.text)
		check(btn.icon != null, "rail button '%s' has an icon" % btn.text)
		check(btn.tooltip_text != "", "rail button '%s' has a tooltip" % btn.text)
	for label in RAIL_LABELS:
		check(texts.has(label), "rail shows the text label '%s'" % label)
	check(texts.size() == RAIL_LABELS.size(),
			"rail has %d labelled buttons (got %d)" % [RAIL_LABELS.size(), texts.size()])

	var by_tool := {
		SketchMode.Tool.SELECT: "Select", SketchMode.Tool.LINE: "Line",
		SketchMode.Tool.ARC: "Arc", SketchMode.Tool.CIRCLE: "Circle",
		SketchMode.Tool.RECT: "Rect", SketchMode.Tool.POLYGON: "Polygon",
		SketchMode.Tool.ELLIPSE: "Ellipse", SketchMode.Tool.SLOT: "Slot",
		SketchMode.Tool.SPLINE: "Spline", SketchMode.Tool.POINT: "Point",
		SketchMode.Tool.TRIM: "Trim", SketchMode.Tool.EXTEND: "Extend",
		SketchMode.Tool.SMART_DIM: "Smart Dim", SketchMode.Tool.CONVERT: "Convert",
		SketchMode.Tool.MIRROR: "Mirror", SketchMode.Tool.PATTERN: "Pattern",
	}
	for tool in by_tool:
		var want: String = by_tool[tool]
		await FilmUI.select_sketch_tool(ctx, sm, tool)
		var found := _rail_button_for(ctx, tool)
		check(found != null and found.text == want,
				"FilmUI resolves tool %s to the rail button '%s'" % [str(tool), want])

	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
	check(jaw != null and jaw.name == "JawTool", "Jaw button is on the rail")
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	check(sm.tool_variant == "corner", "Rect starts as the corner rectangle")
	await _x11_click(jaw)
	await process_frame
	await process_frame
	check(sm.tool == SketchMode.Tool.RECT, "Jaw selects the Rectangle tool")
	check(sm.tool_variant == "center_three_point", "Jaw selects the Center Three Point variant (got %s)" % sm.tool_variant)
	check(_status_has("Jaw — click 1 centre, click 2 end of the long side, click 3 half the width"), "Jaw status explains the three clicks")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
	check(chip != null and chip.is_visible_in_tree(), "Center Three Point chip is visible after Jaw")

	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	var along := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
	var across := Vector2(-along.y, along.x)
	var vp: Viewport = ctx.main.get_viewport()
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, along * 30.0)
	await _click_uv(ctx, vp, across * 10.0)
	await process_frame
	var lines := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	check(lines == 4, "three Jaw clicks make a four-line rectangle (got %d)" % lines)
	var width := _distance_near(sm, 20.0)
	check(width >= 0, "the jaw width dimension reads 20")

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Rect"))
	await process_frame
	check(sm.tool_variant == "corner", "Rect resets the variant to corner after Jaw")
	await _shutdown(ctx)


func _rail_button_for(ctx: FilmContext, tool: int) -> Button:
	var label := ""
	match tool:
		SketchMode.Tool.SELECT: label = "Select"
		SketchMode.Tool.LINE: label = "Line"
		SketchMode.Tool.ARC: label = "Arc"
		SketchMode.Tool.CIRCLE: label = "Circle"
		SketchMode.Tool.RECT: label = "Rectangle"
		SketchMode.Tool.POLYGON: label = "Polygon"
		SketchMode.Tool.ELLIPSE: label = "Ellipse"
		SketchMode.Tool.SLOT: label = "Slot"
		SketchMode.Tool.SPLINE: label = "Spline"
		SketchMode.Tool.POINT: label = "Point"
		SketchMode.Tool.TRIM: label = "Trim"
		SketchMode.Tool.EXTEND: label = "Extend"
		SketchMode.Tool.SMART_DIM: label = "Smart Dimension"
		SketchMode.Tool.CONVERT: label = "Convert"
		SketchMode.Tool.MIRROR: label = "Mirror"
		SketchMode.Tool.PATTERN: label = "Pattern"
	return FilmUI.find_sketch_tool_button(ctx.main, label)


func _distance_near(sm: SketchMode, value: float) -> int:
	for i in sm.dimensions.size():
		var d: Dictionary = sm.dimensions[i]
		if str(d.get("type", "")) == "distance" and absf(float(d.get("value", -1.0)) - value) <= 0.5:
			return i
	return -1


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false


func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
```

Run it on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_rail.gd
```

Expected on `33672f7b`: `SCRIPT ERROR: Cannot call method 'get_global_rect' on a null value.` then `87 checks, 39 failures`. If different, stop.

**Commit 2 — the product change.** Apply both diffs. (The `@@` line numbers in these diffs are from the combined change; apply each hunk by its context, not its number.)

`game/scripts/main.gd`:

```diff
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
index 0da8391..05838e7 100644
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -787,29 +787,33 @@ func _build_ui() -> void:
 	rows.add_child(exit_btn)
 	rows.add_child(HSeparator.new())
 	for entry in [
-			[SketchMode.Tool.SELECT, "select", "Select (S)"],
-			[SketchMode.Tool.LINE, "line", "Line / centerline (L)"],
-			[SketchMode.Tool.ARC, "arc", "Arc tool (A)"],
-			[SketchMode.Tool.CIRCLE, "circle", "Circle (C)"],
-			[SketchMode.Tool.RECT, "rect", "Rectangle (R)"],
-			[SketchMode.Tool.POLYGON, "polygon", "Polygon"],
-			[SketchMode.Tool.ELLIPSE, "circle", "Ellipse (approx)"],
-			[SketchMode.Tool.SLOT, "rect", "Straight slot"],
-			[SketchMode.Tool.SPLINE, "spline", "Fit spline"],
-			[SketchMode.Tool.POINT, "point", "Sketch point"],
-			[SketchMode.Tool.TRIM, "trim", "Power Trim (T)"],
-			[SketchMode.Tool.EXTEND, "extend", "Extend to next"],
-			[SketchMode.Tool.SMART_DIM, "dimension", "Smart Dimension (D)"],
-			[SketchMode.Tool.CONVERT, "convert", "Convert entities"],
-			[SketchMode.Tool.MIRROR, "mirror", "Mirror selection"],
-			[SketchMode.Tool.PATTERN, "pattern", "Linear / circular pattern"],
+			[SketchMode.Tool.SELECT, "select", "Select (S)", "Select"],
+			[SketchMode.Tool.LINE, "line", "Line / centerline (L)", "Line"],
+			[SketchMode.Tool.ARC, "arc", "Arc tool (A)", "Arc"],
+			[SketchMode.Tool.CIRCLE, "circle", "Circle (C)", "Circle"],
+			[SketchMode.Tool.RECT, "rect", "Rectangle (R)", "Rect"],
+			[SketchMode.Tool.POLYGON, "polygon", "Polygon", "Polygon"],
+			[SketchMode.Tool.ELLIPSE, "circle", "Ellipse (approx)", "Ellipse"],
+			[SketchMode.Tool.SLOT, "rect", "Straight slot", "Slot"],
+			[SketchMode.Tool.SPLINE, "spline", "Fit spline", "Spline"],
+			[SketchMode.Tool.POINT, "point", "Sketch point", "Point"],
+			[SketchMode.Tool.TRIM, "trim", "Power Trim (T)", "Trim"],
+			[SketchMode.Tool.EXTEND, "extend", "Extend to next", "Extend"],
+			[SketchMode.Tool.SMART_DIM, "dimension", "Smart Dimension (D)", "Smart Dim"],
+			[SketchMode.Tool.CONVERT, "convert", "Convert entities", "Convert"],
+			[SketchMode.Tool.MIRROR, "mirror", "Mirror selection", "Mirror"],
+			[SketchMode.Tool.PATTERN, "pattern", "Linear / circular pattern", "Pattern"],
 			]:
-		var b := UIIcons.button(entry[1], "", entry[2])
+		var b := UIIcons.button(entry[1], entry[3], entry[2])
 		b.pressed.connect(sketch_mode.set_tool.bind(entry[0]))
 		rows.add_child(b)
-	# Icon-only like the rest of the rail — a text label widens the 44px
-	# column into the finish-bar dim blank (layout suite).
-	var auto_def := UIIcons.button("dimension", "",
+		if entry[0] == SketchMode.Tool.RECT:
+			var jaw := UIIcons.button("wrench_open", "Jaw",
+				"Jaw: open-end wrench jaw. Click 1 = centre, click 2 = end of the long side, click 3 = half the width")
+			jaw.name = "JawTool"
+			jaw.pressed.connect(sketch_mode.start_jaw_tool)
+			rows.add_child(jaw)
+	var auto_def := UIIcons.button("solve", "Auto Dim",
 		"Auto-define — promote weak dims until DOF 0")
 	auto_def.name = "AutoDefine"
 	auto_def.pressed.connect(func() -> void: sketch_mode.auto_define())
```

Notes the BUILD agent needs:

- The fourth element of each rail entry is the visible label. `UIIcons.button(icon, text, tooltip)` already accepts text; no change to `ui_icons.gd`.
- `entry[0] == SketchMode.Tool.RECT` puts the `Jaw` button directly under `Rect`. `JawTool` is the node name; the test finds it with `FilmUI.find_sketch_tool_button(ctx.main, "Jaw")`.
- The Auto-define button changes glyph from `dimension` to `solve` (both exist in `UIIcons`) so it no longer looks like Smart Dimension. The old comment about the 44 px column is deleted because the layout suites pass with labels.

`game/scripts/sketch_mode.gd`:

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index d8b4e6a..8c7cf64 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -831,6 +864,12 @@ func set_tool(t: Tool) -> void:
 	tool_changed.emit(int(t))
 
 
+## Rail "Jaw" button: Rectangle tool, Center Three Point variant.
+func start_jaw_tool() -> void:
+	set_tool(Tool.RECT)
+	set_tool_variant("center_three_point")
+
+
 func set_tool_variant(v: String) -> void:
 	tool_variant = v
 	if tool == Tool.POLYGON and (v == "across_flats" or v == "vertex"):
@@ -838,7 +877,10 @@ func set_tool_variant(v: String) -> void:
 	_tool_points.clear()
 	_length_override = -1.0
 	_update_preview()
-	status.emit("Variant: %s" % v.replace("_", " "))
+	if v == "center_three_point":
+		status.emit(JAW_HINT)
+	else:
+		status.emit("Variant: %s" % v.replace("_", " "))
 
 
 ## True when a draw tool has the first anchor and is waiting for the tip.
@@ -1003,6 +1052,9 @@ func is_empty_new_sketch() -> bool:
 			and sketch.entity_ids().is_empty()
 
 
+const JAW_HINT := "Jaw — click 1 centre, click 2 end of the long side, click 3 half the width"
+
+
 func variants_for_tool(t: Tool = tool) -> Array:
 	match t:
 		Tool.RECT:
```

Step: run the test again. Expected: `89 checks, 0 failures`.

**Regression commands (all must match):**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_layout_tests.gd                    # 33 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan2_layout.gd          # 22 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_icon_tests.gd                      # 13 checks, 2 failures (same as main)
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_dead_chrome_tests.gd              # 28 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_sketch_tools_tests.gd              # 141 checks, 13 failures (same as main)
```

**GUI checklist item (sx-028 F1).** In a sketch, the left rail shows a word under every icon: Select, Line, Arc, Circle, Rect, Jaw, Polygon, Ellipse, Slot, Spline, Point, Trim, Extend, Smart Dim, Convert, Mirror, Pattern, Auto Dim. Press `Jaw`. The `Center Three Point` chip is highlighted beside the rail and the status line reads `Jaw — click 1 centre, click 2 end of the long side, click 3 half the width`.

---

### WP2 — The `Shaft Lines` chip

**Files.** `game/scripts/sketch_mode.gd` (`selection_actions`, new `shaft_lines_selected`), `game/scripts/main.gd` (`_on_sketch_action`), new `game/tests/run_rung01_replan8_shaft.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan8_shaft.gd` with exactly this content.

```gdscript
# Rung 1 replan 8 WP2 — two selected circles get a Shaft Lines chip; the connected blank passes check_rung01 blank.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_shaft.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)



func _init() -> void:
	print("rung01 replan8 WP2 shaft lines")
	FilmUI.reset_fail_count()
	await test_shaft_web()
	await test_refuses_non_circles()
	await test_mouse_select_then_chip()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_shaft_web() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	check(a != "" and b != "", "two circles exist")
	var none: Array = sm.selection_actions()
	check(not none.has("shaft_lines"), "no Shaft Lines chip with nothing selected")
	sm._set_selected([a])
	check(not sm.selection_actions().has("shaft_lines"), "no Shaft Lines chip with one circle")
	sm._set_selected([a, b])
	await process_frame
	await process_frame
	check(sm.selection_actions().has("shaft_lines"), "two circles offer shaft_lines")
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "the Shaft Lines chip is visible")
	_status_log.clear()
	var ok := await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shaft Lines", "Shaft Lines"))
	check(ok, "the Shaft Lines chip was clicked")
	await process_frame

	var lines := 0
	var tangents := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	for cid in sm.sketch.constraint_ids():
		if str(sm.sketch.constraint_info(cid).get("type", "")) == "tangent":
			tangents += 1
	check(lines == 2, "two shaft lines were added (got %d)" % lines)
	check(tangents == 2, "each shaft line is tangent to the small circle (got %d tangent constraints)" % tangents)
	var ys: Array[float] = []
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "line":
			ys.append(float((info["start"] as Vector2).y))
			check(absf(float((info["start"] as Vector2).y) - float((info["end"] as Vector2).y)) < 1e-3, "a shaft line is parallel to the centre line")
			check(absf(float((info["end"] as Vector2).x) - 179.844) < 0.01, "a shaft line ends on the large circle at x = 179.844 (got %.3f)" % float((info["end"] as Vector2).x))
	ys.sort()
	check(ys.size() == 2 and absf(ys[0] + 10.0) < 1e-3 and absf(ys[1] - 10.0) < 1e-3, "the shaft lines sit at y = -10 and y = +10")
	check(_status_has("Shaft lines: 2 added"), "status reports 2 lines added")
	check(SketchMode.profile_is_closed(sm.sketch), "the web closes the profile")

	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	check(doc.body_ids().size() == 1, "one connected blank body (got %d)" % doc.body_ids().size())
	var body: String = doc.body_ids()[0]
	var bb: Dictionary = doc.measure_bbox(body)
	check(absf(float(bb["min"].x) + 10.0) < 0.05, "blank min X is -10 (got %.3f)" % float(bb["min"].x))
	check(absf(float(bb["max"].x) - 222.5) < 0.05, "blank max X is 222.5 (got %.3f)" % float(bb["max"].x))
	check(absf(float(bb["max"].y) - 22.5) < 0.05 and absf(float(bb["min"].y) + 22.5) < 0.05, "blank Y is +-22.5")
	check(absf(float(bb["max"].z) - 10.0) < 0.05, "blank is 10 mm tall")
	var vol := float(doc.measure_mass(body).get("volume", 0.0))
	check(absf(vol - 53128.0) < 60.0, "blank volume is the handout shape, 53128 mm3 (got %.1f)" % vol)
	var out := "/tmp/replan8_blank.3mf"
	check(doc.export_3mf(out), "3MF export succeeded")
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var output: Array = []
	var code := OS.execute("python3", [repo.path_join("tools/check_rung01.py"), "blank", out], output, true)
	print("\n".join(output))
	check(code == 0, "tools/check_rung01.py blank passes on the exported 3MF (exit %d)" % code)
	await _shutdown(ctx)


func test_refuses_non_circles() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(5.0, 0.0, 30.0)
	sm._set_selected([a, b])
	_status_log.clear()
	var n: int = int(sm.call("shaft_lines_selected")) if sm.has_method("shaft_lines_selected") else -1
	check(n == 0, "nested circles add no shaft lines")
	check(_status_has("must sit outside the large one"), "nested circles get a named refuse")
	var c: String = sm.sketch.add_circle(100.0, 0.0, 30.0)
	var d: String = sm.sketch.add_circle(200.0, 0.0, 30.0)
	sm._set_selected([c, d])
	_status_log.clear()
	n = int(sm.call("shaft_lines_selected")) if sm.has_method("shaft_lines_selected") else -1
	check(n == 0 and _status_has("same size"), "two equal circles get a named refuse")
	var l: String = sm.sketch.add_line(0.0, 50.0, 10.0, 50.0)
	sm._set_selected([a, l])
	_status_log.clear()
	n = int(sm.call("shaft_lines_selected")) if sm.has_method("shaft_lines_selected") else -1
	check(n == 0 and _status_has("select two circles first"), "a circle plus a line is refused with a named status")
	await _shutdown(ctx)


func test_mouse_select_then_chip() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.sketch.add_circle(200.0, 0.0, 22.5)
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await _click_uv(ctx, vp, Vector2(200.0, 22.5))
	await process_frame
	await process_frame
	check(sm.selected.size() == 2, "two Select-tool clicks on the circle edges select both (got %d)" % sm.selected.size())
	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
	check(chip != null and chip.is_visible_in_tree(), "Shaft Lines chip appears after the mouse selection")
	if chip != null:
		await FilmUI.click_control(ctx, chip, FilmUICues.alert("Shaft Lines", "Shaft Lines"))
	var lines := 0
	for id in sm.sketch.entity_ids():
		if str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	check(lines == 2, "the chip adds two lines after a mouse selection (got %d)" % lines)
	check(SketchMode.profile_is_closed(sm.sketch), "the mouse-selected web closes the profile")
	await _shutdown(ctx)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false

func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
```

Run on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_shaft.gd
```

Expected on `33672f7b`: `33 checks, 16 failures`. If different, stop.

**Commit 2 — the product change.** Apply.

`game/scripts/sketch_mode.gd`:

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index d8b4e6a..8c7cf64 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -1030,6 +1082,8 @@ func selection_actions() -> Array:
 	if selected.size() == 2:
 		var t0: String = sketch.entity_info(selected[0]).get("type", "")
 		var t1: String = sketch.entity_info(selected[1]).get("type", "")
+		if (t0 == "circle" or t0 == "arc") and (t1 == "circle" or t1 == "arc"):
+			acts.append("shaft_lines")
 		if t0 == "line" and t1 == "line":
 			acts.append("fillet")
 			acts.append("chamfer")
@@ -1044,6 +1098,58 @@ func selection_actions() -> Array:
 	return acts
 
 
+## Two circles selected, one larger: add the two shaft lines of the handout.
+## Each line runs parallel to the centre line, tangent to the smaller circle
+## at its top or bottom and ending where it meets the larger circle on the
+## side nearer the small one. Both go through _infer_line, the same path a
+## hand-drawn shaft line takes, so they get the tangent constraint on the small
+## circle, the on-circle constraint on the large one, and the flip guard.
+## Returns the number of lines added.
+func shaft_lines_selected() -> int:
+	if sketch == null or selected.size() != 2:
+		status.emit("Shaft lines: select two circles first")
+		return 0
+	var ia: Dictionary = sketch.entity_info(selected[0])
+	var ib: Dictionary = sketch.entity_info(selected[1])
+	for info in [ia, ib]:
+		var kind := str(info.get("type", ""))
+		if kind != "circle" and kind != "arc":
+			status.emit("Shaft lines: select two circles first")
+			return 0
+	var small: Dictionary = ia
+	var large: Dictionary = ib
+	if float(ia["radius"]) > float(ib["radius"]):
+		small = ib
+		large = ia
+	var cs: Vector2 = small["center"]
+	var cl: Vector2 = large["center"]
+	var rs := float(small["radius"])
+	var rl := float(large["radius"])
+	var d := cs.distance_to(cl)
+	if rl - rs <= 1e-4:
+		status.emit("Shaft lines: the two circles are the same size")
+		return 0
+	if d <= rl:
+		status.emit("Shaft lines: the small circle must sit outside the large one")
+		return 0
+	var u := (cl - cs) / d
+	var perp := Vector2(-u.y, u.x)
+	var neck := d - sqrt(rl * rl - rs * rs)
+	var added := 0
+	for side in [1.0, -1.0]:
+		var off := perp * (rs * float(side))
+		var pa := cs + off
+		var pb := cs + off + u * neck
+		var lid: String = sketch.add_line(pa.x, pa.y, pb.x, pb.y)
+		if lid == "":
+			continue
+		_infer_line(lid, pa, pb)
+		added += 1
+	status.emit("Shaft lines: %d added" % added)
+	_redraw()
+	return added
+
+
 func set_snap(on: bool) -> void:
 	snap_enabled = on
 	if not on:
```

`game/scripts/main.gd` (`_on_sketch_action`, add the case before `"fillet"`):

```diff
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
index 0da8391..05838e7 100644
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -1301,6 +1305,8 @@ func _on_sketch_action(action: String) -> void:
 		"sweep_path":
 			_sweep_profile_along_path()
 			return
+		"shaft_lines":
+			sketch_mode.shaft_lines_selected()
 		"fillet":
 			sketch_mode.fillet_selected(sketch_chrome.dim_value() if sketch_chrome else 2.0)
 		"chamfer":
```

Why the geometry is exactly this (so nobody "improves" it):

- `pa = cs + perp·(±rs)` is the top or bottom point of the small circle, so the line is tangent to it. `pb = pa + u·(d − √(rl² − rs²))` is where the same parallel line meets the large circle on the side facing the small one. Wrench numbers: `d = 200`, `rs = 10`, `rl = 22.5` → `neck = 179.844`.
- `_infer_line(lid, pa, pb)` is the function a hand-drawn line goes through. It adds the horizontal constraint, the tangent to the small circle, and the end-on-large-circle distance. Do not add constraints by hand.
- Selection order does not matter; the larger radius is the head. Equal radii, or a small circle that is inside or touching the large one (`d <= rl`), give a named status and add nothing.
- A chip, not a rail tool, because the chip row appears with the selection, next to the thing the person just did (Smart Dimension leaves both circles selected).

Step: run the test again. Expected: `37 checks, 0 failures`, including the `check_rung01.py blank` run (`5/5 passed`).

**Regression commands:**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_infer_tests.gd                    # 44 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan3_blank.gd           # 62 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_sketch_tests.gd                   # 83 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_sketch_tests.gd            # 70 checks, 7 failures (same as main)
```

**GUI checklist item (sx-028 F2).** Draw Ø20 at the origin and Ø45 to its right (mouse is fine), Smart Dimension 200 between the centres. Both circles are still selected and a `Shaft Lines` chip is on screen: press it. Two horizontal lines join the circles. If the chip is not showing, press `Select`, click empty canvas, click each circle's edge once, then press `Shaft Lines`. Status `Shaft lines: 2 added`. Extrude 10, export 3MF, `check_rung01.py blank` 5/5.

---

### WP3 — Refuse a cut that wrecks or misses the body

**Files.** `game/scripts/sketch_mode.gd` (`finish_extrude`, new `_body_volume`, `_cut_refusal`, two constants), new `game/tests/run_rung01_replan8_cut.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan8_cut.gd` with exactly this content.

```gdscript
# Rung 1 replan 8 WP3 — a cut that boolean-succeeds but wrecks the body is refused with a named status and rolled back.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_cut.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)



func _init() -> void:
	print("rung01 replan8 WP3 cut refusal")
	FilmUI.reset_fail_count()
	await test_cut_guard()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _extrude_count(doc) -> int:
	var n := 0
	for f in doc.graph_features():
		if str(f.get("type", "")) == "extrude":
			n += 1
	return n


func _volume(doc, body: String) -> float:
	return float(doc.measure_mass(body).get("volume", -1.0))


func _top_face(doc, body: String) -> String:
	for f in doc.get_face_ids(body):
		if absf(doc.face_midpoint(f).z - 10.0) < 0.01:
			return f
	return ""


func test_cut_guard() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 50.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	var doc = ctx.view.doc
	var body: String = doc.body_ids()[0]
	var base_vol := _volume(doc, body)
	check(absf(base_vol - PI * 50.0 * 50.0 * 10.0) < 1.0, "base disc volume is %.1f" % base_vol)
	var top := _top_face(doc, body)
	check(top != "", "top face exists")
	var extrudes_before := _extrude_count(doc)

	ctx.main._start_sketch_on_face(top, body)
	await process_frame
	sm = ctx.main.sketch_mode
	var big: String = sm.sketch.add_circle(0.0, 0.0, 45.0)
	_status_log.clear()
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [])
	await process_frame
	check(_status_has("Cut would remove 81% of the body"), "an 81%% cut gets the named refuse (log: %s)" % str(_status_log))
	check(sm.active, "the sketch session stays open after the refuse")
	check(_extrude_count(doc) == extrudes_before, "the refused cut leaves no extrude feature")
	check(absf(_volume(doc, doc.body_ids()[0]) - base_vol) < 1.0, "the body volume is unchanged after the refuse")

	sm.sketch.remove_entity(big)
	sm.sketch.add_circle(200.0, 0.0, 5.0)
	_status_log.clear()
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [])
	await process_frame
	check(_status_has("Cut removed nothing"), "a contour off the body gets the named refuse (log: %s)" % str(_status_log))
	check(sm.active and _extrude_count(doc) == extrudes_before, "nothing was cut and the session is open")

	for id in sm.sketch.entity_ids():
		sm.sketch.remove_entity(id)
	sm.sketch.add_circle(0.0, 0.0, 5.0)
	_status_log.clear()
	sm.finish_extrude(10.0, "cut", "blind", 0.0, "one_side", false, [])
	await process_frame
	await process_frame
	check(not sm.active, "a small hole is accepted and the session ends")
	check(_extrude_count(doc) == extrudes_before + 1, "the hole adds exactly one extrude feature")
	var want := base_vol - PI * 25.0 * 10.0
	var got := _volume(doc, doc.body_ids()[0])
	check(absf(got - want) < 1.0, "hole volume %.1f matches %.1f" % [got, want])
	await _shutdown(ctx)


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false

func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame
```

Run on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_cut.gd
```

Expected on `33672f7b`: `13 checks, 7 failures`. If different, stop.

**Commit 2 — the product change.**

`game/scripts/sketch_mode.gd`:

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index d8b4e6a..8c7cf64 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -596,6 +596,7 @@ func finish_extrude(distance: float, op: String = "new", end: String = "blind",
 	var sk_fid := _ensure_sketch_feature()
 	if sk_fid == "":
 		return
+	var vol_before := _body_volume(view.body_of_feature(target_fid)) if op == "cut" else -1.0
 	var ex_fid: String = view.doc.graph_add_extrude(
 		sk_fid, distance, symmetric, op, target_fid if op != "new" else "", end,
 		thin_thickness, thin_type, flip_side, selected_contours)
@@ -603,10 +604,42 @@ func finish_extrude(distance: float, op: String = "new", end: String = "blind",
 		status.emit(_graph_error_text())
 		_reassert_camera()
 		return
+	if ex_fid != "" and op == "cut" and vol_before > 0.0:
+		var vol_after := _body_volume(view.body_of_feature(target_fid))
+		var refuse := _cut_refusal(vol_before, vol_after)
+		if refuse != "":
+			view.doc.graph_remove(ex_fid)
+			view.refresh()
+			status.emit(refuse)
+			_reassert_camera()
+			return
 	var fail_msg := "Extrude failed — is the profile closed?"
 	_finish_feature(sk_fid, ex_fid, op, fail_msg)
 
 
+const CUT_MAX_REMOVED_FRACTION := 0.5
+const CUT_MIN_REMOVED_MM3 := 1e-3
+
+
+func _body_volume(body_id: String) -> float:
+	if body_id == "" or view == null or view.doc == null:
+		return -1.0
+	return float(view.doc.measure_mass(body_id).get("volume", -1.0))
+
+
+## Named refusal for a cut that boolean-succeeded but wrecked the body.
+## Empty string = accept.
+func _cut_refusal(before: float, after: float) -> String:
+	if after < 0.0:
+		return "Cut removed the whole body — the sketch contour is not inside the face. Fix the contour or pick Selected Contours."
+	var removed := before - after
+	if removed <= CUT_MIN_REMOVED_MM3:
+		return "Cut removed nothing — the contour does not reach the body. Check the contour and the Up To Surface face."
+	if removed > before * CUT_MAX_REMOVED_FRACTION:
+		return "Cut would remove %d%% of the body — the contour covers most of it. Nothing was cut." % int(round(100.0 * removed / before))
+	return ""
+
+
 ## Finish the sketch and revolve. The axis is the selected line when one is
 ## selected (select tool), otherwise the sketch Y axis through the origin.
 func finish_revolve(angle: float = TAU, op: String = "new") -> void:
```

Rules:

- The check runs only for `op == "cut"`, after `graph_add_extrude` accepted the feature and before `_finish_feature`. A refused cut calls `view.doc.graph_remove(ex_fid)` so the extrude feature is gone; the sketch feature stays in the graph (the session keeps `editing_fid`), `active` stays true and `_reassert_camera()` keeps the sketch view.
- The three messages are asserted verbatim by the test (`Cut would remove 81% of the body`, `Cut removed nothing`). Keep the text.
- Do not touch `sxkernel`, `sx_document.cpp`, the timeline panel or the property panel: edits to an existing cut depth go through `apply_graph_edit` and its own auto-revert.
- No override. If a later rung needs a large hollowing cut, change `CUT_MAX_REMOVED_FRACTION` then, with a test.

Step: run the test again. Expected: `13 checks, 0 failures`.

**Regression commands (the wrench cut suites exercise real Up To Surface cuts):**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan6_cut.gd             # 100 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_wrench_cut_tests.gd               # 21 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_wrench_through_tests.gd           # 23 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan5_face.gd            # 98 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd                  # 391 checks, 0 failures (before WP5)
```

**GUI checklist item (sx-028 F3).** Extrude a Ø100 disc, 10 mm. Sketch on its top face, draw a Ø90 circle, set the finish bar to `Cut`, press Extrude. The status reads `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`, the body is unchanged, the sketch is still open. Delete the circle, draw a Ø10 circle, Extrude: the hole is cut.

---

### WP4 — `Esc` drops a pending first point

**Files.** `game/scripts/sketch_mode.gd` (new `cancel_pending_draw`), `game/scripts/viewport_interaction.gd` (`_sketch_input`, the `KEY_ESCAPE` case), new `game/tests/run_rung01_replan8_esc.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan8_esc.gd` with exactly this content.

```gdscript
# Rung 1 replan 8 WP4 — Esc drops a pending first point without leaving the sketch; Esc after Extrude clears the body;
# the palette Sketch button plus ONE click on the top face starts a face sketch.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan8_esc.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

var failures := 0
var checks := 0
var _status_log: Array[String] = []


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)



func _init() -> void:
	print("rung01 replan8 WP4 Esc ladder and one-click face")
	FilmUI.reset_fail_count()
	await test_esc_ladder()
	await test_one_click_face()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_esc_ladder() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await process_frame
	check(sm.has_pending_draw_point(), "one Circle click leaves a pending first point")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with a pending first point keeps the sketch open")
	check(not sm.has_pending_draw_point(), "Esc drops the pending first point")
	check(_status_has("First point dropped"), "Esc says the first point was dropped (log: %s)" % str(_status_log))
	var entities := sm.sketch.entity_ids().size()
	check(entities == 0, "no circle was created by the dropped point (got %d entities)" % entities)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(10, 0))
	await process_frame
	var r := 0.0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "circle":
			r = float(info.get("radius", 0.0))
	check(absf(r - 10.0) < 0.6, "after the dropped point a fresh two-click circle has r~10 (got %.2f)" % r)
	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing pending still exits the sketch")
	await _shutdown(ctx)


func test_one_click_face() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	_add_rect(sm, 40.0, 30.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	var body: String = doc.body_ids()[0]
	check(ctx.view.selected_body == body, "Extrude leaves the new body selected")
	await _x11_key(vp, KEY_ESCAPE)
	check(ctx.view.selected_body == "" and ctx.view.selection_size() == 0, "Esc after Extrude clears the body selection")
	await _top_zoom(ctx, Vector3(20, 15, 10), 90.0)
	var palette_sketch := FilmUI.find_palette_sketch_button(ctx.main)
	check(palette_sketch != null, "palette Sketch button exists")
	await _x11_click(palette_sketch)
	await process_frame
	check(ctx.main.interaction._picking_sketch_host, "Sketch with nothing selected arms the host pick")
	check(ctx.main.status_label.text.contains("Select a face"), "status asks for a face (got %s)" % ctx.main.status_label.text)
	var pt := FilmUI.model_to_screen(ctx, Vector3(30, 8, 10))
	check(FilmUI.require_on_screen(ctx, pt, "top face click"), "the top face click is on screen")
	await _x11_click_screen(vp, pt)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5 and sm.plane_normal().z > 0.9,
			"ONE click on the top face starts a sketch on z = 10")
	await _shutdown(ctx)


func _add_rect(sm: SketchMode, w: float, h: float) -> void:
	sm.sketch.add_line(0, 0, w, 0)
	sm.sketch.add_line(w, 0, w, h)
	sm.sketch.add_line(w, h, 0, h)
	sm.sketch.add_line(0, h, 0, 0)


func _top_zoom(ctx: FilmContext, pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	cam.sketch_orientation_locked = false
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.yaw = 0.0
	cam.pitch = deg_to_rad(89.0)
	cam.pivot = ctx.main.model_space.to_global(pivot)
	cam.distance = size_mm / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	cam._update_transform()
	await process_frame
	await process_frame


func _status_has(needle: String) -> bool:
	for s in _status_log:
		if s.contains(needle):
			return true
	return false

func _boot() -> FilmContext:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	check(root.size == ROOT_SIZE, "root is 1280×800 (got %s)" % str(root.size))
	_status_log.clear()
	main.sketch_mode.status.connect(_on_status)
	main.interaction.status.connect(_on_status)
	return ctx


func _on_status(text: String) -> void:
	_status_log.append(text)


func _shutdown(ctx: FilmContext) -> void:
	ctx.main.queue_free()
	await process_frame
	await process_frame


func _click_uv(ctx: FilmContext, vp: Viewport, uv: Vector2) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, "sketch click"), "sketch click on screen at %s" % str(uv))
	await _x11_click_screen(vp, screen)


func _zoom(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	var ms: Node3D = ctx.main.model_space
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		var n: Vector3 = sm.plane_normal()
		if n.length_squared() > 1e-8:
			cam.yaw = atan2(n.x, -n.y)
			cam.pitch = clampf(asin(clampf(n.z, -1.0, 1.0)), deg_to_rad(-89.0), deg_to_rad(89.0))
		if ms != null and sm.plane_y.length_squared() > 1e-8:
			var up_w: Vector3 = ms.global_transform.basis * sm.plane_y
			if up_w.length_squared() > 1e-8:
				cam._sketch_view_up = up_w.normalized()
		cam.sketch_orientation_locked = true
		cam._look_at_content = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.pivot = ms.to_global(model_pivot) if ms != null else model_pivot
	var half := tan(deg_to_rad(cam.fov) * 0.5)
	cam.distance = size_mm / (2.0 * half)
	cam._update_transform()
	await process_frame
	await process_frame


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	await _x11_click_screen(ctrl.get_viewport(), pos)


func _x11_click_screen(vp: Viewport, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	vp.push_input(up)
	await process_frame


func _x11_key(vp: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	vp.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	vp.push_input(up)
	await process_frame
```

Run on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_esc.gd
```

Expected on `33672f7b`: `20 checks, 3 failures` (`Esc with a pending first point keeps the sketch open`, `Esc says the first point was dropped`, `after the dropped point a fresh two-click circle has r~10`). If different, stop.

**Commit 2 — the product change.**

`game/scripts/sketch_mode.gd`:

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index d8b4e6a..8c7cf64 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -851,6 +893,13 @@ func has_pending_draw_point() -> bool:
 			return false
 
 
+## Esc with a first anchor placed: drop the anchor and keep the sketch session.
+func cancel_pending_draw() -> void:
+	_tool_points.clear()
+	_length_override = -1.0
+	_update_preview()
+
+
 ## A stationary mouse-up lands on the anchor that the press just stored.
 ## That is not a second point: keep the anchor so the next click can finish
 ## the segment. A real second point closer than MIN_SEGMENT_MM is rejected
```

`game/scripts/viewport_interaction.gd`:

```diff
diff --git a/game/scripts/viewport_interaction.gd b/game/scripts/viewport_interaction.gd
index 8fb98d7..8348960 100644
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -2655,6 +2655,9 @@ func _sketch_input(event: InputEvent) -> void:
 					# keep the sketch session so Extrude stays available.
 					sketch_mode.end_chain()
 					status.emit("Chain ended")
+				elif sketch_mode.has_pending_draw_point():
+					sketch_mode.cancel_pending_draw()
+					status.emit("First point dropped — Esc again exits the sketch")
 				else:
 					sketch_mode.cancel()
 		accept_event()
```

The new branch sits after the open-chain branch and before `cancel()`. Esc order inside a sketch is now: clear the measure anchor → unlock the typed length → end an open Line chain → drop a pending first point → exit the sketch. Nothing outside a sketch changes (`cancel_stack` is untouched; the test's second half asserts it still clears the body after Extrude).

Step: run the test again. Expected: `20 checks, 0 failures`.

**Regression commands:**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_sketch_tools_tests.gd             # 141 checks, 13 failures (same as main)
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan7_facepick.gd        # 31 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan5_session.gd         # 63 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_camera_tests.gd                   # 104 checks, 0 failures
```

**GUI checklist item (sx-028 F4).** In a sketch, Circle tool, click once (centre), press `Esc`: the sketch stays open, no circle, status `First point dropped — Esc again exits the sketch`. Click twice: a circle. Press `Esc` with nothing pending: the sketch closes. After Extrude press `Esc`: the body is deselected. Press the palette `Sketch` button and click the top face once: a sketch opens on the top face. (If the face click does nothing, the click was lost: say so in the log, click again, and do not count it as a product failure unless it fails twice in a row.)

---

### WP5 — The walk uses `Jaw` and `Shaft Lines`; lint and Makefile cover replan 8

Prerequisite: WP1–WP4 merged. **Files.** `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile`.

Why the walk edit looks the way it does:

- `_draw_centre_rect` pressed `Rect`, then found the `Center Three Point` chip. It now presses `Jaw` only. The test asserts the tool and variant after the press, so the rail button is what selects them.
- The two shaft lines were five clicks each. `_shaft_lines_via_chip` replaces them: it zooms to the whole sketch (280 mm), selects the Select tool, clicks empty canvas at (100, 80) to clear the selection that Smart Dimension left, clicks the top of each circle, asserts two selected, presses the `Shaft Lines` chip with `FilmUI.click_control`, and asserts the status. `_draw_shaft_line` is deleted (no other caller). No `select_entity`, no script-side selection.
- Replace the four-line comment above the call (`# Shaft 20 wide: lines at y = ±r0 …` through `# click then Smart Dimension 200), not a hardcoded (200, 0).`) with: `# Shaft 20 wide: the Shaft Lines chip adds the two lines at y = ±r0 that end on the Ø45.` The diff below leaves that comment untouched so it applies cleanly; the replacement is comment-only.

`game/tests/run_rung01_wrench.gd`:

```diff
diff --git a/game/tests/run_rung01_wrench.gd b/game/tests/run_rung01_wrench.gd
index 6928814..500d9ff 100644
--- a/game/tests/run_rung01_wrench.gd
+++ b/game/tests/run_rung01_wrench.gd
@@ -221,16 +221,7 @@ func _walk(ctx: FilmContext) -> Dictionary:
 	# the Ø45 at the concave neck. Clicks are a few tenths off the contacts
 	# so snap + inference close them. Use the solved centres (right-half
 	# click then Smart Dimension 200), not a hardcoded (200, 0).
-	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
-	if circs.size() == 2:
-		print("  shaft from bosses origin (%.3f, %.3f) r=%.3f  head (%.3f, %.3f) r=%.3f" % [
-			(circs[0]["center"] as Vector2).x, (circs[0]["center"] as Vector2).y,
-			float(circs[0]["radius"]),
-			(circs[1]["center"] as Vector2).x, (circs[1]["center"] as Vector2).y,
-			float(circs[1]["radius"])])
-		for y_sign in [1.0, -1.0]:
-			await _draw_shaft_line(ctx, circs[0]["center"] as Vector2, float(circs[0]["radius"]),
-					circs[1]["center"] as Vector2, float(circs[1]["radius"]), float(y_sign))
+	await _shaft_lines_via_chip(ctx)
 	await _assert_shaft_lines_both_sides(sm)
 	await _assert_contours_stay_on(ctx)
 	chrome = ctx.main.sketch_chrome
@@ -1919,18 +1910,30 @@ func _hover_uv(ctx: FilmContext, uv: Vector2) -> void:
 	await _aim_pointer(ctx, screen)
 
 
-func _draw_shaft_line(ctx: FilmContext, c0: Vector2, r0: float, c1: Vector2, r1: float, sign: float) -> void:
-	var far := sqrt(maxf(r1 * r1 - r0 * r0, 0.0))
-	var a_exact := c0 + Vector2(0.0, r0 * sign)
-	var b_exact := Vector2(c1.x - far, c0.y + r0 * sign)
-	var a_off := a_exact + Vector2(0.0, 0.3 * sign)
-	var b_dir := b_exact - c1
-	var b_off := b_exact + (b_dir.normalized() if b_dir.length_squared() > 1e-8 else Vector2(0, sign)) * 0.3
-	await _zoom_uv(ctx, a_off, 90.0)
-	await _click_uv(ctx, a_off, "Tangent start near circle")
-	await _zoom_uv(ctx, b_off, 90.0)
-	await _click_uv(ctx, b_off, "Tangent end near circle")
-	await _right_click_uv(ctx, b_off)
+func _shaft_lines_via_chip(ctx: FilmContext) -> void:
+	var sm: SketchMode = ctx.main.sketch_mode
+	var circs := _circles(sm)
+	check(circs.size() == 2, "Shaft Lines needs two circles (got %d)" % circs.size())
+	if circs.size() != 2:
+		return
+	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
+	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
+	await _x11_click_uv(ctx, Vector2(100.0, 80.0), "Clear the selection on empty canvas")
+	await process_frame
+	check(sm.selected.is_empty(), "a click on empty canvas clears the sketch selection (got %d)" % sm.selected.size())
+	for c in circs:
+		var top: Vector2 = (c["center"] as Vector2) + Vector2(0.0, float(c["radius"]))
+		await _x11_click_uv(ctx, top, "Select circle edge")
+		await process_frame
+	check(sm.selected.size() == 2, "two circle-edge clicks select both circles (got %d)" % sm.selected.size())
+	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Shaft Lines")
+	check(chip != null and chip.is_visible_in_tree(), "the Shaft Lines chip is visible after selecting both circles")
+	if chip == null:
+		return
+	_status_log.clear()
+	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Shaft Lines"))
+	await process_frame
+	check(_status_has("Shaft lines: 2 added"), "status reports 2 shaft lines (got %s)" % ctx.main.status_label.text)
 
 
 func _assert_shaft_lines_both_sides(sm: SketchMode) -> void:
@@ -2052,10 +2055,11 @@ func _smart_dim_centres(ctx: FilmContext, text: String) -> void:
 
 func _draw_centre_rect(ctx: FilmContext, center: Vector2) -> void:
 	var sm: SketchMode = ctx.main.sketch_mode
-	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
-	await process_frame
-	var chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
-	await FilmUI.click_control(ctx, chip, FilmUICues.alert("Click", "Centre three-point rectangle"))
+	var jaw := FilmUI.find_sketch_tool_button(ctx.main, "Jaw")
+	check(jaw != null and jaw.is_visible_in_tree(), "the Jaw button is on the sketch rail")
+	await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Click", "Jaw on the sketch rail"))
+	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
+			"Jaw selects Rectangle, Center Three Point (got tool %d variant %s)" % [int(sm.tool), sm.tool_variant])
 	var along := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
 	var across := Vector2(-along.y, along.x)
 	await _x11_click_uv(ctx, center, "Rect centre")
```

`tools/lint_rung01_e2e.py` and `Makefile`:

```diff
diff --git a/Makefile b/Makefile
index 32c9f49..6c4eab1 100644
--- a/Makefile
+++ b/Makefile
@@ -128,6 +128,10 @@ test-godot: build import preflight
 		[ -e "$$f" ] || continue; \
 		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
 	done
+	@for f in game/tests/run_rung01_replan8_*.gd; do \
+		[ -e "$$f" ] || continue; \
+		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
+	done
 
 lint-rung01-e2e:
 	python3 tools/lint_rung01_e2e.py
diff --git a/tools/lint_rung01_e2e.py b/tools/lint_rung01_e2e.py
index e05475c..b11fd10 100644
--- a/tools/lint_rung01_e2e.py
+++ b/tools/lint_rung01_e2e.py
@@ -344,6 +344,22 @@ def _lint_replan7(errors: list[str]) -> None:
         _lint_dimension_label_pos2(src, errors, prefix)
 
 
+def _lint_replan8(errors: list[str]) -> None:
+    paths = sorted(TESTS.glob("run_rung01_replan8_*.gd"))
+    if not paths:
+        errors.append(f"no run_rung01_replan8_*.gd scripts under {TESTS}")
+        return
+    for path in paths:
+        src = path.read_text(encoding="utf-8")
+        rel = path.relative_to(ROOT)
+        prefix = f"{rel}:"
+        _lint_needles(src, REPLAN7_FORBIDDEN, errors, prefix)
+        _lint_text_assignment(src, errors, prefix)
+        _lint_x11_click_await(src, errors, prefix)
+        _lint_current_dir_assignment(src, errors, prefix)
+        _lint_dimension_label_pos2(src, errors, prefix)
+
+
 def main() -> int:
     if not WALK.is_file():
         print(f"lint_rung01_e2e: missing {WALK}", file=sys.stderr)
@@ -356,6 +372,7 @@ def main() -> int:
     _lint_replan5(errors)
     _lint_replan6(errors)
     _lint_replan7(errors)
+    _lint_replan8(errors)
 
     if errors:
         print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
@@ -367,12 +384,14 @@ def main() -> int:
     n5 = len(list(TESTS.glob("run_rung01_replan5_*.gd")))
     n6 = len(list(TESTS.glob("run_rung01_replan6_*.gd")))
     n7 = len(list(TESTS.glob("run_rung01_replan7_*.gd")))
+    n8 = len(list(TESTS.glob("run_rung01_replan8_*.gd")))
     print(f"lint_rung01_e2e: {WALK} is clean")
     print(f"lint_rung01_e2e: {n3} replan3 scripts are clean")
     print(f"lint_rung01_e2e: {n4} replan4 scripts are clean")
     print(f"lint_rung01_e2e: {n5} replan5 scripts are clean")
     print(f"lint_rung01_e2e: {n6} replan6 scripts are clean")
     print(f"lint_rung01_e2e: {n7} replan7 scripts are clean")
+    print(f"lint_rung01_e2e: {n8} replan8 scripts are clean")
     return 0
 
 
```

Run, in this order:

```
python3 tools/lint_rung01_e2e.py                      # last line: lint_rung01_e2e: 4 replan8 scripts are clean
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd
```

Expected walk output (the checker lines are printed inside the walk):

```
7/7 passed
28/28 passed
4/4 passed
397 checks, 0 failures
```

(In order: the nut, the wrench, the thick file.) On `33672f7b` the same command prints `391 checks, 0 failures`; the six extra checks are the new Jaw, clear-selection, two-selected, chip and status checks.

**GUI checklist item (sx-028 F1+F2).** Covered by the WP1 and WP2 items; the sx-029 walker follows the same rail and chip path as the walk.

---

## Whole-suite check (after every WP and after WP5)

Run every `game/tests/run_*.gd` one by one (do not use `make test-godot`: it stops at the first failure) and compare with this table. These are the suites that are not clean on `33672f7b`; each must print the **same** count after the change. Every other suite must print `0 failures`.

| Suite | Result on `33672f7b` (and required after) |
|---|---|
| `run_assembly_tests` | 87 checks, 4 failures |
| `run_film_manifest_smoke` | exit 1 (`65 films, 9 failures`) |
| `run_howto_tests` | 91 checks, 2 failures |
| `run_icon_tests` | 13 checks, 2 failures |
| `run_insert_component_tests` | 42 checks, 2 failures |
| `run_menu_tests` | 55 checks, 2 failures |
| `run_place_tests` | 110 checks, 1 failure |
| `run_property_tests` | 17 checks, 1 failure |
| `run_rung01_replan3_input` | 110 checks, 1 failure |
| `run_rung01_replan3_shell` | 43 checks, 6 failures |
| `run_rung01_replan_shell` | 34 checks, 1 failure |
| `run_rung01_sketch_tests` | 70 checks, 7 failures |
| `run_sketch_to_3d_ui_tests` | 47 checks, 2 failures |
| `run_sketch_tools_tests` | 141 checks, 13 failures |
| `run_ui_button_coverage_tests` | exit 1, no summary line |
| `run_visual_ux_tests` | 86 checks, 1 failure |
| `run_film_caption_tests` | exit 0, no summary line |

Differences that are expected and required: `run_rung01_wrench` 391 → 397 checks (WP5); `run_parse_sweep_tests` 217 → 220 checks (it parses the new files); and the four new `run_rung01_replan8_*` suites. The kernel tests are untouched (`make test-kernel`); no C++ file changes in this plan.

The reference run: 92 suites on `33672f7b` and 96 with the change; the difference between the two summaries is exactly the four lines above plus the two count changes.

## Soft-GL protocol for the sx-029 walker (no code)

Soft-GL (llvmpipe) drops, reorders and double-fires keystrokes and sometimes loses a click. This is environmental. The headless suites do not see it. The walker follows these rules; none of them is a shortcut.

1. Type into one field at a time. After typing, **read the field back** (zoom the screenshot) before pressing Enter or Tab. If it does not show the intended text, select all (`Ctrl+A` in the field), retype, read back again. Up to three tries per field; log each try in WALK_LOG.
2. A click that has no effect (no status change, no selection change) may be a lost click. Repeat it once. If it again does nothing, log it as a product failure. Never click a third time.
3. If a field refuses a value after three tries, draw the circle by mouse (two clicks), then size it with Smart Dimension: click the circle's edge and type the diameter in the popup (`20`, `45`), reading the popup back before Enter. Log the fallback. The centre distance 200 is always a Smart Dimension between the two centres.
4. After each dimension, wait for the status line to change before the next action.
5. When an Extrude, cut or fillet is refused, record the refusal text verbatim; a named refusal is a pass for the refusal rows, a mangled body without one is a fail.
6. Never use the film/test hooks (`select_entity`, script-side selection, direct sketch API). The walk's lint forbids them; the human walker does not use them either.

## Timeline Distance 14 (carry, GUI)

After the wrench is finished and exported as `wrench.3mf`: open the timeline, double-click the base Extrude (the first extrude, Distance 10), set Distance to 14, Enter. The Up To Surface jaw cut follows the new depth (the jaw is still open through, the slot floor stays 2.5 mm below the top). Export `wrench-t14.3mf` and run `python3 tools/check_rung01.py thick wrench-t14.3mf 14` → 4/4. If WP3's refusal fires during this edit, record the text: it means the edit changed the removed volume by more than half, which is a product failure for this row.

## Observed, not planned

Written down so nobody re-investigates them without new evidence:

- Dim auto-popup flaky on centre picks (sx-028 carry). The headless walk asserts the popup after the second centre click and passes; the GUI flake follows soft-GL event loss (F5). Workaround: double-click the dimension label.
- WALK_LOG B2.4: sketch overlay drawn ~210 mm off the body after Frame; clicks under the left rail's invisible width are swallowed. The rail now has text labels (WP1); its width is unchanged. Not reproduced headless.
- WALK_LOG B2.6: "Esc afterwards re-entered Editing sketch instead of clearing" after the wrecked cut. With WP3 the wreck cannot happen through the GUI path; Esc behavior in that state was not reproduced. Re-test in sx-029; if it recurs, it is a new finding.
- WALK_LOG B1.2: `Ctrl+Z` did not undo a stray circle. Out of scope for rung 1 (the walker used Delete).
- SPOT-93 B2.2 (third click needed for the face): see F4. If sx-029 sees it again with a confirmed non-lost first click, the next plan changes `select_ray`; this plan does not.

## sx-029 GUI checklist

The walker does the handout in the real GUI at 1280×800 on the build that contains WP1–WP5, logs every step, and runs the four checkers on the exported files. One row per WP; rows B1–B5 are the handout order. A step is PASS only if it was done with the mouse and keyboard.

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| A1 | WP1 | In a new sketch, read the left rail | Every button has a word under its icon: Select, Line, Arc, Circle, Rect, Jaw, Polygon, Ellipse, Slot, Spline, Point, Trim, Extend, Smart Dim, Convert, Mirror, Pattern, Auto Dim |
| A2 | WP1 | Press `Jaw` | `Center Three Point` chip highlighted; status `Jaw — click 1 centre, click 2 end of the long side, click 3 half the width` |
| A3 | WP2 | Draw Ø20 at the origin and Ø45 at the right; Smart Dimension 200 between the centres | Dimension 200 shown; both circles still selected |
| A4 | WP2 | Press the `Shaft Lines` chip (or `Select`, click empty canvas, click each circle edge, chip) | Status `Shaft lines: 2 added`; two horizontal lines at y = ±10 joining the circles |
| A5 | WP2 | Extrude 10, export 3MF | `check_rung01.py blank` 5/5 |
| A6 | WP4 | Circle tool, one click, `Esc`; then `Esc` again | First `Esc` keeps the sketch (status `First point dropped…`); second exits |
| A7 | WP4 | After Extrude press `Esc`; palette `Sketch`; one click on the top face | Body deselected; sketch opens on the top face |
| A8 | WP1 | In the face sketch press `Jaw`; three clicks (centre, long side, half-width), dimension 20 | Four lines; width 20 |
| A9 | — | Pivot hole Ø10, Trim the jaw, cut Up To Surface through the bottom face (Opposite face) | Hole and open jaw cut; body is a wrench, not a mangled solid |
| A10 | WP3 | In a scratch document: Ø100 disc, 10 mm; cut a Ø90 circle from the top face | Status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; body unchanged; sketch open |
| A11 | — | Slot 2.5 deep, fillets (R10 neck, 1 mm edges) | Per the handout; any refused fillet shows its reason |
| A12 | — | Export `wrench.3mf` | `check_rung01.py wrench` 28/28, no `--allow-mirror`, orientation row `flipX=False flipY=False` |
| A13 | — | Timeline Distance 14 (steps above), export `wrench-t14.3mf` | `check_rung01.py thick wrench-t14.3mf 14` 4/4 |
| A14 | — | Nut: polygon AF 20, hole Ø10, Extrude 7.5, export | `check_rung01.py nut` 7/7 |
| A15 | WP5 | `python3 tools/lint_rung01_e2e.py` and `run_rung01_wrench.gd` | lint clean; `397 checks, 0 failures` |

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 4/4, walk 0 failures, part made in the real GUI.

## Out of scope

- No kernel change, no change to `select_ray` or any pick logic, no change to the checker.
- No override for the cut guard; no guard on fuse, revolve or thickness edits.
- No new sketch tool beyond the rail labels and `Jaw`; `Shaft Lines` is a chip, not a tool.
- No fix for soft-GL typing; no change to the dimension popup.
- Wave features and `docs/plan/*` are untouched.
