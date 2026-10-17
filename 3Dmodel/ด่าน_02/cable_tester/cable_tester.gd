extends Node3D
class_name CableTester
## NetLife3D - RJ-45 Cable Tester (stage 3 and stage 4).
##
## Root script of cable_tester.tscn (an inherited scene of cable_tester.glb).
## The game decides WHAT the cable result is; this script only shows it on the device:
##   tester.press_power()                     # toggle power (red ON led)
##   tester.press_test(CableTester.STRAIGHT)  # good straight-through cable
##   tester.press_test(mapping, true)         # loose/bad crimp -> remote LEDs flicker
## mapping[i] = remote LED (1-9, 9 = G) that lights together with main LED i+1, 0 = open wire.

signal power_changed(is_on: bool)
signal test_started(mapping: Array, loose: bool)
signal test_stopped

const STRAIGHT := [1, 2, 3, 4, 5, 6, 7, 8, 9]
const CROSSOVER := [3, 6, 1, 4, 5, 2, 7, 8, 9]
const LED_NAMES := ["1", "2", "3", "4", "5", "6", "7", "8", "G"]

@export var step_time := 0.28        ## seconds each wire stays lit while scanning
@export var button_travel := 0.0012  ## metres a button moves when pressed

var is_on := false
var is_testing := false

var _main_leds: Array[MeshInstance3D] = []
var _remote_leds: Array[MeshInstance3D] = []
var _power_led: MeshInstance3D
var _btn_power: Node3D
var _btn_test: Node3D
var _green_on: StandardMaterial3D
var _red_on: StandardMaterial3D
var _run_id := 0


func _ready() -> void:
	for n in LED_NAMES:
		_main_leds.append(find_child("LED_Main_" + n, true, false))
		_remote_leds.append(find_child("LED_Remote_" + n, true, false))
	_power_led = find_child("LED_Power", true, false)
	_btn_power = find_child("Button_Power", true, false)
	_btn_test = find_child("Button_Test", true, false)
	_green_on = _glow(Color(0.25, 1.0, 0.35))
	_red_on = _glow(Color(1.0, 0.15, 0.1))
	_all_off()


# ---------------------------------------------------------------- public API
func press_power() -> void:
	_press(_btn_power)
	set_power(not is_on)


func set_power(on: bool) -> void:
	if on == is_on:
		return
	is_on = on
	_power_led.material_override = _red_on if on else null
	if not on:
		stop_test()
		_all_off()
	power_changed.emit(on)


## Starts the scan loop. Does nothing while the power is off (like the real device).
func press_test(mapping: Array = STRAIGHT, loose := false) -> void:
	_press(_btn_test)
	if not is_on:
		return
	stop_test()
	is_testing = true
	_run_id += 1
	test_started.emit(mapping, loose)
	_scan(mapping, loose, _run_id)


func stop_test() -> void:
	if is_testing:
		is_testing = false
		_run_id += 1
		_leds_off()
		test_stopped.emit()


## Where a cable plug should snap to. unit = "Main" or "Remote".
## The node's -Z axis points into the socket (insertion direction).
func get_plug_point(unit: String) -> Node3D:
	return find_child(unit + "_PlugPoint", true, false)


## Direct LED control, if the game wants its own patterns. index 1-9 (9 = G).
func set_led(unit: String, index: int, on: bool) -> void:
	var list := _main_leds if unit == "Main" else _remote_leds
	list[index - 1].material_override = _green_on if on else null


# ---------------------------------------------------------------- internals
func _scan(mapping: Array, loose: bool, id: int) -> void:
	while id == _run_id and is_on:
		for i in 9:
			if id != _run_id:
				return
			_leds_off()
			_main_leds[i].material_override = _green_on
			var r: int = mapping[i]
			if r > 0:
				if loose:
					# bad contact: remote LED flickers / sometimes missing
					var t := 0.0
					while t < step_time and id == _run_id:
						_remote_leds[r - 1].material_override = _green_on if randf() > 0.45 else null
						await get_tree().create_timer(0.05).timeout
						t += 0.05
					continue
				_remote_leds[r - 1].material_override = _green_on
			await get_tree().create_timer(step_time).timeout


func _press(btn: Node3D) -> void:
	if btn == null:
		return
	var rest := btn.position
	var tw := create_tween()
	tw.tween_property(btn, "position:y", rest.y - button_travel, 0.06)
	tw.tween_property(btn, "position:y", rest.y, 0.1)


func _leds_off() -> void:
	for l in _main_leds + _remote_leds:
		l.material_override = null


func _all_off() -> void:
	_leds_off()
	_power_led.material_override = null


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	m.roughness = 0.2
	return m
