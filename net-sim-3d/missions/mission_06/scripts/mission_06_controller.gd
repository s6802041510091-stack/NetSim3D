class_name Mission06Controller
extends Node

## Mission 6 in the main scene: the ringing phone on the player's desk in the
## IT Support room (the Data Center office of the story), the
## phone call with the teacher (TeamViewer ID and password), the
## "ได้รับภารกิจ" message, and — once the player has fixed the sound, ended the
## Remote Session, closed TeamViewer and switched their computer (IT-PC-01)
## off — the knowledge summary and "ภารกิจสำเร็จ".
## The TeamViewer program itself is TeamViewerSim (opened from DesktopOS).

signal call_answered
signal mission_completed(score: int, wrong_id: int, wrong_password: int, close_without_end: int)

@export var data: Mission06Data
@export var phone_path: NodePath
@export var computers_path: NodePath = ^"../Computers"
## The computer the player must switch off at the end (it has TeamViewer).
@export var player_computer: String = "IT-PC-01"
## Start ringing as soon as the game starts. A future mission system can turn
## this off and call start_ringing() when Mission 6 begins.
@export var ring_on_start: bool = true
@export var use_save_file: bool = true

var state: Mission06State = Mission06State.new()
var phone: DeskPhone
var manager: ComputerManager
var dialog: CallDialog
var summary_visible: bool = false

var _toast_layer: CanvasLayer
var _toast: PanelContainer
var _toast_label: Label
var _summary_layer: CanvasLayer
var _summary_body: VBoxContainer
var _summary_player: Node


func _ready() -> void:
	if data == null:
		data = load(TeamViewerSim.DATA_PATH) as Mission06Data
	state.reset(data)
	_load()
	phone = get_node_or_null(phone_path) as DeskPhone
	manager = get_node_or_null(computers_path) as ComputerManager
	dialog = CallDialog.new()
	dialog.name = "CallDialog"
	add_child(dialog)
	_build_toast()
	_build_summary()
	if phone:
		phone.answered.connect(_on_phone_answered)
		phone.ringing = ring_on_start and not state.call_answered
	if manager and manager.desktop:
		manager.desktop.shutdown_requested.connect(_on_computer_shutdown)


func start_ringing() -> void:
	_load()
	if phone and not state.call_answered:
		phone.ringing = true


# ---------------------------------------------------------------- phone call

func _on_phone_answered(player: Node) -> void:
	phone.ringing = false
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	dialog.show_call(data.call_lines, "สายโทรศัพท์ — ครูสาว (ห้องพักครู)")
	await dialog.finished
	if player.has_method("set_controls_locked"):
		player.set_controls_locked(false)
	_load()
	state.call_answered = true
	_save()
	show_message(data.mission_received_text)
	call_answered.emit()


func show_message(text: String, seconds: float = 4.5) -> void:
	_toast_label.text = text
	_toast_layer.visible = true
	get_tree().create_timer(seconds).timeout.connect(func():
		if _toast_label.text == text:
			_toast_layer.visible = false)


# ---------------------------------------------------------------- finishing

func _on_computer_shutdown() -> void:
	var station := manager.desktop.station
	if station == null or station.hostname != player_computer:
		return
	_load()
	if state.completed or not state.ready_to_finish():
		return
	state.computer_off = true
	state.completed = true
	_save()
	# Wait for the camera to return to the player before showing the summary.
	await get_tree().create_timer(manager.zoom_time + 0.3).timeout
	show_summary(manager.active_player if manager.active_player else _find_player())
	mission_completed.emit(state.score, state.wrong_id_count, state.wrong_password_count, state.close_without_end_count)


func show_summary(player: Node = null) -> void:
	_summary_player = player
	for child in _summary_body.get_children():
		_summary_body.remove_child(child)
		child.queue_free()
	_summary_body.add_child(_label(data.mission_complete_text, 26, RemoteTheme.OK, true))
	var stats := "คะแนน %d / %d   •   กรอก ID ผิด %d ครั้ง   •   Password ผิด %d ครั้ง   •   ปิดโปรแกรมก่อนจบ Session %d ครั้ง" % [
		state.score, data.start_score, state.wrong_id_count, state.wrong_password_count, state.close_without_end_count]
	var stat_label := _label(stats, 15, RemoteTheme.INK, false)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_body.add_child(stat_label)
	_summary_body.add_child(HSeparator.new())
	_summary_body.add_child(_label("สรุปความรู้", 20, RemoteTheme.INK, true))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	_summary_body.add_child(columns)
	for block in data.summary_sections:
		var parts := block.split("\n", false)
		if parts.is_empty():
			continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.PANEL, RemoteTheme.BORDER, 8, 16, 12))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		card.add_child(col)
		col.add_child(_label(parts[0], 18, RemoteTheme.ACCENT, true))
		for i in range(1, parts.size()):
			var l := _label("•  " + parts[i], 15, RemoteTheme.INK, false)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(240, 0)
			col.add_child(l)
		columns.add_child(card)
	var close := Button.new()
	close.name = "CloseSummaryButton"
	close.text = "ปิดหน้าสรุป"
	close.custom_minimum_size = Vector2(200, 44)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	RemoteTheme.primary(close)
	close.pressed.connect(close_summary)
	_summary_body.add_child(close)
	_summary_layer.visible = true
	summary_visible = true
	if player and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_summary() -> void:
	_summary_layer.visible = false
	summary_visible = false
	if _summary_player and _summary_player.has_method("set_controls_locked"):
		_summary_player.set_controls_locked(false)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _find_player() -> Node:
	return get_tree().current_scene.find_child("ITSupportPlayer", true, false) if get_tree().current_scene else null


# ---------------------------------------------------------------- ui

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 15
	_toast_layer.visible = false
	add_child(_toast_layer)
	_toast = PanelContainer.new()
	_toast.name = "MissionToast"
	_toast.theme = RemoteTheme.build()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -420
	_toast.offset_right = 420
	_toast.offset_top = 36
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.06, 0.32, 0.18, 0.94), Color(0.4, 0.85, 0.55), 8, 20, 12))
	_toast_layer.add_child(_toast)
	_toast_label = _label("", 20, Color.WHITE, true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(_toast_label)


func _build_summary() -> void:
	_summary_layer = CanvasLayer.new()
	_summary_layer.layer = 25
	_summary_layer.visible = false
	add_child(_summary_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = RemoteTheme.build()
	_summary_layer.add_child(center)
	var card := PanelContainer.new()
	card.name = "SummaryCard"
	card.custom_minimum_size = Vector2(980, 0)
	card.add_theme_stylebox_override("panel", RemoteTheme.box(Color(1, 1, 1), RemoteTheme.BORDER, 12, 30, 24))
	center.add_child(card)
	_summary_body = VBoxContainer.new()
	_summary_body.add_theme_constant_override("separation", 12)
	card.add_child(_summary_body)


func _label(text: String, size: int, color: Color, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", RemoteTheme.FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _load() -> void:
	if use_save_file:
		Mission06SaveStore.load_into(state, data)


func _save() -> void:
	if use_save_file:
		Mission06SaveStore.save(state)
