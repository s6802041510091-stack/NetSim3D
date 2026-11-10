class_name InteractSpot
extends StaticBody3D

## An invisible box the player can look at and press F to use (e.g. the wall
## rack or the back of a PC during a mission). Hit by the interact ray only
## while it has a prompt, so it never gets in the way otherwise.

signal used(player: Node)

const COLLISION_LAYER := 8

@export var size := Vector3(0.4, 0.4, 0.4)
var prompt := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_meta(&"interactable", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func set_prompt(text: String) -> void:
	prompt = text
	collision_layer = COLLISION_LAYER if text != "" else 0


func get_prompt_text() -> String:
	return prompt


func use(player: Node) -> void:
	if prompt != "":
		used.emit(player)
