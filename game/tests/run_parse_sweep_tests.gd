# Fail the suite if any .gd under scripts/ or tests/ fails to parse.
# Catches the Wave 6.4 / 6.5 class of "merged uncompiled GDScript" regressions
# that landed while godot-smoke was `if: false`.
# Run: tools/godot/godot --headless --path game --script tests/run_parse_sweep_tests.gd
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
	print("parse-sweep tests")
	_scan("res://scripts")
	_scan("res://tests")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		check(false, "open %s" % dir)
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir.path_join(n)
		if d.current_is_dir():
			if n != "." and n != "..":
				_scan(p)
		elif n.ends_with(".gd"):
			var s = load(p)
			check(s != null, "parses %s" % p)
		n = d.get_next()
	d.list_dir_end()
