extends SceneTree

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	var flow := root.get_node("GameFlow")
	var language := root.get_node("L10n")
	var previous: String = language.locale
	var old_path: String = language.preferences_path
	var old_menu_path: String = flow.save_file
	language.preferences_path = "user://language_ui_test.cfg"
	flow.save_file = "user://menu_ui_test.cfg"
	var old_volumes: Dictionary = flow.volumes.duplicate()
	language.set_locale("th", false)
	flow.show_levels()
	await process_frame
	assert(flow._background.texture == flow.LEVELS_TH)
	assert(flow._art_canvas.get_child_count() == 7)
	assert(flow._art_canvas.get_node("Level3Hotspot").disabled)
	assert(flow._art_canvas.get_node("Level4Hotspot").disabled)
	var hit: Rect2 = flow._art_canvas.get_node("Level1Hotspot").get_global_rect()
	assert(hit.has_point(Vector2(475, 474) * flow._art_canvas.scale))
	flow._art_canvas.get_node("BackHotspot").pressed.emit()
	assert(flow._screen == "home")
	flow.show_settings()
	await process_frame
	await process_frame
	var slider: HSlider = flow._art_canvas.get_node("MusicSlider")
	var hit_position := slider.get_global_rect().position + slider.get_global_rect().size * Vector2(0.75, 0.5)
	var click := InputEventMouseButton.new()
	var motion := InputEventMouseMotion.new()
	motion.position = hit_position
	motion.global_position = hit_position
	root.push_input(motion)
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.position = hit_position
	click.global_position = hit_position
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	click.button_mask = 0
	root.push_input(click)
	await process_frame
	assert(slider.value >= 74 and slider.value <= 76)
	slider.value = 63
	assert(flow.volumes.Music == 63)
	flow._art_canvas.get_node("Language_en").pressed.emit()
	assert(language.locale == "en")
	assert(flow._background.texture == flow.SETTINGS_EN)
	assert(flow._art_canvas.get_node("MusicSlider").value == 63)
	var saved := ConfigFile.new()
	assert(saved.load(language.preferences_path) == OK)
	assert(saved.get_value("interface", "language") == "en")
	flow.show_levels()
	assert(flow._background.texture == flow.LEVELS_EN)
	assert(language.t("กำลังส่งข้อมูล… 68%") == "Transferring data… 68%")
	assert(language.t("จุดที่ 2: Router\nคลิกเพื่อเลือกอุปกรณ์") == "Point 2: Router\nClick to choose a device")
	var label := Label.new()
	label.text = "คะแนน 42"
	root.add_child(label)
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = DialogueBox.highlight("มีงานใหม่เข้ามาพอดี โรงเรียนกำลังเตรียมห้องคอมพิวเตอร์ห้องใหม่ มี**เครื่องนักเรียน 20 เครื่อง** และ**เครื่องครูอีก 1 เครื่อง**")
	root.add_child(rich)
	var input := LineEdit.new()
	input.text = "คำตอบของผู้เล่น"
	input.placeholder_text = "พิมพ์ Partner ID"
	root.add_child(input)
	await process_frame
	await process_frame
	assert(label.text == "Score 42")
	assert(rich.get_parsed_text().contains("20 student computers"))
	assert(input.text == "คำตอบของผู้เล่น")
	assert(input.placeholder_text == "Enter Partner ID")
	language.set_locale("th", false)
	assert(label.text == "คะแนน 42")
	assert(rich.get_parsed_text().contains("เครื่องนักเรียน 20 เครื่อง"))
	for bus: String in old_volumes:
		flow.set_volume(bus, old_volumes[bus], false)
	language.set_locale(previous, false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(language.preferences_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.save_file))
	language.preferences_path = old_path
	flow.save_file = old_menu_path
	label.queue_free()
	rich.queue_free()
	input.queue_free()
	await process_frame
	print("BILINGUAL_UI_OK artwork, hit areas, locked levels, sliders, saved language, dynamic text, dialogue and untouched user input")
	quit()
