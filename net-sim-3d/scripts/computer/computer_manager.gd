class_name ComputerManager
extends Node3D

## Finds every monitor screen in the map model, turns each one into a usable
## ComputerStation, and runs the shared simulated desktop (DesktopOS).

## Seconds the camera takes to move to and from the screen.
@export var zoom_time: float = 0.7
@export var map_visual_path: NodePath = ^"../MapVisual"
## Mesh names that end like this are monitor screens.
@export var screen_name_suffix: String = "Monitor_Display_Surface"
## Computers (hostnames) that have NetPlan EDU (Mission 1) installed.
## IT-PC-01 is the player's own desk computer in the IT Support room.
@export var netplan_edu_hosts: PackedStringArray = ["IT-PC-01"]
## Mission 5: the student computer that shows the security warning and has
## Windows Security (simulated) on its desktop.
@export var windows_security_hosts: PackedStringArray = ["PC-R3-L2"]
## Mission 6: computers that have TeamViewer (simulated) — the player's desk in
## the IT Support room (= the Data Center office of the mission story).
@export var teamviewer_hosts: PackedStringArray = ["IT-PC-01"]
## Mission 4: computers with the simple web browser (testing the Internet).
@export var browser_hosts: PackedStringArray = []
## Mission 6: computers with the Mail app (the player's desk computer).
@export var mail_hosts: PackedStringArray = []
## Computers an NPC is sitting at (the supervisor at IT-HEAD-PC): the player
## cannot use them, and their screen collider would otherwise block the
## player's look/talk ray toward that NPC.
@export var npc_used_hosts: PackedStringArray = ["IT-HEAD-PC"]
## Screens that are not part of the map model (a MeshInstance3D in another scene).
@export var extra_screen_paths: Array[NodePath] = []

## Names for the computers that are not student PCs (Godot turns ".001" into "_001").
const NAMED_SCREENS := {
	"Monitor_Display_Surface": ["TEACHER-PC", "192.168.1.5"],
	"Monitor_Display_Surface_001": ["IT-PC-01", "192.168.1.101"],
	"Monitor_Display_Surface_002": ["IT-HEAD-PC", "192.168.1.100"],
	"Monitor_Display_Surface_003": ["IT-HEAD-PC2", "192.168.1.103"],
}

var stations: Array[ComputerStation] = []
var active_station: ComputerStation = null
var active_player: Node = null
var desktop: DesktopOS
var _busy := false


func _ready() -> void:
	desktop = DesktopOS.new()
	desktop.name = "DesktopOS"
	desktop.manager = self
	add_child(desktop)
	desktop.shutdown_requested.connect(close_computer)

	var visual := get_node_or_null(map_visual_path)
	if visual == null:
		push_error("ComputerManager: map visual not found at %s" % map_visual_path)
		return
	var screens: Array[MeshInstance3D] = []
	for child in visual.get_children():
		if child is MeshInstance3D and String(child.name).contains(screen_name_suffix):
			screens.append(child)
	for path in extra_screen_paths:
		var extra := get_node_or_null(path) as MeshInstance3D
		if extra:
			screens.append(extra)
		else:
			push_warning("ComputerManager: extra screen not found at %s" % path)
	for i in screens.size():
		var station := ComputerStation.new()
		station.name = "Computer_" + String(screens[i].name)
		add_child(station)
		station.setup(self, screens[i])
		_assign_identity(station, String(screens[i].name), i)
		if station.hostname in netplan_edu_hosts:
			station.installed_apps.append("netplan_edu")
		if station.hostname in teamviewer_hosts:
			station.installed_apps.append("teamviewer")
		if station.hostname in mail_hosts:
			station.installed_apps.append("mail")
		if station.hostname in browser_hosts:
			station.installed_apps.append("browser")
		if station.hostname in windows_security_hosts:
			station.installed_apps.append("windows_security")
			# Level 5 always starts with the security warning (nothing is
			# carried over between plays); Windows Security clears it.
			station.set_screen_alert(true)
		if station.hostname in npc_used_hosts:
			station.collision_layer = 0
		stations.append(station)


func _assign_identity(station: ComputerStation, screen_name: String, index: int) -> void:
	# StudentPC_Row03_Left_2__Monitor_Display_Surface -> PC-R3-L2, 192.168.1.19
	var regex := RegEx.create_from_string("StudentPC_Row(\\d+)_(Left|Right)_(\\d+)")
	var m := regex.search(screen_name)
	# StaffPC_3_Monitor_Display_Surface (teachers' room) -> STAFF-PC-03, 192.168.1.53
	var staff := RegEx.create_from_string("^StaffPC_(\\d+)_").search(screen_name)
	if m:
		var row := m.get_string(1).to_int()
		var side := m.get_string(2)
		var seat := m.get_string(3).to_int()
		var slot := (seat if side == "Left" else seat + 2)
		station.hostname = "PC-R%d-%s%d" % [row, side.substr(0, 1), seat]
		station.ip_address = "192.168.1.%d" % (10 + (row - 1) * 4 + slot)
	elif staff:
		var n := staff.get_string(1).to_int()
		station.hostname = "STAFF-PC-%02d" % n
		station.ip_address = "192.168.1.%d" % (50 + n)
	elif NAMED_SCREENS.has(screen_name):
		station.hostname = NAMED_SCREENS[screen_name][0]
		station.ip_address = NAMED_SCREENS[screen_name][1]
	else:
		station.hostname = "PC-%02d" % (index + 1)
		station.ip_address = "192.168.1.%d" % (150 + index)
	var last := station.ip_address.get_slice(".", 3).to_int()
	station.mac_address = "00-1A-2B-3C-%02X-%02X" % [index, last]


func find_host(name_or_ip: String) -> ComputerStation:
	var key := name_or_ip.to_lower()
	for station in stations:
		if station.ip_address == key or station.hostname.to_lower() == key:
			return station
	return null


func open_computer(station: ComputerStation, player: Node) -> void:
	if _busy or active_station != null:
		return
	_busy = true
	active_station = station
	active_player = player
	Sound.play("chair")
	player.set_controls_locked(true)
	await player.move_camera_to(station.get_view_transform(player.camera.fov), zoom_time)
	station.set_screen_on(true)
	desktop.power_on(station)
	_busy = false


func close_computer() -> void:
	if _busy or active_station == null:
		return
	_busy = true
	desktop.power_off()
	active_station.set_screen_on(false)
	Sound.play("chair")
	await active_player.return_camera(zoom_time)
	active_player.set_controls_locked(false)
	active_station = null
	active_player = null
	_busy = false
