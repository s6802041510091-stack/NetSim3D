extends Node3D
class_name NetworkDevice
## NetLife3D - shared script for Router and ONT (LEDs + ports).
##
##   dev.set_power(true)                         # Power LED on (+ default LEDs)
##   dev.set_led("Internet", NetworkDevice.Led.ON)
##   dev.set_led("LAN2", NetworkDevice.Led.BLINK)
##   dev.get_port("WAN")                         # plug point (-Z = into the port)
##   dev.list_ports()                            # ["WAN","LAN1",...] / ["PON","LAN1","LAN2"]
## Router only: dev.set_antenna_angle(1, -30.0)  # tilt antenna 1..4 (degrees, + = backwards)

signal power_changed(is_on: bool)
signal led_changed(led_name: String, mode: int)

enum Led { OFF, ON, BLINK }

## LED colours by name. Anything not listed is green.
@export var led_colors := {
	"LOS": Color(1.0, 0.12, 0.08),
	"Internet": Color(0.25, 0.6, 1.0),
	"WiFi24": Color(0.25, 0.6, 1.0),
	"WiFi5": Color(0.25, 0.6, 1.0),
}
## LEDs switched on automatically when power goes on (e.g. ["WiFi24","WiFi5"] for the router).
@export var leds_on_at_power: Array[String] = []
@export var start_powered := true
@export var blink_interval := 0.12

var is_on := false
var _leds := {}       # name -> MeshInstance3D
var _modes := {}      # name -> Led
var _mats := {}       # name -> material
var _t := 0.0


func _ready() -> void:
	for m in find_children("LED_*", "MeshInstance3D", true, false):
		var n := String(m.name).trim_prefix("LED_")
		_leds[n] = m
		_modes[n] = Led.OFF
		_mats[n] = _glow(led_colors.get(n, Color(0.25, 1.0, 0.35)))
	set_power(start_powered)


func set_power(on: bool) -> void:
	is_on = on
	for n in _leds:
		_modes[n] = Led.OFF
	if on:
		_modes["Power"] = Led.ON
		for n in leds_on_at_power:
			if _leds.has(n):
				_modes[n] = Led.ON
	_refresh()
	power_changed.emit(on)


func set_led(led_name: String, mode: Led) -> void:
	assert(_leds.has(led_name), "No LED_%s on %s" % [led_name, name])
	_modes[led_name] = mode
	_refresh()
	led_changed.emit(led_name, mode)


func get_led(led_name: String) -> int:
	return _modes.get(led_name, Led.OFF)


func list_leds() -> Array:
	return _leds.keys()


func get_port(port_name: String) -> Node3D:
	return find_child("Port_" + port_name, true, false)


func list_ports() -> PackedStringArray:
	var out := PackedStringArray()
	for p in find_children("Port_*", "", true, false):
		out.append(String(p.name).trim_prefix("Port_"))
	return out


func get_power_inlet() -> Node3D:
	return find_child("Power_Inlet", true, false)


func set_antenna_angle(index: int, degrees: float) -> void:
	var a: Node3D = find_child("Antenna_%d" % index, true, false)
	if a:
		a.rotation.x = deg_to_rad(-degrees)


func _process(delta: float) -> void:
	_t += delta
	if _t < blink_interval:
		return
	_t = 0.0
	for n in _leds:
		if is_on and _modes[n] == Led.BLINK:
			_leds[n].material_override = _mats[n] if randf() > 0.4 else null


func _refresh() -> void:
	for n in _leds:
		var lit: bool = is_on and _modes[n] != Led.OFF
		_leds[n].material_override = _mats[n] if lit else null


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	return m
