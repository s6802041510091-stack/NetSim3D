extends SceneTree

## Screenshots of the Mission 1 round for a visual check (run WITH a window):
##   godot --path net-sim-3d -s res://tools/capture_mission_01.gd -- <out_dir>
## Uses throw-away save/progress files.

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
	Mission01SaveStore.save_path = "user://capture_mission_01.json"
	Mission01SaveStore.clear()
	GameProgress.save_path = "user://capture_progress.json"
	GameProgress.clear()

	# 1. NetPlan EDU pop-up with the reason question open.
	var app := (load(NetPlanEdu.DATA_PATH.get_base_dir().get_base_dir() + "/scenes/netplan_edu.tscn") as PackedScene).instantiate() as NetPlanEdu
	app.use_save_file = false
	root.add_child(app)
	await process_frame
	app.choose_answer(1, "Router")
	app.answer_device(2, "Switched Hub 8 Port", Mission01Data.DECISION_REJECT)
	var popup: EquipmentPopup = app._popup
	popup.choose("Shared Hub 24 Port")
	popup.decide(Mission01Data.DECISION_REJECT)
	popup.pick_reason(1)
	await _shot("m1_popup_reason")
	popup.cancel()
	await _shot("m1_netplan_plan")
	app.queue_free()

	# 2. The level: dialogue with the supervisor, objective, wall rack.
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 10:
		await process_frame
	var mission: Mission01Controller = map.get_node("Mission01")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	var supervisor: Node3D = map.get_node("ITSupportSupervisor")
	player.global_position = supervisor.global_position + Vector3(1.6, 0, 0)
	player.look_at(Vector3(supervisor.global_position.x, player.global_position.y, supervisor.global_position.z), Vector3.UP)
	player.camera.rotation.x = -0.12
	for i in 5:
		await physics_frame
	await _shot("m1_supervisor_prompt")
	mission._on_talked(player)
	await _shot("m1_dialogue")
	while mission.dialogue.is_open():
		mission.dialogue.advance(true)
	await _shot("m1_objective_after_briefing")
	# Gold arrow over the player's computer, seen from across the room.
	var pc: ComputerStation = (map.get_node("Computers") as ComputerManager).find_host("IT-PC-01")
	var screen_center: Vector3 = pc.screen.global_transform * pc.screen.get_aabb().get_center()
	player.global_position = supervisor.global_position + Vector3(1.0, 0, 1.2)
	player.look_at(Vector3(screen_center.x, player.global_position.y, screen_center.z), Vector3.UP)
	player.camera.rotation.x = -0.05
	for i in 5:
		await physics_frame
	await _shot("m1_arrow_on_computer")

	var camera := Camera3D.new()
	camera.fov = 70.0
	map.add_child(camera)
	camera.global_position = Vector3(6.2, 1.65, -6.6)
	camera.look_at(Vector3(8.2, 1.6, -9.5))
	camera.make_current()
	await _shot("m1_wall_rack")

	# 3. Summary with an example score.
	var state := Mission01State.new()
	var data := mission.data
	state.reset(data)
	for device in ["Router"]:
		state.record_reason(1, device, Mission01Data.DECISION_CHOOSE, 0, data)
		state.set_answer(1, device, 1)
	state.record_reason(2, "Shared Hub 24 Port", Mission01Data.DECISION_CHOOSE, 0, data)
	state.set_answer(2, "Shared Hub 24 Port", 1)
	state.record_reason(3, "Wireless Access Point", Mission01Data.DECISION_CHOOSE, 0, data)
	state.set_answer(3, "Wireless Access Point", 1)
	Mission01Validator.check(state, data)
	state.record_reason(2, "Switched Hub 24 Port", Mission01Data.DECISION_CHOOSE, 0, data)
	state.set_answer(2, "Switched Hub 24 Port", 1)
	Mission01Validator.check(state, data)
	mission.state = state
	mission.elapsed_sec = 412.0
	mission.finish(player)
	await _shot("m1_summary")
	Mission01SaveStore.clear()
	GameProgress.clear()
	print("CAPTURE_DONE ", out_dir)
	quit(0)
