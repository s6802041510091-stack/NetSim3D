extends SceneTree

## Settings segments (language, graphics quality): the blue thumb slides to a
## new choice instead of jumping (asked by the user 2026-11-18), and the text
## colours cross-fade. Scratch settings files, so real preferences are untouched.
## Mid-slide screenshots go to Preview/เมนู_ตั้งค่า/ (run WITHOUT --headless):
##   godot --path net-sim-3d -s res://tools/validate_settings_segments.gd

const SHOTS := "res://../Preview/เมนู_ตั้งค่า"

var failures := 0
var flow: Node


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, title: String) -> void:
	print("PASS: " if condition else "FAIL: ", title)
	if not condition:
		failures += 1


func run() -> void:
	flow = root.get_node("GameFlow")
	var l10n := root.get_node("L10n")
	var real_settings: String = flow.save_file
	var real_language: String = l10n.preferences_path
	var real_locale: String = l10n.locale
	var real_quality: String = flow.quality
	flow.save_file = OS.get_user_data_dir().path_join("validate_settings_segments.cfg")
	l10n.preferences_path = OS.get_user_data_dir().path_join("validate_settings_segments_language.cfg")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	change_scene_to_file("res://scenes/start_menu.tscn")
	await process_frame
	await process_frame
	l10n.set_locale("th")
	flow.set_quality("medium", false)
	flow.show_settings()
	await process_frame

	var thumb := _thumb("Quality_")
	var medium_x := _button("Quality_medium").position.x
	var high_x := _button("Quality_high").position.x
	check(thumb != null and is_equal_approx(thumb.position.x, medium_x), "thumb starts on the current choice (medium)")
	check(_ink("Quality_medium") == Color.WHITE and _ink("Quality_low") == flow.INK, "chosen text is white, the others dark")

	_button("Quality_high").pressed.emit()
	await process_frame
	thumb = _thumb("Quality_")
	var start_x := thumb.position.x
	check(start_x < high_x - 100.0, "after the click the thumb starts from the old place (x=%.0f, target %.0f)" % [start_x, high_x])
	await _shot("quality_mid_slide", 0.12)
	thumb = _thumb("Quality_")
	var mid_x := thumb.position.x
	check(mid_x > start_x and mid_x < high_x, "mid-way the thumb is between the two choices (x=%.0f)" % mid_x)
	await _wait(0.5)
	check(is_equal_approx(_thumb("Quality_").position.x, high_x), "the thumb ends on the new choice (high)")
	check(_ink("Quality_high") == Color.WHITE and _ink("Quality_medium") == flow.INK, "text colours swapped after the slide")
	check(_thumb("Quality_").scale.is_equal_approx(Vector2.ONE), "the thumb is back to its normal shape")
	await _shot("quality_high", 0.0)

	# Language: the page is redrawn in English and the thumb slides to ENG.
	_button("Language_en").pressed.emit()
	await process_frame
	var lang_thumb := _thumb("Language_")
	var en_x := _button("Language_en").position.x
	check(lang_thumb.position.x < en_x - 100.0, "language thumb starts on ไทย after switching")
	await _shot("language_mid_slide", 0.12)
	await _wait(0.5)
	check(is_equal_approx(_thumb("Language_").position.x, en_x), "language thumb ends on ENG")
	check(is_equal_approx(_thumb("Quality_").position.x, high_x), "quality thumb does not move when only the language changes")

	# Re-opening the page does not replay the slide.
	flow.show_home()
	flow.show_settings()
	await process_frame
	check(is_equal_approx(_thumb("Quality_").position.x, high_x), "re-opened settings: thumb already on its choice")

	l10n.set_locale(real_locale)
	flow.set_quality(real_quality, false)
	DirAccess.remove_absolute(flow.save_file)
	DirAccess.remove_absolute(l10n.preferences_path)
	flow.save_file = real_settings
	l10n.preferences_path = real_language
	print("SETTINGS_SEGMENTS_FINISHED failures=", failures)
	quit(1 if failures else 0)


func _button(name: String) -> Button:
	return flow._art_canvas.find_child(name, true, false) as Button


func _thumb(prefix: String) -> Panel:
	return flow._art_canvas.find_child(prefix + "Thumb", true, false) as Panel


func _ink(name: String) -> Color:
	return _button(name).get_theme_color("font_color")


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String, after: float) -> void:
	if after > 0.0:
		await _wait(after)
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOTS)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(name + ".png"))
