extends RefCounted
## Presentation only. DesktopOS owns network checks and page_opened signals.

const NAVY := Color("182f59")
const GOLD := Color("f2c34e")
const INK := Color("24334a")
const MUTED := Color("617089")
const CAMPUS := preload("res://assets/ui/school_spring_background.png")


static func text(value: String, size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func panel(color: Color, padding: int = 16, radius: int = 0) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	box.add_theme_stylebox_override("panel", style)
	return box


static func button(caption: String, primary: bool = false) -> Button:
	var control := Button.new()
	control.text = caption
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if primary else Color("eef2f8")
		if state == "hover" or state == "focus":
			style.bg_color = style.bg_color.lightened(0.12) if primary else Color("dce7f7")
		if state == "pressed":
			style.bg_color = style.bg_color.darkened(0.08)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		control.add_theme_stylebox_override(state, style)
		control.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", NAVY)
	return control


static func paragraph(value: String, size: int = 15, color: Color = INK) -> Label:
	var label := text(value, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func column(parent: Node, separation: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


static func jump(page: Control, target: Control) -> void:
	var scroll := page.get_parent() as ScrollContainer
	if scroll:
		scroll.ensure_control_visible(target)


static func build(page: Control, url: String) -> void:
	var utility := panel(NAVY, 5)
	page.add_child(utility)
	var utility_text := text("เว็บไซต์วิทยาลัย  /  ข้อมูลข่าวสารและบริการนักศึกษา", 12, Color("e2e9f4"))
	utility_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	utility.add_child(utility_text)

	var masthead := panel(Color.WHITE, 16)
	page.add_child(masthead)
	var mast := HBoxContainer.new()
	mast.add_theme_constant_override("separation", 14)
	masthead.add_child(mast)
	var crest := panel(NAVY, 8, 10)
	mast.add_child(crest)
	crest.add_child(text("ETC", 24, GOLD))
	var nameplate := column(mast, 0)
	nameplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nameplate.add_child(text("วิทยาลัยเทคนิคตัวอย่าง", 24, NAVY))
	nameplate.add_child(text("EXAMPLE TECHNICAL COLLEGE", 11, MUTED))
	var home := button("หน้าแรก", true)
	mast.add_child(home)
	home.pressed.connect(func():
		var scroll := page.get_parent() as ScrollContainer
		if scroll:
			scroll.scroll_vertical = 0)

	var hero := panel(NAVY, 20)
	page.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 16)
	hero.add_child(hero_row)
	var pitch := column(hero_row, 8)
	pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch.size_flags_stretch_ratio = 1.2
	pitch.add_child(paragraph("เรียนรู้ • ลงมือทำ • สร้างอนาคต", 14, GOLD))
	pitch.add_child(paragraph("สร้างทักษะอาชีพ\nสู่อนาคตที่มั่นคง", 29, Color.WHITE))
	pitch.add_child(paragraph("เปิดรับสมัครนักศึกษาใหม่ ระดับ ปวช. และ ปวส.", 15, Color("dce5f4")))
	var courses_button := button("ดูหลักสูตรที่เปิดสอน  →", true)
	courses_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pitch.add_child(courses_button)
	var photo := TextureRect.new()
	photo.texture = CAMPUS
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.custom_minimum_size = Vector2(180, 170)
	photo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(photo)

	var content := panel(Color("f5f7fb"), 16)
	page.add_child(content)
	var sections := column(content, 14)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 8)
	sections.add_child(shortcuts)
	var news_link := button("ข่าวประชาสัมพันธ์")
	var courses_link := button("หลักสูตรที่เปิดสอน")
	var calendar_link := button("ปฏิทินการศึกษา")
	for link in [news_link, courses_link, calendar_link]:
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shortcuts.add_child(link)

	var news_heading := text("ข่าวประชาสัมพันธ์", 21, NAVY)
	sections.add_child(news_heading)
	var news := HBoxContainer.new()
	news.add_theme_constant_override("separation", 10)
	sections.add_child(news)
	var items := [
		["รับสมัครนักศึกษาใหม่", "สมัครเรียนระดับ ปวช. และ ปวส.\nสอบถามรายละเอียดที่งานทะเบียน", "งานรับสมัคร"],
		["ประกาศตารางสอบ", "ตรวจสอบวันสอบปลายภาค\nและเตรียมบัตรประจำตัวนักศึกษา", "งานวิชาการ"],
		["เปิดบ้านวิทยาลัย", "รู้จักแผนกวิชาและเยี่ยมชม\nห้องปฏิบัติการของวิทยาลัย", "กิจกรรมนักศึกษา"],
	]
	for item in items:
		var card := panel(Color.WHITE, 12, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		news.add_child(card)
		var details := column(card, 6)
		details.add_child(text(item[2], 12, Color("95701e")))
		details.add_child(paragraph(item[0], 17, NAVY))
		details.add_child(paragraph(item[1], 14, MUTED))

	var courses_heading := text("หลักสูตรที่เปิดสอน", 21, NAVY)
	sections.add_child(courses_heading)
	sections.add_child(paragraph("ปวช.  /  ปวส.   •   เทคโนโลยีสารสนเทศ   •   ช่างไฟฟ้า   •   ช่างยนต์   •   การบัญชี", 15))
	var calendar_heading := text("ปฏิทินการศึกษา", 21, NAVY)
	sections.add_child(calendar_heading)
	sections.add_child(paragraph("ติดตามกำหนดการลงทะเบียน เปิดภาคเรียน และสอบปลายภาคได้ที่งานวิชาการของวิทยาลัย", 15))
	courses_button.pressed.connect(func(): jump(page, courses_heading))
	courses_link.pressed.connect(func(): jump(page, courses_heading))
	news_link.pressed.connect(func(): jump(page, news_heading))
	calendar_link.pressed.connect(func(): jump(page, calendar_heading))

	var footer := panel(NAVY, 12)
	page.add_child(footer)
	var footer_column := column(footer, 2)
	footer_column.add_child(text("วิทยาลัยเทคนิคตัวอย่าง  |  งานประชาสัมพันธ์และบริการนักศึกษา", 13, Color.WHITE))
	footer_column.add_child(paragraph("เชื่อมต่อสำเร็จ: " + url, 12, Color("91e4b3")))
