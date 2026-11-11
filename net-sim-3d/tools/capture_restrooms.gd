extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	var output:="D:/NetSim3D/Preview/โรงเรียนและเมือง/restrooms/"+(args[0] if args.size()>0 else "after")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	var map:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.get_node("ITSupportPlayer").process_mode=Node.PROCESS_MODE_DISABLED
	for child in root.find_children("*","CanvasLayer",true,false):child.hide()
	var camera:=Camera3D.new()
	map.add_child(camera)
	camera.fov=66;camera.make_current()
	for view in [
		["women-room-finished",Vector3(-19.8,1.7,-15.4),Vector3(-13.8,1.1,-13.5),78],
		["men-room-finished",Vector3(-12,1.7,-20.1),Vector3(-18,1,-21.3),80],
		["women-overview",Vector3(-11.9,1.65,-13.2),Vector3(-17,.95,-11)],
		["women-basins",Vector3(-13,1.6,-13.8),Vector3(-13,1.05,-16.9)],
		["women-all-basins",Vector3(-15.5,1.65,-13.3),Vector3(-15.5,1.1,-16.9),90],
		["women-entrance-wall",Vector3(-12.1,1.65,-13.3),Vector3(-10.8,1.2,-15.6),82],
		["women-toilet",Vector3(-20.56,1.45,-11.45),Vector3(-20.56,.50,-10.3)],
		["men-overview",Vector3(-11.9,1.65,-21.1),Vector3(-17.8,1,-19.7)],
		["men-stalls",Vector3(-13,1.65,-21),Vector3(-18,1,-18.6),82],
		["men-urinals",Vector3(-18.8,1.55,-21.5),Vector3(-21.1,1,-21.5),92],
		["men-basins",Vector3(-15.5,1.65,-20.2),Vector3(-15.5,1.05,-24),90]]:
		camera.global_position=view[1];camera.look_at(view[2])
		camera.fov=view[3] if view.size()>3 else 66
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(view[0]+".png"))
	print("RESTROOM_CAPTURE_OK ",output)
	quit()
