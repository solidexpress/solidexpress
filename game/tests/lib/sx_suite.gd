extends SceneTree

var checks := 0
var failures := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func finish() -> void:
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
