class_name StudentLife
extends Node3D

## Corridor director. Students spend most of their time settled somewhere
## (a bench, a wall, a window, inside the restroom or the science room) for
## about a minute to a minute and a half, then walk somewhere with a purpose.
## At most three are on the move at once. Standing spots are against the walls,
## never in a walking lane, a doorway or the stair opening. Walkers keep to the
## left-hand lane of their direction and pass through corners without stopping.

const WEST_LANE := -7.35 # walking toward -Z (the IT/server end)
const EAST_LANE := -4.95 # walking toward +Z (the computer-room end)
const Z_MIN := -43.4
const Z_MAX := 9.2
const SEAT_SLOT := .36 # two people per bench, either side of its middle
const MAX_WALKERS := 3
const STAY := Vector2(60, 90) # seconds at a bench/wall/window
const RESTROOM_STAY := Vector2(35, 60)
const CLASS_STAY := Vector2(60, 100)
const FEMALE := ["bob", "wendy", "layer", "bob_b"]
const SCIENCE_SHOES := Vector3(-8.15, .02, -5.4) # in front of the science shoe rack

## Solo standing spots: [position, yaw]. Window spots look into the classrooms;
## lean spots have the back to a wall and look across the corridor.
var window_spots := {
	"win_w1": [Vector3(-8.6, .02, 2.6), -PI / 2],
	"win_e1": [Vector3(-3.72, .02, 6.1), PI / 2],
	"win_e2": [Vector3(-3.72, .02, 4.3), PI / 2],
}
var lean_spots := {
	"lean_e1": [Vector3(-3.75, .02, -32.3), -PI / 2],
	"lean_e2": [Vector3(-3.75, .02, -11.4), -PI / 2],
	"lean_w1": [Vector3(-8.55, .02, -38.0), PI / 2],
	"lean_w2": [Vector3(-8.55, .02, -12.75), PI / 2],
}
## Places where two friends stand and talk, both against the wall.
var chat_spots := {
	"chat_e1": [Vector3(-3.75, .02, -16.9), Vector3(-3.95, .02, -17.85)],
	"chat_end": [Vector3(-3.9, .02, -42.6), Vector3(-4.8, .02, -43.4)],
	"chat_w1": [Vector3(-8.5, .02, 5.7), Vector3(-8.45, .02, 4.75)],
}
const BENCHES := ["BenchLeft01", "BenchLeft02", "BenchLeft03", "BenchLeft04",
	"BenchRight01", "BenchRight02", "BenchRight03", "BenchRight04"]

@export var random_seed := 0
var rng := RandomNumberGenerator.new()
var students: Array[StudentCharacter] = []
var player: CharacterBody3D
var furnishings: Node3D
var reserved := {} # spot key -> student
var groups := {} # chat key -> {"members": [a, b], "speaker": s, "next": seconds}
var history := {} # student id -> recent plan kinds, newest last
var _serial := 0
var cleaner: CleanerCharacter
var cleaner_log: Array[String] = [] # finished jobs, for the tools

func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	player = get_parent().get_node_or_null("ITSupportPlayer")
	furnishings = get_parent().get_node("CorridorFurnishings")
	for child in get_children():
		if child is CleanerCharacter:
			cleaner = child
		elif child is StudentCharacter:
			students.append(child)
	# After the doors and map collision are ready (they come later in the tree).
	_opening_scene.call_deferred()
	if cleaner:
		_cleaner_start.call_deferred()

## Students and the housekeeper: everyone who walks the corridor.
func people() -> Array[StudentCharacter]:
	var all: Array[StudentCharacter] = students.duplicate()
	if cleaner:
		all.append(cleaner)
	return all

## Everyone starts settled, with staggered stays so they never all leave together.
func _opening_scene() -> void:
	var by_id := {}
	for s in students:
		by_id[s.student_id] = s
	var placed := {}
	if by_id.has("two_block") and by_id.has("wendy"):
		_start_standing_chat(by_id["two_block"], by_id["wendy"], "chat_e1", rng.randf_range(55, 75))
		placed["two_block"] = true; placed["wendy"] = true
	if by_id.has("mullet_b") and by_id.has("bob_b"):
		_start_bench_chat(by_id["mullet_b"], by_id["bob_b"], "BenchLeft04", rng.randf_range(60, 85))
		placed["mullet_b"] = true; placed["bob_b"] = true
	var solo := {"bob": ["bench", "BenchLeft01"], "mullet": ["lean", "lean_e1"], "layer": ["window", "win_e1"]}
	for s in students:
		if placed.has(s.student_id):
			continue
		var plan: Array[Dictionary] = []
		var pick: Array = solo.get(s.student_id, [])
		var stay := rng.randf_range(20, 70)
		if not pick.is_empty() and pick[0] == "bench" and _bench_free(pick[1]):
			var slot := SEAT_SLOT * (1 if rng.randf() < .5 else -1)
			_reserve(s, ["%s:%d" % [pick[1], -1], "%s:%d" % [pick[1], 1]])
			plan.append(seat(pick[1], stay, slot))
		else:
			var spot := _free_solo_spot(s, pick[1] if not pick.is_empty() else "")
			if spot.is_empty():
				continue
			_reserve(s, [spot["key"]])
			plan.append(_spot_step(spot["pos"], spot["activity"], stay, spot["yaw"]))
		plan[-1]["anchor"] = true
		_place(s, plan[0])
		s.start_routine(self, plan)

func _place(s: StudentCharacter, step: Dictionary) -> void:
	s.global_position = step["point"]
	s.rotation.y = float(step.get("yaw", s.rotation.y))

func _start_standing_chat(a: StudentCharacter, b: StudentCharacter, key: String, seconds: float) -> void:
	var spot: Array = chat_spots[key]
	var group := _new_group(a, b)
	_reserve(a, [key])
	for pair in [[a, spot[0], spot[1]], [b, spot[1], spot[0]]]:
		var s: StudentCharacter = pair[0]
		var step := _chat_step(pair[1], pair[2], seconds, group)
		_place(s, step)
		var to: Vector3 = pair[2] - pair[1]
		s.rotation.y = atan2(to.x, to.z)
		var plan: Array[Dictionary] = [step]
		s.start_routine(self, plan)
		s.chat_group = group

func _start_bench_chat(a: StudentCharacter, b: StudentCharacter, bench: String, seconds: float) -> void:
	var group := _new_group(a, b)
	for pair in [[a, -SEAT_SLOT], [b, SEAT_SLOT]]:
		var s: StudentCharacter = pair[0]
		_reserve(s, ["%s:%d" % [bench, signi(int(pair[1] * 100))]])
		var step := seat(bench, seconds, pair[1], "chat")
		step["anchor"] = true
		_place(s, step)
		var plan: Array[Dictionary] = [step]
		s.start_routine(self, plan)
		s.chat_group = group

# --- Step builders (also used by the tools) ---------------------------------

func bench_for(bench_name: String) -> StaticBody3D:
	return furnishings.get_node(bench_name) as StaticBody3D

func door(door_name: String) -> InteractiveDoor:
	return get_parent().get_node_or_null("Doors/" + door_name) as InteractiveDoor

func stop(x: float, z: float, action := "idle", seconds := 1.0, yaw := 0.0) -> Dictionary:
	return {"point": Vector3(x, .02, z), "activity": action, "seconds": seconds, "yaw": yaw}

func via(x: float, z: float) -> Dictionary:
	return {"point": Vector3(x, .02, clampf(z, Z_MIN, Z_MAX)), "via": true}

func seat(bench_name: String, seconds: float, slot := 0.0, action := "rest") -> Dictionary:
	var bench := bench_for(bench_name)
	var at := bench.global_position + bench.global_basis.z * .52 + bench.global_basis.x * slot
	var step := stop(at.x, at.z, action, seconds, bench.rotation.y)
	step["bench"] = bench_name
	step["slot"] = slot
	return step

func _spot_step(pos: Vector3, action: String, seconds: float, yaw: float) -> Dictionary:
	return {"point": pos, "activity": action, "seconds": seconds, "yaw": yaw}

func _chat_step(pos: Vector3, face: Vector3, seconds: float, group: String) -> Dictionary:
	return {"point": pos, "activity": "chat", "seconds": seconds, "face": face, "anchor": true, "group": group}

## Pass-through points along the keep-left lane between two places.
func path(from: Vector3, to: Vector3) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var dz := to.z - from.z
	if absf(dz) < 3.0:
		return steps
	var lane := WEST_LANE if dz < 0 else EAST_LANE
	var sgn := signf(dz)
	var z1 := from.z + sgn * clampf(absf(lane - from.x) * .9, 1.0, 2.6)
	var z2 := to.z - sgn * clampf(absf(lane - to.x) * .9, 1.0, 2.6)
	if (z2 - z1) * sgn > .5:
		steps.append(via(lane, z1))
		steps.append(via(lane, z2))
	else:
		steps.append(via(lane, (from.z + to.z) * .5))
	return steps

# --- Director ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for key in groups.keys():
		var g: Dictionary = groups[key]
		var a: StudentCharacter = g["members"][0]
		if not a._chat_started:
			continue
		g["next"] -= delta
		if g["next"] <= 0:
			g["speaker"] = g["members"][1] if g["speaker"] == g["members"][0] else g["members"][0]
			g["next"] = rng.randf_range(3.5, 7.5)

func is_speaking(student: StudentCharacter) -> bool:
	var g: Dictionary = groups.get(student.chat_group, {})
	return not g.is_empty() and g["speaker"] == student

func chat_partner(student: StudentCharacter) -> StudentCharacter:
	var g: Dictionary = groups.get(student.chat_group, {})
	if g.is_empty():
		return null
	for other: StudentCharacter in g["members"]:
		if other != student:
			return other
	return null

func walkers(except: StudentCharacter = null) -> int:
	var n := 0
	for s in students:
		if s != except and s.is_moving():
			n += 1
	return n

## Asked when a settled student's time is up. Returns extra seconds to stay
## (too many people walking, or staying on after a friend leaves), else 0.
func hold_extension(s: StudentCharacter) -> float:
	if s == cleaner:
		return 0.0
	if s.chat_group != "":
		var friend := chat_partner(s)
		groups.erase(s.chat_group)
		s.chat_group = ""
		s._chat_started = false
		if friend and friend.is_anchored():
			# Half the time the friend lingers a little after the talk.
			friend.leave_chat(rng.randf_range(15, 35) if rng.randf() < .5 else 0.0)
		elif friend:
			friend.chat_group = "" # still on the way: just stays there a while
	var moving := walkers(s)
	if moving >= MAX_WALKERS or (moving >= 2 and rng.randf() < .5):
		return rng.randf_range(6, 14)
	return 0.0

func plan_finished(s: StudentCharacter) -> void:
	if s == cleaner:
		s.start_routine(self, _cleaner_plan())
		return
	_release(s)
	s.start_routine(self, next_plan(s))

func next_plan(s: StudentCharacter) -> Array[Dictionary]:
	var recent: Array = history.get(s.student_id, [])
	var kinds := {"invite": 30.0, "bench": 25.0, "window": 12.0, "lean": 10.0, "restroom": 12.0, "science": 11.0}
	if not recent.is_empty():
		kinds.erase(recent[-1])
	if "restroom" in recent:
		kinds.erase("restroom")
	while not kinds.is_empty():
		var kind := _pick_weighted(kinds)
		kinds.erase(kind)
		var plan := _build(s, kind)
		if not plan.is_empty():
			recent.append(kind)
			if recent.size() > 3:
				recent.pop_front()
			history[s.student_id] = recent
			return plan
	# Everything taken: stand against the nearest free wall spot.
	var spot := _free_solo_spot(s, "")
	if spot.is_empty():
		var wait: Array[Dictionary] = [_spot_step(s.global_position, "idle", 15, s.rotation.y)]
		wait[0]["anchor"] = true
		return wait
	var plan := path(s.global_position, spot["pos"])
	plan.append(_spot_step(spot["pos"], "idle", rng.randf_range(20, 40), spot["yaw"]))
	plan[-1]["anchor"] = true
	_reserve(s, [spot["key"]])
	return plan

func _build(s: StudentCharacter, kind: String) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var stay := rng.randf_range(STAY.x, STAY.y)
	match kind:
		"invite":
			return _invite(s, stay)
		"bench":
			var options := {}
			for b in BENCHES:
				var front: Vector3 = seat(b, 0)["point"]
				# Not a bench someone is just getting up from or walking past.
				if _bench_free(b) and _capsule_free(front, s):
					options[b] = _near_weight(s, front)
			if options.is_empty():
				return none
			var bench := _pick_weighted(options)
			var slot := SEAT_SLOT * (1 if rng.randf() < .5 else -1)
			_reserve(s, ["%s:%d" % [bench, -1], "%s:%d" % [bench, 1]])
			var step := seat(bench, stay, slot)
			step["anchor"] = true
			var plan := path(s.global_position, step["point"])
			plan.append(step)
			return plan
		"window", "lean":
			var spot := _free_solo_spot(s, "", kind)
			if spot.is_empty():
				return none
			_reserve(s, [spot["key"]])
			var plan := path(s.global_position, spot["pos"])
			plan.append(_spot_step(spot["pos"], spot["activity"], stay, spot["yaw"]))
			plan[-1]["anchor"] = true
			return plan
		"restroom":
			var room := "FemaleWCDoor" if s.student_id in FEMALE else "MaleWCDoor"
			return _room_plan(s, room, rng.randf_range(RESTROOM_STAY.x, RESTROOM_STAY.y))
		"science":
			return _room_plan(s, "BackgroundClassDoor", rng.randf_range(CLASS_STAY.x, CLASS_STAY.y))
	return none

## Walk over to a settled friend: sit next to them, or stand beside them.
func _invite(s: StudentCharacter, stay: float) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if walkers(s) >= MAX_WALKERS:
		return none
	var friends: Array[StudentCharacter] = []
	for f in students:
		if f != s and f.is_anchored() and not f.hidden and f.chat_group == "" \
				and f.activity in ["rest", "idle", "window"] and f.hold_time > 25:
			friends.append(f)
	friends.shuffle()
	for f in friends:
		if f.seated:
			var step := f.current_step()
			var bench: String = step.get("bench", "")
			var other := -signf(float(step.get("slot", SEAT_SLOT)))
			var key := "%s:%d" % [bench, int(other)]
			if bench == "" or (reserved.has(key) and reserved[key] != f):
				continue
			var group := _new_group(s, f)
			_reserve(s, [key])
			var seat_step := seat(bench, stay, other * SEAT_SLOT, "chat")
			seat_step["anchor"] = true
			f.join_chat(group, stay)
			s.chat_group = group
			var plan := path(s.global_position, seat_step["point"])
			plan.append(seat_step)
			return plan
		var at := _buddy_point(f)
		if at == Vector3.INF:
			continue
		var group := _new_group(s, f)
		_reserve(s, ["buddy:" + f.student_id])
		f.join_chat(group, stay)
		s.chat_group = group
		var plan := path(s.global_position, at)
		plan.append(_chat_step(at, f.global_position, stay, group))
		return plan
	return none

## Into a room through its door: open it, step in, close it, stay, come back.
func _room_plan(s: StudentCharacter, room: String, stay: float) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	var d := door(room)
	if d == null:
		return none
	var inside_now := 0
	for key in reserved:
		if String(key).begins_with("room:" + room):
			inside_now += 1
	if inside_now >= (3 if room == "BackgroundClassDoor" else 2) or room_busy(room, s):
		return none
	var z := d.get_doorway_center().z
	var outside := Vector3(-8.4, .02, z)
	var inside := Vector3(-10.35, .02, z)
	var science := room == "BackgroundClassDoor"
	var plan: Array[Dictionary] = []
	if science:
		plan = path(s.global_position, SCIENCE_SHOES)
		plan.append(_spot_step(SCIENCE_SHOES, "shoes", rng.randf_range(5, 7), -PI / 2))
		plan[-1]["door"] = room
	else:
		plan = path(s.global_position, outside)
	plan.append({"point": outside, "activity": "door", "door": room, "door_op": "open"})
	plan.append({"point": inside, "activity": "inside", "seconds": stay, "hide": true, "anchor": true, "door": room})
	plan.append({"point": outside, "activity": "door", "door": room, "door_op": "close"})
	if science:
		plan.append(_spot_step(SCIENCE_SHOES, "shoes", rng.randf_range(5, 7), -PI / 2))
		plan[-1]["door"] = room
	_reserve(s, ["room:%s:%s" % [room, s.student_id]])
	return plan

## Someone visible is on the way in or out of this room (one at a time
## through a doorway, and the science shoe rack is part of the doorway).
func room_busy(room: String, except: StudentCharacter) -> bool:
	for other in people():
		if other == except or other.hidden:
			continue
		for i in range(other.step_index, other.routine.size()):
			if other.routine[i].get("door", "") == room or other.routine[i].get("room", "") == room:
				return true
	return false

# --- Spots and reservations ---------------------------------------------------

func _free_solo_spot(s: StudentCharacter, wanted: String, kind := "") -> Dictionary:
	var options := {}
	var all := {}
	for k in window_spots:
		all[k] = [window_spots[k], "window"]
	for k in lean_spots:
		all[k] = [lean_spots[k], "idle"]
	for k in all:
		var spot: Array = all[k][0]
		if reserved.has(k) or (kind != "" and all[k][1] != ("window" if kind == "window" else "idle")):
			continue
		if not _capsule_free(spot[0], s):
			continue
		var found := {"key": k, "pos": spot[0], "yaw": spot[1], "activity": all[k][1]}
		if k == wanted:
			return found
		options[k] = found
	if options.is_empty():
		return {}
	var weights := {}
	for k in options:
		weights[k] = _near_weight(s, options[k]["pos"])
	return options[_pick_weighted(weights)]

## A place beside a standing friend, along the same wall, facing them.
func _buddy_point(f: StudentCharacter) -> Vector3:
	var inward := 1.0 if f.global_position.x < -6.15 else -1.0
	for dz in [.95, -.95]:
		var p := f.global_position + Vector3(.12 * inward, 0, dz)
		p.y = .02
		if p.z < Z_MIN or p.z > Z_MAX or _near_doorway(p):
			continue
		if _capsule_free(p, null, f):
			return p
	return Vector3.INF

## Keeps standing people well clear of doorways (people walk up to them from
## the side) and of the stair opening.
func _near_doorway(p: Vector3) -> bool:
	const CLEAR := .9
	if p.x < -7.8:
		# Science, restrooms, IT support and the stair opening on the west wall.
		for r in [Vector2(-8.41, -7.25), Vector2(-15.59, -14.43), Vector2(-23.38, -22.22), Vector2(-30.52, -24.1), Vector2(-36.06, -34.9)]:
			if p.z > r.x - CLEAR and p.z < r.y + CLEAR:
				return true
	if p.x > -4.5:
		for r in [Vector2(-10.0, -8.95), Vector2(-26.29, -25.13), Vector2(-36.06, -34.9)]:
			if p.z > r.x - CLEAR and p.z < r.y + CLEAR:
				return true
	return false

## True when a standing capsule fits at `p` (no furniture, no wall, nobody there).
func _capsule_free(p: Vector3, s: StudentCharacter = null, also_ignore: StudentCharacter = null) -> bool:
	var probe: StudentCharacter = s if s else students[0]
	var shape: CollisionShape3D = probe.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, p + shape.position + Vector3(0, .03, 0))
	query.collision_mask = 3
	var skip: Array[RID] = []
	if s:
		skip.append(s.get_rid())
	if also_ignore:
		skip.append(also_ignore.get_rid())
	query.exclude = skip
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	for other in people():
		if other == s or other == also_ignore:
			continue
		# Keep a comfortable gap to where people are and where they are going.
		if not other.hidden and other.global_position.distance_to(p) < 1.1:
			return false
		if not other.routine.is_empty() and (other.routine[-1]["point"] as Vector3).distance_to(p) < 1.1:
			return false
	return true

func _bench_free(bench: String) -> bool:
	return not reserved.has("%s:%d" % [bench, -1]) and not reserved.has("%s:%d" % [bench, 1])

func _reserve(s: StudentCharacter, keys: Array) -> void:
	for k in keys:
		reserved[k] = s

func _release(s: StudentCharacter) -> void:
	for k in reserved.keys():
		if reserved[k] == s:
			reserved.erase(k)
	if s.chat_group != "" and groups.has(s.chat_group):
		var friend := chat_partner(s)
		groups.erase(s.chat_group)
		if friend:
			friend.leave_chat(0.0)
	s.chat_group = ""

func _new_group(a: StudentCharacter, b: StudentCharacter) -> String:
	_serial += 1
	var key := "chat%d" % _serial
	groups[key] = {"members": [a, b], "speaker": a, "next": rng.randf_range(3.5, 6.5)}
	return key

func _near_weight(s: StudentCharacter, at: Vector3) -> float:
	return 1.0 / (1.0 + s.global_position.distance_to(at) / 12.0)

func _pick_weighted(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0:
			return k
	return weights.keys()[-1]

# --- Housekeeper ---------------------------------------------------------------
# Cycle: mop two corridor sections -> mop the other restroom (if no student is
# in it; otherwise mop one more section and try again) -> back out -> ...
# She always stays in sight: the restrooms have no closet to rest in.

const CLEAN_SECTIONS := [Vector2(8.6, 1.6), Vector2(1.6, -5.4), Vector2(-5.4, -12.4),
	Vector2(-12.4, -19.4), Vector2(-19.4, -26.4), Vector2(-26.4, -33.4), Vector2(-33.4, -40.4)]
const CLEAN_PASSES := [-7.3, -6.15, -5.0]
## Inside each restroom: the way round the privacy wall and the mopping passes
## (z) between the cubicle fronts and the basins.
const RESTROOM_CLEAN := {
	"FemaleWCDoor": {"around": [Vector3(-10.6, .02, -13.35), Vector3(-12.0, .02, -13.0)],
		"passes": [-12.95, -14.25, -15.55], "x": Vector2(-12.0, -20.3)},
	"MaleWCDoor": {"around": [Vector3(-10.6, .02, -21.1), Vector3(-12.0, .02, -20.6)],
		"passes": [-20.15, -21.1, -22.05, -23.0], "x": Vector2(-12.0, -20.2)},
}
var _cleaner_room := "MaleWCDoor" # the restroom she mopped last
var _cleaner_sections_left := 0
var _section_cleaned := {} # section index -> time it was last mopped
var _clock := 0.0

func _process(delta: float) -> void:
	_clock += delta

## She starts the level out in the corridor, already mopping.
func _cleaner_start() -> void:
	cleaner.global_position = Vector3(CLEAN_PASSES[0], .02, -15.0)
	cleaner.rotation.y = PI
	_cleaner_sections_left = 1
	cleaner.start_routine(self, _section_plan())

func _cleaner_plan() -> Array[Dictionary]:
	if _cleaner_sections_left <= 0:
		var room := "MaleWCDoor" if _cleaner_room == "FemaleWCDoor" else "FemaleWCDoor"
		if _restroom_empty(room):
			_cleaner_room = room
			_cleaner_sections_left = 2
			return _restroom_clean(room)
	_cleaner_sections_left -= 1
	return _section_plan()

## Nobody in it, on the way in, or planning to go.
func _restroom_empty(room: String) -> bool:
	for key in reserved:
		if String(key).begins_with("room:" + room + ":"):
			return false
	return not room_busy(room, cleaner)

func _door_points(room: String) -> Array[Vector3]:
	var z := door(room).get_doorway_center().z
	return [Vector3(-8.4, .02, z), Vector3(-10.45, .02, z)]

func _restroom_clean(room: String) -> Array[Dictionary]:
	var info: Dictionary = RESTROOM_CLEAN[room]
	var points := _door_points(room)
	var plan := path(cleaner.global_position, points[0])
	plan.append({"point": points[0], "activity": "door", "door": room, "door_op": "open", "room": room})
	plan.append({"point": points[1], "activity": "door", "door": room, "door_op": "close", "room": room})
	for p: Vector3 in info["around"]:
		plan.append({"point": p, "via": true, "room": room})
	var x: Vector2 = info["x"]
	var forward := true
	for z: float in info["passes"]:
		var a := Vector3(x.x if forward else x.y, .02, z)
		var b := Vector3(x.y if forward else x.x, .02, z)
		plan.append({"point": a, "via": true, "mop": true, "speed": CleanerCharacter.MOP_SPEED, "room": room})
		plan.append({"point": b, "via": true, "mop": true, "speed": CleanerCharacter.MOP_SPEED, "room": room})
		forward = not forward
	# Back out the way she came in, closing the door behind her.
	plan.append_array(_restroom_exit(room))
	cleaner_log.append("clean:" + room)
	return plan

func _restroom_exit(room: String) -> Array[Dictionary]:
	var info: Dictionary = RESTROOM_CLEAN[room]
	var points := _door_points(room)
	var plan: Array[Dictionary] = []
	var around: Array = info["around"]
	plan.append({"point": Vector3(-12.0, .02, around[1].z), "via": true, "room": room})
	plan.append({"point": around[0], "via": true, "room": room})
	plan.append({"point": points[1], "activity": "door", "door": room, "door_op": "open", "room": room})
	plan.append({"point": points[0], "activity": "door", "door": room, "door_op": "close"})
	return plan

## Three slow passes down a stretch of corridor, starting at its nearer end.
func _section_plan() -> Array[Dictionary]:
	var at := cleaner.global_position
	var best := 0
	var best_score := INF
	for i in CLEAN_SECTIONS.size():
		var r: Vector2 = CLEAN_SECTIONS[i]
		var mid := (r.x + r.y) * .5
		# Prefer stretches not mopped for a while, and not too far away.
		var score := absf(mid - at.z) - (_clock - float(_section_cleaned.get(i, -1000.0))) * .05
		if score < best_score:
			best_score = score
			best = i
	_section_cleaned[best] = _clock
	var r: Vector2 = CLEAN_SECTIONS[best]
	var start_z := r.x if absf(r.x - at.z) < absf(r.y - at.z) else r.y
	var end_z := r.y if start_z == r.x else r.x
	var passes: Array = CLEAN_PASSES.duplicate()
	if absf(passes[-1] - at.x) < absf(passes[0] - at.x):
		passes.reverse()
	var plan := path(at, Vector3(passes[0], .02, start_z))
	plan.append({"point": Vector3(passes[0], .02, start_z), "via": true})
	var z_from := start_z
	var z_to := end_z
	for x: float in passes:
		plan.append({"point": Vector3(x, .02, z_from), "via": true, "mop": true, "speed": CleanerCharacter.MOP_SPEED})
		plan.append({"point": Vector3(x, .02, z_to), "via": true, "mop": true, "speed": CleanerCharacter.MOP_SPEED})
		var t := z_from
		z_from = z_to
		z_to = t
	# A short look over the wet floor before moving on.
	var last: Vector3 = plan[-1]["point"]
	plan.append({"point": last, "activity": "idle", "seconds": 1.5})
	cleaner_log.append("section:%d" % best)
	return plan
