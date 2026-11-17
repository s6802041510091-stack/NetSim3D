class_name NearLightShadows
extends Node
## "High" graphics quality: the ceiling light nearest the camera casts
## shadows, so desks, chairs and people stand on the floor instead of floating.
##
## Only one light at a time, and only lights the camera can see. Since
## 2026-11-18 the ceiling lights are spot lights under each panel
## (CeilingLights): a spot shadow is one extra render of what the cone
## covers. Omni lights still work (cube map, six renders: measured
## 2026-11-17 on a Ryzen 5 3500U at ~6-15 ms a frame for a 12 m room light).

## Omni lights with a larger range light a whole floor and never get a
## shadow (the old 35 m corridor light cost ~60 ms).
const MAX_RANGE := 20.0
## A new light takes over only when it is this much closer (no flicker at
## the midpoint between two lights).
const SWITCH_MARGIN := 1.0
const CHECK_EVERY := 0.25
## Line of sight is tested against the building only (walls, doors, glass:
## layer 1), not students (layer 2), so passers-by don't flick the shadow.
const SIGHT_MASK := 1
## In the Compatibility renderer (Godot 4.7.2) an omni light lights the room
## about six times as strongly once it casts shadows. Measured 2026-11-17 in
## the IT Support room, science lab and storeroom: at 0.15-0.2 of its energy
## the room's brightness matches the shadowless light (average difference
## under 2 %). Re-measure this after a Godot upgrade.
const OMNI_SHADOW_ENERGY := 0.17
## Spot lights (the ceiling panels) behave the same way. Measured 2026-11-18
## in the IT Support room, science lab and teachers' room: at 0.15 the room's
## brightness is within 2 % of the shadowless light; the shadow added
## 0-9 ms a frame.
const SPOT_SHADOW_ENERGY := 0.15
## A spot light is used for shadows while the camera is within its range
## plus this much (its cone lights the floor around the camera).
const SPOT_REACH := 3.0

var _lights: Array[Light3D] = []
var _current: Light3D
var _current_energy := 0.0
var _clock := CHECK_EVERY


func _ready() -> void:
	# Levels open paused behind the "ready" prompt and F1 pauses the game;
	# the world is still on screen then, so keep choosing the light.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node in get_parent().find_children("*", "Light3D", true, false):
		if node is OmniLight3D and node.omni_range <= MAX_RANGE and not node.shadow_enabled:
			node.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
			_lights.append(node)
		elif node is SpotLight3D and not node.shadow_enabled:
			_lights.append(node)


# Physics step: the line-of-sight ray needs the physics space.
func _physics_process(delta: float) -> void:
	_clock += delta
	if _clock >= CHECK_EVERY:
		_clock = 0.0
		_update()


func _exit_tree() -> void:
	_use(null)


func _update() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var space := camera.get_world_3d().direct_space_state
	var skip := _own_bodies(camera)
	var best: Light3D
	var best_distance := INF
	for light in _lights:
		if not _usable(light, eye):
			continue
		var distance := eye.distance_to(light.global_position)
		if distance < best_distance and _seen(space, eye, light, skip):
			best = light
			best_distance = distance
	if best != _current and _usable(_current, eye) and _seen(space, eye, _current, skip):
		if eye.distance_to(_current.global_position) <= best_distance + SWITCH_MARGIN:
			return
	_use(best)


func _usable(light: Light3D, eye: Vector3) -> bool:
	return is_instance_valid(light) and light.is_visible_in_tree() \
		and eye.distance_to(light.global_position) < _reach(light)


func _reach(light: Light3D) -> float:
	return light.spot_range + SPOT_REACH if light is SpotLight3D else light.omni_range


## A light behind a wall or a closed door lights nothing the player sees, so
## its shadow would only cost time (the corridor used to pick the science lab
## light through the wall).
func _seen(space: PhysicsDirectSpaceState3D, eye: Vector3, light: Light3D, skip: Array[RID]) -> bool:
	if space == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(eye, light.global_position, SIGHT_MASK, skip)
	return space.intersect_ray(query).is_empty()


## The player's own body around the camera must not block the ray.
func _own_bodies(camera: Node) -> Array[RID]:
	var bodies: Array[RID] = []
	var node := camera.get_parent()
	while node:
		if node is CollisionObject3D:
			bodies.append((node as CollisionObject3D).get_rid())
		node = node.get_parent()
	return bodies


func _use(light: Light3D) -> void:
	if light == _current:
		return
	if is_instance_valid(_current):
		_current.shadow_enabled = false
		_current.light_energy = _current_energy
	_current = light
	if light:
		_current_energy = light.light_energy
		light.light_energy = _current_energy * (SPOT_SHADOW_ENERGY if light is SpotLight3D else OMNI_SHADOW_ENERGY)
		light.shadow_enabled = true


## For checks: the light that casts shadows now (or null).
func current_light() -> Light3D:
	return _current
