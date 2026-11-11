extends Control
class_name MenuBreeze

## Small looping foreground drift for the illustrated school menu.
## All positions are computed from time, so the loop has no accumulating state.
const LOOP_SECONDS := 7.0
const PETAL_COUNT := 22
var _petal := PackedVector2Array([
	Vector2(0, -8), Vector2(5, -5), Vector2(7, 0),
	Vector2(3, 8), Vector2(0, 10), Vector2(-4, 6), Vector2(-7, 0), Vector2(-4, -5)
])
var _colors := [
	Color("ffe2eddd"), Color("ffd0e5d9"), Color("fff6f1d0"),
	Color("f7a9c8cc"), Color("dcecb3aa")
]

var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed = fposmod(elapsed + delta, LOOP_SECONDS)
	queue_redraw()

func _draw() -> void:
	var width := size.x
	var height := size.y
	if width < 1.0 or height < 1.0:
		return
	for index in PETAL_COUNT:
		var seed := float(index) * 17.713
		var phase := fposmod(elapsed / LOOP_SECONDS + float(index) / PETAL_COUNT, 1.0)
		var y := -22.0 + phase * (height + 50.0)
		var x_start := fposmod(sin(seed * 2.17) * 473.0 + 511.0, width + 130.0) - 65.0
		var x := x_start + phase * 105.0 + sin(phase * TAU * 2.0 + seed) * 17.0
		var scale_factor := 0.48 + fposmod(seed, 1.0) * 0.43
		var angle := phase * TAU * (1.0 + fposmod(seed * 0.17, 1.0)) + seed
		draw_set_transform(Vector2(x, y), angle, Vector2.ONE * scale_factor)
		draw_colored_polygon(_petal, _colors[index % _colors.size()])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
