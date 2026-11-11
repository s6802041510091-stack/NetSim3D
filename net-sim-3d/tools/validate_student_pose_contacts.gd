extends SceneTree

const Audit=preload("res://tools/audit_student_animation.gd")
const BENCHES=["BenchLeft03","BenchRight01","BenchLeft01","BenchRight03","BenchRight04"]
var failures:=0
var measurements:Array=[]

func _initialize() -> void:call_deferred("_run")

func check(ok:bool,note:String) -> void:
	if not ok:
		failures+=1
		push_error("POSE_CONTACT: "+note)

func segment_in_rect(a:Vector2,b:Vector2,rect:Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):return true
	var lo:=rect.position
	var hi:=rect.end
	var corners:=[lo,Vector2(hi.x,lo.y),hi,Vector2(lo.x,hi.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null:return true
	return false

func cloth_crossings(mesh:MeshInstance3D,sk:Skeleton3D,inverse:Transform3D) -> int:
	var world:=Audit.skin_points(mesh,sk)
	var crossings:=0
	var offset:=0
	for surface in mesh.mesh.get_surface_count():
		var a:=mesh.mesh.surface_get_arrays(surface)
		var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX]
		for j in range(0,indices.size(),3):
			var tri:Array[Vector3]=[]
			for k in 3:tri.append(inverse*world[offset+indices[j+k]])
			var points:Array[Vector2]=[]
			for k in 3:
				var p:=tri[k]
				var q:=tri[(k+1)%3]
				# Plane 3mm under the seat top: ignore legitimate soft contact.
				if (p.y-.447)*(q.y-.447)<0:
					var at:=p.lerp(q,(.447-p.y)/(q.y-p.y))
					points.append(Vector2(at.x,at.z))
			if points.size()>=2:
				if segment_in_rect(points[0],points[1],Rect2(-.745,-.225,1.49,.216)) or segment_in_rect(points[0],points[1],Rect2(-.745,.009,1.49,.216)):
					crossings+=1
		offset+=(a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return crossings

func measure(s:StudentCharacter,fraction:float,way:String,bench:Node3D) -> void:
	var low:=INF
	var crossings:=0
	for mesh:MeshInstance3D in s.get_node("Visual").find_children("*","MeshInstance3D",true,false):
		if "Shoes" in mesh.name:
			for point in Audit.skin_points(mesh,s.skeleton):low=minf(low,point.y)
		if "skirt" in mesh.name or "shorts" in mesh.name:
			crossings+=cloth_crossings(mesh,s.skeleton,bench.global_transform.affine_inverse())
	check(low>-.004 and low<.012,"%s %s %.2f sole at %.4fm"%[s.student_id,way,fraction,low])
	check(crossings==0,"%s %s %.2f has %d cloth triangles through seat"%[s.student_id,way,fraction,crossings])
	measurements.append({"id":s.student_id,"way":way,"fraction":fraction,"sole_min_y":low,"seat_triangle_crossings":crossings})

func _run() -> void:
	var map:Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(map)
	await physics_frame
	var life:StudentLife=map.get_node("CorridorStudents")
	var player:CharacterBody3D=map.get_node("ITSupportPlayer")
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position=Vector3(3,.02,0)
	for s in life.students:s.process_mode=Node.PROCESS_MODE_DISABLED
	for i in life.students.size():
		var s:=life.students[i]
		var bench:=life.bench_for(BENCHES[i])
		var step:=life.seat(BENCHES[i],20)
		s.routine=[step]
		s.step_index=0
		s.global_position=step["point"]
		s.rotation.y=life.bench_for(BENCHES[i]).rotation.y
		s._seat_blend=0
		s._arrive()
		for way in ["sit","stand"]:
			for j in 21:
				var fraction:=j/20.0
				s.phase=way
				s._elapsed=fraction*1.1-.001
				s._seat_transition(.001)
				s._apply_animation_pose()
				measure(s,fraction,way,bench)
		print("POSE_CONTACT_CHECKED ",s.student_id," samples=42")
		# Walking: at least one sole stays grounded for every sampled stride.
		s._seat_blend=0
		s.activity="walk"
		s._walk_blend=1
		for j in 24:
			s._phase=j*TAU/24.0
			s._apply_animation_pose()
			var soles:=s._support.sole_heights()
			check(absf(minf(soles["L"],soles["R"])-.003)<.008,s.student_id+" walk has no grounded sole")
	# A player entering the swept stand-up path must stop the transition.
	var s:=life.students[2]
	s.routine=[life.seat(BENCHES[2],20)]
	s.step_index=0
	s.global_position=s.routine[0]["point"]
	s._arrive()
	s.global_position=s._seat
	s._seat_blend=1
	s.phase="stand"
	s._elapsed=0
	var front:=s._bench.global_basis.z
	player.global_position=s._approach+front*.10
	await physics_frame
	for j in 30:s._seat_transition(1.0/60)
	check(s.global_position.distance_to(s._seat)<.10,"standing student passed through player")
	player.global_position=Vector3(3,.02,0)
	await physics_frame
	for j in 90:
		if s.phase=="stand":s._seat_transition(1.0/60)
	check(s._seat_blend<.01 and s.global_position.distance_to(s._approach)<.01,"stand-up did not resume after player left")
	var out:="D:/NetSim3D/Preview/โถงทางเดิน/students/audit-after"
	DirAccess.make_dir_recursive_absolute(out)
	var file:=FileAccess.open(out.path_join("dense-contacts.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"  "))
	print("STUDENT_POSE_CONTACTS_VALID samples=210 walking_samples=120 swept_player_block=pass" if failures==0 else "STUDENT_POSE_CONTACTS_INVALID failures="+str(failures))
	quit(1 if failures else 0)
