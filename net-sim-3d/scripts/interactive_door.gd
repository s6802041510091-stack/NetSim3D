class_name InteractiveDoor
extends Node3D

## A hinged door that the player opens or closes with the interact key (E).
##
## The door leaf, kick plates, handles and levers already exist in the map
## model (classroom_shell.glb), exported in their OPEN pose. Place this node on
## the hinge line and rotate it to the CLOSED pose: at start-up the door
## collects its parts from the map, works out how far the model swings open,
## and gives the leaf a moving collider.

signal state_changed(is_open: bool)

## Mesh name endings that move with the leaf, e.g. "Server_" + "Leaf".
const PART_KINDS: PackedStringArray = ["Leaf", "Kick_Plate", "Handle_Base", "Lever"]
## Characters (player and NPCs) live on physics layer 2.
const CHARACTER_LAYER_MASK := 2
const META_KEY := &"interactive_door"
const GROUP := &"interactive_doors"

@export var map_visual_path: NodePath = ^"../../MapVisual"
## Start of the mesh names in the map model, e.g. "Server_" or "Door_".
@export var part_prefix: String = ""
## Room name shown in the on-screen prompt.
@export var display_name: String = ""
@export var start_open: bool = false
@export_range(0.1, 3.0, 0.05) var swing_time: float = 0.55
## The Blender presentation pose may be only 65 degrees. Open at least square
## to the wall so a player capsule can enter AND leave without snagging the tip.
@export_range(90.0, 120.0, 1.0) var minimum_open_degrees: float = 90.0
## For a leaf modelled without hardware: copy the handles, levers and kick
## plates of the door with this part prefix (e.g. "BackgroundClass_").
@export var borrow_hardware_from: String = ""
## Some models are posed open past square (the computer room door at 117°),
## which turns the leaf's hinge edge back into its own jamb. Cap the swing.
@export_range(90.0, 180.0, 1.0) var maximum_open_degrees: float = 180.0

var is_open := false
var is_moving := false

var _open_angle := 0.0
var _doorway_local := Vector3.ZERO
var _swing: Node3D
var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _tween: Tween


func _ready() -> void:
	var visual := get_node_or_null(map_visual_path)
	if visual == null:
		push_error("%s: map visual not found at %s" % [name, map_visual_path])
		return

	var parts: Array[MeshInstance3D] = []
	var leaf: MeshInstance3D = null
	for child in visual.get_children():
		if child is MeshInstance3D and _is_door_part(String(child.name)):
			parts.append(child)
			if leaf == null and String(child.name).begins_with(part_prefix + "Leaf"):
				leaf = child
	if leaf == null:
		push_error("%s: no door leaf named '%sLeaf...' in the map model" % [name, part_prefix])
		return

	# How far the model's leaf is swung from this node's closed pose.
	var relative := (global_basis.inverse() * leaf.global_basis).orthonormalized()
	var authored_angle := relative.get_euler().y
	_open_angle = signf(authored_angle) * clampf(absf(authored_angle), deg_to_rad(minimum_open_degrees), deg_to_rad(maxf(maximum_open_degrees, minimum_open_degrees)))

	_swing = Node3D.new()
	_swing.name = "Swing"
	add_child(_swing)
	# Capture the authored pose before extending its swing; using the extended
	# angle here would offset the leaf from its jamb when we close it again.
	_swing.rotation.y = authored_angle
	for part in parts:
		part.reparent(_swing, true)

	_build_collider(leaf)
	# Centre of the closed leaf: the middle of the doorway, in this node's space.
	_doorway_local = _body.transform * _shape.position
	add_to_group(GROUP)

	is_open = start_open
	_swing.rotation.y = _open_angle if is_open else 0.0
	if borrow_hardware_from != "":
		# The other door may not be set up yet; wait until every door is.
		_borrow_hardware.call_deferred(leaf)


## Copies the handles, levers and kick plates of the door whose parts start
## with `borrow_hardware_from` onto this leaf. Every door is described in its
## closed pose with the hinge at 0 (see _ready), so the parts are mapped from
## that door's leaf span across the width (Z) onto this one: flipped when this
## leaf hangs the other way, scaled to its width, Y (height) unchanged.
func _borrow_hardware(leaf: MeshInstance3D) -> void:
	var source: InteractiveDoor = null
	for door in get_tree().get_nodes_in_group(GROUP):
		if door != self and door.part_prefix == borrow_hardware_from and door._swing != null:
			source = door
	if source == null:
		push_warning("%s: no door with parts '%s' to copy the handles from" % [name, borrow_hardware_from])
		return
	var from_leaf: MeshInstance3D = null
	var hardware: Array[MeshInstance3D] = []
	for part in source._swing.get_children():
		if not part is MeshInstance3D:
			continue
		if String(part.name).begins_with(borrow_hardware_from + "Leaf"):
			from_leaf = part
		else:
			hardware.append(part)
	if from_leaf == null or hardware.is_empty():
		return
	var from_span := _span_z(from_leaf, source._swing)
	var to_span := _span_z(leaf, _swing)
	# Hinge-side and free-side ends of each leaf (nearest / farthest from 0).
	var from_hinge := from_span.x if absf(from_span.x) < absf(from_span.y) else from_span.y
	var from_free := from_span.y if from_hinge == from_span.x else from_span.x
	var to_hinge := to_span.x if absf(to_span.x) < absf(to_span.y) else to_span.y
	var to_free := to_span.y if to_hinge == to_span.x else to_span.x
	var z_scale := (to_free - to_hinge) / (from_free - from_hinge)
	# A negative Z scale also flips X, which keeps it a turn (no mirrored parts).
	var mapping := Transform3D(Basis.from_scale(Vector3(signf(z_scale), 1.0, z_scale)), Vector3(0, 0, to_hinge - from_hinge * z_scale))
	for part in hardware:
		var copy := part.duplicate() as MeshInstance3D
		copy.name = part_prefix + String(part.name).trim_prefix(borrow_hardware_from)
		_swing.add_child(copy)
		copy.transform = mapping * (source._swing.global_transform.affine_inverse() * part.global_transform)


## The leaf's extent across the doorway (Z) in `frame` (the closed-door space).
func _span_z(mesh: MeshInstance3D, frame: Node3D) -> Vector2:
	var to_frame := frame.global_transform.affine_inverse() * mesh.global_transform
	var box := mesh.get_aabb()
	var low := INF
	var high := -INF
	for i in 8:
		var z: float = (to_frame * box.get_endpoint(i)).z
		low = minf(low, z)
		high = maxf(high, z)
	return Vector2(low, high)


func _is_door_part(mesh_name: String) -> bool:
	for kind in PART_KINDS:
		if mesh_name.begins_with(part_prefix + kind):
			return true
	return false


func _build_collider(leaf: MeshInstance3D) -> void:
	# Physics bodies must not be scaled, so the leaf's scale goes into the box.
	var leaf_scale := leaf.transform.basis.get_scale()
	var aabb := leaf.get_aabb()
	var box := BoxShape3D.new()
	box.size = aabb.size * leaf_scale

	_body = AnimatableBody3D.new()
	_body.name = "Collider"
	_body.collision_layer = 1
	_body.collision_mask = 0
	# The body follows the Swing node it hangs from. Physics sync would make the
	# body ignore its parent's rotation, so it is turned off.
	_body.sync_to_physics = false
	_body.set_meta(META_KEY, self)
	_swing.add_child(_body)
	_body.transform = leaf.transform.orthonormalized()

	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position = aabb.get_center() * leaf_scale
	_body.add_child(_shape)


## Opens a closed door or closes an open one. Returns false if it cannot move.
func toggle() -> bool:
	if is_moving:
		return false
	return set_open(not is_open)


func set_open(value: bool, animate: bool = true) -> bool:
	if _swing == null:
		return false
	if value == is_open and not is_moving:
		return true
	var target := _open_angle if value else 0.0
	if _is_path_blocked(target):
		if animate:
			Sound.play("door_blocked", _swing)
		return false

	is_open = value
	if animate and value:
		Sound.play("door_open", _swing)
	if _tween:
		_tween.kill()
	if not animate:
		_swing.rotation.y = target
		is_moving = false
		state_changed.emit(is_open)
		return true

	is_moving = true
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_swing, "rotation:y", target, swing_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_on_swing_finished)
	return true


func _on_swing_finished() -> void:
	is_moving = false
	if not is_open:
		Sound.play("door_close", _swing) # the latch clicks shut
	state_changed.emit(is_open)


## True when a character stands where the leaf would sweep through.
func _is_path_blocked(target_angle: float) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.collision_mask = CHARACTER_LAYER_MASK
	query.margin = 0.02
	var start_angle := _swing.rotation.y
	const SAMPLES := 6
	for i in range(1, SAMPLES + 1):
		var angle := lerpf(start_angle, target_angle, float(i) / SAMPLES)
		var swing_transform := global_transform * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
		query.transform = swing_transform * _body.transform * _shape.transform
		if not space.intersect_shape(query, 1).is_empty():
			return true
	return false


## World position of the middle of the doorway (where the closed leaf sits).
func get_doorway_center() -> Vector3:
	return global_transform * _doorway_local


func get_prompt_text() -> String:
	var action := "ปิด" if is_open else "เปิด"
	var room := (" " + display_name) if display_name != "" else ""
	return "[F] %sประตู%s" % [action, room]


## Returns the door that owns this collider, or null.
static func from_collider(collider: Object) -> InteractiveDoor:
	if collider != null and collider.has_meta(META_KEY):
		return collider.get_meta(META_KEY) as InteractiveDoor
	return null
