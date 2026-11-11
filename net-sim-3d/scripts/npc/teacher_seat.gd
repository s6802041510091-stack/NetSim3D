class_name TeacherSeat
extends RefCounted

## Levels 1-2: the male teacher (TeacherMale in main.tscn, standing in the
## computer room for the later missions) works at his computer in the
## teachers' room instead: seated, typing and using the mouse like the Data
## Center supervisor (NpcCharacter). Call before the world enters the tree.

const NPC_SCRIPT := "res://scripts/npc/npc_character.gd"
## Teachers' room cubicle 2: chair TR_Chair_2 at (7.79, -21.55), desk to +X.
const DESK_HOST := "STAFF-PC-02"
## Right of the chair centre so the keyboard lies where the supervisor's does
## (the typing pose is tuned for that: left hand outside the shoulder).
const SEAT := Vector3(7.76, 0.02, -21.39)
## The 180 cm model's hips are higher than the 170 cm supervisor's.
const SEAT_DROP := 0.46
const SEAT_FORWARD := 0.1
const LEAN_DEGREES := 14.0
## Hand targets in the teacher's space (+Z toward the desk, +X his left),
## measured from desk 2: keyboard x -0.11..0.31, 0.66 m ahead, top 0.777 m;
## mouse pad centred at x -0.24.
const HANDS := {
	"KeyboardHand": Vector3(0.27, 0.795, 0.55),
	"MouseHand": Vector3(-0.21, 0.79, 0.565),
	"KeyboardRightHand": Vector3(0.09, 0.795, 0.52),
}


static func seat_at_staff_desk(world: Node) -> void:
	var teacher := world.get_node_or_null("TeacherMale") as CharacterBody3D
	if teacher == null:
		return
	teacher.set_script(load(NPC_SCRIPT))
	teacher.position = SEAT
	teacher.rotation = Vector3(0.0, PI * 0.5, 0.0)
	for marker_name: String in HANDS:
		var marker := Marker3D.new()
		marker.name = marker_name
		marker.position = HANDS[marker_name]
		teacher.add_child(marker)
	teacher.set("seat_drop", SEAT_DROP)
	teacher.set("seat_forward", SEAT_FORWARD)
	teacher.set("lean_degrees", LEAN_DEGREES)
	teacher.set("left_hand_target", NodePath("KeyboardHand"))
	teacher.set("right_hand_target", NodePath("MouseHand"))
	teacher.set("right_typing_target", NodePath("KeyboardRightHand"))
	teacher.set("seated", true)
	# His computer is in use: the player cannot sit at it, and its screen
	# collider must not block looking at him.
	var computers := world.get_node_or_null("Computers")
	if computers:
		var hosts: PackedStringArray = computers.get("npc_used_hosts")
		if not DESK_HOST in hosts:
			hosts.append(DESK_HOST)
			computers.set("npc_used_hosts", hosts)
