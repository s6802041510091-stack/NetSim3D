class_name CrimpStation
extends StaticBody3D

## The work spot on the spare desk: look at it and press F to sit and crimp.
## Holds the CrimpBench (the cable end). A mission sets `prompt` when the
## player may use it and listens to `used`.

signal used(player: Node)

const COLLISION_LAYER := 8

var prompt := ""
var bench: CrimpBench


func _ready() -> void:
	# Off until the crimping stage: its box covers the tools on the desk.
	collision_layer = 0
	collision_mask = 0
	set_meta(&"interactable", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.16, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 0.07, 0)
	add_child(shape)
	bench = CrimpBench.new()
	bench.name = "CrimpBench"
	bench.position = Vector3(0, CrimpBench.JACKET_RADIUS + 0.002, 0)
	add_child(bench)


## Shows the prompt and makes the desk spot hit by the interact ray.
func set_prompt(text: String) -> void:
	prompt = text
	collision_layer = COLLISION_LAYER if text != "" else 0


func get_prompt_text() -> String:
	return prompt


func use(player: Node) -> void:
	if prompt != "":
		used.emit(player)
