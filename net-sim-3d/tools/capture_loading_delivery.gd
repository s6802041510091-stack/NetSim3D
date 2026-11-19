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
	flow._label("กำลังโหลด . . . 68%", 32, flow.INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await create_timer(0.4).timeout
	var image := root.get_texture().get_image()
	print("CAPTURE_LOADING ", image.get_size(), " ", image.save_png(OUTPUT + "godot-loading-68.png"))
	quit()
