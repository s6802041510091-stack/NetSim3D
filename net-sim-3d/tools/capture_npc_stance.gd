extends SceneTree

## Front views of the walking NPCs, to judge how wide they walk.
## Lines up a teacher, students and the cleaner in the corridor, frozen in the
## walk cycle at three moments (legs passing, mid stride, full stride).
## Run with a window: godot --path net-sim-3d -s res://tools/capture_npc_stance.gd -- <out_dir>
## Closer view: set STANCE_FOV (degrees), STANCE_X (metres sideways) and
## STANCE_D (camera distance), e.g. 30, 0.3 and 3.2; STANCE_Y is the height
## looked at (0.12 for the ankles).
const NAMES := ["TeacherMale", "TeacherFemale", "MaleMullet", "FemaleBob", "FemaleWendy", "Cleaner"]
const PHASES := {"pass": 0.0, "mid": PI * 0.25, "stride": PI * 0.5}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://stance"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1400, 640)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 10:
		await physics_frame
	(map.get_node("ITSupportPlayer") as Node3D).visible = false
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for other: Node in map.find_children("*", "NpcCharacter", true, false):
		if not NAMES.has(String(other.name)):
			(other as Node3D).visible = false
	var npcs: Array[NpcCharacter] = []
	for n in NAMES:
		var found := map.find_children(n, "NpcCharacter", true, false)
		if found.is_empty():
			push_error("missing " + n)
			continue
		var c := found[0] as NpcCharacter
		if c.seated:
			c.seated = false
			(c.get_node("Visual") as Node3D).position = Vector3.ZERO
		c.set_physics_process(false)
		c.set_process(false)
		npcs.append(c)
	# A clear stretch of the corridor floor.
	var origin := Vector3(-4.6, 0.02, -12.5)
	for i in npcs.size():
		var c := npcs[i]
		c.global_position = origin + Vector3((i - (npcs.size() - 1) / 2.0) * 0.62, 0, 0)
		c.rotation = Vector3(0, PI, 0) # facing -Z, toward the camera
	var camera := Camera3D.new()
	camera.fov = float(OS.get_environment("STANCE_FOV")) if OS.get_environment("STANCE_FOV") != "" else 40.0
	map.add_child(camera)
	camera.make_current()
	var aim_x := float(OS.get_environment("STANCE_X"))
	var aim_y := float(OS.get_environment("STANCE_Y")) if OS.get_environment("STANCE_Y") != "" else 0.6
	var distance := float(OS.get_environment("STANCE_D")) if OS.get_environment("STANCE_D") != "" else 6.2
	camera.global_position = origin + Vector3(aim_x, aim_y + 0.15, -distance)
	camera.look_at(origin + Vector3(aim_x, aim_y, 0))
	for key: String in PHASES:
		for c in npcs:
			c._walk_blend = 1.0
			c._phase = PHASES[key]
			if c is StudentCharacter:
				(c as StudentCharacter)._seat_blend = 0.0
				(c as StudentCharacter)._apply_animation_pose(true)
			else:
				c._pose_walk()
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("stance_" + key + ".png"))
		print("SHOT ", key)
	quit()
