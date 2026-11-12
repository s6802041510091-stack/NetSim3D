class_name StaffRoomLife
extends Node

## The two teachers' life in the teachers' room in the levels where they have
## no part in the mission (ภารกิจ README: the male teacher is in Missions 3
## and 5, the female teacher "ครูสาว" in Missions 4 and 6).
##   - Each one works at his/her own computer: seated, typing and using the
##     mouse (NpcCharacter, the same as the Data Center supervisor).
##   - F on an idle teacher: he/she stops, turns, says one short greeting and
##     goes back to work (no effect on the score).
##   - Routine: work a while, then a break: when both are free the male
##     teacher walks to the female teacher's office and they chat (speech
##     bubbles); a teacher alone goes for a coffee at the pantry counter.
## `auto_routine` false (tests) keeps them at their desks until told.
## GameFlow.configure_level calls setup() before the world enters the tree.

const NPC_SCRIPT := "res://scripts/npc/npc_character.gd"
const FEMALE_SCENE := "res://scenes/teacher_female.tscn"

## Seated pose and hand targets per teacher. Desk layout (both desks the same):
## keyboard 0.66 m ahead of the chair, x -0.11..0.31 in the teacher's space
## (+Z toward the desk, +X his/her left) once seated 6 cm right of the desk
## centre; mouse pad centred at x -0.24. The typing pose is tuned for the
## keyboard lying there (as on the supervisor's desk).
const TEACHERS := {
	"male": {
		"node": "TeacherMale",
		"name": "ครูประจำห้องคอมพิวเตอร์",
		"host": "STAFF-PC-02", # cubicle 2
		"chair": "TR_Chair_2",
		"seat": Vector3(7.76, 0.02, -21.39),
		"drop": 0.46, # the 180 cm model's hips are higher
		"forward": 0.1,
		"lean": 14.0,
		"hands": [Vector3(0.27, 0.795, 0.55), Vector3(-0.21, 0.79, 0.565), Vector3(0.09, 0.795, 0.52)],
		"role_levels": [3, 5],
		"greetings": [
			"สวัสดีครับ วันนี้ต้องเตรียมใบงานคาบบ่ายให้เสร็จก่อนเลย",
			"อ้าว ฝ่าย IT นี่เอง ขอบคุณที่ช่วยดูแลเครือข่ายให้นะครับ",
			"สวัสดีครับ คาบหน้าผมต้องพานักเรียนเข้าห้องคอมพอดี",
		],
	},
	"female": {
		"node": "TeacherFemale",
		"name": "ครูสาว",
		"host": "STAFF-PC-01", # the office behind the long partition
		"chair": "TR_Chair_1",
		"seat": Vector3(7.76, 0.02, -27.94),
		"drop": 0.36, # 160 cm
		"forward": 0.1,
		"lean": 14.0,
		"hands": [Vector3(0.25, 0.79, 0.53), Vector3(-0.2, 0.785, 0.545), Vector3(0.08, 0.79, 0.5)],
		"role_levels": [4, 6],
		"greetings": [
			"สวัสดีค่ะ ช่วงนี้ตรวจการบ้านนักเรียนแทบไม่ทันเลยค่ะ",
			"สวัสดีค่ะ เครื่องของครูยังใช้งานได้ดีอยู่ ขอบคุณนะคะ",
			"สวัสดีค่ะ กำลังกรอกคะแนนสอบกลางภาคอยู่พอดีเลยค่ะ",
		],
	},
}
const HAND_MARKERS := ["KeyboardHand", "MouseHand", "KeyboardRightHand"]

var level := 0
## id ("male" / "female") -> NpcCharacter, only the teachers idle in this level.
var idle := {}
var dialogue: DialogueBox
var _busy := false
## Start the routine by itself (tests turn it off and call run_chat / run_coffee).
static var auto_routine := true


## Puts both teachers where this level needs them and adds the life node.
static func setup(world: Node, for_level: int) -> void:
	var life := StaffRoomLife.new()
	life.name = "StaffRoomLife"
	life.level = for_level
	if world.get_node_or_null("TeacherFemale") == null:
		var female: Node3D = (load(FEMALE_SCENE) as PackedScene).instantiate()
		female.name = "TeacherFemale"
		# Her model has no thighs under the knee-length skirt (like the female
		# students): seated, the skirt opens and the legs looked cut off.
		StudentThighs.add_to(female.get_node("Visual"))
		world.add_child(female)
	for id: String in TEACHERS:
		var info: Dictionary = TEACHERS[id]
		var teacher := world.get_node_or_null(String(info["node"])) as CharacterBody3D
		if teacher == null:
			continue
		var has_role: bool = for_level in info["role_levels"]
		if id == "male" and has_role:
			continue # stands in the computer room for his missions
		# The female teacher's missions (4, 6) are not built yet: there she
		# just sits at her desk, without the routine.
		_seat(world, teacher, info)
		if not has_role:
			life.idle[id] = teacher
	world.add_child(life)


static func _seat(world: Node, teacher: CharacterBody3D, info: Dictionary) -> void:
	teacher.set_script(load(NPC_SCRIPT))
	teacher.position = info["seat"]
	teacher.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var hands: Array = info["hands"]
	for i in HAND_MARKERS.size():
		var marker := Marker3D.new()
		marker.name = HAND_MARKERS[i]
		marker.position = hands[i]
		teacher.add_child(marker)
	teacher.set("seat_drop", info["drop"])
	teacher.set("seat_forward", info["forward"])
	teacher.set("lean_degrees", info["lean"])
	teacher.set("left_hand_target", NodePath(HAND_MARKERS[0]))
	teacher.set("right_hand_target", NodePath(HAND_MARKERS[1]))
	teacher.set("right_typing_target", NodePath(HAND_MARKERS[2]))
	teacher.set("seated", true)
	# The computer is in use: the player cannot sit at it, and its screen
	# collider must not block looking at the teacher.
	var computers := world.get_node_or_null("Computers")
	if computers:
		var hosts: PackedStringArray = computers.get("npc_used_hosts")
		if not String(info["host"]) in hosts:
			hosts.append(String(info["host"]))
			computers.set("npc_used_hosts", hosts)
	if info.has("chair"):
		align_chair(world, String(info["chair"]), info["seat"], teacher.rotation.y)


## Slides a desk chair of the map model sideways so its seat is centred under
## a teacher seated at `seat` facing `yaw` (the chairs in the model stand
## ~17 cm beside the typing position, so he looked seated next to the chair).
## Chairs are visual only (no collider). Works before the world is in the tree.
static func align_chair(world: Node, chair_name: String, seat: Vector3, yaw: float) -> void:
	var visual := world.get_node_or_null("MapVisual") as Node3D
	var chair := visual.get_node_or_null(chair_name) as MeshInstance3D if visual else null
	if chair == null:
		return
	var to_world := visual.transform * chair.transform
	var center := to_world * chair.get_aabb().get_center()
	var side := Basis(Vector3.UP, yaw).x
	var shift := side * side.dot(seat - center)
	chair.position += visual.basis.inverse() * shift

func _ready() -> void:
	dialogue = DialogueBox.new()
	dialogue.name = "GreetingBox"
	add_child(dialogue)
	for id: String in idle:
		var talk := Talkable.new()
		talk.name = "Talk"
		talk.display_name = TEACHERS[id]["name"]
		talk.prompt = "กด F เพื่อทักทาย" + String(TEACHERS[id]["name"])
		(idle[id] as Node).add_child(talk)
		talk.talked.connect(greet.bind(id))
		activity[id] = "desk"
	if auto_routine:
		_start_routines()


## Seat position of teacher `id` (tests, later the routine).
static func seat_of(id: String) -> Vector3:
	return TEACHERS[id]["seat"]


## F on an idle teacher: stop working, turn, one line, back to work.
func greet(player: Node, id: String) -> void:
	if _busy or not idle.has(id) or activity.get(id, "desk") != "desk":
		return
	_busy = true
	var teacher: NpcCharacter = idle[id]
	var lines: Array = TEACHERS[id]["greetings"]
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	if player is Node3D:
		await teacher.turn_to(player)
	dialogue.show_lines(PackedStringArray([String(TEACHERS[id]["name"]) + "|" + String(lines.pick_random())]))
	await dialogue.finished
	teacher.turn_back()
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_busy = false


# --- The routine: work, chat, coffee -----------------------------------------

## Seconds at the desk between two breaks (random in this range); the first
## break comes sooner. Coffee: seconds standing at the counter.
const WORK_TIME := Vector2(45.0, 95.0)
const FIRST_BREAK := Vector2(15.0, 40.0)
const COFFEE_TIME := Vector2(8.0, 13.0)
## Speech bubbles: seconds per line, how close the player must be to see them.
const LINE_TIME := 3.6
const BUBBLE_RANGE := 9.0

## Walking routes (floor points), from where each teacher stands up (0.38 m
## back from the desk). They keep clear of the cubicle partitions, the
## office's partitions and the guest chair (tools/validate_staff_routine.gd
## sweeps them against the map colliders).
const ROUTES := {
	"male_to_chat": [Vector3(6.6, 0.02, -21.39), Vector3(6.6, 0.02, -24.8), Vector3(8.0, 0.02, -24.8), Vector3(8.05, 0.02, -26.7)],
	"male_to_coffee": [Vector3(6.6, 0.02, -21.39), Vector3(6.6, 0.02, -24.8), Vector3(5.4, 0.02, -25.0), Vector3(3.0, 0.02, -29.35)],
	"female_to_coffee": [Vector3(8.0, 0.02, -26.9), Vector3(8.0, 0.02, -24.8), Vector3(6.6, 0.02, -24.8), Vector3(5.4, 0.02, -25.0), Vector3(3.7, 0.02, -29.35)],
}
## Facing the pantry counter (-Z).
const COFFEE_YAW := PI

## Chats in the female teacher's office: who says what, in turns.
const CHATS := [
	[["male", "ครูครับ ตารางสอนเทอมหน้าออกแล้วนะ"], ["female", "จริงเหรอคะ ขอดูคาบของตัวเองหน่อย"], ["male", "ผมส่งเข้ากลุ่มไลน์ให้แล้วครับ"], ["female", "ขอบคุณค่ะ เดี๋ยวเปิดดู"]],
	[["male", "บ่ายนี้มีประชุมกลุ่มสาระฯ ใช่ไหมครับ"], ["female", "ค่ะ บ่ายสองโมงที่ห้องประชุมเล็ก"], ["male", "เดี๋ยวผมเอาเอกสารไปด้วยครับ"], ["female", "ได้ค่ะ เจอกันนะคะ"]],
	[["female", "ข้อสอบกลางภาคต้องส่งวันศุกร์นี้นะคะ"], ["male", "ผมออกเสร็จแล้ว เหลือตรวจทานอีกรอบ"], ["female", "ของฉันยังเหลือตอนที่สองเลยค่ะ"], ["male", "สู้ ๆ ครับ"]],
	[["male", "ห้องคอมใหม่จะใช้ได้เมื่อไหร่ครับ"], ["female", "ฝ่าย IT บอกว่ากำลังติดตั้งเครือข่ายอยู่ค่ะ"], ["male", "จะได้พานักเรียนไปเรียนเสียที"], ["female", "นักเรียนรอกันหลายคนเลยค่ะ"]],
]

## id -> "desk" (working), "away" (walking, coffee, chatting).
var activity := {}
var _bubbles: Array[Label3D] = []
var _chat_index := -1


func _process(_delta: float) -> void:
	# Bubbles only show to a player close enough to overhear.
	var player := get_node_or_null("../ITSupportPlayer") as Node3D
	for bubble in _bubbles:
		if is_instance_valid(bubble):
			bubble.visible = player != null and player.global_position.distance_to(bubble.global_position) < BUBBLE_RANGE


func _start_routines() -> void:
	for id: String in idle:
		_routine(id)


## Each idle teacher: work a while, take a break, again. In levels where both
## are free the male teacher goes to chat; otherwise a coffee break.
func _routine(id: String) -> void:
	var wait := randf_range(FIRST_BREAK.x, FIRST_BREAK.y)
	while is_inside_tree():
		await get_tree().create_timer(wait, false).timeout
		wait = randf_range(WORK_TIME.x, WORK_TIME.y)
		if not is_inside_tree() or not idle.has(id):
			return
		var teacher: NpcCharacter = idle[id]
		# Not while the player is talking to him/her, or a chat is on.
		if teacher.talking or _busy or activity.get(id, "") != "desk":
			wait = 5.0
			continue
		if id == "male" and idle.has("female") and activity.get("female", "") == "desk" and randf() < 0.6:
			await run_chat()
		else:
			await run_coffee(id)


## The male teacher walks over to the female teacher's office, they talk
## (speech bubbles, in turns) and he walks back to his desk.
func run_chat() -> void:
	if not idle.has("male") or not idle.has("female") or activity.get("male") != "desk" or activity.get("female") != "desk":
		return
	var male: NpcCharacter = idle["male"]
	var female: NpcCharacter = idle["female"]
	activity["male"] = "away"
	activity["female"] = "away" # she stays seated but stops for the chat
	_set_greeting(male, false)
	_set_greeting(female, false)
	var route: Array = ROUTES["male_to_chat"]
	await male.stand_up()
	await male.walk_path(route)
	if not is_inside_tree():
		return
	var to_her := female.global_position - male.global_position
	await male.face_yaw(atan2(to_her.x, to_her.z))
	await female.turn_to(male)
	_chat_index = (_chat_index + 1 + randi() % CHATS.size()) % CHATS.size()
	for line: Array in CHATS[_chat_index]:
		if not is_inside_tree():
			return
		await say(idle[line[0]], line[1], LINE_TIME)
	female.turn_back()
	await _walk_home(male, route)
	activity["female"] = "desk"
	_set_greeting(female, true)


## A teacher walks to the pantry counter, stands there a while and comes back.
func run_coffee(id: String) -> void:
	if not idle.has(id) or activity.get(id) != "desk":
		return
	var teacher: NpcCharacter = idle[id]
	activity[id] = "away"
	_set_greeting(teacher, false)
	var route: Array = ROUTES[id + "_to_coffee"]
	await teacher.stand_up()
	await teacher.walk_path(route)
	if not is_inside_tree():
		return
	await teacher.face_yaw(COFFEE_YAW)
	await get_tree().create_timer(randf_range(COFFEE_TIME.x, COFFEE_TIME.y), false).timeout
	await _walk_home(teacher, route)


## Back along `route` to where the teacher stood up, then onto the seat.
func _walk_home(teacher: NpcCharacter, route: Array) -> void:
	var back := route.duplicate()
	back.reverse()
	back.pop_front()
	var id := "male" if teacher == idle.get("male") else "female"
	var seat: Vector3 = TEACHERS[id]["seat"]
	back.append(seat - Vector3(NpcCharacter.STAND_BACK, 0.0, 0.0))
	await teacher.walk_path(back)
	if not is_inside_tree():
		return
	await teacher.face_yaw(PI * 0.5)
	await teacher.sit_down()
	activity[id] = "desk"
	_set_greeting(teacher, true)


## A speech bubble over `who`'s head for `seconds`.
func say(who: NpcCharacter, text: String, seconds: float) -> void:
	var bubble := Label3D.new()
	bubble.name = "SpeechBubble"
	bubble.text = text
	bubble.font = GameUI.FONT_BOLD
	bubble.font_size = 40
	bubble.pixel_size = 0.0016
	bubble.outline_size = 12
	bubble.outline_modulate = Color(0.05, 0.08, 0.14, 0.9)
	bubble.modulate = Color(1.0, 1.0, 1.0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 560.0
	bubble.visible = false
	get_parent().add_child(bubble)
	bubble.global_position = _head_of(who) + Vector3.UP * 0.32
	_bubbles.append(bubble)
	Sound.play("type_tick", who, -6.0)
	await get_tree().create_timer(seconds, false).timeout
	_bubbles.erase(bubble)
	if is_instance_valid(bubble):
		bubble.queue_free()


func _head_of(who: NpcCharacter) -> Vector3:
	var head := who.skeleton.find_bone("head") if who.skeleton else -1
	if head < 0:
		return who.global_position + Vector3.UP * 1.6
	return who.skeleton.global_transform * who.skeleton.get_bone_global_pose(head).origin


func _set_greeting(teacher: NpcCharacter, on: bool) -> void:
	var talk := teacher.get_node_or_null("Talk") as Talkable
	if talk:
		var id := "male" if teacher == idle.get("male") else "female"
		talk.prompt = ("กด F เพื่อทักทาย" + String(TEACHERS[id]["name"])) if on else ""
