extends Node3D
class_name ComputerScreen
## Shows a SimDesktop on a 3D monitor and lets the player use it.
##
## Two ways to use it (pick one per computer):
##   A) Full-screen (recommended for gameplay): player presses E at the PC -> open_fullscreen()
##      The desktop covers the game view; Esc / close_fullscreen() returns to 3D.
##   B) On the 3D monitor: the desktop is rendered into a SubViewport texture on `screen_mesh`.
##      Forward clicks with push_click(hit_world_position, event) from your raycast code.
##
## The same SimDesktop instance is used in both modes, so open windows stay open.

signal fullscreen_changed(is_open: bool)

@export var screen_mesh: MeshInstance3D     ## a QuadMesh / PlaneMesh that is the monitor glass
@export var resolution := Vector2i(1280, 720)
@export var machine_name := "TEACHER-PC"
@export var user_name := "Teacher"
@export var apps: Array[String] = SimDesktop.TEACHER_APPS
@export var screen_brightness := 1.0

var desktop: SimDesktop
var viewport: SubViewport
var is_fullscreen := false
var _layer: CanvasLayer


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = resolution
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	add_child(viewport)
	desktop = SimDesktop.new()
	desktop.machine_name = machine_name
	desktop.user_name = user_name
	desktop.apps = apps
	desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(desktop)
	if screen_mesh:
		var m := StandardMaterial3D.new()
		m.albedo_texture = viewport.get_texture()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(screen_brightness, screen_brightness, screen_brightness)
		screen_mesh.material_override = m


func open_fullscreen() -> void:
	if is_fullscreen:
		return
	is_fullscreen = true
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	desktop.reparent(_layer, false)
	desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetSim.log_action("computer_used", {"machine": machine_name})
	fullscreen_changed.emit(true)


func close_fullscreen() -> void:
	if not is_fullscreen:
		return
	is_fullscreen = false
	desktop.reparent(viewport, false)
	desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.queue_free()
	fullscreen_changed.emit(false)


func _unhandled_input(e: InputEvent) -> void:
	if is_fullscreen and e.is_action_pressed("ui_cancel"):
		close_fullscreen()
		get_viewport().set_input_as_handled()


## Mode B: forward a mouse event that hit the monitor at `hit` (world position).
func push_click(hit: Vector3, event: InputEvent) -> void:
	var uv := world_to_uv(hit)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return
	var ev := event.duplicate()
	if ev is InputEventMouse:
		ev.position = uv * Vector2(resolution)
		ev.global_position = ev.position
	viewport.push_input(ev)


## World position on the screen quad -> 0..1 UV (top-left = 0,0). Works for QuadMesh / PlaneMesh.
func world_to_uv(hit: Vector3) -> Vector2:
	var local := screen_mesh.to_local(hit)
	var size2 := Vector2.ONE
	var plane_xz := false
	if screen_mesh.mesh is QuadMesh:
		size2 = (screen_mesh.mesh as QuadMesh).size
	elif screen_mesh.mesh is PlaneMesh:
		size2 = (screen_mesh.mesh as PlaneMesh).size
		plane_xz = true
	if plane_xz:
		return Vector2(local.x / size2.x + 0.5, local.z / size2.y + 0.5)
	return Vector2(local.x / size2.x + 0.5, 0.5 - local.y / size2.y)
