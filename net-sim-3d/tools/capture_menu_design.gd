extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	await process_frame
	await process_frame
	var flow := root.get_node("GameFlow")
	for page in ["home", "levels", "settings"]:
		match page:
			"home": flow.show_home()
			"levels": flow.show_levels()
			"settings": flow.show_settings()
		await create_timer(0.38).timeout
		var img := root.get_texture().get_image()
		var err := img.save_png("D:/NetSim3D/tmp/menu_" + page + ".png")
		print("CAPTURE ", page, " ", img.get_size(), " error=", err)
		if page == "home":
			await create_timer(1.2).timeout
			var later := root.get_texture().get_image()
			print("CAPTURE home motion error=", later.save_png("D:/NetSim3D/tmp/menu_home_motion.png"))
	quit()
