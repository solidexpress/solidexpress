# Fails fast, with one readable line, when libsxcore did not load.
# Run: tools/godot/godot --headless --path game --script tests/preflight_sxcore.gd
extends SceneTree


func _init() -> void:
	if not ClassDB.class_exists("SxDocument"):
		printerr("PREFLIGHT FAIL: SxDocument is not registered, so libsxcore did not load. "
				+ "Put the OCCT libraries on the loader path first: "
				+ "export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib:$LD_LIBRARY_PATH")
		quit(2)
		return
	print("preflight ok: SxDocument is registered")
	quit(0)
