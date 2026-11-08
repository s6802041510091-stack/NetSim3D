extends Node

const HELD_ITEMS = preload("res://scripts/held_item_catalog.gd")
const HAND_POSITION := Vector3(0.075, -0.18, -0.48)
# Reference: forearm enters from bottom-right; thumb below the index finger.
# Keep orientation fixed even while walking/using; only translate for motion.
const HAND_ROTATION := Vector3(-15, 0, 45)
const ARM_TWIST := PI / 3.0

## Procedural walk/run pose plus a separate first-person viewmodel viewport.
## Never modifies the camera pose used by computer interaction or body collision.
var player: CharacterBody3D
var hand: Node3D
var hand_view: SubViewportContainer
var skeleton: Skeleton3D
var bones: Dictionary = {}
var phase := 0.0
var blend := 0.0
var use_time := 0.0
var inventory_open := false
var items: Array[Dictionary] = []
var selected_slot := -1
var _inventory: Control
var _slots: Array[Button] = []
var _description: Label
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _hud: CanvasLayer
var grip: Node3D
var held_model: Node3D
var relaxed_arm: Node3D
var gripping_arm: Node3D
var _grip_poses: Dictionary = {}
var equipped_id := ""
var preview_id := ""
var _equip_button: Button
var _preview_picker: OptionButton

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	for node in player.get_node("Visual").find_children("*", "Skeleton3D", true, false):
		skeleton = node
		break
	if skeleton:
		for name in ["upperleg01.L", "upperleg01.R", "lowerleg01.L", "lowerleg01.R", "upperarm01.L", "upperarm01.R"]:
			var index := skeleton.find_bone(name)
			if index >= 0:
				bones[name] = {"index": index, "rest": skeleton.get_bone_pose_rotation(index), "axis": skeleton.get_bone_global_rest(index).basis.inverse() * Vector3.RIGHT}
	for i in range(24):
		items.append({})
	_build_hand()
	_build_inventory()

func _build_hand() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 3
	add_child(_hud)
	hand_view = SubViewportContainer.new()
	hand_view.stretch = true
	hand_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hand_view)
	# Scale with the game window instead of a small fixed 320px corner.
	hand_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_view.anchor_left = 0.5
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.size = Vector2i(320, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	hand_view.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 55
	viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -30, 0)
	viewport.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	hand = Node3D.new()
	viewport.add_child(hand)
	hand.position = HAND_POSITION
	hand.rotation_degrees = HAND_ROTATION
	var original_arm: Node3D = load("res://assets/models/player_right_arm.glb").instantiate()
	original_arm.name = "OriginalAvatarRightArm"
	original_arm.rotation.y = PI + ARM_TWIST
	hand.add_child(original_arm)
	for mesh in original_arm.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gripping_arm = original_arm
	relaxed_arm = load("res://assets/models/player_right_arm_relaxed.glb").instantiate()
	relaxed_arm.name = "OriginalAvatarRelaxedArm"
	relaxed_arm.rotation.y = PI + ARM_TWIST
	hand.add_child(relaxed_arm)
	for mesh in relaxed_arm.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gripping_arm.hide()
	grip = Node3D.new()
	grip.name = "ItemGrip"
	grip.position = Basis(Vector3.UP, ARM_TWIST) * Vector3(0, 0.085, -0.045)
	hand.add_child(grip)

func _case_style(fill: Color, border: Color, width := 2, radius := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func _slot_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _case_style(Color("f4f5f6"), Color("8c949b")))
	button.add_theme_stylebox_override("hover", _case_style(Color.WHITE, Color("4c5965"), 3))
	button.add_theme_stylebox_override("pressed", _case_style(Color("cbd2d8"), Color("374754"), 3))
	button.add_theme_stylebox_override("focus", _case_style(Color(0, 0, 0, 0), Color("374754"), 3))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("28323b"))

func _build_inventory() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_inventory = ColorRect.new()
	_inventory.color = Color(0.02, 0.04, 0.06, 0.25)
	_inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_inventory)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inventory.add_child(center)
	var bag := VBoxContainer.new()
	bag.add_theme_constant_override("separation", -2)
	center.add_child(bag)
	# An open rectangular handle, not an opaque block, above the tool case.
	var handle_row := CenterContainer.new()
	bag.add_child(handle_row)
	var handle := Panel.new()
	handle.custom_minimum_size = Vector2(138, 32)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_theme_stylebox_override("panel", _case_style(Color(0, 0, 0, 0), Color("c0c6cb"), 8, 10))
	handle_row.add_child(handle)
	var shell := PanelContainer.new()
	var shell_style := _case_style(Color("d9dde0"), Color("606a73"), 4, 14)
	shell_style.shadow_color = Color(0, 0, 0, 0.35)
	shell_style.shadow_size = 12
	shell_style.shadow_offset = Vector2(0, 7)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		shell_style.set_content_margin(side, 20)
	shell.add_theme_stylebox_override("panel", shell_style)
	bag.add_child(shell)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 12)
	shell.add_child(panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	panel.add_child(header)
	var latch := Panel.new()
	latch.custom_minimum_size = Vector2(22, 38)
	latch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	latch.add_theme_stylebox_override("panel", _case_style(Color("f6f7f8"), Color("77828c"), 3, 3))
	header.add_child(latch)
	var title := Label.new()
	title.text = "กระเป๋าช่าง  /  INVENTORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("26333e"))
	header.add_child(title)
	header.add_child(latch.duplicate())
	var subtitle := Label.new()
	subtitle.text = "NETSIM  •  TOOL CASE                                      24 ช่อง"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("52606c"))
	panel.add_child(subtitle)
	var tray := PanelContainer.new()
	var tray_style := _case_style(Color("9da6ae"), Color("78838e"), 2, 8)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		tray_style.set_content_margin(side, 10)
	tray.add_theme_stylebox_override("panel", tray_style)
	panel.add_child(tray)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	tray.add_child(grid)
	for i in range(24):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(68, 58)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.toggle_mode = true
		slot.text = "%02d" % (i + 1)
		slot.clip_text = true
		_slot_theme(slot)
		slot.pressed.connect(select_slot.bind(i))
		grid.add_child(slot)
		_slots.append(slot)
	_description = Label.new()
	_description.text = "กระเป๋ายังว่าง — ยังไม่เชื่อมการเก็บอุปกรณ์ภารกิจ"
	_description.add_theme_color_override("font_color", Color("394652"))
	_description.add_theme_font_size_override("font_size", 15)
	panel.add_child(_description)
	var actions := HBoxContainer.new()
	panel.add_child(actions)
	_equip_button = Button.new()
	_equip_button.text = "ถือของที่เลือก"
	_equip_button.disabled = true
	_slot_theme(_equip_button)
	_equip_button.pressed.connect(func():
		if selected_slot >= 0 and selected_slot < items.size() and not items[selected_slot].is_empty():
			if equip_item(items[selected_slot].id):
				close_inventory())
	actions.add_child(_equip_button)
	var empty_hands := Button.new()
	empty_hands.text = "เก็บของ / มือเปล่า"
	_slot_theme(empty_hands)
	empty_hands.pressed.connect(func():
		unequip_item()
		close_inventory())
	actions.add_child(empty_hands)
	_preview_picker = OptionButton.new()
	_preview_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_theme(_preview_picker)
	_preview_picker.add_item("ทดลองถือ (ไม่ใช่ของภารกิจ)")
	for id: String in HELD_ITEMS.TOOLS:
		_preview_picker.add_item("ทดลอง: " + HELD_ITEMS.TOOLS[id].title)
		_preview_picker.set_item_metadata(_preview_picker.item_count - 1, id)
	_preview_picker.item_selected.connect(func(index: int):
		preview_item("" if index == 0 else str(_preview_picker.get_item_metadata(index)))
		close_inventory())
	panel.add_child(_preview_picker)
	var close := Button.new()
	close.text = "ปิดกระเป๋า  [E / Esc]"
	close.custom_minimum_size.y = 44
	_slot_theme(close)
	close.pressed.connect(close_inventory)
	panel.add_child(close)
	_inventory.hide()

## Inventory data API for mission pickups; no pretend mission items are granted.
func add_item(id: String, title: String, amount := 1) -> bool:
	if id.is_empty() or amount <= 0:
		return false
	for i in range(items.size()):
		if items[i].get("id", "") == id:
			items[i].amount += amount
			_refresh_slots()
			return true
	for i in range(items.size()):
		if items[i].is_empty():
			items[i] = {"id": id, "title": title, "amount": amount}
			_refresh_slots()
			return true
	return false

func remove_item(id: String, amount := 1) -> bool:
	if amount <= 0:
		return false
	for i in range(items.size()):
		if items[i].get("id", "") == id and items[i].amount >= amount:
			items[i].amount -= amount
			if items[i].amount == 0:
				items[i] = {}
			_refresh_slots()
			return true
	return false

func _refresh_slots() -> void:
	if not equipped_id.is_empty() and not _owns_item(equipped_id):
		unequip_item()
	for i in range(items.size()):
		_slots[i].text = "%02d" % (i + 1) if items[i].is_empty() else "%s\n×%d" % [items[i].title, items[i].amount]
		_slots[i].tooltip_text = _slots[i].text
	select_slot(selected_slot)

func select_slot(index: int) -> void:
	selected_slot = index
	for i in range(_slots.size()):
		_slots[i].set_pressed_no_signal(i == index)
	if index < 0 or index >= items.size() or items[index].is_empty():
		_description.text = "ช่องว่าง — ยังไม่เชื่อมการเก็บอุปกรณ์ภารกิจ"
		_equip_button.disabled = true
	else:
		_description.text = "%s × %d" % [items[index].title, items[index].amount]
		_equip_button.disabled = not HELD_ITEMS.TOOLS.has(items[index].id)
		if _equip_button.disabled:
			_description.text += " — ยังไม่มีโมเดลสำหรับถือ"

func _owns_item(id: String) -> bool:
	for item in items:
		if item.get("id", "") == id and item.get("amount", 0) > 0:
			return true
	return false

## Real equipment requires ownership. Preview never grants inventory or mission progress.
func equip_item(id: String) -> bool:
	if not _owns_item(id) or not HELD_ITEMS.TOOLS.has(id):
		return false
	equipped_id = id
	preview_id = ""
	_preview_picker.select(0)
	_show_held_item(id)
	return true

func unequip_item() -> void:
	equipped_id = ""
	preview_id = ""
	_preview_picker.select(0)
	_show_held_item("")

func preview_item(id: String) -> bool:
	if not id.is_empty() and not HELD_ITEMS.TOOLS.has(id):
		return false
	preview_id = id
	for index in range(_preview_picker.item_count):
		if (index == 0 and id.is_empty()) or _preview_picker.get_item_metadata(index) == id:
			_preview_picker.select(index)
			break
	_show_held_item(equipped_id if id.is_empty() else id)
	return true

func _show_held_item(id: String) -> void:
	relaxed_arm.visible = id.is_empty()
	gripping_arm.hide()
	if is_instance_valid(held_model):
		grip.remove_child(held_model)
		held_model.queue_free()
		held_model = null
	if id.is_empty():
		return
	var entry: Dictionary = HELD_ITEMS.TOOLS[id]
	if not _grip_poses.has(id):
		var pose: Node3D = entry.hand_scene.instantiate()
		pose.name = "GripPose_" + id
		pose.rotation.y = PI + ARM_TWIST
		hand.add_child(pose)
		for mesh in pose.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_grip_poses[id] = pose
	gripping_arm = _grip_poses[id]
	gripping_arm.show()
	held_model = entry.scene.instantiate()
	held_model.name = "Held_" + id
	grip.add_child(held_model)
	# Keep the tool upright in the reference framing while the forearm enters diagonally.
	var rest_basis := Basis.from_euler(HAND_ROTATION * PI / 180.0)
	held_model.basis = rest_basis.inverse() * Basis.from_euler(entry.rotation * PI / 180.0)
	held_model.scale = Vector3.ONE * entry.scale
	# Put the actual model's handle in the avatar palm, not at its file origin.
	held_model.position = -(held_model.basis * entry.handle) + entry.get("offset", Vector3.ZERO)
	var correction: Vector3 = entry.get("fit_offset", Vector3.ZERO)
	held_model.position += gripping_arm.basis * Vector3(correction.x, correction.z, -correction.y)
	for mesh in held_model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func open_inventory() -> void:
	if player.controls_locked or get_tree().paused:
		return
	inventory_open = true
	_mouse_before = Input.mouse_mode
	player.set_controls_locked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_inventory.show()
	_slots[0].grab_focus()

func close_inventory() -> void:
	if not inventory_open:
		return
	inventory_open = false
	_inventory.hide()
	player.set_controls_locked(false)
	Input.mouse_mode = _mouse_before

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		if inventory_open:
			close_inventory()
		elif not player.controls_locked:
			open_inventory()
		else:
			return # Do not intercept typing E in a simulated computer.
		get_viewport().set_input_as_handled()
	elif inventory_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_inventory()
		get_viewport().set_input_as_handled()

func play_use() -> void:
	use_time = 0.32

func _process(delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var moving: bool = speed > 0.1 and player.is_on_floor() and not player.controls_locked
	blend = move_toward(blend, minf(speed / player.walk_speed, 1.5) if moving else 0.0, delta * 5)
	phase += delta * (11.0 if speed > player.walk_speed + 0.3 else 7.0)
	use_time = maxf(0, use_time - delta)
	hand_view.visible = not player.controls_locked
	var reach := sin((1.0 - use_time / 0.32) * PI) if use_time > 0 else 0.0
	hand.position = HAND_POSITION + Vector3(sin(phase) * 0.010 * blend, cos(phase * 2) * 0.009 * blend, -reach * 0.06)
	hand.rotation_degrees = HAND_ROTATION
	if skeleton:
		for name: String in bones:
			var entry: Dictionary = bones[name]
			var stride := sin(phase + (PI if name.ends_with(".R") else 0.0)) * blend
			var angle := stride * 0.35
			if name.begins_with("lowerleg"):
				angle = maxf(0.0, -stride) * 0.45
			elif name.begins_with("upperarm"):
				angle = -stride * 0.25
			skeleton.set_bone_pose_rotation(entry.index, entry.rest * Quaternion(Vector3(entry.axis).normalized(), angle))
