class_name Mission05TestBench
extends Control

## Stand-alone test scene for Mission 5 (no 3D map needed).
## Runs the same flow as the game: Set-up (2 s) -> Desktop (security warning
## pops up) -> Windows Security, using the real DesktopOS and a stand-in for
## the target student computer (PC-R3-L2).
## Open scenes/missions/mission_05/mission_05_test.tscn and press F6.

signal computer_opened
signal computer_exited

@export var auto_open_computer: bool = true
## Mouse mode given back when leaving the computer. The game itself uses
## MOUSE_MODE_CAPTURED (see player_controller.gd); the bench keeps the cursor.
@export var exit_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var desktop: DesktopOS
var station: ComputerStation
var is_using_computer: bool = false

@onready var _exited_panel: Control = %ExitedPanel
@onready var _info: Label = %BenchInfo


func _ready() -> void:
	theme = SecurityTheme.build()
	station = ComputerStation.new()
	station.name = "TargetComputer"
	station.hostname = "PC-R3-L2"
	station.ip_address = "192.168.1.20"
	station.installed_apps.append("windows_security")
	add_child(station)

	desktop = DesktopOS.new()
	desktop.name = "DesktopOS"
	add_child(desktop)
	desktop.shutdown_requested.connect(exit_computer)

	%OpenComputerButton.pressed.connect(open_computer)
	%ResetSaveButton.pressed.connect(_reset_save)
	_update_info()
	if auto_open_computer:
		open_computer()


func _unhandled_input(event: InputEvent) -> void:
	# Same key as the game: E (input action "interact") sits down at the computer.
	if not is_using_computer and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_computer()


## Sit down at the computer: Set-up screen for 2 s, then the Desktop.
func open_computer() -> void:
	if is_using_computer:
		return
	is_using_computer = true
	_exited_panel.visible = false
	station.screen_alert = not _saved_protected()
	desktop.power_on(station)
	computer_opened.emit()


## Opens Windows Security (waits for the Desktop if it is still starting up).
func open_mission() -> WindowsSecurity:
	if not is_using_computer:
		open_computer()
	if desktop.is_booting:
		await desktop.desktop_ready
	return desktop.open_windows_security() as WindowsSecurity


## Leave the computer: switch it off and give control back.
func exit_computer() -> void:
	if not is_using_computer:
		return
	is_using_computer = false
	desktop.power_off()
	Input.mouse_mode = exit_mouse_mode
	_exited_panel.visible = true
	_update_info()
	computer_exited.emit()


func get_mission() -> WindowsSecurity:
	return desktop.find_child("WindowsSecurity", true, false) as WindowsSecurity


func _saved_protected() -> bool:
	var state := Mission05State.new()
	var data := load(WindowsSecurity.DATA_PATH) as Mission05Data
	return Mission05SaveStore.load_into(state, data) and state.is_protected()


func _reset_save() -> void:
	Mission05SaveStore.clear()
	_update_info()


func _update_info() -> void:
	var state := Mission05State.new()
	var data := load(WindowsSecurity.DATA_PATH) as Mission05Data
	if not Mission05SaveStore.load_into(state, data):
		_info.text = "ยังไม่มีข้อมูลบันทึกของภารกิจที่ 5"
	elif state.report_submitted:
		_info.text = "ส่งผลการตรวจสอบแล้ว — คะแนน %d, เลือกผิด %d ครั้ง (ต่อไป: รายงานหัวหน้างานที่ห้อง Data Center)" % [state.score, state.wrong_count()]
	else:
		_info.text = "มีข้อมูลบันทึก: Firewall %s, Anti-Virus %s, คะแนน %d" % [
			"เรียบร้อย" if state.firewall_blocked else "ยังไม่เสร็จ",
			"เรียบร้อย" if state.threat_quarantined else "ยังไม่เสร็จ",
			state.score]
