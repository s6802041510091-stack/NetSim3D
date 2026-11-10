class_name PlugBoard
extends Node

## Plugging cables in by hand, shared by every place that has sockets (the
## LAN cable tester now; the Wall Rack and the teacher PC later).
##   - Views: a fixed list of camera poses the caller defines (e.g. the whole
##     device, socket A close up, socket B close up; or device 1 / device 2,
##     top / bottom). Q goes to the previous one, E to the next; the camera
##     glides there, so the player always knows what each view shows.
##   - Plugs: RJ45 heads (Node3D, -Z points the way the head goes in). The
##     player presses on a head, drags it, and lets go over a free socket;
##     the head lines up in front of the socket and slides in with a click.
##   - Sockets: Node3D points whose -Z goes into the socket (like
##     CableTester's *_PlugPoint). A free socket glows while a head is dragged
##     near it.
## When every head is in a socket, the view stays a moment (PLUGGED_HOLD)
## and then `all_plugged` fires. Only the sockets passed to begin() take a
## head (e.g. the ports a work order names); a drop anywhere else sends the
## head back. Heads move on `drag_plane` (default: level, at the height the
## head lay at; a wall rack or the back of a PC uses an upright plane).
## Keys work only while `active`; a small bar at the bottom shows the view
## name and the Q / E keys (top left of the screen).

signal plugged(plug_id: String, socket_id: String)
signal all_plugged
signal plug_moved(plug_id: String)
signal view_changed(index: int)

const VIEW_TIME := 0.4
const PLUGGED_HOLD := 1.0
const PICK_PX := 34.0
const SNAP_PX := 60.0
## How far in front of the socket the head lines up before sliding in (m).
const SLIDE_OUT := 0.03
const SLIDE_TIME := 0.25

var camera: Camera3D
var active := false
## [{"name": String, "xform": Transform3D}]
var views: Array = []
var view_index := 0
var plugs := {} # id -> Node3D
var sockets := {} # id -> Node3D
var required: PackedStringArray = []
var connected := {} # socket id -> plug id
var hint := "ลากหัว RJ45 ไปเสียบที่ช่อง"
## Upright plane for dragging in front of a panel of ports; a zero normal
## means "level, at the head's height".
var drag_plane := Plane(Vector3.ZERO, 0.0)
## Size of the green glow on a socket (the tester's sockets are drawn 1.6x).
var glow_size := Vector3(0.026, 0.02, 0.012)

var _homes := {} # plug id -> Transform3D (global)
var _drag := ""
## While dragging, the head slides on the level it lay on (the desk / mat).
var _drag_height := 0.0
var _near := ""
var _busy := false
var _view_tween: Tween
var _glow: MeshInstance3D
var _bar: CanvasLayer
var _bar_label: Label
var _hint_label: Label


func _ready() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 23
	_bar.visible = false
	add_child(_bar)
	var panel := PanelContainer.new()
	panel.name = "ViewBar"
	# Top left: heads and cables usually lie low in the picture.
	panel.offset_left = 20
	panel.offset_top = 20
	panel.add_theme_stylebox_override("panel", GameUI.box(Color(0.06, 0.08, 0.12, 0.82), Color(0.4, 0.6, 0.95, 0.6), 8, 16, 8))
	_bar.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	_bar_label = GameUI.label("", 18, Color.WHITE, true)
	col.add_child(_bar_label)
	_hint_label = GameUI.label("", 14, Color(0.75, 0.8, 0.88))
	col.add_child(_hint_label)


## Starts plugging. `view_list` as in `views`; the camera is assumed to be at
## view 0 already. Plug homes are where the heads are now.
## `keep_view`: the camera stays on the current view (a next step at the
## same place, same view list).
func begin(cam: Camera3D, view_list: Array, plug_nodes: Dictionary, socket_nodes: Dictionary, required_sockets: PackedStringArray = PackedStringArray(), keep_view := false) -> void:
	camera = cam
	if not keep_view or view_list.size() != views.size():
		view_index = 0
	views = view_list
	plugs = plug_nodes
	sockets = socket_nodes
	required = required_sockets if not required_sockets.is_empty() else PackedStringArray(socket_nodes.keys())
	connected.clear()
	_homes.clear()
	for id: String in plugs:
		_homes[id] = (plugs[id] as Node3D).global_transform
	active = true
	_busy = false
	_bar.visible = true
	_refresh_bar()


## Stops plugging. `keep_view`: let a camera glide that has started finish.
func end(keep_view := false) -> void:
	active = false
	_drag = ""
	_set_glow("")
	_bar.visible = false
	if not keep_view and _view_tween and _view_tween.is_valid():
		_view_tween.kill()


func is_plugged(plug_id: String) -> bool:
	return plug_id in connected.values()


## Moves to view `index` (wraps round).
func go_to_view(index: int) -> void:
	if views.is_empty() or camera == null:
		return
	view_index = posmod(index, views.size())
	if _view_tween and _view_tween.is_valid():
		_view_tween.kill()
	_view_tween = create_tween()
	_view_tween.tween_property(camera, "global_transform", views[view_index]["xform"], VIEW_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sound.play("select")
	_refresh_bar()
	view_changed.emit(view_index)


## Puts `plug_id` into `socket_id`: lines up in front of it, slides in.
## Also what dropping a dragged head on a socket does.
func plug_into(plug_id: String, socket_id: String) -> bool:
	if not plugs.has(plug_id) or not sockets.has(socket_id) or connected.has(socket_id) or is_plugged(plug_id):
		return false
	connected[socket_id] = plug_id
	var head: Node3D = plugs[plug_id]
	var socket: Node3D = sockets[socket_id]
	var inside := Transform3D(socket.global_basis.orthonormalized(), socket.global_position)
	var front := inside.translated(inside.basis.z * SLIDE_OUT)
	var tween := create_tween()
	tween.tween_method(func(t: Transform3D): _move_head(plug_id, t), head.global_transform, front, 0.12)
	tween.tween_method(func(t: Transform3D): _move_head(plug_id, t), front, inside, SLIDE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): Sound.play("crimp", socket, -6.0))
	plugged.emit(plug_id, socket_id)
	if _all_done():
		_finish_after(tween)
	return true


## The last head is in: let the player see it a moment, then report.
func _finish_after(tween: Tween) -> void:
	_busy = true
	await tween.finished
	await get_tree().create_timer(PLUGGED_HOLD).timeout
	_busy = false
	if active:
		all_plugged.emit()


func _all_done() -> bool:
	for id: String in plugs:
		if not is_plugged(id):
			return false
	return true


func _move_head(plug_id: String, xform: Transform3D) -> void:
	var head: Node3D = plugs.get(plug_id)
	if head == null or not is_instance_valid(head):
		return
	head.global_transform = xform
	plug_moved.emit(plug_id)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not active or camera == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_Q or key == KEY_E:
			get_viewport().set_input_as_handled()
			if _drag == "":
				go_to_view(view_index + (1 if key == KEY_E else -1))
		return
	if _busy:
		return
	if event is InputEventMouseMotion and _drag != "":
		var at := (event as InputEventMouseMotion).position
		var head: Node3D = plugs[_drag]
		var plane := drag_plane if drag_plane.normal != Vector3.ZERO else Plane(Vector3.UP, _drag_height)
		var hit: Variant = plane.intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
		if hit != null:
			_move_head(_drag, Transform3D(head.global_basis, hit))
		_near = _socket_near(at)
		_set_glow(_near)
		return
	if not event is InputEventMouseButton or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var button := event as InputEventMouseButton
	if button.pressed:
		var id := _plug_at(button.position)
		if id != "":
			get_viewport().set_input_as_handled()
			_drag = id
			_drag_height = (_homes[id] as Transform3D).origin.y
			Sound.play("select")
		return
	if _drag == "":
		return
	get_viewport().set_input_as_handled()
	var id := _drag
	_drag = ""
	var target := _socket_near(button.position)
	_set_glow("")
	if target != "":
		plug_into(id, target)
	else:
		# Not over a free socket: the head goes back where it lay.
		var tween := create_tween()
		tween.tween_method(func(t: Transform3D): _move_head(id, t), (plugs[id] as Node3D).global_transform, _homes[id], 0.2)


func _plug_at(at: Vector2) -> String:
	var best := ""
	var best_d := PICK_PX
	for id: String in plugs:
		if is_plugged(id):
			continue
		var p: Vector3 = (plugs[id] as Node3D).global_position
		if camera.is_position_behind(p):
			continue
		var d := camera.unproject_position(p).distance_to(at)
		if d < best_d:
			best_d = d
			best = id
	return best


func _socket_near(at: Vector2) -> String:
	var best := ""
	var best_d := SNAP_PX
	for id: String in sockets:
		if connected.has(id):
			continue
		var p: Vector3 = (sockets[id] as Node3D).global_position
		if camera.is_position_behind(p):
			continue
		var d := camera.unproject_position(p).distance_to(at)
		if d < best_d:
			best_d = d
			best = id
	return best


## Screen points, for tests and hints.
func plug_screen_point(plug_id: String) -> Vector2:
	return camera.unproject_position((plugs[plug_id] as Node3D).global_position)


func socket_screen_point(socket_id: String) -> Vector2:
	return camera.unproject_position((sockets[socket_id] as Node3D).global_position)


## A soft glow in front of the socket a dragged head would go into.
func _set_glow(socket_id: String) -> void:
	if socket_id == "" or not sockets.has(socket_id):
		if _glow:
			_glow.visible = false
		return
	if _glow == null:
		_glow = MeshInstance3D.new()
		_glow.name = "SocketGlow"
		var box := BoxMesh.new()
		box.size = glow_size
		_glow.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 1.0, 0.45, 0.45)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		_glow.material_override = material
		add_child(_glow)
	var socket: Node3D = sockets[socket_id]
	(_glow.mesh as BoxMesh).size = glow_size
	_glow.global_transform = Transform3D(socket.global_basis.orthonormalized(), socket.global_position + socket.global_basis.z.normalized() * glow_size.z * 0.5)
	_glow.visible = true


func _refresh_bar() -> void:
	if views.is_empty():
		_bar_label.text = ""
	else:
		_bar_label.text = "◀ Q    %s  (%d/%d)    E ▶" % [views[view_index]["name"], view_index + 1, views.size()]
	_hint_label.text = hint


## A real-size RJ45 plug with a coloured boot, its tip at the origin and the
## cable side along +Z (as the rack and the PC draw plugged cables).
static func make_head(boot_color: Color) -> Node3D:
	var head := Node3D.new()
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.85, 0.9, 0.95, 0.55)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.2
	var boot := StandardMaterial3D.new()
	boot.albedo_color = boot_color
	boot.roughness = 0.6
	for part in [[Vector3(0.0112, 0.0082, 0.014), Vector3(0, 0, 0.007), clear], [Vector3(0.0128, 0.0108, 0.02), Vector3(0, 0, 0.024), boot]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		mesh.material_override = part[2]
		head.add_child(mesh)
	return head
