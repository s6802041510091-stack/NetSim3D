class_name PickupItem
extends StaticBody3D

## Something on a desk the player can pick up with F into the tool case
## (PlayerPresentation inventory). It sits on the interaction layer, so it
## never blocks walking. A mission turns it on with `available` and listens to
## `picked_up`. Its collision box is fitted to the visual when it is ready.

signal picked_up(item_id: String)

const COLLISION_LAYER := 8

@export var item_id := ""
@export var title := ""
## Only pickable while true (e.g. after the briefing).
@export var available := false

var taken := false


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	set_meta(&"interactable", self)
	var bounds := _visual_bounds()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (bounds.size + Vector3(0.04, 0.04, 0.04)).max(Vector3(0.08, 0.06, 0.08))
	shape.shape = box
	shape.position = bounds.get_center()
	add_child(shape)


func get_prompt_text() -> String:
	if taken or not available:
		return ""
	return "กด F เพื่อหยิบ " + title


func use(player: Node) -> void:
	if taken or not available:
		return
	var presentation: Node = player.get("presentation") if player else null
	if presentation and presentation.has_method("add_item"):
		if not presentation.call("add_item", item_id, title):
			return
	take()


## Removes the item from the desk (also used by tests and the mission).
func take() -> void:
	if taken:
		return
	taken = true
	visible = false
	collision_layer = 0
	Sound.play("select")
	picked_up.emit(item_id)


## The visual's box in this node's space (children meshes only).
func _visual_bounds() -> AABB:
	var result := AABB()
	var first := true
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		if m.mesh == null:
			continue
		var local := global_transform.affine_inverse() * m.global_transform
		var box := local * m.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result if not first else AABB(Vector3(-0.05, 0, -0.05), Vector3(0.1, 0.05, 0.1))
