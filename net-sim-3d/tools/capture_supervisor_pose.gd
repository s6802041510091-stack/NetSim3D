extends SceneTree

## Close-ups of the seated supervisor's hands on the keyboard and mouse
## (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_supervisor_pose.gd -- <out_dir>

var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://.saves/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	for i in 10:
		await process_frame
	var supervisor: NpcCharacter = map.get_node("ITSupportSupervisor")
	var sk := supervisor.skeleton
	for side in ["L", "R"]:
		var target := supervisor.get_node_or_null(supervisor.left_hand_target if side == "L" else supervisor.right_hand_target) as Node3D
		var wrist := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("wrist." + side)).origin
		print("WRIST ", side, " ", wrist, " target ", target.global_position if target else Vector3.ZERO,
			" off ", wrist.distance_to(target.global_position) if target else -1.0)
	var camera := Camera3D.new()
	camera.fov = 55.0
	map.add_child(camera)
	camera.make_current()
	var desk := Vector3(-18.2, 0.78, -42.6)
	# The player's usual view: standing beside the desk, from the right (+Z) side.
	var views := {
		"pose_player_view": [supervisor.global_position + Vector3(1.6, 1.6, 1.4), desk + Vector3(-0.3, 0.1, 0)],
		"pose_side_right": [Vector3(-18.55, 1.05, -41.55), Vector3(-18.45, 0.85, -42.45)],
		"pose_side_left": [Vector3(-18.45, 1.1, -43.5), Vector3(-18.45, 0.85, -42.6)],
		"pose_over_desk": [Vector3(-17.75, 1.35, -42.5), Vector3(-18.45, 0.85, -42.55)],
		"pose_top": [Vector3(-18.35, 1.9, -42.55), Vector3(-18.34, 0.78, -42.56)],
		# Low close-ups: do the hands sink into the mouse / keyboard?
		"close_mouse": [Vector3(-18.12, 0.84, -42.12), Vector3(-18.21, 0.785, -42.36)],
		"close_keys": [Vector3(-18.02, 0.86, -42.98), Vector3(-18.24, 0.78, -42.74)],
	}
	supervisor.work_at_desk = false
	for name: String in views:
		camera.global_position = views[name][0]
		camera.look_at(views[name][1])
		await _shot(name)
	# Right hand typing on the keyboard instead of holding the mouse.
	supervisor._right_on_keys = true
	supervisor._update_hands()
	for name: String in ["pose_side_right", "pose_top", "close_keys"]:
		camera.global_position = views[name][0]
		camera.look_at(views[name][1])
		await _shot("typing_" + name.trim_prefix("pose_"))
	# How high the hand joints sit over the keyboard (key tops 0.774 m) and
	# the mouse (top 0.788 m): finger bones need ~0.8 cm, the palm ~1.5 cm.
	for state in ["keys", "keys_pressed", "mouse", "mouse_click"]:
		supervisor._right_on_keys = state.begins_with("keys")
		for side in supervisor._taps:
			supervisor._taps[side] = [0.0, 0.0, 0.0, 0.0]
		if state == "keys_pressed":
			supervisor._taps["L"].fill(supervisor.TAP_TIME * 0.5)
			supervisor._taps["R"].fill(supervisor.TAP_TIME * 0.5)
		if state == "mouse_click":
			supervisor._taps["R"][0] = supervisor.TAP_TIME * 0.5
		supervisor._update_hands()
		for side in ["L", "R"]:
			var line := "HEIGHT %s %s" % [state, side]
			for bone_name in ["wrist", "finger2-1", "finger3-1", "finger5-1", "finger2-3", "finger3-3", "finger4-3", "finger5-3"]:
				var bone := sk.find_bone(bone_name + "." + side)
				var pose := sk.get_bone_global_pose(bone)
				var p := sk.global_transform * pose.origin
				line += "  %s=%.3f" % [bone_name, p.y]
				if bone_name.ends_with("-3"):
					var tip := sk.global_transform * (pose.origin + pose.basis.y.normalized() * 0.02)
					line += "(tip %.3f x%.3f)" % [tip.y, tip.x]
			print(line)
	for side in supervisor._taps:
		supervisor._taps[side] = [0.0, 0.0, 0.0, 0.0]
	supervisor._right_on_keys = true
	supervisor._update_hands()
	# Cost of one hand update (the game runs it up to 30 times a second).
	var start := Time.get_ticks_usec()
	for i in 30:
		supervisor._update_hands()
	print("HAND_UPDATE_US ", (Time.get_ticks_usec() - start) / 30)
	supervisor._right_on_keys = false
	supervisor._update_hands()
	supervisor.work_at_desk = true
	# Turned toward a player standing to the side, as when talking.
	var stand := Node3D.new()
	map.add_child(stand)
	stand.global_position = supervisor.global_position + Vector3(2.3, 1.6, 0.9)
	supervisor.turn_time = 0.05
	await supervisor.turn_to(stand)
	camera.global_position = supervisor.global_position + Vector3(1.8, 1.5, 1.2)
	camera.look_at(supervisor.global_position + Vector3(0.2, 0.9, 0))
	await _shot("pose_turned")
	camera.global_position = Vector3(-18.55, 1.05, -41.55)
	camera.look_at(Vector3(-18.45, 0.85, -42.45))
	await _shot("pose_turned_side")
	print("CAPTURE_DONE ", out_dir)
	quit()
