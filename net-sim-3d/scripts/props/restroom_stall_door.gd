@tool
class_name RestroomStallDoor
extends Node3D

## A cubicle door using the player's existing generic F interaction.
signal state_changed(opened:bool)
var number:=1
var width:=.78
var height:=1.75
var gap:=.14
var start_open:=false
var material:Material
var is_open:=false
var is_moving:=false
var swing:Node3D
var body:AnimatableBody3D
var collider:CollisionShape3D
var _tween:Tween
const OPEN_ANGLE:=-PI/2

func _ready() -> void:
	swing=Node3D.new();swing.name="Swing";add_child(swing)
	var panel:=MeshInstance3D.new()
	var mesh:=BoxMesh.new();mesh.size=Vector3(width,height,.028)
	panel.mesh=mesh;panel.material_override=material
	panel.position=Vector3(width/2,gap+height/2,0);swing.add_child(panel)
	var metal:=StandardMaterial3D.new()
	metal.albedo_color=Color(.7,.74,.75);metal.metallic=.75;metal.roughness=.28
	var handle:=MeshInstance3D.new();var handle_mesh:=BoxMesh.new()
	handle_mesh.size=Vector3(.095,.024,.04);handle.mesh=handle_mesh;handle.material_override=metal
	handle.position=Vector3(width-.10,1.02,-.035);swing.add_child(handle)
	var inside:=handle.duplicate() as MeshInstance3D
	inside.position.z=.035;swing.add_child(inside)
	var plate:=MeshInstance3D.new();var plate_mesh:=CylinderMesh.new()
	plate_mesh.top_radius=.024;plate_mesh.bottom_radius=.024;plate_mesh.height=.007
	plate_mesh.radial_segments=12;plate.mesh=plate_mesh
	var green:=StandardMaterial3D.new();green.albedo_color=Color(.24,.63,.45)
	plate.material_override=green;plate.rotation.x=PI/2
	plate.position=Vector3(width-.10,1.12,-.02);swing.add_child(plate)
	var label:=Label3D.new();label.text="%02d"%number
	label.font=GameUI.FONT_BOLD;label.font_size=64;label.pixel_size=.0016
	label.modulate=Color(.94,.96,.96);label.outline_size=0
	label.position=Vector3(width/2,1.47,-.018);label.rotation.y=PI
	swing.add_child(label)
	body=AnimatableBody3D.new();body.name="Collider"
	body.collision_layer=1;body.collision_mask=0;body.sync_to_physics=false
	body.set_meta("interactable",self);swing.add_child(body)
	collider=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=mesh.size;collider.shape=shape;collider.position=panel.position
	body.add_child(collider)
	is_open=start_open;swing.rotation.y=OPEN_ANGLE if is_open else 0.0
	add_to_group("restroom_stall_doors")

func get_prompt_text() -> String:
	if is_moving:return ""
	var pattern:=GameLocale.text("[F] ปิดประตู%s" if is_open else "[F] เปิดประตู%s")
	return pattern% (" "+GameLocale.text("คอก %d"%number))

func use(_player:Node) -> void:
	set_open(not is_open)

func set_open(value:bool,animate:=true) -> bool:
	if is_moving:return false
	var target:=OPEN_ANGLE if value else 0.0
	if _blocked(target):
		if not Engine.is_editor_hint():Sound.play("door_blocked",global_position)
		return false
	is_open=value
	if not animate:
		swing.rotation.y=target;state_changed.emit(is_open);return true
	is_moving=true
	if not Engine.is_editor_hint():Sound.play("door_open" if value else "door_close",global_position)
	_tween=create_tween();_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(swing,"rotation:y",target,.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(func():is_moving=false;state_changed.emit(is_open))
	return true

func _blocked(target:float) -> bool:
	if Engine.is_editor_hint():return false
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=collider.shape;query.collision_mask=2;query.margin=.015
	for i in range(1,13):
		var angle:=lerpf(swing.rotation.y,target,i/12.0)
		query.transform=global_transform*Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)*collider.transform
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return true
	return false
