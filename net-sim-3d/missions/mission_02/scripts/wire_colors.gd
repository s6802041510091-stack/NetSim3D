class_name WireColors
extends RefCounted

## The 8 wires of a UTP cable, the T568B / T568A orders (pin 1 to 8) and a
## helper to draw a wire as a coloured strip (white wires with a coloured
## stripe). Used by the work order and the crimping step.

const ORANGE := Color(0.95, 0.5, 0.1)
const GREEN := Color(0.15, 0.62, 0.25)
const BLUE := Color(0.15, 0.35, 0.85)
const BROWN := Color(0.45, 0.27, 0.13)
const WHITE := Color(0.96, 0.96, 0.94)

## id -> [Thai name, main colour, striped (white with a colour stripe)]
const WIRES := {
	"white_orange": ["ขาวส้ม", ORANGE, true],
	"orange": ["ส้ม", ORANGE, false],
	"white_green": ["ขาวเขียว", GREEN, true],
	"green": ["เขียว", GREEN, false],
	"white_blue": ["ขาวน้ำเงิน", BLUE, true],
	"blue": ["น้ำเงิน", BLUE, false],
	"white_brown": ["ขาวน้ำตาล", BROWN, true],
	"brown": ["น้ำตาล", BROWN, false],
}
const T568B := ["white_orange", "orange", "white_green", "blue", "white_blue", "green", "white_brown", "brown"]
const T568A := ["white_green", "green", "white_orange", "blue", "white_blue", "orange", "white_brown", "brown"]


static func thai_name(id: String) -> String:
	return String(WIRES[id][0]) if WIRES.has(id) else id


## How many pins of `order` match T568B (0-8).
static func correct_positions(order: Array) -> int:
	var n := 0
	for i in mini(order.size(), 8):
		if String(order[i]) == T568B[i]:
			n += 1
	return n


## Draws wire `id` as a rectangle on `canvas` (a CanvasItem inside _draw).
static func draw_wire(canvas: CanvasItem, rect: Rect2, id: String) -> void:
	if not WIRES.has(id):
		return
	var color: Color = WIRES[id][1]
	if bool(WIRES[id][2]):
		canvas.draw_rect(rect, WHITE)
		# Diagonal-looking stripe: three coloured bands across the white wire.
		var band := rect.size.y / 5.0
		for k in [1, 3]:
			canvas.draw_rect(Rect2(rect.position + Vector2(0, band * k), Vector2(rect.size.x, band)), color)
	else:
		canvas.draw_rect(rect, color)
	canvas.draw_rect(rect, Color(0, 0, 0, 0.35), false, 1.0)
