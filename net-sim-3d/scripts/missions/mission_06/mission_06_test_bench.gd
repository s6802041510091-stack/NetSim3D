class_name Mission06TestBench
extends Control

## Stand-alone test scene for Mission 6 (no 3D map needed).
## "รับสายโทรศัพท์" plays the teacher's call (TeamViewer ID and password), then
## the computer opens: Set-up (2 s) -> Desktop -> TeamViewer, using the real
## DesktopOS and a stand-in for the player's computer (IT-PC-01).
## Open scenes/missions/mission_06/mission_06_test.tscn and press F6.

signal computer_opened
signal computer_exited

@export var exit_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var desktop: DesktopOS
var station: ComputerStation
var dialog: CallDialog
var data: Mission06Data
var is_using_computer: bool = false

@onready var _exited_panel: Control = %ExitedPanel
@onready var _info: Label = %BenchInfo


func _ready() -> void:
	theme = RemoteTheme.build()
	data = load(TeamViewerSim.DATA_PATH) as Mission06Data
	station = ComputerStation.new()
	station.name = "PlayerComputer"
	station.hostname = "IT-PC-01"
	station.ip_address = "192.168.1.101"
	station.installed_apps.append("teamviewer")
	add_child(station)

	desktop = DesktopOS.new()
	desktop.name = "DesktopOS"
	add_child(desktop)
	desktop.shutdown_requested.connect(exit_computer)
	dialog = CallDialog.new()
	add_child(dialog)

	%OpenComputerButton.pressed.connect(open_computer)
	%ResetSaveButton.pressed.connect(_reset_save)
	%AnswerCallButton.pressed.connect(answer_call)
	_exited_panel.visible = true
	_update_info()


## Plays the phone call and records that it was answered.
func answer_call() -> void:
	_exited_panel.visible = false
	dialog.show_call(data.call_lines, "สายโทรศัพท์ — ครูสาว (ห้องพักครู)")
	await dialog.finished
	var state := Mission06State.new()
	Mission06SaveStore.load_into(state, data)
	state.call_answered = true
	Mission06SaveStore.save(state)
	_exited_panel.visible = true
	_update_info()


func open_computer() -> void:
	if is_using_computer:
		return
	is_using_computer = true
	_exited_panel.visible = false
	desktop.power_on(station)
	computer_opened.emit()


func open_mission() -> TeamViewerSim:
	if not is_using_computer:
		open_computer()
	if desktop.is_booting:
		await desktop.desktop_ready
	return desktop.open_teamviewer() as TeamViewerSim


func exit_computer() -> void:
	if not is_using_computer:
		return
	is_using_computer = false
	desktop.power_off()
	Input.mouse_mode = exit_mouse_mode
	_exited_panel.visible = true
	_update_info()
	computer_exited.emit()


func _reset_save() -> void:
	Mission06SaveStore.clear()
	_update_info()


func _update_info() -> void:
	var state := Mission06State.new()
	if not Mission06SaveStore.load_into(state, data):
		_info.text = "ยังไม่มีข้อมูลบันทึกของภารกิจที่ 6 — กด \"รับสายโทรศัพท์\" ก่อน"
	elif state.ready_to_finish():
		_info.text = "ทำใน TeamViewer ครบแล้ว — คะแนน %d (ในเกมจริง: ปิดคอมพิวเตอร์แล้วจะขึ้นหน้าสรุป)" % state.score
	else:
		_info.text = "รับสายแล้ว: %s, ครูยืนยันเสียง: %s, จบ Session: %s, คะแนน %d" % [
			"ใช่" if state.call_answered else "ยัง", "ใช่" if state.teacher_confirmed else "ยัง",
			"ใช่" if state.session_ended else "ยัง", state.score]
