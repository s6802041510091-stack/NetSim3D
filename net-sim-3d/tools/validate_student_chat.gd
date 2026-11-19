extends SceneTree

## Students chatting in the corridor speak in turns: one speech bubble at a
## time over the speaker's head, lines in conversation order, seen only by a
## player close enough to overhear, gone when the chat ends.
## Run: godot --headless --path net-sim-3d -s res://tools/validate_student_chat.gd
## With a window and `-- <out_dir>` it also saves screenshots (set
## NETSIM_L10N_AUDIT=<file> for English without touching the saved language).
const StudentLifeScript := preload("res://scripts/npc/student_life.gd")

var failures := 0
var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, note: String) -> void:
	print("  ok   " if ok else "  FAIL ", note)
	if not ok:
		failures += 1


func _bubbles(life: Node) -> Array[Label3D]:
	var found: Array[Label3D] = []
	for child in life.get_children():
		if child is Label3D and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _shot(name: String) -> void:
	if out_dir == "":
		return
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	(map.get_node("CorridorStudents") as StudentLife).random_seed = 7
	root.get_node("GameFlow").configure_level(map, 1)
	root.add_child(map)
	for i in 5:
		await physics_frame
	var life: StudentLife = map.get_node("CorridorStudents")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.set_physics_process(false)
	if out_dir != "":
		player.visible = false # the test camera stands where the player is
	# Every conversation alternates speakers and has something to say.
	for talk: Array in StudentLifeScript.CHAT_LINES:
		check(talk.size() >= 4 and talk[0][0] == 0, "conversation of 4+ lines opened by speaker 0: " + str(talk[0][1]))
		for i in range(1, talk.size()):
			check(talk[i][0] != talk[i - 1][0], "speakers take turns: " + str(talk[i][1]))

	# The standing pair at chat_e1 (as at the start of every level).
	var spot: Array = life.chat_spots["chat_e1"]
	var middle: Vector3 = (spot[0] + spot[1]) * 0.5
	var group := ""
	for s in life.students:
		if s.chat_group != "" and s.global_position.distance_to(spot[0]) < 0.2:
			group = s.chat_group
	check(group != "", "a pair is chatting at chat_e1")
	if group == "":
		quit(1)
		return
	var g: Dictionary = life.groups[group]
	# Player across the corridor, close enough to overhear.
	player.global_position = middle + Vector3(-2.6, 0.0, 0.4)
	var camera := Camera3D.new()
	camera.fov = 60.0
	map.add_child(camera)
	camera.make_current()
	camera.global_position = middle + Vector3(-2.9, 1.55, 0.2)
	camera.look_at(middle + Vector3(0, 1.45, 0))

	var heard: Array[String] = []
	var speakers: Array = []
	var talk_index: int = g["talk"]
	var max_bubbles := 0
	var t := 0.0
	var shots := 0
	while t < 40.0 and life.groups.has(group):
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var shown := _bubbles(life)
		var here := shown.filter(func(b: Label3D): return Vector2(b.global_position.x - middle.x, b.global_position.z - middle.z).length() < 2.0)
		max_bubbles = maxi(max_bubbles, here.size())
		var bubble: Label3D = g.get("bubble")
		if bubble != null and is_instance_valid(bubble) and (heard.is_empty() or heard[-1] != bubble.text):
			heard.append(bubble.text)
			speakers.append(g["speaker"])
			check(bubble.visible, "bubble shows to a player 2.6 m away: " + bubble.text)
			var head: Vector3 = (g["speaker"] as StudentCharacter).skeleton.global_transform * (g["speaker"] as StudentCharacter).skeleton.get_bone_global_pose((g["speaker"] as StudentCharacter).skeleton.find_bone("head")).origin
			check(absf(bubble.global_position.x - head.x) < 0.05 and absf(bubble.global_position.z - head.z) < 0.05 and bubble.global_position.y > head.y + 0.2, "bubble over the speaker's head")
			check(life.is_speaking(g["speaker"]) and not life.is_speaking(life.chat_partner(g["speaker"])), "only the speaker gestures")
			if shots < 2 and heard.size() in [1, 2]:
				await create_timer(0.4).timeout
				await _shot("student_chat_%d" % heard.size())
				shots += 1
		if g["talk"] != talk_index and heard.size() >= (StudentLifeScript.CHAT_LINES[talk_index] as Array).size():
			break
	var expected: Array = StudentLifeScript.CHAT_LINES[talk_index]
	check(heard.size() == expected.size(), "the whole conversation was said (%d of %d lines)" % [heard.size(), expected.size()])
	for i in mini(heard.size(), expected.size()):
		check(heard[i] == root.get_node("L10n").t(expected[i][1]) or heard[i] == expected[i][1], "line %d in order: %s" % [i + 1, heard[i]])
		if i > 0:
			check(speakers[i] != speakers[i - 1], "line %d by the other friend" % (i + 1))
	check(max_bubbles <= 1, "one bubble at a time over this pair (saw %d)" % max_bubbles)

	# Walk away: the next line is not shown to a player out of earshot.
	player.global_position = middle + Vector3(0, 0, 12.0)
	var far_ok := true
	for i in 240:
		await physics_frame
		for b in _bubbles(life):
			if b.visible:
				far_ok = false
	check(far_ok, "no bubble shows to a player 12 m away")

	# The chat ends (one friend leaves): its bubble goes.
	player.global_position = middle + Vector3(-2.6, 0.0, 0.4)
	var members: Array = g["members"]
	life._release(members[0])
	for i in 3:
		await physics_frame
	check(not is_instance_valid(g.get("bubble")) and _bubbles(life).filter(func(b: Label3D): return b.global_position.distance_to(middle) < 2.5).is_empty(), "bubble removed when the chat ends")
	print("STUDENT_CHAT_VALID" if failures == 0 else "STUDENT_CHAT_INVALID failures=%d" % failures)
	quit(1 if failures else 0)
