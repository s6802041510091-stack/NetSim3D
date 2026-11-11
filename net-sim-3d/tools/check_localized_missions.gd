extends SceneTree
var thai := RegEx.create_from_string("[ก-๙]")
var missing: Array[String] = []
var checked := 0

func _initialize() -> void:
	call_deferred("_check")

func _inspect(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		checked += 1
		if thai.search(node.text):
			missing.append(node.name + ": " + node.text)
	if node is OptionButton or node is PopupMenu:
		for index in range(node.item_count):
			if thai.search(node.get_item_text(index)):
				missing.append(node.get_item_text(index))
	for child in node.get_children():
		_inspect(child)

func _check() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var language := root.get_node("L10n")
	var flow := root.get_node("GameFlow")
	var previous: String = language.locale
	language.set_locale("en", false)
	flow._layer.hide()
	for source: String in language._catalog:
		if thai.search(language.t(source)):
			missing.append("Catalog: " + source)
	var parent := Control.new()
	root.add_child(parent)
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var apps := [
		load("res://missions/mission_01/scenes/netplan_edu.tscn").instantiate(),
		WindowsSecurity.new(),
		TeamViewerSim.new(),
	]
	for app: Control in apps:
		app.use_save_file = false
		parent.add_child(app)
		app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var directory := "D:/NetSim3D/Preview/UI_เลือกด่าน_สองภาษา/actual/"
			root.get_texture().get_image().save_png(directory + app.get_class() + "-" + str(apps.find(app)) + "-english.png")
		_inspect(app)
		if app is WindowsSecurity:
			app.open_page(WindowsSecurity.Page.FIREWALL)
			await process_frame
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
			_inspect(app)
		parent.remove_child(app)
		app.queue_free()
		await process_frame
	var dialogue := DialogueBox.new()
	parent.add_child(dialogue)
	dialogue.show_lines(PackedStringArray(Mission02Controller.BRIEFING))
	for index in range(Mission02Controller.BRIEFING.size()):
		await process_frame
		_inspect(dialogue)
		dialogue._finish_typing()
		dialogue.advance(true)
	parent.queue_free()
	language.set_locale(previous, false)
	await process_frame
	for item in missing:
		print("UNTRANSLATED ", item)
	print("LOCALIZED_MISSIONS checked=", checked, " missing=", missing.size())
	quit(0 if missing.is_empty() else 1)
