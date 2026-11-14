class_name ClassroomStudents
extends RefCounted

## Level 5 (user 2026-11-15): the class is in the computer room, so nobody
## walks the corridor (the housekeeper still does). The corridor students sit
## at the student PCs, working, and the owner of the infected PC-R3-L2 stands
## beside it watching the technician; once the computer is fixed (the report
## is sent and the player stands up) he sits down at it.
##
## The students become seated NPCs like the teachers (NpcCharacter, typing on
## the keyboard and mouse). Student desks have the same layout as the teacher's
## desk: the keyboard 0.70 m ahead of the seat, the seat 0.95 m behind the
## screen and 6 cm to the student's right, so the teachers' hand targets fit.
## Called by GameFlow.configure_level before the world enters the tree.

const NPC_SCRIPT := "res://scripts/npc/npc_character.gd"
const NODE := "ClassroomStudents"
## student_id -> the PC the student works at.
const SEATS := {
	"mullet": "PC-R1-L2",
	"bob": "PC-R1-R1",
	"wendy": "PC-R2-L1",
	"layer": "PC-R2-R2",
	"mullet_b": "PC-R3-L1",
	"bob_b": "PC-R4-R1",
	"two_block": "PC-R3-L2",
}
## The owner of the infected computer: stands beside it until it is fixed.
const WATCHER := "two_block"
const WATCHER_HOST := "PC-R3-L2"
## In the aisle at the end of the desk, a little behind the chair, looking at
## the screen over the technician's shoulder.
const WATCH_SPOT := Vector3(1.42, 0.02, 2.32)
## Student PC screens (map model): columns x and rows z; they all face +Z.
const COLUMNS := {"L1": -0.52, "L2": 0.68, "R1": 4.88, "R2": 6.08}
const ROW_Z := [-5.07, -1.97, 1.13, 4.23, 7.33]
const SEAT_BEHIND := 0.95
const SEAT_RIGHT := 0.06
## Facing the screen (-Z).
const YAW := PI
## Hand targets (keyboard left, mouse, keyboard right) from the teachers'
## desks, which have the same layout; seat drop for the 170 / 158 cm models.
const HANDS_MALE := [Vector3(0.27, 0.795, 0.55), Vector3(-0.21, 0.79, 0.565), Vector3(0.09, 0.795, 0.52)]
const HANDS_FEMALE := [Vector3(0.25, 0.79, 0.53), Vector3(-0.2, 0.785, 0.545), Vector3(0.08, 0.79, 0.5)]
const DROP_MALE := 0.42
const DROP_FEMALE := 0.35


## Moves the corridor students to their PCs (before the world is in the tree).
static func setup(world: Node) -> void:
	var corridor := world.get_node_or_null("CorridorStudents")
	if corridor == null:
		return
	var holder := Node3D.new()
	holder.name = NODE
	world.add_child(holder)
	for child in corridor.get_children():
		if child is CleanerCharacter or not child is StudentCharacter:
			continue
		var id: String = child.get("student_id")
		var tint: Color = child.get("hair_tint")
		corridor.remove_child(child)
		if not SEATS.has(id):
			child.free()
			continue
		holder.add_child(child)
		_seat_student(world, child as CharacterBody3D, id)
		if tint.a > 0.0:
			_tint_hair(child, tint)


## Screen centre of a student PC from its name, e.g. "PC-R3-L2".
static func screen_of(host: String) -> Vector3:
	var row := int(host.substr(4, 1)) - 1
	return Vector3(COLUMNS[host.substr(6, 2)], 1.07, ROW_Z[row])


static func seat_of(host: String) -> Vector3:
	var s := screen_of(host)
	return Vector3(s.x + SEAT_RIGHT, 0.02, s.z + SEAT_BEHIND)


static func chair_of(host: String) -> String:
	var side := "Left" if host.substr(6, 1) == "L" else "Right"
	return "Chair_StudentDesk_Row0%s_%s_%s" % [host.substr(4, 1), side, host.substr(7, 1)]


## The watcher (null when the level has none).
static func watcher(world: Node) -> NpcCharacter:
	return world.get_node_or_null("%s/%s" % [NODE, WATCHER]) as NpcCharacter


static func _seat_student(world: Node, person: CharacterBody3D, id: String) -> void:
	var host: String = SEATS[id]
	var female: bool = id in StudentLife.FEMALE
	person.name = id
	person.set_meta("student_id", id)
	var info := {
		"seat": seat_of(host), "host": host, "forward": 0.1, "lean": 12.0,
		"drop": DROP_FEMALE if female else DROP_MALE,
		"hands": HANDS_FEMALE if female else HANDS_MALE,
	}
	StaffRoomLife._seat(world, person, info)
	person.rotation = Vector3(0.0, YAW, 0.0)
	# Walks only for the watcher; the player is two levels up from here.
	person.set("blocker_path", NodePath("../../ITSupportPlayer"))
	StaffRoomLife.align_chair(world, chair_of(host), info["seat"], YAW)
	if id == WATCHER:
		# The player must be able to use PC-R3-L2 while he stands beside it.
		var computers := world.get_node_or_null("Computers")
		if computers:
			var hosts: PackedStringArray = computers.get("npc_used_hosts")
			var i := hosts.find(host)
			if i >= 0:
				hosts.remove_at(i)
				computers.set("npc_used_hosts", hosts)
	if female:
		_dress_seated(person)


## Seated, the skirt opens and the models' legs end above the knee: add the
## runtime thighs in the skirt's fabric and thicken the skirt a little, as
## for the female teacher (approved 2026-11-13).
static func _dress_seated(person: Node) -> void:
	var visual := person.get_node_or_null("Visual")
	if visual == null:
		return
	StudentThighs.add_to(visual)
	var skirt_material: Material = null
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		if "skirt" in String(mesh.name).to_lower():
			skirt_material = (mesh as MeshInstance3D).get_active_material(0)
			StaffRoomLife._inflate(mesh as MeshInstance3D, StaffRoomLife.SKIRT_INFLATE)
	var thighs := visual.find_child("Thighs (runtime)", true, false) as MeshInstance3D
	if thighs and skirt_material:
		thighs.material_override = skirt_material


## Same hair colour change as StudentCharacter._tint_hair (the "_b" students).
static func _tint_hair(person: Node, tint: Color) -> void:
	for mesh_node in person.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.resource_name.begins_with("Hair"):
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * Color(tint.r, tint.g, tint.b)
				mi.set_surface_override_material(i, copy)
