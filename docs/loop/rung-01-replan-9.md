# Rung 1 replan 9 — highlight the active chip, keep the Smart Dim first pick, stop autosave hiding the Discard prompt

Status: plan only. No product code in this change.

Baseline: `main` at `e85bd766` (merge of #101; replan 8 WP1–WP5 are all in). Replan 8 is [`rung-01-replan-8.md`](rung-01-replan-8.md). The sx-029 critique of that build scored **7/10** and failed rung 1 (up from 6). Leftovers: [`rung-01-leftovers-sx029.md`](rung-01-leftovers-sx029.md). The sx-029 evidence (CRITIQUE, WALK_LOG, the two screenshots `A2-jaw`, `A8-retry3-blocked`) was read for this plan; `e85bd766` is not re-critiqued.

Every claim below was measured on `e85bd766` on a VM with Godot 4.7-stable and OCCT 8.0.1, headless, at 1280×800. (OCCT was built from the pinned `V8_0_1` tarball with `-DBUILD_MODULE_Visualization=OFF` to save build time; the kernel does not link visualization libraries.) Every code block in the WPs was run: the product diffs, the three new test files, the lint, Makefile and walk edits were applied together; the whole `game/tests/run_*.gd` list was run before and after (96 suites before, 99 after); `run_rung01_wrench.gd` printed `399 checks, 0 failures` with the real `check_rung01.py` inside it (nut 7/7, wrench 28/28, thick 4/4). The BUILD agent copies, it does not design.

BUILD agents execute one WP each. WP1–WP3 touch different functions and merge in any order; `game/scripts/main.gd` and `game/scripts/sketch_mode.gd` are edited by more than one WP in different hunks, so rebase on `main` before opening the PR and re-run your WP's test. WP4 (walk, lint, Makefile) merges last, rebased on `main` after WP1–WP3. Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1. Set `LD_LIBRARY_PATH=<occt prefix>/lib` (for example `/opt/occt-8.0.1/lib`) before every Godot command or `libsxcore.so` does not load. The first Godot run on a fresh checkout bakes `game/.godot`; run `tools/godot/godot --headless --path game --import` once first. Godot writes a `<script>.gd.uid` file next to every script it loads. Do not commit the `.uid` files for the new `run_rung01_replan9_*.gd` tests (the replan 8 test scripts' `.uid` files are not tracked either), and do not add anything else Godot generates.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and gets what the checker wants. sx-029 got as far as the blank and then lost it. This plan removes the three product causes that showed in sx-029's logs and re-requires the rows it could not reach:

- When a tool has variant chips, **exactly one chip is highlighted: the one in use.** Pressing `Jaw` highlights `Center Three Point`; pressing `Rect` highlights `Corner`; clicking another chip moves the highlight. (sx-029 A2.)
- Smart Dim between two circle centres works with **two plain clicks, no Shift**, and a missed second click no longer silently throws away the first pick. After the first pick the status says what to click next. `Esc` with a first pick drops the pick and keeps the sketch. (sx-029 A3 friction.)
- **File → New and File → Open ask "Discard unsaved changes?" for a blank that has not been saved**, even after the 60 s autosave has run. Today the autosave marks the document saved, so File → New threw the sx-029 blank away with no prompt; every rebuild after that hit soft-GL. (sx-029 A6 note.)
- The headless walk asserts the highlight and the first-pick status, so what it does is what a person sees.
- The sx-030 walker keeps the blank open through A8–A13 and runs the scratch-document rows last.

Checker commands on files the export dialog wrote (all unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf               # 5/5, run right after Extrude 10
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Do not pass `--allow-mirror`. Exit code 0 is the pass.

**Pass bar (unchanged).** Rung 1 is done when sx-030 follows the checklist at the end of this file, the four checker commands pass on files exported from the GUI (nut 7/7, blank 5/5, wrench 28/28, thick 4/4), `run_rung01_wrench.gd` prints 0 failures, the part was made in the real GUI without `select_entity` or any other script-side shortcut, and the score is at least 9.

## What the investigation found

### F1. P1 — no variant chip is ever highlighted, so the Jaw chip cannot be

Code:

- `SketchContextChrome.show_variants` (`game/scripts/sketch_context_chrome.gd`) builds each chip as a plain `Button` with no state. A chip row has never shown which variant is active, for any tool (Rect → `Corner`, Circle → `Center`, Line → `Line`, Polygon → `Vertex` are all unmarked too). sx-029 A2 ("`Center Three Point` chip not highlighted vs peers") is therefore not a Jaw bug; Jaw is the first place a human needed it.
- `SketchMode.start_jaw_tool` calls `set_tool(Tool.RECT)` (which emits `tool_changed`, and `main._on_sketch_tool_changed` builds the chips while `tool_variant` is still `corner`) and only then `set_tool_variant("center_three_point")`. Nothing is emitted after the variant changes, so even a highlight written only into `show_variants` would mark `Corner` after Jaw. The fix needs a signal after `set_tool_variant`.
- The chip row is hidden on the first canvas press (`ViewportInteraction._sketch_input` calls `sketch_chrome.hide_variants()`), so the highlight matters between pressing the tool and the first click, which is exactly when the human reads the row.
- Default `Button` margins are 4 px on every side (measured: `get_theme_stylebox("normal")` is a `StyleBoxFlat` with margins 4/4/4/4). The highlighted style must use the same 4 px margins; an 8 px margin clipped the label to `Center Three Poi` in a rendered check and the container did not reflow. (Rendered under lavapipe at 1280×800: before/after screenshots were taken with a scratch script that is not part of this plan.)

Measured on `e85bd766`: the new test `run_rung01_replan9_chip.gd` prints `23 checks, 11 failures`; every "only X is highlighted" row fails with `got []`.

### F2. P2 — Smart Dim does not need Shift; a miss throws the first pick away

The critique and leftovers say the second plain click replaced the selection and "Shift+click is required". The code and the log say otherwise:

- Nothing in the sketch click path reads Shift. `ViewportInteraction._sketch_input` calls `sketch_mode.click(p2)` for every left press, with or without a modifier; `_additive_click` (which does read Shift) is only used by the 3D body selection path. `SketchMode._click_smart_dim` is already additive: a first click near a circle centre stores `_smart_dim_pending`; a second click on another centre or on another circle's edge calls `_smart_dim_between`.
- The headless walk (`_smart_dim_centres`) completes the centre-distance dimension with two plain `_x11_click_screen` clicks.
- Reconstructing sx-029 A3 from WALK_LOG: click 1 on c1 → pending c1, selection `[c1]`. Click 2 "near c2" → no change: it landed outside the snap radius of c2 and outside `PICK_TOLERANCE` (2.5 mm) of any edge, so `_nearest_entity_at` returned `""` and the old code ran `_smart_dim_pending.clear()`. Click 3 "exact c2" → pending is empty, so c2 became a **new first pick** and the selection was replaced by `[c2]` (this is what the walker saw: "selection REPLACED with c2, still '1 sketch entities selected'"). Click 4, Shift+click on c1 → pending c2 + c1 → dimension. The Shift made no difference; the retry after the miss did.
- `SketchMode._snap_radius()` is `clamp(max(1.25, span·0.02), 1.25, max(1.25, span·0.08))` mm, about 5.6 mm at the 280 mm view the handout needs for a 200 mm centre distance. A click a few millimetres further out misses both the centre and the edge.
- The first pick gives no feedback today: the status line does not change (WALK_LOG A3: "status unchanged"), so a human cannot tell whether the first click registered.
- `Esc` with a first Smart Dim pick falls through to `SketchMode.cancel()` and discards the whole sketch (measured on `e85bd766`: `sm.active` is false after one Esc). With the fix below keeping the pick through a miss, a person is more likely to be holding one, so the Esc step is part of the same WP.
- Clicking the same circle's centre (or edge) a second time would call `_smart_dim_between(c1, c1)`, a zero-length distance. The fix refuses it by name.

Measured on `e85bd766`: `run_rung01_replan9_dim.gd` prints `35 checks, 10 failures`: the first-pick status, the miss keeping the pick, the same-circle refusal, and the Esc step all fail; the two plain-click completions (centre then centre, centre then edge) already pass, which is the evidence that Shift is not needed.

### F3. P1 — the 60 s autosave marks the document saved, so File → New discards without asking

`main._autosave` (60 s timer) writes `user://autosave.sxp` and then sets `_last_saved_revision = view.doc.revision()`. `main._document_is_dirty` compares the same field, so after one autosave tick a never-saved blank reads as clean; `_confirm_discard` then runs File → New / File → Open straight away. sx-029 A6: "File→New (no unsaved-changes prompt for the blank doc)". The walk to that point had taken longer than 60 s. That is the whole reason the blank was gone for A8–A14, and the three rebuilds that followed all died in soft-GL (F4). The critique filed it as out of scope "unless it keeps blocking walks"; it did.

Fix: track the autosave in its own field (`_last_autosaved_revision`). The autosave still writes the file and still skips when nothing changed since the last autosave or the last real save; it just no longer touches `_last_saved_revision`. `_save_current`, `Save As`, `Open` and `_do_new` still set `_last_saved_revision`, which is correct.

Measured on `e85bd766`: `run_rung01_replan9_dirty.gd` prints `13 checks, 3 failures` (autosave marks the document saved; second autosave likewise; File → New shows no prompt).

### F4. P2 — soft-GL after a radius dimension (environmental, no WP)

Unchanged conclusion from replan 8 F5 and the critique: after `radius: success` the llvmpipe viewport often stays stale (label Ø4.18 / Ø161.92) and the chip row ghosts; Frame does not always clear it; digits drop or reorder in fields. The status line was correct each time (`radius: success`, `Circle r=10.0000 (Ø20.0000)`). No driver WP, no product WP. What this plan does about it: (a) WP3 removes the event that forced three rebuilds; (b) the walker protocol below adds a saved checkpoint and tells the walker to read the status line, not the viewport; (c) the rebuild rule: never File → New before `wrench.3mf` and `wrench-t14.3mf` are exported.

### F5. Carry — A8–A14 are still untested in a real GUI

A8–A9 (jaw, hole, trim, cut), A10 (81 % refusal), A11 (slot, fillets), A12 (wrench), A13 (thick), A14 (nut) never ran in sx-029 (blocked or not reached). They stay in the checklist unchanged below; WP1–WP3 touch none of their code paths. Headless covers all of them (`run_rung01_wrench.gd`, `run_rung01_replan8_cut.gd`). The sx-030 walker order is changed so none of them needs a File → New before the wrench is exported.

### F6. Observed, not planned

Written down so nobody re-investigates them without new evidence:

- A6: after the second `Esc` the sketch closes but the status line still shows `First point dropped — Esc again exits the sketch`. Cosmetic; A6 passed.
- A7: "stray `45.00` vertical dimension graphic" in the new face sketch. `SketchMode._activate_session` calls `dimensions.clear()` and `_clear_dimension_labels()`, so it is not a sketch dimension of the old sketch. The selected-body bounding-box measure labels are drawn in the viewport at the same time (the blank is 44.9 mm across in Y). Not reproduced; if sx-030 sees it again on a body that is not selected, it is a new finding.
- A3/retry: rim click took its radius from the last pointer motion (Ø4.18); pointer moves issued right after a click are dropped by the desktop (WALK_LOG retry3 note). Environmental; the walker re-issues the move.
- Rebuild 1: Smart Dim "pick at the small-circle edge selected the large circle". The two circles were r 3.48 and r 31.03 at the same zoom, mouse-drawn under pointer lag. Not reproduced; `_nearest_entity_at` picks the nearest edge within 2.5 mm.
- The 18 rail labels need a rail scroll at 800 px (A1 PASS). Unchanged.
- Dim auto-popup flaky on centre picks (replan 8 carry): unchanged; workaround double-click the dimension label.

## Work packages

| WP | What | Files | Test | Red on `e85bd766` | Green after |
|---|---|---|---|---|---|
| WP1 | Highlight the active variant chip (toggle chips, `tool_variant_changed` signal) | `game/scripts/sketch_context_chrome.gd`, `game/scripts/sketch_mode.gd`, `game/scripts/main.gd` | `run_rung01_replan9_chip.gd` (new) | 23 checks, 11 failures | 23 checks, 0 failures |
| WP2 | Smart Dim: first-pick status, a miss keeps the pick, same-circle refusal, Esc drops the pick | `game/scripts/sketch_mode.gd`, `game/scripts/viewport_interaction.gd` | `run_rung01_replan9_dim.gd` (new) | 35 checks, 10 failures | 35 checks, 0 failures |
| WP3 | Autosave no longer marks the document saved | `game/scripts/main.gd` | `run_rung01_replan9_dirty.gd` (new) | 13 checks, 3 failures | 13 checks, 0 failures |
| WP4 | Walk asserts chip highlight and first-pick status; lint and Makefile cover replan 9 | `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile` | the walk | 397 checks, 0 failures | 399 checks, 0 failures |

Order of work: WP1, WP2, WP3 in any order, each its own PR; WP4 last. Product fixes come before the walk. If any of WP1–WP3 is not merged, WP4 does not start. PR titles: `Rung 1 replan 9 WP1: highlight the active variant chip`, `Rung 1 replan 9 WP2: Smart Dim keeps its first pick`, `Rung 1 replan 9 WP3: autosave keeps the document dirty`, `Rung 1 replan 9 WP4: walk, lint and Makefile cover replan 9`.

How each new test was measured red: the same file was run on a tree at `e85bd766` with no product change; the red counts above are those runs. In `run_rung01_replan9_dim.gd` the new methods are reached with `has_method` / `call`, so the test reports failures instead of a script error on unmodified code.

All three new tests use the same `FilmUI` rules the walk uses: sketch clicks are pushed as motion + press + release with no `await` between press and release, nothing calls `select_entity`, and `tools/lint_rung01_e2e.py` (extended in WP4) is clean on them. `run_rung01_replan9_dirty.gd` calls `main._autosave`, `main._on_file_menu` and `main._save_current` directly because the 60 s timer and the native file dialogs cannot be driven headless; it is a product-state test, not a walk.

---

### WP1 — Highlight the active variant chip

**Files.** `game/scripts/sketch_context_chrome.gd` (`show_variants`, new `_active_variant`, `sync_variant_highlight`, `_active_chip_style`), `game/scripts/sketch_mode.gd` (new signal `tool_variant_changed`, emitted at the end of `set_tool_variant`), `game/scripts/main.gd` (`_build_ui`, one `connect` line), new `game/tests/run_rung01_replan9_chip.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan9_chip.gd` with exactly this content.

```gdscript
# Rung 1 replan 9 WP1 — exactly one variant chip is highlighted: the active one (Jaw highlights Center Three Point).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan9_chip.gd
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
	print("rung01 replan9 WP1 variant chip highlight")
	FilmUI.reset_fail_count()
	await test_chip_highlight()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_chip_highlight() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	check(sm.active, "sketch is active")

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Rect"))
	await process_frame
	check(_pressed(ctx) == ["Corner"], "Rect: only Corner is highlighted (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	check(sm.tool_variant == "center_three_point", "Jaw sets the Center Three Point variant")
	check(_pressed(ctx) == ["Center Three Point"], "Jaw: only Center Three Point is highlighted (got %s)" % str(_pressed(ctx)))
	var chip := _chip(ctx, "Center Three Point")
	check(chip != null and chip.is_visible_in_tree(), "the Center Three Point chip is visible")
	if chip != null:
		var style := chip.get_theme_stylebox("pressed") as StyleBoxFlat
		check(style != null and style.bg_color == Color("2d5f93") and style.border_color == Color("6ab0f3"),
				"the highlighted chip draws the accent fill and border")
		var other := _chip(ctx, "Corner")
		check(other != null and not other.button_pressed, "the Corner chip is not highlighted")

	await _x11_click(_chip(ctx, "Parallelogram"))
	await process_frame
	check(sm.tool_variant == "parallelogram", "clicking Parallelogram sets the variant")
	check(_pressed(ctx) == ["Parallelogram"], "Parallelogram click: only Parallelogram is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Parallelogram"))
	await process_frame
	check(_pressed(ctx) == ["Parallelogram"], "clicking the active chip again keeps it highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Corner"))
	await process_frame
	check(_pressed(ctx) == ["Corner"], "Corner click moves the highlight back (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Circle"))
	await process_frame
	check(_pressed(ctx) == ["Center"], "Circle: only Center is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Perimeter"))
	await process_frame
	check(_pressed(ctx) == ["Perimeter"], "Perimeter click: only Perimeter is highlighted (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Line"))
	await process_frame
	check(_pressed(ctx) == ["Line"], "Line: only Line is highlighted (got %s)" % str(_pressed(ctx)))
	await _x11_click(_chip(ctx, "Centerline"))
	await process_frame
	check(sm.tool == SketchMode.Tool.CENTERLINE, "clicking Centerline switches the tool")
	check(_pressed(ctx) == ["Centerline"], "Centerline click: only Centerline is highlighted (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Polygon"))
	await process_frame
	await _x11_click(_chip(ctx, "Across Flats"))
	await process_frame
	check(_pressed(ctx) == ["Across Flats"], "Polygon: Across Flats click highlights only Across Flats (got %s)" % str(_pressed(ctx)))

	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Jaw"))
	await process_frame
	await _zoom(ctx, Vector3(0, 0, 0), 120.0)
	await _click_uv(ctx, vp, Vector2.ZERO)
	await _click_uv(ctx, vp, Vector2(30.0, 0.0))
	await _click_uv(ctx, vp, Vector2(0.0, 10.0))
	await process_frame
	var lines := 0
	for id in sm.sketch.entity_ids():
		if not sm.sketch.is_construction(id) and str(sm.sketch.entity_info(id).get("type", "")) == "line":
			lines += 1
	check(lines == 4, "Jaw still draws a four-line rectangle after the highlight change (got %d)" % lines)
	await _shutdown(ctx)


func _variant_bar(ctx: FilmContext) -> Node:
	return ctx.main.sketch_chrome.find_child("VariantBar", true, false)


func _chip(ctx: FilmContext, text: String) -> Button:
	var bar := _variant_bar(ctx)
	if bar == null:
		return null
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.text == text:
			return b
	return null


func _pressed(ctx: FilmContext) -> Array[String]:
	var out: Array[String] = []
	var bar := _variant_bar(ctx)
	if bar == null:
		return out
	for c in bar.get_children():
		var b := c as Button
		if b != null and b.button_pressed:
			out.append(b.text)
	return out


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

Run it on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan9_chip.gd
```

Expected on `e85bd766`: `23 checks, 11 failures` (every `only … is highlighted` row prints `got []`, plus `the highlighted chip draws the accent fill and border`). If different, stop.

**Commit 2 — the product change.** Apply all three diffs. (Apply each hunk by its context, not its line numbers.)

`game/scripts/sketch_context_chrome.gd`:

```diff
diff --git a/game/scripts/sketch_context_chrome.gd b/game/scripts/sketch_context_chrome.gd
--- a/game/scripts/sketch_context_chrome.gd
+++ b/game/scripts/sketch_context_chrome.gd
@@ -1206,14 +1206,57 @@ func show_variants(kind: String, variants: Array, screen_pos: Vector2) -> void:
 		var b := Button.new()
 		b.text = label.capitalize().replace("_", " ")
 		b.custom_minimum_size = Vector2(0, _chip_h())
-		b.pressed.connect(func() -> void: variant_chosen.emit(kind, label))
+		b.toggle_mode = true
+		b.set_meta("variant", label)
+		b.add_theme_stylebox_override("pressed", _active_chip_style())
+		b.add_theme_stylebox_override("hover_pressed", _active_chip_style())
+		b.add_theme_color_override("font_pressed_color", Color.WHITE)
+		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
+		b.pressed.connect(func() -> void:
+			variant_chosen.emit(kind, label)
+			sync_variant_highlight())
 		_variant_bar.add_child(b)
+	sync_variant_highlight()
 	_variant_bar.visible = not variants.is_empty()
 	# Ignore a caller Y that would pull the chips up into the finish bar.
 	if _variant_bar.visible:
 		place_variant_row(screen_pos.x)
 
 
+## Variant chip that matches what SketchMode is doing right now.
+func _active_variant() -> String:
+	if sketch_mode == null:
+		return ""
+	if _active_kind == "line":
+		return "centerline" if sketch_mode.tool == SketchMode.Tool.CENTERLINE else "line"
+	return sketch_mode.tool_variant
+
+
+## Exactly one chip is pressed: the active variant. A toggle chip pressed twice
+## would un-press itself, so every press re-syncs.
+func sync_variant_highlight() -> void:
+	if _variant_bar == null:
+		return
+	var active := _active_variant()
+	for c in _variant_bar.get_children():
+		var b := c as Button
+		if b != null and b.has_meta("variant"):
+			b.set_pressed_no_signal(str(b.get_meta("variant")) == active)
+
+
+func _active_chip_style() -> StyleBoxFlat:
+	var s := StyleBoxFlat.new()
+	s.bg_color = Color("2d5f93")
+	s.border_color = Color("6ab0f3")
+	s.set_border_width_all(2)
+	s.set_corner_radius_all(3)
+	s.content_margin_left = 4.0
+	s.content_margin_right = 4.0
+	s.content_margin_top = 4.0
+	s.content_margin_bottom = 4.0
+	return s
+
+
 ## Stack variant chips on the next row under the finish bar. Caller Y is not
 ## used; rail_x is the left edge. WP4 calls this instead of show_variants(y=80).
 func place_variant_row(rail_x: float) -> void:
```

`game/scripts/sketch_mode.gd`:

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -824,6 +824,8 @@ func ray_to_sketch(origin: Vector3, direction: Vector3) -> Variant:
 
 
 signal tool_changed(tool: int)
+## Emitted after set_tool_variant. The chip row re-highlights the active chip.
+signal tool_variant_changed
 ## Emitted when selection chips should refresh (ids may be empty).
 signal selection_actions_needed
 ## Live rubber-band distance (mm) while a single-DOF draw step is active.
@@ -881,6 +883,7 @@ func set_tool_variant(v: String) -> void:
 		status.emit(JAW_HINT)
 	else:
 		status.emit("Variant: %s" % v.replace("_", " "))
+	tool_variant_changed.emit()
 
 
 ## True when a draw tool has the first anchor and is waiting for the tip.
```

`game/scripts/main.gd`:

```diff
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -865,6 +868,7 @@ func _build_ui() -> void:
 	sketch_chrome.visible = false
 	ui.add_child(sketch_chrome)
 	sketch_chrome.variant_chosen.connect(_on_sketch_variant)
+	sketch_mode.tool_variant_changed.connect(sketch_chrome.sync_variant_highlight)
 	sketch_chrome.action_chosen.connect(_on_sketch_action)
 	sketch_chrome.finish_requested.connect(_on_sketch_finish)
 	sketch_chrome.dim_submitted.connect(_on_sketch_dim_submitted)
```

Notes the BUILD agent needs:

- Every chip is a toggle `Button` carrying its variant string in `set_meta("variant", …)`. `sync_variant_highlight` presses exactly the chip whose variant equals `_active_variant()` using `set_pressed_no_signal`, so it never re-fires `pressed`.
- `_active_variant()` is `sketch_mode.tool_variant`, except for the Line/Centerline chips (kind `"line"`): those are tools, not variants, so the active one is `centerline` when `sketch_mode.tool == Tool.CENTERLINE`, else `line`. Polygon chips (kind `""`) use `tool_variant`, which `set_tool` already sets from `_polygon_variant`.
- A toggle chip that is pressed again would un-press itself, so the `pressed` handler calls `sync_variant_highlight()` after emitting `variant_chosen`. The test clicks the active chip twice and expects it to stay highlighted.
- The `tool_variant_changed` connection is made once in `_build_ui` next to the other `sketch_chrome` connections. `sync_variant_highlight` takes no arguments because the signal has none.
- Colours are fixed: fill `#2d5f93`, border `#6ab0f3` (the accent in `UIIcons.ACCENT`), 2 px border, 3 px corners, 4 px content margins, white label. Do not choose others; the sx-030 checklist row reads these colours.
- No change to `ui_icons.gd`, to the rail buttons, or to the layout code. The rail's active tool is not highlighted by this WP; see "Out of scope".

Step: run the test again. Expected: `23 checks, 0 failures`.

**Regression commands (all must match):**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_layout_tests.gd                    # 33 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan2_layout.gd          # 22 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_dead_chrome_tests.gd              # 28 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_rail.gd            # 89 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan6_chrome.gd          # 64 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_sketch_tools_tests.gd              # 141 checks, 13 failures (same as main)
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_icon_tests.gd                      # 13 checks, 2 failures (same as main)
```

**GUI checklist item (sx-029 A2).** In a sketch press `Jaw`. The `Center Three Point` chip has a blue fill with a light-blue border; the other four chips (`Corner`, `Center`, `Three Point`, `Parallelogram`) are plain grey; the label is not clipped. The status line reads `Jaw — click 1 centre, click 2 end of the long side, click 3 half the width`. Press `Rect`: `Corner` is highlighted. Click `Parallelogram`: the highlight moves to it; click it again: it stays.

---

### WP2 — Smart Dim keeps its first pick

**Files.** `game/scripts/sketch_mode.gd` (`_click_smart_dim`, three constants, new `has_pending_dim_pick`, `cancel_pending_dim_pick`), `game/scripts/viewport_interaction.gd` (`_sketch_input`, the `KEY_ESCAPE` case), new `game/tests/run_rung01_replan9_dim.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan9_dim.gd` with exactly this content.

```gdscript
# Rung 1 replan 9 WP2 — Smart Dim keeps its first pick through a miss, says so, and Esc drops it without leaving the sketch.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dim.gd
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
	print("rung01 replan9 WP2 smart dim second pick")
	FilmUI.reset_fail_count()
	await test_centre_then_centre()
	await test_centre_then_edge()
	await test_esc_drops_pick()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _two_circles(ctx: FilmContext) -> Array[String]:
	var sm: SketchMode = ctx.main.sketch_mode
	var a: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var b: String = sm.sketch.add_circle(200.0, 0.0, 22.5)
	await _zoom(ctx, Vector3(100, 0, 0), 280.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SMART_DIM)
	return [a, b]


func test_centre_then_centre() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var ids := await _two_circles(ctx)
	var edits: Array[int] = []
	sm.dimension_edit_requested.connect(func(i: int) -> void: edits.append(i))

	_status_log.clear()
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "the first centre click sets a pending pick")
	check(sm.selected.size() == 1 and sm.selected[0] == ids[0], "the first circle is selected")
	check(_status_has("Smart Dim: first pick set"), "the first pick says what to click next (log: %s)" % str(_status_log))

	_status_log.clear()
	await _click_uv(ctx, vp, Vector2(100.0, 80.0))
	check(_pending(sm), "a click on empty canvas keeps the first pick")
	check(sm.selected.size() == 1 and sm.selected[0] == ids[0], "the first circle stays selected after the miss")
	check(_status_has("first pick kept"), "the miss is named in the status (log: %s)" % str(_status_log))

	_status_log.clear()
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "a second click on the same circle keeps the first pick")
	check(_status_has("pick a different circle"), "the same-circle click is named (log: %s)" % str(_status_log))
	check(_distance_near(sm, 0.0, 0.5) < 0, "no zero-length distance dimension was made")

	await _click_uv(ctx, vp, Vector2(200.0, 0.0))
	await process_frame
	await process_frame
	check(not _pending(sm), "the second centre click completes the pick")
	check(sm.selected.size() == 2, "both circles are selected after the dimension (got %d)" % sm.selected.size())
	check(_distance_near(sm, 200.0, 0.5) >= 0, "a centre distance of 200 was dimensioned")
	check(not edits.is_empty(), "the dimension editor was requested")
	await _shutdown(ctx)


func test_centre_then_edge() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	var ids := await _two_circles(ctx)
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "first centre pick is pending")
	await _click_uv(ctx, vp, Vector2(200.0, 22.5))
	await process_frame
	await process_frame
	check(not _pending(sm), "an edge click on the second circle completes the pick")
	check(sm.selected.size() == 2 and sm.selected.has(ids[0]) and sm.selected.has(ids[1]), "both circles are selected")
	check(_distance_near(sm, 200.0, 0.5) >= 0, "the edge pick dimensions the centre distance, 200")
	await _shutdown(ctx)


func test_esc_drops_pick() -> void:
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = ctx.main.sketch_mode
	var vp: Viewport = ctx.main.get_viewport()
	await _two_circles(ctx)
	await _click_uv(ctx, vp, Vector2.ZERO)
	check(_pending(sm), "first centre pick is pending before Esc")
	_status_log.clear()
	await _x11_key(vp, KEY_ESCAPE)
	check(sm.active, "Esc with a pending Smart Dim pick keeps the sketch open")
	check(not _pending(sm), "Esc drops the pending pick")
	check(sm.selected.is_empty(), "Esc clears the first-pick selection")
	check(_status_has("Smart Dim pick dropped"), "Esc says the pick was dropped (log: %s)" % str(_status_log))
	check(sm.sketch.entity_ids().size() == 2, "both circles are still in the sketch")
	await _x11_key(vp, KEY_ESCAPE)
	check(not sm.active, "Esc with nothing pending still exits the sketch")
	await _shutdown(ctx)


func _pending(sm: SketchMode) -> bool:
	return sm.has_method("has_pending_dim_pick") and bool(sm.call("has_pending_dim_pick"))


func _distance_near(sm: SketchMode, value: float, tol: float) -> int:
	for i in sm.dimensions.size():
		var d: Dictionary = sm.dimensions[i]
		if str(d.get("type", "")) == "distance" and absf(float(d.get("value", -1.0)) - value) <= tol:
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

Run it on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dim.gd
```

Expected on `e85bd766`: `35 checks, 10 failures`: `the first centre click sets a pending pick`, `the first pick says what to click next`, `a click on empty canvas keeps the first pick`, `the miss is named in the status`, `a second click on the same circle keeps the first pick`, `the same-circle click is named`, `first centre pick is pending` (centre-then-edge test), `first centre pick is pending before Esc`, `Esc with a pending Smart Dim pick keeps the sketch open`, `Esc says the pick was dropped`. The two completions (`centre then centre`, `centre then edge`) pass on unmodified code: that is the evidence that Shift is not needed. If different, stop.

**Commit 2 — the product change.** Apply both diffs.

`game/scripts/sketch_mode.gd`:

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -3328,26 +3331,52 @@ func _add_semicircle(center: Vector2, start_off: Vector2, outward: Vector2) -> v
 		prev = p
 
 
+const SMART_DIM_PICK_HINT := "Smart Dim: first pick set — click the second circle's centre or edge (Esc drops it)"
+const SMART_DIM_MISS_HINT := "Smart Dim: nothing there — first pick kept, click the second circle's centre or edge (Esc drops it)"
+const SMART_DIM_SAME_HINT := "Smart Dim: pick a different circle — first pick kept"
+
+
+## True while Smart Dim holds a first centre pick and waits for the second.
+func has_pending_dim_pick() -> bool:
+	return tool == Tool.SMART_DIM and not _smart_dim_pending.is_empty()
+
+
+## Esc with a first Smart Dim pick: drop the pick and keep the sketch session.
+func cancel_pending_dim_pick() -> void:
+	_smart_dim_pending.clear()
+	_smart_dim_first = null
+	_set_selected([])
+
+
 func _click_smart_dim(pos2: Vector2) -> void:
 	var center_ref := _center_ref_near(pos2)
 	if not center_ref.is_empty():
 		if not _smart_dim_pending.is_empty():
+			if str(_smart_dim_pending["entity"]) == str(center_ref["entity"]):
+				status.emit(SMART_DIM_SAME_HINT)
+				return
 			_smart_dim_between(_smart_dim_pending, center_ref)
 			_smart_dim_pending.clear()
 		else:
 			_smart_dim_pending = center_ref
 			_set_selected([str(center_ref["entity"])])
+			status.emit(SMART_DIM_PICK_HINT)
 		_smart_dim_first = null
 		return
 	var hit := _nearest_entity_at(pos2)
 	if hit == "":
-		_smart_dim_pending.clear()
+		if not _smart_dim_pending.is_empty():
+			status.emit(SMART_DIM_MISS_HINT)
+			return
 		_smart_dim_first = null
 		return
 	var info: Dictionary = sketch.entity_info(hit)
 	match str(info.get("type", "")):
 		"circle", "arc":
 			if not _smart_dim_pending.is_empty():
+				if str(_smart_dim_pending["entity"]) == hit:
+					status.emit(SMART_DIM_SAME_HINT)
+					return
 				_smart_dim_between(_smart_dim_pending, {"entity": hit, "role": "center"})
 				_smart_dim_pending.clear()
 			else:
```

`game/scripts/viewport_interaction.gd`:

```diff
diff --git a/game/scripts/viewport_interaction.gd b/game/scripts/viewport_interaction.gd
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -2655,6 +2655,9 @@ func _sketch_input(event: InputEvent) -> void:
 					# keep the sketch session so Extrude stays available.
 					sketch_mode.end_chain()
 					status.emit("Chain ended")
+				elif sketch_mode.has_pending_dim_pick():
+					sketch_mode.cancel_pending_dim_pick()
+					status.emit("Smart Dim pick dropped — Esc again exits the sketch")
 				elif sketch_mode.has_pending_draw_point():
 					sketch_mode.cancel_pending_draw()
 					status.emit("First point dropped — Esc again exits the sketch")
```

Notes the BUILD agent needs:

- The three hint strings are asserted by substring in the test (`Smart Dim: first pick set`, `first pick kept`, `pick a different circle`) and by the walk (WP4). Keep the text, including the em dashes.
- A miss with a pick pending **returns** without touching `_smart_dim_pending` or the selection. A miss with nothing pending behaves as before (clears `_smart_dim_first`; nothing else to clear). `set_tool` and `_activate_session` already clear `_smart_dim_pending`, so the pick cannot leak into another tool or another sketch.
- The same-circle check is in both places a second pick is accepted: the centre branch (`center_ref`) and the circle/arc edge branch. The line branches are untouched.
- `has_pending_dim_pick` requires `tool == Tool.SMART_DIM`. Do **not** add Smart Dim to `has_pending_draw_point`: the mouse-up path in `_sketch_input` and `finish_extrude` both call it and would then fire a second `click` on release.
- Esc order inside a sketch is now: clear the measure anchor → unlock the typed length → end an open Line chain → **drop a pending Smart Dim pick** → drop a pending first point → exit the sketch. The new branch sits before the replan 8 `has_pending_draw_point` branch.
- A first click on a circle **edge** with nothing pending still dimensions that circle's diameter immediately; unchanged. Only a centre pick starts a pending pair.

Step: run the test again. Expected: `35 checks, 0 failures`.

**Regression commands:**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan4_smartdim.gd         # 47 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan5_smartdim.gd         # 66 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan6_smartdim.gd         # 81 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan8_esc.gd              # 20 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_infer_tests.gd                    # 44 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_sketch_tests.gd                   # 83 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_sketch_parity_tests.gd            # 30 checks, 0 failures
```

**GUI checklist item (sx-029 A3).** Two circles on screen (Ø20 at the origin, Ø45 to its right). Press `Smart Dim`. Click the dot at the centre of the Ø20: the status reads `Smart Dim: first pick set — click the second circle's centre or edge (Esc drops it)`. Click empty canvas between the circles: `Smart Dim: nothing there — first pick kept, …`; the Ø20 is still selected. Click the dot at the centre of the Ø45, plain click, no Shift: the dimension popup opens. Type `200`, Enter: `Dimension updated`. Separately, with one pick set, press `Esc`: the sketch stays open, the circle is deselected, status `Smart Dim pick dropped — Esc again exits the sketch`.

---

### WP3 — Autosave keeps the document dirty

**Files.** `game/scripts/main.gd` (new var `_last_autosaved_revision`, `_autosave`), new `game/tests/run_rung01_replan9_dirty.gd`.

**Commit 1 — the test.** Create `game/tests/run_rung01_replan9_dirty.gd` with exactly this content.

```gdscript
# Rung 1 replan 9 WP3 — the 60 s autosave must not mark the document saved: File > New still asks before it discards.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dirty.gd
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
	print("rung01 replan9 WP3 autosave keeps the document dirty")
	FilmUI.reset_fail_count()
	await test_autosave_dirty()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_autosave_dirty() -> void:
	var ctx := await _boot()
	var main = ctx.main
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	sm.sketch.add_circle(0.0, 0.0, 10.0)
	sm.finish_extrude(10.0, "new", "blind")
	await process_frame
	await process_frame
	var doc = ctx.view.doc
	check(doc.body_ids().size() == 1, "one body exists")
	check(main._document_is_dirty(), "a fresh extrude makes the document dirty")

	var autosave_path := ProjectSettings.globalize_path("user://autosave.sxp")
	if FileAccess.file_exists(autosave_path):
		DirAccess.remove_absolute(autosave_path)
	main._autosave()
	check(FileAccess.file_exists(autosave_path), "the autosave wrote user://autosave.sxp")
	check(main._document_is_dirty(), "the autosave does not mark the document saved")
	main._autosave()
	check(main._document_is_dirty(), "a second autosave still does not mark the document saved")

	main._on_file_menu(0)
	await process_frame
	await process_frame
	check(main.confirm_dialog.visible, "File > New after an autosave asks to discard unsaved changes")
	check(doc.body_ids().size() == 1, "the body is still there while the prompt is up")
	main.confirm_dialog.hide()
	await process_frame
	check(doc.body_ids().size() == 1, "Cancel keeps the document")

	var save_path := "/tmp/replan9_dirty.sxp"
	main.current_path = save_path
	main._save_current()
	await process_frame
	check(not main._document_is_dirty(), "a real Save marks the document clean")
	main._on_file_menu(0)
	await process_frame
	await process_frame
	check(not main.confirm_dialog.visible, "File > New after a real Save does not ask")
	check(ctx.view.doc.body_ids().size() == 0, "File > New after a real Save gives an empty part")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
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

Run it on unmodified product code:

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan9_dirty.gd
```

Expected on `e85bd766`: `13 checks, 3 failures` (`the autosave does not mark the document saved`, `a second autosave still does not mark the document saved`, `File > New after an autosave asks to discard unsaved changes`). If different, stop.

**Commit 2 — the product change.**

`game/scripts/main.gd`:

```diff
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -125,6 +125,9 @@ func _finish_op_name() -> String:
 	return ["new", "cut", "fuse"][finish_op.selected]
 var extrude_distance: SpinBox
 var _last_saved_revision := 0
+## Revision last written to user://autosave.sxp. Kept apart from
+## _last_saved_revision so an autosave never hides the Discard prompt.
+var _last_autosaved_revision := 0
 
 
 func _ready() -> void:
@@ -1035,11 +1039,12 @@ func _build_autosave() -> void:
 
 
 func _autosave() -> void:
-	if view.doc.revision() == _last_saved_revision:
+	var rev: int = view.doc.revision()
+	if rev == _last_saved_revision or rev == _last_autosaved_revision:
 		return
 	var path := ProjectSettings.globalize_path("user://autosave.sxp")
 	if view.save(path):
-		_last_saved_revision = view.doc.revision()
+		_last_autosaved_revision = rev
 
 
 func _request_sketch() -> void:
```

Notes the BUILD agent needs:

- `_autosave` still writes `user://autosave.sxp` through `ProjectSettings.globalize_path` (the standing rule: no `user://` into C++), still skips when the revision equals the last real save, and now also skips when it equals the last autosave. It never writes `_last_saved_revision`.
- `_save_current`, the Save As handler, `_open_document` and `_do_new` keep setting `_last_saved_revision`. Do not touch them.
- Do not change the autosave interval, the autosave path, or `confirm_dialog` text. Do not add a "recover autosave" feature.
- Nothing else reads `_last_autosaved_revision`.

Step: run the test again. Expected: `13 checks, 0 failures`.

**Regression commands:**

```
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_menu_tests.gd                     # 55 checks, 2 failures (same as main)
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_ui_tests.gd                       # 275 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_workflow_tests.gd                 # 82 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan4_dialog.gd          # 47 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan5_shell.gd           # 96 checks, 0 failures
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan_shell.gd            # 34 checks, 1 failure (same as main)
```

**GUI checklist item (sx-029 A6 note).** Build the blank, export it, and wait until a minute has passed since the last edit (the export dialogs take longer than that). Do not Save. File → New: the dialog `Discard unsaved changes?` appears. Press Cancel: the blank is still on screen and nothing changed. (If the walker saved with Save As first, File → New correctly does not ask.)

---

### WP4 — The walk asserts chip highlight and first pick; lint and Makefile cover replan 9

Prerequisite: WP1–WP3 merged. **Files.** `game/tests/run_rung01_wrench.gd`, `tools/lint_rung01_e2e.py`, `Makefile`.

Why the walk edit looks the way it does:

- After pressing `Jaw`, `_draw_centre_rect` now also asserts that the `Center Three Point` chip is highlighted (`button_pressed`). It uses `FilmUI.find_button`, the same lookup a human's eye does.
- After the first Smart Dim centre click, `_smart_dim_centres` asserts the first-pick status. `_status_log` is fed by the sketch status signal; it is not cleared first (an earlier entry cannot contain the new text).
- No other walk step changes. No `select_entity`, no script-side selection.

`game/tests/run_rung01_wrench.gd`:

```diff
diff --git a/game/tests/run_rung01_wrench.gd b/game/tests/run_rung01_wrench.gd
--- a/game/tests/run_rung01_wrench.gd
+++ b/game/tests/run_rung01_wrench.gd
@@ -2027,6 +2027,7 @@ func _smart_dim_centres(ctx: FilmContext, text: String) -> void:
 	print("  Smart Dimension: _x11_click_screen first centre, no label click")
 	await _x11_click_screen(ctx.main.get_viewport(), s1)
 	await process_frame
+	check(_status_has("Smart Dim: first pick set"), "the first centre pick says what to click next")
 	await _zoom_uv(ctx, c2, 50.0)
 	var s2 := FilmUI.model_to_screen(ctx, sm.to_model(c2))
 	check(FilmUI.require_on_screen(ctx, s2, "Smart Dimension second centre"),
@@ -2057,6 +2058,9 @@ func _draw_centre_rect(ctx: FilmContext, center: Vector2) -> void:
 	await FilmUI.click_control(ctx, jaw, FilmUICues.alert("Click", "Jaw on the sketch rail"))
 	check(sm.tool == SketchMode.Tool.RECT and sm.tool_variant == "center_three_point",
 			"Jaw selects Rectangle, Center Three Point (got tool %d variant %s)" % [int(sm.tool), sm.tool_variant])
+	var jaw_chip := FilmUI.find_button(ctx.main.sketch_chrome, "Center Three Point")
+	check(jaw_chip != null and jaw_chip.button_pressed,
+			"the Center Three Point chip is highlighted after Jaw")
 	var along := Vector2(cos(deg_to_rad(45.0)), sin(deg_to_rad(45.0)))
 	var across := Vector2(-along.y, along.x)
 	await _x11_click_uv(ctx, center, "Rect centre")
```

`tools/lint_rung01_e2e.py` and `Makefile`:

```diff
diff --git a/tools/lint_rung01_e2e.py b/tools/lint_rung01_e2e.py
--- a/tools/lint_rung01_e2e.py
+++ b/tools/lint_rung01_e2e.py
@@ -360,6 +360,22 @@ def _lint_replan8(errors: list[str]) -> None:
         _lint_dimension_label_pos2(src, errors, prefix)
 
 
+def _lint_replan9(errors: list[str]) -> None:
+    paths = sorted(TESTS.glob("run_rung01_replan9_*.gd"))
+    if not paths:
+        errors.append(f"no run_rung01_replan9_*.gd scripts under {TESTS}")
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
@@ -373,6 +389,7 @@ def main() -> int:
     _lint_replan6(errors)
     _lint_replan7(errors)
     _lint_replan8(errors)
+    _lint_replan9(errors)
 
     if errors:
         print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
@@ -385,6 +402,7 @@ def main() -> int:
     n6 = len(list(TESTS.glob("run_rung01_replan6_*.gd")))
     n7 = len(list(TESTS.glob("run_rung01_replan7_*.gd")))
     n8 = len(list(TESTS.glob("run_rung01_replan8_*.gd")))
+    n9 = len(list(TESTS.glob("run_rung01_replan9_*.gd")))
     print(f"lint_rung01_e2e: {WALK} is clean")
     print(f"lint_rung01_e2e: {n3} replan3 scripts are clean")
     print(f"lint_rung01_e2e: {n4} replan4 scripts are clean")
@@ -392,6 +410,7 @@ def main() -> int:
     print(f"lint_rung01_e2e: {n6} replan6 scripts are clean")
     print(f"lint_rung01_e2e: {n7} replan7 scripts are clean")
     print(f"lint_rung01_e2e: {n8} replan8 scripts are clean")
+    print(f"lint_rung01_e2e: {n9} replan9 scripts are clean")
     return 0
 
 

diff --git a/Makefile b/Makefile
--- a/Makefile
+++ b/Makefile
@@ -132,6 +132,10 @@ test-godot: build import preflight
 		[ -e "$$f" ] || continue; \
 		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
 	done
+	@for f in game/tests/run_rung01_replan9_*.gd; do \
+		[ -e "$$f" ] || continue; \
+		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
+	done
 
 lint-rung01-e2e:
 	python3 tools/lint_rung01_e2e.py
```

Run, in this order:

```
python3 tools/lint_rung01_e2e.py                      # last line: lint_rung01_e2e: 3 replan9 scripts are clean
LD_LIBRARY_PATH=<occt prefix>/lib tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd
```

Expected walk output (the checker lines are printed inside the walk):

```
7/7 passed
28/28 passed
4/4 passed
399 checks, 0 failures
```

(In order: the nut, the wrench, the thick file.) On `e85bd766` the same command prints `397 checks, 0 failures`; the two extra checks are the chip highlight and the first-pick status.

**GUI checklist item.** Covered by the WP1 and WP2 items; the sx-030 walker follows the same rail, chip and Smart Dim path as the walk.

---

## Whole-suite check (after every WP and after WP4)

Run every `game/tests/run_*.gd` one by one (do not use `make test-godot`: it stops at the first failure) and compare with this table. These are the suites that are not clean on `e85bd766`; each must print the **same** count after the change. Every other suite must print `0 failures`.

| Suite | Result on `e85bd766` (and required after) |
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

Differences that are expected and required: `run_rung01_wrench` 397 → 399 checks (WP4); `run_parse_sweep_tests` 220 → 223 checks (it parses the three new files); and the three new `run_rung01_replan9_*` suites. The kernel tests are untouched (`make test-kernel`); no C++ file changes in this plan.

The reference run: 96 suites on `e85bd766` and 99 with the change; the difference between the two summaries is exactly the three new lines above plus the two count changes (measured with a script that runs each suite and prints `name | exit code | last "N checks, M failures" line`).

## Soft-GL protocol for the sx-030 walker (no code)

Soft-GL (llvmpipe) drops, reorders and double-fires keystrokes, sometimes loses a click, and sometimes does not repaint after a dimension commit. This is environmental. The headless suites do not see it. The walker follows these rules; none of them is a shortcut. Rules 1–6 are replan 8's, unchanged; 7–12 are new from sx-029.

1. Type into one field at a time. After typing, **read the field back** (zoom the screenshot) before pressing Enter or Tab. If it does not show the intended text, select all (`Ctrl+A` in the field), retype, read back again. Up to three tries per field; log each try in WALK_LOG.
2. A click that has no effect (no status change, no selection change) may be a lost click. Repeat it once. If it again does nothing, log it as a product failure. Never click a third time. Exception: a Smart Dim second pick whose status says `first pick kept` is a miss, not a lost click; see rule 9.
3. If a field refuses a value after three tries, draw the circle by mouse (centre click, re-issue the pointer move, rim click), then size it with Smart Dimension: click the circle's edge and type the value in the popup, reading it back before Enter. Log the fallback. The centre distance 200 is always a Smart Dimension between the two centres.
4. After each dimension, wait for the status line to change before the next action.
5. When an Extrude, cut or fillet is refused, record the refusal text verbatim; a named refusal is a pass for the refusal rows, a mangled body without one is a fail.
6. Never use the film/test hooks (`select_entity`, script-side selection, direct sketch API). The walk's lint forbids them; the human walker does not use them either.
7. **The field on a circle is the radius.** Ø20 is `10`, Ø45 is `22.5`. The `Circle r=…` status shows both radius and diameter; read it. Paste via `xclip` + `Ctrl+V` when `xclip` is installed (`which xclip`; install it before the walk if missing).
8. **The status line is the truth, the viewport is not.** `radius: success`, `Dimension updated`, `Shaft lines: 2 added`, `Circle r=… (Ø…)` and the timeline panel entries (`sketch 1`, `extrude 2`) confirm a commit even when the viewport is stale (sx-029 A5, A8). Frame at most once. Do not retry a commit because the picture did not change.
9. **Smart Dim second pick is a plain click, no Shift.** After the first centre click the status must read `Smart Dim: first pick set …`. If the second click gives `nothing there — first pick kept`, the first pick is alive: click closer to the centre dot (or on the circle edge) and again. Do not start over.
10. **Keep the blank open until `wrench.3mf` and `wrench-t14.3mf` are exported. No File → New before then.** After A5 and A5b, File → Save As `blank.sxp` into the sx-030 `out` folder as a checkpoint.
11. If the viewport stays ghosted after one Frame (chip rows stuck mid-canvas, stale label), and a `blank.sxp` checkpoint exists: File → Open `blank.sxp` once (press the Discard dialog's OK; it appears because the document is unsaved) and carry on from the reopened document. This is untested; log what happens. If no checkpoint exists, or the reopened document is also ghosted, record HARD BLOCK and stop that row.
12. Pointer moves issued right after a click are dropped by the desktop: after each click, move the pointer in a separate action before the next click or rim pick.

## Timeline Distance 14 (carry, GUI)

After the wrench is finished and exported as `wrench.3mf`: open the timeline, double-click the base Extrude (the first extrude, Distance 10), set Distance to 14, Enter. The Up To Surface jaw cut follows the new depth (the jaw is still open through, the slot floor stays 2.5 mm below the top). Export `wrench-t14.3mf` and run `python3 tools/check_rung01.py thick wrench-t14.3mf 14` → 4/4. If the replan 8 cut refusal fires during this edit, record the text: it means the edit changed the removed volume by more than half, which is a product failure for this row.

## sx-030 GUI checklist

The walker does the handout in the real GUI at 1280×800 on the build that contains WP1–WP4, logs every step, and runs the four checkers on the exported files. One row per WP; the rows keep their sx-029 numbers. A step is PASS only if it was done with the mouse and keyboard.

**Walk order (changed from sx-029):** A1, A2, A3, A4, A5, A5b, A7, A6, A7b, A8, A9, A11, A12, A13, then the scratch rows A10 and A14, then A15. A10 and A14 start a new document, so they come after `wrench.3mf` and `wrench-t14.3mf` are exported. A6 runs inside the face sketch of the blank so no File → New is needed before A8.

| Row | WP | Action | Pass looks like |
|---|---|---|---|
| A1 | carry | In a new sketch, read the left rail (scroll it at 800 px) | Every button has a word under its icon: Select, Line, Arc, Circle, Rect, Jaw, Polygon, Ellipse, Slot, Spline, Point, Trim, Extend, Smart Dim, Convert, Mirror, Pattern, Auto Dim |
| A2 | WP1 | Press `Jaw`; then `Rect`; then click `Parallelogram` twice | After `Jaw`: `Center Three Point` has a blue fill and light-blue border, the other four chips are grey, label not clipped, status `Jaw — click 1 centre, click 2 end of the long side, click 3 half the width`. After `Rect`: `Corner` highlighted. After the chip clicks: `Parallelogram` highlighted and stays so |
| A3 | WP2 | Draw Ø20 at the origin and Ø45 at the right (Radius 10 and 22.5). `Smart Dim`; click the Ø20 centre; click empty canvas once; click the Ø45 centre with a plain click | Statuses: `Smart Dim: first pick set …`, then `… nothing there — first pick kept …`, then the dimension popup. Type `200`: `Dimension updated`. No Shift used at any point. If a Shift click was needed, FAIL the row and log which statuses were seen |
| A4 | carry | With both circles still selected press the `Shaft Lines` chip (or `Select`, click empty canvas, click each circle edge, chip) | Status `Shaft lines: 2 added`; two horizontal lines at y = ±10 joining the circles |
| A5 | carry | Extrude 10, export 3MF | `check_rung01.py blank` 5/5 |
| A5b | WP3 | Do not Save. Wait until at least a minute has passed since the last edit. File → New. Press Cancel. Then File → Save As `blank.sxp` | The dialog `Discard unsaved changes?` appears; after Cancel the blank is still on screen. If File → New replaces the blank with no dialog, FAIL the row and rebuild the blank (it is a product failure, not soft-GL) |
| A7 | carry | `Esc`; palette `Sketch`; one click on the top face | Body deselected; `Sketch on face (plane +Z @ origin 0.0,0.0,10.0)` |
| A6 | carry | In that face sketch: Circle tool, one click, `Esc`; then `Esc` again | First `Esc` keeps the sketch (status `First point dropped — Esc again exits the sketch`); second exits the sketch. The blank is untouched |
| A7b | carry | Palette `Sketch`; one click on the top face again | A new face sketch opens on the blank |
| A8 | carry | In the face sketch press `Jaw`; three clicks (centre, long side, half-width), dimension 20 | Four lines; width 20 |
| A9 | carry | Pivot hole Ø10, Trim the jaw, cut Up To Surface through the bottom face (Opposite face) | Hole and open jaw cut; body is a wrench, not a mangled solid |
| A11 | carry | Slot 2.5 deep, fillets (R10 neck, 1 mm edges) | Per the handout; any refused fillet shows its reason |
| A12 | carry | Export `wrench.3mf` | `check_rung01.py wrench` 28/28, no `--allow-mirror`, orientation row `flipX=False flipY=False` |
| A13 | carry | Timeline Distance 14 (steps above), export `wrench-t14.3mf` | `check_rung01.py thick wrench-t14.3mf 14` 4/4 |
| A10 | carry | Scratch document (File → New; press the Discard dialog's OK): Ø100 disc, 10 mm; cut a Ø90 circle from the top face | Status `Cut would remove 81% of the body — the contour covers most of it. Nothing was cut.`; body unchanged; sketch open |
| A14 | carry | Nut (File → New again): polygon AF 20, hole Ø10, Extrude 7.5, export | `check_rung01.py nut` 7/7 |
| A15 | WP4 | `python3 tools/lint_rung01_e2e.py` and `run_rung01_wrench.gd` | lint clean (`3 replan9 scripts are clean`); `399 checks, 0 failures` |

Pass: score ≥ 9, nut 7/7, blank 5/5, wrench 28/28, thick 4/4, walk 0 failures, part made in the real GUI.

If the soft-GL protocol above cannot complete A8–A14 even with the checkpoint, the critique scores what ran and lists the blocked rows by name; it does not mark them PASS.

## Out of scope

- No soft-GL / llvmpipe / Mesa driver change and no product WP for stale viewports, dropped keys or lost clicks.
- No kernel change, no change to `select_ray` or any pick logic, no change to the checker formulas.
- No highlight of the active tool on the left rail (only the chip row, which is what sx-029 A2 asked about). The rail's active tool is not required by any checklist row.
- No unsaved-changes prompt on app quit, and no autosave recovery feature. WP3 only stops the autosave from hiding the existing prompt.
- No "Shift to add" in Smart Dim: it is not needed (F2).
- No status refresh on sketch exit (F6), no change to the dimension popup.
- Wave features and `docs/plan/*` are untouched.
