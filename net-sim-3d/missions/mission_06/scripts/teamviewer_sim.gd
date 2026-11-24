class_name TeamViewerSim
extends PanelContainer

## TeamViewer (simulated, for teaching) — the program of Mission 6 v2
## (ภารกิจ/ด่าน_06/README.md, "ร่างด่าน 6 v2", agreed with the user on
## 2026-11-15). English like the real program; Thai only in the game's own
## toast. No Microsoft / TeamViewer artwork: everything is drawn in code.
##
##   Home     "Allow Remote Control" (this computer) and "Control Remote
##            Computer": Partner ID (typed or pasted from the e-mail) ->
##            Connect -> Authentication: Password -> Log On. The status line
##            says "Ready to connect (secure connection)" like the real one
##            (no checklist that would give the steps away).
##   Session  the desktop of MEETING-PC in the small meeting room: the
##            presentation clip, the teacher's private grade file (opening
##            it is a privacy mistake), Start menu with Restart / Shut down
##            (both cut the session and disturb the teacher), the speaker
##            icon (muted, 25 %). The Chat (Communicate) lets the player ask
##            the teacher to play the clip; she answers with what she hears.
##   End      End Session -> Disconnect -> "Session ended". Then close the
##            program and switch IT-PC-01 off.
##
## A wrong step is not applied; Mission06State records it for the score.
## Nothing here is real: no real TeamViewer, no network connection.
## Runs on the simulated desktop: DesktopOS.open_teamviewer().

signal connect_attempted(accepted: bool)
signal login_attempted(accepted: bool)
signal session_started
signal chat_sent(text: String)
## Mute or volume changed on the remote computer.
signal sound_changed
## "muted", "low", "high" or "ok" — what the teacher heard.
signal teacher_replied(result: String)
signal teacher_confirmed
## The teacher asked one of the chat questions / the player answered it.
signal chat_question_asked(id: String)
signal chat_question_answered(id: String, correct: bool)
## "disconnect", "restart" or "shutdown".
signal session_ended(reason: String)
## "restart" / "shutdown" chosen in the remote Start menu.
signal remote_power_used(kind: String)
signal private_file_opened
signal mistake_made(reason: String)
signal close_requested
signal minimize_requested

const DATA_PATH := "res://missions/mission_06/data/mission_06_data.tres"
## How long "Connection established" stays before the remote desktop appears.
const CONNECT_DELAY := 1.2
## The teacher's first chat message after the session starts / her replies.
const HELLO_DELAY := 2.0
const REPLY_DELAY := 1.6
## Chat look, messenger style: the player's bubbles blue, hers light grey.
const CHAT_MINE := Color(0.0, 0.52, 1.0)
const CHAT_THEIRS := Color(0.91, 0.92, 0.94)
const CHAT_AVATAR := Color(0.85, 0.36, 0.55)
## The quick-reply tray under the log: a darker grey than the bubbles.
const CHAT_TRAY := Color(0.94, 0.95, 0.97)
const CHAT_BUBBLE_MAX := 196.0

enum View { HOME, SESSION, ENDED }

## This play's progress, set by Mission06Controller. When it is null (the
## scene run on its own with F6) the program starts with its own fresh state.
static var shared_state: Mission06State

@export var data: Mission06Data
## Handle Esc here. Inside DesktopOS the desktop calls handle_escape() instead.
@export var handle_escape_itself: bool = false

var state: Mission06State
var view: View = View.HOME
var _pending_connect := false
var _chat_unread := 0

var _body: Control
var _overlay: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_until := 0
var _status_dot: Control
var _status_label: Label
var _id_edit: LineEdit
var _pw_edit: LineEdit
var _home_msg: Label
var _auth_msg: Label
var _auth_card: Control
var _confirm_card: Control
var _connected_card: Control
var _partner_card: Control
var _partner_msg: Label
var _flyout: PanelContainer
var _slider: HSlider
var _volume_label: Label
var _mute_button: Button
var _speaker_button: Button
var _video_status: Label
var _start_menu: PanelContainer
var _power_menu: VBoxContainer
var _sheet: PanelContainer
var _chat: PanelContainer
var _chat_log: VBoxContainer
var _chat_scroll: ScrollContainer
## Preset message buttons (no free typing).
var _chat_presets: VBoxContainer
var _chat_button: Button
var _chat_history: Array = [] # [speaker, text] kept across views
## The teacher's question waiting in the chat ("" when none), its reply
## buttons and their order (data indexes).
var chat_question := ""
var reply_order: Array[int] = []
var _reply_box: VBoxContainer


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
	if shared_state != null:
		state = shared_state
	else:
		state = Mission06State.new()
		state.reset(data)
		state.call_answered = true
		state.partner_online = true
	state.tv_opened = true
	state.tv_closed = false
	add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.BG, RemoteTheme.BORDER, 0, 0, 0))
	_build_frame()
	_show_view(View.SESSION if state.session_active else View.HOME)


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
	elif _partner_card.visible:
		_close_overlay()
	elif _sheet != null and _sheet.visible:
		_sheet.visible = false
	elif _start_menu != null and _start_menu.visible:
		_start_menu.visible = false
	elif _flyout != null and _flyout.visible:
		_flyout.visible = false
	else:
		try_close()
	return true


## Connect button. True when the Partner ID is right and the password window opens.
func connect_partner(typed_id: String) -> bool:
	if state.session_active or _pending_connect:
		return false
	if data.normalize_id(typed_id) == "":
		_set_home_message(data.msg_empty_id, RemoteTheme.WARNING)
		return false
	var ok := data.is_partner_id(typed_id)
	if ok and not state.partner_online:
		# Right ID, but TeamViewer is not running over there (yet / again).
		_set_home_message(data.msg_partner_offline, RemoteTheme.WARNING)
		return false
	connect_attempted.emit(ok)
	if not ok:
		state.wrong_id_count += 1
		_set_home_message(data.msg_wrong_id, RemoteTheme.DANGER)
		mistake_made.emit(data.msg_wrong_id)
		return false
	_set_home_message("", RemoteTheme.INK)
	_open_auth()
	return true


## Log On button (case-sensitive). True when the session starts.
func log_on(typed_password: String) -> bool:
	if not _auth_card.visible:
		return false
	if typed_password == "":
		_auth_msg.text = data.msg_empty_password
		return false
	var ok := typed_password.strip_edges() == state.partner_password
	login_attempted.emit(ok)
	if not ok:
		state.wrong_password_count += 1
		_auth_msg.text = data.msg_wrong_password
		mistake_made.emit(data.msg_wrong_password)
		return false
	_close_overlay()
	state.session_active = true
	state.connected_once = true
	_pending_connect = true
	_overlay.visible = true
	_connected_card.visible = true
	_refresh_status()
	get_tree().create_timer(CONNECT_DELAY).timeout.connect(func():
		if not is_inside_tree() or not state.session_active:
			return
		_pending_connect = false
		_close_overlay()
		_show_view(View.SESSION)
		session_started.emit()
		get_tree().create_timer(HELLO_DELAY).timeout.connect(func():
			if is_inside_tree() and state.session_active and _chat_history.is_empty():
				_receive_chat(data.chat_teacher_hello))
		# Back after a dropped session: her questions are still waiting.
		if state.teacher_confirmed:
			_ask_chat_question_later())
	return true


func cancel_login() -> void:
	_close_overlay()


func open_volume_flyout() -> void:
	if view == View.SESSION and _flyout:
		_start_menu.visible = false
		_flyout.visible = not _flyout.visible
		_refresh_sound()


func toggle_mute() -> void:
	if not state.session_active:
		return
	state.remote_muted = not state.remote_muted
	_refresh_sound()
	sound_changed.emit()


func set_volume(value: int) -> void:
	if not state.session_active:
		return
	state.remote_volume = clampi(value, 0, 100)
	if _slider and int(_slider.value) != state.remote_volume:
		_slider.set_value_no_signal(state.remote_volume)
	_refresh_sound()
	sound_changed.emit()


func open_chat() -> void:
	if view != View.SESSION or _chat == null:
		return
	_chat.visible = true
	_chat_unread = 0
	_refresh_chat_button()


## Sends a chat message (one of data.chat_presets from the buttons; tools may
## pass any text). The teacher plays the clip and answers with what she hears
## (any message is a request to test). True when sent.
func send_chat(text: String) -> bool:
	var message := text.strip_edges()
	if message == "" or not state.session_active or view != View.SESSION:
		return false
	_add_chat("คุณ", message)
	chat_sent.emit(message)
	get_tree().create_timer(REPLY_DELAY).timeout.connect(func():
		if not is_inside_tree() or not state.session_active:
			return
		var result := state.sound_result(data)
		var reply: String = {"muted": data.chat_reply_muted, "low": data.chat_reply_low, "high": data.chat_reply_high, "ok": data.chat_reply_ok}[result]
		_receive_chat(reply)
		var first := result == "ok" and not state.teacher_confirmed
		if result == "ok":
			state.teacher_confirmed = true
			_refresh_sound()
		teacher_replied.emit(result)
		if first:
			teacher_confirmed.emit()
			_ask_chat_question_later())
	return true


## One of the teacher's chat questions, answered with a reply button
## (`option_index` = index in the data). True when right.
func answer_chat_question(option_index: int) -> bool:
	var q := data.get_question(chat_question)
	if q == null or option_index < 0 or option_index >= q.options.size():
		return false
	var id := chat_question
	chat_question = ""
	reply_order.clear()
	_refresh_replies()
	_add_chat("คุณ", q.options[option_index])
	var right := q.is_correct(option_index)
	state.note_question(id, option_index, right)
	chat_question_answered.emit(id, right)
	get_tree().create_timer(REPLY_DELAY).timeout.connect(func():
		if not is_inside_tree():
			return
		_receive_chat(q.reactions[option_index])
		if right:
			_ask_chat_question_later()
		elif state.session_active:
			_ask_chat_question(id, false))
	return right


func _ask_chat_question_later() -> void:
	get_tree().create_timer(REPLY_DELAY).timeout.connect(func():
		if is_inside_tree() and state.session_active and chat_question == "":
			var next := state.next_chat_question()
			if next != "":
				_ask_chat_question(next, true))


## The teacher asks (or, after a wrong answer, waits again with new buttons).
func _ask_chat_question(id: String, say_it: bool) -> void:
	var q := data.get_question(id)
	if q == null:
		return
	chat_question = id
	reply_order.clear()
	for i in q.options.size():
		reply_order.append(i)
	reply_order.shuffle()
	if say_it:
		_receive_chat(q.prompt)
		chat_question_asked.emit(id)
	_refresh_replies()


func _refresh_replies() -> void:
	if _reply_box == null or not is_instance_valid(_reply_box):
		return
	for child in _reply_box.get_children():
		_reply_box.remove_child(child)
		child.queue_free()
	var q := data.get_question(chat_question)
	_reply_box.visible = q != null
	# Her question waits for an answer: the preset messages step aside.
	if _chat_presets and is_instance_valid(_chat_presets):
		_chat_presets.visible = q == null
	if q == null:
		return
	# Her question is the last bubble above; the tray says what to do with it.
	var asked := _label("ตอบคำถามของ%s · เลือก 1 ข้อ" % data.teacher_name, 12, RemoteTheme.INK_SOFT, true)
	asked.name = "ReplyQuestion"
	asked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asked.custom_minimum_size = Vector2(250, 0)
	_reply_box.add_child(asked)
	_scroll_chat.call_deferred()
	for i in reply_order:
		var b := _chat_pill(q.options[i])
		b.name = "Reply%d" % i
		b.pressed.connect(answer_chat_question.bind(i))
		_reply_box.add_child(b)


## Double-click on a file of the remote desktop. The private grade file is
## not the player's business: it opens (like Windows would) and is recorded.
func open_remote_file(file_name: String) -> void:
	if view != View.SESSION:
		return
	if file_name == data.private_file:
		state.opened_private_file = true
		_sheet.visible = true
		_sheet.move_to_front()
		private_file_opened.emit()
	elif file_name == data.video_file:
		var win := find_child("VideoWindow", true, false) as Control
		if win:
			win.move_to_front()


func open_start_menu() -> void:
	if view == View.SESSION and _start_menu:
		_flyout.visible = false
		_start_menu.visible = not _start_menu.visible
		_power_menu.visible = false


## Restart / Shut down of MEETING-PC from its Start menu: the session drops at
## once, the teacher has to start TeamViewer again (a new password, by e-mail).
func remote_power(kind: String) -> void:
	if not state.session_active or not kind in ["restart", "shutdown"]:
		return
	state.disruptive.append(kind)
	state.session_active = false
	state.last_end = kind
	state.partner_online = false
	state.partner_password = data.partner_password_after_restart
	mistake_made.emit(kind)
	remote_power_used.emit(kind)
	_show_view(View.HOME)
	_partner_msg.text = data.msg_partner_restarted if kind == "restart" else data.msg_partner_shut_down
	_overlay.visible = true
	_partner_card.visible = true
	session_ended.emit(kind)


## The teacher started TeamViewer again (the controller calls this when her
## new e-mail arrives).
func partner_back_online() -> void:
	state.partner_online = true
	_refresh_status()


## End Session button: asks first.
func request_end_session() -> void:
	if not state.session_active:
		return
	_overlay.visible = true
	_confirm_card.visible = true


func confirm_disconnect() -> void:
	if not state.session_active:
		return
	_close_overlay()
	state.session_active = false
	state.last_end = "disconnect"
	if not state.teacher_confirmed:
		state.ended_before_confirm = true
	_show_view(View.ENDED)
	session_ended.emit("disconnect")


func cancel_end_session() -> void:
	_close_overlay()


## Title-bar close / Esc. Not during a Remote Session (recorded).
func try_close() -> bool:
	if state.session_active or _pending_connect:
		state.close_in_session_count += 1
		_show_toast(data.msg_close_in_session, RemoteTheme.DANGER)
		mistake_made.emit(data.msg_close_in_session)
		return false
	state.tv_closed = true
	close_requested.emit()
	return true


## DesktopOS asks before switching the computer off. True stops it: during a
## session (a message only), or with the program still open (recorded once
## the work is done — closing the program comes first).
func block_shutdown() -> bool:
	if state.session_active or _pending_connect:
		_show_toast(data.msg_shutdown_in_session, RemoteTheme.WARNING)
		return true
	if state.work_done():
		state.shutdown_with_tv_count += 1
		mistake_made.emit(data.msg_close_teamviewer_first)
	_show_toast(data.msg_close_teamviewer_first, RemoteTheme.WARNING)
	return true


func chat_lines() -> Array:
	return _chat_history.duplicate()


# ================================================================ internals

func _open_auth() -> void:
	_overlay.visible = true
	_auth_card.visible = true
	_pw_edit.text = ""
	_auth_msg.text = ""
	_pw_edit.grab_focus.call_deferred()


func _close_overlay() -> void:
	_overlay.visible = false
	for card in [_auth_card, _confirm_card, _connected_card, _partner_card]:
		card.visible = false


func _set_home_message(text: String, color: Color) -> void:
	if _home_msg:
		_home_msg.text = text
		_home_msg.add_theme_color_override("font_color", color)


func _show_toast(text: String, color: Color) -> void:
	_toast.add_theme_stylebox_override("panel", RemoteTheme.box(color, color.darkened(0.2), 6, 16, 10))
	_toast_label.text = text
	_toast.visible = true
	_toast.move_to_front()
	_toast_until = Time.get_ticks_msec() + 4500


func _refresh_status() -> void:
	if _status_label == null:
		return
	if state.session_active:
		_status_label.text = "Remote session active — %s" % data.partner_name
	else:
		_status_label.text = "Ready to connect (secure connection)"
	_status_dot.queue_redraw()


func _add_chat(speaker: String, text: String) -> void:
	_chat_history.append([speaker, text])
	if _chat_log:
		_chat_log.add_child(_chat_line(speaker, text))
		_scroll_chat.call_deferred()


func _receive_chat(text: String) -> void:
	_add_chat(data.teacher_name, text)
	if _chat and not _chat.visible:
		# A message pops the chat open, like the real program.
		_chat.visible = true
	_refresh_chat_button()


func _scroll_chat() -> void:
	# The tray below can grow in the same frame (answer buttons), shrinking the
	# log: scroll once the layout has settled so the newest bubble is in view.
	for i in 2:
		if not is_inside_tree():
			return
		await get_tree().process_frame
	if _chat_scroll and is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _refresh_chat_button() -> void:
	if _chat_button:
		_chat_button.text = "Chat" if _chat_unread == 0 else "Chat (%d)" % _chat_unread


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
	_partner_card = _build_partner_card()
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
	# Status line at the bottom, like the real program.
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", RemoteTheme.box(RemoteTheme.PANEL, Color(0, 0, 0, 0), 0, 14, 5))
	column.add_child(foot)
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 8)
	foot.add_child(foot_row)
	_status_dot = Control.new()
	_status_dot.custom_minimum_size = Vector2(14, 14)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot.draw.connect(func(): _status_dot.draw_circle(_status_dot.size * 0.5, 6.0, Color(0.2, 0.75, 0.3)))
	foot_row.add_child(_status_dot)
	_status_label = _label("", 14, RemoteTheme.INK)
	_status_label.name = "StatusLine"
	foot_row.add_child(_status_label)
	var note := _label(data.disclaimer, 12, RemoteTheme.INK_SOFT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
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
	b.draw.connect(func():
		var c := b.size * 0.5
		var color := Color.WHITE if is_close and b.is_hovered() else RemoteTheme.INK
		if is_close:
			RemoteTheme.draw_cross(b, c, 22.0, color, 1.6)
		else:
			b.draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), color, 1.6))
	return b


func _show_view(target: View) -> void:
	view = target
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for n in ["_flyout", "_home_msg", "_start_menu", "_sheet", "_chat", "_chat_log", "_chat_presets", "_chat_button", "_chat_scroll", "_power_menu", "_speaker_button", "_video_status", "_reply_box"]:
		set(n, null)
	match target:
		View.HOME:
			_build_home()
		View.SESSION:
			_build_session()
		View.ENDED:
			_build_ended()
	_refresh_status()


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
	var left := _panel(380)
	row.add_child(left.get_parent())
	left.add_child(_label("Allow Remote Control", 20, RemoteTheme.INK, true))
	left.add_child(_label("Please tell your partner the following ID and\npassword if you would like to allow remote control.", 13, RemoteTheme.INK_SOFT))
	left.add_child(_label("Your ID", 14, RemoteTheme.INK_SOFT))
	left.add_child(_label(data.own_id, 26, RemoteTheme.INK, true))
	left.add_child(_label("Password", 14, RemoteTheme.INK_SOFT))
	left.add_child(_label(data.own_password, 22, RemoteTheme.INK, true))
	var right := _panel(0)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right.get_parent())
	right.add_child(_label("Control Remote Computer", 20, RemoteTheme.INK, true))
	right.add_child(_label("Partner ID", 15, RemoteTheme.INK, true))
	_id_edit = LineEdit.new()
	_id_edit.name = "PartnerIdEdit"
	_id_edit.placeholder_text = "Insert partner ID"
	_id_edit.max_length = 20
	_id_edit.custom_minimum_size = Vector2(0, 42)
	_id_edit.add_theme_font_size_override("font_size", 20)
	_id_edit.text_submitted.connect(func(t): connect_partner(t))
	right.add_child(_id_edit)
	var mode := HBoxContainer.new()
	mode.add_theme_constant_override("separation", 8)
	var radio := CheckBox.new()
	radio.text = "Remote control"
	radio.button_pressed = true
	radio.focus_mode = Control.FOCUS_NONE
	radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode.add_child(radio)
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
	col.add_child(_label("Please enter the password displayed on your partner's screen.", 14, RemoteTheme.INK_SOFT))
	col.add_child(_label("Password", 15, RemoteTheme.INK, true))
	_pw_edit = LineEdit.new()
	_pw_edit.name = "PasswordEdit"
	_pw_edit.secret = true
	_pw_edit.custom_minimum_size = Vector2(0, 42)
	_pw_edit.add_theme_font_size_override("font_size", 20)
	_pw_edit.text_submitted.connect(func(t): log_on(t))
	col.add_child(_pw_edit)
	var show := CheckBox.new()
	show.text = "Show password"
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
	cancel.text = "Cancel"
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
	col.add_child(_label("Opening the desktop of %s ..." % data.partner_name, 15, RemoteTheme.INK_SOFT))
	return col.get_parent().get_parent()


func _build_partner_card() -> Control:
	var col := _card("PartnerGoneCard", 460)
	col.add_child(_label("Session ended", 20, RemoteTheme.INK, true))
	_partner_msg = _label("", 15, RemoteTheme.INK)
	_partner_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_partner_msg)
	var ok := Button.new()
	ok.name = "PartnerGoneOk"
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(120, 40)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	RemoteTheme.primary(ok)
	ok.pressed.connect(_close_overlay)
	col.add_child(ok)
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
		_chat_button = Button.new()
		_chat_button.name = "ChatButton"
		_chat_button.custom_minimum_size = Vector2(110, 36)
		_chat_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_chat_button.focus_mode = Control.FOCUS_NONE
		_chat_button.tooltip_text = "Communicate › Chat"
		_chat_button.pressed.connect(open_chat)
		row.add_child(_chat_button)
		_refresh_chat_button()
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
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 0)
	column.add_child(split)
	var screen := Control.new()
	screen.name = "RemoteDesktop"
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.clip_contents = true
	split.add_child(screen)
	_chat = _build_chat()
	split.add_child(_chat)
	# The teacher's own desktop (playtest 2026-11-24: it was a bare gradient
	# with coloured squares): a drawn dusk landscape, her sticky note and
	# drawn file icons.
	var wallpaper := Control.new()
	wallpaper.name = "Wallpaper"
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.draw.connect(func(): _draw_wallpaper(wallpaper))
	wallpaper.resized.connect(wallpaper.queue_redraw)
	wallpaper.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_flyout.visible = false
			_start_menu.visible = false)
	screen.add_child(wallpaper)
	screen.add_child(_sticky_note())
	var icons := VBoxContainer.new()
	icons.position = Vector2(10, 12)
	icons.add_theme_constant_override("separation", 6)
	screen.add_child(icons)
	icons.add_child(_remote_icon("VideoFile", "video", data.video_file))
	icons.add_child(_remote_icon("PrivateFile", "sheet", data.private_file))
	icons.add_child(_remote_icon("RecycleBin", "bin", "Recycle Bin"))
	screen.add_child(_video_window())
	_sheet = _build_sheet()
	screen.add_child(_sheet)
	screen.add_child(_remote_taskbar())
	_flyout = _build_flyout()
	screen.add_child(_flyout)
	_start_menu = _build_start_menu()
	screen.add_child(_start_menu)
	_refresh_sound()
	_refresh_replies()


## A desktop icon of the remote computer: a click selects it, a double-click opens it.
func _remote_icon(node_name: String, kind: String, caption: String) -> Control:
	var b := Button.new()
	b.name = node_name
	b.flat = true
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 92)
	b.tooltip_text = caption
	b.add_theme_stylebox_override("hover", RemoteTheme.box(Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.22), 4))
	b.add_theme_stylebox_override("pressed", RemoteTheme.box(Color(0.6, 0.8, 1.0, 0.30), Color(0.7, 0.85, 1.0, 0.6), 4))
	b.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.double_click and e.button_index == MOUSE_BUTTON_LEFT:
			open_remote_file(caption))
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var art := Control.new()
	art.name = "Art"
	art.custom_minimum_size = Vector2(48, 48)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(func(): _draw_file_icon(art, kind))
	box.add_child(art)
	var c := _label(caption, 12, Color.WHITE)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(116, 0)
	c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	c.add_theme_constant_override("shadow_offset_x", 1)
	c.add_theme_constant_override("shadow_offset_y", 1)
	c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	c.add_theme_constant_override("outline_size", 2)
	box.add_child(c)
	return b


## File icons drawn in code (no image files, no brand logos), 48 x 48.
## video: a page with a film frame and a play mark; sheet: a page with a
## green header and a grid; bin: a see-through waste bin.
func _draw_file_icon(c: Control, kind: String) -> void:
	var o := Vector2((c.size.x - 48.0) * 0.5, 0)
	if kind == "bin":
		var glass := Color(0.86, 0.92, 0.98, 0.55)
		var rim := Color(0.95, 0.98, 1.0, 0.95)
		var body := PackedVector2Array([o + Vector2(12, 12), o + Vector2(36, 12), o + Vector2(33, 44), o + Vector2(15, 44)])
		c.draw_colored_polygon(body, glass)
		c.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), rim, 1.5, true)
		for x in [19.0, 24.0, 29.0]:
			c.draw_line(o + Vector2(x, 16), o + Vector2(x + (24.0 - x) * 0.12, 40), Color(1, 1, 1, 0.7), 1.2, true)
		c.draw_rect(Rect2(o + Vector2(9, 7), Vector2(30, 5)), rim)
		c.draw_rect(Rect2(o + Vector2(20, 4), Vector2(8, 3)), rim)
		return
	# A page with a folded top-right corner and a soft shadow.
	var page := PackedVector2Array([o + Vector2(9, 3), o + Vector2(31, 3), o + Vector2(40, 12), o + Vector2(40, 45), o + Vector2(9, 45)])
	var shadow := PackedVector2Array()
	for p in page:
		shadow.append(p + Vector2(1.5, 2))
	c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	c.draw_colored_polygon(page, Color(0.99, 0.99, 1.0))
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(31, 3), o + Vector2(40, 12), o + Vector2(31, 12)]), Color(0.80, 0.83, 0.88))
	var font: Font = RemoteTheme.FONT_BOLD
	if kind == "video":
		var frame := Rect2(o + Vector2(12, 15), Vector2(25, 18))
		c.draw_rect(frame, Color(0.12, 0.14, 0.22))
		for i in 4:
			c.draw_rect(Rect2(frame.position + Vector2(2 + i * 6.2, 1.5), Vector2(3, 2)), Color(1, 1, 1, 0.55))
			c.draw_rect(Rect2(frame.position + Vector2(2 + i * 6.2, 14.5), Vector2(3, 2)), Color(1, 1, 1, 0.55))
		var m := frame.get_center()
		c.draw_colored_polygon(PackedVector2Array([m + Vector2(-3.5, -4.5), m + Vector2(5, 0), m + Vector2(-3.5, 4.5)]), Color(1.0, 0.45, 0.38))
		_icon_badge(c, o + Vector2(5, 35), "MP4", Color(0.90, 0.30, 0.28), font)
	else:
		c.draw_rect(Rect2(o + Vector2(12, 14), Vector2(25, 5)), Color(0.13, 0.58, 0.32))
		for row in 4:
			c.draw_line(o + Vector2(12, 22 + row * 4), o + Vector2(37, 22 + row * 4), Color(0.13, 0.58, 0.32, 0.45), 1.0)
		for col in [20.0, 28.0]:
			c.draw_line(o + Vector2(col, 14), o + Vector2(col, 34), Color(0.13, 0.58, 0.32, 0.45), 1.0)
		_icon_badge(c, o + Vector2(5, 35), "XLSX", Color(0.13, 0.55, 0.30), font)


func _icon_badge(c: Control, at: Vector2, text: String, color: Color, font: Font) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 8.0
	c.draw_style_box(RemoteTheme.box(color, Color(0, 0, 0, 0), 3, 0, 0), Rect2(at, Vector2(w, 12)))
	c.draw_string(font, at + Vector2(4, 9.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


## Dusk over hills: a sky gradient, a low sun and three layers of hills.
func _draw_wallpaper(c: Control) -> void:
	var s := c.size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var top := Color(0.16, 0.20, 0.42)
	var mid := Color(0.55, 0.42, 0.62)
	var low := Color(0.98, 0.70, 0.52)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.45), Vector2(0, s.y * 0.45)]), PackedColorArray([top, top, mid, mid]))
	c.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.45), Vector2(s.x, s.y * 0.45), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([mid, mid, low, low]))
	var sun := Vector2(s.x * 0.72, s.y * 0.66)
	for i in 4:
		c.draw_circle(sun, 70.0 - i * 14.0, Color(1.0, 0.86, 0.62, 0.10 + i * 0.06))
	c.draw_circle(sun, 22.0, Color(1.0, 0.93, 0.78))
	var layers := [
		[0.62, 26.0, 0.011, 0.0, Color(0.46, 0.38, 0.58)],
		[0.72, 22.0, 0.008, 1.7, Color(0.33, 0.30, 0.50)],
		[0.84, 18.0, 0.013, 3.1, Color(0.20, 0.22, 0.38)],
	]
	for layer in layers:
		var ridge := PackedVector2Array([Vector2(0, s.y)])
		var x := 0.0
		while x <= s.x + 8.0:
			var y: float = s.y * float(layer[0]) - float(layer[1]) * (sin(x * float(layer[2]) + float(layer[3])) + 0.5 * sin(x * float(layer[2]) * 2.3 + float(layer[3]) * 1.9))
			ridge.append(Vector2(x, y))
			x += 8.0
		ridge.append(Vector2(s.x + 8.0, s.y))
		c.draw_colored_polygon(ridge, layer[4])
	# A few early stars in the top of the sky.
	var stars := [Vector2(0.12, 0.08), Vector2(0.34, 0.15), Vector2(0.58, 0.06), Vector2(0.81, 0.12), Vector2(0.93, 0.27), Vector2(0.47, 0.24)]
	for p: Vector2 in stars:
		c.draw_circle(Vector2(p.x * s.x, p.y * s.y), 1.3, Color(1, 1, 1, 0.65))


## The teacher's reminder stuck on her desktop (top right).
func _sticky_note() -> Control:
	var note := PanelContainer.new()
	note.name = "StickyNote"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.anchor_left = 1.0
	note.anchor_right = 1.0
	note.offset_left = -190
	note.offset_right = -18
	note.offset_top = 16
	note.rotation_degrees = 2.0
	var style := RemoteTheme.box(Color(1.0, 0.93, 0.55), Color(0, 0, 0, 0), 2, 12, 10)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2, 3)
	note.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_child(col)
	col.add_child(_label("วันนี้ 13:00", 15, Color(0.45, 0.30, 0.05), true))
	var body := _label("นำเสนอผลการจัดการเรียนรู้\nที่ห้องประชุมเล็ก", 13, Color(0.35, 0.27, 0.10))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(148, 0)
	col.add_child(body)
	return note


func _video_window() -> Control:
	var win := PanelContainer.new()
	win.name = "VideoWindow"
	win.position = Vector2(150, 18)
	win.custom_minimum_size = Vector2(500, 0)
	win.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.14, 0.15, 0.18), Color(0, 0, 0, 0.5), 6, 0, 0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	win.add_child(col)
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.22, 0.23, 0.27), Color(0, 0, 0, 0), 0, 10, 4))
	title.add_child(_label("%s — Media Player" % data.video_file, 14, Color(0.9, 0.92, 0.95)))
	col.add_child(title)
	var picture := ColorRect.new()
	picture.color = Color(0.05, 0.12, 0.22)
	picture.custom_minimum_size = Vector2(500, 190)
	var caption := _label("นำเสนอผลการจัดการเรียนรู้ — กลุ่มสาระฯ", 20, Color.WHITE, true)
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
	bar.value = 4
	bar.custom_minimum_size = Vector2(0, 6)
	bar.add_theme_stylebox_override("background", RemoteTheme.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 2, 0, 0))
	bar.add_theme_stylebox_override("fill", RemoteTheme.box(Color(0.95, 0.4, 0.35), Color(0, 0, 0, 0), 2, 0, 0))
	line.add_child(bar)
	_video_status = _label("", 14, Color(0.9, 0.92, 0.95))
	_video_status.name = "VideoStatus"
	line.add_child(_video_status)
	return win


## What opens when the private file is double-clicked (a made-up grade sheet).
func _build_sheet() -> PanelContainer:
	var win := PanelContainer.new()
	win.name = "PrivateSheet"
	win.position = Vector2(230, 60)
	win.custom_minimum_size = Vector2(420, 0)
	win.visible = false
	win.add_theme_stylebox_override("panel", RemoteTheme.box(Color(1, 1, 1), Color(0.3, 0.3, 0.3), 4, 0, 0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	win.add_child(col)
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.13, 0.45, 0.27), Color(0, 0, 0, 0), 0, 10, 4))
	var trow := HBoxContainer.new()
	title.add_child(trow)
	var t := _label("%s — Spreadsheet" % data.private_file, 14, Color.WHITE, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(t)
	var x := Button.new()
	x.name = "SheetClose"
	x.text = " X "
	x.flat = true
	x.add_theme_color_override("font_color", Color.WHITE)
	x.pressed.connect(func(): win.visible = false)
	trow.add_child(x)
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_child(grid)
	col.add_child(pad)
	var scores := [17, 12, 19, 8, 15, 14]
	for cell in ["เลขที่", "ชื่อ", "คะแนน (20)"]:
		grid.add_child(_label(cell, 14, RemoteTheme.INK, true))
	for i in scores.size():
		grid.add_child(_label(str(i + 1), 14, RemoteTheme.INK))
		grid.add_child(_label("นักเรียนคนที่ %d" % (i + 1), 14, RemoteTheme.INK))
		grid.add_child(_label(str(scores[i]), 14, RemoteTheme.INK))
	return win


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
	var start := Button.new()
	start.name = "RemoteStart"
	start.text = "Start"
	start.flat = true
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_color_override("font_color", Color.WHITE)
	start.pressed.connect(open_start_menu)
	row.add_child(start)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_speaker_button = Button.new()
	_speaker_button.name = "SpeakerIcon"
	_speaker_button.custom_minimum_size = Vector2(44, 36)
	_speaker_button.focus_mode = Control.FOCUS_NONE
	_speaker_button.tooltip_text = "Speakers"
	_speaker_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_speaker_button.add_theme_stylebox_override("hover", RemoteTheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 4))
	_speaker_button.add_theme_stylebox_override("pressed", RemoteTheme.box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0), 4))
	_speaker_button.pressed.connect(open_volume_flyout)
	var sb := _speaker_button
	sb.draw.connect(func(): RemoteTheme.draw_speaker(sb, sb.size * 0.5, 24.0, Color.WHITE, state.remote_muted))
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
	fly.offset_left = -380
	fly.offset_right = -10
	fly.offset_bottom = -48
	fly.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fly.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.97, 0.97, 0.98), RemoteTheme.BORDER, 8, 18, 14))
	fly.visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	fly.add_child(col)
	col.add_child(_label("Speakers", 16, RemoteTheme.INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_mute_button = Button.new()
	_mute_button.name = "MuteButton"
	_mute_button.custom_minimum_size = Vector2(48, 40)
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.tooltip_text = "Mute / Unmute"
	_mute_button.pressed.connect(toggle_mute)
	var mb := _mute_button
	mb.draw.connect(func(): RemoteTheme.draw_speaker(mb, mb.size * 0.5, 24.0, RemoteTheme.INK, state.remote_muted))
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
	return fly


func _build_start_menu() -> PanelContainer:
	var menu := PanelContainer.new()
	menu.name = "RemoteStartMenu"
	menu.anchor_top = 1.0
	menu.anchor_bottom = 1.0
	menu.offset_left = 8
	menu.offset_right = 300
	menu.offset_bottom = -48
	menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu.visible = false
	menu.add_theme_stylebox_override("panel", RemoteTheme.box(Color(0.97, 0.97, 0.98), RemoteTheme.BORDER, 8, 16, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	menu.add_child(col)
	col.add_child(_label("Pinned", 14, RemoteTheme.INK, true))
	for app in ["Media Player", "File Explorer", "TeamViewer", "Microsoft Edge"]:
		col.add_child(_label("   " + app, 14, RemoteTheme.INK))
	col.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	col.add_child(foot)
	var user := _label(data.teacher_name, 14, RemoteTheme.INK, true)
	user.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(user)
	var power := Button.new()
	power.name = "PowerButton"
	power.text = "Power"
	power.focus_mode = Control.FOCUS_NONE
	power.pressed.connect(func(): _power_menu.visible = not _power_menu.visible)
	foot.add_child(power)
	_power_menu = VBoxContainer.new()
	_power_menu.name = "PowerMenu"
	_power_menu.visible = false
	col.add_child(_power_menu)
	for item in [["PowerSleep", "Sleep", ""], ["PowerShutDown", "Shut down", "shutdown"], ["PowerRestart", "Restart", "restart"]]:
		var b := Button.new()
		b.name = item[0]
		b.text = item[1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var kind: String = item[2]
		if kind == "":
			b.disabled = true # Disabled by the school's policy on meeting-room PCs.
		else:
			b.pressed.connect(func(): remote_power(kind))
		_power_menu.add_child(b)
	return menu


func _build_chat() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ChatPanel"
	panel.custom_minimum_size = Vector2(300, 0)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", RemoteTheme.box(Color(1, 1, 1), RemoteTheme.BORDER, 0, 0, 0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	# Header: her face, name and the machine, like a messenger conversation.
	var head_pad := MarginContainer.new()
	for side in ["left", "right"]:
		head_pad.add_theme_constant_override("margin_" + side, 12)
	head_pad.add_theme_constant_override("margin_top", 8)
	head_pad.add_theme_constant_override("margin_bottom", 8)
	col.add_child(head_pad)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head_pad.add_child(head)
	head.add_child(_chat_avatar(data.teacher_name, 32))
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(who)
	var title := _label(data.teacher_name, 15, RemoteTheme.INK, true)
	title.name = "ChatTitle"
	who.add_child(title)
	who.add_child(_label("Chat · %s" % data.partner_name, 12, RemoteTheme.OK))
	var hide := Button.new()
	hide.name = "ChatHide"
	hide.text = " – "
	hide.flat = true
	hide.focus_mode = Control.FOCUS_NONE
	hide.pressed.connect(func(): panel.visible = false)
	head.add_child(hide)
	var line := ColorRect.new()
	line.color = RemoteTheme.BORDER
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	# The conversation.
	var log_pad := MarginContainer.new()
	log_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		log_pad.add_theme_constant_override("margin_" + side, 10)
	col.add_child(log_pad)
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_pad.add_child(_chat_scroll)
	_chat_log = VBoxContainer.new()
	_chat_log.name = "ChatLog"
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_constant_override("separation", 8)
	# Room on the right so the scroll bar never covers the blue bubbles.
	var log_inset := MarginContainer.new()
	log_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_inset.add_theme_constant_override("margin_right", 14)
	_chat_scroll.add_child(log_inset)
	log_inset.add_child(_chat_log)
	for entry in _chat_history:
		_chat_log.add_child(_chat_line(entry[0], entry[1]))
	# The tray: what the player can send. A grey strip with its own heading,
	# kept apart from the conversation above.
	var tray := PanelContainer.new()
	tray.name = "ChatComposer"
	var tray_style := RemoteTheme.box(CHAT_TRAY, Color(0, 0, 0, 0), 0, 12, 10)
	tray_style.border_color = RemoteTheme.BORDER
	tray_style.border_width_top = 1
	tray.add_theme_stylebox_override("panel", tray_style)
	col.add_child(tray)
	var tray_col := VBoxContainer.new()
	tray_col.add_theme_constant_override("separation", 0)
	tray.add_child(tray_col)
	_reply_box = VBoxContainer.new()
	_reply_box.name = "ReplyBox"
	_reply_box.add_theme_constant_override("separation", 5)
	_reply_box.visible = false
	tray_col.add_child(_reply_box)
	# No free typing: the player picks one of the prepared messages.
	_chat_presets = VBoxContainer.new()
	_chat_presets.name = "ChatPresets"
	_chat_presets.add_theme_constant_override("separation", 5)
	_chat_presets.visible = chat_question == ""
	tray_col.add_child(_chat_presets)
	_chat_presets.add_child(_label("ข้อความด่วน · กดเพื่อส่ง", 12, RemoteTheme.INK_SOFT, true))
	for i in data.chat_presets.size():
		var b := _chat_pill(data.chat_presets[i])
		b.name = "ChatPreset%d" % i
		b.pressed.connect(func(): send_chat(data.chat_presets[i]))
		_chat_presets.add_child(b)
	return panel


## One chat message as a bubble (playtest 2026-11-24: the log and the preset
## buttons looked alike). Hers: grey, on the left under her name with a round
## initial; the player's: blue, on the right.
func _chat_line(speaker: String, text: String) -> Control:
	var mine := speaker == "คุณ"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	if not mine:
		var face := _chat_avatar(speaker, 26)
		face.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	if not mine:
		var who := _label(speaker, 11, RemoteTheme.INK_SOFT)
		col.add_child(who)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", RemoteTheme.box(CHAT_MINE if mine else CHAT_THEIRS, Color(0, 0, 0, 0), 16, 12, 7))
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
	col.add_child(bubble)
	var l := _label(text, 14, Color.WHITE if mine else RemoteTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Short messages get a short bubble; long ones wrap at CHAT_BUBBLE_MAX.
	var shown := GameLocale.text(text)
	var width := RemoteTheme.FONT_REGULAR.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	l.custom_minimum_size = Vector2(minf(ceilf(width) + 2.0, CHAT_BUBBLE_MAX), 0)
	bubble.add_child(l)
	return row


## A round face with the first letter of the name (no photo).
func _chat_avatar(person: String, size: float) -> Control:
	var face := Control.new()
	face.custom_minimum_size = Vector2(size, size)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initial := GameLocale.text(person).left(1)
	face.draw.connect(func():
		var r := size * 0.5
		face.draw_circle(Vector2(r, r), r, CHAT_AVATAR)
		var font: Font = RemoteTheme.FONT_BOLD
		var fs := int(size * 0.5)
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		face.draw_string(font, Vector2(r - w * 0.5, r + fs * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE))
	return face


## A quick-reply pill: white with a blue edge and blue words, so it reads as
## something to press, not as a message already sent.
func _chat_pill(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed"]:
		var s := RemoteTheme.box(Color(1, 1, 1) if state == "normal" else (Color(0.90, 0.95, 1.0) if state == "hover" else Color(0.82, 0.90, 1.0)), CHAT_MINE, 16, 12, 6)
		s.set_border_width_all(2 if state == "hover" else 1)
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, CHAT_MINE.darkened(0.15))
	return b


func _refresh_sound() -> void:
	if _flyout == null:
		return
	_volume_label.text = "%d%%" % state.remote_volume
	var mute_line: Label = _flyout.find_child("MuteState", true, false)
	mute_line.text = "Muted" if state.remote_muted else "Volume %d%%" % state.remote_volume
	_mute_button.queue_redraw()
	if _speaker_button:
		_speaker_button.queue_redraw()
	if _video_status:
		_video_status.text = "Paused — %s" % ("sound OK" if state.teacher_confirmed else "ready to present")


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
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(RemoteTheme.status_icon(true, 26))
	row.add_child(_label("Session ended", 24, RemoteTheme.INK, true))
	col.add_child(row)
	col.add_child(_label("Your remote control session with %s has ended." % data.partner_name, 16, RemoteTheme.INK))
	var back := Button.new()
	back.name = "BackHomeButton"
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 40)
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
