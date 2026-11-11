class_name StaffRoomLife
extends Node

## The two teachers' life in the teachers' room in the levels where they have
## no part in the mission (ภารกิจ README: the male teacher is in Missions 3
## and 5, the female teacher "ครูสาว" in Missions 4 and 6).
##   - Each one works at his/her own computer: seated, typing and using the
##     mouse (NpcCharacter, the same as the Data Center supervisor).
##   - F on an idle teacher: he/she stops, turns, says one short greeting and
##     goes back to work (no effect on the score).
## Later steps add standing up, walking, chatting together and coffee breaks.
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
		"host": "STAFF-PC-02", # cubicle 2, chair TR_Chair_2
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
		"host": "STAFF-PC-01", # the office behind the long partition, chair TR_Chair_1
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


## Puts both teachers where this level needs them and adds the life node.
static func setup(world: Node, for_level: int) -> void:
	var life := StaffRoomLife.new()
	life.name = "StaffRoomLife"
	life.level = for_level
	if world.get_node_or_null("TeacherFemale") == null:
		var female: Node3D = (load(FEMALE_SCENE) as PackedScene).instantiate()
		female.name = "TeacherFemale"
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


## Seat position of teacher `id` (tests, later the routine).
static func seat_of(id: String) -> Vector3:
	return TEACHERS[id]["seat"]


## F on an idle teacher: stop working, turn, one line, back to work.
func greet(player: Node, id: String) -> void:
	if _busy or not idle.has(id):
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
