extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	print("PASS " if value else "FAIL ", title)
	if not value:
		failures += 1

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player: CharacterBody3D = load("res://scenes/it_support_player.tscn").instantiate()
	world.add_child(player)
	player.require_mouse_capture = false
	var floor_body := StaticBody3D.new()
	world.add_child(floor_body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	collision.shape = box
	collision.position.y = -0.1
	floor_body.add_child(collision)
	await process_frame
	var presentation: Node = player.get_node("Presentation")
	check(presentation.bones.size() == 6, "six real skeleton bones animated")
	check(presentation.hand_view.visible, "right hand visible")
	var arm := presentation.hand.get_node("OriginalAvatarRightArm") as Node3D
	var arm_meshes := arm.find_children("*", "MeshInstance3D", true, false)
	check(arm_meshes.size() == 2, "original avatar skin and sleeve meshes")
	for mesh in arm_meshes:
		check(mesh.mesh is ArrayMesh and mesh.material_override == null, "original mesh/material, not a primitive replacement")
	check(presentation.relaxed_arm.visible and not presentation.gripping_arm.visible, "empty hand uses relaxed reference pose")
	check(presentation.relaxed_arm.find_children("*", "MeshInstance3D", true, false).size() == 2, "relaxed pose uses original skin and sleeve")
	check(is_equal_approx(presentation.relaxed_arm.rotation.y, PI + presentation.ARM_TWIST), "reference forearm twist")
	key(KEY_E)
	await process_frame
	check(presentation.inventory_open and player.controls_locked, "E opens inventory and locks player")
	Input.action_press("move_forward")
	for i in range(5):
		await physics_frame
	check(absf(player.velocity.z) < 0.01, "inventory prevents walking")
	Input.action_release("move_forward")
	check(presentation.add_item("test", "TEST", 2), "add item")
	check(presentation.add_item("test", "TEST", 3), "stack item")
	check(presentation.items[0].amount == 5, "stack quantity")
	check(not presentation.remove_item("test", 6), "reject insufficient quantity")
	check(presentation.remove_item("test", 5) and presentation.items[0].is_empty(), "remove stack")
	check(presentation.hand.position.z > -0.5, "hand is closer to the camera")
	check(presentation.hand_view.anchor_left == 0.5 and presentation.hand_view.anchor_bottom == 1.0, "viewmodel follows window size")
	check(not presentation.equip_item("crimping_tool"), "cannot equip an unowned item")
	var pose_ids := []
	for id in presentation.HELD_ITEMS.TOOLS:
		check(presentation.preview_item(id), "preview real tool " + id)
		check(presentation.gripping_arm.visible and not presentation.relaxed_arm.visible, "tool switches to grip pose")
		check(presentation.gripping_arm.name == "GripPose_" + id, "each item has its own fitted pose")
		check(not pose_ids.has(presentation.gripping_arm.get_instance_id()), "pose is not shared with a different tool")
		pose_ids.append(presentation.gripping_arm.get_instance_id())
		var visible_poses := 0
		for cached_pose in presentation._grip_poses.values():
			if cached_pose.visible:
				visible_poses += 1
		check(visible_poses == 1, "exactly one equipped hand visible")
		check(presentation.held_model.get_parent() == presentation.grip, "tool follows hand grip")
		check(presentation.grip.get_child_count() == 1, "switching leaves only one tool")
		check(presentation.held_model.find_children("*", "MeshInstance3D", true, false).size() > 0, "tool has real meshes")
	check(presentation.items.all(func(item): return item.is_empty()), "preview never grants inventory")
	var cache_size: int = presentation._grip_poses.size()
	for repeat in range(3):
		presentation.preview_item("crimping_tool")
		presentation.preview_item("cable_tester")
	check(presentation._grip_poses.size() == cache_size, "repeated swaps reuse cached hand poses")
	check(not presentation.preview_item("unknown"), "unknown preview rejected")
	presentation.preview_item("")
	check(presentation.held_model == null, "end preview returns empty hands")
	check(presentation.relaxed_arm.visible and not presentation.gripping_arm.visible, "empty hands restores relaxed pose")
	presentation.add_item("crimping_tool", "คีมย้ำสาย LAN", 2)
	presentation.select_slot(0)
	check(not presentation._equip_button.disabled, "owned tool enables equip button")
	check(presentation.equip_item("crimping_tool"), "equip owned item")
	presentation.preview_item("cable_tester")
	presentation.preview_item("")
	check(presentation.held_model.name == "Held_crimping_tool", "preview restores equipped item")
	presentation.remove_item("crimping_tool")
	check(presentation.held_model != null, "partial stack removal keeps equipment")
	presentation.remove_item("crimping_tool")
	check(presentation.held_model == null and presentation.equipped_id == "", "last item removal clears hand")
	check(not presentation.hand_view.visible, "inventory hides hand and held items")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/NetSim3D/tmp/godot-4.7.1/player-inventory.png")
	key(KEY_ESCAPE)
	await process_frame
	await process_frame
	print("ESC_STATE ", presentation.inventory_open, " ", player.controls_locked)
	check(not presentation.inventory_open and not player.controls_locked, "Esc closes inventory")
	key(KEY_E)
	await process_frame
	await process_frame
	key(KEY_E)
	await process_frame
	await process_frame
	check(not presentation.inventory_open and not player.controls_locked, "E toggles inventory closed")
	presentation.add_item("crimping_tool", "คีมย้ำสาย LAN")
	presentation.open_inventory()
	presentation.select_slot(0)
	presentation._equip_button.pressed.emit()
	check(presentation.equipped_id == "crimping_tool" and not presentation.inventory_open, "equip UI closes inventory")
	await process_frame
	await process_frame
	check(presentation.hand_view.visible, "equipped hand visible during gameplay")
	presentation.remove_item("crimping_tool")
	presentation.add_item("unsupported", "ไม่มีโมเดล")
	presentation.select_slot(0)
	check(presentation._equip_button.disabled and not presentation.equip_item("unsupported"), "unsupported item cannot equip")
	presentation.remove_item("unsupported")
	player.set_controls_locked(true)
	key(KEY_E)
	await process_frame
	await process_frame
	check(not presentation.inventory_open, "E does not steal computer/dialog input")
	check(not presentation.hand_view.visible, "computer interaction hides viewmodel")
	player.set_controls_locked(false)
	presentation.preview_item("crimping_tool")
	presentation.unequip_item()
	check(presentation.held_model == null and presentation.preview_id == "", "empty hands clears preview")
	Input.action_press("move_forward")
	for i in range(30):
		await physics_frame
	check(presentation.blend > 0.5, "walk animation active")
	check(presentation.hand.rotation_degrees.is_equal_approx(presentation.HAND_ROTATION), "walking preserves requested hand orientation")
	Input.action_release("move_forward")
	presentation.play_use()
	check(presentation.use_time > 0, "hand interaction gesture")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/NetSim3D/tmp/godot-4.7.1/player-right-hand.png")
	for i in range(50):
		await physics_frame
	check(presentation.blend < 0.01, "idle settles")
	check(InputMap.action_get_events("interact")[0].physical_keycode == KEY_F, "F is interact")
	print("PLAYER_PRESENTATION_VALID failures=", failures)
	quit(1 if failures else 0)
