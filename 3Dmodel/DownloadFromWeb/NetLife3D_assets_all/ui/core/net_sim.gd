extends Node
## NetLife3D - simulated network state shared by every software screen.
## Register as Autoload with the name "NetSim"  (Project > Project Settings > Globals > Autoload).
##
## One source of truth: Command Prompt, Advanced IP Scanner, Veyon Configurator and Veyon Master
## all read the same device list, so results always agree with each other.
## Every meaningful player action goes through log_action() -> use the signal for scoring.

signal action_logged(action: String, data: Dictionary)
signal state_changed

const SUBNET := "192.168.10"
const MASK := "255.255.255.0"
const GATEWAY := "192.168.10.1"
const DNS := "8.8.8.8"

## Rules for stage 6 (can be changed per scenario)
@export var require_auth_keys := true        ## Veyon Master needs key-file auth set up
@export var require_firewall_rule := false   ## Veyon Master also needs the firewall exception
@export var student_count := 30

## device: {name, ip, mac, vendor, type ("router"|"teacher"|"student"|"printer"|"other"),
##          online, veyon_service, screen_color}
var devices: Array[Dictionary] = []
var local_host := {}             ## the teacher PC the player is using

# ---- stage 5 result
var inventory: Array[Dictionary] = []          ## [{name, ip, mac}] saved by the player

# ---- stage 6 (Veyon) state
var veyon_locations := {}                      ## location name -> Array of {name, ip, mac}
var veyon_auth_method := "logon"               ## "logon" | "keyfile"
var veyon_keys: Array[String] = []             ## created key pair names, e.g. ["teacher"]
var veyon_keys_distributed := false            ## public key copied to student PCs
var firewall_veyon_allowed := false
var help_request := {"pc": "PC-15", "app": "notepad", "message": "Please open Notepad for me"}

var action_log: Array[Dictionary] = []
var _start_ms := 0


func _ready() -> void:
	reset()


## Build a fresh scenario. Same seed -> same MAC addresses / offline machines.
func reset(seed_value := 2569, offline_students: Array[int] = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	devices.clear()
	devices.append(_dev("ROUTER-LAB", GATEWAY, "NetCare Router", "router", rng))
	devices.append(_dev("PRINTER-LAB", SUBNET + ".50", "PrintCo", "printer", rng))
	local_host = _dev("TEACHER-PC", SUBNET + ".100", "PC Maker Inc.", "teacher", rng)
	devices.append(local_host)
	for i in range(1, student_count + 1):
		var d := _dev("PC-%02d" % i, "%s.%d" % [SUBNET, 100 + i], "PC Maker Inc.", "student", rng)
		d.online = not (i in offline_students)
		d.veyon_service = d.online
		devices.append(d)
	# a phone on the Wi-Fi - something the player must NOT save as a student PC
	devices.append(_dev("Android-Phone", SUBNET + ".182", "Mobile Device", "other", rng))
	inventory.clear()
	veyon_locations.clear()
	veyon_auth_method = "logon"
	veyon_keys.clear()
	veyon_keys_distributed = false
	firewall_veyon_allowed = false
	action_log.clear()
	_start_ms = Time.get_ticks_msec()
	state_changed.emit()


# ---------------------------------------------------------------- queries
func find_device(name_or_ip: String) -> Dictionary:
	var key := name_or_ip.strip_edges().to_lower()
	for d in devices:
		if d.ip == key or String(d.name).to_lower() == key:
			return d
	return {}


func students() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in devices:
		if d.type == "student":
			out.append(d)
	return out


## Devices that answer a scan between two IPs (inclusive). Invalid range -> [].
func scan(from_ip: String, to_ip: String) -> Array[Dictionary]:
	var a := ip_to_int(from_ip)
	var b := ip_to_int(to_ip)
	var out: Array[Dictionary] = []
	if a < 0 or b < 0 or b < a:
		return out
	for d in devices:
		var v := ip_to_int(d.ip)
		if v >= a and v <= b and d.online:
			out.append(d)
	out.sort_custom(func(x, y): return ip_to_int(x.ip) < ip_to_int(y.ip))
	return out


## Can Veyon Master reach this computer? Returns "" if OK, else a status text.
func veyon_status(ip: String) -> String:
	var d := find_device(ip)
	if d.is_empty() or not d.online:
		return "Offline"
	if not d.get("veyon_service", false):
		return "Service not running"
	if require_firewall_rule and not firewall_veyon_allowed:
		return "Connection timed out"
	if require_auth_keys and not veyon_auth_ready():
		return "Authentication failed"
	return ""


func veyon_auth_ready() -> bool:
	return veyon_auth_method == "keyfile" and not veyon_keys.is_empty() and veyon_keys_distributed


func ip_to_int(ip: String) -> int:
	var p := ip.strip_edges().split(".")
	if p.size() != 4:
		return -1
	var v := 0
	for s in p:
		if not s.is_valid_int():
			return -1
		var n := s.to_int()
		if n < 0 or n > 255:
			return -1
		v = v * 256 + n
	return v


# ---------------------------------------------------------------- logging
## Record a player action (used for scoring). data is free-form.
func log_action(action: String, data := {}) -> void:
	var e := {"t": (Time.get_ticks_msec() - _start_ms) / 1000.0, "action": action, "data": data}
	action_log.append(e)
	action_logged.emit(action, data)


func elapsed_seconds() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


# ---------------------------------------------------------------- internals
func _dev(n: String, ip: String, vendor: String, type: String, rng: RandomNumberGenerator) -> Dictionary:
	var oui: String = {"router": "50:C7:BF", "printer": "00:1B:A9", "other": "A4:6C:F1"}.get(type, "D8:BB:C1")
	var mac := "%s:%02X:%02X:%02X" % [oui, rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255)]
	return {
		"name": n, "ip": ip, "mac": mac, "vendor": vendor, "type": type,
		"online": true, "veyon_service": type == "student" or type == "teacher",
		"screen_color": Color.from_hsv(rng.randf(), 0.45, 0.75),
	}
