# Replan 12 WP6 — fillet picks: camera-aware snap, face click only as the first pick, a miss keeps the set, status text, Esc ends the pick

You are a BUILD agent. **WP5 and WP3 must be merged first** (WP5: same two functions of `viewport_interaction.gd`; WP3: `main.gd`). Edit only the files below and add `game/tests/run_rung01_replan12_pick.gd`.

| File | Function / hunk (line numbers are `2606160c`) |
|---|---|
| `game/scripts/document_view.gd` | new `model_to_screen`, `edge_near_screen` after `edge_near_point` (~1257); `_polyline_screen_distance` (~1303) becomes a wrapper over the new `_polyline_screen_nearest`; new `_edge_point_visible` |
| `game/scripts/ops_panel.gd` | `_apply_dressup` (~852), `_open_last_feature` (~946), `cancel_pending_pick` (~1769), `_accumulate_dressup_edge` (~1996) split into itself + `handle_viewport_miss` + `_toggle_dressup_edge`; consts `DRESSUP_SNAP_PX`, `DRESSUP_SILHOUETTE_PX`; `_dressup_camera`, `_dressup_has_edges` |
| `game/scripts/main.gd` | `open_feature_params` (~1889) takes a `lead` text |
| `game/scripts/viewport_interaction.gd` | `cancel_stack`: the **second** rung, after WP5's; `_on_release`: the `armed_pick` condition and the armed branch |

## The bugs (measured on `2606160c` with real pointer events)

1. **Fillet pick camera.** `view.edge_near_point(body, point, tol)` measures in model millimetres from the clicked surface point. From Top (key `3`) a click on a neck corner hits the top face next to the vertical edge, and the vertical is a point on screen. The walk on `2606160c` arms a **179.8 mm side line** (`Fillet: 1 edge(s) — 179.8 mm line — click more …`) instead of the 10 mm vertical; the new pick test arms no edge at all (`edges []`). The sx-032 walker needed the `_look_along` helper.
2. **Face click while armed.** With edges armed, a click on a face interior still calls `_add_dressup_face`, which fillets the whole face and replaces the set (`Fillet: 4 edge(s) — 40.0 mm line, 10.0 mm vertical …`).
3. **Press off the solid.** A press on background falls into `if _press_empty:`, which clears the selection and the armed set; the sx-032 walker lost two picked edges.
4. **Status text.** `Enter` ends in `Feature created — …` which overwrote `Fillet 2 edges 10.00 applied`. A removed edge reads only `— removed`.
5. **Esc.** Esc with Fillet armed reached `cancel_stack`, which cleared the selection (`Selection cleared`) and left Fillet armed; `ops_panel.cancel_pending_pick()` (the function that ends an armed pick) was unreachable from the keyboard.

## Decisions (see `rung-01-replan-12.md` 4, 5, 6, 7 and 12)

- Edge snap is in **screen pixels**: `view.edge_near_screen(body, camera, screen, max_px)` projects each edge polyline, takes the closest approach, ignores edges whose closest point is hidden behind a face (`_edge_point_visible`: a ray from the camera through the projected point must not hit the solid more than `max(0.3, 0.002 × dist)` mm earlier), and breaks ties within `EDGE_PICK_SCREEN_TIE_PX` (8 px) in favour of the edge most parallel to the view ray (end-on wins).
- `DRESSUP_SNAP_PX = 14` for a face click while edges are armed; `DRESSUP_SILHOUETTE_PX = 10` for a press that missed the solid. Both constants live on `OpsPanel`.
- A face click takes the face's edges **only** as the first pick (nothing armed). Armed, it snaps to an edge within 14 px or says `No edge near click — click on an edge (a face click fillets the whole face only as the first pick)` and keeps the set.
- A press off the solid while a pick is armed never clears anything: an edge within 10 px of the press is toggled, otherwise `Missed the solid — click a face or edge`. With nothing armed the old empty-press behaviour (clear + commit panel) is unchanged.
- `_apply_dressup` builds `applied = "<name> <scope> <value> applied"`, emits it and passes it as `lead` through `_open_last_feature` to `open_feature_params`, which prints `<lead> — View ▸ Timeline to edit parameters` instead of `Feature created — …`. Other callers keep `Feature created`.
- Re-clicking an armed edge removes it and the status ends `— removed <len> <kind>` (e.g. `removed 10.0 mm vertical`).
- Esc: `cancel_stack`'s second rung calls `ops_panel.cancel_pending_pick()`. For a fillet/chamfer pick it also drops the picked edges (keeps the body selected), resets `_dressup_from_face` and emits `Edge pick cancelled`.

## Diffs (measured; apply by function name)

### `game/scripts/document_view.gd`

```diff
diff --git a/game/scripts/document_view.gd b/game/scripts/document_view.gd
index 45e698a..d0ff1e3 100644
--- a/game/scripts/document_view.gd
+++ b/game/scripts/document_view.gd
@@ -1290,6 +1290,35 @@ func edge_near_point(body_id: String, point: Vector3, tolerance_mm: float = EDGE
 	return best_id
 
 
+## Screen position of a model-space point under `camera`.
+func model_to_screen(camera: Camera3D, point: Vector3) -> Vector2:
+	return camera.unproject_position(_model_to_world(point))
+
+
+## Closest edge of `body_id` to a screen position, within `max_px`, "" when none.
+## Edges within EDGE_PICK_SCREEN_TIE_PX of each other prefer the one most
+## parallel to the view ray (an end-on vertical beats the arc it meets).
+func edge_near_screen(body_id: String, camera: Camera3D, screen: Vector2, max_px: float) -> String:
+	var lines: Dictionary = doc.get_edge_lines(body_id)
+	var ray := (-camera.global_transform.basis.z).normalized()
+	var best_id := ""
+	var best_px := INF
+	var best_align := -1.0
+	for edge_id in lines:
+		var near := _polyline_screen_nearest(camera, screen, lines[edge_id])
+		var px: float = near["px"]
+		if px > max_px or not _edge_point_visible(camera, near["point"]):
+			continue
+		var align := absf(_model_to_world_dir(edge_direction(body_id, str(edge_id))).dot(ray))
+		var closer := px < best_px - EDGE_PICK_SCREEN_TIE_PX
+		var tie := absf(px - best_px) <= EDGE_PICK_SCREEN_TIE_PX
+		if best_id == "" or closer or (tie and align > best_align + 0.05):
+			best_id = str(edge_id)
+			best_px = px
+			best_align = align
+	return best_id
+
+
 func _model_to_world(p: Vector3) -> Vector3:
 	return to_global(p) if is_inside_tree() else p
 
@@ -1301,7 +1330,13 @@ func _model_to_world_dir(d: Vector3) -> Vector3:
 
 
 func _polyline_screen_distance(camera: Camera3D, screen: Vector2, pts: PackedVector3Array) -> float:
+	return _polyline_screen_nearest(camera, screen, pts)["px"]
+
+
+## Closest approach of the projected polyline to `screen`: {px, point (model space)}.
+func _polyline_screen_nearest(camera: Camera3D, screen: Vector2, pts: PackedVector3Array) -> Dictionary:
 	var best := INF
+	var best_pt := Vector3.ZERO
 	for i in range(pts.size() - 1):
 		var wa := _model_to_world(pts[i])
 		var wb := _model_to_world(pts[i + 1])
@@ -1309,8 +1344,33 @@ func _polyline_screen_distance(camera: Camera3D, screen: Vector2, pts: PackedVec
 			continue
 		var a := camera.unproject_position(wa)
 		var b := camera.unproject_position(wb)
-		best = minf(best, _point_segment_distance2(screen, a, b))
-	return best
+		var ab := b - a
+		var t := 0.0 if ab.length_squared() < 1e-12 else clampf((screen - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
+		var d := screen.distance_to(a + ab * t)
+		if d < best:
+			best = d
+			best_pt = pts[i].lerp(pts[i + 1], t)
+	return {"px": best, "point": best_pt}
+
+
+## False when a solid face sits between the camera and `model_pt` (a hidden edge
+## must not be snapped to through a wall).
+func _edge_point_visible(camera: Camera3D, model_pt: Vector3) -> bool:
+	var world_pt := _model_to_world(model_pt)
+	var sp := camera.unproject_position(world_pt)
+	var wo := camera.project_ray_origin(sp)
+	var wd := camera.project_ray_normal(sp)
+	var o := to_local(wo) if is_inside_tree() else wo
+	var d := (to_local(wo + wd) - o) if is_inside_tree() else wd
+	if d.length_squared() < 1e-12:
+		return true
+	d = d.normalized()
+	var dist := (model_pt - o).dot(d)
+	var hit: Dictionary = doc.pick(o, d)
+	if hit.is_empty() or not (hit.get("point") is Vector3):
+		return true
+	var hit_dist := ((hit["point"] as Vector3) - o).dot(d)
+	return hit_dist >= dist - maxf(0.3, dist * 0.002)
 
 
 func _point_segment_distance2(p: Vector2, a: Vector2, b: Vector2) -> float:
```

### `game/scripts/ops_panel.gd`

```diff
diff --git a/game/scripts/ops_panel.gd b/game/scripts/ops_panel.gd
index 37d9677..97c5b84 100644
--- a/game/scripts/ops_panel.gd
+++ b/game/scripts/ops_panel.gd
@@ -884,11 +884,12 @@ func _apply_dressup(fillet: bool) -> void:
 	if ok:
 		_dressup_from_face = false
 		view.graph_changed()
-		status.emit("%s %s %.2f applied" % [name, scope, value])
+		var applied := "%s %s %.2f applied" % [name, scope, value]
+		status.emit(applied)
 		_pending = Pending.NONE
 		dressup_armed_changed.emit(false, fillet)
 		if new_fid != "":
-			_open_last_feature("fillet" if fillet else "chamfer")
+			_open_last_feature("fillet" if fillet else "chamfer", applied)
 	else:
 		if fillet:
 			status.emit(_fillet_refusal_status(value, targets.size()))
@@ -943,7 +944,7 @@ func _fault_phrase(why: String) -> String:
 	return "" if m == null else m.get_string(1)
 
 
-func _open_last_feature(ftype: String) -> void:
+func _open_last_feature(ftype: String, lead: String = "") -> void:
 	var main := _find_main()
 	if main == null or not main.has_method("open_feature_params"):
 		return
@@ -952,7 +953,7 @@ func _open_last_feature(ftype: String) -> void:
 		if str(f.get("type", "")) == ftype:
 			fid = str(f.get("id", ""))
 	if fid != "":
-		main.open_feature_params(fid)
+		main.open_feature_params(fid, lead)
 
 
 func _find_main() -> Node:
@@ -1782,6 +1783,9 @@ func cancel_pending_pick() -> bool:
 	_selected_hole_fid = ""
 	_clear_hole_wizard()
 	if was_dress:
+		if view.selected_body != "" and (view.selected_edges.size() > 0 or view.selected_edge != ""):
+			view.select_entity(view.selected_body, "")
+		_dressup_from_face = false
 		dressup_armed_changed.emit(false, was_fillet)
 	if was_wizard:
 		status.emit("Hole Wizard cancelled")
@@ -2001,21 +2005,61 @@ func _accumulate_dressup_edge(body: String, point: Vector3, face: String = "") -
 	if _pending_body != "" and body != _pending_body:
 		status.emit("Fillet/Chamfer: pick edges on the same body")
 		return
-	# A click on the face interior fillets every edge of that face. A click
-	# on the silhouette (within 2.5 mm, or 12 mm when no face was hit) adds
-	# one edge so the two neck edges can share one feature.
-	var edge := view.edge_near_point(body, point, 2.5)
+	# A click on the face interior fillets every edge of that face, but only as
+	# the FIRST pick. Once an edge is armed, a face click snaps to the nearest
+	# edge within DRESSUP_SNAP_PX or is refused; it never replaces the set.
+	var cam := _dressup_camera()
+	var edge := view.edge_near_point(body, point, 2.5, cam)
 	if edge == "" and face != "":
-		_add_dressup_face(body, face)
-		return
+		if not _dressup_has_edges():
+			_add_dressup_face(body, face)
+			return
+		if cam != null:
+			edge = view.edge_near_screen(body, cam, view.model_to_screen(cam, point), DRESSUP_SNAP_PX)
+		if edge == "":
+			status.emit("No edge near click — click on an edge (a face click fillets the whole face only as the first pick)")
+			return
 	if edge == "":
-		edge = view.edge_near_point(body, point, 12.0)
+		edge = view.edge_near_point(body, point, 12.0, cam)
 	if edge == "":
 		status.emit("No edge near click — zoom in or click closer to an edge")
 		return
-	# Additive edge selection while armed (do not go through select_ray —
-	# face refine would clear the edge set).
+	_toggle_dressup_edge(body, edge)
+
+
+const DRESSUP_SNAP_PX := 14.0
+const DRESSUP_SILHOUETTE_PX := 10.0
+
+
+func _dressup_camera() -> Camera3D:
+	if view == null or not view.is_inside_tree():
+		return null
+	return view.get_viewport().get_camera_3d()
+
+
+func _dressup_has_edges() -> bool:
+	return not view.selected_edges.is_empty() or view.selected_edge != ""
+
+
+## A press that missed the solid while a pick is armed. Never clears the set:
+## an edge seen edge-on within DRESSUP_SILHOUETTE_PX of the press is toggled,
+## anything else is a named miss.
+func handle_viewport_miss(screen: Vector2, camera: Camera3D) -> void:
+	var body := _pending_body if _pending_body != "" else view.selected_body
+	if (_pending == Pending.FILLET_EDGES or _pending == Pending.CHAMFER_EDGES) \
+			and body != "" and camera != null:
+		var edge := view.edge_near_screen(body, camera, screen, DRESSUP_SILHOUETTE_PX)
+		if edge != "":
+			_toggle_dressup_edge(body, edge)
+			return
+	status.emit("Missed the solid — click a face or edge")
+
+
+## Add `edge` to the armed set, or remove it when it is already there. Does not
+## go through select_ray (face refine would clear the edge set).
+func _toggle_dressup_edge(body: String, edge: String) -> void:
 	if view.selected_edges.has(edge) or view.selected_edge == edge:
+		var gone := _edge_length_kind(body, edge)
 		view.selected_edges.erase(edge)
 		if view.selected_edge == edge:
 			view.selected_edge = str(view.selected_edges[0]) if not view.selected_edges.is_empty() else ""
@@ -2024,7 +2068,7 @@ func _accumulate_dressup_edge(body: String, point: Vector3, face: String = "") -
 		view._highlight_edge()
 		view.selection_changed.emit(view.selected_body, view.selected_face)
 		_dressup_from_face = false
-		status.emit(_dressup_pick_status() + " — removed")
+		status.emit(_dressup_pick_status() + " — removed " + gone)
 		return
 	elif view.selected_edges.is_empty() and view.selected_edge == "":
 		view.select_edge(body, edge)
```

### `game/scripts/main.gd` (`open_feature_params` only; WP3 owns the rest of the file)

```diff
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
index 9af07ea..9516f49 100644
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -1886,19 +1889,20 @@ func _reflow_left_stack() -> void:
 
 ## After creating a feature: open params ONLY if Timeline is already user-shown.
 ## Never force Timeline on — that broke "hidden until requested."
-func open_feature_params(fid: String) -> void:
+func open_feature_params(fid: String, lead: String = "") -> void:
 	if fid == "" or timeline == null:
 		return
+	var head := "Feature created" if lead == "" else lead
 	if not show_timeline:
-		_on_status("Feature created — View ▸ Timeline to edit parameters")
+		_on_status(head + " — View ▸ Timeline to edit parameters")
 		return
 	_update_panel_visibility()
 	timeline.refresh()
 	timeline._select_feature(fid)
 	if timeline.property_panel != null and timeline.property_panel.visible:
-		_on_status("Feature created — adjust parameters (Esc cancels, deselect keeps)")
+		_on_status(head + " — adjust parameters (Esc cancels, deselect keeps)")
 	else:
-		_on_status("Feature created — edit Params (JSON) if needed")
+		_on_status(head + " — edit Params (JSON) if needed")
 
 
 ## Keep View menu checkboxes honest with show_* flags.
```

### `game/scripts/viewport_interaction.gd` (as it looks after WP5 merged)

```diff
--- a/game/scripts/viewport_interaction.gd
+++ b/game/scripts/viewport_interaction.gd
@@ -1580,6 +1580,11 @@
 			vp.gui_get_focus_owner().release_focus()
 		status.emit("Edits cancelled")
 		return true
+	if ops_panel != null and ops_panel.cancel_pending_pick():
+		clear_hole_markers()
+		if vp != null and _should_release_cancel_focus(vp.gui_get_focus_owner()):
+			vp.gui_get_focus_owner().release_focus()
+		return true
 	if vp != null:
 		var focus := vp.gui_get_focus_owner()
 		if _should_release_cancel_focus(focus):
@@ -3379,7 +3384,8 @@
 	# An armed fillet/chamfer/hole pick must hit the solid, not reopen the pad.
 	if was_click and _click_hits_pad():
 		return
-	if _press_empty:
+	var armed_pick := ops_panel != null and ops_panel.consumes_viewport_pick()
+	if _press_empty and not armed_pick:
 		if not _additive_click:
 			view.clear_selection()
 			_commit_property_panel_on_deselect()
@@ -3392,15 +3398,16 @@
 	# Prefer the press ray so a tiny slide off the body still selects it.
 	var ray := _model_ray(_press_pos)
 	# Armed geometry picks (Hole Wizard / Fillet edges / …) must NOT go through
-	# select_ray face-refine — that clears accumulated edges mid-pick.
-	if ops_panel != null and ops_panel.consumes_viewport_pick():
+	# select_ray face-refine — that clears accumulated edges mid-pick. An empty
+	# press while armed keeps the set (silhouette pick or a named miss).
+	if armed_pick:
 		var hit: Dictionary = view.pick_info(ray[0], ray[1])
 		if not hit.is_empty():
 			ops_panel.handle_viewport_pick(
 				str(hit.get("body", "")), str(hit.get("face", "")),
 				hit.get("point", Vector3.ZERO) as Vector3)
 		else:
-			status.emit("Missed the solid — click a face or edge")
+			ops_panel.handle_viewport_miss(_press_pos, get_viewport().get_camera_3d())
 		_box_drag = false
 		_additive_click = false
 		_press_empty = false
```

## Test — `game/tests/run_rung01_replan12_pick.gd` (create)

Builds a 40×20×10 box, arms Fillet (`select_entity` + the ops panel; arming through the strip is allowed in this validation suite), then drives **real pointer events** with `Viewport.push_input` from the Top and Back views (keys `3`, `4` through `camera.handle_input`): corner click, far-face click while armed (refused), neighbour vertical within 14 px, press on background, re-click to remove, Enter, a 5 px off-silhouette press, a hidden far vertical that must not be snapped to, face click with nothing armed (4 edges), and one real Esc.

`game/tests/run_rung01_replan12_pick.gd`

```gdscript
# Rung 1 replan 12 WP4/WP5 — fillet picks through the real pointer path: end-on corner pick,
# face click while armed, press off the solid, status text.
# Real events: Viewport.push_input (motion, press, release), never ix._input.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_pick.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)

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
	print("rung01 replan12 WP4/WP5 fillet picks")
	FilmUI.reset_fail_count()
	await _run()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _push_click(pos: Vector2) -> void:
	var vp: Viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	vp.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		vp.push_input(ev)
		await process_frame
	await process_frame


func _push_key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _vertical_edges(view: DocumentView, body: String) -> Array:
	var out := []
	var lines: Dictionary = view.doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		var d: Vector3 = pts[pts.size() - 1] - pts[0]
		if absf(d.z) >= 5.0 and absf(d.x) < 0.2 and absf(d.y) < 0.2:
			out.append(str(id))
	return out


func _top_of(view: DocumentView, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return pts[0] if pts[0].z > pts[pts.size() - 1].z else pts[pts.size() - 1]


func _mid_of(view: DocumentView, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return (pts[0] + pts[pts.size() - 1]) * 0.5


func _tap(main, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	main.camera.handle_input(ev)
	await process_frame
	await process_frame


func _arm(main, body: String) -> void:
	main.view.select_entity(body, "")
	main.ops_panel.set_dressup_radius(1.0)
	main.ops_panel.arm_or_apply_fillet()
	await process_frame
	await process_frame


func _st(main) -> String:
	return str(main.status_label.text)


func _fillet_count(view: DocumentView) -> int:
	var n := 0
	for f in view.doc.graph_features():
		if str(f.get("type", "")) == "fillet":
			n += 1
	return n


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	var view: DocumentView = main.view
	var ops = main.ops_panel
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	var verts := _vertical_edges(view, body)
	check(verts.size() == 4, "box has 4 vertical edges (got %d)" % verts.size())
	var bb: Dictionary = view.doc.measure_bbox(body)
	var centre: Vector3 = (bb["min"] + bb["max"]) * 0.5

	# 1. Top view: a click on the projected corner arms the vertical, not a top line.
	await _arm(main, body)
	await _tap(main, KEY_3)
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet is armed")
	var corner := _top_of(view, body, verts[0])
	var cs := FilmUI.model_to_screen(ctx, corner)
	var inward := (FilmUI.model_to_screen(ctx, centre) - cs).normalized() * 3.0
	await _push_click(cs + inward)
	check(view.selected_edges.size() == 1 and verts.has(str(view.selected_edges[0])),
			"Top-view corner click arms a vertical edge (edges %s)" % str(view.selected_edges))
	check(_st(main).contains("10.0 mm vertical"), "status names `10.0 mm vertical` (got `%s`)" % _st(main))

	# 2. Iso: a wall click far from any edge while armed keeps the set and says why.
	await _tap(main, KEY_1)
	var armed_before: Array = view.selected_edges.duplicate()
	var first_armed := str(armed_before[0]) if armed_before.size() > 0 else ""
	# Wall interior: middle of the −Y wall, found by a ray through the screen centre of that wall.
	var wall_mid := Vector3(centre.x, bb["min"].y, centre.z)
	var ws := FilmUI.model_to_screen(ctx, wall_mid)
	var on_screen := FilmUI.is_on_screen(ctx, ws)
	check(on_screen, "−Y wall centre is on screen (%s)" % str(ws))
	await _push_click(ws)
	check(view.selected_edges.size() == armed_before.size() and view.selected_edges.has(first_armed),
			"a face click far from every edge keeps the armed set (edges %s)" % str(view.selected_edges))
	check(_st(main).contains("No edge near click"), "refusal is named (got `%s`)" % _st(main))

	# 3. A face click within 14 px of another edge adds that edge and keeps the first.
	var other: String = ""
	for v in verts:
		if v != first_armed:
			var s := FilmUI.model_to_screen(ctx, _mid_of(view, body, v))
			if FilmUI.is_on_screen(ctx, s) and absf(_mid_of(view, body, v).y - bb["min"].y) < 0.5:
				other = v
				break
	check(other != "", "found another vertical on the −Y wall")
	if other != "":
		var os := FilmUI.model_to_screen(ctx, _mid_of(view, body, other))
		await _push_click(os + Vector2(6.0, 0.0) * (1.0 if os.x < ws.x else -1.0))
		check(view.selected_edges.size() == 2 and view.selected_edges.has(first_armed)
				and view.selected_edges.has(other),
				"a wall click within 14 px of a second vertical adds it and keeps the first (edges %s)" % str(view.selected_edges))

		# 4. A press off the solid keeps the set and the panel; a silhouette edge within 10 px is toggled.
		var set_before: Array = view.selected_edges.duplicate()
		var empty := Vector2(60.0, 700.0)
		await _push_click(empty)
		check(view.selected_edges.size() == set_before.size(), "an empty press keeps both edges (edges %s)" % str(view.selected_edges))
		check(ops.visible, "an empty press keeps the ops panel visible")
		check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "an empty press keeps Fillet armed")
		check(_st(main).contains("Missed the solid"), "a real miss is named (got `%s`)" % _st(main))

		# 5. Remove an edge: the status names its length and kind.
		await _push_click(FilmUI.model_to_screen(ctx, _mid_of(view, body, other)) + Vector2(2.0, 0.0))
		check(_st(main).contains("removed 10.0 mm vertical") or _st(main).contains("removed"),
				"re-click status names the removed edge (got `%s`)" % _st(main))
		check(_st(main).contains("removed 10.0 mm"), "the removed edge has its length (got `%s`)" % _st(main))
		await _push_click(FilmUI.model_to_screen(ctx, _mid_of(view, body, other)) + Vector2(2.0, 0.0))
		check(view.selected_edges.size() == 2, "the edge is back in the set (%d)" % view.selected_edges.size())

		# 6. Enter applies both and the applied text stays in the status bar.
		var before_fillets := _fillet_count(view)
		await _push_key(KEY_ENTER)
		check(_fillet_count(view) == before_fillets + 1, "Enter adds one fillet feature (%d → %d)" % [before_fillets, _fillet_count(view)])
		check(_st(main).begins_with("Fillet 2 edges 1.00 applied"), "status is `Fillet 2 edges 1.00 applied …` (got `%s`)" % _st(main))
		check(not _st(main).contains("Feature created"), "the applied text is not overwritten by `Feature created`")

	# 7. A press just off a silhouette edge picks it (within 10 px), and from nothing armed a face click still takes the face.
	var body2: String = view.insert_primitive("box", Vector3(100, 0, 0), Vector3(20, 20, 10))
	await process_frame
	var bb2: Dictionary = view.doc.measure_bbox(body2)
	var centre2: Vector3 = (bb2["min"] + bb2["max"]) * 0.5
	await _arm(main, body2)
	await _tap(main, KEY_1)
	var right_edge := ""
	var right_x := -INF
	for v in _vertical_edges(view, body2):
		var sx := FilmUI.model_to_screen(ctx, _mid_of(view, body2, v)).x
		if sx > right_x:
			right_x = sx
			right_edge = v
	var sil := FilmUI.model_to_screen(ctx, _mid_of(view, body2, right_edge)) + Vector2(5.0, 0.0)
	await _push_click(sil)
	check(view.selected_edges.size() == 1 and view.selected_edges.has(right_edge),
			"a press 5 px off the silhouette picks that edge (edges %s)" % str(view.selected_edges))
	ops.cancel_pending_pick()
	view.clear_selection()
	await _arm(main, body2)
	await _tap(main, KEY_1)
	var face_pt := Vector3(centre2.x, bb2["min"].y, centre2.z)
	await _push_click(FilmUI.model_to_screen(ctx, face_pt))
	check(view.selected_edges.size() == 4, "with nothing armed a face click takes the face's 4 edges (got %d)" % view.selected_edges.size())

	# 8. An edge hidden behind a wall is never snapped to from the camera side.
	view.clear_selection()
	await _tap(main, KEY_7)
	var cam: Camera3D = main.camera.get_node("Camera3D") if main.camera.has_node("Camera3D") else get_root().get_camera_3d()
	var far_edge := ""
	var far_d := -INF
	for v in _vertical_edges(view, body2):
		var d: float = (view.to_global(_mid_of(view, body2, v)) - cam.global_position).length()
		if d > far_d:
			far_d = d
			far_edge = v
	var snapped := ""
	if view.has_method("edge_near_screen") and view.has_method("model_to_screen"):
		var hidden_screen: Vector2 = view.call("model_to_screen", cam, _mid_of(view, body2, far_edge))
		snapped = str(view.call("edge_near_screen", body2, cam, hidden_screen, 14.0))
	check(view.has_method("edge_near_screen") and snapped != far_edge,
			"the far vertical edge hidden behind the box is not snapped to")

	# 9. Esc ends an armed fillet and its edge set in one press; the body stays selected.
	ops.cancel_pending_pick()
	await _arm(main, body2)
	await _tap(main, KEY_3)
	var esc_corner := FilmUI.model_to_screen(ctx, _top_of(view, body2, _vertical_edges(view, body2)[0]))
	var esc_in := (FilmUI.model_to_screen(ctx, centre2) - esc_corner).normalized() * 3.0
	await _push_click(esc_corner + esc_in)
	check(view.selected_edges.size() >= 1, "an edge is armed before Esc (%d)" % view.selected_edges.size())
	await _push_key(KEY_ESCAPE)
	check(ops._pending == OpsPanel.Pending.NONE, "one real Esc ends the armed fillet")
	check(view.selected_edges.is_empty() and view.selected_edge == "", "Esc drops the picked edges")
	check(view.selected_body == body2, "Esc keeps the body selected")
	check(_st(main).contains("Edge pick cancelled"), "status says the pick was cancelled (got `%s`)" % _st(main))

	main.queue_free()
	await process_frame
	await process_frame
```

## Commands and expected output

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_pick.gd
#   27 checks, 0 failures
for t in run_rung01_replan11_fillet_ui run_rung01_replan11_fillet_err run_rung01_replan6_cut run_rung01_replan10_esc run_rung01_replan11_esc run_critic_walk_tests run_infer_tests; do
  timeout 120 tools/godot/godot --headless --path game --script res://tests/$t.gd | tail -2
done
```

Counts must equal the whole-suite table (`replan11_fillet_ui`, `replan11_fillet_err`, `replan6_cut` 100/0, `critic_walk` 46/0, `infer` 44/0).

**Red on `2606160c`:** `27 checks, 16 failures` (corner pick arms nothing from Top, face click replaces the set, a miss is not named and the set is lost, `— removed` has no length, Enter ends as `Card text saved`, no silhouette pick, Esc leaves Fillet armed). `grep -rn "Feature created" game/tests` finds no assertion, so changing the text breaks no existing test.

## Do not

- Raise the 14 px or 10 px limits, or drop the occlusion test (the test fails when `_edge_point_visible` is disabled; verified).
- Touch the Hole Wizard, Shell or Thicken pick paths: they share `consumes_viewport_pick()` and must behave as before.
- Change `edge_near_point`'s model-space signature beyond the optional camera argument shown in the diff.
