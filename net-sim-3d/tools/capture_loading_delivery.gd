extends SceneTree

const OUTPUT := "D:/NetSim3D/Preview/UI_หน้าโหลด/"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	var flow := root.get_node("GameFlow")
	flow._page("Level 1  /  กำลังโหลด", "ออกแบบเครือข่าย")
	var visual := LoadingDelivery.new()
	flow._body.add_child(visual)
	visual.set_percent(68)
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", flow._panel(Color("d7e8ee"), 9))
	bar.add_theme_stylebox_override("fill", flow._panel(flow.CORAL, 9))
	bar.value = 68
	flow._body.add_child(bar)
	flow._label("กำลังโหลด . . . 68%", 32, flow.INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await create_timer(0.4).timeout
	var image := root.get_texture().get_image()
	print("CAPTURE_LOADING ", image.get_size(), " ", image.save_png(OUTPUT + "godot-loading-68.png"))
	quit()
