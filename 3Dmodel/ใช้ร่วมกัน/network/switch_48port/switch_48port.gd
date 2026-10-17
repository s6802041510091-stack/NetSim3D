extends Node3D
class_name Switch48
## NetLife3D - 48-port switch (stage 1 equipment, stage 4 broken ports).
##
##   sw.set_power(true)
##   sw.set_port_state(5, Switch48.LinkState.ACTIVITY)   # cable plugged + traffic
##   sw.broken_ports = [7, 18]                           # stage 4: these ports never light
##   sw.connect_cable(7)  -> returns false (port is broken)
##   sw.get_port_point(12)  # Node3D to snap the RJ-45 plug to (-Z = into the port)
## Port numbering like a real switch: top row odd (1,3..47), bottom row even (2,4..48).

signal port_state_changed(port: int, state: int)
signal power_changed(is_on: bool)

enum LinkState { OFF, LINK, ACTIVITY, FAULT }

@export var broken_ports: Array[int] = []      ## ports that never get a link
@export var start_powered := true
@export var blink_interval := 0.09

var is_on := false
var _state: Array[int] = []
var _leds: Array[MeshInstance3D] = []
var _points: Array[Node3D] = []
var _mat_link: StandardMaterial3D
var _mat_fault: StandardMaterial3D
var _mat_pwr: StandardMaterial3D
var _blink_t := 0.0


func _ready() -> void:
	_state.resize(49)
	_state.fill(LinkState.OFF)
	_leds.resize(49)
	_points.resize(49)
	for n in range(1, 49):
		_leds[n] = find_child("LED_Port_%02d" % n, true, false)
		_points[n] = find_child("Port_%02d" % n, true, false)
	_mat_link = _glow(Color(0.25, 1.0, 0.35))
	_mat_fault = _glow(Color(1.0, 0.55, 0.05))
	_mat_pwr = _glow(Color(0.25, 1.0, 0.35))
	set_power(start_powered)


# ---------------------------------------------------------------- public API
func set_power(on: bool) -> void:
	is_on = on
	find_child("LED_Power", true, false).material_override = _mat_pwr if on else null
	find_child("LED_System", true, false).material_override = _mat_pwr if on else null
	for n in range(1, 49):
		_apply(n)
	power_changed.emit(on)


func set_port_state(port: int, state: LinkState) -> void:
	assert(port >= 1 and port <= 48, "port must be 1..48")
	_state[port] = state
	_apply(port)
	port_state_changed.emit(port, state)


func get_port_state(port: int) -> int:
	return _state[port]


## Convenience: a cable was plugged in. Returns true if the port gets a link.
func connect_cable(port: int, with_traffic := true) -> bool:
	if is_port_broken(port):
		set_port_state(port, LinkState.OFF)
		return false
	set_port_state(port, LinkState.ACTIVITY if with_traffic else LinkState.LINK)
	return true


func disconnect_cable(port: int) -> void:
	set_port_state(port, LinkState.OFF)


func is_port_broken(port: int) -> bool:
	return port in broken_ports


## Snap point for an RJ-45 plug. -Z = insertion direction, +Y = contact side (latch clip on -Y).
func get_port_point(port: int) -> Node3D:
	return _points[port]


func get_console_point() -> Node3D:
	return find_child("Port_Console", true, false)


## Which port is closest to a world position (e.g. where the player clicked).
func port_at(world_pos: Vector3, max_dist := 0.012) -> int:
	var best := 0
	var best_d := max_dist
	for n in range(1, 49):
		var d := _points[n].global_position.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = n
	return best


# ---------------------------------------------------------------- internals
func _process(delta: float) -> void:
	_blink_t += delta
	if _blink_t < blink_interval:
		return
	_blink_t = 0.0
	if not is_on:
		return
	for n in range(1, 49):
		if _state[n] == LinkState.ACTIVITY and not is_port_broken(n):
			_leds[n].material_override = _mat_link if randf() > 0.35 else null


func _apply(n: int) -> void:
	var s := _state[n]
	if not is_on or is_port_broken(n) or s == LinkState.OFF:
		_leds[n].material_override = null
	elif s == LinkState.FAULT:
		_leds[n].material_override = _mat_fault
	else:
		_leds[n].material_override = _mat_link


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	return m
