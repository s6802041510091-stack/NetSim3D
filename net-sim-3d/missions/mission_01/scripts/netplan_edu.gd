class_name NetPlanEdu
extends PanelContainer

## NetPlan EDU — the program for Mission 1: choose the network device for the
## three fixed install points of a computer room, then press "ตรวจสอบแบบ".
##
## This script only wires the UI together:
##   data (questions)  -> Mission01Data / EquipmentQuestion  (missions/mission_01/data/*.tres)
##   player progress   -> Mission01State
##   checking + score  -> Mission01Validator
##   saving            -> Mission01SaveStore
##   room plan         -> RoomPlanView,  install points -> EquipmentPoint,  pop-up -> EquipmentPopup
##
## Inside the game it runs on the simulated desktop (DesktopOS.open_netplan_edu()).

signal equipment_point_opened(point_id: int)
signal equipment_selected(point_id: int, option: String)
signal answer_confirmed(point_id: int, option: String)
signal validation_requested
signal mission_completed(final_score: int, check_count: int, ever_wrong_count: int)
signal computer_exit_requested
## The player closed the program (title-bar close, menu, "กลับสู่ Desktop" or Esc).
signal close_requested
## The player pressed the title-bar minimise button.
signal minimize_requested

const POINT_SCENE := preload("res://missions/mission_01/scenes/equipment_point.tscn")
const DATA_PATH := "res://missions/mission_01/data/mission_01_data.tres"

const MSG_READY := "พร้อมทำภารกิจ"
const MSG_SELECTED := "เลือกอุปกรณ์จุดที่ %d แล้ว"
const MSG_MISSING := "กรุณาเลือกอุปกรณ์ให้ครบทั้ง 3 จุด"
const MSG_FIX := "พบจุดที่ต้องแก้ไข"
const MSG_DONE := "ภารกิจสำเร็จ"
const GENERAL_HINT := "คลิกจุดสีส้มบนผังห้อง เลือกอุปกรณ์ แล้วกด \"ยืนยันการเลือก\" เมื่อเลือกครบ 3 จุดให้กด \"ตรวจสอบแบบ\""

enum MenuId { SAVE, CLOSE, UNDO, REDO, VIEW_PLAN, VIEW_REQUIREMENTS, VIEW_LAN, CHECK, HELP }

@export var data: Mission01Data
## Load and save progress with Mission01SaveStore. Tests turn this off.
@export var use_save_file: bool = true
## Handle Esc here. Inside DesktopOS the desktop calls handle_escape() instead;
## when this scene is run on its own (F6) it is switched on automatically.
@export var handle_escape_itself: bool = false

var state: Mission01State = Mission01State.new()
var last_result: Mission01Validator.Result
var status_message: String = ""

var _rows := {}
var _project_group := ButtonGroup.new()

@onready var _plan: RoomPlanView = %RoomPlan
@onready var _popup: EquipmentPopup = %Popup
@onready var _status: Label = %StatusLabel
@onready var _status_bar: PanelContainer = %StatusBar
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _point_list: VBoxContainer = %PointList
@onready var _hint: Label = %HintLabel
@onready var _score: Label = %ScoreLabel
@onready var _check_count: Label = %CheckCountLabel
@onready var _info: MarginContainer = %InfoOverlay
@onready var _completion: Control = %CompletionOverlay


func _ready() -> void:
	theme = NetPlanTheme.build()
	if data == null:
		data = load(DATA_PATH) as Mission01Data
	var problem := data.validate_data()
	if problem != "":
		push_error("NetPlan EDU: " + problem)
	if get_tree().current_scene == self:
		handle_escape_itself = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if use_save_file:
		Mission01SaveStore.load_into(state, data)
	else:
		state.reset(data)

	_style_chrome()
	_build_points()
	_build_point_rows()
	_connect_ui()
	_build_menus()
	%FileName.text = "— " + data.project_file_name
	%ProjectFileLabel.text = data.project_file_name
	_hint.text = GENERAL_HINT
	_refresh()
	if state.passed:
		_set_status(MSG_DONE, NetPlanTheme.CORRECT)
		_show_completion()
	else:
		_set_status(MSG_READY)


func _unhandled_input(event: InputEvent) -> void:
	if handle_escape_itself and visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		handle_escape()


# ================================================================ public API

## Esc order: pop-up -> info page -> close the program. Returns true if used.
func handle_escape() -> bool:
	if not visible:
		return false
	if _popup.visible:
		_popup.cancel()
		return true
	if _info.visible:
		_show_plan()
		return true
	close_mission()
	return true


## Same as clicking install point `point_id` on the plan.
func open_point(point_id: int) -> void:
	var point := _plan.get_point(point_id)
	if point:
		point.pressed.emit()


## Opens the pop-up, picks `option` and confirms — exactly what the player does.
func choose_answer(point_id: int, option: String) -> bool:
	open_point(point_id)
	if not _popup.visible or _popup.locked:
		return false
	_popup.choose(option)
	_popup.confirm()
	return state.get_answer(point_id) == option


## "ตรวจสอบแบบ". Returns the result (see Mission01Validator.Result).
func request_validation() -> Mission01Validator.Result:
	validation_requested.emit()
	var was_passed := state.passed
	var result := Mission01Validator.check(state, data)
	last_result = result
	if not result.checked:
		_set_status("%s (ยังไม่ได้เลือก: %s)" % [MSG_MISSING, _join_points(result.missing)], NetPlanTheme.EMPTY.darkened(0.15))
		_hint.text = "ยังเลือกอุปกรณ์ไม่ครบ จุดที่ยังไม่ได้เลือก: %s" % _join_points(result.missing)
	elif result.completed:
		_set_status(MSG_DONE, NetPlanTheme.CORRECT)
		_hint.text = "ทุกจุดถูกต้อง ภารกิจสำเร็จ"
	else:
		_set_status("%s (จุดที่ %s)" % [MSG_FIX, _join_points(result.wrong)], NetPlanTheme.WRONG)
		_hint.text = "จุดสีแดงยังไม่ถูกต้อง คลิกจุดนั้นเพื่อเปลี่ยนอุปกรณ์ แล้วกด \"ตรวจสอบแบบ\" อีกครั้ง"
	_save()
	_refresh()
	if result.completed and not was_passed:
		_show_completion()
		mission_completed.emit(state.final_score, state.check_count, state.ever_wrong_count())
	return result


func close_mission() -> void:
	_popup.close()
	close_requested.emit()


func is_popup_open() -> bool:
	return _popup.visible


func is_completion_shown() -> bool:
	return _completion.visible


func get_point_status(point_id: int) -> Mission01State.PointStatus:
	return state.get_status(point_id)


# ================================================================ building

func _style_chrome() -> void:
	%TitleBar.add_theme_stylebox_override("panel", NetPlanTheme.box(NetPlanTheme.TITLE_BAR, Color(0, 0, 0, 0), 0, 10, 4))
	%Logo.add_theme_stylebox_override("panel", NetPlanTheme.box(Color(0.20, 0.60, 0.95), Color(0, 0, 0, 0), 6, 4, 2))
	%AppName.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)
	%MenuPanel.add_theme_stylebox_override("panel", NetPlanTheme.box(NetPlanTheme.MENU_BAR, Color(0, 0, 0, 0), 0, 6, 2))
	%ToolbarPanel.add_theme_stylebox_override("panel", NetPlanTheme.box(NetPlanTheme.TOOLBAR, Color(0, 0, 0, 0), 0, 8, 5))
	%ProjectPanel.add_theme_stylebox_override("panel", NetPlanTheme.box(NetPlanTheme.PANEL, Color(0, 0, 0, 0), 0, 12, 12))
	%SidePanel.add_theme_stylebox_override("panel", NetPlanTheme.box(NetPlanTheme.PANEL, Color(0, 0, 0, 0), 0, 14, 12))
	%CenterPanel.add_theme_stylebox_override("panel", NetPlanTheme.box(NetPlanTheme.PLAN_BG, NetPlanTheme.BORDER, 0, 0, 0))
	%InfoCard.add_theme_stylebox_override("panel", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 10, 24, 18))
	%CompletionCard.add_theme_stylebox_override("panel", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 12, 30, 24))
	for label in [%ProjectHeader, %ProgressTitle, %PointsTitle, %HintTitle, %ResultTitle, %InfoTitle, %CompleteTitle]:
		label.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)

	var check_style := NetPlanTheme.box(NetPlanTheme.ACCENT, NetPlanTheme.ACCENT.darkened(0.2), 6, 14, 6)
	var check_hover := check_style.duplicate() as StyleBoxFlat
	check_hover.bg_color = NetPlanTheme.ACCENT.lightened(0.12)
	for b in [%CheckDesignButton, %SideCheckButton, %ExitComputerButton]:
		b.add_theme_stylebox_override("normal", check_style)
		b.add_theme_stylebox_override("hover", check_hover)
		b.add_theme_stylebox_override("pressed", check_hover)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE)
		b.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)

	# Window buttons are drawn (no font glyph needed).
	var clear := StyleBoxEmpty.new()
	var hover := NetPlanTheme.box(Color(1, 1, 1, 0.14), Color(0, 0, 0, 0), 4)
	var close_hover := NetPlanTheme.box(Color(0.85, 0.2, 0.2), Color(0, 0, 0, 0), 4)
	for b in [%MinimizeButton, %MaximizeButton, %CloseButton]:
		b.add_theme_stylebox_override("normal", clear)
		b.add_theme_stylebox_override("disabled", clear)
		b.add_theme_stylebox_override("hover", close_hover if b == %CloseButton else hover)
		b.add_theme_stylebox_override("pressed", close_hover if b == %CloseButton else hover)
	%MinimizeButton.draw.connect(func():
		var c: Vector2 = %MinimizeButton.size * 0.5
		%MinimizeButton.draw_line(c + Vector2(-7, 5), c + Vector2(7, 5), Color.WHITE, 2.0))
	%MaximizeButton.draw.connect(func():
		var c: Vector2 = %MaximizeButton.size * 0.5
		%MaximizeButton.draw_rect(Rect2(c - Vector2(7, 6), Vector2(14, 12)), Color(1, 1, 1, 0.35), false, 2.0))
	%CloseButton.draw.connect(func():
		NetPlanTheme.draw_cross(%CloseButton, %CloseButton.size * 0.5, 22.0, Color.WHITE, 2.0))


func _build_points() -> void:
	for q in data.questions:
		var point := POINT_SCENE.instantiate() as EquipmentPoint
		point.point_id = q.point_id
		point.name = "EquipmentPoint%d" % q.point_id
		_plan.add_point(point, q.plan_position)
		point.equipment_point_opened.connect(_on_point_opened)


func _build_point_rows() -> void:
	for q in data.questions:
		var row := PanelContainer.new()
		row.name = "PointRow%d" % q.point_id
		row.add_theme_stylebox_override("panel", NetPlanTheme.box(Color(1, 1, 1), NetPlanTheme.BORDER, 6, 10, 6))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var dot := Control.new()
		dot.name = "Dot"
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id := q.point_id
		dot.draw.connect(func(): dot.draw_circle(Vector2(9, 9), 8.0, NetPlanTheme.status_color(state.get_status(id))))
		h.add_child(dot)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		var title := Label.new()
		title.text = "จุดที่ %d · %s" % [q.point_id, q.title]
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", NetPlanTheme.INK_SOFT)
		v.add_child(title)
		var device := Label.new()
		device.name = "Device"
		device.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		device.add_theme_font_size_override("font_size", 16)
		device.add_theme_font_override("font", NetPlanTheme.FONT_BOLD)
		v.add_child(device)
		_point_list.add_child(row)
		_rows[q.point_id] = {"dot": dot, "device": device}


func _connect_ui() -> void:
	_popup.equipment_selected.connect(func(id: int, option: String): equipment_selected.emit(id, option))
	_popup.answer_confirmed.connect(_on_answer_confirmed)
	_popup.cancelled.connect(func(): _hint.text = GENERAL_HINT)
	%CheckDesignButton.pressed.connect(request_validation)
	%SideCheckButton.pressed.connect(request_validation)
	%SaveButton.pressed.connect(_on_save_pressed)
	%CloseButton.pressed.connect(close_mission)
	%MinimizeButton.pressed.connect(func(): minimize_requested.emit())
	%BackToDesktopButton.pressed.connect(close_mission)
	%ExitComputerButton.pressed.connect(func(): computer_exit_requested.emit())
	%InfoCloseButton.pressed.connect(_show_plan)

	for b in [%MissionItem, %RoomPlanItem, %RequirementsItem]:
		b.button_group = _project_group
	%MissionItem.pressed.connect(_show_mission_brief)
	%RoomPlanItem.pressed.connect(_show_plan)
	%RequirementsItem.pressed.connect(_show_requirements)
	%LanRoutesItem.toggled.connect(_set_lan_highlight)


func _build_menus() -> void:
	var file: PopupMenu = %FileMenu.get_popup()
	file.add_item("บันทึก Project", MenuId.SAVE)
	file.add_separator()
	file.add_item("ปิดโปรแกรม", MenuId.CLOSE)
	var edit: PopupMenu = %EditMenu.get_popup()
	edit.add_item("ย้อนกลับ (ใช้ไม่ได้ในภารกิจนี้)", MenuId.UNDO)
	edit.add_item("ทำซ้ำ (ใช้ไม่ได้ในภารกิจนี้)", MenuId.REDO)
	edit.set_item_disabled(0, true)
	edit.set_item_disabled(1, true)
	var view: PopupMenu = %ViewMenu.get_popup()
	view.add_item("ผังห้องคอม", MenuId.VIEW_PLAN)
	view.add_item("ข้อกำหนด", MenuId.VIEW_REQUIREMENTS)
	view.add_check_item("เน้นเส้นทางสาย LAN (ดูอย่างเดียว)", MenuId.VIEW_LAN)
	var check: PopupMenu = %CheckMenu.get_popup()
	check.add_item("ตรวจสอบแบบ", MenuId.CHECK)
	var help: PopupMenu = %HelpMenu.get_popup()
	help.add_item("วิธีทำภารกิจ", MenuId.HELP)
	for menu in [file, edit, view, check, help]:
		menu.id_pressed.connect(_on_menu)


# ================================================================ events

func _on_point_opened(point_id: int) -> void:
	var q := data.get_question(point_id)
	if q == null:
		return
	equipment_point_opened.emit(point_id)
	var locked := state.passed or state.get_status(point_id) == Mission01State.PointStatus.CORRECT
	_popup.open_for(q, state.get_answer(point_id), locked)
	_hint.text = "จุดที่ %d: %s" % [point_id, q.hint]


func _on_answer_confirmed(point_id: int, option: String) -> void:
	if not state.set_answer(point_id, option):
		return
	_set_status(MSG_SELECTED % point_id)
	_hint.text = GENERAL_HINT if state.answered_count(data) < data.questions.size() else "เลือกครบ 3 จุดแล้ว กด \"ตรวจสอบแบบ\" เพื่อตรวจคำตอบ"
	_save()
	_refresh()
	answer_confirmed.emit(point_id, option)


func _on_save_pressed() -> void:
	if _save():
		_hint.text = "บันทึก Project แล้ว"


func _on_menu(id: int) -> void:
	match id:
		MenuId.SAVE:
			_on_save_pressed()
		MenuId.CLOSE:
			close_mission()
		MenuId.VIEW_PLAN:
			_show_plan()
		MenuId.VIEW_REQUIREMENTS:
			_show_requirements()
		MenuId.VIEW_LAN:
			%LanRoutesItem.button_pressed = not %LanRoutesItem.button_pressed
		MenuId.CHECK:
			request_validation()
		MenuId.HELP:
			_show_info("วิธีทำภารกิจ", "1. คลิกจุดที่ 1, 2 หรือ 3 บนผังห้อง\n2. อ่านคำถาม เลือกอุปกรณ์ 1 ตัวเลือก แล้วกด \"ยืนยันการเลือก\"\n3. เปลี่ยนอุปกรณ์ได้โดยคลิกที่จุดเดิมอีกครั้ง (ก่อนตรวจไม่เสียคะแนน)\n4. เลือกครบ 3 จุดแล้วกด \"ตรวจสอบแบบ\"\n5. จุดสีแดงคือจุดที่ต้องแก้ไข แก้แล้วตรวจอีกครั้ง\n\nคะแนนเต็ม %d คะแนน — จุดที่ตรวจแล้วผิด จะถูกหักจุดละ %d คะแนนทุกครั้งที่ตรวจ\n\nEsc: ปิดหน้าต่างเลือกอุปกรณ์ → ปิดโปรแกรม" % [data.start_score, data.penalty_per_wrong])
	_sync_view_menu()


func _set_lan_highlight(on: bool) -> void:
	_plan.lan_highlight = on
	%ProjectNote.text = "กำลังเน้นเส้นทางสาย LAN — เส้นทางถูกกำหนดไว้แล้ว ดูได้อย่างเดียว แก้ไขไม่ได้" if on else "เส้นทางสาย LAN ถูกกำหนดไว้แล้ว ดูได้อย่างเดียว"
	_sync_view_menu()


func _sync_view_menu() -> void:
	var view: PopupMenu = %ViewMenu.get_popup()
	var index := view.get_item_index(MenuId.VIEW_LAN)
	if index >= 0:
		view.set_item_checked(index, %LanRoutesItem.button_pressed)


# ================================================================ pages

func _show_plan() -> void:
	_info.visible = false
	%RoomPlanItem.button_pressed = true


func _show_mission_brief() -> void:
	%MissionItem.button_pressed = true
	_show_info(data.mission_title + " — เลือกอุปกรณ์เครือข่ายห้องคอม", data.brief)


func _show_requirements() -> void:
	%RequirementsItem.button_pressed = true
	var lines := PackedStringArray()
	for r in data.requirements:
		lines.append("•  " + r)
	_show_info("ข้อกำหนด", "\n".join(lines))


func _show_info(title: String, body: String) -> void:
	%InfoTitle.text = title
	%InfoBody.text = body
	_info.visible = true


func _show_completion() -> void:
	%CompleteScore.text = "คะแนนรวม %d / %d" % [state.final_score, data.start_score]
	%CompleteChecks.text = "จำนวนครั้งที่ตรวจสอบ: %d ครั้ง" % state.check_count
	%CompleteWrong.text = "จำนวนจุดที่เคยผิด: %d จุด" % state.ever_wrong_count()
	_completion.visible = true
	_completion.move_to_front()


# ================================================================ refresh

func _refresh() -> void:
	var answered := state.answered_count(data)
	var total := data.questions.size()
	_progress_label.text = "%d/%d จุด" % [answered, total]
	_progress_bar.max_value = total
	_progress_bar.value = answered
	for q in data.questions:
		var id := q.point_id
		var status := state.get_status(id)
		var answer := state.get_answer(id)
		_plan.get_point(id).set_status(status, q.title, answer)
		var row: Dictionary = _rows[id]
		var text := answer if answer != "" else "ยังไม่เลือก"
		match status:
			Mission01State.PointStatus.WRONG:
				text += "  — ต้องแก้ไข"
			Mission01State.PointStatus.CORRECT:
				text += "  — ถูกต้อง"
		(row.device as Label).text = text
		(row.device as Label).add_theme_color_override("font_color", NetPlanTheme.INK if status != Mission01State.PointStatus.WRONG else NetPlanTheme.WRONG)
		(row.dot as Control).queue_redraw()
	if state.check_count == 0:
		_score.text = "คะแนน: ยังไม่ได้ตรวจสอบ (คะแนนเต็ม %d)" % data.start_score
	else:
		_score.text = "คะแนน: %d / %d" % [state.total_score(), data.start_score]
	_check_count.text = "ตรวจสอบแล้ว: %d ครั้ง" % state.check_count
	var can_check := not state.passed
	%CheckDesignButton.disabled = not can_check
	%SideCheckButton.disabled = not can_check
	var check_menu: PopupMenu = %CheckMenu.get_popup()
	if check_menu.item_count > 0:
		check_menu.set_item_disabled(0, not can_check)


func _set_status(text: String, color: Color = NetPlanTheme.INK) -> void:
	status_message = text
	_status.text = text
	_status.add_theme_color_override("font_color", Color.WHITE if color != NetPlanTheme.INK else NetPlanTheme.INK)
	var bg := NetPlanTheme.MENU_BAR if color == NetPlanTheme.INK else color
	_status_bar.add_theme_stylebox_override("panel", NetPlanTheme.box(bg, NetPlanTheme.BORDER, 0, 12, 3))
	%StatusInfo.add_theme_color_override("font_color", Color(1, 1, 1, 0.85) if color != NetPlanTheme.INK else NetPlanTheme.INK_SOFT)


func _save() -> bool:
	if not use_save_file:
		return true
	return Mission01SaveStore.save(state)


static func _join_points(ids: Array[int]) -> String:
	var parts := PackedStringArray()
	for id in ids:
		parts.append(str(id))
	return ", ".join(parts)
