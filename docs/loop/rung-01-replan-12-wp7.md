# Replan 12 WP7 — the walk, lint, Makefile and the thick checker row (merges last)

You are a BUILD agent. **Start only after WP1–WP6 are merged into `main`** (the walk calls `graph_warnings()`, `_label_px_scale`, `_dimension_label_rect`, the rail fix, the Esc rung and the pick path). Edit only the four files below.

| File | Change |
|---|---|
| `game/tests/run_rung01_wrench.gd` | 413 → 456 checks: rail click probe, Save As inside the sketch, label glyph clicks, human fillet picks, Esc ends the pick, timeline panel dismiss, thick-fillet probes, `6/6` |
| `tools/lint_rung01_e2e.py` | new `_lint_replan12`, called from `main()`; prints `7 replan12 scripts are clean` |
| `Makefile` | `test-godot` runs `game/tests/run_rung01_replan12_*.gd` |
| `tools/check_rung01.py` | one new `thick` row: `1mm top fillet at new T` |

Nothing else changes. No product code. No `.gd.uid` files in the commit.

## Decisions (see `rung-01-replan-12.md` 11, 17 and 18)

- The walk stays real input only: `_aim_pointer` + `_pointer_click` (X11), `_push_key` for keys and Esc. No `select_entity`, `set_view(`, `.yaw =`, `.pitch =`, `_look_along`, `.basis =` or window-size literals. `tools/lint_rung01_e2e.py` already enforces this on the walk and now on the seven new suites.
- Label clicks hit the **first** glyph of the width label and the **last** glyph of the angle label, computed from the same rectangle the product draws (`_label_glyph_screen`).
- Fillet picks: Top corner, Back wall click, press off the solid, then Esc; two Esc presses are allowed because the first can release a focused radius field (`_esc_ends_pick`), a third is a failure.
- The thick row is the only checker change: `1mm top fillet at new T` asserts the point `(-9.9, 0.0, T - 0.1)` is outside the mesh (the R1 top fillet at the outer end survives the thickness edit). It does not touch any other row or tolerance.
- `_triball_one_esc` no longer calls `cancel_property_panel()` from script; it asserts the panel is already closed (WP5 closes it).

## Diff — walk (measured; apply by function name)

```diff
diff --git a/game/tests/run_rung01_wrench.gd b/game/tests/run_rung01_wrench.gd
index 2670fae..4dcf21c 100644
--- a/game/tests/run_rung01_wrench.gd
+++ b/game/tests/run_rung01_wrench.gd
@@ -283,6 +283,7 @@ func _walk(ctx: FilmContext) -> Dictionary:
 	await _sketch_on_top(ctx, body, top, 10.0, false)
 	sm = ctx.main.sketch_mode
 	await _zoom_uv(ctx, Vector2.ZERO, 40.0)
+	await _rail_click_probe(ctx)
 	await _place_hole_circle(ctx)
 	await _zoom_uv(ctx, Vector2(200, 0), 120.0)
 	print("  B2.8 redraw Ø45 at the head as a sketch circle")
@@ -297,6 +298,7 @@ func _walk(ctx: FilmContext) -> Dictionary:
 	check(absf(head_r - 22.5) <= 0.05, "jaw sketch has Ø45 at the head (r=%.4f)" % head_r)
 	await _draw_centre_rect(ctx, Vector2(200, 0))
 	await _edit_rect_labels(ctx)
+	await _save_as_in_sketch(ctx)
 	var first_miss := 12.0
 	check(first_miss > 0.15 * 22.5, "offset cutter misses the Ø45 15% gate")
 	check(first_miss < 0.9 * 22.5, "offset cutter still crosses the Ø45 disc inside the 90% rim limit")
@@ -398,6 +400,7 @@ func _walk(ctx: FilmContext) -> Dictionary:
 
 	print("- fillets: neck R10, faces R1, slot floor R1.5 refused")
 	var far_x := 200.0 - sqrt(22.5 * 22.5 - 10.0 * 10.0)
+	await _human_fillet_picks(ctx, body, far_x)
 	await _fillet_neck(ctx, body, far_x)
 	await _fillet_face(ctx, body, Vector3(0, 0, 1), Vector3(200, -16, 10), 1.0, "top face")
 	await _fillet_face(ctx, body, Vector3(0, 0, -1), Vector3(50, 0, 0), 1.0, "bottom face")
@@ -416,11 +419,18 @@ func _walk(ctx: FilmContext) -> Dictionary:
 	check(boss != "", "base extrude is on the timeline")
 	if boss != "":
 		await _type_timeline_distance(ctx, boss, "14")
+		await _timeline_panel_dismiss(ctx, boss)
 	var thick_bb: Dictionary = ctx.view.doc.measure_bbox(body)
 	var thick_ext: Vector3 = thick_bb["max"] - thick_bb["min"]
 	check(absf(thick_ext.z - 14.0) <= TOL, "thick bbox Z is 14 (got %.3f)" % thick_ext.z)
 	var thick_mesh := _load_mesh(ctx.view.doc, body)
 	check(not _inside(thick_mesh, Vector3(93.5, 0, 12.75)), "thick slot is open at z=12.75")
+	check(not _inside(thick_mesh, Vector3(thick_bb["min"].x + 0.1, 0, 13.9)),
+			"top R1 fillet survives T=14 (corner at z=13.9 is cut away)")
+	check(_inside(thick_mesh, Vector3(93.5, 4.9, 11.6)),
+			"slot-floor R1 fillet survives T=14 (corner material at z=11.6)")
+	check(str(ctx.view.doc.graph_warnings()).find("lost on rebuild") < 0,
+			"T=14 rebuild reports no lost fillet edges (%s)" % str(ctx.view.doc.graph_warnings()))
 	var thick_path := await _export_via_dialog(ctx, "wrench-t14.3mf")
 	check(thick_path != "" and FileAccess.file_exists(thick_path), "exported wrench-t14.3mf through the dialog")
 	return {
@@ -452,7 +462,7 @@ func _checker(checker: String, args: Array) -> void:
 	print(text)
 	check(code == 0, "check_rung01.py %s exit %d" % [" ".join(args), code])
 	if str(args[0]) == "thick":
-		check(text.contains("5/5"), "thick checker prints 5/5")
+		check(text.contains("6/6"), "thick checker prints 6/6")
 
 
 func _assert_timeline(ctx: FilmContext) -> void:
@@ -626,10 +636,7 @@ func _triball_one_esc(ctx: FilmContext) -> void:
 	var sm: SketchMode = ctx.main.sketch_mode
 	if sm != null and sm.active:
 		await FilmUI.exit_sketch(ctx)
-	# The thickness edit leaves the timeline property panel up. That layer
-	# owns Esc; dismiss it so this key is the TriBall cancel.
-	if ctx.main.has_method("cancel_property_panel"):
-		ctx.main.cancel_property_panel()
+	check(not ctx.main.timeline.property_panel.visible, "no timeline panel is left open before TriBall")
 	await process_frame
 	await _ensure_body_selected(ctx, body)
 	check(ctx.main.sketch_mode == null or not ctx.main.sketch_mode.active,
@@ -756,6 +763,126 @@ func _refuse_slot_floor(ctx: FilmContext, body: String) -> void:
 	_slot_floor_refused = _count_type(ctx, "fillet") == before and _slot_floor_error != ""
 	check(absf(ctx.view.doc.body_volume(body) - vol0) < 1e-3, "body unchanged after refused fillet")
 	print("  slot floor refusal: " + _slot_floor_error)
+	await _esc_ends_pick(ctx)
+
+
+func _rail_click_probe(ctx: FilmContext) -> void:
+	print("- a sketch click 30 px right of the left rail lands on the canvas")
+	var sm: SketchMode = ctx.main.sketch_mode
+	var rail: Control = ctx.main.sketch_toolbar
+	check(rail != null and rail.is_visible_in_tree(), "sketch rail is visible")
+	if rail == null:
+		return
+	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
+	var size: Vector2 = ctx.main.get_viewport().get_visible_rect().size
+	var pos := Vector2(rail.get_global_rect().end.x + 30.0, size.y * 0.5)
+	await _aim_pointer(ctx, pos)
+	check(ctx.main.get_viewport().gui_get_hovered_control() == ctx.main.interaction,
+			"the control under the pointer next to the rail is the viewport (got %s)" % str(
+			ctx.main.get_viewport().gui_get_hovered_control()))
+	await _pointer_click(ctx, pos, false)
+	await process_frame
+	check(sm.has_pending_draw_point(), "a Circle click next to the rail starts a circle")
+	await _real_esc(ctx)
+	check(not sm.has_pending_draw_point() and sm.active, "Esc drops that first point and keeps the sketch")
+	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.SELECT)
+
+
+func _save_as_in_sketch(ctx: FilmContext) -> void:
+	print("- File → Save As inside the sketch keeps the session")
+	var sm: SketchMode = ctx.main.sketch_mode
+	check(sm.active, "jaw sketch is open before Save As")
+	var entities: int = sm.sketch.entity_ids().size()
+	var path := "/tmp/sx-rung01-jaw-saveas.sxp"
+	if FileAccess.file_exists(path):
+		DirAccess.remove_absolute(path)
+	var opened: bool = await _click_menu_item(ctx, "File", 3, "File → Save As")
+	await process_frame
+	await process_frame
+	var dlg: FileDialog = ctx.main.file_dialog
+	check(opened and dlg != null and dlg.visible, "Save As opens a FileDialog")
+	if dlg == null or not dlg.visible:
+		return
+	check(str(dlg.current_file).ends_with(".sxp"), "Save As suggests an .sxp name (got %s)" % dlg.current_file)
+	for _i in 4:
+		await process_frame
+	await _type_export_name(dlg, path)
+	var ok_btn := dlg.get_ok_button()
+	if ok_btn != null:
+		await _x11_click_embedded(ok_btn)
+		await process_frame
+		await process_frame
+		await process_frame
+	check(FileAccess.file_exists(path), "Save As wrote %s" % path)
+	check(sm.active and ctx.main.sketch_chrome.visible, "the sketch session is still open after Save As")
+	check(sm.sketch.entity_ids().size() == entities,
+			"the sketch kept its %d entities (got %d)" % [entities, sm.sketch.entity_ids().size()])
+	check(sm.tool == SketchMode.Tool.SELECT, "tool is Select after Save As")
+	check(str(ctx.main.status_label.text).begins_with("Saved "),
+			"status reads Saved <path> (got %s)" % ctx.main.status_label.text)
+	var saved := SxDocument.new()
+	var has_sketch := false
+	if saved.load(path):
+		for f in saved.graph_features():
+			if str(f.get("type", "")) == "sketch":
+				has_sketch = true
+	check(has_sketch, "the saved file contains the sketch")
+	if dlg.visible:
+		dlg.hide()
+
+
+func _real_esc(ctx: FilmContext) -> void:
+	await _push_key(ctx.main.get_viewport(), KEY_ESCAPE, 0)
+	await process_frame
+
+
+func _walk_empty_pixel(ctx: FilmContext) -> Vector2:
+	var size: Vector2 = ctx.main.get_viewport().get_visible_rect().size
+	for f in [Vector2(0.9, 0.19), Vector2(0.86, 0.75), Vector2(0.7, 0.15), Vector2(0.55, 0.81)]:
+		var p: Vector2 = f * size
+		var ray: Array = ctx.main.interaction._model_ray(p)
+		if ctx.view.pick_info(ray[0], ray[1]).is_empty():
+			return p
+	return Vector2.INF
+
+
+func _human_fillet_picks(ctx: FilmContext, body: String, neck_x: float) -> void:
+	print("- fillet picks as a human: Top corner, wall click, press off the solid, Esc")
+	await _ensure_body_selected(ctx, body)
+	await _arm_fillet(ctx, 10.0)
+	await _view_key(ctx, KEY_3)
+	await _click_model(ctx, Vector3(neck_x - 0.3, 9.7, 10.0), "Top-view neck corner")
+	check(ctx.view.selected_edges.size() == 1, "Top-view corner click arms one edge (got %d)" % ctx.view.selected_edges.size())
+	check(str(ctx.main.status_label.text).contains("mm vertical"),
+			"Top-view corner arms the vertical (got %s)" % ctx.main.status_label.text)
+	var first: Array = ctx.view.selected_edges.duplicate()
+	await _view_key(ctx, KEY_4)
+	await _click_model(ctx, Vector3(100, 10, 5), "Back wall")
+	check(not first.is_empty() and ctx.view.selected_edges.has(first[0])
+			and ctx.view.selected_edges.size() <= first.size() + 1,
+			"a wall click keeps the earlier pick (got %d)" % ctx.view.selected_edges.size())
+	var after_wall: int = ctx.view.selected_edges.size()
+	var empty := _walk_empty_pixel(ctx)
+	check(empty != Vector2.INF, "found a pixel off the solid")
+	if empty != Vector2.INF:
+		await _aim_pointer(ctx, empty)
+		await _pointer_click(ctx, empty, false)
+		check(ctx.view.selected_edges.size() == after_wall,
+				"a press off the solid keeps the set (got %d)" % ctx.view.selected_edges.size())
+		check(str(ctx.main.status_label.text).contains("Missed the solid"),
+				"the miss is named (got %s)" % ctx.main.status_label.text)
+	await _esc_ends_pick(ctx)
+
+
+## One Esc releases a focused radius field, the next ends the armed pick. A person
+## presses Esc until the strip is quiet, so allow two and fail on a third.
+func _esc_ends_pick(ctx: FilmContext) -> void:
+	var presses := 0
+	while ctx.main.ops_panel._pending != OpsPanel.Pending.NONE and presses < 3:
+		await _real_esc(ctx)
+		presses += 1
+	check(ctx.main.ops_panel._pending == OpsPanel.Pending.NONE and presses <= 2,
+			"real Esc ends the armed fillet within two presses (%d)" % presses)
 
 
 func _arm_fillet(ctx: FilmContext, radius: float) -> void:
@@ -1106,6 +1233,25 @@ func _type_timeline_distance(ctx: FilmContext, fid: String, digits: String) -> v
 	check(absf(got - float(digits)) < 0.05, "base extrude distance is %.3f" % got)
 
 
+func _timeline_panel_dismiss(ctx: FilmContext, boss: String) -> void:
+	print("- timeline panel: Esc cancels the preview, an empty click keeps it")
+	var panel = ctx.main.timeline.property_panel
+	check(panel.visible, "the Distance panel is open with the focused field")
+	await _real_esc(ctx)
+	check(not panel.visible, "one real Esc closes the Distance panel")
+	check(absf(_feature_distance(ctx, boss) - 10.0) < 0.05,
+			"Esc cancelled the previewed 14 (distance %.3f)" % _feature_distance(ctx, boss))
+	await _type_timeline_distance(ctx, boss, "14")
+	var empty := _walk_empty_pixel(ctx)
+	check(empty != Vector2.INF, "found a pixel off the solid for the click-away")
+	if empty != Vector2.INF:
+		await _aim_pointer(ctx, empty)
+		await _pointer_click(ctx, empty, false)
+	check(not panel.visible, "one empty-viewport click closes the Distance panel")
+	check(absf(_feature_distance(ctx, boss) - 14.0) < 0.05,
+			"the click-away keeps 14 (distance %.3f)" % _feature_distance(ctx, boss))
+
+
 func _boss_extrude_id(ctx: FilmContext) -> String:
 	for f in ctx.view.doc.graph_features():
 		if str(f.get("type", "")) != "extrude":
@@ -2562,7 +2708,7 @@ func _edit_rect_labels(ctx: FilmContext) -> void:
 	var ang_i := _dim_index(sm, "angle")
 	check(ang_i >= 0, "jaw angle label exists")
 	if ang_i >= 0:
-		await _edit_label(ctx, ang_i, "45")
+		await _edit_label(ctx, ang_i, "45", "last")
 	width_i = _dim_index_near(sm, "distance", 20.0)
 	ang_i = _dim_index(sm, "angle")
 	var width_shown := -1.0
@@ -2601,23 +2747,45 @@ func _edit_rect_labels(ctx: FilmContext) -> void:
 			"jaw floor is perpendicular to the wall")
 
 
-func _edit_label(ctx: FilmContext, index: int, text: String) -> void:
+func _edit_label(ctx: FilmContext, index: int, text: String, glyph: String = "first") -> void:
 	var sm: SketchMode = ctx.main.sketch_mode
 	var lp: Variant = sm._dimension_label_pos2(sm.dimensions[index])
 	check(lp != null, "dimension label has a position")
 	if lp == null:
 		return
 	await _zoom_uv(ctx, lp as Vector2, 50.0)
-	await _click_uv(ctx, lp as Vector2, "Edit dimension label")
+	var screen := _label_glyph_screen(ctx, index, glyph)
+	check(FilmUI.require_on_screen(ctx, screen, "label %s glyph" % glyph),
+			"label %s glyph is on screen" % glyph)
+	await _aim_pointer(ctx, screen)
+	await _pointer_click(ctx, screen, false)
 	await process_frame
 	await process_frame
 	var ix = ctx.main.interaction
-	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible, "dimension editor opened")
+	check(ix._dim_edit_popup != null and ix._dim_edit_popup.visible,
+			"one click on the %s glyph opens the dimension editor" % glyph)
 	if ix._dim_edit_popup == null or not ix._dim_edit_popup.visible:
 		return
 	await _type_popup(ctx, ix._dim_edit_line, text)
 
 
+## Screen centre of the first or last drawn glyph of a dimension label (never its centre).
+func _label_glyph_screen(ctx: FilmContext, index: int, glyph: String) -> Vector2:
+	var sm: SketchMode = ctx.main.sketch_mode
+	var cam: Camera3D = ctx.main.get_viewport().get_camera_3d()
+	var dim: Dictionary = sm.dimensions[index]
+	var lp: Variant = dim.get("label_pos", null)
+	if lp == null:
+		lp = sm._dimension_label_pos2(dim)
+	var anchor := FilmUI.model_to_screen(ctx, sm.to_model(lp as Vector2))
+	var k: float = sm._label_px_scale(cam)
+	var rect: Rect2 = sm._dimension_label_rect(dim, anchor, k)
+	var text := str(dim.get("label_text", sm._dimension_label_text(dim)))
+	var one: Vector2 = sm._dimension_label_size_px(text.substr(0, 1) if glyph == "first" else text.substr(text.length() - 1)) * k
+	var x := rect.position.x + one.x * 0.5 if glyph == "first" else rect.end.x - one.x * 0.5
+	return Vector2(x, rect.get_center().y)
+
+
 func _power_trim_shaft_click(ctx: FilmContext) -> void:
 	var sm: SketchMode = ctx.main.sketch_mode
 	var click_uv := HEAD + JAW * 3.0 + PERP * 8.0
```

## Diff — lint, Makefile, checker

```diff
diff --git a/Makefile b/Makefile
index 5a60b0c..737bd91 100644
--- a/Makefile
+++ b/Makefile
@@ -144,6 +144,10 @@ test-godot: build import preflight
 		[ -e "$$f" ] || continue; \
 		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
 	done
+	@for f in game/tests/run_rung01_replan12_*.gd; do \
+		[ -e "$$f" ] || continue; \
+		$(GODOT) --headless --path game --script tests/$$(basename $$f) || exit 1; \
+	done
 
 lint-rung01-e2e:
 	python3 tools/lint_rung01_e2e.py
diff --git a/tools/check_rung01.py b/tools/check_rung01.py
index 26deb08..85ef785 100644
--- a/tools/check_rung01.py
+++ b/tools/check_rung01.py
@@ -204,6 +204,7 @@ def main():
         r.add('grip slot open from the top', slot_ok,
               '' if slot_ok else f'xm={xm} floor={floor}',
               'open at z=T-1.25, floor T-2.5, solid skin absent at z=T-0.5')
+        r.add('1mm top fillet at new T', not inside(tr, (-9.9, 0.0, T_ - 0.1)), '', 'outside')
         r.show(); sys.exit(1 if r.fail else 0)
     if kind == 'nut':
         e = sorted(ext[:2])
diff --git a/tools/lint_rung01_e2e.py b/tools/lint_rung01_e2e.py
index b134225..00fe6d2 100644
--- a/tools/lint_rung01_e2e.py
+++ b/tools/lint_rung01_e2e.py
@@ -468,6 +468,19 @@ def _lint_replan11(errors: list[str]) -> None:
         _lint_current_dir_assignment(src, errors, prefix)
 
 
+def _lint_replan12(errors: list[str]) -> None:
+    paths = sorted(TESTS.glob("run_rung01_replan12_*.gd"))
+    if len(paths) != 7:
+        errors.append("expected 7 run_rung01_replan12_*.gd")
+    for path in paths:
+        src = path.read_text(encoding="utf-8")
+        prefix = f"{path.relative_to(ROOT)}:"
+        # These are validation suites: script-side setup (insert_primitive,
+        # select_entity to arm) is allowed, but the pointer and camera paths
+        # under test must be real keys and events.
+        _lint_replan11_camera(src, errors, prefix)
+
+
 def main() -> int:
     if not WALK.is_file():
         print(f"lint_rung01_e2e: missing {WALK}", file=sys.stderr)
@@ -484,6 +497,7 @@ def main() -> int:
     _lint_replan9(errors)
     _lint_replan10(errors)
     _lint_replan11(errors)
+    _lint_replan12(errors)
 
     if errors:
         print("lint_rung01_e2e: GUI shortcuts remain:", file=sys.stderr)
@@ -509,6 +523,8 @@ def main() -> int:
     print(f"lint_rung01_e2e: {n9} replan9 scripts are clean")
     print(f"lint_rung01_e2e: {n10} replan10 scripts are clean")
     print(f"lint_rung01_e2e: {n11} replan11 scripts are clean")
+    n12 = len(list(TESTS.glob("run_rung01_replan12_*.gd")))
+    print(f"lint_rung01_e2e: {n12} replan12 scripts are clean")
     return 0
 
 
```

## Commands and expected output

```
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
python3 tools/lint_rung01_e2e.py
#   lint_rung01_e2e: 7 replan12 scripts are clean        (last line)
python3 tools/test_check_rung01.py
#   Ran 4 tests ... OK
DISPLAY=:1 timeout 900 tools/godot/godot --path game --script res://tests/run_rung01_wrench.gd 2>&1 | tee /tmp/walk.log | tail -5
#   456 checks, 0 failures
python3 tools/check_rung01.py wrench <wrench.3mf from the walk>     # 28/28
python3 tools/check_rung01.py thick <wrench-t14.3mf> 14             # 6/6
python3 tools/check_rung01.py blank <blank.3mf>                     # 5/5
python3 tools/check_rung01.py nut <nut.3mf>                         # 7/7
```

The walk needs `DISPLAY=:1` (it clicks through X11, not headless). It prints the checker lines itself; the thick export has about 5760 triangles. Run it alone: it is the slowest suite and flakes under load.

**Red on `2606160c` product code with the new walk:** the process aborts with `handle_crash: Program crashed with signal 11` after 331 `ok` lines and 21 `FAIL` lines. The FAILs are the plan's evidence: `the control under the pointer next to the rail is the viewport (got LeftStack…)`, `label first glyph is on screen`, `one click on the first glyph opens the dimension editor` (x3), `Save As suggests an .sxp name (got nut.3mf)`, `the sketch session is still open after Save As`, `Top-view corner arms the vertical (got … 179.8 mm line …)`, `a press off the solid keeps the set (got 0)`, `real Esc ends the armed fillet within two presses (3)`, and then the neck fillet fails inside `BRepFilletAPI_MakeFillet::NbEdges` (WP1 guard).

**Checker evidence with all WPs applied:** wrench 28/28, thick 6/6 (including the new row), nut 7/7, blank 5/5; `wrench-t14.3mf` has 5760 triangles (2438 on `2606160c`, which means every fillet was lost).

## Whole-suite run

Run the full table in `rung-01-replan-12.md` ("Whole-suite check") after this WP. Every row must equal the "After all WPs" column. Do not edit any pre-existing-failure suite.

## Do not

- Add `select_entity`, a test-only camera, or a hard-coded window size to the walk.
- Change any other checker row, formula or tolerance.
- Weaken a check to make the walk green: a failure means a product WP is incomplete; report which WP.
- Commit `game/tests/*.gd.uid`.
