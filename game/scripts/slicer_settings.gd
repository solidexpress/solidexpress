extends Node
class_name SlicerSettings

const CFG_PATH := "user://slicer.cfg"

static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(CFG_PATH)
	if err != OK:
		return {"exec": "", "args": PackedStringArray([])}
	var exec_path: String = str(cfg.get_value("slicer", "executable", ""))
	var args_val = cfg.get_value("slicer", "args", PackedStringArray([]))
	var args: PackedStringArray
	if typeof(args_val) == TYPE_PACKED_STRING_ARRAY:
		args = args_val
	else:
		args = _split_args(str(args_val))
	return {"exec": exec_path, "args": args}

static func save_settings(exec_path: String, args: PackedStringArray) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("slicer", "executable", exec_path)
	cfg.set_value("slicer", "args", args)
	return cfg.save(CFG_PATH) == OK

static func _split_args(s: String) -> PackedStringArray:
	# Simple whitespace split with quote handling for common cases.
	var out: PackedStringArray = []
	var cur := ""
	var in_quote := false
	for i in s.length():
		var ch := s[i]
		if ch == "\"":
			in_quote = not in_quote
		elif ch == " " and not in_quote:
			if cur != "":
				out.append(cur)
				cur = ""
		else:
			cur += ch
	if cur != "":
		out.append(cur)
	return out

