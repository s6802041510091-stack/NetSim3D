class_name FirewallAlerts
extends Control

## The "Windows Security Alert" dialogs of Mission 5 v2.1 (idea 1 in
## ภารกิจ/ด่าน_05/README.md, agreed with the user on 2026-11-15). They come up
## when the player opens Firewall & network protection (the user chose this
## over showing them on the desktop). Two of them, in a fixed order (user:
## SchoolLab first):
##   1. SchoolLab Classroom (the school's program the teacher needs) — right:
##      Allow access with Private networks ticked. Private + Public is accepted
##      with a short note (no harm in real life on a lab desktop).
##   2. Unknown_Update.exe (unknown publisher, in Downloads) — right: Cancel.
## Only the front alert can be answered; while both wait, a second window
## peeks out behind it. A wrong answer is not applied: a Thai hint shows in the
## game's own panel (bottom left, outside the Windows look) and the player
## tries again. Mission05State records every answer for the score.
## Owned by WindowsSecurity (show_alerts()).

signal answered(key: String, answer: String, correct: bool)
signal all_answered

var data: Mission05Data
var state: Mission05State
## The X of the alert hides it until show_again() (Review button / sitting down again).
var dismissed := false

var _back: PanelContainer
var _window: PanelContainer
var _shown := ""
var _private_box: CheckBox
var _public_box: CheckBox
var _hint_panel: PanelContainer
var _hint_title: Label
var _hint_label: Label
var _hint_retry: Label
var _hint := ""
var _note := ""


func setup(mission_data: Mission05Data, mission_state: Mission05State) -> FirewallAlerts:
	data = mission_data
	state = mission_state
	return self


func _ready() -> void:
	name = "FirewallAlerts" if name == "" else name
	theme = SecurityTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if data == null:
		data = load(WindowsSecurity.DATA_PATH) as Mission05Data
	if state == null:
		state = Mission05State.new()
	_build_hint_panel()
	refresh()


# ================================================================ public API

## The alert in front ("school" / "unknown"), "" when both are answered or hidden.
func current_alert() -> String:
	return _shown if _window != null and _window.visible else ""


func alert_visible() -> bool:
	return current_alert() != ""


func current_hint() -> String:
	return _hint


func current_note() -> String:
	return _note


func show_again() -> void:
	dismissed = false
	refresh()


## Answers the front alert: `allow` = Allow access (with the two network boxes),
## otherwise Cancel. Returns true when it is the right answer for that program.
func answer(key: String, allow: bool, private_on: bool = true, public_on: bool = false) -> bool:
	if key == "" or key != state.next_alert():
		return false
	var id := Mission05State.alert_answer(allow, private_on, public_on)
	var right := state.note_alert(key, id)
	if right:
		_hint = ""
		_note = data.school_public_note if id == "allow_both" else ""
		Sound.play("correct")
	else:
		_note = ""
		_hint = _hint_for(key, id)
		Sound.play("wrong")
	answered.emit(key, id, right)
	if right and state.alerts_done():
		all_answered.emit()
	refresh()
	return right


## Clicks the front alert's buttons as the player would (tests): ticks the boxes first.
func press(allow: bool, private_on: bool = true, public_on: bool = false) -> bool:
	if _private_box:
		_private_box.button_pressed = private_on
	if _public_box:
		_public_box.button_pressed = public_on
	return answer(current_alert(), allow, private_on, public_on)


func _hint_for(key: String, id: String) -> String:
	if key == Mission05State.ALERT_SCHOOL:
		return data.school_block_hint if id == "block" else data.school_no_private_hint
	return data.get_firewall_choice("allow").hint


# ================================================================ building

func refresh() -> void:
	var key := state.next_alert()
	if key != _shown or (key != "" and _window == null):
		_rebuild(key)
	var open := key != "" and not dismissed
	if _window:
		_window.visible = open
	if _back:
		_back.visible = open and key == Mission05State.ALERT_SCHOOL
	_refresh_hint()


func _rebuild(key: String) -> void:
	for n in [_window, _back]:
		if n != null and is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	_window = null
	_back = null
	_private_box = null
	_public_box = null
	_shown = key
	if key == "":
		return
	# The second alert peeks out behind the first (Windows stacks them).
	if key == Mission05State.ALERT_SCHOOL:
		_back = _alert_window(Mission05State.ALERT_UNKNOWN, true)
		_back.name = "AlertBehind"
		for side in ["offset_left", "offset_right", "offset_top", "offset_bottom"]:
			_back.set(side, 26.0)
		add_child(_back)
	_window = _alert_window(key, false)
	_window.name = "AlertWindow"
	add_child(_window)
	move_child(_hint_panel, -1)


func _app_info(key: String) -> Array:
	if key == Mission05State.ALERT_SCHOOL:
		return [data.school_app, data.school_publisher, data.school_path]
	return [data.firewall_app, data.firewall_publisher, data.firewall_path]


func _alert_window(key: String, behind: bool) -> PanelContainer:
	var info := _app_info(key)
	var win := PanelContainer.new()
	win.custom_minimum_size = Vector2(560, 0)
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win.grow_vertical = Control.GROW_DIRECTION_BOTH
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE if behind else Control.MOUSE_FILTER_STOP
	var sb := SecurityTheme.box(SecurityTheme.CARD, Color(0.6, 0.6, 0.6), 8, 0, 0)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 18
	win.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	win.add_child(col)
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 34)
	col.add_child(bar)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(12, 0)
	bar.add_child(pad)
	var t := _label("Windows Security Alert", 13, SecurityTheme.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(t)
	if not behind:
		var x := Button.new()
		x.name = "AlertClose"
		x.custom_minimum_size = Vector2(46, 34)
		x.focus_mode = Control.FOCUS_NONE
		x.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var hover := SecurityTheme.box(Color(0.77, 0.17, 0.11), Color(0, 0, 0, 0), 0)
		x.add_theme_stylebox_override("hover", hover)
		x.add_theme_stylebox_override("pressed", hover)
		x.draw.connect(func(): SecurityTheme.draw_cross(x, x.size * 0.5, 16.0, Color.WHITE if x.is_hovered() else SecurityTheme.INK, 1.0))
		x.pressed.connect(func():
			dismissed = true
			refresh())
		bar.add_child(x)
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 22)
	body.add_theme_constant_override("margin_top", 8)
	body.add_theme_constant_override("margin_bottom", 16)
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	body.add_child(inner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	inner.add_child(head)
	var shield := Control.new()
	shield.custom_minimum_size = Vector2(40, 40)
	shield.draw.connect(func():
		SecurityTheme.draw_shield(shield, shield.size * 0.5, 38.0, SecurityTheme.ACCENT)
		SecurityTheme.draw_badge(shield, "warn", shield.size * 0.5 + Vector2(10, 10), 18.0))
	head.add_child(shield)
	var h := _label("Windows Defender Firewall has blocked some features of this app", 18, SecurityTheme.INK, true)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	var d := _label("Windows Defender Firewall has blocked some features of %s on all public and private networks." % info[0], 14, SecurityTheme.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(d)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	for pair in [["Name:", info[0]], ["Publisher:", info[1]], ["Path:", info[2]]]:
		grid.add_child(_label(pair[0], 14, SecurityTheme.INK_SOFT))
		var v := _label(pair[1], 14, SecurityTheme.INK)
		if not behind:
			v.name = "Info_" + String(pair[0]).trim_suffix(":")
		grid.add_child(v)
	inner.add_child(grid)
	inner.add_child(_label("Allow %s to communicate on these networks:" % info[0], 14, SecurityTheme.INK))
	# Real Windows ticks Private networks by default.
	var priv := CheckBox.new()
	priv.name = "PrivateBox"
	priv.text = "Private networks, such as my home or work network"
	priv.button_pressed = true
	priv.focus_mode = Control.FOCUS_NONE
	inner.add_child(priv)
	var pub := CheckBox.new()
	pub.name = "PublicBox"
	pub.text = "Public networks, such as those in airports and coffee shops (not\nrecommended because these networks often have little or no security)"
	pub.button_pressed = false
	pub.focus_mode = Control.FOCUS_NONE
	inner.add_child(pub)
	var risk := Button.new()
	risk.text = "What are the risks of allowing an app through a firewall?"
	risk.focus_mode = Control.FOCUS_NONE
	SecurityTheme.style_link(risk)
	inner.add_child(risk)
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.BG, Color(0, 0, 0, 0), 0, 16, 12))
	col.add_child(foot)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	foot.add_child(buttons)
	var allow := Button.new()
	allow.name = "AllowAccessButton"
	# The shield: allowing needs administrator rights (the player has them).
	allow.text = "      " + data.get_firewall_choice("allow").label
	allow.custom_minimum_size = Vector2(150, 32)
	allow.focus_mode = Control.FOCUS_NONE
	SecurityTheme.style_accent(allow)
	allow.draw.connect(func(): _draw_admin_shield(allow))
	buttons.add_child(allow)
	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = data.get_firewall_choice("block").label
	cancel.custom_minimum_size = Vector2(110, 32)
	cancel.focus_mode = Control.FOCUS_NONE
	buttons.add_child(cancel)
	if behind:
		for b: Button in [allow, cancel, risk]:
			b.disabled = true
		priv.disabled = true
		pub.disabled = true
	else:
		_private_box = priv
		_public_box = pub
		allow.pressed.connect(func(): answer(key, true, priv.button_pressed, pub.button_pressed))
		cancel.pressed.connect(func(): answer(key, false, priv.button_pressed, pub.button_pressed))
	return win


## The blue/yellow UAC shield on "Allow access" (drawn, no Microsoft artwork).
static func _draw_admin_shield(b: Button) -> void:
	var c := Vector2(20, b.size.y * 0.5)
	var left := PackedVector2Array([c + Vector2(0, -7), c + Vector2(-6, -5), c + Vector2(-6, 1), c + Vector2(0, 7)])
	var right := PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, -5), c + Vector2(6, 1), c + Vector2(0, 7)])
	b.draw_colored_polygon(left, Color(0.25, 0.55, 0.95))
	b.draw_colored_polygon(right, Color(1.0, 0.8, 0.2))


# ================================================================ game panel (Thai)

func _build_hint_panel() -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "AlertHintPanel"
	_hint_panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.07, 0.09, 0.13, 0.94), Color(1.0, 0.76, 0.2, 0.9), 8, 16, 10))
	_hint_panel.anchor_left = 0.0
	_hint_panel.anchor_right = 0.0
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left = 10
	_hint_panel.offset_right = 360
	_hint_panel.offset_top = -170
	_hint_panel.offset_bottom = -60
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.visible = false
	add_child(_hint_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_hint_panel.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_hint_title = GameUI.label("คำใบ้", 14, Color(1.0, 0.8, 0.35), true)
	col.add_child(_hint_title)
	_hint_label = GameUI.label("", 16, Color.WHITE)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint_label)
	_hint_retry = GameUI.label("ลองเลือกใหม่อีกครั้ง", 13, Color(0.75, 0.8, 0.9))
	col.add_child(_hint_retry)
	var hide := Button.new()
	hide.name = "AlertHintClose"
	hide.text = " x "
	hide.flat = true
	hide.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hide.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	hide.pressed.connect(func():
		_hint = ""
		_note = ""
		_refresh_hint())
	row.add_child(hide)


func _refresh_hint() -> void:
	if _hint_panel == null:
		return
	var text := _hint if _hint != "" else _note
	_hint_panel.visible = text != ""
	_hint_label.text = text
	_hint_title.text = "คำใบ้" if _hint != "" else "หมายเหตุ"
	_hint_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35) if _hint != "" else Color(0.55, 0.78, 1.0))
	_hint_retry.visible = _hint != ""


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", SecurityTheme.FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
