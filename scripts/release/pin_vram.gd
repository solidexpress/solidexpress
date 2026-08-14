extends SceneTree


func _init() -> void:
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_s3tc_bptc", true)
	var err := ProjectSettings.save()
	print(
		"pin_vram etc2=",
		ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"),
		" save=",
		err
	)
	quit()
