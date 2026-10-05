# Rung 1 replan 7 — click the face, pin the pivot circle, make the checker's orientation geometric

Status: plan only. No product code in this change.

Baseline: `main` at `8478773d` (merge of #90). Replan 6 is [`rung-01-replan-6.md`](rung-01-replan-6.md) (WP1–WP4, PRs #87–#90, all merged). The sx-027 critique of that build scored **5/10** and failed rung 1. Symptom list: [`rung-01-leftovers-sx027.md`](rung-01-leftovers-sx027.md).

Every claim below was measured on `8478773d` on a VM with Godot 4.7-stable and OCCT 8.0.1 (`/opt/occt-8.0.1`), headless, at 1280×800. Every code block in the WPs was run: the product diffs, the new tests and the walk edit were applied together and `run_rung01_wrench.gd` printed `391 checks, 0 failures` with the real `check_rung01.py` inside it. The BUILD agent copies, it does not design.

BUILD agents execute one WP each. WP1, WP2 and WP3 own disjoint files and merge in any order. WP4 merges last, rebased on `main` after WP1–WP3. Godot stays `tools/godot/godot` (4.7-stable). Do not switch the pin to 4.7.1.

## Goal

A person using only the GUI, at 1280×800, does the rung-1 handout and gets what the checker wants:

- Clicking a face of a solid selects that face (second click) and offers `Sketch`. It never reopens a sketch that is behind the solid. A sketch drawn on that face reopens when the click is on its ink, and only then.
- After Smart Dimension 200 and Enter, the Ø20 circle is still centred on the sketch origin and the head is at (200, 0). The pivot hole, the jaw and the slot then land where the handout says.
- `check_rung01.py` decides which end is the head from the part's shape, not by counting failed rows, so a hole-less blank cannot print `flipX=True (MIRROR)`.
- `make test-godot` says in one line when the GDExtension did not load, instead of a wall of parse errors.
- The headless walk contains no recovery path for a face click. It clicks, and a miss fails loudly.

Checker commands on files the export dialog wrote (the first is new, the other three are unchanged):

```
python3 tools/check_rung01.py blank  blank.3mf               # 5/5, run right after Extrude 10
python3 tools/check_rung01.py nut    nut.3mf                 # 7/7
python3 tools/check_rung01.py wrench wrench.3mf              # 28/28
python3 tools/check_rung01.py thick  wrench-t14.3mf 14       # 4/4
```

Do not pass `--allow-mirror`. Exit code 0 is the pass.

Rung 1 is done when sx-028 follows the checklist at the end of this file, the four checker commands pass, `run_rung01_wrench.gd` prints 0 failures, and the score is at least 9.

## What the investigation found

### F1. P0 — a face click reopens a sketch because pads are picked without looking at the solid

Code (all line numbers are `8478773d`):

- `ViewportInteraction._on_release` (`game/scripts/viewport_interaction.gd`, the block that starts "Pads sit on faces — prefer a pad hit even when the body ray is non-empty") calls `view.sketch_pads.pick_pad(ray)` first and returns on a hit. It never asks `view.pick_info(ray)` where the solid is.
- `ViewportInteraction._commit_pick_sketch_host` (same file; runs after the Sketch palette button is pressed with nothing selected, status `Select a face or existing sketch`) has the same order: pads first, then `view.pick_info`.
- `SketchPadOverlay.pick_pad` (`game/scripts/sketch_pad_overlay.gd`) intersects the ray with each pad's plane and accepts any hit inside the pad's 2D bounding box (`min2`/`max2`, grown by `PAD_FRAC` 0.2). A pad 10 mm behind the blank's top face (Sketch 1, plane z = 0) is "hit" through the solid. Several pads: the one nearest the pad's own centre wins.
- `_on_release` has a second hole. A press on an already-selected face arms `DragMode.PUSH_PULL` (value 3 in `enum DragMode`). On release with a plain click, the PUSH_PULL branch resets state and `return`s: no pad test, no selection. Measured by printing `_drag_mode` on release: `mode=3 travel=0.0` for every click after the face is selected. So even with the first hole fixed, a click on the ink of a sketch drawn on a selected face does nothing.

Measured on `8478773d`, walk sequence, jaw sketch click on the blank's top face (camera 1° off vertical, the pose the walk leaves):

```
ray origin (123.93, -5.69, 335.71) dir (0, 0.01745, -0.99985)
solid hit  (123.93, 0, 10.0)        solid_t = 325.756
Sketch 1 pad plane z = 0            t       = 335.76    (10 mm behind the solid)
old pick_pad -> Sketch 1 id         new pick_pad_visible -> ""
```

Second walk click, the slot sketch. `FilmUI.face_pick_point` (`game/tests/lib/film_ui.gd:1130`) is the average of the face's tessellation vertices. After the jaw is cut that average is (199.6, 13.7, 10): inside the jaw opening, where there is no material. The ray goes through the opening and hits the jaw wall at z = 4.9995 (`solid_t` 325.757). The jaw sketch's pad (z = 10, id `9720b99c…`) is about 5 mm in front of that wall, so the old code picks it and the click goes to the jaw sketch instead of starting a new one. With the host moved to (100, 0, 10), on the shaft, the same step makes `sketch 5` and `extrude 6` (blind −2.5) as the handout intends. A slot built on the reopened jaw sketch would explain the slot-depth and fillet failures in `headless_H2.txt`; those were not reproduced here (F5).

The walk and the film library hide all of this:

- `_sketch_on_top` in `game/tests/run_rung01_wrench.gd`: if the click does not open a top-face sketch it presses `Exit Sketch`, then calls `ctx.view.select_entity(body, top)` and the private `ctx.main.interaction._refresh_selection_strip()`, then presses the strip's `Sketch` button. Every P0 failure is turned into a pass.
- `_ensure_body_selected` (same file) has the comment "Side view: a top-down click lands on the sketch pad and reopens the sketch." It is the walk admitting the bug.
- `FilmUI.enter_sketch_on_face` (`game/tests/lib/film_ui.gd`, around line 680) sets `pads.visible = false` so "nearby rails/profiles cannot steal the face pick ray".

Fix (WP1): `pick_pad_visible(ray_origin, ray_dir, solid_t)`. A pad behind the solid surface never wins. A pad on the surface (within 0.6 mm of the solid hit; that is a sketch drawn on that face) wins only when the cursor is within 1.5 mm of its drawn ink, so clicking blank face area still reaches the face. A pad in front of the solid, or when the ray misses every solid, wins as before. `_on_release` and `_commit_pick_sketch_host` both use it. A click on a selected face still tests the pad.

### F2. P1 — `flipX=True` is not a mirrored model

What `flipX=True` means in `tools/check_rung01.py`: `align()` flips X and/or Y and moves the bbox minimum corner to (−10, −22.5, 0). The old `main()` tries all four flips and keeps the one with the fewest failed rows (`rr.fail < best[0].fail`, ties keep the first, `(False, False)`). `mirrored = (fx != fy)`.

Measured facts:

1. Camera. Ground sketch pose in the running binary: `yaw π`, `pitch π/2`, `plane_x (1,0,0)`, `plane_y (0,1,0)`. With the 1280×800 viewport, model (0,0,0) → screen (640, 400) and model (50,0,0) → screen (1232.6, 400). Screen right is +X. A head click at screen x = 921.6 is sketch (23.76, 0). No camera or `ModelSpace` change is needed.
2. 16 headless runs of the handout blank with the head clicked at the right half of the screen (Ø20 drawn before or after the head, Smart Dimension 200 on or off, tangent lines clicked exactly or 3 mm off, drawn start-to-end or end-to-start). Every run that extruded has its head at +X. Two runs did not extrude (open profile) and are not counted.
3. The checker is the source of the flag. A blank from one of those runs (head at +X, bbox `[232.416, 44.882, 10.0]`) printed `orientation got flipX=True flipY=False (MIRROR)` on `8478773d`. A blank has no pivot hole and no jaw, so the hole and jaw rows fail in all four orientations and the X-mirror happens to fail one fewer row. The sx-027 files `check_wrench_base.txt` and `check_thick.txt` are blanks or near-blanks; the flag there says nothing about the model.
4. What really moves is the pivot. In the same runs Smart Dimension 200 between two unpinned circles moves both: origin circle to x = −77.3, −99.0 or −105.1, head to 122.7, 101.0 or 94.9 (the pair is re-centred). In the walk, which draws the Ø20 first, the origin circle goes to (−1.157, 0) and the head to (198.84, 0). Everything the handout then does at (0,0) and (200,0) is 1.16 mm off.

Fix (WP2):

- Product: when Smart Dimension is applied to two circles, a circle whose centre is within 0.5 mm of the sketch origin is coincident with a fixed construction point at (0, 0) before the distance is added. Only the centre is pinned, so a later diameter dimension still resizes it (tested).
- Checker: decide which end is the head from the vertices (the X end whose last 10 mm has the larger Y extent), then test only the rotation and the mirror for that end. Ties and blanks give the rotation. Add a `blank` kind that fails when the head is at −X. This is stricter than before for a finished wrench (the X sign no longer depends on failed-row counts) and removes the false positive on blanks. The 0.2 mm tolerance and every wrench row are unchanged.

### F3. The eight deterministic headless failures are all the F2 drift

`run_rung01_wrench.gd` on this VM, `8478773d`, `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib`: `359 checks, 8 failures`.

| Failure line | Cause |
|---|---|
| `jaw sketch has Ø45 at the head (r=0.0000)` | The test looks for a circle within 1 mm of (200, 0). The head is at (198.84, 0). |
| `jaw width label exists` and `jaw width label is 20 (got -1.000)` | The Center Three Point third click is measured from the axis through the snapped centre (198.84, 0), not from (200, 0): half width 10 − 1.157·sin 45° = 9.18, width 18.40. `_dim_index_near(sm, "distance", 20.0)` and `(…, 16.0)` accept ±1.0, so 18.40 matches neither and the index is −1. |
| `jaw AF at z=2/5/8 is 18.400` | The cut uses that 18.40 wide rectangle. |
| `check_rung01.py wrench … exit 1` | The same three AF rows plus `1mm fillet on jaw top edge` (the wall is at 9.2, not 10). |
| `jaw width dimension restored` | Same missing dimension index. |

`P2.6 head centre from mesh: (199.061, …)` already shows it, and passes only because the test allows ±5 mm.

With only the F2 product pin applied: `379 checks, 0 failures`.

### F4. The `after_n` parse error is the extension failing to load

`headless_H.txt` ran Godot without the OCCT directory on `LD_LIBRARY_PATH`. Reproduced with `env -u LD_LIBRARY_PATH tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd`:

```
ERROR: Can't open dynamic library: …/libsxcore.so. Error: libTKOffset.so.8.0: cannot open shared object file
SCRIPT ERROR: Parse Error: Could not find type "SxDocument" in the current scope.
SCRIPT ERROR: Parse Error: Cannot infer the type of "before_n" variable because the value doesn't have a set type.   (line 850)
SCRIPT ERROR: Parse Error: Cannot infer the type of "after_n" variable because the value doesn't have a set type.    (line 853)
```

Lines 850 and 853 (`var before_n := sm.sketch.entity_ids().size() if sm.sketch != null else 0`) are the only two lines in the file that need `:=` to infer through an `SxSketch` call. They are the symptom, not the cause. `libsxcore.so` has `RUNPATH $ORIGIN`; CI exports `LD_LIBRARY_PATH` (`.github/workflows/ci.yml` lines 66, 299, 306); the Makefile does not. Fix (WP3): type those two variables as `int`, make the Makefile put `/opt/occt-$(OCCT_VERSION)/lib` first on the loader path when it exists, and add a preflight that prints one readable line.

### F5. Other numbers

- With the F2 pin, F1 fix and the WP4 walk edit together: `391 checks, 0 failures`.
- The WP4 walk edit on unmodified product code: `59` failures. The first is `first top-face click does not reopen a sketch`, so the new walk fails on `8478773d`, as the rules require.
- `headless_H2.txt` reported `354 checks / 17 failures`. The 8 above reproduce. The slot-depth and fillet extras depend on the walk's recovery path in `_sketch_on_top` firing differently; they are F1 symptoms and are not separately fixed. After WP4 there is no recovery path.
- Failures that are the same before and after WP1+WP2 (measured): `run_assembly_tests` 4, `run_howto_tests` 2, `run_icon_tests` 2, `run_insert_component_tests` 2, `run_menu_tests` 2, `run_place_tests` 1, `run_property_tests` 1, `run_rung01_replan3_input` 1, `run_rung01_replan3_shell` 6, `run_rung01_replan_shell` 1, `run_rung01_sketch_tests` 7, `run_sketch_to_3d_ui_tests` 2, `run_sketch_tools_tests` 13, `run_ui_button_coverage_tests` 2, `run_visual_ux_tests` 1. `run_film_manifest_smoke` has a script error and `run_film_caption_tests` prints nothing. Do not touch them.

## Work packages

| WP | Owns | Closes | Merge |
|---|---|---|---|
| WP1 | `game/scripts/sketch_pad_overlay.gd`, `game/scripts/viewport_interaction.gd`, `game/tests/run_rung01_replan7_facepick.gd` | F1 face pick | any time |
| WP2 | `game/scripts/sketch_mode.gd`, `tools/check_rung01.py`, `tools/test_check_rung01.py`, `game/tests/run_rung01_replan7_anchor.gd` | F2, F3 | any time |
| WP3 | `Makefile`, `tools/lint_rung01_e2e.py`, `game/tests/preflight_sxcore.gd`, lines 850 and 853 of `game/tests/run_rung01_wrench.gd` | F4 | any time |
| WP4 | `game/tests/run_rung01_wrench.gd` (everything except WP3's two lines) | the walk clicks the face | last, after WP1–WP3 |

WP1, WP2 and WP3 can run in parallel: no file appears twice. WP3 touches two lines of the walk that WP4 does not touch, so WP4 rebases cleanly. WP4 cannot go green before WP1 and WP2 are merged; do not start it earlier than that.

Shared rules, for every WP:

- Work from `main`, one branch and one PR per WP. Commit messages start `replan-7 WPn:`.
- Before every `tools/godot/godot` command: `export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib:$LD_LIBRARY_PATH` (until WP3 is merged; after that `make` does it).
- Order of work in every WP: write the test, run it on unmodified product code and see the failure count given below, then change product code, then see 0 failures. A test that passes before the product change does not count.
- New scripts use `Vector2i(1280, 800)`. Do not add `await` between mouse-down and mouse-up in any `_x11_*` helper.
- Do not pass `--allow-mirror`. Do not change the 0.2 mm tolerance, the 1e-6 sketch tolerance, or the manifold gate.
- Do not edit `orbit_camera.gd`, `ModelSpace`, `sketch.cpp`, or the replan-2…6 scripts.
- Forbidden in new or edited test code: `interaction._input`, `id_pressed.emit`, `set_up_to_face`, `set_finish_op`, `set_finish_end`, `set_extrude_distance`, assigning `LineEdit.text` or `SpinBox.value`, `text_submitted.emit`, `focus_dim_for_typing`, `focus_distance_for_typing`, `export_3mf(` (except in the WP2 unit script, which builds no GUI path), `infer_enabled = false`, `dlg.current_path =`, `dlg.current_dir =`, `sketch_mode.cancel(`, `sketch_mode.exit_sketch(`, `sketch_mode.trim_at(`, `new_document(`, `graph_update_sketch(`, `dimension_edit_requested.emit`, and from WP3 on `select_entity(`.

### WP1 — A face click selects the face; a pad wins only where it is visible

**Files.** `game/scripts/sketch_pad_overlay.gd`, `game/scripts/viewport_interaction.gd`, new `game/tests/run_rung01_replan7_facepick.gd`.

**Step 1 — write the test.** Create `game/tests/run_rung01_replan7_facepick.gd` with exactly this content.

```gdscript
# Rung 1 replan 7 WP1 — a click on a solid face selects the face; a pad wins only on its ink.
# Clicks are one X11 burst (no await between mouse-down and mouse-up).
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan7_facepick.gd
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
	print("rung01 replan7 WP1 facepick")
	FilmUI.reset_fail_count()
	await test_face_click_beats_hidden_pad()
	check(FilmUI.fail_count == 0, "FilmUI click path stayed on screen (%d)" % FilmUI.fail_count)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _sketch_feature_ids(ctx: FilmContext) -> Array:
	var out: Array = []
	for f in ctx.view.doc.graph_features():
		if str(f.get("type", "")) == "sketch":
			out.append(str(f.get("id", "")))
	return out


func _open_sketch_id(ctx: FilmContext) -> String:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null or not sm.active:
		return ""
	return str(ctx.main.get_active_sketch_feature_id()) if ctx.main.has_method("get_active_sketch_feature_id") else "open"


func test_face_click_beats_hidden_pad() -> void:
	print("- face click, hidden pad, ink click")
	var ctx := await _boot()
	await FilmUI.enter_sketch(ctx)
	await process_frame
	var sm: SketchMode = ctx.main.sketch_mode
	check(sm != null and sm.active, "ground sketch is open")
	await _zoom(ctx, Vector3(20, 15, 0), 90.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.RECT)
	await _click_uv(ctx, Vector2.ZERO, "Rect corner A")
	await _click_uv(ctx, Vector2(40, 30), "Rect corner B")
	await process_frame
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	var dist := _distance_edit(chrome)
	await _x11_click(dist)
	await _x11_type(dist.get_viewport(), "10")
	await process_frame
	await _x11_click(chrome.extrude_button())
	for i in 3:
		await process_frame
	var body := _first_body(ctx)
	check(body != "", "10 mm blank exists")
	var top := _face_along(ctx, body, 1)
	check(top != "", "top face exists")
	var sketches_before := _sketch_feature_ids(ctx).size()
	check(sketches_before == 1, "one sketch feature before the face click (got %d)" % sketches_before)

	await _zoom_top(ctx, Vector3(20, 15, 10), 90.0)
	var ix: ViewportInteraction = ctx.main.interaction
	var vp: Viewport = ctx.main.get_viewport()
	var face_pt := FilmUI.model_to_screen(ctx, Vector3(30, 8, 10))
	check(FilmUI.require_on_screen(ctx, face_pt, "top face click"), "top face click is on screen")
	await _x11_key(vp, KEY_ESCAPE)
	await _x11_click_screen(vp, face_pt)
	await process_frame
	sm = ctx.main.sketch_mode
	check(not sm.active, "first click on the top face does not reopen Sketch 1")
	check(ctx.view.selected_body == body, "first click on the top face selects the body")
	await _x11_click_screen(vp, face_pt)
	await process_frame
	sm = ctx.main.sketch_mode
	check(not sm.active, "second click on the top face does not reopen Sketch 1")
	check(ctx.view.selected_face == top, "second click on the top face selects the top face")
	check(ix._strip_sketch.visible, "the selection strip offers Sketch")

	await _x11_click(ix._strip_sketch)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5 and sm.plane_normal().z > 0.9,
			"Sketch from the strip opens on the top face")
	await _zoom_uv(ctx, Vector2(20, 15), 80.0)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await _click_uv(ctx, Vector2(20, 15), "Hole centre")
	await _click_uv(ctx, Vector2(25, 15), "Hole radius")
	await process_frame
	var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
	await _x11_click(exit_btn)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(not sm.active, "Exit Sketch leaves the top sketch")
	var sketches_mid := _sketch_feature_ids(ctx).size()
	check(sketches_mid == 2, "two sketch features after the top sketch (got %d)" % sketches_mid)

	await _zoom_top(ctx, Vector3(20, 15, 10), 90.0)
	await _x11_key(vp, KEY_ESCAPE)
	check(ctx.view.selected_face == "", "a click on empty space clears the face selection")
	var off_ink := FilmUI.model_to_screen(ctx, Vector3(32, 6, 10))
	await _x11_click_screen(vp, off_ink)
	await process_frame
	check(not ctx.main.sketch_mode.active, "a face click away from the sketch ink does not reopen that sketch")
	check(ctx.view.selected_body == body, "a face click away from the ink selects the body")
	await _x11_click_screen(vp, off_ink)
	await process_frame
	check(not ctx.main.sketch_mode.active, "a second click away from the ink does not reopen that sketch")
	check(ctx.view.selected_face == top, "a second click away from the ink selects the top face")

	await _x11_key(vp, KEY_ESCAPE)
	var palette_sketch := FilmUI.find_palette_sketch_button(ctx.main)
	check(palette_sketch != null, "palette Sketch button exists")
	await _x11_click(palette_sketch)
	await process_frame
	check(ctx.main.interaction._picking_sketch_host, "Sketch with nothing selected arms the host pick")
	await _x11_click_screen(vp, off_ink)
	await process_frame
	await process_frame
	sm = ctx.main.sketch_mode
	check(sm.active and sm.editing_fid == "", "host pick on the top face starts a new sketch, not an edit")
	check(sm.active and absf(sm.plane_origin.z - 10.0) < 0.5 and sm.plane_normal().z > 0.9,
			"host pick on the top face puts the new sketch on z = 10")
	check(_sketch_feature_ids(ctx).size() == 2, "host pick adds no sketch feature before drawing")
	await _x11_click(FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch"))
	await process_frame
	await process_frame
	await _zoom_top(ctx, Vector3(20, 15, 10), 90.0)
	await _x11_key(vp, KEY_ESCAPE)

	var on_ink := FilmUI.model_to_screen(ctx, Vector3(30, 15, 10))
	await _x11_click_screen(vp, on_ink)
	await process_frame
	await process_frame
	check(ctx.main.sketch_mode.active, "a click on the circle ink reopens the top sketch")
	check(_sketch_feature_ids(ctx).size() == 2, "reopening adds no sketch feature")
	await _shutdown(ctx)


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
	if main.sketch_mode != null and not main.sketch_mode.status.is_connected(_on_status):
		main.sketch_mode.status.connect(_on_status)
	if main.interaction != null and not main.interaction.status.is_connected(_on_status):
		main.interaction.status.connect(_on_status)
	return ctx




func _shutdown(ctx: FilmContext) -> void:
	if ctx == null or ctx.main == null:
		return
	ctx.main.queue_free()
	await process_frame
	await process_frame




func _on_status(text: String) -> void:
	_status_log.append(text)
	print("  status: " + text)




func _first_body(ctx: FilmContext) -> String:
	if ctx.view == null or ctx.view.doc == null:
		return ""
	var ids: PackedStringArray = ctx.view.doc.body_ids()
	if ids.is_empty():
		return ""
	return str(ids[0])




func _face_along(ctx: FilmContext, body: String, z_sign: int) -> String:
	var best := ""
	var best_z := -1.0e30 if z_sign > 0 else 1.0e30
	var best_area := -1.0
	for f in ctx.view.doc.get_face_ids(body):
		var fbb: Dictionary = ctx.view.doc.measure_bbox(f)
		if fbb.is_empty():
			continue
		var fext: Vector3 = fbb["max"] - fbb["min"]
		var span := maxf(fext.x, fext.y)
		if fext.z > 0.5 and fext.z > span * 0.05:
			continue
		var z: float = fbb["max"].z if z_sign > 0 else fbb["min"].z
		var area := fext.x * fext.y
		var better := false
		if z_sign > 0:
			better = z > best_z + 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		else:
			better = z < best_z - 0.05 or (absf(z - best_z) <= 0.05 and area > best_area)
		if better:
			best_z = z
			best_area = area
			best = f
	return best




func _click_uv(ctx: FilmContext, uv: Vector2, desc: String) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var screen := FilmUI.model_to_screen(ctx, sm.to_model(uv))
	check(FilmUI.require_on_screen(ctx, screen, desc), "sketch click on screen: %s" % desc)
	await _x11_click_screen(ctx.main.get_viewport(), screen)




func _zoom_uv(ctx: FilmContext, uv: Vector2, size_mm: float) -> void:
	await _zoom(ctx, ctx.main.sketch_mode.to_model(uv), size_mm)




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




func _x11_key(vp: Viewport, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	vp.push_input(ev)
	var rel := ev.duplicate() as InputEventKey
	rel.pressed = false
	vp.push_input(rel)
	await process_frame


func _zoom_top(ctx: FilmContext, model_pivot: Vector3, size_mm: float) -> void:
	var cam = ctx.main.camera
	if cam._view_tween != null and cam._view_tween.is_valid():
		cam._view_tween.kill()
		cam._view_tween = null
	cam.yaw = PI
	cam.pitch = deg_to_rad(89.0)
	await _zoom(ctx, model_pivot, size_mm)


func _x11_click(ctrl: Control) -> void:
	var pos := ctrl.get_global_rect().get_center()
	var vp := ctrl.get_viewport()
	await _x11_click_screen(vp, pos)




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




func _distance_edit(chrome: SketchContextChrome) -> LineEdit:
	if chrome == null:
		return null
	return chrome.find_child("DistanceLineEdit", true, false) as LineEdit




func _x11_type(vp: Viewport, text: String) -> void:
	for i in text.length():
		var ch := text.unicode_at(i)
		var code := KEY_NONE
		if ch >= 48 and ch <= 57:
			code = (KEY_0 + (ch - 48)) as Key
		elif ch >= 97 and ch <= 122:
			code = (KEY_A + (ch - 97)) as Key
		elif ch == 46:
			code = KEY_PERIOD
		elif ch == 45:
			code = KEY_MINUS
		elif ch == 47:
			code = KEY_SLASH
		else:
			push_error("no X11 key for U+%X" % ch)
			return
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.unicode = ch
		ev.pressed = true
		ev.echo = false
		vp.push_input(ev)
		var rel := ev.duplicate() as InputEventKey
		rel.pressed = false
		rel.unicode = 0
		vp.push_input(rel)
		await process_frame
```

**Step 2 — see it fail.**

```
tools/godot/godot --headless --path game --script tests/run_rung01_replan7_facepick.gd
```

On `8478773d` the last line is `31 checks, 17 failures`. The first failure is `first click on the top face does not reopen Sketch 1`. If you get a different count, stop and report; do not continue.

**Step 3 — product change.** Apply this diff to the two files (`git apply` works from the repo root; if it rejects, make the same edits by hand, the context is unique).

```diff
diff --git a/game/scripts/sketch_pad_overlay.gd b/game/scripts/sketch_pad_overlay.gd
index a71381c..1018f68 100644
--- a/game/scripts/sketch_pad_overlay.gd
+++ b/game/scripts/sketch_pad_overlay.gd
@@ -14,6 +14,10 @@ const PROFILE_COLOR_CLOSED := Color(0.98, 0.78, 0.08, 1.0)
 const PROFILE_COLOR_OPEN := Color(0.35, 0.88, 1.0, 1.0)
 const CONSTRUCTION_COLOR := Color(0.85, 0.7, 0.25, 0.45)
 const PAD_FRAC := 0.2
+## A pad whose plane is within this distance of the solid surface under the
+## cursor is "on" that surface. It only wins if the cursor is on its ink.
+const PAD_FACE_EPS_MM := 0.6
+const PAD_INK_TOL_MM := 1.5
 ## Rim half-width in sketch-plane units (mm); ~1/3 of the original 0.35.
 const EDGE_HALF := 0.35 / 3.0
 ## Profile curve half-width in sketch-plane units (mm) — world-space so it stays readable when orbiting.
@@ -190,9 +194,46 @@ func _add_pad(fid: String, sk: SxSketch) -> void:
 		"min2": mn,
 		"max2": mx,
 		"closed": closed,
+		"ink": _collect_ink(sk),
 	}
 
 
+## Non-construction strokes of a sketch in plane (u, v) units, for hit tests.
+func _collect_ink(sk: SxSketch) -> Array:
+	var ink: Array = []
+	for id in sk.entity_ids():
+		var info: Dictionary = sk.entity_info(id)
+		if bool(info.get("construction", false)):
+			continue
+		match str(info.get("type", "")):
+			"line":
+				ink.append({"k": "line", "a": info["start"], "b": info["end"]})
+			"circle":
+				ink.append({"k": "circle", "c": info["center"], "r": float(info["radius"])})
+			"arc":
+				ink.append({"k": "circle", "c": info["center"], "r": float(info["radius"])})
+			_:
+				pass
+	return ink
+
+
+func _ink_distance(ink: Array, p: Vector2) -> float:
+	var best := INF
+	for seg in ink:
+		var d := INF
+		if str(seg["k"]) == "line":
+			var a: Vector2 = seg["a"]
+			var b: Vector2 = seg["b"]
+			var ab := b - a
+			var len2 := ab.length_squared()
+			var t := 0.0 if len2 < 1e-12 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
+			d = p.distance_to(a + ab * t)
+		else:
+			d = absf(p.distance_to(seg["c"] as Vector2) - float(seg["r"]))
+		best = minf(best, d)
+	return best
+
+
 ## Reflective rim: thin quads around the pad perimeter (screen-stable width in mm).
 ## Odd-numbered sides extend by full line thickness so corners overlap cleanly
 ## instead of leaving a jagged notch where ribbons meet.
@@ -360,6 +401,49 @@ func pick_pad(ray_origin: Vector3, ray_dir: Vector3) -> String:
 	return best_fid
 
 
+## Like pick_pad, but aware of the solid under the same ray. `solid_t` is the
+## distance along `ray_dir` (unit length) to the first solid hit, INF when the
+## ray misses every solid. A pad behind that surface never wins. A pad on that
+## surface (a face sketch) only wins when the cursor is on its drawn ink, so a
+## click elsewhere on the face still reaches the face.
+func pick_pad_visible(ray_origin: Vector3, ray_dir: Vector3, solid_t: float = INF) -> String:
+	var d := ray_dir.normalized() if ray_dir.length_squared() > 1e-12 else ray_dir
+	var best_score := INF
+	var best_fid := ""
+	for fid in _pads:
+		var e: Dictionary = _pads[fid]
+		var n: Vector3 = e["normal"]
+		var denom := d.dot(n)
+		if absf(denom) < 1e-9:
+			continue
+		var origin: Vector3 = e["origin"]
+		var t := (origin - ray_origin).dot(n) / denom
+		if t < 0.0:
+			continue
+		var hit: Vector3 = ray_origin + d * t
+		var local := hit - origin
+		var u := local.dot(e["x"] as Vector3)
+		var v := local.dot(e["y"] as Vector3)
+		var mn2: Vector2 = e["min2"]
+		var mx2: Vector2 = e["max2"]
+		if u < mn2.x or u > mx2.x or v < mn2.y or v > mx2.y:
+			continue
+		if is_finite(solid_t):
+			if t > solid_t + PAD_FACE_EPS_MM:
+				continue
+			if t >= solid_t - PAD_FACE_EPS_MM \
+					and _ink_distance(e["ink"] as Array, Vector2(u, v)) > PAD_INK_TOL_MM:
+				continue
+		var center := (mn2 + mx2) * 0.5
+		var extent := (mx2 - mn2).length()
+		var radial := Vector2(u, v).distance_to(center)
+		var score := radial / maxf(extent, 1.0) + t * 1e-4
+		if score < best_score:
+			best_score = score
+			best_fid = fid
+	return best_fid
+
+
 ## Pads whose screen AABB matches `rect` (window vs crossing, same as bodies).
 func pads_in_rect(rect: Rect2, camera: Camera3D, model_space: Node3D, crossing := false) -> Array[String]:
 	var band := rect.abs()
diff --git a/game/scripts/viewport_interaction.gd b/game/scripts/viewport_interaction.gd
index 410d2da..8fb98d7 100644
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -1607,16 +1607,24 @@ func _should_release_cancel_focus(focus: Control) -> bool:
 	return false
 
 
+## Distance along the (unit) ray to a solid hit; INF when the ray missed.
+func _solid_hit_t(ray: Array, hit: Dictionary) -> float:
+	if hit.is_empty() or not (hit.get("point") is Vector3):
+		return INF
+	var d: Vector3 = (ray[1] as Vector3).normalized()
+	return ((hit["point"] as Vector3) - (ray[0] as Vector3)).dot(d)
+
+
 func _commit_pick_sketch_host(screen_pos: Vector2) -> void:
 	var ray := _model_ray(screen_pos)
-	# Prefer yellow sketch pads.
+	var hit: Dictionary = view.pick_info(ray[0], ray[1])
 	if view.sketch_pads != null:
-		var pad_fid: String = view.sketch_pads.pick_pad(ray[0], ray[1])
+		var pad_fid: String = view.sketch_pads.pick_pad_visible(
+				ray[0], ray[1], _solid_hit_t(ray, hit))
 		if pad_fid != "":
 			_picking_sketch_host = false
 			sketch_host_picked.emit("pad", "", "", pad_fid)
 			return
-	var hit: Dictionary = view.pick_info(ray[0], ray[1])
 	if not hit.is_empty() and str(hit.get("face", "")) != "":
 		var face_id := str(hit["face"])
 		var body_id := str(hit.get("body", ""))
@@ -3272,6 +3280,10 @@ func _on_release(pos: Vector2) -> void:
 						status.emit("Push/pull failed (planar faces only for now)")
 			_pp_preview_dist = 0.0
 			_drag_mode = DragMode.NONE
+			if was_click and _click_hits_pad():
+				_refresh_transform_hud()
+				queue_redraw()
+				return
 			_box_drag = false
 			_additive_click = false
 			_refresh_transform_hud()
@@ -3343,17 +3355,8 @@ func _on_release(pos: Vector2) -> void:
 	# Pads sit on faces — prefer a pad hit even when the body ray is non-empty,
 	# otherwise face-hosted pads are unclickable under the solid.
 	# An armed fillet/chamfer/hole pick must hit the solid, not reopen the pad.
-	var armed_pick := ops_panel != null and ops_panel.consumes_viewport_pick()
-	if was_click and not armed_pick and view.sketch_pads != null and (sketch_mode == null or not sketch_mode.active):
-		var pad_ray := _model_ray(_press_pos)
-		var pad_fid: String = view.sketch_pads.pick_pad(pad_ray[0], pad_ray[1])
-		if pad_fid != "":
-			sketch_pad_clicked.emit(pad_fid, _additive_click)
-			_box_drag = false
-			_additive_click = false
-			_press_empty = false
-			_press_travel = 0.0
-			return
+	if was_click and _click_hits_pad():
+		return
 	if _press_empty:
 		if not _additive_click:
 			view.clear_selection()
@@ -3395,6 +3398,29 @@ func _on_release(pos: Vector2) -> void:
 	_press_travel = 0.0
 
 
+## A click that lands on a sketch pad reopens that sketch. An armed
+## fillet/chamfer/hole pick must hit the solid instead. Returns true when the
+## click was consumed by a pad.
+func _click_hits_pad() -> bool:
+	var armed_pick := ops_panel != null and ops_panel.consumes_viewport_pick()
+	if armed_pick or view.sketch_pads == null:
+		return false
+	if sketch_mode != null and sketch_mode.active:
+		return false
+	var pad_ray := _model_ray(_press_pos)
+	var pad_hit: Dictionary = view.pick_info(pad_ray[0], pad_ray[1])
+	var pad_fid: String = view.sketch_pads.pick_pad_visible(
+			pad_ray[0], pad_ray[1], _solid_hit_t(pad_ray, pad_hit))
+	if pad_fid == "":
+		return false
+	sketch_pad_clicked.emit(pad_fid, _additive_click)
+	_box_drag = false
+	_additive_click = false
+	_press_empty = false
+	_press_travel = 0.0
+	return true
+
+
 func _commit_property_panel_on_deselect() -> void:
 	var main_n := _find_main()
 	if main_n == null or main_n.timeline == null:
```

What each part does:

- `PAD_FACE_EPS_MM` (0.6) and `PAD_INK_TOL_MM` (1.5) are the two thresholds. `_collect_ink` stores each sketch's non-construction lines (start/end) and circles/arcs (centre, radius; an arc is tested against its full circle, which is fine because the pad is already inside the sketch's bounding box). `_ink_distance` is the distance from a point to the nearest ink.
- `pick_pad_visible(ray_origin, ray_dir, solid_t)` is `pick_pad` plus the two depth rules. `pick_pad` stays as it is, unchanged, because `game/tests/lib/film_ui.gd` and `run_sketch_tests.gd` call it.
- `_solid_hit_t` turns `view.pick_info`'s `point` into a distance along the unit ray, `INF` when the ray missed.
- `_click_hits_pad` is the old inline block, moved into a function and switched to `pick_pad_visible`. It is called from the normal tail of `_on_release` and, new, from the `PUSH_PULL` branch when the release was a click. Nothing else in the `PUSH_PULL` branch changes: a real push/pull drag still returns without a pad test.
- `_commit_pick_sketch_host` now calls `pick_info` first and passes the solid distance.

**Step 4 — see it pass and check nothing else moved.**

```
tools/godot/godot --headless --path game --script tests/run_rung01_replan7_facepick.gd   # 31 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_sketch_tests.gd              # 83 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_replan5_face.gd       # 98 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_replan5_trim.gd       # 117 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_replan6_cut.gd        # 100 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd             # 359 checks, 8 failures (the F3 eight; WP2 clears them)
tools/godot/godot --headless --path game --script tests/run_sketch_to_3d_ui_tests.gd     # 47 checks, 2 failures (same as main)
```

**Pitfalls.**

- Do not delete `pick_pad`. Do not make `pick_pad_visible` call `pick_info` itself; the caller already has the hit.
- A face click that lands within 1.5 mm of a coplanar sketch's ink opens that sketch. That is intended. Test points in the test file are at least 5 mm from ink; keep it that way when you add points.
- The 0.6 mm window exists because the pad plane and the face are the same plane within float noise. Do not shrink it below 0.1.
- `MOVE_BODY` (press on an already-selected body) swallows plain clicks the same way. It is not changed here; the body is not what the handout clicks.
- Do not touch `FilmUI.enter_sketch_on_face`; films use it.

**Headless acceptance.** The six commands above, with the counts shown.

**GUI checklist item (sx-028 F1).** Extrude a blank. Press Esc. Click its top face once: the body is selected and no sketch opens. Click again: the face is selected and `Sketch` appears. Press `Sketch`: a new sketch opens on the top face.

### WP2 — Pin the pivot circle when a centre distance is dimensioned; make the checker's orientation geometric

**Files.** `game/scripts/sketch_mode.gd`, `tools/check_rung01.py`, new `tools/test_check_rung01.py`, new `game/tests/run_rung01_replan7_anchor.gd`.

**Commit 1 — the pin.**

Step 1: create `game/tests/run_rung01_replan7_anchor.gd` with this content.

```gdscript
# Rung 1 replan 7 WP2 — Smart Dimension between two circles keeps the origin circle at the origin.
# Run: tools/godot/godot --headless --path game --script tests/run_rung01_replan7_anchor.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main._start_sketch_on_ground()
	await process_frame
	var sm: SketchMode = main.sketch_mode
	var origin_id: String = sm.sketch.add_circle(0.0, 0.0, 10.0)
	var head_id: String = sm.sketch.add_circle(17.6, 0.0, 22.5)
	sm._smart_dim_between({"entity": origin_id, "role": "center"}, {"entity": head_id, "role": "center"})
	var idx := -1
	for i in sm.dimensions.size():
		if str(sm.dimensions[i].get("type", "")) == "distance":
			idx = i
	check(idx >= 0, "centre distance dimension exists")
	sm.set_dimension_value(idx, "200")
	var oc: Vector2 = sm.sketch.entity_info(origin_id)["center"]
	var hc: Vector2 = sm.sketch.entity_info(head_id)["center"]
	print("  origin circle %s head circle %s" % [str(oc), str(hc)])
	check(oc.length() < 1e-3, "origin circle stays at (0, 0) (got %s)" % str(oc))
	check(absf(hc.x - 200.0) < 1e-3 and absf(hc.y) < 1e-3, "head circle is at (200, 0) (got %s)" % str(hc))

	var far_id: String = sm.sketch.add_circle(-60.0, 40.0, 8.0)
	var near_id: String = sm.sketch.add_circle(-20.0, 40.0, 6.0)
	sm._smart_dim_between({"entity": far_id, "role": "center"}, {"entity": near_id, "role": "center"})
	var fc: Vector2 = sm.sketch.entity_info(far_id)["center"]
	check(fc.distance_to(Vector2(-60.0, 40.0)) < 1e-6, "circles away from the origin are not pinned (got %s)" % str(fc))
	sm._set_selected([origin_id])
	sm.constrain("diameter", 24.0)
	var rr := float(sm.sketch.entity_info(origin_id)["radius"])
	check(absf(rr - 12.0) < 1e-3, "a diameter dimension still resizes the pinned circle (radius %.3f)" % rr)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
```

Step 2: run it on unmodified product code.

```
tools/godot/godot --headless --path game --script tests/run_rung01_replan7_anchor.gd
```

Expected on `8478773d`: `5 checks, 2 failures`; the failures are `origin circle stays at (0, 0)` (got about (−77.29, 0)) and `head circle is at (200, 0)` (got about (122.71, 0)). If different, stop.

Step 3: apply.

```diff
diff --git a/game/scripts/sketch_mode.gd b/game/scripts/sketch_mode.gd
index d80fd7e..d8b4e6a 100644
--- a/game/scripts/sketch_mode.gd
+++ b/game/scripts/sketch_mode.gd
@@ -3330,6 +3330,8 @@ func _smart_dim_between(a: Dictionary, b: Dictionary) -> void:
 	if (ta == "circle" or ta == "arc") and (tb == "circle" or tb == "arc"):
 		var ca: Vector2 = sketch.entity_info(ida)["center"]
 		var cb: Vector2 = sketch.entity_info(idb)["center"]
+		_pin_circle_at_sketch_origin(ida, ca)
+		_pin_circle_at_sketch_origin(idb, cb)
 		constrain("distance", ca.distance_to(cb))
 		# A failed solve reverts the constraint. Do not open a popup on a
 		# stale index — only emit when that centre distance is still live.
@@ -3642,6 +3644,41 @@ func _lock_sized_circle(id: String) -> void:
 	sketch.add_constraint("fix", [{"entity": id, "role": "self"}], 0.0)
 
 
+const ORIGIN_PIN_TOL := 0.5
+
+
+func _pin_circle_at_sketch_origin(id: String, center: Vector2) -> void:
+	if center.length() > ORIGIN_PIN_TOL:
+		return
+	var anchor := _origin_anchor_point()
+	if anchor == "":
+		return
+	for cid in sketch.constraint_ids():
+		var info: Dictionary = sketch.constraint_info(cid)
+		if str(info.get("type", "")) != "coincident":
+			continue
+		var refs: Array = info.get("refs", [])
+		if refs.size() == 2 and str(refs[0].get("entity", "")) == id and str(refs[1].get("entity", "")) == anchor:
+			return
+	sketch.add_constraint("coincident", [
+		{"entity": id, "role": "center"},
+		{"entity": anchor, "role": "self"}], 0.0)
+
+
+func _origin_anchor_point() -> String:
+	for id in sketch.entity_ids():
+		var info: Dictionary = sketch.entity_info(id)
+		if str(info.get("type", "")) == "point" and sketch.is_construction(id) \
+				and _entity_has_constraint(id, "fix"):
+			return id
+	var pt: String = sketch.add_point(0.0, 0.0)
+	if pt == "":
+		return ""
+	sketch.set_construction(pt, true)
+	sketch.add_constraint("fix", [{"entity": pt, "role": "self"}], 0.0)
+	return pt
+
+
 ## Lock every sized circle (typed radius on the wrench bosses).
 func _lock_sized_circles() -> void:
 	if sketch == null:
```

Behaviour: `_pin_circle_at_sketch_origin` runs for both circles before `constrain("distance", …)` in `_smart_dim_between`. A circle whose centre is within `ORIGIN_PIN_TOL` (0.5 mm) of (0, 0) gets one `coincident` between its `center` and a construction point at (0, 0) that carries a `fix`. `_origin_anchor_point` reuses that point if one exists (a construction `point` entity that has a `fix`), otherwise it creates it. The `coincident` is added once per circle. Only the centre is pinned: radius stays editable, which the last test row checks (`diameter` 24 → radius 12). Do not use `_lock_sized_circle` here: it adds a `fix` that also freezes the radius and silently ignores a later diameter edit (measured: radius stayed 10.000).

Step 4: `5 checks, 0 failures`. Then:

```
tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd             # 379 checks, 0 failures (WP2 alone)
tools/godot/godot --headless --path game --script tests/run_rung01_replan4_smartdim.gd   # 47 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_replan5_smartdim.gd   # 66 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_replan6_smartdim.gd   # 81 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_rung01_replan6_cut.gd        # 100 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_sketch_tests.gd              # 83 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_sketch_fully_defined_tests.gd # 6 checks, 0 failures
tools/godot/godot --headless --path game --script tests/run_sketch_tools_tests.gd        # 141 checks, 13 failures (same as main)
```

Pitfalls: a circle that is not near the origin must stay free (the test's third block). The popup flow from replan 6 (`_emit_dimension_edit`) is below this code and must not move. Do not add the pin to the nut flow's centre-to-flat branch; it is a line/point distance, not two circles.

**Commit 2 — the checker.**

Step 1: create `tools/test_check_rung01.py` with this content.

```python
#!/usr/bin/env python3
"""Unit tests for the orientation logic in check_rung01.py.

Run: python3 tools/test_check_rung01.py
"""
import math
import sys
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_rung01 as c


def blank_vertices(head_x=200.0, pivot_x=0.0, thickness=10.0):
    """Vertices of a pivot disc (r10), a shaft (half width 10) and a head disc (r22.5)."""
    pts = []
    for cx, r in ((pivot_x, 10.0), (head_x, 22.5)):
        for k in range(48):
            a = 2 * math.pi * k / 48
            for z in (0.0, thickness):
                pts.append((cx + r * math.cos(a), r * math.sin(a), z))
    lo, hi = sorted((pivot_x, head_x))
    for x in np.linspace(lo, hi, 20):
        for y in (-10.0, 10.0):
            for z in (0.0, thickness):
                pts.append((x, y, z))
    return np.array(pts, float)


class OrientationTests(unittest.TestCase):
    def test_head_on_plus_x_is_a_rotation(self):
        v = blank_vertices()
        self.assertFalse(c.head_at_min_x(v))
        self.assertEqual(c.orientation_candidates(v)[0], (False, False))

    def test_head_on_minus_x_tries_the_180_rotation_first(self):
        v = blank_vertices(head_x=-200.0)
        self.assertTrue(c.head_at_min_x(v))
        self.assertEqual(c.orientation_candidates(v)[0], (True, True))

    def test_rotation_about_z_is_never_reported_as_a_mirror(self):
        v = blank_vertices()
        rot = v.copy()
        rot[:, 0] *= -1
        rot[:, 1] *= -1
        fx, fy = c.orientation_candidates(rot)[0]
        self.assertEqual(fx, fy)

    def test_mirror_candidate_is_second(self):
        for v in (blank_vertices(), blank_vertices(head_x=-200.0)):
            fx, fy = c.orientation_candidates(v)[1]
            self.assertNotEqual(fx, fy)


if __name__ == "__main__":
    unittest.main()
```

Run `python3 tools/test_check_rung01.py`. On `8478773d` all 4 tests error with `AttributeError: module 'check_rung01' has no attribute 'head_at_min_x'` (or `orientation_candidates`). That is the red.

Step 2: apply.

```diff
diff --git a/tools/check_rung01.py b/tools/check_rung01.py
index 033a47d..d50774b 100644
--- a/tools/check_rung01.py
+++ b/tools/check_rung01.py
@@ -134,6 +134,27 @@ def wrench_tests(tris, r):
     r.add('outer wall solid mid-z', inside(tris, (-9.7, 0, 5)), '', 'inside')
     r.add('1mm fillet on jaw top edge', not inside(tris, J(10, 10.08, 9.92)), '', 'outside')
 
+END_BAND = 10.0
+
+def head_at_min_x(V):
+    """True when the wide (head) end of the part is at the minimum-X end.
+
+    The head end is the X end whose last END_BAND mm has the larger Y extent
+    (head dia 45 against pivot boss dia 20). Geometry decides this, never a
+    count of failed rows, so a blank without holes cannot report a mirror.
+    """
+    lo, hi = V[:, 0].min(), V[:, 0].max()
+    def ye(m):
+        y = V[m, 1]
+        return float(y.max() - y.min())
+    return ye(V[:, 0] <= lo + END_BAND) > ye(V[:, 0] >= hi - END_BAND)
+
+def orientation_candidates(V):
+    """(flipx, flipy) pairs to try. The first is the pure rotation, the second the mirror."""
+    if head_at_min_x(V):
+        return [(True, True), (True, False)]
+    return [(False, False), (False, True)]
+
 def align(V, flipx, flipy, want_min):
     W = V.copy()
     if flipx: W[:, 0] *= -1
@@ -156,14 +177,13 @@ def main():
         r.add('bbox Z == new thickness', abs(ext[2] - T_) <= TOL, round(ext[2], 3), f'{T_}')
         s2 = math.sqrt(2) / 2
         best = None
-        for fx in (False, True):
-            for fy in (False, True):
-                W = align(V, fx, fy, (-10, -22.5, 0)); tr = tri_arrays(W, T)
-                zs = (0.5, T_ / 2, T_ - 0.5)
-                ok_h = all(not inside(tr, (0, 0, z)) for z in zs)
-                ok_j = all(not inside(tr, (200 + u * s2, u * s2, z)) for u in (3, 11, 18) for z in zs)
-                sc = ok_h + ok_j
-                if best is None or sc > best[0]: best = (sc, ok_h, ok_j, fx, fy)
+        for fx, fy in orientation_candidates(V):
+            W = align(V, fx, fy, (-10, -22.5, 0)); tr = tri_arrays(W, T)
+            zs = (0.5, T_ / 2, T_ - 0.5)
+            ok_h = all(not inside(tr, (0, 0, z)) for z in zs)
+            ok_j = all(not inside(tr, (200 + u * s2, u * s2, z)) for u in (3, 11, 18) for z in zs)
+            sc = ok_h + ok_j
+            if best is None or sc > best[0]: best = (sc, ok_h, ok_j, fx, fy)
         _, ok_h, ok_j, fx, fy = best
         r.add('pivot hole still through at new T', ok_h, f'flipX={fx} flipY={fy}', 'open at 0.5, T/2, T-0.5')
         r.add('jaw still through at new T', ok_j, '', 'open at 0.5, T/2, T-0.5')
@@ -181,17 +201,22 @@ def main():
         r.add('bore diameter', g is not None and abs(g - 10) <= TOL, g, '10.0')
         r.add('nut body solid at r=8', inside(tris, (0, 8, 3.75)) or inside(tris, (8, 0, 3.75)), '', 'inside')
         r.show(); sys.exit(1 if r.fail else 0)
+    if kind == 'blank':
+        r.add('bbox X (length)', abs(ext[0] - 232.5) <= TOL, round(ext[0], 3), '232.5')
+        r.add('bbox Y (head dia)', abs(ext[1] - 45) <= TOL, round(ext[1], 3), '45.0')
+        r.add('bbox Z (thickness)', abs(ext[2] - 10) <= TOL, round(ext[2], 3), '10.0')
+        r.add('head end at +X', not head_at_min_x(V), 'head at -X' if head_at_min_x(V) else 'head at +X', 'head at +X')
+        r.show(); sys.exit(1 if r.fail else 0)
     # wrench
     r.add('bbox X (length)', abs(ext[0] - 232.5) <= TOL, round(ext[0], 3), '232.5')
     r.add('bbox Y (head dia)', abs(ext[1] - 45) <= TOL, round(ext[1], 3), '45.0')
     r.add('bbox Z (thickness)', abs(ext[2] - 10) <= TOL, round(ext[2], 3), '10.0')
     best = None
-    for fx in (False, True):
-        for fy in (False, True):
-            W = align(V, fx, fy, (-10, -22.5, 0))
-            rr = R(); wrench_tests(tri_arrays(W, T), rr)
-            if best is None or rr.fail < best[0].fail:
-                best = (rr, fx, fy)
+    for fx, fy in orientation_candidates(V):
+        W = align(V, fx, fy, (-10, -22.5, 0))
+        rr = R(); wrench_tests(tri_arrays(W, T), rr)
+        if best is None or rr.fail < best[0].fail:
+            best = (rr, fx, fy)
     rr, fx, fy = best
     mirrored = (fx != fy)  # one flip = mirror image; two flips = 180 deg rotation
     r.add('orientation', (not mirrored) or allow_mirror,
```

Also edit the module docstring at the top of `tools/check_rung01.py`: add the line `  python3 check_rung01.py blank  <file.3mf>   # right after Extrude 10: size and head at +X` under the `wrench` usage line, and replace the sentence "if the head is at -X or the jaw opens to -Y the script tries the XY flips and reports which one it used (mirror only accepted with --allow-mirror)." with "the head end is found from the vertices (the X end whose last 10 mm has the larger Y extent); the script then tries only the rotation and the mirror for that end and reports which one it used (mirror only accepted with --allow-mirror)."

Step 3: `python3 tools/test_check_rung01.py` prints `Ran 4 tests` and `OK`. `python3 tools/check_rung01.py wrench <any wrench 3mf>` and the `nut` and `thick` commands still print their old rows. In `run_rung01_wrench.gd` the call `check_rung01.py wrench /tmp/sx-rung01-wrench.3mf` stays green.

Behaviour notes for the diff above:

- `head_at_min_x` compares the Y extent of the vertices within 10 mm of the minimum-X end with the same for the maximum-X end. Head Ø45 against pivot boss Ø20: 37+ mm against 20 mm.
- `orientation_candidates` returns the pure rotation first, then the mirror. For head at +X: `(False, False)` then `(False, True)`. For head at −X: `(True, True)` (a 180° rotation about Z) then `(True, False)`. The existing `rr.fail < best[0].fail` keeps the rotation on ties.
- `kind == 'blank'` checks closed mesh, `bbox X 232.5`, `Y 45`, `Z 10` within 0.2, and `head end at +X`. It never reports a mirror.
- Measured before and after on the same blank (`[232.416, 44.882, 10.0]`, head +X): old `orientation … flipX=True flipY=False (MIRROR)`; new `flipX=False flipY=False`, and `blank` prints `5/5 passed`. The same blank with X negated: `blank` fails `head end at +X got head at -X`. Rotated 180° about Z: `wrench` prints `flipX=True flipY=True`, which is not a mirror.

**Headless acceptance.** `run_rung01_replan7_anchor.gd` 5/0; `test_check_rung01.py` 4 tests OK; the regression list above.

**GUI checklist item (sx-028 F2).** Ground sketch: Ø20 at the origin, a head circle with a click on the right half of the screen, Smart Dimension on the two centres, type 200, Enter. The Ø20 centre still reads (0, 0) in the status/inspector and the head is at (200, 0). After tangents and Extrude 10: `check_rung01.py blank` prints 5/5.

### WP3 — One readable line when the extension is missing; typed `after_n`

**Files.** `Makefile`, `tools/lint_rung01_e2e.py`, new `game/tests/preflight_sxcore.gd`, and two lines in `game/tests/run_rung01_wrench.gd`.

**Step 1 — the two lines.** In `game/tests/run_rung01_wrench.gd`, in `_recovery_open_profile_then_new`, change

```gdscript
	var before_n := sm.sketch.entity_ids().size() if sm.sketch != null else 0
```
to
```gdscript
	var before_n: int = sm.sketch.entity_ids().size() if sm.sketch != null else 0
```
and
```gdscript
	var after_n := sm.sketch.entity_ids().size() if sm.sketch != null else 0
```
to
```gdscript
	var after_n: int = sm.sketch.entity_ids().size() if sm.sketch != null else 0
```
Touch nothing else in that file.

**Step 2 — the preflight.** Create `game/tests/preflight_sxcore.gd` with this content. It names no `Sx*` type, so it parses even when the extension is missing.

```gdscript
# Fails fast, with one readable line, when libsxcore did not load.
# Run: tools/godot/godot --headless --path game --script tests/preflight_sxcore.gd
extends SceneTree


func _init() -> void:
	if not ClassDB.class_exists("SxDocument"):
		printerr("PREFLIGHT FAIL: SxDocument is not registered, so libsxcore did not load. "
				+ "Put the OCCT libraries on the loader path first: "
				+ "export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib:$LD_LIBRARY_PATH")
		quit(2)
		return
	print("preflight ok: SxDocument is registered")
	quit(0)
```

**Step 3 — Makefile and lint.** Apply.

```diff
diff --git a/Makefile b/Makefile
index 3a992f1..32c9f49 100644
--- a/Makefile
+++ b/Makefile
@@ -2,10 +2,18 @@ BUILD_DIR := build
 GODOT := tools/godot/godot
 JOBS := $(shell nproc)
 
-.PHONY: all configure build test test-kernel test-godot lint-rung01-e2e clean import movies publish-demo-movies sync-website check-website-demos release-linux fetch-godot-templates
+.PHONY: all configure build test test-kernel test-godot preflight test-tools lint-rung01-e2e clean import movies publish-demo-movies sync-website check-website-demos release-linux fetch-godot-templates
 
 VERSION := $(shell cat VERSION 2>/dev/null || echo 0.0.0-dev)
 
+# OCCT shared libraries must be on the loader path or libsxcore does not load
+# and every Godot script dies with "Could not find type SxDocument".
+-include packaging/occt.version
+OCCT_PREFIX ?= /opt/occt-$(OCCT_VERSION)
+ifneq ($(wildcard $(OCCT_PREFIX)/lib),)
+export LD_LIBRARY_PATH := $(OCCT_PREFIX)/lib$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH))
+endif
+
 all: build
 
 configure:
@@ -23,7 +31,10 @@ test-kernel: build
 import: build
 	$(GODOT) --headless --path game --import > /dev/null 2>&1 || true
 
-test-godot: build import
+preflight: build import
+	$(GODOT) --headless --path game --script tests/preflight_sxcore.gd
+
+test-godot: build import preflight
 	$(GODOT) --headless --path game --script tests/run_parse_sweep_tests.gd
 	$(GODOT) --headless --path game --script tests/run_tests.gd
 	$(GODOT) --headless --path game --script tests/run_ui_tests.gd
@@ -113,12 +124,20 @@ test-godot: build import
 	$(GODOT) --headless --path game --script tests/run_rung01_replan6_smartdim.gd
 	$(GODOT) --headless --path game --script tests/run_rung01_replan6_export.gd
 	$(GODOT) --headless --path game --script tests/run_rung01_replan6_chrome.gd
+	@for f in game/tests/run_rung01_replan7_*.gd; do \
+		[ -e "$$f" ] || continue; \
+		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
+	done
 
 lint-rung01-e2e:
 	python3 tools/lint_rung01_e2e.py
 
+test-tools:
+	@if [ -f tools/test_check_rung01.py ]; then python3 tools/test_check_rung01.py; fi
+
 test: test-kernel
 	python3 tools/lint_rung01_e2e.py
+	$(MAKE) test-tools
 	$(MAKE) test-godot
 	@echo "ALL TESTS PASSED"
 
diff --git a/tools/lint_rung01_e2e.py b/tools/lint_rung01_e2e.py
index 78138d3..23d17d7 100644
--- a/tools/lint_rung01_e2e.py
+++ b/tools/lint_rung01_e2e.py
@@ -87,6 +87,9 @@ WALK_EXTRA_FORBIDDEN = REPLAN4_EXTRA_FORBIDDEN + (
     "new_document(",
     "graph_update_sketch(",
 )
+REPLAN7_FORBIDDEN = REPLAN5_FORBIDDEN + (
+    "select_entity(",
+)
 WALK_PRESS_RELEASE_EXTRA = (
     "_draw_centreline",
     "_end_centreline_chain",
@@ -327,6 +330,19 @@ def _lint_replan6(errors: list[str]) -> None:
         _lint_dimension_label_pos2(src, errors, prefix)
 
 
+def _lint_replan7(errors: list[str]) -> None:
+    paths = sorted(TESTS.glob("run_rung01_replan7_*.gd"))
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
@@ -338,6 +354,7 @@ def main() -> int:
     _lint_replan4(errors)
     _lint_replan5(errors)
     _lint_replan6(errors)
+    _lint_replan7(errors)
 
     if errors:
         print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
@@ -348,11 +365,13 @@ def main() -> int:
     n4 = len(list(TESTS.glob("run_rung01_replan4_*.gd")))
     n5 = len(list(TESTS.glob("run_rung01_replan5_*.gd")))
     n6 = len(list(TESTS.glob("run_rung01_replan6_*.gd")))
+    n7 = len(list(TESTS.glob("run_rung01_replan7_*.gd")))
     print(f"lint_rung01_e2e: {WALK} is clean")
     print(f"lint_rung01_e2e: {n3} replan3 scripts are clean")
     print(f"lint_rung01_e2e: {n4} replan4 scripts are clean")
     print(f"lint_rung01_e2e: {n5} replan5 scripts are clean")
     print(f"lint_rung01_e2e: {n6} replan6 scripts are clean")
+    print(f"lint_rung01_e2e: {n7} replan7 scripts are clean")
     return 0
 
 
```

What it does: the Makefile includes `packaging/occt.version` (it defines `OCCT_VERSION=8.0.1`), sets `OCCT_PREFIX` to `/opt/occt-$(OCCT_VERSION)` unless the caller overrides it, and prepends `$(OCCT_PREFIX)/lib` to `LD_LIBRARY_PATH` for every recipe when that directory exists. `make preflight` and `make test-godot` run the preflight first. `make test-godot` runs every `game/tests/run_rung01_replan7_*.gd` through a shell loop so WP1 and WP2 do not need to edit the Makefile. `make test-tools` runs `tools/test_check_rung01.py` when it exists, and `make test` calls it. The lint now scans `run_rung01_replan7_*.gd` with the replan-5 list plus `select_entity(`, and forbids `select_entity(` in the walk; with zero replan-7 scripts it prints `0 replan7 scripts are clean`.

**Step 4 — checks.**

```
env -u LD_LIBRARY_PATH make preflight                                   # last line: preflight ok: SxDocument is registered
env -u LD_LIBRARY_PATH make preflight OCCT_PREFIX=/nonexistent          # PREFLIGHT FAIL: SxDocument is not registered, so libsxcore did not load. …  then: make: *** [Makefile:35: preflight] Error 2
env -u LD_LIBRARY_PATH tools/godot/godot --headless --path game --script tests/preflight_sxcore.gd; echo $?   # prints the PREFLIGHT FAIL line, then 2
make lint-rung01-e2e                                                    # ends with: lint_rung01_e2e: 0 replan7 scripts are clean   (2 once WP1 and WP2 are merged)
make test-tools                                                         # prints nothing until WP2 is merged, then Ran 4 tests / OK
```

The diff adds `select_entity(` only to the new replan-7 list. It does not add it to the walk's list, because the walk still has two `select_entity(` calls until WP4 (`_recovery_ground_sketch` and `_sketch_on_top`); WP4 adds that rule.

**Headless acceptance.** The five commands above. `run_rung01_wrench.gd` with `LD_LIBRARY_PATH` set prints the same `359 checks, 8 failures` as before (the typed ints change nothing).

**GUI checklist item (sx-028 F4).** None. This WP is test infrastructure; say so in the critique.

### WP4 — The walk clicks the face and has no recovery path

Last. Rebase on `main` after WP1, WP2 and WP3 are merged. This is the only package that edits `run_rung01_wrench.gd` beyond WP3's two lines.

**Step 1 — the diff.** Apply, then add the lint line from the WP3 note.

```diff
diff --git a/game/tests/run_rung01_wrench.gd b/game/tests/run_rung01_wrench.gd
index e599772..6928814 100644
--- a/game/tests/run_rung01_wrench.gd
+++ b/game/tests/run_rung01_wrench.gd
@@ -8,6 +8,7 @@
 extends SceneTree
 
 const FilmUI = preload("res://tests/lib/film_ui.gd")
+const SHAFT_PICK_X := 100.0
 const TOL := 0.2
 const ROOT_SIZE := Vector2i(1280, 800)
 const NEW_SENTENCE := "New — empty part, Top plane (XY). View ▸ Timeline to edit features"
@@ -887,8 +888,7 @@ func _recovery_ground_sketch(ctx: FilmContext, ground := Vector3(22, 18, 0)) ->
 	var sm: SketchMode = ctx.main.sketch_mode
 	if sm != null and sm.active:
 		return
-	if ctx.view != null:
-		ctx.view.select_entity("", "")
+	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
 	await process_frame
 	await _zoom(ctx, ground, 80.0)
 	var sketch_btn := FilmUI.find_palette_sketch_button(ctx.main)
@@ -1784,34 +1784,26 @@ func _assert_contours_stay_on(ctx: FilmContext) -> void:
 
 
 func _sketch_on_top(ctx: FilmContext, body: String, top: String, z_top: float) -> void:
-	var host := Vector3(100, 0, z_top)
-	if top != "":
-		var picked := FilmUI.face_pick_point(ctx.view, body, top)
-		if picked != Vector3.INF:
-			host = picked
-	await _zoom(ctx, host, 500.0)
-	var host_screen := FilmUI.model_to_screen(ctx, host)
-	if FilmUI.is_on_screen(ctx, host_screen):
-		await _aim_pointer(ctx, host_screen)
-		await _pointer_click(ctx, host_screen, false)
-		await process_frame
-	var sm: SketchMode = ctx.main.sketch_mode
-	var on_top := sm.active and sm.plane_normal().dot(Vector3(0, 0, 1)) > 0.9 \
-			and absf(sm.plane_origin.z - z_top) < 0.5
-	if sm.active and not on_top:
-		var exit_btn := FilmUI.find_sketch_tool_button(ctx.main, "Exit Sketch")
-		await FilmUI.click_control(ctx, exit_btn, FilmUICues.exit_sketch())
-		await process_frame
-		sm = ctx.main.sketch_mode
-		on_top = false
-	if not on_top:
-		if top != "":
-			ctx.view.select_entity(body, top)
-		ctx.main.interaction._refresh_selection_strip()
-		var sketch_btn: Button = ctx.main.interaction._strip_sketch
-		await FilmUI.click_control(ctx, sketch_btn, FilmUICues.toolbar_sketch())
-		await process_frame
-		await process_frame
+	var vp: Viewport = ctx.main.get_viewport()
+	var host := Vector3(SHAFT_PICK_X, 0.0, z_top)
+	await _look_along(ctx, Vector3(0, 0, 1), host, 500.0)
+	await _push_key(vp, KEY_ESCAPE, 0)
+	var screen := FilmUI.model_to_screen(ctx, host)
+	check(FilmUI.require_on_screen(ctx, screen, "top face pick"), "top face pick is on screen")
+	await _aim_pointer(ctx, screen)
+	await _x11_click_screen(vp, screen)
+	await process_frame
+	check(not ctx.main.sketch_mode.active, "first top-face click does not reopen a sketch")
+	check(ctx.view.selected_body == body, "first top-face click selects the body")
+	await _x11_click_screen(vp, screen)
+	await process_frame
+	check(not ctx.main.sketch_mode.active, "second top-face click does not reopen a sketch")
+	check(ctx.view.selected_face == top, "second top-face click selects the top face")
+	var strip: Button = ctx.main.interaction._strip_sketch
+	check(strip.is_visible_in_tree(), "selection strip offers Sketch")
+	await FilmUI.click_control(ctx, strip, FilmUICues.toolbar_sketch())
+	await process_frame
+	await process_frame
 
 
 func _ground_sketch(ctx: FilmContext) -> void:
```

Add `"select_entity(",` to `WALK_EXTRA_FORBIDDEN` in `tools/lint_rung01_e2e.py` (the line sits right after `"dimension_edit_requested.emit",`).

What the edit does:

- `SHAFT_PICK_X := 100.0` is the click point on the shaft's top face, a point that has material both before the jaw is cut and after. Never use `FilmUI.face_pick_point` for a click: it is a vertex average and can sit in a hole.
- `_sketch_on_top` looks along −Z with the existing `_look_along(ctx, Vector3(0, 0, 1), host, 500.0)`, presses Esc so nothing is selected, clicks the point once (the body is selected, no sketch opens), clicks again (the face is selected), checks the selection strip offers `Sketch`, and presses it with `FilmUI.click_control`. There is no `Exit Sketch` recovery, no `select_entity`, no `_refresh_selection_strip`. A wrong result fails the check and the walk goes on to fail at the next row.
- `_recovery_ground_sketch` presses Esc instead of calling `ctx.view.select_entity("", "")`.
- Leave `_ensure_body_selected` as it is (it uses a side view and a private strip refresh). Switching it to a top-down click breaks the fillet face picks: those clicks land within 1.5 mm of the slot ink, which is the intended WP1 behaviour (measured: 24 failures). That cleanup is out of scope.

**Step 2 — run.**

```
python3 tools/lint_rung01_e2e.py                                                  # clean; replan7 scripts counted
tools/godot/godot --headless --path game --script tests/run_rung01_wrench.gd      # 391 checks, 0 failures
```

Before WP1 and WP2 are in, the same command prints 59 failures; that is the red. It must be green on `main` after WP1–WP3. The run writes `/tmp/sx-rung01-wrench.3mf` and calls `python3 tools/check_rung01.py wrench` on it: `28/28`.

**Step 3 — full suite.** `make test` with the pre-existing failures listed in F5 unchanged. `make test-godot` stops at the first failing script; to see the whole picture run the scripts one by one, as AGENTS.md says.

**Pitfalls.**

- If `selection strip offers Sketch` fails, the second click did not select the face: check that Esc ran first and the point is on the shaft (x = 100), not near a sketch's ink.
- `_look_along` with `z > 0.9` uses a 75° pitch. That is the angle the walk always used here; do not change it to 90° (degenerate up vector).
- The walk's check count is 391 with this diff. A different count with 0 failures means the diff was applied differently; diff against this file.

**GUI checklist item (sx-028 F1+F2).** The whole handout in one pass, below.

## Order of work

1. In parallel: WP1, WP2, WP3 (three agents, three PRs, no shared files).
2. After all three are merged: WP4.
3. Then the sx-028 critique on a build that contains WP4. Do not re-critique `8478773d`.

## sx-028 GUI critique checklist

Desktop 1280×800, real mouse and keyboard, no scripts, no private calls. Record each row as pass or fail with the status line or a number. Save the exported files and run the four checker commands on them.

| # | Do | Expect |
|---|---|---|
| A1–A6 | Nut: AF 20, r 5, Distance 7.5, export bare `nut.3mf` into a folder you typed in the dialog's path field | `nut 7/7`; the file is in that folder |
| B1.1 | Ground sketch, Circle, radius field `Radius`: type 10, centre on the origin | Ø20 at (0, 0) |
| B1.2 | Second circle: click on the **right** half of the screen, type 22.5 in `Radius` (not the `Extrude` field) | Ø45; status does not say `Extrude 22.5` |
| B1.3 | Smart Dimension, click centre of Ø20, click centre of Ø45 | Popup opens at once. Type 200, Enter |
| B1.3b | Look at the Ø20 against the sketch origin marker before and after typing 200 | The Ø20 stays on the origin; only the dimension reads 200 (F2) |
| B1.4 | Two tangent lines, Extrude Blind 10, export `blank.3mf` | `check_rung01.py blank` 5/5, head at +X |
| B2.1 | Esc. Click the top face once | Body selected, no sketch opens (F1) |
| B2.2 | Click the top face again | Face selected, strip shows `Sketch` |
| B2.3 | Press `Sketch` | New sketch on the top face; Sketch 1 is untouched |
| B2.4 | Ø10 at the origin, Ø45 at the head, Center Three Point jaw, width 20, angle 45 | Width label exists and reads 20; the head circle is at (200, 0) |
| B2.5 | Centreline retry, Power Trim | One cutter remains; `Trimmed open jaw` |
| B2.6 | Cut, Up To Surface, `Opposite face`, Extrude | Jaw and hole cut; no `Open-profile` message |
| B3.1 | Esc, then click the top face on the shaft away from any drawn line, twice, then `Sketch` | A **new** sketch on the face, not the jaw sketch (F1) |
| B3.2 | R5 slot, Cut, Blind 2.5, Extrude | Slot 2.5 deep; the jaw is not re-cut |
| B3.3 | Click exactly on a drawn slot line of the saved sketch (nothing selected) | That sketch reopens (ink wins) |
| B4 | Fillets: R10 neck, 1 mm edges, slot floor | Timeline shows the fillets; slot floor 1.5 refused with a named limit |
| B5 | Export `wrench.3mf`; thickness to 14 and export `wrench-t14.3mf` | `wrench 28/28`, `thick 4/4`, orientation row says `flipX=False flipY=False` |
| C | Resize/overlap/readability spot check: `Exit Sketch` readable, dimension labels distinct | Pass |

Score at least 9 and all four checker lines green closes rung 1.

## Out of scope

- `MOVE_BODY` swallowing plain clicks on an already-selected body; `FilmUI.enter_sketch_on_face`'s `pads.visible = false`; `_ensure_body_selected`'s side-view workaround. All listed in F1, all left alone on purpose.
- The pre-existing failures in F5. `nav_preset` defaults (`FUSION` vs `SOLIDEXPRESS`) tests from AGENTS.md also stay.
- Camera and `ModelSpace`: the right half of the ground sketch is +X (F2.1).
