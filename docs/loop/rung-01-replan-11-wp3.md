# Replan 11 WP3 — fillet deselect, face-first, refusal text

You are a BUILD agent. Edit only `game/scripts/ops_panel.gd` and add `game/tests/run_rung01_replan11_fillet_ui.gd`.

**Merge WP2 first.** This test reads `last_graph_error()` from the kernel strings WP2 emits (`fillet failed (limit 5.000; 10.000 mm line at (x, y, z))` and `fillet failed (32.200 mm arc at (x, y, z))`). On a tree without WP2 the limit row fails the `mm` assertion.

Do not edit `ops_dress.cpp`. Do not change `_fillet_all` or `_round_targets`. The Modify-card Fillet button still fillets every edge of a body when the user presses that button with no edges selected. A viewport click must not arm Fillet.

## Decisions already made

- Order dependency is status text only. No automatic second fillet. See plan decision 1.
- Body clicks do not arm. Add a guard anyway. See plan decision 14.

## 1. Guard

At the top of `_accumulate_dressup_edge` (line 1947), after the empty-body return:

```gdscript
if _pending != Pending.FILLET_EDGES and _pending != Pending.CHAMFER_EDGES:
	return
```

## 2. Re-click removes

Replace the `if view.selected_edges.has(edge): pass` block (lines 1967-1968) with:

```gdscript
if view.selected_edges.has(edge) or view.selected_edge == edge:
	view.selected_edges.erase(edge)
	if view.selected_edge == edge:
		view.selected_edge = str(view.selected_edges[0]) if not view.selected_edges.is_empty() else ""
	if view.selected_edges.is_empty():
		view.selected_edge = ""
	view._highlight_edge()
	view.selection_changed.emit(view.selected_body, view.selected_face)
	status.emit(_dressup_pick_status() + " — removed")
	return
```

The add path below it stays. Both the add path and `_add_dressup_face` end by emitting `_dressup_pick_status()` instead of the old `"%s: %d edge(s) — click more..."` sentence.

## 3. Status lists length and kind

```gdscript
func _edge_length_kind(body: String, edge_id: String) -> String:
	var length := float(view.doc.measure_edge_length(edge_id))
	var dir := view.edge_direction(body, edge_id)
	var kind := "line"
	if absf(dir.z) >= 0.95 and absf(dir.x) < 0.2 and absf(dir.y) < 0.2:
		kind = "vertical"
	elif dir == Vector3.ZERO:
		kind = "line"
	else:
		var pts: PackedVector3Array = view.doc.get_edge_lines(body).get(edge_id, PackedVector3Array())
		if pts.size() >= 2:
			var chord: float = pts[0].distance_to(pts[pts.size() - 1])
			if length > 0.5 and chord < length * 0.95:
				kind = "arc"
	return "%.1f mm %s" % [length, kind]


func _dressup_pick_status() -> String:
	var kind := "Fillet" if _pending == Pending.FILLET_EDGES else "Chamfer"
	var ids: Array = []
	for e in view.selected_edges:
		ids.append(str(e))
	if ids.is_empty() and view.selected_edge != "":
		ids.append(view.selected_edge)
	var parts: PackedStringArray = PackedStringArray()
	for id in ids:
		parts.append(_edge_length_kind(view.selected_body, str(id)))
	var listed := ", ".join(parts)
	if listed == "":
		listed = "none"
	return "%s: %d edge(s) — %s — click more, Enter to apply, Esc cancel" % [kind, ids.size(), listed]
```

Example: `Fillet: 2 edge(s) — 10.0 mm vertical, 10.0 mm vertical — click more, Enter to apply, Esc cancel`.

## 4. Face first, then Enter

`_commit_armed_dressup` (line 834). When there are no edges, expand a selected face before cancelling:

```gdscript
func _commit_armed_dressup() -> bool:
	var fillet := _pending == Pending.FILLET_EDGES
	if view.selected_edges.is_empty() and view.selected_edge == "":
		if view.selected_face != "":
			_add_dressup_face(view.selected_body, view.selected_face)
		if view.selected_edges.is_empty() and view.selected_edge == "":
			_pending = Pending.NONE
			dressup_armed_changed.emit(false, fillet)
			if view.selected_face == "":
				status.emit("No edges selected — cancelled")
			return false
	_apply_dressup(fillet)
	return _pending == Pending.NONE
```

`_add_dressup_face` already emits its own "no edges" status when the face has none. Do not emit `No edges selected` in that case.

`_start_or_apply_dressup` (line 825): if no edges but `view.selected_face != ""`, call `_add_dressup_face` and then `_apply_dressup` instead of only arming.

`arm_or_apply_fillet`: when already pending, call `try_commit_pending()` even if the edge list is empty (the face expansion is inside the commit). Same for chamfer.

Set `var _dressup_from_face := false` next to the other pending fields. `_add_dressup_face` sets it true. `_accumulate_dressup_edge` sets it false when it adds or removes a single edge. `_apply_dressup` reads it for the refusal sentence and clears it on success.

## 5. Refusal text

Replace the failure branch of `_apply_dressup` (lines 885-893) for fillets. Chamfer keeps the old sentence.

```gdscript
else:
	if fillet:
		status.emit(_fillet_refusal_status(value, targets.size()))
	else:
		status.emit("%s r=%.2f too large for selected edge(s) — reduce Radius, Enter again" % [name, value])
	_pending = Pending.FILLET_EDGES if fillet else Pending.CHAMFER_EDGES
	_pending_body = view.selected_body
	_pending_fid = view.feature_of_body(view.selected_body)
	dressup_armed_changed.emit(true, fillet)
	_reveal_radius(fillet)
```

```gdscript
func _fillet_refusal_status(radius: float, n: int) -> String:
	var why := ""
	if view.doc.has_method("last_graph_error"):
		why = str(view.doc.last_graph_error())
	if why.contains("limit "):
		var num := _first_number_after(why, "limit ")
		var edge := _first_mm_kind(why)
		var by := "the %s edge" % edge if edge != "" else "an edge in the selection"
		return "Fillet r=%.2f exceeds the %s mm limit set by %s — click it again to remove it, or reduce Radius" % [radius, num, by]
	var fault := _fault_phrase(why)
	var mid := " (%s)" % fault if fault != "" else ""
	return "Fillet could not be built on %d edge(s)%s — fillet the R10 neck first, or pick fewer edges" % [n, mid]


func _first_number_after(why: String, marker: String) -> String:
	var i := why.find(marker)
	if i < 0:
		return ""
	var rest := why.substr(i + marker.length())
	var num := ""
	for ch in rest:
		if (ch >= "0" and ch <= "9") or ch == ".":
			num += ch
		else:
			break
	return num


func _first_mm_kind(why: String) -> String:
	var re := RegEx.new()
	re.compile("(\\d+\\.\\d+ mm [a-z]+)")
	var m := re.search(why)
	return "" if m == null else m.get_string(1)


func _fault_phrase(why: String) -> String:
	var re := RegEx.new()
	re.compile("\\((\\d+\\.\\d+ mm [a-z]+ at \\([^)]*\\))\\)")
	var m := re.search(why)
	return "" if m == null else m.get_string(1)
```

Worked example, radius 10, kernel `fillet 8: fillet failed (limit 5.000; 179.833 mm line at (189.917, 10.000, 10.000))`:

```
Fillet r=10.00 exceeds the 5.000 mm limit set by the 179.833 mm line edge — click it again to remove it, or reduce Radius
```

Worked example, kernel `fillet 8: fillet failed (32.200 mm arc at (193.500, 15.900, 10.000))`:

```
Fillet could not be built on 13 edge(s) (32.200 mm arc at (193.500, 15.900, 10.000)) — fillet the R10 neck first, or pick fewer edges
```

`_dressup_from_face` does not change the sentence. The neck-first clause is already in the `fillet failed` sentence, which is what a face-wide R1 on a sharp neck produces. The walk follows that order. Do not call `graph_add_fillet` a second time from this function.

## 6. `_dressup_radius_refused`

Replace the body (line 1939) with:

```gdscript
func _dressup_radius_refused() -> bool:
	if view == null or view.doc == null or not view.doc.has_method("last_graph_error"):
		return false
	var why := str(view.doc.last_graph_error())
	return why.contains("limit ") or why.contains("fillet failed") or why.contains("chamfer failed")
```

The new kernel strings still contain those markers, so the direct `fillet_edges` fallback still does not run after a real refusal.

## Test

`game/tests/run_rung01_replan11_fillet_ui.gd`. Validation test on the live main scene. 14 checks. Commit the test first: on `b3161bba` re-click does not shrink the selection, the status has no `mm`, face-first commit emits `No edges selected`, and the refusal contains `too large`.

```gdscript
extends SceneTree
## Needs WP2. LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan11_fillet_ui.gd

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
	print("rung01 replan11 WP3 fillet ui")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var view = main.view
	var ops = main.ops_panel
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(20, 10, 10))
	await process_frame
	view.select_entity(body, "")
	ops._on_picked(body, "", Vector3.ZERO)
	check(ops._pending != OpsPanel.Pending.FILLET_EDGES, "body click does not arm fillet")
	var edges: PackedStringArray = view.doc.get_edge_ids(body)
	check(edges.size() >= 2, "two edges")
	ops.arm_or_apply_fillet()
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "Fillet button arms")
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[0]), "")
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[1]), "")
	var status_add: String = main.status_label.text
	check(status_add.contains("mm"), "status lists a length (got %s)" % status_add)
	check(view.selected_edges.has(edges[0]) and view.selected_edges.has(edges[1]), "both edges selected")
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[0]), "")
	check(not view.selected_edges.has(edges[0]), "re-click removes the edge")
	check(main.status_label.text.contains("removed"), "status says removed")
	# Refusal names the limit. Radius 50 cannot fit a 10 mm edge.
	ops._accumulate_dressup_edge(body, _mid(view, body, edges[0]), "")
	ops.set_dressup_radius(50.0)
	ops.try_commit_pending()
	var refused: String = main.status_label.text
	check(refused.contains("exceeds the"), "limit refusal (got %s)" % refused)
	check(refused.contains("mm"), "limit refusal names the edge")
	check(refused.contains("click it again to remove it"), "limit refusal tells the user to re-click")
	check(not refused.contains("too large for selected edge"), "the old sentence is gone")
	check(ops._pending == OpsPanel.Pending.FILLET_EDGES, "refusal keeps the set armed")
	# Face first.
	ops.cancel_pending_pick()
	view.selected_edges.clear()
	view.selected_edge = ""
	var faces: PackedStringArray = view.doc.get_face_ids(body)
	view.select_entity(body, faces[0])
	ops.arm_or_apply_fillet()
	var committed: bool = ops._commit_armed_dressup()
	check(not main.status_label.text.contains("No edges selected"), "face-first does not cancel (got %s)" % main.status_label.text)
	check(committed or view.selected_edges.size() > 0 or main.status_label.text.contains("applied") or main.status_label.text.contains("fillet the R10 neck first") or main.status_label.text.contains("exceeds the"),
			"face-first applies or names a real refusal")
	main.queue_free()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _mid(view, body: String, edge: String) -> Vector3:
	var pts: PackedVector3Array = view.doc.get_edge_lines(body)[edge]
	return (pts[0] + pts[pts.size() - 1]) * 0.5
```

That is 14 `check()` calls. Green: `14 checks, 0 failures`.

`select_entity` is allowed in this validation test. The walk (WP11) must not use it.

Also run `run_rung01_fillet_tests.gd` and `run_rung01_replan3_fillet.gd`. They must stay at 0 failures. If one of them expected the old `too large` sentence, update that one assertion to the new sentence and say so in the commit message. Do not weaken a test that was checking a successful fillet.

## Do not

- Call `graph_add_fillet` twice to "try the neck first".
- Fillet every edge from a body click.
