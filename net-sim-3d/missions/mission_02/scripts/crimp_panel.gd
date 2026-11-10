class_name CrimpPanel
extends CanvasLayer

## The step panel at the crimping desk (right side of the screen) and the
## order of work for the 4 cable ends: cable 1 end 1, cable 1 end 2, cable 2
## end 1, cable 2 end 2. Each end: (cut) -> strip -> untwist -> arrange the
## colours -> trim -> insert into the RJ45 head -> crimp. Every step is one
## button except arranging, where the player clicks the 8 wires into pins 1-8.
## The arrangement is confirmed once (Mission02State.ends) — no changes later.
## The player may stand up (Esc) and come back; work resumes where it stopped.

signal leave_requested
signal end_finished(key: String)
signal all_done

const ENDS := ["1A", "1B", "2A", "2B"]
## Seconds the crimped head stays on screen before the next end.
const CRIMPED_HOLD := 0.9
## cable -> [route, length]
const CABLES := {
	1: ["Router → Switched Hub 24 Port", "0.5 เมตร"],
	2: ["Switched Hub 24 Port → คอมพิวเตอร์ครู", "6 เมตร"],
}
## step -> [title, what to do, tool shown, look after the step, sound]
const STEPS := {
	"cut": ["ตัดสาย", "ตัดสาย UTP Cat6 ยาว %s ด้วยใบมีดของคีมย้ำสาย", "crimping_tool", CrimpBench.Look.CUT, "snip"],
	"strip": ["ปอกฉนวน", "ปอกฉนวนด้านนอกออกประมาณ 2.5 ซม. ด้วยคีมปอกสาย", "cable_stripper", CrimpBench.Look.STRIPPED, "snip"],
	"untwist": ["คลายเกลียว", "คลายเกลียวสายแต่ละคู่ แล้วจัดเส้นลวดทั้ง 8 เส้นให้ตรง", "", CrimpBench.Look.UNTWISTED, "click"],
	"arrange": ["เรียงสี T568B", "", "", CrimpBench.Look.ARRANGED, ""],
	"trim": ["ตัดปลายให้เสมอ", "ตัดปลายสายทั้ง 8 เส้นให้เสมอกัน เหลือยาวประมาณ 1.3 ซม.", "crimping_tool", CrimpBench.Look.TRIMMED, "snip"],
	"insert": ["เสียบหัว RJ45", "เสียบสายเข้าหัว RJ45 ให้ครบทั้ง 8 เส้น โดยไม่ให้ตำแหน่งสลับกัน", "", CrimpBench.Look.INSERTED, "click"],
	"crimp": ["ย้ำหัว", "ใส่หัว RJ45 ในช่องของคีมย้ำสาย แล้วบีบให้สุด", "crimping_tool", CrimpBench.Look.CRIMPED, "crimp"],
}
const ARRANGE_HELP := "เรียงสายตามมาตรฐาน T568B จากขา 1 ถึงขา 8 (มองจากด้านบน ขา 1 อยู่ซ้ายสุด)\nคลิกสีเพื่อวางลงขาถัดไป คลิกที่ขาเพื่อเอาสายออก — ยืนยันแล้วแก้ไม่ได้"

var bench: CrimpBench
var state: Mission02State
var end_index := 0
var step_index := 0
var busy := false
var arrangement: Array = ["", "", "", "", "", "", "", ""]

var _rng := RandomNumberGenerator.new()
var _title: Label
var _subtitle: Label
var _progress: Label
var _steps_box: VBoxContainer
var _action_box: VBoxContainer
var _leave: Button
var _pin_buttons: Array[Button] = []
var _chip_buttons := {}
var _confirm_arrange: Button


func _ready() -> void:
	layer = 22
	visible = false
	_rng.randomize()
	var panel := PanelContainer.new()
	panel.name = "CrimpPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_right = -14
	panel.offset_top = 14
	panel.offset_bottom = -14
	panel.add_theme_stylebox_override("panel", GameUI.box(Color(1, 1, 1, 0.97), Color(0.8, 0.83, 0.88), 12, 20, 16))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_title = GameUI.label("เข้าหัวสาย LAN", 21, GameUI.INK, true)
	col.add_child(_title)
	_subtitle = GameUI.label("", 15, GameUI.INK_SOFT)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_subtitle)
	_progress = GameUI.label("", 14, GameUI.INK_SOFT)
	col.add_child(_progress)
	col.add_child(HSeparator.new())
	_steps_box = VBoxContainer.new()
	_steps_box.add_theme_constant_override("separation", 2)
	col.add_child(_steps_box)
	col.add_child(HSeparator.new())
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 8)
	_action_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_action_box)
	_leave = GameUI.button("ลุกจากโต๊ะ (Esc)", false, 200)
	_leave.name = "LeaveButton"
	_leave.set_meta("sound", "back")
	_leave.pressed.connect(func(): if not busy: leave_requested.emit())
	col.add_child(_leave)


func setup(work_bench: CrimpBench, mission_state: Mission02State) -> void:
	bench = work_bench
	state = mission_state


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_bench()
	_refresh()


func close() -> void:
	visible = false


func is_done() -> bool:
	return end_index >= ENDS.size()


func current_key() -> String:
	return ENDS[end_index] if not is_done() else ""


func current_step() -> String:
	if is_done():
		return ""
	var steps := _steps_for(current_key())
	return steps[step_index] if step_index < steps.size() else ""


## Does the current one-button step (cut, strip, untwist, trim, insert, crimp).
func do_step() -> void:
	var step := current_step()
	if busy or step == "" or step == "arrange":
		return
	busy = true
	_refresh()
	var info: Array = STEPS[step]
	if String(info[4]) != "":
		Sound.play(info[4])
	if String(info[2]) != "" and bench:
		await bench.play_tool(info[2], 0.55)
	if step == "crimp" and bench:
		# Let the player see the finished head before the next end.
		bench.show_state(CrimpBench.Look.CRIMPED, state.ends.get(current_key(), arrangement))
		await get_tree().create_timer(CRIMPED_HOLD).timeout
	_advance()
	busy = false
	_refresh()


## Puts wire `id` into the first empty pin.
func place_wire(id: String) -> void:
	if current_step() != "arrange" or id in arrangement:
		return
	var pin := arrangement.find("")
	if pin < 0:
		return
	arrangement[pin] = id
	Sound.play("select")
	_show_bench()
	_refresh()


func remove_pin(pin: int) -> void:
	if current_step() != "arrange" or pin < 0 or pin >= 8 or arrangement[pin] == "":
		return
	arrangement[pin] = ""
	Sound.play("back")
	_show_bench()
	_refresh()


func clear_arrangement() -> void:
	if current_step() != "arrange":
		return
	arrangement = ["", "", "", "", "", "", "", ""]
	_show_bench()
	_refresh()


## Saves the 8 wires of this end (once) and moves on.
func confirm_arrangement() -> void:
	if current_step() != "arrange" or "" in arrangement:
		return
	state.ends[current_key()] = arrangement.duplicate()
	Sound.play("confirm")
	_advance()
	_refresh()


func _advance() -> void:
	var key := current_key()
	step_index += 1
	if step_index >= _steps_for(key).size():
		end_finished.emit(key)
		end_index += 1
		step_index = 0
		arrangement = ["", "", "", "", "", "", "", ""]
		if is_done():
			all_done.emit()
			return
	_show_bench()


func _steps_for(key: String) -> PackedStringArray:
	var steps := PackedStringArray(["strip", "untwist", "arrange", "trim", "insert", "crimp"])
	if key.ends_with("A"):
		steps.insert(0, "cut")
	return steps


## The cable end as it looks before the current step.
func _show_bench() -> void:
	if bench == null or is_done():
		return
	var key := current_key()
	var steps := _steps_for(key)
	if step_index == 0:
		bench.show_state(CrimpBench.Look.WHOLE if key.ends_with("A") else CrimpBench.Look.CUT)
		return
	var done_step := steps[step_index - 1]
	var look: CrimpBench.Look = STEPS[done_step][3]
	if current_step() == "arrange":
		# Loose wires until the first one is placed, then the pins filled so far.
		var any := arrangement.any(func(id: String): return id != "")
		bench.show_state(CrimpBench.Look.ARRANGED if any else CrimpBench.Look.UNTWISTED, arrangement)
		return
	bench.show_state(look, state.ends.get(key, arrangement))


func _refresh() -> void:
	for child in _steps_box.get_children():
		child.queue_free()
	for child in _action_box.get_children():
		child.queue_free()
	_pin_buttons.clear()
	_chip_buttons.clear()
	if is_done():
		_subtitle.text = "เข้าหัวครบทั้ง 2 เส้นแล้ว"
		_progress.text = ""
		return
	var key := current_key()
	var cable := int(key.substr(0, 1))
	_subtitle.text = "สายเส้นที่ %d: %s  ·  ปลายที่ %d จาก 2" % [cable, CABLES[cable][0], 1 if key.ends_with("A") else 2]
	var marks := []
	for i in ENDS.size():
		var label := "เส้น %s ปลาย %s" % [ENDS[i].substr(0, 1), "1" if ENDS[i].ends_with("A") else "2"]
		marks.append(("[เสร็จ] " if i < end_index else ("[กำลังทำ] " if i == end_index else "")) + label)
	_progress.text = "   ".join(PackedStringArray(marks.slice(0, 2))) + "\n" + "   ".join(PackedStringArray(marks.slice(2, 4)))
	var steps := _steps_for(key)
	var step := current_step()
	if step == "arrange":
		# Room for the pins and wires: just one line for the steps.
		_steps_box.add_child(GameUI.label("ขั้นที่ %d จาก %d:  %s" % [step_index + 1, steps.size(), STEPS[step][0]], 15, GameUI.ACCENT, true))
	else:
		for i in steps.size():
			var title: String = STEPS[steps[i]][0]
			var color := GameUI.OK if i < step_index else (GameUI.ACCENT if i == step_index else GameUI.INK_SOFT)
			var line := GameUI.label(("%d. " % (i + 1)) + title + ("  (เสร็จ)" if i < step_index else ""), 15, color, i == step_index)
			_steps_box.add_child(line)
	if step == "arrange":
		_build_arrange()
	else:
		var text: String = STEPS[step][1]
		if step == "cut":
			text = text % CABLES[cable][1]
		var help := GameUI.label(text, 16, GameUI.INK)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_action_box.add_child(help)
		var go := GameUI.button(STEPS[step][0], true, 240)
		go.name = "StepButton"
		go.set_meta("sound", "")
		go.disabled = busy
		go.pressed.connect(do_step)
		_action_box.add_child(go)
	_leave.disabled = busy


func _build_arrange() -> void:
	var help := GameUI.label(ARRANGE_HELP, 14, GameUI.INK)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_box.add_child(help)
	var pins := HBoxContainer.new()
	pins.add_theme_constant_override("separation", 4)
	_action_box.add_child(pins)
	for pin in 8:
		var slot := Button.new()
		slot.name = "Pin%d" % (pin + 1)
		slot.custom_minimum_size = Vector2(46, 78)
		slot.focus_mode = Control.FOCUS_NONE
		slot.set_meta("sound", "")
		slot.add_theme_stylebox_override("normal", GameUI.box(Color(0.96, 0.97, 0.99), Color(0.78, 0.81, 0.87), 6, 2, 2))
		slot.add_theme_stylebox_override("hover", GameUI.box(Color(0.92, 0.95, 1.0), GameUI.ACCENT.lightened(0.3), 6, 2, 2))
		var id: String = arrangement[pin]
		slot.draw.connect(func():
			var font := slot.get_theme_default_font()
			slot.draw_string(font, Vector2(0, 16), str(pin + 1), HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, 14, GameUI.INK_SOFT)
			if id != "":
				WireColors.draw_wire(slot, Rect2(Vector2(slot.size.x * 0.5 - 9, 22), Vector2(18, slot.size.y - 28)), id))
		slot.tooltip_text = WireColors.thai_name(id) if id != "" else "ขา %d (ว่าง)" % (pin + 1)
		slot.pressed.connect(remove_pin.bind(pin))
		pins.add_child(slot)
		_pin_buttons.append(slot)
	_action_box.add_child(GameUI.label("สายที่ยังไม่ได้วาง", 14, GameUI.INK_SOFT, true))
	var chips := GridContainer.new()
	chips.columns = 2
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	_action_box.add_child(chips)
	for id: String in _chip_order():
		var chip := Button.new()
		chip.name = "Chip_" + id
		chip.custom_minimum_size = Vector2(200, 34)
		chip.focus_mode = Control.FOCUS_NONE
		chip.set_meta("sound", "")
		chip.text = WireColors.thai_name(id)
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.add_theme_font_size_override("font_size", 15)
		# Left margin keeps the text clear of the colour swatch.
		for style_name in ["normal", "hover", "pressed", "disabled"]:
			var bg := Color(1, 1, 1)
			var edge := Color(0.8, 0.83, 0.88)
			if style_name == "hover":
				bg = Color(0.94, 0.96, 1.0)
				edge = GameUI.ACCENT.lightened(0.3)
			elif style_name == "disabled":
				bg = Color(0.93, 0.94, 0.95)
				edge = Color(0.88, 0.89, 0.91)
			var style := GameUI.box(bg, edge, 6, 6, 4)
			style.content_margin_left = 52
			chip.add_theme_stylebox_override(style_name, style)
		chip.add_theme_color_override("font_color", GameUI.INK)
		chip.disabled = id in arrangement
		chip.draw.connect(func():
			if not chip.disabled:
				WireColors.draw_wire(chip, Rect2(Vector2(10, 9), Vector2(30, chip.size.y - 18)), id))
		chip.pressed.connect(place_wire.bind(id))
		chips.add_child(chip)
		_chip_buttons[id] = chip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_action_box.add_child(row)
	var clear := GameUI.button("ล้างทั้งหมด", false, 130)
	clear.name = "ClearButton"
	clear.set_meta("sound", "back")
	clear.pressed.connect(clear_arrangement)
	row.add_child(clear)
	_confirm_arrange = GameUI.button("ยืนยันการเรียงสี", true, 220)
	_confirm_arrange.name = "ConfirmArrangeButton"
	_confirm_arrange.set_meta("sound", "")
	_confirm_arrange.disabled = "" in arrangement
	_confirm_arrange.pressed.connect(confirm_arrangement)
	row.add_child(_confirm_arrange)


## The 8 wires in a mixed order, fixed for this end so chips do not jump around.
var _chip_orders := {}
func _chip_order() -> Array:
	var key := current_key()
	if not _chip_orders.has(key):
		var ids := WireColors.T568B.duplicate()
		for i in range(ids.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp: Variant = ids[i]
			ids[i] = ids[j]
			ids[j] = tmp
		if ids == WireColors.T568B:
			ids.reverse()
		_chip_orders[key] = ids
	return _chip_orders[key]


func _unhandled_input(event: InputEvent) -> void:
	if visible and not busy and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		leave_requested.emit()
