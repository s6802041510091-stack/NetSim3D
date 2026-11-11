extends SceneTree
const OUTPUT := "D:/NetSim3D/Preview/UI_หน้าโหลด/"

func _initialize() -> void:
	call_deferred("_check")

func _click(button: Button) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	var click := InputEventMouseButton.new()
	click.position = at
	click.global_position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	root.push_input(click)
	await process_frame
	click = click.duplicate()
	click.button_mask = 0
	click.pressed = false
	root.push_input(click)
	await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT + name + ".png") == OK)

func _check() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	var flow := root.get_node("GameFlow")
	var sound := root.get_node("SoundManager")
	var language := root.get_node("L10n")
	var original_locale: String = language.locale
	var original_save: String = flow.save_file
	flow.save_file = "user://loading_ui_test.cfg"
	for code in ["th", "en"]:
		language.set_locale(code, false)
		sound.history.clear()
		flow.start_level(1)
		assert(flow.loading)
		var last_percent := 0.0
		var saw_in_between := false
		var deadline := Time.get_ticks_msec() + 30000
		while flow.loading and Time.get_ticks_msec() < deadline:
			await process_frame
			var percent: float = flow._progress.value
			assert(percent >= last_percent)
			assert(is_equal_approx(flow._loading_visual.mail_progress, percent / 100.0))
			assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
			saw_in_between = saw_in_between or (percent > 0 and percent < 100)
			last_percent = percent
		assert(saw_in_between)
		assert(not flow.loading)
		assert(flow._progress.value == 100.0)
		assert(flow._loading_visual.mail_progress == 1.0)
		assert(not flow._status.visible)
		assert(sound.history.count("load_complete") == 1)
		assert(sound._music_id == "menu" and sound._active_music.playing)
		assert(current_scene.scene_file_path == "res://scenes/main.tscn")
		assert(paused)
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		var start: Button = flow._body.get_node("StartButton")
		for child in flow._body.get_children():
			if child is Label:
				assert(not child.text.contains("WASD") and not child.text.contains("W A S D"))
				assert(not child.text.contains("Start by") and not child.text.contains("เริ่มจากคุย"))
		await _shot("ready-" + code)
		assert(sound.history.count("load_complete") == 1)
		await _click(start)
		assert(flow._controls_help.visible)
		assert(sound._music_id == "level")
		assert(not flow._layer.visible)
		assert(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		await _shot("controls-popup-" + code)
		await _click(flow._controls_help.close_button)
		assert(not flow._controls_help.visible)
		assert(not paused)
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		print("LOADING_FLOW_OK ", code, " synced percentage/mail, mouse Start click, in-world controls popup, dismiss and play")
	language.set_locale(original_locale, false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.save_file))
	flow.save_file = original_save
	quit()
