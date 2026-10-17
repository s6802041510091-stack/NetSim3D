class_name TeamViewerSim
extends PanelContainer

## TeamViewer (simulated, for teaching) — the program for Mission 6.
##
##   Home      "Allow Remote Control" (this computer) + "Control Remote Computer":
##             type the Partner ID, press Connect.
##   Auth      type the Password, press Log On -> "Connection established".
##   Session   the teacher's desktop inside a Remote Session bar
##             (Connected to: TEACHER-PC, Session status: Active, End Session).
##             Fix the sound: speaker icon -> unmute -> 50–70 % -> ทดสอบเสียง.
##   End       End Session -> confirm -> Disconnect -> "Session ended",
##             then close the program and switch the computer off.
##
## Nothing here is real: no real TeamViewer, no network connection, no data leaves
## the game. The ID and password are made up (Mission06Data).
## Runs on the simulated desktop: DesktopOS.open_teamviewer().

signal connect_attempted(accepted: bool)
signal login_attempted(accepted: bool)
signal session_started
## "muted", "low", "high" or "ok".
signal sound_tested(result: String)
signal teacher_confirmed
signal session_ended
signal mistake_made(reason: String, penalty: int)
signal close_requested
signal minimize_requested

const DATA_PATH := "res://missions/mission_06/data/mission_06_data.tres"
## How long "Connection established" stays before the remote desktop appears.
const CONNECT_DELAY := 1.2

enum View { HOME, SESSION, ENDED }

@export var data: Mission06Data
@export var use_save_file: bool = true
## Handle Esc here. Inside DesktopOS the desktop calls handle_escape() instead.
@export var handle_escape_itself: bool = false

var state: Mission06State = Mission06State.new()
var view: View = View.HOME
var session_active: bool = false

var _body: Control
var _overlay: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_until := 0
var _footer: Label
var _id_edit: LineEdit
var _pw_edit: LineEdit
var _home_msg: Label
var _auth_msg: Label
var _auth_card: Control
var _confirm_card: Control
var _connected_card: Control
var _flyout: PanelContainer
var _slider: HSlider
var _volume_label: Label
var _mute_button: Button
var _speaker_button: Button
var _advice: Label
var _video_status: Label
var _teacher_bubble: PanelContainer
var _pending_connect := false


func _ready() -> void:
	theme = RemoteTheme.build()
	if data == null:
		data = load(DATA_PATH) as Mission06Data
	var problem := data.validate_data()
	if problem != "":
		push_error("TeamViewer (Mission 6): " + problem)
	if get_tree().current_scene == self:
		handle_escape_itself = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if use_save_file:
		Mission06SaveStore.load_into(state, data)
	else:
		state.reset(data)
	state.teamviewer_closed = false # The program is open now.
	_save()
	add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.BG, RemoteTheme.BORDER, 0, 0, 0))
	_build_frame()
	_show_view(View.HOME)


func _process(_delta: float) -> void:
	if _toast.visible and Time.get_ticks_msec() > _toast_until:
		_toast.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if handle_escape_itself and visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		handle_escape()


# ================================================================ public API

## Esc: close the top pop-up first, then try to close the program.
func handle_escape() -> bool:
	if not visible:
		return false
	if _auth_card.visible:
		cancel_login()
	elif _confirm_card.visible:
		cancel_end_session()
	elif _flyout != null and _flyout.visible:
		_flyout.visible = false
	else:
		try_close()
	return true


## Connect button. True when the Partner ID is right and the auth window opens.
func connect_partner(typed_id: String) -> bool:
	if session_active or _pending_connect:
		return false
	if data.normalize_id(typed_id) == "":
		_set_home_message(data.msg_empty_id, RemoteTheme.WARNING)
		return false
	if not state.call_answered:
		# The partner has not opened TeamViewer or allowed the connection yet.
		_set_home_message(data.msg_partner_not_ready, RemoteTheme.WARNING)
		return false
	var ok := data.is_partner_id(typed_id)
	connect_attempted.emit(ok)
	if not ok:
		state.wrong_id_count += 1
		_mistake(data.msg_wrong_id, data.penalty_wrong_id)
		_set_home_message("%s  (−%d คะแนน)" % [data.msg_wrong_id, data.penalty_wrong_id], RemoteTheme.DANGER)
		return false
	state.id_accepted_once = true
	_save()
	_set_home_message("", RemoteTheme.INK)
	_open_auth()
	return true


## Log On button. True when the password is right and the session starts.
func log_on(typed_password: String) -> bool:
	if not _auth_card.visible:
		return false
	if typed_password == "":
		_set_auth_message(data.msg_empty_password)
		return false
	var ok := data.is_partner_password(typed_password)
	login_attempted.emit(ok)
	if not ok:
		state.wrong_password_count += 1
		_mistake(data.msg_wrong_password, data.penalty_wrong_password)
		_set_auth_message("%s  (−%d คะแนน)" % [data.msg_wrong_password, data.penalty_wrong_password])
		return false
	_close_overlay()
	session_active = true
	state.connected_once = true
	state.session_ended = false
	_save()
	_pending_connect = true
	_overlay.visible = true
	_connected_card.visible = true
	get_tree().create_timer(CONNECT_DELAY).timeout.connect(func():
		if not is_inside_tree():
			return
		_pending_connect = false
		_close_overlay()
		_show_view(View.SESSION)
		session_started.emit())
	return true


func cancel_login() -> void:
	_close_overlay()


func open_volume_flyout() -> void:
	if view == View.SESSION and _flyout:
		_flyout.visible = not _flyout.visible
		_refresh_sound()


func toggle_mute() -> void:
	if not session_active:
		return
	state.remote_muted = not state.remote_muted
	_save()
	_refresh_sound()


func set_volume(value: int) -> void:
	if not session_active:
		return
	state.remote_volume = clampi(value, 0, 100)
	if _slider and int(_slider.value) != state.remote_volume:
		_slider.set_value_no_signal(state.remote_volume)
	_save()
	_refresh_sound()


## "ทดสอบเสียง". Wrong settings give advice only (no points lost).
func test_sound() -> String:
	if not session_active:
		return ""
	var result := "ok"
	var advice := ""
	if state.remote_muted:
		result = "muted"
		advice = data.msg_still_muted
	elif state.remote_volume < data.volume_min:
		result = "low"
		advice = data.msg_volume_low
	elif state.remote_volume > data.volume_max:
		result = "high"
		advice = data.msg_volume_high
	sound_tested.emit(result)
	if result == "ok":
		var first := not state.teacher_confirmed
		state.teacher_confirmed = true
		_save()
		_refresh_sound()
		if first:
			teacher_confirmed.emit()
	else:
		_advice.text = advice
		_advice.visible = true
	return result


## End Session button: asks first.
func request_end_session() -> void:
	if not session_active:
		return
	_overlay.visible = true
	_confirm_card.visible = true


func confirm_disconnect() -> void:
	if not session_active:
		return
	_close_overlay()
	session_active = false
	state.session_ended = true
	_save()
	_show_view(View.ENDED)
	session_ended.emit()


func cancel_end_session() -> void:
	_close_overlay()


## Title-bar close / Esc. Closing during a Remote Session is not allowed and
## costs points; the player must end the session properly first.
func try_close() -> bool:
	if session_active or _pending_connect:
		_close_blocked()
		return false
	state.teamviewer_closed = true
	_save()
	close_requested.emit()
	return true


## Called by DesktopOS before switching the computer off. Returns true to stop it.
func block_shutdown() -> bool:
	if session_active or _pending_connect:
		_close_blocked()
	else:
		_show_toast(data.msg_close_teamviewer_first, RemoteTheme.WARNING)
	return true


# ================================================================ internals

func _mistake(reason: String, penalty: int) -> void:
	state.penalise(penalty)
	_save()
	_update_footer()
	mistake_made.emit(reason, penalty)


func _close_blocked() -> void:
	state.close_without_end_count += 1
	_mistake(data.msg_close_without_end, data.penalty_close_without_end)
	_show_toast("%s  (−%d คะแนน)" % [data.msg_close_without_end, data.penalty_close_without_end], RemoteTheme.DANGER)


func _save() -> void:
	if use_save_file:
		Mission06SaveStore.save(state)


func _open_auth() -> void:
	_overlay.visible = true
	_auth_card.visible = true
	_pw_edit.text = ""
	_auth_msg.text = ""
	_pw_edit.grab_focus.call_deferred()


func _close_overlay() -> void:
	_overlay.visible = false
	for card in [_auth_card, _confirm_card, _connected_card]:
		card.visible = false


func _set_home_message(text: String, color: Color) -> void:
	if _home_msg:
		_home_msg.text = text
		_home_msg.add_theme_color_override("font_color", color)


func _set_auth_message(text: String) -> void:
	_auth_msg.text = text


func _show_toast(text: String, color: Color) -> void:
	var s := RemoteTheme.box(color, color.darkened(0.2), 6, 16, 10)
	_toast.add_theme_stylebox_override("panel", s)
	_toast_label.text = text
	_toast.visible = true
	_toast.move_to_front()
	_toast_until = Time.get_ticks_msec() + 4500


func _update_footer() -> void:
	var status := "พร้อมเชื่อมต่อ (Ready to connect)"
	if session_active:
		status = "Remote Session: Active — %s" % data.partner_name
	elif view == View.ENDED:
		status = "Session ended"
	_footer.text = "%s      คะแนนภารกิจ %d / %d" % [status, state.score, data.start_score]


# ================================================================ frame

func _build_frame() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_title_bar())

	var content := Control.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	_body = Control.new()
	_body.name = "Body"
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(_body)

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.35)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	content.add_child(_overlay)
	_auth_card = _build_auth_card()
	_confirm_card = _build_confirm_card()
	_connected_card = _build_connected_card()

	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -330
	_toast.offset_right = 330
	_toast.offset_top = 56
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_toast)
	_toast_label = _label("", 16, Color.WHITE, true)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)

	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.PANEL, Color(0, 0, 0, 0), 0, 14, 5))
	column.add_child(foot)
	var foot_row := HBoxContainer.new()
	foot.add_child(foot_row)
	_footer = _label("", 14, RemoteTheme.INK)
	_footer.name = "Footer"
	foot_row.add_child(_footer)
	# Long disclaimer: clipped to the space left so it never widens the window.
	var note := _label(data.disclaimer, 12, RemoteTheme.INK_SOFT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.tooltip_text = data.disclaimer
	note.mouse_filter = Control.MOUSE_FILTER_PASS
	foot_row.add_child(note)


func _title_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 40)
	bar.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.94, 0.95, 0.97), Color(0, 0, 0, 0), 0, 10, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(26, 26)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.draw.connect(func(): RemoteTheme.draw_logo(logo, logo.size * 0.5, 24.0))
	row.add_child(logo)
	var title := _label(data.app_name, 16, RemoteTheme.INK, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var note := _label("(%s)" % data.app_note, 14, RemoteTheme.INK_SOFT)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	row.add_child(_window_button("MinimizeButton", false, func(): minimize_requested.emit()))
	row.add_child(_window_button("CloseButton", true, try_close))
	return bar


func _window_button(node_name: String, is_close: bool, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(44, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := RemoteTheme.box(Color(0.78, 0.16, 0.16) if is_close else Color(0, 0, 0, 0.08), Color(0, 0, 0, 0), 0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	b.draw.connect(func(): _draw_window_button(b, is_close))
	return b


func _draw_window_button(b: Button, is_close: bool) -> void:
	var c := b.size * 0.5
	var color := Color.WHITE if is_close and b.is_hovered() else RemoteTheme.INK
	if is_close:
		RemoteTheme.draw_cross(b, c, 22.0, color, 1.6)
	else:
		b.draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), color, 1.6)


func _show_view(target: View) -> void:
	view = target
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_flyout = null
	_home_msg = null
	match target:
		View.HOME:
			_build_home()
		View.SESSION:
			_build_session()
		View.ENDED:
			_build_ended()
	_update_footer()


# ================================================================ home

func _build_home() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	_body.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	# Left: this computer + checklist.
	var left := _panel(380)
	row.add_child(left.get_parent())
	left.add_child(_label("Allow Remote Control", 20, RemoteTheme.INK, true))
	left.add_child(_label("ข้อมูลของคอมพิวเตอร์เครื่องนี้ (IT-PC-01)", 14, RemoteTheme.INK_SOFT))
	left.add_child(_label("Your ID", 14, RemoteTheme.INK_SOFT))
	left.add_child(_label(data.own_id, 26, RemoteTheme.INK, true))
	left.add_child(_label("Password", 14, RemoteTheme.INK_SOFT))
	left.add_child(_label(data.own_password, 22, RemoteTheme.INK, true))
	left.add_child(HSeparator.new())
	left.add_child(_label("รายการตรวจสอบก่อนเชื่อมต่อ", 16, RemoteTheme.INK, true))
	var partner_ready := state.call_answered
	for item in [
		["คอมพิวเตอร์ของผู้เล่นเปิดอยู่", true],
		["คอมพิวเตอร์ของครูสาวเปิดอยู่", partner_ready],
		["เครื่องทั้งสองเชื่อมต่อเครือข่าย", partner_ready],
		["เครื่องทั้งสองเปิด TeamViewer", partner_ready],
		["ครูสาวอนุญาตให้เจ้าหน้าที่เชื่อมต่อ", partner_ready],
	]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.add_child(RemoteTheme.status_icon(item[1], 18))
		line.add_child(_label(item[0], 15, RemoteTheme.INK))
		left.add_child(line)

	# Right: control a remote computer.
	var right := _panel(0)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right.get_parent())
	right.add_child(_label("Control Remote Computer", 20, RemoteTheme.INK, true))
	right.add_child(_label("พิมพ์ TeamViewer ID ของเครื่องปลายทางที่ได้รับจากผู้ใช้", 14, RemoteTheme.INK_SOFT))
	right.add_child(_label("Partner ID", 15, RemoteTheme.INK, true))
	_id_edit = LineEdit.new()
	_id_edit.name = "PartnerIdEdit"
	_id_edit.placeholder_text = "พิมพ์ Partner ID"
	_id_edit.max_length = 20
	_id_edit.custom_minimum_size = Vector2(0, 42)
	_id_edit.add_theme_font_size_override("font_size", 20)
	_id_edit.text_submitted.connect(func(t): connect_partner(t))
	right.add_child(_id_edit)
	var mode := HBoxContainer.new()
	mode.add_theme_constant_override("separation", 8)
	mode.add_child(RemoteTheme.status_icon(true, 16))
	mode.add_child(_label("Remote control (ควบคุมเครื่องปลายทาง)", 15, RemoteTheme.INK))
	right.add_child(mode)
	var connect := Button.new()
	connect.name = "ConnectButton"
	connect.text = "Connect"
	connect.custom_minimum_size = Vector2(200, 44)
	connect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	RemoteTheme.primary(connect)
	connect.pressed.connect(func(): connect_partner(_id_edit.text))
	right.add_child(connect)
	_home_msg = _label("", 15, RemoteTheme.DANGER, true)
	_home_msg.name = "HomeMessage"
	_home_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_home_msg)
	var note := _label("การเชื่อมต่อแบบนี้ใช้ TeamViewer ID และ Password ของเครื่องปลายทาง ไม่ต้องกรอก IP Address", 13, RemoteTheme.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)


func _panel(width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.PANEL, RemoteTheme.BORDER, 8, 20, 16))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return col


# ================================================================ pop-ups

func _card(node_name: String, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.name = node_name
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", RemoteTheme.box(Color(1, 1, 1), RemoteTheme.BORDER, 8, 24, 20))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	return col


func _build_auth_card() -> Control:
	var col := _card("AuthCard", 460)
	col.add_child(_label("TeamViewer Authentication", 20, RemoteTheme.INK, true))
	var info := _label("พิมพ์ Password ที่แสดงบนหน้าจอของเครื่องปลายทาง (ผู้ใช้ปลายทางเป็นผู้แจ้ง)", 14, RemoteTheme.INK_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	col.add_child(_label("Password", 15, RemoteTheme.INK, true))
	_pw_edit = LineEdit.new()
	_pw_edit.name = "PasswordEdit"
	_pw_edit.secret = true
	_pw_edit.custom_minimum_size = Vector2(0, 42)
	_pw_edit.add_theme_font_size_override("font_size", 20)
	_pw_edit.text_submitted.connect(func(t): log_on(t))
	col.add_child(_pw_edit)
	var show := CheckBox.new()
	show.text = "แสดงรหัสผ่าน"
	show.focus_mode = Control.FOCUS_NONE
	show.toggled.connect(func(on): _pw_edit.secret = not on)
	col.add_child(show)
	_auth_msg = _label("", 15, RemoteTheme.DANGER, true)
	_auth_msg.name = "AuthMessage"
	_auth_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_auth_msg)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var log_button := Button.new()
	log_button.name = "LogOnButton"
	log_button.text = "Log On"
	log_button.custom_minimum_size = Vector2(150, 42)
	RemoteTheme.primary(log_button)
	log_button.pressed.connect(func(): log_on(_pw_edit.text))
	buttons.add_child(log_button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 42)
	cancel.pressed.connect(cancel_login)
	buttons.add_child(cancel)
	return col.get_parent().get_parent()


func _build_confirm_card() -> Control:
	var col := _card("ConfirmEndCard", 460)
	col.add_child(_label("End Session", 20, RemoteTheme.INK, true))
	col.add_child(_label(data.msg_end_confirm, 16, RemoteTheme.INK))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var disconnect := Button.new()
	disconnect.name = "DisconnectButton"
	disconnect.text = "Disconnect"
	disconnect.custom_minimum_size = Vector2(160, 42)
	RemoteTheme.primary(disconnect, RemoteTheme.DANGER)
	disconnect.pressed.connect(confirm_disconnect)
	buttons.add_child(disconnect)
	var cancel := Button.new()
	cancel.text = "ยกเลิก"
	cancel.custom_minimum_size = Vector2(120, 42)
	cancel.pressed.connect(cancel_end_session)
	buttons.add_child(cancel)
	return col.get_parent().get_parent()


func _build_connected_card() -> Control:
	var col := _card("ConnectedCard", 420)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(RemoteTheme.status_icon(true, 28))
	row.add_child(_label(data.msg_connected, 22, RemoteTheme.OK, true))
	col.add_child(row)
	col.add_child(_label("กำลังเปิด Desktop ของ %s ..." % data.partner_name, 15, RemoteTheme.INK_SOFT))
	return col.get_parent().get_parent()


# ================================================================ remote session

func _session_bar(active: bool) -> Control:
	var bar := PanelContainer.new()
	bar.name = "SessionBar"
	bar.custom_minimum_size = Vector2(0, 46)
	bar.add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.SESSION_BAR, Color(0, 0, 0, 0), 0, 14, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(22, 22)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.draw.connect(func(): RemoteTheme.draw_logo(logo, logo.size * 0.5, 20.0))
	row.add_child(logo)
	for part in [["Remote Session", Color.WHITE, true], ["Connected to: %s" % data.partner_name, Color(0.82, 0.86, 0.92), false]]:
		var l := _label(part[0], 16, part[1], part[2])
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	var status := _label("Session status: Active" if active else "Session status: Session ended", 16, Color(0.45, 0.9, 0.55) if active else Color(0.75, 0.78, 0.83), true)
	status.name = "SessionStatus"
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	if active:
		var end := Button.new()
		end.name = "EndSessionButton"
		end.text = "End Session"
		end.custom_minimum_size = Vector2(150, 36)
		end.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		RemoteTheme.primary(end, RemoteTheme.DANGER)
		end.pressed.connect(request_end_session)
		row.add_child(end)
	return bar


func _build_session() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	_body.add_child(column)
	column.add_child(_session_bar(true))

	var screen := Control.new()
	screen.name = "RemoteDesktop"
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.clip_contents = true
	column.add_child(screen)

	var wallpaper := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.36, 0.22, 0.45))
	gradient.set_color(1, Color(0.93, 0.55, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_to = Vector2(1, 1)
	wallpaper.texture = tex
	wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and _flyout: _flyout.visible = false)
	screen.add_child(wallpaper)

	var icons := VBoxContainer.new()
	icons.position = Vector2(18, 16)
	icons.add_theme_constant_override("separation", 16)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(icons)
	for item in [["VID", Color(0.85, 0.3, 0.3), "วิดีโอประกอบการสอน"], ["DOC", Color(0.25, 0.5, 0.9), "เอกสารการสอน"], ["BIN", Color(0.55, 0.6, 0.65), "Recycle Bin"]]:
		icons.add_child(_remote_icon(item[0], item[1], item[2]))

	screen.add_child(_video_window())
	_teacher_bubble = _build_teacher_bubble()
	screen.add_child(_teacher_bubble)
	screen.add_child(_remote_taskbar())
	_flyout = _build_flyout()
	screen.add_child(_flyout)
	_refresh_sound()


func _remote_icon(glyph: String, color: Color, caption: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(110, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(44, 38)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.add_theme_stylebox_override("panel", RemoteTheme.box(color, Color(0, 0, 0, 0), 6, 4, 4))
	var g := _label(glyph, 13, Color.WHITE, true)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(g)
	box.add_child(tile)
	var c := _label(caption, 13, Color.WHITE)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	c.add_theme_constant_override("outline_size", 3)
	box.add_child(c)
	return box


func _video_window() -> Control:
	var win := PanelContainer.new()
	win.name = "VideoWindow"
	win.position = Vector2(170, 24)
	win.custom_minimum_size = Vector2(520, 0)
	win.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.14, 0.15, 0.18), Color(0, 0, 0, 0.5), 6, 0, 0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	win.add_child(col)
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.22, 0.23, 0.27), Color(0, 0, 0, 0), 0, 10, 4))
	title.add_child(_label("วิดีโอประกอบการสอน.mp4 — Media Player", 14, Color(0.9, 0.92, 0.95)))
	col.add_child(title)
	var picture := ColorRect.new()
	picture.color = Color(0.05, 0.12, 0.22)
	picture.custom_minimum_size = Vector2(520, 200)
	var caption := _label("บทที่ 8  ซอฟต์แวร์ช่วยงานระบบเครือข่าย", 20, Color.WHITE, true)
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picture.add_child(caption)
	col.add_child(picture)
	var controls := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		controls.add_theme_constant_override("margin_" + side, 10)
	col.add_child(controls)
	var line := VBoxContainer.new()
	controls.add_child(line)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = 38
	bar.custom_minimum_size = Vector2(0, 6)
	bar.add_theme_stylebox_override("background", RemoteTheme.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 2, 0, 0))
	bar.add_theme_stylebox_override("fill", RemoteTheme.box(Color(0.95, 0.4, 0.35), Color(0, 0, 0, 0), 2, 0, 0))
	line.add_child(bar)
	_video_status = _label("", 14, Color(0.9, 0.92, 0.95))
	_video_status.name = "VideoStatus"
	line.add_child(_video_status)
	return win


func _build_teacher_bubble() -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.name = "TeacherBubble"
	bubble.anchor_left = 1.0
	bubble.anchor_right = 1.0
	bubble.offset_left = -360
	bubble.offset_right = -16
	bubble.offset_top = 16
	bubble.add_theme_stylebox_override("panel", RemoteTheme.box(Color(1, 1, 1, 0.97), RemoteTheme.OK, 10, 16, 12))
	var col := VBoxContainer.new()
	bubble.add_child(col)
	col.add_child(_label("ครูสาว (ทางโทรศัพท์)", 14, RemoteTheme.OK, true))
	var text := _label(data.teacher_confirm_line, 16, RemoteTheme.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	bubble.visible = false
	return bubble


func _remote_taskbar() -> Control:
	var bar := PanelContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -42
	bar.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.1, 0.11, 0.14, 0.95), Color(0, 0, 0, 0), 0, 10, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var start := _label("เริ่ม", 15, Color.WHITE, true)
	start.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(start)
	_speaker_button = Button.new()
	_speaker_button.name = "SpeakerIcon"
	_speaker_button.custom_minimum_size = Vector2(44, 36)
	_speaker_button.focus_mode = Control.FOCUS_NONE
	_speaker_button.tooltip_text = "ระดับเสียง (Speakers)"
	_speaker_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_speaker_button.add_theme_stylebox_override("hover", RemoteTheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 4))
	_speaker_button.add_theme_stylebox_override("pressed", RemoteTheme.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 4))
	_speaker_button.pressed.connect(open_volume_flyout)
	_speaker_button.draw.connect(func(): RemoteTheme.draw_speaker(_speaker_button, _speaker_button.size * 0.5, 24.0, Color.WHITE, state.remote_muted))
	row.add_child(_speaker_button)
	var t := Time.get_time_dict_from_system()
	var clock := _label("%02d:%02d" % [t.hour, t.minute], 15, Color.WHITE)
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(clock)
	return bar


func _build_flyout() -> PanelContainer:
	var fly := PanelContainer.new()
	fly.name = "VolumeFlyout"
	fly.anchor_left = 1.0
	fly.anchor_right = 1.0
	fly.anchor_top = 1.0
	fly.anchor_bottom = 1.0
	fly.offset_left = -400
	fly.offset_right = -10
	fly.offset_bottom = -48
	fly.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fly.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.97, 0.97, 0.98), RemoteTheme.BORDER, 8, 18, 14))
	fly.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	fly.add_child(col)
	col.add_child(_label("ระดับเสียง — Speakers", 16, RemoteTheme.INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_mute_button = Button.new()
	_mute_button.name = "MuteButton"
	_mute_button.custom_minimum_size = Vector2(48, 40)
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.tooltip_text = "เปิด/ปิดเสียง (Mute)"
	_mute_button.pressed.connect(toggle_mute)
	_mute_button.draw.connect(func(): RemoteTheme.draw_speaker(_mute_button, _mute_button.size * 0.5, 24.0, RemoteTheme.INK, state.remote_muted))
	row.add_child(_mute_button)
	_slider = HSlider.new()
	_slider.name = "VolumeSlider"
	_slider.min_value = 0
	_slider.max_value = 100
	_slider.step = 1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.set_value_no_signal(state.remote_volume)
	_slider.value_changed.connect(func(v): set_volume(int(v)))
	row.add_child(_slider)
	_volume_label = _label("", 18, RemoteTheme.INK, true)
	_volume_label.custom_minimum_size = Vector2(56, 0)
	row.add_child(_volume_label)
	var state_line := _label("", 14, RemoteTheme.INK_SOFT)
	state_line.name = "MuteState"
	col.add_child(state_line)
	var test := Button.new()
	test.name = "TestSoundButton"
	test.text = "ทดสอบเสียง"
	test.custom_minimum_size = Vector2(160, 40)
	test.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	RemoteTheme.primary(test)
	test.pressed.connect(test_sound)
	col.add_child(test)
	_advice = _label("", 14, RemoteTheme.WARNING, true)
	_advice.name = "SoundAdvice"
	_advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_advice.visible = false
	col.add_child(_advice)
	return fly


func _refresh_sound() -> void:
	if _flyout == null:
		return
	_volume_label.text = "%d%%" % state.remote_volume
	var mute_line: Label = _flyout.find_child("MuteState", true, false)
	mute_line.text = "สถานะ: ปิดเสียงอยู่ (Muted)" if state.remote_muted else "สถานะ: เปิดเสียง"
	_mute_button.queue_redraw()
	_speaker_button.queue_redraw()
	if state.teacher_confirmed:
		_video_status.text = "กำลังเล่น — มีเสียงตามปกติ"
		_advice.visible = false
		_teacher_bubble.visible = true
	else:
		_video_status.text = "กำลังเล่น — ไม่ได้ยินเสียง"


func _build_ended() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	_body.add_child(column)
	column.add_child(_session_bar(false))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	var col := VBoxContainer.new()
	col.name = "EndedInfo"
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(620, 0)
	center.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(RemoteTheme.status_icon(true, 26))
	row.add_child(_label("Remote Session สิ้นสุดแล้ว", 24, RemoteTheme.INK, true))
	col.add_child(row)
	var next := ""
	if state.teacher_confirmed:
		next = "แก้ไขปัญหาเสียงเรียบร้อยแล้ว ขั้นต่อไป: ปิดโปรแกรม TeamViewer แล้วปิดคอมพิวเตอร์ของคุณ (เริ่ม → ปิดเครื่อง)\nไม่ต้องปิดคอมพิวเตอร์ของครูสาว เพราะครูสาวยังต้องใช้งานต่อ"
	else:
		next = "ยังไม่ได้แก้ปัญหาเสียงของครูสาว เชื่อมต่อใหม่ได้จากหน้าหลัก (ต้องกรอก ID และ Password อีกครั้ง)"
	var info := _label(next, 16, RemoteTheme.INK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info)
	if not state.teacher_confirmed:
		var back := Button.new()
		back.name = "BackHomeButton"
		back.text = "กลับหน้าเชื่อมต่อ"
		back.custom_minimum_size = Vector2(200, 42)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back.pressed.connect(func(): _show_view(View.HOME))
		col.add_child(back)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", RemoteTheme.FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
