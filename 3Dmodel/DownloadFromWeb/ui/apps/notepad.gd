extends Control
## Minimal Notepad (used on student PCs for the Veyon remote-control task).

var editor: TextEdit


func _ready() -> void:
	var v := UIKit.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	var menu := UIKit.hbox(14)
	for m in ["File", "Edit", "View"]:
		menu.add_child(UIKit.label(m, 13))
	v.add_child(UIKit.margin(menu, 6))
	editor = TextEdit.new()
	UIKit.expand(editor)
	editor.add_theme_font_override("font", UIKit.mono_font())
	editor.add_theme_stylebox_override("normal", UIKit.box(Color.WHITE, UIKit.BORDER, 0))
	editor.add_theme_color_override("font_color", UIKit.TEXT)
	editor.add_theme_color_override("caret_color", UIKit.TEXT)
	v.add_child(editor)
