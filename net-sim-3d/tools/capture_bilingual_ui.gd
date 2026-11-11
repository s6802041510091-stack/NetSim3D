extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	await process_frame
	await process_frame
	var flow := root.get_node("GameFlow")
	var language := root.get_node("L10n")
	var previous: String = language.locale
	var old_volumes: Dictionary = flow.volumes.duplicate()
	for bus: String in old_volumes:
		flow.set_volume(bus, 80, false)
	var directory := "D:/NetSim3D/Preview/UI_เลือกด่าน_สองภาษา/actual"
	DirAccess.make_dir_recursive_absolute(directory)
	for code in ["th", "en"]:
		language.set_locale(code, false)
		for page in ["home", "levels", "settings"]:
			match page:
				"home": flow.show_home()
				"levels": flow.show_levels()
				"settings": flow.show_settings()
			await create_timer(0.35).timeout
			var img := root.get_texture().get_image()
			assert(img.save_png(directory + "/" + page + "-" + code + ".png") == OK)
			print("CAPTURE_OK ", page, " ", code)
	for bus: String in old_volumes:
		flow.set_volume(bus, old_volumes[bus], false)
	language.set_locale(previous, false)
	await process_frame
	quit()
