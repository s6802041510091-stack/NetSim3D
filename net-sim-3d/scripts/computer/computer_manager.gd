class_name ComputerManager
extends Node3D

## Finds every monitor screen in the map model, turns each one into a usable
## ComputerStation, and runs the shared simulated desktop (DesktopOS).

## Seconds the camera takes to move to and from the screen.
@export var zoom_time: float = 0.7
@export var map_visual_path: NodePath = ^"../MapVisual"
## Mesh names that end like this are monitor screens.
@export var screen_name_suffix: String = "Monitor_Display_Surface"
## Computers (hostnames) that have Network Designer installed.
## Leave empty to install it on every computer, e.g. ["DATACENTER-PC"] for Mission 1.
@export var network_designer_hosts: PackedStringArray = []
## Computers (hostnames) that have NetPlan EDU (Mission 1) installed.
## IT-PC-01 is the player's own desk computer in the IT Support room.
@export var netplan_edu_hosts: PackedStringArray = ["IT-PC-01"]
## Mission 5: the student computer that shows the security warning and has
## Windows Security (simulated) on its desktop.
@export var windows_security_hosts: PackedStringArray = ["PC-R3-L2"]
## Mission 6: computers that have TeamViewer (simulated) — the Data Center desk.
@export var teamviewer_hosts: PackedStringArray = ["DATACENTER-PC"]
## Screens that are not part of the map model (e.g. the Data Center desk scene).
@export var extra_screen_paths: Array[NodePath] = []
## Where Mission 5 progress is saved (same as Mission05SaveStore.DEFAULT_PATH).
@export var mission_05_save_path: String = "user://netsim3d/mission_05_save.json"

## Names for the computers that are not student PCs (Godot turns ".001" into "_001").
const NAMED_SCREENS := {
	"Monitor_Display_Surface": ["TEACHER-PC", "192.168.1.5"],
	"Monitor_Display_Surface_001": ["IT-PC-01", "192.168.1.101"],
	"Monitor_Display_Surface_002": ["IT-HEAD-PC", "192.168.1.100"],
	"Monitor_Display_Surface_003": ["IT-HEAD-PC2", "192.168.1.103"],
	"DataCenter_Monitor_Display_Surface": ["DATACENTER-PC", "192.168.1.110"],
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
		if not network_designer_hosts.is_empty() and not station.hostname in network_designer_hosts:
			station.installed_apps.erase("network_designer")
		if station.hostname in netplan_edu_hosts:
			station.installed_apps.append("netplan_edu")
		if station.hostname in teamviewer_hosts:
			station.installed_apps.append("teamviewer")
		if station.hostname in windows_security_hosts:
			station.installed_apps.append("windows_security")
			station.set_screen_alert(not _mission_05_protected())
		stations.append(station)


## True when the saved Mission 5 progress says the target computer is already fixed.
## Read by path (no class dependency) so the computers still work without the mission files.
func _mission_05_protected() -> bool:
	if not FileAccess.file_exists(mission_05_save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(mission_05_save_path))
	return parsed is Dictionary and bool(parsed.get("protected", false))


func _assign_identity(station: ComputerStation, screen_name: String, index: int) -> void:
	# StudentPC_Row03_Left_2__Monitor_Display_Surface -> PC-R3-L2, 192.168.1.19
	var regex := RegEx.create_from_string("StudentPC_Row(\\d+)_(Left|Right)_(\\d+)")
	var m := regex.search(screen_name)
	if m:
		var row := m.get_string(1).to_int()
		var side := m.get_string(2)
		var seat := m.get_string(3).to_int()
		var slot := (seat if side == "Left" else seat + 2)
		station.hostname = "PC-R%d-%s%d" % [row, side.substr(0, 1), seat]
		station.ip_address = "192.168.1.%d" % (10 + (row - 1) * 4 + slot)
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
	await active_player.return_camera(zoom_time)
	active_player.set_controls_locked(false)
	active_station = null
	active_player = null
	_busy = false
