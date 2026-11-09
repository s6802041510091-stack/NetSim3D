extends SceneTree

## Frame-time profile of a level, run WITH a window (not --headless):
##   godot --path net-sim-3d -s res://tools/profile_level.gd -- [level] [WxH] [no_town]
## Loads the school like the menu does, then for each viewpoint records the
## average and worst frame time, draw calls, objects and primitives drawn.
## Prints PROFILE lines; changes nothing on disk.

const VIEWS := {
	"it_room_spawn": [Vector3(-12.47, 1.65, -42.6), Vector3(-17.0, 1.2, -42.5)],
	"corridor": [Vector3(-7.6, 1.65, -30.0), Vector3(-7.6, 1.4, -5.0)],
	"classroom_20pcs": [Vector3(8.0, 1.7, -8.6), Vector3(0.0, 0.8, 4.0)],
	"classroom_window_town": [Vector3(3.0, 1.65, 0.0), Vector3(20.0, 2.0, 0.0)],
	"server_room": [Vector3(-2.6, 1.7, -36.6), Vector3(-0.5, 1.0, -41.0)],
	"teachers_room": [Vector3(-1.5, 1.65, -20.0), Vector3(8.0, 1.0, -20.0)],
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var level := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		var parts := args[1].split("x")
		root.size = Vector2i(int(parts[0]), int(parts[1]))
	print("PROFILE device=", RenderingServer.get_video_adapter_name(), " size=", root.size, " vsync=", DisplayServer.window_get_vsync_mode())
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0 := Time.get_ticks_msec()
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	root.get_node("GameFlow").configure_level(map, level)
	root.add_child(map)
	print("PROFILE load_ms=", Time.get_ticks_msec() - t0)
	if "no_town" in args:
		map.get_node("ExteriorTown").queue_free()
	var player := map.get_node("ITSupportPlayer")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	camera.fov = 75.0
	map.add_child(camera)
	camera.make_current()
	for i in 60:
		await process_frame
	for view_name: String in VIEWS:
		var pose: Array = VIEWS[view_name]
		camera.global_position = pose[0]
		camera.look_at(pose[1])
		# Warm up (shader compilation), then measure.
		var first_frame := Time.get_ticks_usec()
		await process_frame
		var warm_ms := (Time.get_ticks_usec() - first_frame) / 1000.0
		for i in 30:
			await process_frame
		var worst := 0.0
		var total := 0.0
		var frames := 120
		var last := Time.get_ticks_usec()
		for i in frames:
			await process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			total += ms
			worst = maxf(worst, ms)
		print("PROFILE view=%s avg_ms=%.2f fps=%.0f worst_ms=%.1f first_frame_ms=%.1f draw_calls=%d objects=%d primitives=%d" % [
			view_name, total / frames, 1000.0 * frames / total, worst, warm_ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PROFILE memory_static_mb=%.0f video_mem_mb=%.0f nodes=%d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit(0)
