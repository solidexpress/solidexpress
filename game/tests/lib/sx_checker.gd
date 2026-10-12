## Runs tools/check_<rung>.py for validation suites.
## Returns {code, text} and prints the checker output.
class_name SxChecker
extends RefCounted


static func run(rung: String, args: Array) -> Dictionary:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var checker := repo.path_join("tools/check_%s.py" % rung)
	var argv := PackedStringArray()
	argv.append(checker)
	for a in args:
		argv.append(str(a))
	var output: Array = []
	var code := OS.execute("python3", argv, output, true)
	var text := "\n".join(output)
	print(text)
	return {"code": code, "text": text}
