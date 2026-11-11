class_name StudentLife
extends Node3D

## World-space, deliberately authored routes on this school's broad corridor.
## Each student has a different loop; seats and chat spots are not doorways.
var students: Array[StudentCharacter] = []
var player: CharacterBody3D
var furnishings: Node3D
var conversation_time := 0.0

func _ready() -> void:
	player = get_parent().get_node("ITSupportPlayer")
	furnishings = get_parent().get_node("CorridorFurnishings")
	for child in get_children():
		if child is StudentCharacter:
			students.append(child)
	for student in students:
		student.start_routine(self, routine_for(student.student_id))

func _physics_process(delta:float) -> void:
	var pair:Array[StudentCharacter]=[]
	for s in students:
		if s.student_id in ["two_block","wendy"] and s.activity=="chat" and s.phase=="hold":pair.append(s)
	conversation_time=conversation_time+delta if pair.size()==2 else 0.0

func is_speaking(student:StudentCharacter) -> bool:
	var id:="two_block" if fmod(conversation_time,9)<4.5 else "wendy"
	return student.student_id==id

func bench_for(bench_name: String) -> StaticBody3D:
	return furnishings.get_node(bench_name) as StaticBody3D

func chat_partner(student: StudentCharacter) -> StudentCharacter:
	var id := "wendy" if student.student_id == "two_block" else "two_block"
	for other in students:
		if other.student_id == id:
			return other
	return null

func stop(x: float, z: float, action := "idle", seconds := 1.0, yaw := 0.0) -> Dictionary:
	return {"point": Vector3(x, .02, z), "activity": action, "seconds": seconds, "yaw": yaw}

func seat(bench_name: String, seconds: float) -> Dictionary:
	var bench := bench_for(bench_name)
	var at := bench.global_position + bench.global_basis.z * .52
	var step := stop(at.x, at.z, "rest", seconds, bench.rotation.y)
	step["bench"] = bench_name
	return step

func routine_for(id: String) -> Array[Dictionary]:
	match id:
		"mullet":
			return [stop(-7.15, 3, "window", 4, 0), stop(-7.15, -18.8),
				seat("BenchLeft03", 13), stop(-7.15, -18.8),
				stop(-7.15, -4.8), stop(-8.05, -4.8, "shoes", 6, -PI/2), stop(-7.15, -4.8)]
		"two_block":
			return [stop(-5.35, -16.2, "chat", 11, PI/2), stop(-5.15, -5.3),
				seat("BenchRight01", 15), stop(-5.15, -5.3),
				stop(-4.15, -.7, "shoes", 5, PI/2), stop(-5.35, -4)]
		"bob":
			return [seat("BenchLeft01", 17), stop(-7.15, -.4),
				stop(-4.15, .7, "shoes", 7, PI/2), stop(-5.15, 4),
				stop(-5.15, 8.4, "window", 7, 0), stop(-7.15, 4), stop(-7.15, -.4)]
		"wendy":
			return [stop(-4.65, -16.2, "chat", 11, -PI/2), stop(-5.15, -18),
				stop(-5.15, -22.2), seat("BenchRight03", 16), stop(-5.15, -22.2), stop(-5.15, -18)]
		"layer":
			return [stop(-7.15, -42.7, "window", 8, PI), stop(-5.15, -40.4),
				seat("BenchRight04", 18), stop(-5.15, -40.4),
				stop(-5.15, -29.8, "idle", 6, -PI/2), stop(-7.15, -29.8, "idle", 2, -PI/2)]
	return []
