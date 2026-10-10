# Fail the suite if any .gd under scripts/ or tests/ fails to parse.
# Catches the Wave 6.4 / 6.5 class of "merged uncompiled GDScript" regressions
# that landed while godot-smoke was `if: false`.
# Run: tools/godot/godot --headless --path game --script tests/run_parse_sweep_tests.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("parse-sweep tests")
	_scan("res://scripts")
	_scan("res://tests")
	finish()


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
			if n == "sx_input.gd":
				if s == null:
					check(false, "parses %s" % p)
			else:
				check(s != null, "parses %s" % p)
		n = d.get_next()
	d.list_dir_end()
