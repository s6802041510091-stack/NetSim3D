class_name Mission03Report
extends CanvasLayer

## Network Inspection Report: opens once all three rows are attached. The
## player reads it through and confirms it (no changes possible any more),
## then takes it back to the Data Center supervisor.

signal confirmed

var state: Mission03State
var confirm_button: Button
var _grid: GridContainer


func _ready() -> void:
	layer = 24
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.name = "ReportCard"
	card.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1, 0.98), Color(0.8, 0.83, 0.88), 14, 26, 20))
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	col.add_child(GameUI.label("Network Inspection Report", 24, GameUI.INK, true))
	col.add_child(GameUI.label("ผลการตรวจรับการเชื่อมต่อเครือข่ายห้องคอมพิวเตอร์ (ตรวจด้วย ipconfig และ ping)", 15, GameUI.INK_SOFT))
	col.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 10)
	col.add_child(_grid)
	col.add_child(HSeparator.new())
	col.add_child(GameUI.label("ตรวจความครบถ้วนของรายงาน แล้วกดยืนยันเพื่อนำไปส่งหัวหน้างาน Data Center", 15, GameUI.INK_SOFT))
	confirm_button = GameUI.button("ยืนยันรายงาน", true, 220)
	confirm_button.name = "ConfirmReport"
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	confirm_button.pressed.connect(confirm)
	col.add_child(confirm_button)


func open(p_state: Mission03State) -> void:
	state = p_state
	for child in _grid.get_children():
		child.queue_free()
	for title in ["ตำแหน่งเครื่อง", "IP Address", "Subnet Mask", "Default Gateway", "ผล ping", "สถานะ", "ผลคำสั่ง"]:
		_grid.add_child(GameUI.label(title, 15, GameUI.INK, true))
	for host: String in Mission03State.TARGETS:
		var r: Dictionary = state.records.get(host, {})
		_grid.add_child(GameUI.label("%s\n%s" % [Mission03State.TITLES[host], host], 15))
		for key in ["ip", "mask", "gateway"]:
			_grid.add_child(GameUI.label(String(r.get(key, "-")), 15))
		var ping := String(r.get("ping", ""))
		_grid.add_child(GameUI.label("ได้รับการตอบกลับ" if ping == Mission03State.REPLY else ("หมดเวลา" if ping == Mission03State.TIMEOUT else "-"), 15))
		var status := String(r.get("status", ""))
		var abnormal := status == Mission03State.ABNORMAL
		_grid.add_child(GameUI.label("ผิดปกติ" if abnormal else ("ปกติ" if status == Mission03State.NORMAL else "-"), 15, GameUI.BAD if abnormal else GameUI.OK, true))
		_grid.add_child(GameUI.label("แนบแล้ว ✓" if not r.is_empty() else "-", 15, GameUI.INK_SOFT))
	visible = true
	Sound.play("popup_open")
	confirm_button.grab_focus()


func is_open() -> bool:
	return visible


func confirm() -> void:
	if not visible or state == null or not state.all_attached():
		return
	state.report_confirmed = true
	visible = false
	Sound.play("confirm")
	confirmed.emit()
