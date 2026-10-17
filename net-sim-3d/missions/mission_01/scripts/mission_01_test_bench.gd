class_name Mission01TestBench
extends Control

## Stand-alone test scene for Mission 1 (no 3D map needed).
## Runs the same flow as the game: Set-up (2 s) -> Desktop -> NetPlan EDU,
## using the real DesktopOS and a stand-in for the player's computer (IT-PC-01).
## Open missions/mission_01/scenes/mission_01_test.tscn and press F6.

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
	theme = NetPlanTheme.build()
	station = ComputerStation.new()
	station.name = "PlayerComputer"
	station.hostname = "IT-PC-01"
	station.ip_address = "192.168.1.101"
	station.installed_apps.append("netplan_edu")
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
	desktop.power_on(station)
	computer_opened.emit()


## Opens NetPlan EDU (waits for the Desktop if it is still starting up).
func open_mission() -> NetPlanEdu:
	if not is_using_computer:
		open_computer()
	if desktop.is_booting:
		await desktop.desktop_ready
	return desktop.open_netplan_edu() as NetPlanEdu


## Closes NetPlan EDU and goes back to the Desktop.
func close_mission() -> void:
	var app := get_mission()
	if app:
		app.close_mission()


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


func get_mission() -> NetPlanEdu:
	var app := desktop.find_child("NetPlanEdu", true, false)
	return app as NetPlanEdu


func _reset_save() -> void:
	Mission01SaveStore.clear()
	_update_info()


func _update_info() -> void:
	var state := Mission01State.new()
	var data := load(NetPlanEdu.DATA_PATH) as Mission01Data
	var has_save := Mission01SaveStore.load_into(state, data)
	if not has_save:
		_info.text = "ยังไม่มีข้อมูลบันทึกของภารกิจที่ 1"
	elif state.passed:
		_info.text = "ภารกิจที่ 1 สำเร็จแล้ว — คะแนน %d, ตรวจสอบ %d ครั้ง" % [state.final_score, state.check_count]
	else:
		_info.text = "มีข้อมูลบันทึก: เลือกแล้ว %d/3 จุด, ตรวจสอบ %d ครั้ง" % [state.answered_count(data), state.check_count]
