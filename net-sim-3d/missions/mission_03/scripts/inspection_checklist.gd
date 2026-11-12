class_name Mission03Checklist
extends CanvasLayer

## Network Inspection Checklist: the foldable panel on the right while the
## player sits at one of the three sample computers. The player runs ipconfig
## and ping in the Command Prompt, types IP / Subnet Mask / Default Gateway,
## picks the ping result and the status, then attaches the row to the report
## once (it cannot be changed afterwards). Nothing is filled in for the player.

signal attached(host: String)

var state: Mission03State
var host := ""

var side_panel: SidePanel
var _subtitle: Label
var _steps: Label
var _progress: Label
var ip_edit: LineEdit
var mask_edit: LineEdit
var gateway_edit: LineEdit
var ping_buttons := {}
var status_buttons := {}
var attach_button: Button
var _hint: Label


func _ready() -> void:
	layer = 22
	visible = false
	side_panel = SidePanel.new()
	side_panel.name = "ChecklistPanel"
	add_child(side_panel)
	side_panel.title.text = "Network Inspection Checklist"
	var col := side_panel.body
	_subtitle = GameUI.label("", 16, GameUI.INK, true)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_subtitle)
	_steps = GameUI.label("", 15, GameUI.INK_SOFT)
	_steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_steps)
	col.add_child(HSeparator.new())
	ip_edit = _field(col, "IP Address", "IpEdit")
	mask_edit = _field(col, "Subnet Mask", "MaskEdit")
	gateway_edit = _field(col, "Default Gateway", "GatewayEdit")
	col.add_child(GameUI.label("ผลการ ping ไปที่ Default Gateway", 15, GameUI.INK, true))
	ping_buttons = _choices(col, "Ping", [[Mission03State.REPLY, "ได้รับการตอบกลับ"], [Mission03State.TIMEOUT, "หมดเวลา / ไม่ตอบกลับ"]])
	col.add_child(GameUI.label("สถานะของเครื่อง", 15, GameUI.INK, true))
	status_buttons = _choices(col, "Status", [[Mission03State.NORMAL, "ปกติ"], [Mission03State.ABNORMAL, "ผิดปกติ"]])
	_hint = GameUI.label("", 14, GameUI.BAD)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	attach_button = GameUI.button("แนบผลลงรายงาน", true)
	attach_button.name = "AttachButton"
	attach_button.pressed.connect(attach)
	col.add_child(attach_button)
	col.add_child(GameUI.label("แนบได้ครั้งเดียว ตรวจค่าให้ตรงกับผลคำสั่งก่อนแนบ", 13, GameUI.INK_SOFT))
	_progress = GameUI.label("", 14, GameUI.INK_SOFT)
	_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_progress)
	_progress.visible = false # the count is in the subtitle (fits 720 px)


func _field(parent: Control, title: String, node_name: String) -> LineEdit:
	parent.add_child(GameUI.label(title, 15, GameUI.INK, true))
	var edit := LineEdit.new()
	edit.name = node_name
	edit.placeholder_text = "พิมพ์ตามผลคำสั่ง ipconfig"
	edit.add_theme_font_size_override("font_size", 17)
	edit.text_changed.connect(func(_t: String): refresh())
	parent.add_child(edit)
	return edit


func _choices(parent: Control, prefix: String, options: Array) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var group := ButtonGroup.new()
	var out := {}
	for option: Array in options:
		var b := Button.new()
		b.name = prefix + "_" + String(option[0])
		b.text = option[1]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", GameUI.box(Color(0.93, 0.95, 0.98), Color(0.8, 0.83, 0.88), 6, 8, 4))
		b.add_theme_stylebox_override("hover", GameUI.box(Color(0.86, 0.91, 1.0), GameUI.ACCENT.lightened(0.3), 6, 8, 4))
		b.add_theme_stylebox_override("pressed", GameUI.box(GameUI.ACCENT, GameUI.ACCENT.darkened(0.2), 6, 8, 4))
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(c, GameUI.INK)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.toggled.connect(func(_on: bool): refresh())
		row.add_child(b)
		out[option[0]] = b
	return out


func setup(p_state: Mission03State) -> void:
	state = p_state


func open(p_host: String) -> void:
	if host != p_host:
		host = p_host
		for edit: LineEdit in [ip_edit, mask_edit, gateway_edit]:
			edit.clear()
		for b: Button in ping_buttons.values() + status_buttons.values():
			b.set_pressed_no_signal(false)
	visible = true
	refresh()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _picked(buttons: Dictionary) -> String:
	for id: String in buttons:
		if (buttons[id] as Button).button_pressed:
			return id
	return ""


## Fills the form (used by tests).
func fill(ip: String, mask: String, gateway: String, ping: String, status: String) -> void:
	ip_edit.text = ip
	mask_edit.text = mask
	gateway_edit.text = gateway
	if ping_buttons.has(ping):
		(ping_buttons[ping] as Button).button_pressed = true
	if status_buttons.has(status):
		(status_buttons[status] as Button).button_pressed = true
	refresh()


func refresh() -> void:
	if state == null or host == "":
		return
	_subtitle.text = "%s  (%s)  ·  เครื่องที่ %d/3" % [Mission03State.TITLES.get(host, host), host, Mission03State.TARGETS.find(host) + 1]
	var act: Dictionary = state.activity.get(host, {})
	var done := state.records.has(host)
	_steps.text = "%s ใช้คำสั่ง ipconfig ดูข้อมูลเครือข่าย\n%s ใช้คำสั่ง ping ไปที่ Default Gateway" % [
		"✓" if act.get("ipconfig", false) or done else "•", "✓" if act.get("ping", false) or done else "•"]
	var count := state.records.size()
	_progress.text = "แนบผลแล้ว %d/3 เครื่อง" % count
	for edit: LineEdit in [ip_edit, mask_edit, gateway_edit]:
		edit.editable = not done
	for b: Button in ping_buttons.values() + status_buttons.values():
		b.disabled = done
	if done:
		var r: Dictionary = state.records[host]
		ip_edit.text = r["ip"]
		mask_edit.text = r["mask"]
		gateway_edit.text = r["gateway"]
		(ping_buttons[r["ping"]] as Button).set_pressed_no_signal(true)
		(status_buttons[r["status"]] as Button).set_pressed_no_signal(true)
		attach_button.disabled = true
		attach_button.text = "แนบผลแล้ว ✓"
		_hint.text = ""
		return
	attach_button.text = "แนบผลลงรายงาน"
	var missing := missing_items()
	attach_button.disabled = not missing.is_empty()
	_hint.text = "" if missing.is_empty() else "ยังแนบไม่ได้: " + ", ".join(missing)


## What still stops the row from being attached.
func missing_items() -> PackedStringArray:
	var out := PackedStringArray()
	var act: Dictionary = state.activity.get(host, {})
	if not act.get("ipconfig", false):
		out.append("ใช้ ipconfig")
	if not act.get("ping", false):
		out.append("ใช้ ping")
	# Short, so the panel still fits a 720 px screen.
	for edit: LineEdit in [ip_edit, mask_edit, gateway_edit]:
		if edit.text.strip_edges() == "":
			out.append("กรอกค่าให้ครบ 3 ช่อง")
			break
	if _picked(ping_buttons) == "" or _picked(status_buttons) == "":
		out.append("เลือกผล ping และสถานะ")
	return out


func attach() -> void:
	if state == null or host == "" or not missing_items().is_empty():
		return
	if state.attach(host, ip_edit.text, mask_edit.text, gateway_edit.text, _picked(ping_buttons), _picked(status_buttons)):
		Sound.play("confirm")
		refresh()
		attached.emit(host)
