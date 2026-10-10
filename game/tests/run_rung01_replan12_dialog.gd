# Rung 1 replan 12 WP3 — Save As pre-fills a .sxp name, not the last export name.
# Run: LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_dialog.gd
extends "res://tests/lib/sx_suite.gd"


func _init() -> void:
	print("rung01 replan12 WP7 Save As dialog")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.file_dialog.current_file = "blank.3mf"
	main.current_path = ""
	main._save_current()
	await process_frame
	check(main.file_dialog.visible, "Save As dialog opens for an unsaved document")
	check(main.file_dialog.current_file == "untitled.sxp",
			"unsaved document pre-fills untitled.sxp (got `%s`)" % main.file_dialog.current_file)
	main.file_dialog.hide()
	main.file_dialog.current_file = "blank.3mf"
	main.current_path = "/tmp/pre-cut.sxp"
	main._show_file_dialog(main.FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
	await process_frame
	check(main.file_dialog.current_file == "pre-cut.sxp",
			"a saved document pre-fills its own file name (got `%s`)" % main.file_dialog.current_file)
	main.file_dialog.hide()
	main.queue_free()
	await process_frame
	finish()
