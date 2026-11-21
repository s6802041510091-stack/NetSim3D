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
	check(not InputMap.has_action("inventory"), "no inventory action")
	check(not presentation.has_method("add_item") and not presentation.has_method("open_inventory"), "inventory removed")
	key(KEY_E)
	await process_frame
	await process_frame
	check(not player.controls_locked, "E with nothing in view does not lock the player")
	check(presentation.hand.position.z > -0.5, "hand is closer to the camera")
	check(presentation.hand_view.anchor_left == 0.5 and presentation.hand_view.anchor_bottom == 1.0, "viewmodel follows window size")
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
	var cache_size: int = presentation._grip_poses.size()
	for repeat in range(3):
		presentation.preview_item("crimping_tool")
		presentation.preview_item("cable_tester")
	check(presentation._grip_poses.size() == cache_size, "repeated swaps reuse cached hand poses")
	check(not presentation.preview_item("unknown"), "unknown preview rejected")
	presentation.preview_item("")
	check(presentation.held_model == null, "end preview returns empty hands")
	check(presentation.relaxed_arm.visible and not presentation.gripping_arm.visible, "empty hands restores relaxed pose")
	player.set_controls_locked(true)
	await process_frame
	check(not presentation.hand_view.visible, "computer interaction hides viewmodel")
	player.set_controls_locked(false)
	await process_frame
	check(presentation.hand_view.visible, "hand visible again during gameplay")
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
		root.get_texture().get_image().save_png(OS.get_environment("NETSIM_SHOTS").path_join("player-right-hand.png") if OS.has_environment("NETSIM_SHOTS") else "user://player-right-hand.png")
	for i in range(50):
		await physics_frame
	check(presentation.blend < 0.01, "idle settles")
	check(InputMap.action_get_events("interact")[0].physical_keycode == KEY_E, "E is interact")
	print("PLAYER_PRESENTATION_VALID failures=", failures)
	quit(1 if failures else 0)
