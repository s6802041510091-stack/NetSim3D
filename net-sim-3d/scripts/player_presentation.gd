extends Node

const HELD_ITEMS = preload("res://scripts/held_item_catalog.gd")
const HAND_POSITION := Vector3(0.075, -0.18, -0.48)
# Reference: forearm enters from bottom-right; thumb below the index finger.
# Keep orientation fixed even while walking/using; only translate for motion.
const HAND_ROTATION := Vector3(-15, 0, 45)
const ARM_TWIST := PI / 3.0

## Procedural walk/run pose plus a separate first-person viewmodel viewport.
## Never modifies the camera pose used by computer interaction or body collision.
var player: CharacterBody3D
var hand: Node3D
var hand_view: SubViewportContainer
var skeleton: Skeleton3D
var bones: Dictionary = {}
var phase := 0.0
var blend := 0.0
var use_time := 0.0
var _hud: CanvasLayer
var grip: Node3D
var held_model: Node3D
var relaxed_arm: Node3D
var gripping_arm: Node3D
var _grip_poses: Dictionary = {}
var preview_id := ""

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	for node in player.get_node("Visual").find_children("*", "Skeleton3D", true, false):
		skeleton = node
		break
	if skeleton:
		for name in ["upperleg01.L", "upperleg01.R", "lowerleg01.L", "lowerleg01.R", "upperarm01.L", "upperarm01.R"]:
			var index := skeleton.find_bone(name)
			if index >= 0:
				bones[name] = {"index": index, "rest": skeleton.get_bone_pose_rotation(index), "axis": skeleton.get_bone_global_rest(index).basis.inverse() * Vector3.RIGHT}
	_build_hand()

func _build_hand() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 3
	add_child(_hud)
	hand_view = SubViewportContainer.new()
	hand_view.stretch = true
	hand_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hand_view)
	# Scale with the game window instead of a small fixed 320px corner.
	hand_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_view.anchor_left = 0.5
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.size = Vector2i(320, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	hand_view.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 55
	viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -30, 0)
	viewport.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.65
	viewport.add_child(environment)
	hand = Node3D.new()
	viewport.add_child(hand)
	hand.position = HAND_POSITION
	hand.rotation_degrees = HAND_ROTATION
	var original_arm: Node3D = load("res://assets/models/player_right_arm.glb").instantiate()
	original_arm.name = "OriginalAvatarRightArm"
	original_arm.rotation.y = PI + ARM_TWIST
	hand.add_child(original_arm)
	for mesh in original_arm.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gripping_arm = original_arm
	relaxed_arm = load("res://assets/models/player_right_arm_relaxed.glb").instantiate()
	relaxed_arm.name = "OriginalAvatarRelaxedArm"
	relaxed_arm.rotation.y = PI + ARM_TWIST
	hand.add_child(relaxed_arm)
	for mesh in relaxed_arm.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gripping_arm.hide()
	grip = Node3D.new()
	grip.name = "ItemGrip"
	grip.position = Basis(Vector3.UP, ARM_TWIST) * Vector3(0, 0.085, -0.045)
	hand.add_child(grip)


## Shows a real tool in the first-person hand (tools and tests only; the game
## has no inventory). An empty id returns to empty hands.
func preview_item(id: String) -> bool:
	if not id.is_empty() and not HELD_ITEMS.TOOLS.has(id):
		return false
	preview_id = id
	_show_held_item(id)
	return true

func _show_held_item(id: String) -> void:
	relaxed_arm.visible = id.is_empty()
	gripping_arm.hide()
	if is_instance_valid(held_model):
		grip.remove_child(held_model)
		held_model.queue_free()
		held_model = null
	if id.is_empty():
		return
	var entry: Dictionary = HELD_ITEMS.TOOLS[id]
	if not _grip_poses.has(id):
		var pose: Node3D = entry.hand_scene.instantiate()
		pose.name = "GripPose_" + id
		pose.rotation.y = PI + ARM_TWIST
		hand.add_child(pose)
		for mesh in pose.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_grip_poses[id] = pose
	gripping_arm = _grip_poses[id]
	gripping_arm.show()
	held_model = entry.scene.instantiate()
	held_model.name = "Held_" + id
	grip.add_child(held_model)
	# Keep the tool upright in the reference framing while the forearm enters diagonally.
	var rest_basis := Basis.from_euler(HAND_ROTATION * PI / 180.0)
	held_model.basis = rest_basis.inverse() * Basis.from_euler(entry.rotation * PI / 180.0)
	held_model.scale = Vector3.ONE * entry.scale
	# Put the actual model's handle in the avatar palm, not at its file origin.
	held_model.position = -(held_model.basis * entry.handle) + entry.get("offset", Vector3.ZERO)
	var correction: Vector3 = entry.get("fit_offset", Vector3.ZERO)
	held_model.position += gripping_arm.basis * Vector3(correction.x, correction.z, -correction.y)
	for mesh in held_model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func play_use() -> void:
	use_time = 0.32

func _process(delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var moving: bool = speed > 0.1 and player.is_on_floor() and not player.controls_locked
	blend = move_toward(blend, minf(speed / player.walk_speed, 1.5) if moving else 0.0, delta * 5)
	phase += delta * (11.0 if speed > player.walk_speed + 0.3 else 7.0)
	use_time = maxf(0, use_time - delta)
	hand_view.visible = not player.controls_locked
	var reach := sin((1.0 - use_time / 0.32) * PI) if use_time > 0 else 0.0
	hand.position = HAND_POSITION + Vector3(sin(phase) * 0.010 * blend, cos(phase * 2) * 0.009 * blend, -reach * 0.06)
	hand.rotation_degrees = HAND_ROTATION
	if skeleton:
		for name: String in bones:
			var entry: Dictionary = bones[name]
			var stride := sin(phase + (PI if name.ends_with(".R") else 0.0)) * blend
			var angle := stride * 0.35
			if name.begins_with("lowerleg"):
				angle = maxf(0.0, -stride) * 0.45
			elif name.begins_with("upperarm"):
				angle = -stride * 0.25
			skeleton.set_bone_pose_rotation(entry.index, entry.rest * Quaternion(Vector3(entry.axis).normalized(), angle))
