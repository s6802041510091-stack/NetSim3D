extends Control
## Generic program that is installed but not needed for the mission (distractor / student apps).

var app_title := "Program"


func _ready() -> void:
	var p := UIKit.panel(Color.WHITE, Color.TRANSPARENT, 0)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	var l := UIKit.label(app_title, 22, UIKit.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
