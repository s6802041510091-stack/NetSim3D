extends SceneTree

## GPU keyframes plus CPU-skinned geometry measurements, not collider-only QA.
var output := "D:/NetSim3D/Preview/โถงทางเดิน/students/audit-before"
var camera: Camera3D
var label: Label
var rows: Array = []
const BENCHES := ["BenchLeft03", "BenchRight01", "BenchLeft01", "BenchRight03", "BenchRight04"]

func _initialize() -> void:
	call_deferred("_run")

static func skin_points(mesh: MeshInstance3D, sk: Skeleton3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var transforms: Array[Transform3D] = []
	for i in mesh.skin.get_bind_count():
		var b := mesh.skin.get_bind_bone(i)
		if b < 0:b=sk.find_bone(mesh.skin.get_bind_name(i))
		transforms.append(sk.global_transform * sk.get_bone_global_pose(b) * mesh.skin.get_bind_pose(i))
	for surface in mesh.mesh.get_surface_count():
		var a := mesh.mesh.surface_get_arrays(surface)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		if mesh.mesh.get_blend_shape_count()>0:
			var morphs:=mesh.mesh.surface_get_blend_shape_arrays(surface)
			var corrected:PackedVector3Array=morphs[0][Mesh.ARRAY_VERTEX]
			var amount:=mesh.get_blend_shape_value(0)
			vs=vs.duplicate()
			for i in vs.size():vs[i]=vs[i].lerp(corrected[i],amount)
		var joints: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		if joints.is_empty():continue
		var stride: int = joints.size()/vs.size()
		for i in vs.size():
			var posed := Vector3.ZERO
			for k in stride:
				posed += (transforms[joints[i*stride+k]]*vs[i])*weights[i*stride+k]
			points.append(posed)
	return points

func metrics(s: StudentCharacter, tag: String) -> void:
	var soles := INF
	var sole_rear := INF
	var seat_hits := 0
	var back_hits := 0
	var by_mesh := {}
	var inverse := s._bench.global_transform.affine_inverse()
	for mesh: MeshInstance3D in s.get_node("Visual").find_children("*","MeshInstance3D",true,false):
		if mesh.skin == null or not ("Shoes" in mesh.name or "Body" in mesh.name or "skirt" in mesh.name or "shorts" in mesh.name or "Shirt" in mesh.name):continue
		var mesh_hits := 0
		var low_over_seat := INF
		for p in skin_points(mesh,s.skeleton):
			var at := inverse*p
			if "Shoes" in mesh.name:
				soles=minf(soles,p.y)
				sole_rear=maxf(sole_rear if sole_rear != INF else -INF,at.z)
			if absf(at.x)<.74:
				if at.y>.417 and at.y<.447 and absf(at.z)<.225 and absf(at.z)>.009:
					seat_hits+=1
					mesh_hits+=1
				if absf(at.z)<.225 and at.y>.20 and at.y<.70:low_over_seat=minf(low_over_seat,at.y)
				if absf(at.z+.198)<.011 and ((at.y>.6005 and at.y<.6995) or (at.y>.7155 and at.y<.8145)):back_hits+=1
		by_mesh[String(mesh.name)]={"hits":mesh_hits,"min_above_seat":low_over_seat if low_over_seat!=INF else null}
	rows.append({"id":s.student_id,"tag":tag,"sole_min_y":soles,"seat_penetrating_vertices":seat_hits,"back_penetrating_vertices":back_hits,"by_mesh":by_mesh,"root":str(s.global_position)})
	print("POSE_AUDIT ",JSON.stringify(rows[-1]))

func capture() -> Image:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()>0:output=args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(640,640)
	var map: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var life: StudentLife=map.get_node("CorridorStudents")
	map.get_node("ITSupportPlayer").process_mode=Node.PROCESS_MODE_DISABLED
	for child in root.find_children("*","CanvasLayer",true,false):child.hide()
	for s in life.students:s.process_mode=Node.PROCESS_MODE_DISABLED
	camera=Camera3D.new()
	map.add_child(camera)
	camera.fov=53
	camera.make_current()
	var hud:=CanvasLayer.new()
	root.add_child(hud)
	label=Label.new()
	hud.add_child(label)
	label.position=Vector2(16,16)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",7)
	label.add_theme_font_size_override("font_size",22)
	for i in life.students.size():
		var s:=life.students[i]
		var bench:=life.bench_for(BENCHES[i])
		var step:=life.seat(BENCHES[i],30)
		s.routine=[step]
		s.step_index=0
		s.global_position=step["point"]
		s.rotation.y=bench.rotation.y
		s._seat_blend=0
		s._arrive()
		var front:=bench.global_basis.z
		var across:=bench.global_basis.x
		camera.global_position=bench.global_position+front*2.65+across*1.9+Vector3(0,1.35,0)
		camera.look_at(bench.global_position+front*.1+Vector3(0,.85,0))
		var sheet:=Image.create(1920,1280,false,Image.FORMAT_RGBA8)
		for j in 6:
			var fraction: float=[0,.25,.5,.75,1,0][j]
			s.phase="sit" if j<5 else "stand"
			s._elapsed=(fraction if j<5 else 1.0)*1.1-.001
			s._seat_transition(.001)
			s._process(.06)
			label.text=s.student_id+" | "+("sit %d%%"%int(fraction*100) if j<5 else "stand end")
			var frame:=await capture()
			sheet.blit_rect(frame,Rect2i(0,0,640,640),Vector2i((j%3)*640,(j/3)*640))
			if j<5:metrics(s,label.text)
			if j==4:frame.save_png(output.path_join(s.student_id+"-seated.png"))
		sheet.save_png(output.path_join(s.student_id+"-sit-stand-sheet.png"))
		# Walking phases, isolated from turn/transition, all at the same spot.
		s.seated=false
		s._seat_blend=0
		s.activity="walk"
		s.phase="walk"
		s._walk_blend=1
		s.global_position=bench.global_position+front*1.15
		var walk_sheet:=Image.create(1920,640,false,Image.FORMAT_RGBA8)
		for j in 3:
			s._phase=[0,PI/2,PI][j]
			s._process(.06)
			label.text=s.student_id+" | walk phase "+str(j)
			walk_sheet.blit_rect(await capture(),Rect2i(0,0,640,640),Vector2i(j*640,0))
		walk_sheet.save_png(output.path_join(s.student_id+"-walk-sheet.png"))
	var f:=FileAccess.open(output.path_join("pose-metrics.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"  "))
	print("STUDENT_POSE_AUDIT_DONE ",output)
	quit()
