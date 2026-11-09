class_name Talkable
extends StaticBody3D

## Makes an NPC something the player can look at and press F to talk to.
## Add it as a child of the NPC (it builds its own capsule on the interaction
## layer, so it never blocks walking). A mission sets `prompt` when the NPC has
## something to say and listens to `talked`. An empty prompt = not talkable now.

signal talked(player: Node)

## Same layer as computers and the desk phone: hit by the player's interact ray only.
const COLLISION_LAYER := 8

@export var display_name: String = "หัวหน้างาน"
var prompt: String = ""


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	set_meta(&"interactable", self)
	if get_child_count() == 0:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.75
		shape.shape = capsule
		shape.position = Vector3(0, 0.9, 0)
		add_child(shape)


func get_prompt_text() -> String:
	return prompt


func use(player: Node) -> void:
	if prompt != "":
		talked.emit(player)
