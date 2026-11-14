class_name WindowsSecurity
extends PanelContainer

## Windows Security (simulated, for teaching) — the only program in Mission 5.
## Looks and works like the Windows 11 program, in English (user, 2026-11-13):
##
##   Home      "Security at a glance": tiles with status badges. Before the
##             fix both Firewall and Virus show "Actions recommended".
##   Sidebar   Home, Virus & threat protection, Account protection, Firewall &
##             network protection, App & browser control, Device security,
##             Device performance & health, Family options, Protection
##             history, Settings. The first section the player opens for each
##             problem is a decision (Mission05State.note_section).
##   Firewall  network profiles (Domain / Private (active) / Public). Opening
##             the page brings up the two "Windows Security Alert" dialogs
##             (FirewallAlerts: SchoolLab Classroom first, then
##             Unknown_Update.exe — user 2026-11-15); a banner with "Review"
##             stays until both are answered. "Allow an app through firewall"
##             lists the rules (checking them is a process point). Switching
##             the firewall off on a profile page is wrong (it switches back on).
##   Virus     Quick scan (a few seconds, only after the alerts), one threat
##             found with two affected files: Remove / Quarantine / Allow on
##             device + "Start actions". Settings: Real-time protection switch
##             (off = wrong), Exclusions -> Add an exclusion -> File (wrong).
##   History   after the quarantine: the entry that confirms it (opening it
##             before the report is a process point).
##
## A wrong answer is not applied: the game shows a Thai hint (never the
## answer) in its own panel, outside the Windows look, and the player tries
## again. "ส่งผลการตรวจสอบ" is also a game panel. Mission05State records
## everything for the 30/50/20 score. Nothing here touches the real computer:
## no real Windows Security, no real scan, no real harmful file — every name
## is made up for the game. No Microsoft artwork: every icon is drawn in code.
##
## data    -> Mission05Data   (missions/mission_05/data/mission_05_data.tres)
## progress-> Mission05State  (shared_state, owned by Mission05Controller for
##            one play of the level; the program may be closed and opened again)
## Runs on the simulated desktop: DesktopOS.open_windows_security().

## An alert answered (allow_private / allow_both / allow_public / allow_none /
## block) or the firewall switch turned off ("disable").
signal firewall_choice_made(choice_id: String, correct: bool)
signal scan_started
signal scan_finished(threats_found: int)
signal threat_choice_made(choice_id: String, correct: bool)
## A sidebar section / page was opened ("firewall", "virus", "account", ...).
signal section_opened(section: String)
signal mistake_made(hint: String)
## Both parts fixed: every tile is green.
signal protected_reached
## "ส่งผลการตรวจสอบ" accepted (Protected). The mission system listens to this.
signal report_submitted
## Asks the desktop to switch the computer off (player goes back to first person).
signal computer_exit_requested
signal close_requested
signal minimize_requested

const DATA_PATH := "res://missions/mission_05/data/mission_05_data.tres"

enum Page { HOME, VIRUS, ACCOUNT, FIREWALL, APP, DEVICE, HEALTH, FAMILY, HISTORY, SETTINGS, FW_PROFILE, AV_SETTINGS, EXCLUSIONS, ALLOWED_APPS }

## Sidebar: page, glyph, title.
const NAV := [
	[Page.HOME, "home", "Home"],
	[Page.VIRUS, "virus", "Virus & threat protection"],
	[Page.ACCOUNT, "account", "Account protection"],
	[Page.FIREWALL, "firewall", "Firewall & network protection"],
	[Page.APP, "app", "App & browser control"],
	[Page.DEVICE, "device", "Device security"],
	[Page.HEALTH, "health", "Device performance & health"],
	[Page.FAMILY, "family", "Family options"],
	[Page.HISTORY, "history", "Protection history"],
]
## Which section each page belongs to (for the decisions).
const SECTION := {
	Page.HOME: "home", Page.VIRUS: "virus", Page.ACCOUNT: "account", Page.FIREWALL: "firewall",
	Page.APP: "app", Page.DEVICE: "device", Page.HEALTH: "health", Page.FAMILY: "family",
	Page.HISTORY: "history", Page.SETTINGS: "settings", Page.FW_PROFILE: "firewall",
	Page.AV_SETTINGS: "virus", Page.EXCLUSIONS: "virus",
	Page.ALLOWED_APPS: Mission05State.TOOL_RULES,
}
## Built-in rules shown on "Allow an app through firewall" (name, private, public).
const BUILTIN_RULES := [
	["Core Networking", true, true],
	["File and Printer Sharing", true, false],
	["Microsoft Edge", true, true],
	["Network Discovery", true, false],
	["Remote Desktop", false, false],
]
const SUBMIT_EARLY_HINT := "ยังมีส่วนที่ต้องดำเนินการอยู่ ตรวจสอบสถานะในหน้า Home ให้ทุกส่วนเป็นสีเขียวก่อนส่งผล"

## Made-up paths shown while the scan runs.
const SCAN_PATHS := [
	"C:\\Windows\\System32\\drivers\\etc",
	"C:\\Program Files\\School Apps\\Typing",
	"C:\\Users\\Student\\Documents",
	"C:\\Users\\Student\\Downloads",
	"C:\\Users\\Student\\Desktop",
	"C:\\Users\\Public\\Pictures",
]
const SCAN_FILES := 48213
const DOWNLOADS := ["Student_Game_Crack.exe", "Unknown_Update.exe", "Homework_Week3.docx", "Typing_Practice.pdf"]
## v2: the crack dropped Unknown_Update.exe, so one detection has both files.
const AFFECTED_FILES := 2
const PROFILES := {
	"Domain": "Networks at a workplace that are joined to a domain.",
	"Private": "Networks at home or work, where you know and trust the people and devices on the network.",
	"Public": "Networks in public places such as airports or coffee shops.",
}
## The school network is a Private network (v2): SchoolLab must be allowed on
## Private networks, so the program has to say which one is active.
const ACTIVE_PROFILE := "Private"

## The progress of this play, set by Mission05Controller. When it is null (the
## scene run on its own with F6) the program starts with its own fresh state.
static var shared_state: Mission05State

@export var data: Mission05Data
## Handle Esc here. Inside DesktopOS the desktop calls handle_escape() instead;
## when this scene runs on its own (F6) it is switched on automatically.
@export var handle_escape_itself: bool = false
## Seconds between pressing "ส่งผลการตรวจสอบ" and leaving the computer.
@export var exit_delay: float = 1.8

var state: Mission05State
var page: Page = Page.HOME
## The network profile shown on Page.FW_PROFILE.
var profile := ACTIVE_PROFILE
var scanning: bool = false
var scan_progress: float = 0.0
## The threat's details are open, and the action picked in them.
var threat_expanded := false
var threat_pick := ""

var _hint := ""
var _content: VBoxContainer
var _scroll: ScrollContainer
var _nav := {}
var _scan_bar: ProgressBar
var _scan_count: Label
var _scan_path: Label
var _scan_left: Label
## The two firewall alerts (shown over the program from the Firewall page).
var _alerts: FirewallAlerts
var _picker: Control
var _picker_pick := ""
var _add_menu_open := false
var _hint_panel: PanelContainer
var _hint_label: Label
var _submit_button: Button
var _submit_note: Label
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
	state = shared_state if shared_state != null else Mission05State.new()
	state.app_opened = true
	add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.BG, Color(0.75, 0.75, 0.75), 0, 0, 0))
	_build_frame()
	_build_picker()
	_build_game_panels()
	open_page(Page.HOME)


func _process(delta: float) -> void:
	if not scanning:
		return
	scan_progress = minf(1.0, scan_progress + delta / maxf(0.1, data.scan_seconds))
	if is_instance_valid(_scan_bar):
		_scan_bar.value = scan_progress * 100.0
		_scan_count.text = "%s files scanned" % _thousands(int(scan_progress * SCAN_FILES))
		_scan_path.text = SCAN_PATHS[int(scan_progress * 23) % SCAN_PATHS.size()]
		_scan_left.text = "Estimated time remaining: 00:00:%02d" % ceili((1.0 - scan_progress) * data.scan_seconds)
	if scan_progress >= 1.0:
		_finish_scan()


func _unhandled_input(event: InputEvent) -> void:
	if handle_escape_itself and visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		handle_escape()


# ================================================================ public API

## Esc closes an open dialog first, then the program. Returns true when used.
func handle_escape() -> bool:
	if not visible:
		return false
	if _picker.visible:
		_picker.visible = false
		return true
	if alert_visible():
		_alerts.dismissed = true
		_alerts.refresh()
		return true
	close_program()
	return true


func close_program() -> void:
	scanning = false
	close_requested.emit()


func open_page(target: Page) -> void:
	page = target
	_add_menu_open = false
	var section: String = SECTION[target]
	state.note_section(section)
	section_opened.emit(section)
	# Like v1: the alerts come up on the Firewall page (user 2026-11-15).
	if target == Page.FIREWALL and firewall_pending():
		show_alerts()
	_refresh()


## Redraws the current page (the alerts on the desktop changed the state).
func refresh() -> void:
	_refresh()
	_after_fix()


## A network profile page (Domain / Private / Public).
func open_profile(profile_name: String) -> void:
	profile = profile_name
	open_page(Page.FW_PROFILE)


func is_protected() -> bool:
	return state.is_protected()


## A firewall alert still needs an answer.
func firewall_pending() -> bool:
	return not state.alerts_done()


## The program's own alerts are showing (only when it runs on its own).
func alert_visible() -> bool:
	return _alerts != null and _alerts.alert_visible()


func picker_visible() -> bool:
	return _picker.visible


## The alert dialogs (opening the Firewall page, or "Review").
func show_alerts() -> void:
	if not firewall_pending():
		return
	if _alerts == null:
		_alerts = FirewallAlerts.new().setup(data, state)
		_alerts.name = "FirewallAlerts"
		add_child(_alerts)
		_alerts.answered.connect(func(_k: String, id: String, ok: bool):
			_clear_hint()
			firewall_choice_made.emit(id, ok)
			refresh())
	_clear_hint()
	_alerts.show_again()


## The alerts' FirewallAlerts node (null until the Firewall page was opened).
func alerts() -> FirewallAlerts:
	return _alerts


## The firewall switch on a network profile page ("disable"): always wrong,
## recorded and not applied (it switches back on). The alerts' answers are in
## FirewallAlerts. Returns false.
func choose_firewall(choice_id: String) -> bool:
	if choice_id != Mission05State.FIREWALL_OFF:
		return false
	state.note_firewall_off()
	firewall_choice_made.emit(choice_id, false)
	_wrong(data.get_firewall_choice(choice_id).hint)
	_refresh()
	return false


## Quick scan. Only once the alerts and the teacher's question are done (v2).
func start_scan() -> bool:
	if scanning or state.scan_status == Mission05State.ScanStatus.SCANNED or not state.can_scan():
		return false
	if page != Page.VIRUS:
		open_page(Page.VIRUS)
	scanning = true
	scan_progress = 0.0
	scan_started.emit()
	_refresh()
	return true


## Anti-Virus answers: "remove" / "quarantine" / "allow" (the threat's actions,
## after the scan), "exclude" (Add an exclusion), "realtime_off" (the switch).
## A wrong one is not applied. Returns true when right (quarantine).
func choose_threat(choice_id: String) -> bool:
	var choice := data.get_threat_choice(choice_id)
	if choice == null or state.threat_quarantined:
		return false
	if choice_id in ["remove", "quarantine", "allow"] and state.scan_status != Mission05State.ScanStatus.SCANNED:
		return false
	state.note_threat(choice_id)
	threat_choice_made.emit(choice_id, choice.is_correct)
	_picker.visible = false
	threat_pick = ""
	if choice.is_correct:
		threat_expanded = false
		_clear_hint()
		_after_fix()
	else:
		_wrong(choice.hint)
	_refresh()
	return choice.is_correct


## "ส่งผลการตรวจสอบ". Accepted only once the computer is Protected; earlier it
## shows a hint (and decision (e) is lost).
func submit_report() -> bool:
	if state.report_submitted:
		return false
	if not state.note_submit():
		_wrong(SUBMIT_EARLY_HINT)
		return false
	_clear_hint()
	_refresh_game_panels()
	report_submitted.emit()
	_exit_timer = get_tree().create_timer(exit_delay)
	_exit_timer.timeout.connect(func():
		if is_inside_tree():
			computer_exit_requested.emit())
	return true


func current_hint() -> String:
	return _hint


# ================================================================ state changes

func _wrong(hint: String) -> void:
	_hint = hint
	_refresh_game_panels()
	mistake_made.emit(hint)


func _clear_hint() -> void:
	_hint = ""
	_refresh_game_panels()


func _after_fix() -> void:
	if state.is_protected():
		protected_reached.emit()


func _finish_scan() -> void:
	scanning = false
	state.scan_status = Mission05State.ScanStatus.SCANNED
	threat_expanded = false
	scan_finished.emit(1)
	_refresh()


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
	var content_bg := PanelContainer.new()
	content_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_bg.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.CONTENT, Color(0, 0, 0, 0), 0, 0, 0))
	body.add_child(content_bg)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_bg.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 120)
	_scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	margin.add_child(_content)


func _title_bar() -> Control:
	var bar := PanelContainer.new()
	bar.name = "TitleBar"
	bar.custom_minimum_size = Vector2(0, 36)
	bar.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.BG, Color(0, 0, 0, 0), 0, 12, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(18, 18)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.draw.connect(func(): SecurityTheme.draw_shield(logo, logo.size * 0.5, 17.0, SecurityTheme.ACCENT))
	row.add_child(logo)
	var title := _label(data.app_name, 13, SecurityTheme.INK)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_window_button("MinimizeButton", "min", func(): minimize_requested.emit()))
	row.add_child(_window_button("MaximizeButton", "max", func(): pass))
	row.add_child(_window_button("CloseButton", "close", close_program))
	return bar


func _window_button(node_name: String, kind: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(46, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := SecurityTheme.box(Color(0.77, 0.17, 0.11) if kind == "close" else Color(0, 0, 0, 0.06), Color(0, 0, 0, 0), 0)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	b.draw.connect(_draw_window_button.bind(b, kind))
	return b


static func _draw_window_button(b: Button, kind: String) -> void:
	var c := b.size * 0.5
	var color := Color.WHITE if kind == "close" and b.is_hovered() else SecurityTheme.INK
	match kind:
		"close":
			SecurityTheme.draw_cross(b, c, 16.0, color, 1.0)
		"max":
			b.draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), color, false, 1.0)
		_:
			b.draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), color, 1.0)


func _sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Sidebar"
	panel.custom_minimum_size = Vector2(290, 0)
	panel.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.SIDEBAR, Color(0, 0, 0, 0), 0, 6, 4))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	for kind in ["back", "menu"]:
		var b := Button.new()
		b.name = "Nav_" + kind
		b.custom_minimum_size = Vector2(40, 36)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", SecurityTheme.box(SecurityTheme.HOVER, Color(0, 0, 0, 0), 4))
		b.add_theme_stylebox_override("pressed", SecurityTheme.box(SecurityTheme.SELECTED, Color(0, 0, 0, 0), 4))
		b.draw.connect(func(): SecurityTheme.draw_glyph(b, kind, b.size * 0.5, 15.0, SecurityTheme.INK if kind == "menu" or page != Page.HOME else Color(SecurityTheme.INK, 0.35)))
		if kind == "back":
			b.pressed.connect(_go_back)
		col.add_child(b)
	for item in NAV:
		col.add_child(_nav_item(item[0], item[1], item[2]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_nav_item(Page.SETTINGS, "settings", "Settings"))
	var note := _label("Simulated for education. Not affiliated with Microsoft.", 11, SecurityTheme.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(270, 0)
	col.add_child(note)
	return panel


func _go_back() -> void:
	match page:
		Page.FW_PROFILE, Page.ALLOWED_APPS:
			open_page(Page.FIREWALL)
		Page.AV_SETTINGS:
			open_page(Page.VIRUS)
		Page.EXCLUSIONS:
			open_page(Page.AV_SETTINGS)
		Page.HOME:
			pass
		_:
			open_page(Page.HOME)


func _nav_item(target: Page, kind: String, text: String) -> Button:
	var b := Button.new()
	b.name = "Nav_%s" % Page.keys()[target]
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", SecurityTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 46, 4))
	b.add_theme_stylebox_override("hover", SecurityTheme.box(SecurityTheme.HOVER, Color(0, 0, 0, 0), 4, 46, 4))
	b.add_theme_stylebox_override("pressed", SecurityTheme.box(SecurityTheme.SELECTED, Color(0, 0, 0, 0), 4, 46, 4))
	b.pressed.connect(func(): open_page(target))
	b.draw.connect(func():
		var selected := _nav_selected() == target
		if selected:
			b.draw_style_box(SecurityTheme.box(SecurityTheme.SELECTED, Color(0, 0, 0, 0), 4), Rect2(Vector2.ZERO, b.size))
			b.draw_style_box(SecurityTheme.box(SecurityTheme.ACCENT, Color(0, 0, 0, 0), 2), Rect2(0, b.size.y * 0.5 - 8, 3, 16))
		SecurityTheme.draw_glyph(b, kind, Vector2(24, b.size.y * 0.5), 16.0, SecurityTheme.INK))
	_nav[target] = b
	return b


## The sidebar item lit for the current page (sub-pages light their section).
func _nav_selected() -> Page:
	match page:
		Page.FW_PROFILE, Page.ALLOWED_APPS:
			return Page.FIREWALL
		Page.AV_SETTINGS, Page.EXCLUSIONS:
			return Page.VIRUS
	return page


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
		Page.VIRUS:
			_page_virus()
		Page.ACCOUNT:
			_page_account()
		Page.FIREWALL:
			_page_firewall()
		Page.APP:
			_page_app()
		Page.DEVICE:
			_page_device()
		Page.HEALTH:
			_page_health()
		Page.FAMILY:
			_page_family()
		Page.HISTORY:
			_page_history()
		Page.SETTINGS:
			_page_settings()
		Page.FW_PROFILE:
			_page_profile()
		Page.AV_SETTINGS:
			_page_av_settings()
		Page.EXCLUSIONS:
			_page_exclusions()
		Page.ALLOWED_APPS:
			_page_allowed_apps()
	for b in _nav.values():
		b.queue_redraw()
	if _alerts:
		_alerts.refresh()
	_refresh_game_panels()


func _page_home() -> void:
	_title("Security at a glance", "See what's happening with the security and health of your device\nand take any actions needed.")
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	var virus_badge := "ok"
	var virus_text := "No action needed."
	if not state.threat_quarantined:
		virus_badge = "bad" if state.scan_status == Mission05State.ScanStatus.SCANNED else "warn"
		virus_text = "Threats found.\nStart the recommended actions." if virus_badge == "bad" else "Actions recommended."
	grid.add_child(_tile("TileVirus", "virus", "Virus & threat protection", virus_text, virus_badge, Page.VIRUS))
	grid.add_child(_tile("TileAccount", "account", "Account protection", "No action needed.", "ok", Page.ACCOUNT))
	var fw_ok := state.alerts_done()
	grid.add_child(_tile("TileFirewall", "firewall", "Firewall & network protection", "No action needed." if fw_ok else "Actions recommended.", "ok" if fw_ok else "warn", Page.FIREWALL))
	grid.add_child(_tile("TileApp", "app", "App & browser control", "No action needed.", "ok", Page.APP))
	grid.add_child(_tile("TileDevice", "device", "Device security", "View status and manage hardware\nsecurity features.", "", Page.DEVICE))
	grid.add_child(_tile("TileHealth", "health", "Device performance & health", "No action needed.", "ok", Page.HEALTH))
	grid.add_child(_tile("TileFamily", "family", "Family options", "Manage how your family uses their\ndevices.", "", Page.FAMILY))


func _tile(node_name: String, kind: String, title: String, status: String, badge: String, target: Page) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(250, 178)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", SecurityTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("hover", SecurityTheme.box(SecurityTheme.HOVER, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("pressed", SecurityTheme.box(SecurityTheme.SELECTED, Color(0, 0, 0, 0), 6))
	b.pressed.connect(func(): open_page(target))
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 18
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	b.add_child(col)
	var icon := SecurityTheme.glyph(kind, 58.0, SecurityTheme.INK, badge)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var t := _label(title, 16, SecurityTheme.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var s := _label(status, 13, SecurityTheme.INK_SOFT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(s)
	return b


func _page_virus() -> void:
	_title("Virus & threat protection", "Protection for your device against threats.", "virus")
	_section("history", "Current threats")
	var box := _block()
	if scanning:
		box.add_child(_label("Quick scan running...", 15, SecurityTheme.INK, true))
		_scan_left = _label("", 14, SecurityTheme.INK_SOFT)
		box.add_child(_scan_left)
		_scan_bar = ProgressBar.new()
		_scan_bar.name = "ScanBar"
		_scan_bar.custom_minimum_size = Vector2(360, 4)
		_scan_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_scan_bar.show_percentage = false
		_scan_bar.value = scan_progress * 100.0
		box.add_child(_scan_bar)
		_scan_count = _label("", 14, SecurityTheme.INK_SOFT)
		box.add_child(_scan_count)
		_scan_path = _label("", 13, SecurityTheme.INK_SOFT)
		box.add_child(_scan_path)
		var cancel := Button.new()
		cancel.text = "Cancel"
		cancel.disabled = true
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		box.add_child(cancel)
	elif state.scan_status == Mission05State.ScanStatus.NOT_SCANNED:
		box.add_child(_status_row("warn", "Your device hasn't been scanned in 7 days.", "No scan results available. Run a quick scan to check for threats."))
		box.add_child(_label("Last scan: 7 days ago (quick scan)", 14, SecurityTheme.INK_SOFT))
		var scan := Button.new()
		scan.name = "QuickScanButton"
		scan.text = "Quick scan"
		scan.custom_minimum_size = Vector2(120, 32)
		scan.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		SecurityTheme.style_accent(scan)
		scan.disabled = not state.can_scan()
		scan.pressed.connect(start_scan)
		box.add_child(scan)
		if not state.alerts_done():
			box.add_child(_label("Another security action is waiting: Firewall & network protection.", 13, SecurityTheme.WARNING_INK))
		_links(box, ["Scan options", "Allowed threats", "Protection history"])
	elif not state.threat_quarantined:
		box.add_child(_status_row("bad", "Threats found.", "Start the recommended actions."))
		box.add_child(_label("Threats found: 1   ·   Last scan: %s (quick scan)   ·   %s files scanned" % [_today(), _thousands(SCAN_FILES)], 14, SecurityTheme.INK_SOFT))
		_threat_list(box)
		var start := Button.new()
		start.name = "StartActionsButton"
		start.text = "Start actions"
		start.custom_minimum_size = Vector2(130, 32)
		start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		SecurityTheme.style_accent(start)
		start.disabled = threat_pick == ""
		start.pressed.connect(func(): choose_threat(threat_pick))
		box.add_child(start)
		_links(box, ["Scan options", "Allowed threats", "Protection history"])
	else:
		box.add_child(_status_row("ok", "No current threats.", "Last scan: %s (quick scan)\n1 threat found and quarantined (%d affected items).\n%s files scanned." % [_today(), AFFECTED_FILES, _thousands(SCAN_FILES)]))
		var done := _label("%s, %s — Threat quarantined" % [data.threat_file, data.firewall_app], 14, SecurityTheme.OK, true)
		done.name = "QuarantinedNote"
		box.add_child(done)
		var quick := Button.new()
		quick.text = "Quick scan"
		quick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		SecurityTheme.style_accent(quick)
		box.add_child(quick)
		_links(box, ["Scan options", "Allowed threats", "Protection history"])
	_section("settings", "Virus & threat protection settings")
	var settings := _block()
	settings.add_child(_label("No action needed.", 14, SecurityTheme.INK_SOFT))
	_links(settings, ["Manage settings"], [func(): open_page(Page.AV_SETTINGS)])
	_section("history", "Virus & threat protection updates")
	var updates := _block()
	updates.add_child(_label("Security intelligence is up to date.\nLast update: %s 7:42 AM" % _today(), 14, SecurityTheme.INK_SOFT))
	_links(updates, ["Protection updates"])


## The threat found by the scan: a row that opens its details and actions.
func _threat_list(parent: Control) -> void:
	var card := PanelContainer.new()
	card.name = "ThreatCard"
	card.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.CARD, SecurityTheme.BORDER, 6, 16, 10))
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var row := Button.new()
	row.name = "ThreatRow"
	row.custom_minimum_size = Vector2(0, 44)
	row.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed"]:
		row.add_theme_stylebox_override(s, StyleBoxEmpty.new() if s == "normal" else SecurityTheme.box(SecurityTheme.HOVER, Color(0, 0, 0, 0), 4))
	row.pressed.connect(func():
		threat_expanded = not threat_expanded
		_refresh())
	col.add_child(row)
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	line.add_child(SecurityTheme.icon("bad", Color.WHITE, 16))
	var name_col := VBoxContainer.new()
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 0)
	line.add_child(name_col)
	name_col.add_child(_label(data.threat_name, 15, SecurityTheme.INK, true))
	name_col.add_child(_label("%s 3:01 PM (Active)" % _today(), 13, SecurityTheme.INK_SOFT))
	var level := _label(data.threat_risk, 14, SecurityTheme.DANGER, true)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(level)
	var chevron := Control.new()
	chevron.custom_minimum_size = Vector2(20, 20)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var up := threat_expanded
	chevron.draw.connect(func():
		var c := chevron.size * 0.5
		var dy := -3.0 if up else 3.0
		chevron.draw_polyline(PackedVector2Array([c + Vector2(-5, -dy), c + Vector2(0, dy), c + Vector2(5, -dy)]), SecurityTheme.INK_SOFT, 1.5, true))
	line.add_child(chevron)
	if not threat_expanded:
		return
	col.add_child(_details({
		"Alert level": data.threat_risk,
		"Status": "Active",
		"Date": "%s 3:01 PM" % _today(),
		"Category": "Tool",
		"Details": "This program has potentially unwanted behavior.",
		"Affected items": _affected_items(),
	}))
	col.add_child(_label("Actions", 14, SecurityTheme.INK, true))
	var group := ButtonGroup.new()
	for id in ["remove", "quarantine", "allow"]:
		var choice := data.get_threat_choice(id)
		var rb := CheckBox.new()
		rb.name = "Action_" + id
		rb.text = choice.label
		rb.button_group = group
		rb.focus_mode = Control.FOCUS_NONE
		rb.button_pressed = threat_pick == id
		rb.toggled.connect(func(on: bool):
			if on:
				threat_pick = id
				var start := find_child("StartActionsButton", true, false) as Button
				if start:
					start.disabled = false)
		col.add_child(rb)


## Both files of the one detection (v2: the crack dropped Unknown_Update.exe).
func _affected_items() -> String:
	return "file: %s\nfile: %s" % [data.threat_path, data.firewall_path]


func _page_firewall() -> void:
	_title("Firewall & network protection", "Who and what can access your networks.", "firewall")
	if firewall_pending():
		var waiting := PackedStringArray()
		for key: String in Mission05State.ALERT_ORDER:
			if not state.alert_done(key):
				waiting.append(data.school_app if key == Mission05State.ALERT_SCHOOL else data.firewall_app)
		var banner := _banner(SecurityTheme.WARNING_BG, "warn", "Windows Defender Firewall has blocked some features of %s." % " and ".join(waiting), "FirewallBanner")
		var review := Button.new()
		review.name = "ReviewButton"
		review.text = "Review"
		review.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		review.pressed.connect(show_alerts)
		banner.add_child(review)
	else:
		var done := _banner(SecurityTheme.OK_BG, "ok", "Unauthorized connection blocked: %s can't access your networks." % data.firewall_app, "FirewallDone")
		var nets := "private and public networks" if "allow_both" in state.alert_answers[Mission05State.ALERT_SCHOOL] else "private networks"
		done.add_child(_label("%s is allowed on %s." % [data.school_app, nets], 13, SecurityTheme.INK_SOFT))
		done.add_child(_label("Microsoft Defender Firewall is on for all networks.", 13, SecurityTheme.INK_SOFT))
	for p: String in ["Domain", "Private", "Public"]:
		_content.add_child(_profile_row(p))
	_content.add_child(_spacer(10))
	_links(_content, ["Allow an app through firewall", "Network and Internet troubleshooter", "Firewall notification settings", "Advanced settings", "Restore firewalls to default"], [func(): open_page(Page.ALLOWED_APPS)])


## "Allow an app through firewall": the rules list, like the real "Allowed
## apps" window (read-only until "Change settings", which the game does not
## need). Shows what the alerts did: SchoolLab allowed, Unknown_Update blocked.
## Opening it after the alerts is process point 2 (checking the result).
func _page_allowed_apps() -> void:
	_title("Allowed apps", "Allow apps to communicate through Windows Defender Firewall.\nTo add, change, or remove allowed apps and ports, click Change settings.", "firewall")
	var change := Button.new()
	change.name = "ChangeSettingsButton"
	change.text = "Change settings"
	change.disabled = true
	change.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(change)
	_content.add_child(_label("Allowed apps and features:", 14, SecurityTheme.INK, true))
	var card := PanelContainer.new()
	card.name = "AllowedAppsList"
	card.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.CARD, SecurityTheme.BORDER, 4, 12, 8))
	_content.add_child(card)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	card.add_child(grid)
	for head in ["Name", "Private", "Public"]:
		grid.add_child(_label(head, 14, SecurityTheme.INK_SOFT, true))
	var rows: Array = BUILTIN_RULES.duplicate()
	var school: Array = state.alert_answers[Mission05State.ALERT_SCHOOL]
	if state.alert_done(Mission05State.ALERT_SCHOOL):
		rows.append([data.school_app, true, "allow_both" in school])
	if state.alert_done(Mission05State.ALERT_UNKNOWN):
		rows.append([data.firewall_app, false, false])
	rows.sort_custom(func(a, b): return String(a[0]).naturalnocasecmp_to(String(b[0])) < 0)
	for r in rows:
		var name_box := CheckBox.new()
		name_box.name = "Rule_" + String(r[0]).replace(" ", "").replace(".", "")
		name_box.text = r[0]
		name_box.button_pressed = r[1] or r[2]
		grid.add_child(_read_only(name_box))
		for on in [r[1], r[2]]:
			var cb := CheckBox.new()
			cb.button_pressed = on
			grid.add_child(_read_only(cb))
	if not state.alerts_done():
		_content.add_child(_label("Some apps are waiting for your decision in Windows Security Alert.", 13, SecurityTheme.WARNING_INK))
	var another := Button.new()
	another.name = "AllowAnotherButton"
	another.text = "Allow another app..."
	another.disabled = true
	another.size_flags_horizontal = Control.SIZE_SHRINK_END
	_content.add_child(another)


func _profile_row(p: String) -> Button:
	var b := Button.new()
	b.name = "Profile_" + p
	b.custom_minimum_size = Vector2(0, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", SecurityTheme.box(SecurityTheme.HOVER, Color(0, 0, 0, 0), 4))
	b.add_theme_stylebox_override("pressed", SecurityTheme.box(SecurityTheme.SELECTED, Color(0, 0, 0, 0), 4))
	b.pressed.connect(func(): open_profile(p))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	b.add_child(row)
	var kinds := {"Domain": "device", "Private": "home", "Public": "firewall"}
	var g := SecurityTheme.glyph(kinds[p], 28.0)
	row.add_child(g)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(_label("%s network%s" % [p, " (active)" if p == ACTIVE_PROFILE else ""], 15, SecurityTheme.LINK))
	col.add_child(_label("Firewall is on.", 14, SecurityTheme.INK_SOFT))
	return b


func _page_profile() -> void:
	var active := profile == ACTIVE_PROFILE
	_title("%s network" % profile, PROFILES[profile], "firewall")
	var nets := _block()
	nets.add_child(_label("Active %s networks" % profile.to_lower(), 15, SecurityTheme.INK, true))
	nets.add_child(_label("SCHOOL-LAN" if active else "Not connected", 14, SecurityTheme.INK_SOFT))
	var fw := _block()
	fw.add_child(_label("Microsoft Defender Firewall", 15, SecurityTheme.INK, true))
	fw.add_child(_label("Helps protect your device while on a %s network." % profile.to_lower(), 14, SecurityTheme.INK_SOFT))
	var t := SecurityTheme.toggle(true, func(on: bool):
		if not on:
			choose_firewall(Mission05State.FIREWALL_OFF))
	t.name = "FirewallToggle"
	fw.add_child(t)
	var inc := _block()
	inc.add_child(_label("Incoming connections", 15, SecurityTheme.INK, true))
	var cb := CheckBox.new()
	cb.text = "Blocks all incoming connections, including those in the list of allowed apps."
	cb.focus_mode = Control.FOCUS_NONE
	inc.add_child(cb)


func _page_av_settings() -> void:
	_title("Virus & threat protection settings", "View and update virus & threat protection settings for Microsoft\nDefender Antivirus.", "settings")
	var rt := _block()
	rt.add_child(_label("Real-time protection", 15, SecurityTheme.INK, true))
	var text := _label("Locates and stops malware from installing or running on your device. You can turn off this setting for a short time before it turns back on automatically.", 14, SecurityTheme.INK_SOFT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.add_child(text)
	var t := SecurityTheme.toggle(true, func(on: bool):
		if not on:
			choose_threat("realtime_off")
			_refresh())
	t.name = "RealtimeToggle"
	rt.add_child(t)
	for item in [["Cloud-delivered protection", "Provides increased and faster protection with access to the latest protection data in the cloud."], ["Automatic sample submission", "Send sample files to Microsoft to help protect you and others from potential threats."], ["Tamper Protection", "Prevents others from tampering with important security features."]]:
		var blk := _block()
		blk.add_child(_label(item[0], 15, SecurityTheme.INK, true))
		blk.add_child(_label("This setting is managed by your administrator.", 13, SecurityTheme.INK_SOFT))
		var d := _label(item[1], 14, SecurityTheme.INK_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blk.add_child(d)
		var locked := SecurityTheme.toggle(true, func(_on: bool): pass)
		(locked.get_node("Switch") as Button).disabled = true
		locked.modulate = Color(1, 1, 1, 0.5)
		blk.add_child(locked)
	var ex := _block()
	ex.add_child(_label("Exclusions", 15, SecurityTheme.INK, true))
	var ed := _label("Microsoft Defender Antivirus won't scan items that have been excluded. Excluded items could contain threats that make your device vulnerable.", 14, SecurityTheme.INK_SOFT)
	ed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ex.add_child(ed)
	_links(ex, ["Add or remove exclusions"], [func(): open_page(Page.EXCLUSIONS)])


func _page_exclusions() -> void:
	_title("Exclusions", "Add or remove items that you want to exclude from Microsoft\nDefender Antivirus scans.", "virus")
	var add := Button.new()
	add.name = "AddExclusionButton"
	add.text = "+   Add an exclusion"
	add.custom_minimum_size = Vector2(200, 34)
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.pressed.connect(func():
		_add_menu_open = not _add_menu_open
		_refresh())
	_content.add_child(add)
	if _add_menu_open:
		var menu := PanelContainer.new()
		menu.name = "AddExclusionMenu"
		menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		menu.custom_minimum_size = Vector2(200, 0)
		menu.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.CARD, SecurityTheme.BORDER, 6, 4, 4))
		_content.add_child(menu)
		var col := VBoxContainer.new()
		menu.add_child(col)
		for kind in ["File", "Folder", "File type", "Process"]:
			var b := Button.new()
			b.name = "Exclude_" + kind.replace(" ", "")
			b.text = kind
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			b.pressed.connect(func():
				_add_menu_open = false
				open_picker())
			col.add_child(b)
	_content.add_child(_spacer(6))
	_content.add_child(_label("No exclusions.", 14, SecurityTheme.INK_SOFT))


func _page_account() -> void:
	_title("Account protection", "Security for your account and sign-in.", "account")
	_status_block("account", "Microsoft account", "ok", "Signed in with a local school account.", ["Account info"])
	_status_block("account", "Windows Hello", "ok", "No action needed.", ["Sign-in options"])
	_status_block("account", "Dynamic lock", "", "Windows can lock when devices paired to your PC go out of range.", ["Dynamic lock settings"])


func _page_app() -> void:
	_title("App & browser control", "App protection and online security.", "app")
	_status_block("app", "Smart App Control", "", "Smart App Control adds significant protection from new and emerging threats by blocking apps that are malicious or untrusted.", ["Smart App Control settings"])
	_status_block("app", "Reputation-based protection", "ok", "No action needed.", ["Reputation-based protection settings"])
	_status_block("app", "Exploit protection", "ok", "No action needed.", ["Exploit protection settings"])


func _page_device() -> void:
	_title("Device security", "Security that comes built into your device.", "device")
	_status_block("device", "Core isolation", "ok", "Virtualization-based security is running to protect the core parts of your device.", ["Core isolation details"])
	_status_block("device", "Security processor", "ok", "Your security processor, called the trusted platform module (TPM), is providing additional encryption for your device.", ["Security processor details"])
	_status_block("device", "Secure boot", "ok", "Secure boot is on. This helps prevent malicious software from loading when your device starts.", [])


func _page_health() -> void:
	_title("Device performance & health", "Reports on the health of your device.", "health")
	_content.add_child(_label("Health report", 18, SecurityTheme.INK, true))
	_content.add_child(_label("Last scan: %s 7:40 AM" % _today(), 14, SecurityTheme.INK_SOFT))
	for item in ["Storage capacity", "Apps and software", "Windows Time service"]:
		_content.add_child(_status_row("ok", item, "No problems found."))


func _page_family() -> void:
	_title("Family options", "Get what you need to simplify your family's digital life.", "family")
	_status_block("family", "Parental controls", "", "Help protect your kids online. Choose which websites your kids can visit as they explore the web.", ["View family settings"])
	_status_block("family", "See your family's devices at a glance", "", "View the health and safety status of your family's devices.", ["View devices"])


func _page_history() -> void:
	_title("Protection history", "View the latest protection actions and recommendations from\nWindows Security.", "history")
	if not state.threat_quarantined:
		_content.add_child(_label("No recent actions.", 14, SecurityTheme.INK_SOFT))
		return
	var card := PanelContainer.new()
	card.name = "HistoryEntry"
	card.add_theme_stylebox_override("panel", SecurityTheme.box(SecurityTheme.CARD, SecurityTheme.BORDER, 6, 16, 12))
	_content.add_child(card)
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(_status_row("ok", "Threat quarantined", "%s 3:02 PM   ·   Affected items: %d" % [_today(), AFFECTED_FILES]))
	col.add_child(_details({"Detected": data.threat_name, "Alert level": data.threat_risk, "Status": "Quarantined", "Affected items": _affected_items()}))
	col.add_child(_label("Quarantined files are in a restricted location where they can't harm your device.", 13, SecurityTheme.INK_SOFT))


func _page_settings() -> void:
	_title("Settings", "", "settings")
	_status_block("settings", "Notifications", "", "Windows Security will send notifications with critical information about the health and security of your device.", ["Manage notifications"])
	_status_block("settings", "About", "", "Windows Security (simulated for education)\nNot affiliated with Microsoft. Nothing on your real computer is scanned.", [])


# ================================================================ file picker (Add an exclusion)

func open_picker() -> void:
	_picker_pick = ""
	_picker.visible = true
	_refresh_picker()


func _build_picker() -> void:
	_picker = Control.new()
	_picker.name = "FilePicker"
	_picker.visible = false
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.12)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(dim)
	var win := PanelContainer.new()
	win.name = "PickerWindow"
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(620, 380)
	win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := SecurityTheme.box(SecurityTheme.CARD, Color(0.6, 0.6, 0.6), 8, 0, 0)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 18
	win.add_theme_stylebox_override("panel", sb)
	_picker.add_child(win)
	var m := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	win.add_child(m)
	var col := VBoxContainer.new()
	col.name = "PickerColumn"
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)


func _refresh_picker() -> void:
	var col := _picker.find_child("PickerColumn", true, false) as VBoxContainer
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 34)
	col.add_child(bar)
	var title := _label("Open", 13, SecurityTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	bar.add_child(_window_button("PickerClose", "close", func(): _picker.visible = false))
	var path := _label("This PC  ›  Local Disk (C:)  ›  Users  ›  Student  ›  Downloads", 14, SecurityTheme.INK)
	col.add_child(path)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	col.add_child(list)
	for f: String in DOWNLOADS:
		var b := Button.new()
		b.name = "File_" + f.get_basename()
		b.text = "          " + f
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 32)
		b.focus_mode = Control.FOCUS_NONE
		var picked := _picker_pick == f
		b.add_theme_stylebox_override("normal", SecurityTheme.box(SecurityTheme.INFO_BG if picked else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12, 4))
		b.add_theme_stylebox_override("hover", SecurityTheme.box(SecurityTheme.INFO_BG, Color(0, 0, 0, 0), 0, 12, 4))
		b.draw.connect(func(): SecurityTheme.draw_glyph(b, "file", Vector2(30, b.size.y * 0.5), 16.0, SecurityTheme.INK_SOFT))
		b.pressed.connect(func():
			_picker_pick = f
			_refresh_picker())
		list.add_child(b)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	col.add_child(foot)
	var name_box := _label("File name:  " + _picker_pick, 14, SecurityTheme.INK)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(name_box)
	var open := Button.new()
	open.name = "PickerOpen"
	open.text = "Open"
	open.custom_minimum_size = Vector2(100, 32)
	SecurityTheme.style_accent(open)
	open.disabled = _picker_pick == ""
	open.pressed.connect(func(): choose_threat("exclude"))
	foot.add_child(open)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(100, 32)
	cancel.pressed.connect(func(): _picker.visible = false)
	foot.add_child(cancel)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(8, 8)
	col.add_child(pad)


# ================================================================ game panels (Thai, outside the Windows look)

func _build_game_panels() -> void:
	var layer := Control.new()
	layer.name = "GameLayer"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_hint_panel = PanelContainer.new()
	_hint_panel.name = "HintPanel"
	_hint_panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.07, 0.09, 0.13, 0.94), Color(1.0, 0.76, 0.2, 0.9), 8, 16, 10))
	# Bottom left, over the sidebar: never on top of a dialog's buttons.
	_hint_panel.anchor_left = 0.0
	_hint_panel.anchor_right = 0.0
	_hint_panel.anchor_top = 1.0
	_hint_panel.anchor_bottom = 1.0
	_hint_panel.offset_left = 10
	_hint_panel.offset_right = 318
	_hint_panel.offset_top = -150
	_hint_panel.offset_bottom = -10
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.visible = false
	layer.add_child(_hint_panel)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 10)
	_hint_panel.add_child(hint_row)
	var hint_col := VBoxContainer.new()
	hint_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(hint_col)
	hint_col.add_child(GameUI.label("คำใบ้", 14, Color(1.0, 0.8, 0.35), true))
	_hint_label = GameUI.label("", 16, Color.WHITE)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_col.add_child(_hint_label)
	hint_col.add_child(GameUI.label("ลองเลือกใหม่อีกครั้ง", 13, Color(0.75, 0.8, 0.9)))
	var hide := Button.new()
	hide.name = "HintClose"
	hide.text = " x "
	hide.flat = true
	hide.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hide.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	hide.pressed.connect(func(): _hint_panel.visible = false)
	hint_row.add_child(hide)

	var submit_panel := PanelContainer.new()
	submit_panel.name = "SubmitPanel"
	submit_panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.07, 0.09, 0.13, 0.94), Color(0.4, 0.6, 0.95, 0.7), 8, 14, 10))
	submit_panel.anchor_left = 1.0
	submit_panel.anchor_right = 1.0
	submit_panel.anchor_top = 1.0
	submit_panel.anchor_bottom = 1.0
	submit_panel.offset_left = -250
	submit_panel.offset_right = -16
	submit_panel.offset_top = -110
	submit_panel.offset_bottom = -16
	submit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(submit_panel)
	var sc := VBoxContainer.new()
	sc.add_theme_constant_override("separation", 6)
	submit_panel.add_child(sc)
	_submit_note = GameUI.label("เมื่อทุกส่วนเป็นสีเขียวแล้ว", 13, Color(0.75, 0.8, 0.9))
	_submit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc.add_child(_submit_note)
	_submit_button = Button.new()
	_submit_button.name = "SubmitButton"
	_submit_button.text = data.submit_button_text
	_submit_button.custom_minimum_size = Vector2(0, 38)
	_submit_button.focus_mode = Control.FOCUS_NONE
	_submit_button.add_theme_font_override("font", GameUI.FONT_BOLD)
	_submit_button.add_theme_font_size_override("font_size", 16)
	_submit_button.add_theme_stylebox_override("normal", GameUI.box(Color(0.16, 0.45, 0.85), Color(0, 0, 0, 0), 6, 12, 6))
	_submit_button.add_theme_stylebox_override("hover", GameUI.box(Color(0.22, 0.52, 0.92), Color(0, 0, 0, 0), 6, 12, 6))
	_submit_button.add_theme_stylebox_override("pressed", GameUI.box(Color(0.12, 0.38, 0.75), Color(0, 0, 0, 0), 6, 12, 6))
	_submit_button.add_theme_stylebox_override("disabled", GameUI.box(Color(0.25, 0.3, 0.38), Color(0, 0, 0, 0), 6, 12, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_submit_button.add_theme_color_override(c, Color.WHITE)
	_submit_button.pressed.connect(submit_report)
	sc.add_child(_submit_button)


func _refresh_game_panels() -> void:
	if _hint_panel == null:
		return
	_hint_label.text = _hint
	_hint_panel.visible = _hint != ""
	_submit_button.disabled = state.report_submitted
	_submit_note.text = data.submitted_message if state.report_submitted else "เมื่อทุกส่วนเป็นสีเขียวแล้ว"


# ================================================================ widgets

## Page title with the section's icon above it, like the real program.
func _title(title: String, subtitle: String, kind: String = "") -> void:
	if kind != "":
		var g := SecurityTheme.glyph(kind, 44.0)
		g.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_content.add_child(g)
	_content.add_child(_label(title, 28, SecurityTheme.INK, true))
	if subtitle != "":
		_content.add_child(_label(subtitle, 14, SecurityTheme.INK_SOFT))
	_content.add_child(_spacer(10))


func _section(kind: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(SecurityTheme.glyph(kind, 22.0))
	row.add_child(_label(title, 18, SecurityTheme.INK, true))
	_content.add_child(_spacer(6))
	_content.add_child(row)


## A block of content under a section heading (indented like the real one).
func _block() -> VBoxContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 32)
	m.add_theme_constant_override("margin_bottom", 10)
	_content.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)
	return col


## A section with a status badge, a line of text and links (static pages).
func _status_block(kind: String, title: String, badge: String, text: String, links: Array) -> void:
	_section(kind, title)
	var b := _block()
	if badge != "":
		b.add_child(_status_row(badge, text, ""))
	else:
		var l := _label(text, 14, SecurityTheme.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)
		b.add_child(l)
	if not links.is_empty():
		_links(b, links)


func _status_row(badge: String, text: String, sub: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := SecurityTheme.icon(badge, Color.WHITE, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(_label(text, 14, SecurityTheme.INK))
	if sub != "":
		col.add_child(_label(sub, 14, SecurityTheme.INK_SOFT))
	return row


## A card with a status badge on the left (banners on the firewall page).
func _banner(bg: Color, badge: String, text: String, node_name: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.add_theme_stylebox_override("panel", SecurityTheme.box(bg, Color(0, 0, 0, 0), 6, 16, 12))
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon := SecurityTheme.icon(badge, Color.WHITE, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var l := _label(text, 14, SecurityTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	return col


## Blue links; `actions` (optional, same order) are called when clicked.
func _links(parent: Control, texts: Array, actions: Array = []) -> void:
	for i in texts.size():
		var b := Button.new()
		b.name = "Link_" + String(texts[i]).replace(" ", "")
		b.text = texts[i]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.add_theme_font_size_override("font_size", 14)
		SecurityTheme.style_link(b)
		if i < actions.size():
			b.pressed.connect(actions[i])
		parent.add_child(b)


func _details(rows: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	for key in rows:
		grid.add_child(_label(str(key), 14, SecurityTheme.INK_SOFT))
		var v := _label(str(rows[key]), 14, SecurityTheme.INK)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size = Vector2(420, 0)
		grid.add_child(v)
	return grid


## A check box that shows its state clearly but cannot be clicked (the list
## is read-only until "Change settings", which the game does not need).
static func _read_only(cb: CheckBox) -> CheckBox:
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		cb.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	return cb


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", SecurityTheme.FONT_BOLD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Today as Windows shows it in en-US: M/D/YYYY.
static func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%d/%d/%d" % [d.month, d.day, d.year]


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
