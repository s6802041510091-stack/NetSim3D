extends SceneTree

## Runs the corridor with the housekeeper for sixteen in-game minutes and
## checks her cleaning cycle: both restrooms and corridor stretches mopped,
## never stuck, never in a restroom while a student is inside it, doors shut
## after her, mop on the floor while mopping, hands on the handle.
const SIM_SECONDS := 960.0
const DOORS := ["FemaleWCDoor", "MaleWCDoor", "BackgroundClassDoor"]

var failures := 0
func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error("CLEANER: " + note)

func _room_of(p: Vector3) -> String:
	if p.x > -9.3:
		return ""
	if p.z > -16.93 and p.z < -9.9:
		return "FemaleWCDoor"
	if p.z > -24.02 and p.z < -17.08:
		return "MaleWCDoor"
	return "other"

func _run() -> void:
	var map: Node3D = load("res://scenes/main.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if not args.is_empty() else 0
	(map.get_node("CorridorStudents") as StudentLife).random_seed = seed
	print("CLEANER_SEED ", seed)
	root.add_child(map)
	for i in 5:
		await physics_frame
	var life: StudentLife = map.get_node("CorridorStudents")
	var player: CharacterBody3D = map.get_node("ITSupportPlayer")
	player.set_physics_process(false)
	player.global_position = Vector3(3, .02, 0)
	var c := life.cleaner
	check(c != null, "no housekeeper in CorridorStudents")
	if c == null:
		quit(1)
		return
	check(c.skeleton != null and c.skeleton.get_bone_count() >= 160, "housekeeper rig")
	check(c.mop != null, "mop missing")
	# A camera that follows her, so her arms are posed like when the player is near.
	var follow := Camera3D.new()
	map.add_child(follow)
	follow.make_current()
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 6
	var dt := 1.0 / 120.0 * 6.0
	var elapsed := 0.0
	var checkpoint := 60.0
	var window_start := c.global_position
	var window_time := 0.0
	var mop_time := 0.0
	var mop_floor_bad := 0.0
	var grip_gap := 0.0
	var door_open_idle := {}
	var seen_rooms := {}
	while elapsed < SIM_SECONDS and failures == 0:
		await physics_frame
		elapsed += dt
		var p := c.global_position
		follow.global_position = p + Vector3(0, 1.6, 3)
		# She is always in sight (there is no closet to rest in).
		check(not c.hidden, "housekeeper hidden at %s" % p)
		# Progress: she must keep moving between door and mop stops.
		var resting := c.hidden or c.is_anchored() or c.phase in ["door", "turn"] or c.activity == "idle"
		# Only judge stretches of 25 s spent entirely on the move.
		window_time += dt
		if resting:
			window_start = p
			window_time = 0.0
		if window_time >= 25.0:
			if not resting:
				check(window_start.distance_to(p) > .4, "housekeeper stuck near %s (%s/%s)" % [p, c.phase, c.activity])
			window_start = p
			window_time = 0.0
		check(c.blocked_time < 20, "housekeeper blocked at %s" % p)
		# Never mopping a restroom while a student is inside it.
		var room := _room_of(p)
		if not c.hidden and room in ["FemaleWCDoor", "MaleWCDoor"]:
			seen_rooms[room] = true
			for s in life.students:
				if s.hidden and s.current_step().get("door", "") == room:
					check(false, "%s inside %s with the housekeeper" % [s.student_id, room])
		# Students and housekeeper never overlap.
		if not c.hidden:
			for s in life.students:
				if not s.hidden:
					var d := Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length()
					check(d > .43, "%s overlaps the housekeeper" % s.student_id)
		if c.is_mopping() and c._mop_blend > .99:
			mop_time += dt
			var head := c.mop.global_position
			if head.y > .06 or head.y < -.03:
				mop_floor_bad += dt
			var grip := c.mop.global_transform * Vector3(0, CleanerCharacter.UPPER_GRIP, 0)
			var wrist := c.skeleton.global_transform * c._bone_pos(c.skeleton.find_bone("wrist.R"))
			grip_gap = maxf(grip_gap, wrist.distance_to(grip))
		for door_name in DOORS:
			var d := life.door(door_name)
			var in_use := false
			for s in life.people():
				in_use = in_use or s.current_step().get("door", "") == door_name or s._closing > 0
			if d.is_open and not d.is_moving and not in_use:
				door_open_idle[door_name] = float(door_open_idle.get(door_name, 0.0)) + dt
		if elapsed >= checkpoint:
			print("CLEANER_PROGRESS t=", int(elapsed), " ", c.phase, "/", c.activity, " hidden=", c.hidden, " at ", p.snapped(Vector3.ONE * .01), " log=", life.cleaner_log)
			checkpoint += 60
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	var sections := 0
	for entry in life.cleaner_log:
		if entry.begins_with("section:"):
			sections += 1
	check("clean:MaleWCDoor" in life.cleaner_log, "never cleaned the men's restroom")
	check("clean:FemaleWCDoor" in life.cleaner_log, "never cleaned the women's restroom")
	check(sections >= 3, "only %d corridor stretches mopped" % sections)
	check(seen_rooms.size() == 2, "was not seen inside both restrooms")
	check(mop_time > 120, "mopped only %.0fs" % mop_time)
	check(mop_floor_bad < 1.0, "mop head off the floor for %.1fs while mopping" % mop_floor_bad)
	check(grip_gap < .16, "right hand %.2fm from the handle grip" % grip_gap)
	for door_name in door_open_idle:
		check(float(door_open_idle[door_name]) < 3.0, "%s left open %.1fs" % [door_name, door_open_idle[door_name]])
	print("CLEANER_SUMMARY log=", life.cleaner_log, " mop_s=", int(mop_time), " grip_gap_m=", snappedf(grip_gap, .001))
	if failures == 0:
		print("CLEANER_VALID sections=%d restrooms=both mop_s=%d" % [sections, int(mop_time)])
	else:
		print("CLEANER_INVALID failures=", failures)
	quit(1 if failures else 0)
