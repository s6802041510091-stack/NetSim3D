class_name WindowsSecurity
extends PanelContainer

## Windows Security (simulated, for teaching) — the only program in Mission 5.
##
##   Home      red "ต้องดำเนินการ" until both parts are fixed, then
##             "Security status: Protected" and the "ส่งผลการตรวจสอบ" button.
##   Firewall  an unknown program asks to connect: allow / block / turn the
##             firewall off. Only "block" is right.
##   Virus     scan (a few seconds), one high-risk file is found:
##             quarantine / allow / add exclusion. Only "quarantine" is right.
##
## A wrong choice shows a hint (never the answer), costs points, and the player
## picks again. Nothing here touches the real computer: no real Windows Security,
## no real scan and no real harmful file — every name is made up for the game.
##
## data    -> Mission05Data   (data/missions/mission_05/mission_05_data.tres)
## progress-> Mission05State  saved by Mission05SaveStore
## Runs on the simulated desktop: DesktopOS.open_windows_security().

signal firewall_choice_made(choice_id: String, correct: bool)
signal scan_started
signal scan_finished(threats_found: int)
signal threat_choice_made(choice_id: String, correct: bool)
signal mistake_made(hint: String, penalty: int)
## Both parts fixed: Security status is Protected.
signal protected_reached
## "ส่งผลการตรวจสอบ" pressed. The mission system listens to this.
signal report_submitted(score: int, wrong_count: int)
## Asks the desktop to switch the computer off (player goes back to first person).
signal computer_exit_requested
signal close_requested
signal minimize_requested

const DATA_PATH := "res://data/missions/mission_05/mission_05_data.tres"

enum Page { HOME, FIREWALL, VIRUS }

## Made-up paths shown while the scan runs.
const SCAN_PATHS := [
	"C:\\Windows\\System32\\drivers",
	"C:\\Program Files\\School Apps",
	"C:\\Users\\Student\\Documents",
	"C:\\Users\\Student\\Downloads",
	"C:\\Users\\Student\\Desktop",
	"C:\\Users\\Public\\Pictures",
]

@export var data: Mission05Data
## Load and save progress with Mission05SaveStore. Tests turn this off.
@export var use_save_file: bool = true
## Handle Esc here. Inside DesktopOS the desktop calls handle_escape() instead;
## when this scene runs on its own (F6) it is switched on automatically.
@export var handle_escape_itself: bool = false
## Seconds between pressing "ส่งผลการตรวจสอบ" and leaving the computer.
@export var exit_delay: float = 1.8

var state: Mission05State = Mission05State.new()
var page: Page = Page.HOME
var scanning: bool = false
var scan_progress: float = 0.0

var _hint := {"page": -1, "text": ""}
var _content: VBoxContainer
var _nav := {}
var _score_label: Label
var _scan_bar: ProgressBar
var _scan_count: Label
var _scan_path: Label
var _exit_timer: SceneTreeTimer


func _ready() -> void:
	theme = SecurityTheme.build()
	if data == null:
		data = load(DATA_PATH) as Mission05Data
	var problem := data.validate_data()
	if problem != "":
		push_error("Windows Security (Mission 5): " + problem)
	if get_tree().current_scene == self:
		handle_escape_itself = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if use_save_file:
		Mission05SaveStore.load_into(state, data)
	else:
		state.reset(data)
	if not state.app_opened:
		state.app_opened = true
		_save()
	add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.BG, SecurityTheme.BORDER, 0, 0, 0))
	_build_frame()
	open_page(Page.HOME)


func _process(delta: float) -> void:
	if not scanning:
		return
	scan_progress = minf(1.0, scan_progress + delta / maxf(0.1, data.scan_seconds))
	if is_instance_valid(_scan_bar):
		_scan_bar.value = scan_progress * 100.0
		_scan_count.text = "ตรวจสอบแล้ว %s ไฟล์" % _thousands(int(scan_progress * 48213))
		_scan_path.text = SCAN_PATHS[int(scan_progress * 23) % SCAN_PATHS.size()]
	if scan_progress >= 1.0:
		_finish_scan()


func _unhandled_input(event: InputEvent) -> void:
	if handle_escape_itself and visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		handle_escape()


# ================================================================ public API

## Esc closes the program (it has no pop-ups). Returns true when used.
func handle_escape() -> bool:
	if not visible:
		return false
	close_program()
	return true


func close_program() -> void:
	scanning = false
	close_requested.emit()


func open_page(target: Page) -> void:
	page = target
	_refresh()


func is_protected() -> bool:
	return state.is_protected()


## Firewall answer. Returns true when it was the right one (block).
func choose_firewall(choice_id: String) -> bool:
	if state.firewall_blocked:
		return false
	var choice := data.get_firewall_choice(choice_id)
	if choice == null:
		return false
	firewall_choice_made.emit(choice_id, choice.is_correct)
	if choice.is_correct:
		state.firewall_blocked = true
		_clear_hint()
		_after_fix()
	else:
		_wrong("firewall", choice, Page.FIREWALL)
	_refresh()
	return choice.is_correct


## Starts the simulated scan. Returns false if it is already running or done.
func start_scan() -> bool:
	if scanning or state.scan_status == Mission05State.ScanStatus.SCANNED:
		return false
	scanning = true
	scan_progress = 0.0
	page = Page.VIRUS
	scan_started.emit()
	_refresh()
	return true


## Anti-Virus answer for the file the scan found. True when right (quarantine).
func choose_threat(choice_id: String) -> bool:
	if state.scan_status != Mission05State.ScanStatus.SCANNED or state.threat_quarantined:
		return false
	var choice := data.get_threat_choice(choice_id)
	if choice == null:
		return false
	threat_choice_made.emit(choice_id, choice.is_correct)
	if choice.is_correct:
		state.threat_quarantined = true
		_clear_hint()
		_after_fix()
	else:
		_wrong("threat", choice, Page.VIRUS)
	_refresh()
	return choice.is_correct


## "ส่งผลการตรวจสอบ". Only works once the computer is Protected.
func submit_report() -> bool:
	if not state.is_protected() or state.report_submitted:
		return false
	state.report_submitted = true
	_save()
	page = Page.HOME
	_refresh()
	report_submitted.emit(state.score, state.wrong_count())
	_exit_timer = get_tree().create_timer(exit_delay)
	_exit_timer.timeout.connect(func():
		if is_inside_tree():
			computer_exit_requested.emit())
	return true


func current_hint() -> String:
	return _hint.text if _hint.page == page else ""


# ================================================================ state changes

func _wrong(part: String, choice: SecurityChoice, on_page: Page) -> void:
	state.add_wrong(part, choice.choice_id, data.penalty_per_wrong)
	_hint = {"page": on_page, "text": choice.hint}
	_save()
	mistake_made.emit(choice.hint, data.penalty_per_wrong)


func _clear_hint() -> void:
	_hint = {"page": -1, "text": ""}


func _after_fix() -> void:
	_save()
	if state.is_protected():
		protected_reached.emit()


func _finish_scan() -> void:
	scanning = false
	state.scan_status = Mission05State.ScanStatus.SCANNED
	_save()
	scan_finished.emit(1)
	_refresh()


func _save() -> void:
	if use_save_file:
		Mission05SaveStore.save(state)


# ================================================================ frame

func _build_frame() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	column.add_child(_title_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	body.add_child(_sidebar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	margin.add_child(_content)


func _title_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "TitleBar"
	bar.custom_minimum_size = Vector2(0, 40)
	bar.add_theme_stylebox_override("panel", SecurityTheme.box(Color(0.93, 0.94, 0.96), Color(0, 0, 0, 0), 0, 10, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(26, 26)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.draw.connect(func(): SecurityTheme.draw_shield(logo, logo.size * 0.5, 24.0, SecurityTheme.ACCENT))
	row.add_child(logo)
	var title := _label(data.app_name, 16, SecurityTheme.INK, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var note := _label("(%s)" % data.app_note, 14, SecurityTheme.INK_SOFT)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	row.add_child(_window_button("MinimizeButton", "min", func(): minimize_requested.emit()))
	row.add_child(_window_button("CloseButton", "close", close_program))
	return bar


func _window_button(node_name: String, kind: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(44, 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := SecurityTheme.box(Color(0.76, 0.15, 0.15) if kind == "close" else Color(0, 0, 0, 0.08), Color(0, 0, 0, 0), 0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	b.draw.connect(func():
		var c := b.size * 0.5
		var color := Color.WHITE if kind == "close" and b.is_hovered() else SecurityTheme.INK
		if kind == "close":
			SecurityTheme.draw_cross(b, c, 22.0, color, 1.6)
		else:
			b.draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), color, 1.6))
	return b


func _sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Sidebar"
	panel.custom_minimum_size = Vector2(290, 0)
	panel.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.SIDEBAR, Color(0, 0, 0, 0), 0, 8, 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	for item in [[Page.HOME, "หน้าแรก"], [Page.FIREWALL, "Firewall & network protection"], [Page.VIRUS, "Virus & threat protection"]]:
		col.add_child(_nav_item(item[0], item[1]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_score_label = _label("", 16, SecurityTheme.INK, true)
	_score_label.name = "ScoreLabel"
	col.add_child(_score_label)
	var disclaimer := _label(data.disclaimer, 12, SecurityTheme.INK_SOFT)
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disclaimer.custom_minimum_size = Vector2(270, 0)
	col.add_child(disclaimer)
	return panel


func _nav_item(target: Page, text: String) -> Button:
	var b := Button.new()
	b.name = "Nav_%s" % Page.keys()[target]
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 42)
	# Room on the left for the status dot.
	b.add_theme_stylebox_override("normal", SecurityTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 36, 6))
	b.add_theme_stylebox_override("hover", SecurityTheme.box(Color(0, 0, 0, 0.05), Color(0, 0, 0, 0), 4, 36, 6))
	b.add_theme_stylebox_override("pressed", SecurityTheme.box(Color(0, 0, 0, 0.08), Color(0, 0, 0, 0), 4, 36, 6))
	b.pressed.connect(func(): open_page(target))
	b.draw.connect(func():
		if page == target:
			b.draw_rect(Rect2(0, 8, 4, b.size.y - 16), SecurityTheme.ACCENT)
		b.draw_circle(Vector2(20, b.size.y * 0.5), 6.0, _page_color(target)))
	_nav[target] = b
	return b


## Colour of the status dot for each page.
func _page_color(target: Page) -> Color:
	match target:
		Page.FIREWALL:
			return SecurityTheme.OK if state.firewall_blocked else SecurityTheme.DANGER
		Page.VIRUS:
			if state.threat_quarantined:
				return SecurityTheme.OK
			return SecurityTheme.DANGER if state.scan_status == Mission05State.ScanStatus.SCANNED else SecurityTheme.WARNING
	return SecurityTheme.OK if state.is_protected() else SecurityTheme.DANGER


# ================================================================ pages

func _refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_scan_bar = null
	match page:
		Page.HOME:
			_page_home()
		Page.FIREWALL:
			_page_firewall()
		Page.VIRUS:
			_page_virus()
	_score_label.text = "คะแนนภารกิจ  %d / %d" % [state.score, data.start_score]
	for b in _nav.values():
		b.add_theme_color_override("font_color", SecurityTheme.ACCENT if b == _nav[page] else SecurityTheme.INK)
		b.queue_redraw()


func _page_home() -> void:
	_heading("ความปลอดภัยโดยรวม", "ภาพรวมการป้องกันของคอมพิวเตอร์เครื่องนี้")
	var safe := state.is_protected()
	var issues := int(not state.firewall_blocked) + int(not state.threat_quarantined)

	var hero := PanelContainer.new()
	hero.name = "StatusHero"
	hero.add_theme_stylebox_override("panel", SecurityTheme.status_box(SecurityTheme.OK_BG if safe else SecurityTheme.DANGER_BG, SecurityTheme.OK if safe else SecurityTheme.DANGER))
	_content.add_child(hero)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	hero.add_child(row)
	var shield := Control.new()
	shield.custom_minimum_size = Vector2(64, 64)
	shield.draw.connect(func(): SecurityTheme.draw_shield(shield, shield.size * 0.5, 60.0, SecurityTheme.OK if safe else SecurityTheme.DANGER, "check" if safe else "alert"))
	row.add_child(shield)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if safe:
		text.add_child(_label("Security status: Protected", 26, SecurityTheme.OK, true))
		text.add_child(_label("คอมพิวเตอร์เครื่องนี้ได้รับการป้องกันแล้ว", 16, SecurityTheme.INK_SOFT))
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		for line in ["Firewall is active", "Unauthorized connection blocked", "Virus scan completed", "Threat quarantined"]:
			list.add_child(_icon_row("check", SecurityTheme.OK, line, SecurityTheme.INK))
		text.add_child(list)
	else:
		text.add_child(_label("ต้องดำเนินการ", 26, SecurityTheme.DANGER, true))
		text.add_child(_label("พบปัญหาด้านความปลอดภัย %d รายการ — เปิดแต่ละเมนูเพื่อตรวจสอบและแก้ไข" % issues, 16, SecurityTheme.INK))

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	_content.add_child(tiles)
	var fw_text := data.firewall_done_message if state.firewall_blocked else "ต้องดำเนินการ: มีโปรแกรมขอเชื่อมต่อเครือข่าย"
	tiles.add_child(_tile("TileFirewall", "Firewall & network protection", fw_text, _page_color(Page.FIREWALL), Page.FIREWALL))
	var av_text := "ยังไม่ได้ตรวจสอบเครื่องในวันนี้"
	if state.threat_quarantined:
		av_text = data.threat_done_message
	elif state.scan_status == Mission05State.ScanStatus.SCANNED:
		av_text = "ต้องดำเนินการ: Threats found: 1"
	tiles.add_child(_tile("TileVirus", "Virus & threat protection", av_text, _page_color(Page.VIRUS), Page.VIRUS))

	var submit := Button.new()
	submit.name = "SubmitButton"
	submit.text = data.submit_button_text
	submit.custom_minimum_size = Vector2(260, 46)
	submit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	submit.disabled = not safe or state.report_submitted
	if not submit.disabled:
		_style_primary(submit)
	submit.pressed.connect(submit_report)
	_content.add_child(submit)
	if state.report_submitted:
		var done := _label(data.submitted_message, 16, SecurityTheme.OK, true)
		done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(done)
	elif not safe:
		_content.add_child(_label("ต้องดำเนินการทั้ง Firewall และ Anti-Virus ให้ถูกต้องก่อน จึงจะส่งผลการตรวจสอบได้", 14, SecurityTheme.INK_SOFT))


func _page_firewall() -> void:
	_heading("Firewall & network protection", "ควบคุมว่าโปรแกรมใดเชื่อมต่อผ่านเครือข่ายได้")
	if not state.firewall_blocked:
		var alert := _card(SecurityTheme.DANGER_BG, SecurityTheme.DANGER, "FirewallAlert")
		alert.add_child(_icon_row("alert", SecurityTheme.DANGER, data.firewall_alert, SecurityTheme.DANGER, 20, true))
		alert.add_child(_details(data.firewall_details))
		_hint_card() # Above the buttons so it is seen without scrolling.
		_content.add_child(_label("เลือกวิธีดำเนินการ", 18, SecurityTheme.INK, true))
		_choices("FirewallChoices", data.firewall_choices, choose_firewall)
		return

	var done := _card(SecurityTheme.OK_BG, SecurityTheme.OK, "FirewallDone")
	done.add_child(_icon_row("check", SecurityTheme.OK, data.firewall_done_message, SecurityTheme.OK, 22, true))
	done.add_child(_blocked_diagram())
	var details := data.firewall_details.duplicate()
	details["Status"] = "Blocked"
	done.add_child(_details(details))
	done.add_child(_icon_row("check", SecurityTheme.OK, "Firewall is active", SecurityTheme.INK))
	_reason(data.firewall_reason)


func _page_virus() -> void:
	_heading("Virus & threat protection", "ตรวจหาและจัดการไฟล์อันตรายในคอมพิวเตอร์")
	if scanning:
		var card := _card(SecurityTheme.INFO_BG, SecurityTheme.ACCENT, "ScanProgress")
		card.add_child(_label("กำลังสแกน (Quick scan)...", 20, SecurityTheme.ACCENT, true))
		_scan_bar = ProgressBar.new()
		_scan_bar.name = "ScanBar"
		_scan_bar.custom_minimum_size = Vector2(0, 14)
		_scan_bar.show_percentage = false
		_scan_bar.value = scan_progress * 100.0
		card.add_child(_scan_bar)
		_scan_count = _label("", 15, SecurityTheme.INK)
		card.add_child(_scan_count)
		_scan_path = _label("", 14, SecurityTheme.INK_SOFT)
		card.add_child(_scan_path)
		return

	if state.scan_status == Mission05State.ScanStatus.NOT_SCANNED:
		var card := _card(SecurityTheme.WARNING_BG, SecurityTheme.WARNING, "NotScanned")
		card.add_child(_icon_row("alert", SecurityTheme.WARNING, "ยังไม่ได้ตรวจสอบเครื่องในวันนี้", SecurityTheme.INK, 20, true))
		card.add_child(_label("ภัยคุกคามปัจจุบัน: ยังไม่ทราบ — ต้องสแกนก่อน", 15, SecurityTheme.INK_SOFT))
		var scan := Button.new()
		scan.name = "ScanButton"
		scan.text = "Scan (สแกนด่วน)"
		scan.custom_minimum_size = Vector2(220, 44)
		scan.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_style_primary(scan)
		scan.pressed.connect(start_scan)
		card.add_child(scan)
		return

	if not state.threat_quarantined:
		var found := _card(SecurityTheme.DANGER_BG, SecurityTheme.DANGER, "ThreatFound")
		found.add_child(_icon_row("alert", SecurityTheme.DANGER, "Threats found: 1", SecurityTheme.DANGER, 20, true))
		found.add_child(_details({"File": data.threat_file, "Risk level": data.threat_risk, "Status": "Action required"}, {"Risk level": SecurityTheme.DANGER}))
		_hint_card()
		_content.add_child(_label("เลือกวิธีจัดการไฟล์นี้", 18, SecurityTheme.INK, true))
		_choices("ThreatChoices", data.threat_choices, choose_threat)
		return

	var done := _card(SecurityTheme.OK_BG, SecurityTheme.OK, "ThreatDone")
	done.add_child(_icon_row("check", SecurityTheme.OK, data.threat_done_message, SecurityTheme.OK, 22, true))
	done.add_child(_details({"Threats found": "1", "ภัยคุกคามที่กำลังทำงาน": "0", "Virus scan": "Completed"}))
	var quarantine := _card(Color(1, 1, 1), SecurityTheme.BORDER, "QuarantineList")
	quarantine.add_child(_label("พื้นที่กักกัน (Quarantine)", 16, SecurityTheme.INK, true))
	quarantine.add_child(_details({data.threat_file: "Quarantined — ไฟล์ทำงานไม่ได้"}))
	_reason(data.threat_reason)


# ================================================================ widgets

func _heading(title: String, subtitle: String) -> void:
	_content.add_child(_label(title, 26, SecurityTheme.INK, true))
	_content.add_child(_label(subtitle, 15, SecurityTheme.INK_SOFT))


func _card(bg: Color, strip: Color, node_name: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.add_theme_stylebox_override("panel", SecurityTheme.status_box(bg, strip))
	_content.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	return col


func _icon_row(kind: String, color: Color, text: String, text_color: Color, size: float = 18.0, bold: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(SecurityTheme.icon(kind, color, size))
	var l := _label(text, 18 if bold else 16, text_color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _details(rows: Dictionary, colors: Dictionary = {}) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	for key in rows:
		grid.add_child(_label(str(key), 15, SecurityTheme.INK_SOFT))
		grid.add_child(_label(str(rows[key]), 15, colors.get(key, SecurityTheme.INK), colors.has(key)))
	return grid


func _choices(node_name: String, list: Array[SecurityChoice], action: Callable) -> void:
	var col := VBoxContainer.new()
	col.name = node_name
	col.add_theme_constant_override("separation", 8)
	_content.add_child(col)
	for choice in list:
		var b := Button.new()
		b.name = "Choice_" + choice.choice_id
		b.custom_minimum_size = Vector2(0, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): action.call(choice.choice_id))
		var text := VBoxContainer.new()
		text.set_anchors_preset(Control.PRESET_FULL_RECT)
		text.offset_left = 16
		text.offset_top = 6
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_constant_override("separation", 0)
		b.add_child(text)
		text.add_child(_label(choice.label, 17, SecurityTheme.INK, true))
		text.add_child(_label(choice.description, 14, SecurityTheme.INK_SOFT))
		col.add_child(b)


func _hint_card() -> void:
	var hint := current_hint()
	if hint == "":
		return
	var card := _card(SecurityTheme.WARNING_BG, SecurityTheme.WARNING, "HintCard")
	card.add_child(_icon_row("alert", SecurityTheme.WARNING, "คำใบ้: " + hint, SecurityTheme.INK, 20, true))
	card.add_child(_label("ลองเลือกใหม่อีกครั้ง  (−%d คะแนน)" % data.penalty_per_wrong, 14, SecurityTheme.DANGER))


func _reason(text: String) -> void:
	if text.strip_edges() == "":
		return
	var card := _card(SecurityTheme.INFO_BG, SecurityTheme.ACCENT, "Reason")
	var l := _label("เหตุผล: " + text, 15, SecurityTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(l)


## Internet -> blocked by the firewall -> this computer.
func _blocked_diagram() -> Control:
	var d := Control.new()
	d.name = "BlockedDiagram"
	d.custom_minimum_size = Vector2(0, 92)
	d.draw.connect(func():
		var w := d.size.x
		var y := 46.0
		var font := SecurityTheme.FONT_REGULAR
		var left := Rect2(10, y - 26, 190, 52)
		var right := Rect2(minf(w - 200, 560), y - 26, 190, 52)
		d.draw_rect(left, Color(1, 1, 1))
		d.draw_rect(left, SecurityTheme.BORDER, false, 1.0)
		d.draw_string(font, left.position + Vector2(10, 22), "Unknown_Update.exe", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SecurityTheme.INK)
		d.draw_string(font, left.position + Vector2(10, 42), "Incoming connection", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SecurityTheme.INK_SOFT)
		d.draw_rect(right, Color(1, 1, 1))
		d.draw_rect(right, SecurityTheme.BORDER, false, 1.0)
		d.draw_string(font, right.position + Vector2(10, 22), "คอมพิวเตอร์เครื่องนี้", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SecurityTheme.INK)
		d.draw_string(font, right.position + Vector2(10, 42), "Firewall: Active", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SecurityTheme.OK)
		var mid := (left.end.x + right.position.x) * 0.5
		d.draw_dashed_line(Vector2(left.end.x, y), Vector2(mid - 22, y), SecurityTheme.DANGER, 2.0, 7.0)
		d.draw_line(Vector2(mid + 22, y), Vector2(right.position.x, y), Color(SecurityTheme.INK_SOFT, 0.4), 2.0)
		SecurityTheme.draw_shield(d, Vector2(mid, y), 40.0, SecurityTheme.OK)
		SecurityTheme.draw_cross(d, Vector2(mid, y - 2), 26.0, Color.WHITE, 3.0)
		d.draw_string(font, Vector2(mid - 30, y + 40), "Blocked", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SecurityTheme.DANGER))
	return d


func _tile(node_name: String, title: String, status: String, color: Color, target: Page) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(320, 110)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): open_page(target))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -12
	col.offset_top = 12
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	b.add_child(col)
	col.add_child(_label(title, 17, SecurityTheme.INK, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(SecurityTheme.icon("check" if color == SecurityTheme.OK else "alert", color, 18))
	var l := _label(status, 15, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	col.add_child(row)
	col.add_child(_label("คลิกเพื่อเปิด", 13, SecurityTheme.ACCENT))
	return b


func _style_primary(b: Button) -> void:
	var s := SecurityTheme.box(SecurityTheme.ACCENT, SecurityTheme.ACCENT.darkened(0.2), 4, 16, 8)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = SecurityTheme.ACCENT.lightened(0.12)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_font_override("font", SecurityTheme.FONT_BOLD)
	b.add_theme_font_size_override("font_size", 17)


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", SecurityTheme.FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
