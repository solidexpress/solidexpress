# Rung 1 replan 16 WP1 — suite manifests are the only registration path.
# Run from the repo root:
#   tools/godot/godot --headless --path game --script tests/run_rung01_replan16_suites.gd
extends "res://tests/lib/sx_suite.gd"
const OLD_CI: Array[String] = [
	"tests/run_workflow_tests.gd",
	"tests/run_ui_tests.gd",
	"tests/run_sketch_tests.gd",
	"tests/run_sketch_tools_tests.gd",
	"tests/run_print_tests.gd",
	"tests/run_rung01_wrench.gd",
	"tests/run_rung01_sx036_esc.gd",
	"tests/run_rung01_sx036_fields.gd",
	"tests/run_rung01_jaw_label_hit.gd",
	"tests/run_rung01_replan15_shaftbadges.gd",
	"tests/run_rung01_replan6_cut.gd",
	"tests/run_rung01_replan12_status.gd",
	"tests/run_rung01_n12_extrude.gd",
	"tests/run_rung01_sx036_rail.gd",
	"tests/run_rung01_replan15_jawstub.gd",
	"tests/run_rung01_replan15_thick.gd",
]



func _init() -> void:
	print("rung01 replan16 WP1 suites")
	_run()
	finish()


func _repo() -> String:
	var game := ProjectSettings.globalize_path("res://").simplify_path()
	return game.get_base_dir()


func _parse(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data := {}
	var ok := true
	for raw in text.split("\n"):
		var line: String = raw
		var hash := line.find("#")
		if hash >= 0:
			line = line.substr(0, hash)
		line = line.strip_edges()
		if line == "":
			continue
		var eq := line.find("=")
		if eq < 0:
			ok = false
			continue
		var key := line.substr(0, eq).strip_edges()
		var val := line.substr(eq + 1).strip_edges()
		data[key] = val
	data["_ok"] = ok
	return data


func _derived(script: String) -> String:
	var base := script.get_file()
	if base.begins_with("run_") and base.ends_with(".gd"):
		return base.substr(4, base.length() - 7)
	return ""


func _exec_text(argv0: String, args: PackedStringArray) -> Dictionary:
	var out: Array = []
	var code := OS.execute(argv0, args, out, true)
	var text := ""
	for item in out:
		text += str(item)
	return {"code": code, "text": text}


func _run() -> void:
	var repo := _repo()
	var suites := repo.path_join("packaging/ci/suites.d")
	var names := DirAccess.get_files_at(suites)
	check(names.size() > 0, "suites.d has manifests (got %d)" % names.size())
	names.sort()
	var tiers := {}
	var basenames := {}
	for name in names:
		if not str(name).ends_with(".suite"):
			continue
		var path := suites.path_join(name)
		var data := _parse(path)
		var script := str(data.get("script", ""))
		var tier := str(data.get("tier", ""))
		var reason := str(data.get("reason", ""))
		var stem := str(name).trim_suffix(".suite")
		var reason_ok := false
		for prefix in ["env: ", "stale-feature: ", "product: "]:
			if reason.begins_with(prefix) and reason.substr(prefix.length()).strip_edges() != "":
				reason_ok = true
		var tier_ok := tier == "ci" or tier == "full" or (tier == "known-red" and reason_ok)
		var parsed: bool = bool(data.get("_ok", false)) and script != "" and tier_ok
		check(parsed, "parses " + str(name))
		check(_derived(script) == stem, "name derived from script for " + str(name))
		if script != "":
			tiers[script] = tier
			basenames[script.get_file()] = true
	var baseline := FileAccess.get_file_as_string(repo.path_join("packaging/ci/suites.baseline"))
	var missing: Array[String] = []
	var base_n := 0
	for raw in baseline.split("\n"):
		var line := str(raw).strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		base_n += 1
		if not basenames.has(line):
			missing.append(line)
	check(base_n == 154, "baseline has 154 names (got %d)" % base_n)
	check(missing.is_empty(), "baseline basenames ⊆ manifest scripts, missing %s" % str(missing))
	for script in OLD_CI:
		check(str(tiers.get(script, "")) == "ci", "old CI tier=ci " + script)
	# Godot's --path sets the process cwd to game/, so the tools are addressed
	# from the repo root. The argv is still python3 + lint_suites.py and
	# bash + run_suites.sh --tier ci --list.
	var lint := _exec_text("python3", PackedStringArray([repo.path_join("tools/lint_suites.py")]))
	check(int(lint["code"]) == 0, "lint_suites.py exit 0 (got %s) %s" % [str(lint["code"]), str(lint["text"])])
	var tmp := OS.get_temp_dir().path_join("sx_suites_lint_%d" % Time.get_ticks_usec())
	var made := DirAccess.make_dir_recursive_absolute(tmp)
	check(made == OK, "temp suites dir " + tmp)
	var bad := tmp.path_join("no_such_suite.suite")
	var fh := FileAccess.open(bad, FileAccess.WRITE)
	check(fh != null, "write temp manifest")
	if fh != null:
		fh.store_string("script=tests/run_no_such_suite.gd\ntier=full\n")
		fh.close()
	OS.set_environment("SX_SUITES_DIR", tmp)
	var bad_lint := _exec_text("python3", PackedStringArray([repo.path_join("tools/lint_suites.py")]))
	if OS.has_method("unset_environment"):
		OS.unset_environment("SX_SUITES_DIR")
	else:
		OS.set_environment("SX_SUITES_DIR", "")
	check(int(bad_lint["code"]) == 1, "missing script lint exits 1 (got %s)" % str(bad_lint["code"]))
	check(str(bad_lint["text"]).find("missing script") >= 0, "lint prints missing script: " + str(bad_lint["text"]))
	var listed := _exec_text("bash", PackedStringArray([
		repo.path_join("packaging/ci/run_suites.sh"), "--tier", "ci", "--list",
	]))
	var nlines := 0
	for raw in str(listed["text"]).split("\n"):
		if str(raw).strip_edges() != "":
			nlines += 1
	var nci := 0
	for script in tiers.keys():
		if str(tiers[script]) == "ci":
			nci += 1
	check(int(listed["code"]) == 0, "run_suites --tier ci --list exit 0 (got %s)" % str(listed["code"]))
	check(nlines == nci, "ci --list lines %d == ci manifests %d" % [nlines, nci])
