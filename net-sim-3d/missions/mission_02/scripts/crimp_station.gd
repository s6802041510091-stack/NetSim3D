class_name CrimpStation
extends StaticBody3D

## The work spot on the spare desk: look at it and press F to sit and crimp.
## Holds the CrimpBench (the 3x cable end, shown only while seated) and the
## DeskLayout (work mat, the two cables, the kit). A mission sets `prompt`
## when the player may use it and listens to `used`.

signal used(player: Node)

const COLLISION_LAYER := 8

var prompt := ""
var bench: CrimpBench
## The LAN cable tester, put on the desk for the test step (null before).
var tester: CableTester
var layout: Mission02DeskLayout
var _test_cable: Node3D
## Plugging the test cable by hand (drag, Q / E views).
var plug_board: PlugBoard
var _heads := {}
var _cable_color := Color(0.62, 0.72, 0.84)

## RJ45 plug drawn at the tester's 1.6x scale; the cable under test.
const HEAD_SIZE := Vector3(0.019, 0.013, 0.034)
const CABLE_RADIUS := 0.0045
## The test cable keeps this far to the side of the tester (m).
const SIDE_CLEAR := 0.11
## A head waits this far in front of its socket and to the left of it (m).
const HEAD_FRONT := 0.05
const HEAD_SIDE := 0.045


func _ready() -> void:
	# Off until the mission sets a prompt.
	collision_layer = 0
	collision_mask = 0
	set_meta(&"interactable", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.16, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 0.07, 0)
	add_child(shape)
	layout = Mission02DeskLayout.new()
	add_child(layout)
	bench = CrimpBench.new()
	bench.name = "CrimpBench"
	bench.position = Vector3(0, CrimpBench.JACKET_RADIUS + Mission02DeskLayout.MAT_THICKNESS + 0.002, 0)
	bench.visible = false
	add_child(bench)
	plug_board = PlugBoard.new()
	plug_board.name = "PlugBoard"
	add_child(plug_board)
	plug_board.plug_moved.connect(func(_id: String): _rebuild_cable())


## Shows the prompt and makes the desk spot hit by the interact ray.
func set_prompt(text: String) -> void:
	prompt = text
	collision_layer = COLLISION_LAYER if text != "" else 0


func get_prompt_text() -> String:
	return prompt


## Puts the tester on the desk (main unit's socket towards the player) and
## hides the cable end. Scaled up 1.6x so the LEDs read in the close-up.
func show_tester() -> CableTester:
	if tester == null:
		tester = CableTester.make()
		tester.name = "CableTester"
		tester.scale = Vector3.ONE * 1.6
		add_child(tester)
		var plug := tester.get_plug_point("Main")
		if plug:
			# Turn so the main socket opens towards -X (the player).
			var out := tester.global_basis.inverse() * plug.global_basis.z
			tester.rotation.y = atan2(-1.0, 0.0) - atan2(out.x, out.z)
		tester.position = Vector3(0.02, Mission02DeskLayout.MAT_THICKNESS, 0.0)
	bench.visible = false
	layout.set_side_tester_visible(false)
	tester.visible = true
	return tester


func hide_tester() -> void:
	if tester:
		tester.visible = false
		tester.set_power(false)
	plug_test_cable(false)
	layout.set_side_tester_visible(true)


## The cable under test: two RJ45 heads joined by the cable. Laid on the mat
## beside the tester (`plugged` false) or already in the sockets (true, when
## the player comes back to a cable that was plugged before). `on` false
## takes it away.
func plug_test_cable(on: bool, plugged := true, color := Color(0.62, 0.72, 0.84)) -> void:
	if _test_cable:
		_test_cable.queue_free()
		_test_cable = null
		_heads.clear()
	if not on or tester == null:
		return
	_test_cable = Node3D.new()
	_test_cable.name = "TestCable"
	add_child(_test_cable)
	_cable_color = color
	var sockets := tester_sockets()
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.88, 0.93, 0.98, 0.55)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.15
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.9, 0.75, 0.3)
	var i := 0
	for id in ["A", "B"]:
		var head := Node3D.new()
		head.name = "Head" + id
		_test_cable.add_child(head)
		# The plug body sticks out of the socket along +Z (the node is the tip).
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = HEAD_SIZE
		body.mesh = box
		body.material_override = clear
		body.position = Vector3(0, 0, HEAD_SIZE.z * 0.5)
		head.add_child(body)
		var contacts := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(HEAD_SIZE.x * 0.8, 0.0015, 0.006)
		contacts.mesh = strip
		contacts.material_override = gold
		contacts.position = Vector3(0, HEAD_SIZE.y * 0.5 - 0.001, 0.004)
		head.add_child(contacts)
		if plugged:
			var socket: Node3D = sockets.values()[i]
			head.global_transform = Transform3D(socket.global_basis.orthonormalized(), socket.global_position)
		else:
			head.transform = head_home(i)
		_heads[id] = head
		i += 1
	_rebuild_cable()


## Where head `i` (0 = A by MAIN, 1 = B by REMOTE) lies before plugging, in
## station space: on the mat just in front of its socket and a little to the
## left as seen from that socket's close-up, pointing at the socket, so the
## close-up shows both.
func head_home(i: int) -> Transform3D:
	var socket: Node3D = tester_sockets().values()[i]
	var inv := global_transform.affine_inverse()
	var p := inv * socket.global_position
	var out := global_basis.inverse() * socket.global_basis.z
	out.y = 0.0
	out = out.normalized()
	var right := (-out).cross(Vector3.UP).normalized()
	var at := p + out * HEAD_FRONT - right * HEAD_SIDE
	at.y = Mission02DeskLayout.MAT_THICKNESS + HEAD_SIZE.y * 0.5
	return Transform3D(Basis.looking_at(-out, Vector3.UP), at)


## The heads by id ("A", "B") while the test cable is out.
func test_heads() -> Dictionary:
	return _heads


## The tester's sockets, for PlugBoard: id -> plug point (-Z goes in).
func tester_sockets() -> Dictionary:
	if tester == null:
		return {}
	return {"MAIN": tester.get_plug_point("Main"), "REMOTE": tester.get_plug_point("Remote")}


## Q / E views at the tester: the whole device, then each socket close up.
func tester_views() -> Array:
	var list := [{"name": "ภาพรวมเครื่อง", "xform": tester_view_transform()}]
	var i := 0
	for id: String in tester_sockets():
		var socket: Node3D = tester_sockets()[id]
		var out := socket.global_basis.z.normalized()
		# Aimed between the socket and the head waiting for it, so both show.
		var p := socket.global_position.lerp(global_transform * head_home(i).origin, 0.35)
		i += 1
		var eye := p + out * 0.1 + Vector3.UP * 0.06
		var basis := Basis.looking_at(p - eye, Vector3.UP)
		# Shifted right so the socket sits left of centre, clear of the step panel.
		eye += basis.x * 0.015
		list.append({"name": "ช่อง %s (%s)" % [id, "ตัวแม่" if id == "MAIN" else "ตัวลูก"], "xform": Transform3D(basis, eye)})
	return list


## The cable from head A's tail, along the mat in front of the tester, to
## head B's tail. Rebuilt whenever a head moves.
func _rebuild_cable() -> void:
	if _test_cable == null:
		return
	var old := _test_cable.get_node_or_null("Loop")
	if old:
		old.free()
	if _heads.size() < 2:
		return
	var a: Node3D = _heads["A"]
	var b: Node3D = _heads["B"]
	var inv := global_transform.affine_inverse()
	var pa := inv * a.global_position
	var pb := inv * b.global_position
	var za := (global_basis.inverse() * a.global_basis.z).normalized()
	var zb := (global_basis.inverse() * b.global_basis.z).normalized()
	var mat_y := Mission02DeskLayout.MAT_THICKNESS + CABLE_RADIUS
	var a1 := pa + za * HEAD_SIZE.z
	var b1 := pb + zb * HEAD_SIZE.z
	var a2 := a1 + za * 0.05
	var b2 := b1 + zb * 0.05
	a2.y = maxf(mat_y, a2.y - 0.01)
	b2.y = maxf(mat_y, b2.y - 0.01)
	# Round the front of the tester (in front of the MAIN socket), never under it.
	var main_socket: Node3D = tester_sockets().get("MAIN")
	var front_x := (inv * main_socket.global_position).x - 0.07 if main_socket else -0.15
	# Each end keeps to its own side of the tester (A left, B right).
	var side_a := minf(a2.z, -SIDE_CLEAR)
	var side_b := maxf(b2.z, SIDE_CLEAR)
	var loop := CableBuilder.build([a1, a2, Vector3(a2.x, mat_y, side_a), Vector3(front_x, mat_y, side_a),
		Vector3(front_x, mat_y, side_b), Vector3(b2.x, mat_y, side_b), b2, b1], _cable_color, "Loop", CABLE_RADIUS)
	_test_cable.add_child(loop)


## Camera pose looking down at the tester's LEDs from the player's side.
func tester_view_transform() -> Transform3D:
	var center := global_position + global_basis * Vector3(0.02, 0.0, 0.0)
	if tester:
		var box := AABB()
		var first := true
		for m in tester.find_children("*", "MeshInstance3D", true, false):
			var mesh := m as MeshInstance3D
			var world_box: AABB = mesh.global_transform * mesh.get_aabb()
			box = world_box if first else box.merge(world_box)
			first = false
		if not first:
			center = box.get_center()
	var eye := center + global_basis * Vector3(-0.11, 0.19, 0.065)
	var target := center + global_basis * Vector3(0.0, 0.0, 0.065)
	return Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func use(player: Node) -> void:
	if prompt != "":
		used.emit(player)
