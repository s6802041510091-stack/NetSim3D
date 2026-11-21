class_name ScienceTeacher
extends Node

## ครูแสตมป์: a male teacher who stands in for the game's developer. He sits
## at the laptop on the teacher's demo bench in the science room in every
## level, typing. E on him: he turns to the player and says a short welcome,
## then goes back to work. No part in any mission or score.
## GameFlow.configure_level calls setup() before the world enters the tree.

const NPC_SCRIPT := "res://scripts/npc/npc_character.gd"
const SCENE := "res://scenes/teacher_male.tscn"
const SELF := "res://scripts/npc/science_teacher.gd"
const NODE_NAME := "TeacherStamp"
const NAME := "ครูแสตมป์"
const LINES := [
	"สวัสดีนักเรียน สนุกกับ รร. นี้รึเปล่า",
	"ครูหวังว่าเธอจะชอบ รร. นี้นะ เพราะครูตั้งใจพัฒนาจริงๆ",
]

## The laptop sits on the demo bench (top 0.90 m, front edge z -7.91) with its
## keyboard around (-14.30, -7.52); the screen faces the chair (-Z). He sits
## facing +Z (model forward), so his left (+X local) is world +X.
const SEAT := Vector3(-14.30, 0.02, -8.17)
const CHAIR := "SCI_TeacherChair"
## The map's chair stands 1.1 m from the laptop: it moves this far toward the bench.
const CHAIR_FORWARD := 0.38
## ...and its gas lift goes up as far as he sits higher.
const CHAIR_RAISE := 0.12
const DROP := 0.34 # 12 cm higher than in the teachers' room: the lab bench is 0.90 m
const LEAN := 12.0
## Left hand / right hand on the touchpad / right hand typing (teacher space).
const HANDS := [Vector3(0.11, 0.90, 0.60), Vector3(-0.02, 0.895, 0.52), Vector3(-0.09, 0.90, 0.61)]
const HAND_MARKERS := ["KeyboardHand", "MouseHand", "KeyboardRightHand"]

## Clothes: shirt, trousers and stitching colours, and whether the khaki
## uniform's epaulets stay. Picked by the user from in-game previews.
const OUTFITS := {
	"khaki": {"shirt": Color(0, 0, 0, 0), "trousers": Color(0, 0, 0, 0), "epaulets": true},
	"white": {"shirt": Color(0.93, 0.94, 0.95), "trousers": Color(0.16, 0.17, 0.19), "epaulets": false},
	"blue": {"shirt": Color(0.62, 0.76, 0.90), "trousers": Color(0.17, 0.21, 0.30), "epaulets": false},
}
static var outfit := "white"

var teacher: NpcCharacter
var dialogue: DialogueBox
var _busy := false


static func setup(world: Node, _level: int) -> void:
	if world.get_node_or_null(NODE_NAME):
		return
	var body: CharacterBody3D = (load(SCENE) as PackedScene).instantiate()
	body.name = NODE_NAME
	dress(body, outfit)
	body.set_script(load(NPC_SCRIPT))
	body.position = SEAT
	body.rotation = Vector3.ZERO
	for i in HAND_MARKERS.size():
		var marker := Marker3D.new()
		marker.name = HAND_MARKERS[i]
		marker.position = HANDS[i]
		body.add_child(marker)
	body.set("seat_drop", DROP)
	body.set("seat_forward", 0.1)
	body.set("lean_degrees", LEAN)
	body.set("left_hand_target", NodePath(HAND_MARKERS[0]))
	body.set("right_hand_target", NodePath(HAND_MARKERS[1]))
	body.set("right_typing_target", NodePath(HAND_MARKERS[2]))
	body.set("seated", true)
	world.add_child(body)
	_move_chair(world)
	StaffRoomLife.align_chair(world, CHAIR, SEAT, 0.0)
	var life: Node = (load(SELF) as GDScript).new()
	life.name = "ScienceTeacher"
	life.set("teacher", body)
	world.add_child(life)


## Recolours the khaki uniform (copies of the materials; the GLB is unchanged).
static func dress(body: Node, id: String) -> void:
	var look: Dictionary = OUTFITS.get(id, OUTFITS["khaki"])
	var shirt: Color = look["shirt"]
	if shirt.a == 0.0:
		return
	var trousers: Color = look["trousers"]
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if String(mesh.name).begins_with("Uniform | epaulets") and not look["epaulets"]:
			mesh.visible = false
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var tint := Color(0, 0, 0, 0)
			if "khaki tailored trousers" in material.resource_name:
				tint = trousers
			elif "khaki cotton twill" in material.resource_name:
				tint = shirt
			elif "tonal khaki" in material.resource_name:
				tint = shirt.darkened(0.12)
			if tint.a > 0.0:
				var copy := material.duplicate() as BaseMaterial3D
				copy.albedo_color = tint
				mesh.set_surface_override_material(surface, copy)


## Slides the map's chair toward the bench so it sits under him.
static func _move_chair(world: Node) -> void:
	var visual := world.get_node_or_null("MapVisual") as Node3D
	var chair := visual.get_node_or_null(CHAIR) as Node3D if visual else null
	if chair:
		chair.position += visual.basis.inverse() * Vector3(0, CHAIR_RAISE, CHAIR_FORWARD)


func _ready() -> void:
	dialogue = DialogueBox.new()
	dialogue.name = "StampTalkBox"
	add_child(dialogue)
	var talk := Talkable.new()
	talk.name = "Talk"
	talk.display_name = NAME
	talk.prompt = "กด E เพื่อคุยกับ" + NAME
	teacher.add_child(talk)
	talk.talked.connect(talk_to)


## E on him: turn to the player, the welcome, back to the laptop.
func talk_to(player: Node) -> void:
	if _busy:
		return
	_busy = true
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	if player is Node3D:
		await teacher.turn_to(player)
	var lines := PackedStringArray()
	for line: String in LINES:
		lines.append(NAME + "|" + line)
	dialogue.show_lines(lines)
	await dialogue.finished
	teacher.turn_back()
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_busy = false
