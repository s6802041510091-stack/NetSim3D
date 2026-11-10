class_name CrimpStation
extends StaticBody3D

## The work spot on the spare desk: look at it and press F to sit and crimp.
## Holds the CrimpBench (the cable end). A mission sets `prompt` when the
## player may use it and listens to `used`.

signal used(player: Node)

const COLLISION_LAYER := 8

var prompt := ""
var bench: CrimpBench
## The LAN cable tester, put on the desk for the test step (null before).
var tester: CableTester
var _test_cable: Node3D


func _ready() -> void:
	# Off until the crimping stage: its box covers the tools on the desk.
	collision_layer = 0
	collision_mask = 0
	set_meta(&"interactable", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.16, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 0.07, 0)
	add_child(shape)
	bench = CrimpBench.new()
	bench.name = "CrimpBench"
	bench.position = Vector3(0, CrimpBench.JACKET_RADIUS + 0.002, 0)
	add_child(bench)


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
		tester.position = Vector3(0.02, 0.0, 0.0)
	bench.visible = false
	tester.visible = true
	return tester


func hide_tester() -> void:
	if tester:
		tester.visible = false
		tester.set_power(false)
	plug_test_cable(false)
	bench.visible = true


## A short cable between the main and remote sockets while testing.
func plug_test_cable(on: bool, color := Color(0.62, 0.72, 0.84)) -> void:
	if _test_cable:
		_test_cable.queue_free()
		_test_cable = null
	if not on or tester == null:
		return
	var main := tester.get_plug_point("Main")
	var remote := tester.get_plug_point("Remote")
	if main == null or remote == null:
		return
	var a := to_local(main.global_position)
	var b := to_local(remote.global_position)
	var out_a := (global_basis.inverse() * main.global_basis.z).normalized()
	var out_b := (global_basis.inverse() * remote.global_basis.z).normalized()
	_test_cable = Node3D.new()
	_test_cable.name = "TestCable"
	add_child(_test_cable)
	for end in [[a, out_a], [b, out_b]]:
		var head := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.019, 0.013, 0.034)
		head.mesh = box
		var clear := StandardMaterial3D.new()
		clear.albedo_color = Color(0.88, 0.93, 0.98, 0.5)
		clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		head.material_override = clear
		var at: Vector3 = end[0] + end[1] * 0.01
		head.transform = Transform3D(Basis.looking_at(-end[1], Vector3.UP), at)
		_test_cable.add_child(head)
	# The cable runs out of the main socket, round the right side of the
	# tester and into the remote socket, flat on the desk.
	var right := Vector3(0, 0, 0.1)
	var a_out := a + out_a * 0.06
	var b_out := b + out_b * 0.06
	_test_cable.add_child(CableBuilder.build([a + out_a * 0.026, a_out, a_out + right,
		b_out + right, b_out, b + out_b * 0.026], color, "Loop", 0.0045))


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
