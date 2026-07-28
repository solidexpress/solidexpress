# Headless tests for Shortcuts registry and HelpOverlay cheat sheet.
# Run: tools/godot/godot --headless --path game --script tests/run_help_tests.gd
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
	print("help / shortcuts tests")
	test_registry()
	await test_overlay()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_registry() -> void:
	print("- Shortcuts registry")
	var table := Shortcuts.all()
	check(table.size() > 0, "TABLE / all() non-empty")
	for entry in table:
		check(entry.has("keys") and str(entry["keys"]) != "", "entry has non-empty keys")
		check(entry.has("context") and str(entry["context"]) != "", "entry has non-empty context")
		check(entry.has("desc") and str(entry["desc"]) != "", "entry has non-empty desc")

	var grouped := Shortcuts.by_context()
	var expected := ["View", "Model", "Sketch", "Timeline", "File"]
	check(grouped.size() == expected.size(), "by_context() has exactly %d contexts" % expected.size())
	for ctx in expected:
		check(grouped.has(ctx), "by_context() has " + ctx)
		check(grouped[ctx] is Array and (grouped[ctx] as Array).size() > 0, ctx + " has entries")

	# No unexpected contexts.
	for ctx in grouped.keys():
		check(ctx in expected, "context is expected: " + str(ctx))

	var fit_desc := Shortcuts.describe("F")
	check(fit_desc != "", "describe(F) known")
	check(fit_desc.to_lower().contains("fit"), "describe(F) mentions fit")
	check(Shortcuts.describe("NotARealKey") == "", "describe unknown returns empty")

	var sketch_entries: Array = Shortcuts.by_context()["Sketch"]
	var found_chain_end := false
	var found_esc_chain := false
	for e in sketch_entries:
		var keys := str(e.get("keys", "")).to_lower()
		var desc := str(e.get("desc", "")).to_lower()
		if (keys.contains("done") or keys.contains("right-click")) and desc.contains("chain"):
			found_chain_end = true
		if keys == "esc" and desc.contains("chain"):
			found_esc_chain = true
	check(found_chain_end, "Sketch shortcuts document Done/RMB end chain")
	check(found_esc_chain, "Sketch Esc shortcut mentions ending chain")
	check(Shortcuts.describe("Esc").to_lower().contains("chain"),
			"describe(Esc) mentions ending chain")
	check(Shortcuts.describe("Done").to_lower().contains("chain"),
			"describe(Done) ends chain")


func test_overlay() -> void:
	print("- HelpOverlay")
	var overlay := HelpOverlay.new()
	root.add_child(overlay)
	await process_frame
	await process_frame

	check(not overlay.visible, "hidden by default")

	overlay.toggle()
	await process_frame
	check(overlay.visible, "toggle() shows overlay")

	var grids: Array[GridContainer] = []
	_collect_grids(overlay, grids)
	check(grids.size() >= 1, "at least one GridContainer")
	var found_populated := false
	for g in grids:
		var n: int = g.get_child_count()
		if n >= 2 and n % 2 == 0:
			found_populated = true
			check(n == 2 * (n / 2), "GridContainer has 2*N children (%d)" % n)
			break
	check(found_populated, "a GridContainer has 2*N children")

	# Close via _unhandled_input with a pressed key.
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	overlay._unhandled_input(key)
	check(not overlay.visible, "key press while visible hides overlay")

	# toggle() twice returns to hidden.
	overlay.toggle()
	check(overlay.visible, "first toggle shows")
	overlay.toggle()
	check(not overlay.visible, "second toggle hides again")


func _collect_grids(node: Node, out: Array[GridContainer]) -> void:
	if node is GridContainer:
		out.append(node as GridContainer)
	for child in node.get_children():
		_collect_grids(child, out)
