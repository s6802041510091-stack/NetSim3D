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

## The demo bench (top 0.90 m, edge z -7.91) is a closed cabinet with no knee
## space, so he sits back where the map's chair stands: knees 5 cm short of the
## top's edge, shoes at the cabinet's kick. He faces +Z (model forward), so his
## left (+X local) is world +X.
const SEAT := Vector3(-14.30, 0.02, -8.56)
const BENCH := "SCI_TeacherDemoBench"
const CHAIR := "SCI_TeacherChair"
## The map's chair faces away from the bench: it turns round under him and its
## gas lift goes up as far as he sits higher.
const CHAIR_RAISE := 0.12
const DROP := 0.34 # 12 cm higher than in the teachers' room: the lab bench is 0.90 m
const LEAN := 18.0
## The laptop the map bakes into the bench (0.40 m in from the edge, out of his
## reach from here) comes off the bench mesh; his own stands at the edge, the
## screen towards him. Base centre, on the bench top:
const LAPTOP := Vector3(-14.30, 0.91, -7.77)
## Left hand / right hand on the touchpad / right hand typing (teacher space).
const HANDS := [Vector3(0.11, 0.90, 0.73), Vector3(-0.02, 0.895, 0.67), Vector3(-0.09, 0.90, 0.74)]
const HAND_MARKERS := ["KeyboardHand", "MouseHand", "KeyboardRightHand"]

## The developer's credit, small in marker ink in the bottom-right corner of
## the science-room whiteboard (board face z -9.705, x -17.3..-13.1, y 0.93..2.18).
const CREDIT := "Develop by Weeraphat Krunitiwat\nTCT KMUTNB"
const CREDIT_POS := Vector3(-13.22, 1.02, -9.70)

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
	_place_chair(world)
	_move_laptop(world)
	_write_credit(world)
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


## Turns the map's chair round (backrest behind him, not between him and the
## bench), centres it under the seat and raises it.
static func _place_chair(world: Node) -> void:
	var visual := world.get_node_or_null("MapVisual") as Node3D
	var chair := visual.get_node_or_null(CHAIR) as MeshInstance3D if visual else null
	if chair == null:
		return
	# World space = the level root's space: setup() runs before it enters the tree.
	var to_world := visual.transform * chair.transform
	var center := to_world * chair.get_aabb().get_center()
	var turned := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Transform3D(to_world.basis, to_world.origin - center)
	turned.origin += Vector3(SEAT.x, center.y + CHAIR_RAISE, SEAT.z)
	chair.transform = visual.transform.affine_inverse() * turned


## Takes the baked laptop off the bench mesh (its keys share the polymer
## surface with the sink basin at the other end; its screen has a surface of
## its own) and builds the same laptop at the bench edge.
static func _move_laptop(world: Node) -> void:
	var visual := world.get_node_or_null("MapVisual") as Node3D
	var bench := visual.get_node_or_null(BENCH) as MeshInstance3D if visual else null
	if bench == null or bench.mesh == null:
		return
	var old := bench.mesh
	var mesh := ArrayMesh.new()
	var polymer: Material = null
	var screen: Material = null
	for surface in old.get_surface_count():
		var material := old.surface_get_material(surface)
		var arrays := old.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if material and material.resource_name.begins_with("DC | screen"):
			screen = material
			continue
		if material and material.resource_name.ends_with("Polymer"):
			polymer = material
			# Laptop: local x -1.07..-0.73; sink basin: x 0.96..1.34.
			var kept := PackedInt32Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				if verts[indices[i]].x < 0.0 and verts[indices[i + 1]].x < 0.0 and verts[indices[i + 2]].x < 0.0:
					continue
				kept.append_array([indices[i], indices[i + 1], indices[i + 2]])
			arrays[Mesh.ARRAY_INDEX] = kept
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	bench.mesh = mesh

	var laptop := Node3D.new()
	laptop.name = "StampLaptop"
	laptop.position = LAPTOP
	# Same parts as the baked one: base, lid tilted back 0.25 rad, screen on the lid.
	_box(laptop, Vector3(0.34, 0.02, 0.24), Vector3.ZERO, 0.0, polymer)
	_box(laptop, Vector3(0.34, 0.23, 0.015), Vector3(0, 0.12, 0.12), 0.25, polymer)
	_box(laptop, Vector3(0.30, 0.19, 0.004), Vector3(0, 0.12, 0.11), 0.25, screen)
	world.add_child(laptop)


## Small, faded marker writing tucked in the board's corner (reads from the class).
static func _write_credit(world: Node) -> void:
	var label := Label3D.new()
	label.name = "WhiteboardCredit"
	label.text = CREDIT
	label.font = GameUI.FONT_BOLD
	label.font_size = 32
	label.pixel_size = 0.0011
	label.outline_size = 0
	label.modulate = Color(0.10, 0.20, 0.55, 0.7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.line_spacing = -6.0
	label.shaded = false
	label.double_sided = false
	label.position = CREDIT_POS
	world.add_child(label)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, tilt: float, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var part := MeshInstance3D.new()
	part.mesh = box
	part.material_override = material
	part.position = pos
	part.rotation.x = tilt
	parent.add_child(part)


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
