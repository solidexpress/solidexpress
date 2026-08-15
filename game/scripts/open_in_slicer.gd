extends Node
class_name OpenInSlicer

const LAST_CMD_PATH := "user://slicer_last_command.txt"

static func _sanitize_filename(name: String) -> String:
	var s := name.strip_edges()
	if s == "":
		s = "body"
	# Replace invalid characters with underscore.
	var out := ""
	for i in s.length():
		var c := s[i]
		# Godot 4.7: String has no is_ascii_digit(); use is_valid_int() for single-char digit.
		if c.is_valid_identifier() or c.is_valid_int() or c == "-" or c == "_":
			out += c
		else:
			out += "_"
	return out

static func export_per_body(doc: SxDocument, dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	DirAccess.make_dir_recursive_absolute(dir_path)
	var idx := 0
	for body_id in doc.body_ids():
		idx += 1
		var base := _sanitize_filename(doc.body_name(body_id))
		if base == "":
			base = "body_%d" % idx
		# Ensure uniqueness
		var path := "%s/%s.3mf" % [dir_path, base]
		var attempt := 1
		while FileAccess.file_exists(path):
			path = "%s/%s_%d.3mf" % [dir_path, base, attempt]
			attempt += 1
		if not doc.export_3mf_for_body(body_id, path):
			push_error("export_3mf_for_body failed for %s" % body_id)
			continue
		out.append(path)
	return out

static func open_in_slicer(doc: SxDocument, dry_run: bool = false) -> Dictionary:
	var settings := SlicerSettings.load_settings()
	var exec_path: String = settings["exec"]
	var args: PackedStringArray = settings["args"]
	# Export under a per-run folder.
	var ts := Time.get_unix_time_from_system()
	var dir_path := "user://slicer/%d" % int(ts)
	var files := export_per_body(doc, dir_path)
	var full_args: PackedStringArray = args.duplicate()
	for f in files:
		full_args.append(ProjectSettings.globalize_path(f))
	var record := "%s %s" % [exec_path, " ".join(full_args)]
	# Always record what would be spawned.
	var f := FileAccess.open(LAST_CMD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(record + "\n")
		f.close()
	if not dry_run and exec_path != "":
		# Best-effort spawn; ignore exit code here.
		var _output := []
		OS.execute(exec_path, full_args, _output, false)
	return {"exec": exec_path, "args": full_args, "files": files, "record_path": LAST_CMD_PATH}

