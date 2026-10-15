extends CharacterBody3D

@export_group("Movement")
@export var walk_speed: float = 3.2
@export var run_speed: float = 5.8
@export var acceleration: float = 14.0
@export var deceleration: float = 18.0
@export var gravity: float = 9.8
@export var max_step_height: float = 0.28
@export var step_forward_distance: float = 0.30

@export_group("Camera")
@export var look_sensitivity: float = 0.0025
@export var minimum_look_angle: float = -1.48
@export var maximum_look_angle: float = 1.48
@export var require_mouse_capture: bool = true

@export_group("Interaction")
## How far in front of the camera the player can reach a door or computer, in metres.
@export var interact_distance: float = 2.2
## When the door is open the leaf is out of the way, so looking at the doorway
## within this angle (degrees) also selects the door.
@export var doorway_look_angle: float = 30.0

@onready var camera: Camera3D = $Camera3D
@onready var visual: Node3D = $Visual

var focused_door: InteractiveDoor = null
var focused_computer: ComputerStation = null
## Any other object with the "interactable" meta and get_prompt_text()/use(player),
## e.g. the desk phone in the IT Support room (Mission 6).
var focused_interactable: Object = null
## True while the player is sitting at a computer.
var controls_locked := false
var _camera_home := Transform3D.IDENTITY
var _camera_tween: Tween
var _interact_ray: RayCast3D
var _prompt: Label
var _blocked_message_time := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = maxf(floor_snap_length, max_step_height + 0.04)
	# Show the real skinned trousers and shoes without letting the head, hair,
	# hands or polo shirt block the first-person camera.
	_set_first_person_layers(visual)
	_create_interaction()


func _create_interaction() -> void:
	_interact_ray = RayCast3D.new()
	_interact_ray.name = "InteractRay"
	_interact_ray.target_position = Vector3(0.0, 0.0, -interact_distance)
	_interact_ray.collision_mask = 1 | ComputerStation.COLLISION_LAYER
	_interact_ray.add_exception(self)
	camera.add_child(_interact_ray)

	var hud := CanvasLayer.new()
	hud.name = "InteractionHUD"
	add_child(hud)
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -120.0
	_prompt.offset_bottom = -80.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	hud.add_child(_prompt)


func _update_interaction() -> void:
	focused_door = null
	focused_computer = null
	focused_interactable = null
	if controls_locked:
		_prompt.visible = false
		return
	if _interact_ray.is_colliding():
		var collider := _interact_ray.get_collider()
		focused_door = InteractiveDoor.from_collider(collider)
		focused_computer = ComputerStation.from_collider(collider)
		if focused_computer == null and collider != null and collider.has_meta("interactable"):
			var other: Object = collider.get_meta("interactable")
			if other.has_method("use") and other.has_method("get_prompt_text") and String(other.call("get_prompt_text")) != "":
				focused_interactable = other
	if focused_door == null and focused_computer == null and focused_interactable == null:
		focused_door = _find_doorway_in_view()

	if _blocked_message_time > 0.0:
		_prompt.text = "มีคนยืนขวางประตูอยู่"
		_prompt.visible = true
	elif focused_door != null and not focused_door.is_moving:
		_prompt.text = focused_door.get_prompt_text()
		_prompt.visible = true
	elif focused_computer != null:
		_prompt.text = focused_computer.get_prompt_text()
		_prompt.visible = true
	elif focused_interactable != null:
		_prompt.text = String(focused_interactable.call("get_prompt_text"))
		_prompt.visible = true
	else:
		_prompt.visible = false


func _find_doorway_in_view() -> InteractiveDoor:
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	var wall_distance := INF
	if _interact_ray.is_colliding():
		wall_distance = eye.distance_to(_interact_ray.get_collision_point())
	var best: InteractiveDoor = null
	var best_angle := deg_to_rad(doorway_look_angle)
	for node in get_tree().get_nodes_in_group(InteractiveDoor.GROUP):
		var door := node as InteractiveDoor
		var to_door := door.get_doorway_center() - eye
		var distance := to_door.length()
		# Skip doors out of reach or behind a wall the player is looking at.
		if distance > interact_distance or distance > wall_distance + 0.3:
			continue
		var angle := forward.angle_to(to_door)
		if angle < best_angle:
			best_angle = angle
			best = door
	return best


func interact() -> void:
	if controls_locked:
		return
	if focused_computer != null:
		focused_computer.use(self)
	elif focused_interactable != null:
		focused_interactable.call("use", self)
	elif focused_door != null and not focused_door.toggle() and not focused_door.is_moving:
		_blocked_message_time = 1.2


func set_controls_locked(locked: bool) -> void:
	controls_locked = locked
	velocity.x = 0.0
	velocity.z = 0.0
	_prompt.visible = false
	if not locked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Moves the first-person camera to a world pose (e.g. in front of a screen).
func move_camera_to(target: Transform3D, duration: float) -> void:
	_camera_home = camera.transform
	camera.top_level = true # Keeps its world pose while detached from the head.
	await _tween_camera(target, duration)


## Brings the camera back to the player's eyes.
func return_camera(duration: float) -> void:
	await _tween_camera(global_transform * _camera_home, duration)
	camera.top_level = false
	camera.transform = _camera_home


func _tween_camera(target: Transform3D, duration: float) -> void:
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "global_transform", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _camera_tween.finished


func _set_first_person_layers(node: Node) -> void:
	if node is VisualInstance3D:
		var part: VisualInstance3D = node
		if part.name.begins_with("Trousers") or part.name.begins_with("Shoes"):
			part.layers = 3 # World layer and self-view layer.
		else:
			part.layers = 2 # Hidden from this camera (cull_mask = 1).
	for child in node.get_children():
		_set_first_person_layers(child)


func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		if not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			interact()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * look_sensitivity)
		camera.rotate_x(-event.relative.y * look_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, minimum_look_angle, maximum_look_angle)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()
	if was_on_floor:
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	var input_direction := Vector2.ZERO
	if controls_locked:
		pass # Sitting at a computer: no walking.
	elif not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var move_direction := global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	var target_speed := run_speed if Input.is_action_pressed("run") else walk_speed
	var target_velocity := move_direction * target_speed
	var rate := acceleration if input_direction != Vector2.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	if was_on_floor and is_on_wall():
		_try_step_up(horizontal_motion)

	_blocked_message_time = maxf(_blocked_message_time - delta, 0.0)
	_update_interaction()


func _try_step_up(horizontal_motion: Vector3) -> void:
	if horizontal_motion.length_squared() < 0.000001:
		return
	# Probe far enough onto the tread for the capsule to meet its flat top.
	# A single frame of motion would hit the tread edge at an unusable angle.
	var step_motion := horizontal_motion.normalized() * maxf(horizontal_motion.length(), step_forward_distance)

	var lift := Vector3.UP * max_step_height
	if test_move(global_transform, lift):
		return # A low ceiling blocks the character from rising.

	var raised := global_transform
	raised.origin += lift
	if test_move(raised, step_motion):
		return # The obstacle is taller than a step or the landing is blocked.

	var landing := raised
	landing.origin += step_motion
	var floor_hit := KinematicCollision3D.new()
	if not test_move(landing, Vector3.DOWN * (max_step_height + 0.04), floor_hit):
		return
	if floor_hit.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return # Do not stand on a wall or a steep slope.

	var rise := max_step_height + floor_hit.get_travel().y
	if rise < 0.015 or rise > max_step_height + 0.005:
		return

	global_position = landing.origin + floor_hit.get_travel()
	velocity.y = 0.0
	apply_floor_snap()
