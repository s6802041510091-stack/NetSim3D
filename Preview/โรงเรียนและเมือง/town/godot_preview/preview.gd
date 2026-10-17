extends Node3D
const G = -7.2
var people: Array[Dictionary] = []
var petals: Array[MeshInstance3D] = []
var clock_time := 0.0
var camera: Camera3D
var active_view := 0
var horizon_ground_count := 0
var japanese_instances := 0
var views := [
	[Vector3(88,65,100),Vector3(-3,-2,-15),"01_campus"],
	[Vector3(7.6,1.65,-2.7),Vector3(65,-5,-14),"02_classroom_east"],
	[Vector3(-19.8,1.65,4.9),Vector3(-65,-5,0),"03_science_garden"],
	[Vector3(3,1.65,8.5),Vector3(3,-5,64),"04_south_shops"],
	[Vector3(48,-2.8,32),Vector3(8,-2,-5),"05_street"]]
func material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=c
	m.roughness=.85
	return m
func shape(parent: Node3D, size: Vector3, pos: Vector3, m: Material, sphere:=false) -> MeshInstance3D:
	var o:=MeshInstance3D.new()
	if sphere:
		var mesh:=SphereMesh.new()
		mesh.radial_segments=8
		mesh.rings=4
		mesh.radius=.5
		mesh.height=1
		o.mesh=mesh
	else:
		o.mesh=BoxMesh.new()
	o.scale=size
	o.position=pos
	o.material_override=m
	parent.add_child(o)
	return o
func _ready() -> void:
	seed(43)
	var town: Node3D=(load("res://town.glb") as PackedScene).instantiate()
	add_child(town)
	for child in town.find_children("*Spring*", "MeshInstance3D", true, false):
		var original: StandardMaterial3D=child.get_active_material(0)
		var horizon:=ShaderMaterial.new()
		horizon.shader=load("res://horizon_ground.gdshader")
		horizon.set_shader_parameter("grass",original.albedo_texture)
		horizon.set_shader_parameter("panorama",load("res://town_panorama_v1.png"))
		child.material_override=horizon
		horizon_ground_count+=1
	add_child((load("res://architecture.glb") as PackedScene).instantiate())
	var building_library: Node3D=(load("res://japanese_buildings.glb") as PackedScene).instantiate()
	var japanese_layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://japanese_layout.json"))
	var district:=Node3D.new()
	district.name="Japanese streets - Michal Solarek CC BY 4.0"
	add_child(district)
	for placement in japanese_layout.placements:
		var prototype:=building_library.find_child(placement.prototype,true,false)
		assert(prototype!=null,"Missing Japanese building prototype")
		var building: Node3D=prototype.duplicate()
		district.add_child(building)
		building.position=Vector3(placement.position[0],placement.position[2],-placement.position[1])
		building.rotation.y=placement.rotation
		japanese_instances+=1
	building_library.free()
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	var sky:=Sky.new()
	var sky_mat:=ShaderMaterial.new()
	sky_mat.shader=load("res://town_backdrop.gdshader")
	sky_mat.set_shader_parameter("panorama",load("res://town_panorama_v1.png"))
	sky.sky_material=sky_mat
	env.background_mode=Environment.BG_SKY
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.80,.88,1)
	env.ambient_light_energy=.35
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.environment=env
	add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-32,0)
	sun.light_color=Color(1,.94,.83)
	sun.light_energy=.65
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=230
	add_child(sun)
	camera=Camera3D.new()
	camera.fov=65
	camera.far=450
	add_child(camera)
	camera.current=true
	set_view(0)
	for i in range(20): make_person(i,i>=14)
	var petal_mat:=material(Color(1,.64,.75))
	for i in range(80):
		var p:=shape(self,Vector3(.11,.035,.19),Vector3(randf_range(-42,42),randf_range(G+.5,5),randf_range(-65,28)),petal_mat)
		petals.append(p)
	var layer:=CanvasLayer.new()
	add_child(layer)
	var label:=Label.new()
	label.text="SAKURA TOWN  /  Third-floor view\n1–5: viewpoints   |   arrows: look   |   WASD: fly   |   Q/E: height"
	label.position=Vector2(24,20)
	label.add_theme_color_override("font_shadow_color",Color(.1,.15,.2))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
	var credit:=Label.new()
	credit.text="Japanese buildings: Michał Solarek / Sketchfab / CC BY 4.0 — modified layout"
	credit.position=Vector2(24,860)
	credit.add_theme_color_override("font_shadow_color",Color(.1,.15,.2))
	credit.add_theme_constant_override("shadow_offset_x",2)
	credit.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(credit)
	if "--validate" in OS.get_cmdline_user_args():
		var before: Vector3=people[0].node.position
		update_actors(2.0)
		var passed: bool=people.size()==20 and people[0].node.position.distance_to(before)>1 and abs(1.65-G-8.85)<.001 and horizon_ground_count==1
		for p in people:
			var period:=433.0 if p.bike else 406.0
			passed=passed and route(p.distance,p.bike).distance_to(route(p.distance+period,p.bike))<.01
			passed=passed and p.node.position.is_finite()
		var report:={"passed":passed,"walkers":14,"cyclists":6,"animated_petals":80,"third_floor_eye_height_m":8.85,"walking_loop_length_m":406,"cycling_loop_length_m":433,"production_integration":false}
		report["painted_2d_background"] = ResourceLoader.exists("res://town_panorama_v1.png")
		report["horizon_ground_blend_count"] = horizon_ground_count
		report["japanese_building_instances"] = japanese_instances
		passed = passed and japanese_instances==japanese_layout.instance_count
		report["passed"] = passed
		FileAccess.open("res://validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		get_tree().quit(0 if passed else 1)
	if "--capture" in OS.get_cmdline_user_args():
		for i in range(views.size()):
			set_view(i)
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://"+views[i][2]+".png")
		get_tree().quit()
func make_person(i: int, bike: bool) -> void:
	var root:=Node3D.new()
	add_child(root)
	var skin:=material(Color(.94,.71,.54))
	var uniform:=material([Color(.18,.29,.48),Color(.97,.69,.68),Color(.72,.85,.89),Color(.94,.90,.73)][i%4])
	var dark:=material(Color(.13,.16,.23))
	shape(root,Vector3(.38,.60,.24),Vector3(0,1.12,0),uniform)
	shape(root,Vector3(.30,.34,.30),Vector3(0,1.61,0),skin,true)
	shape(root,Vector3(.32,.17,.32),Vector3(0,1.73,.02),dark,true)
	var limbs: Array[Node3D]=[]
	for x in [-.12,.12]:
		var leg:=Node3D.new()
		root.add_child(leg)
		leg.position=Vector3(x,.83,0)
		shape(leg,Vector3(.13,.66,.15),Vector3(0,-.33,0),dark)
		limbs.append(leg)
	for x in [-.26,.26]:
		var arm:=Node3D.new()
		root.add_child(arm)
		arm.position=Vector3(x,1.36,0)
		shape(arm,Vector3(.12,.50,.12),Vector3(0,-.25,0),uniform)
		limbs.append(arm)
	var wheels: Array[MeshInstance3D]=[]
	if bike:
		var frame:=material(Color(.87,.39,.29))
		shape(root,Vector3(.10,.10,1.1),Vector3(0,.49,0),frame)
		shape(root,Vector3(.08,.55,.08),Vector3(0,.58,-.5),frame)
		shape(root,Vector3(.6,.07,.08),Vector3(0,.9,-.5),dark)
		for endpoints in [[Vector3(0,.34,.52),Vector3(0,.85,.12)],[Vector3(0,.85,.12),Vector3(0,.34,-.52)],[Vector3(0,.34,.52),Vector3(0,.34,-.52)]]:
			var bar:=shape(root,Vector3(.055,.055,endpoints[0].distance_to(endpoints[1])),(endpoints[0]+endpoints[1])*.5,frame)
			bar.look_at(root.to_global(endpoints[1]),Vector3.UP)
		shape(root,Vector3(.24,.07,.28),Vector3(0,.87,.12),dark)
		for z in [-.52,.52]:
			var wheel:=MeshInstance3D.new()
			var mesh:=TorusMesh.new()
			mesh.inner_radius=.26
			mesh.outer_radius=.34
			mesh.rings=12
			mesh.ring_segments=6
			wheel.mesh=mesh
			wheel.material_override=dark
			wheel.rotation.z=PI/2
			wheel.position=Vector3(0,.34,z)
			root.add_child(wheel)
			shape(wheel,Vector3(.035,.035,.56),Vector3.ZERO,uniform)
			wheels.append(wheel)
	people.append({"node":root,"distance":i*21.4,"speed":3.2 if bike else 1.2,"bike":bike,"limbs":limbs,"wheels":wheels})
	update_actors(0)
func route(distance: float, bike: bool) -> Vector3:
	var points:=[Vector3(-46.5,G+.25,36.5),Vector3(49.5,G+.25,36.5),Vector3(49.5,G+.25,-70.5),Vector3(-46.5,G+.25,-70.5)]
	if bike: points=[Vector3(-50,G+.06,39.5),Vector3(53,G+.06,39.5),Vector3(53,G+.06,-74),Vector3(-50,G+.06,-74)]
	var total:=0.0
	for i in range(4): total+=points[i].distance_to(points[(i+1)%4])
	var d:=fposmod(distance,total)
	for i in range(4):
		var length: float=points[i].distance_to(points[(i+1)%4])
		if d<=length: return points[i].lerp(points[(i+1)%4],d/length)
		d-=length
	return points[0]
func update_actors(delta: float) -> void:
	for p in people:
		p.distance+=p.speed*delta
		var pos:=route(p.distance,p.bike)
		p.node.position=pos
		p.node.look_at(route(p.distance+.1,p.bike),Vector3.UP)
		for j in range(4):
			p.limbs[j].rotation.x=sin(p.distance*(3 if p.bike else 5)+j*PI)*(.3 if p.bike else .45)
			if p.bike and j>=2: p.limbs[j].rotation.x=-.9
		for wheel in p.wheels: wheel.rotation.y=p.distance/.3
func set_view(i: int) -> void:
	active_view=i
	camera.position=views[i][0]
	camera.look_at(views[i][1])
func _process(delta: float) -> void:
	clock_time+=delta
	update_actors(delta)
	for i in range(petals.size()):
		petals[i].position+=Vector3(.3+sin(clock_time+i)*.25,-.22,.12)*delta
		petals[i].rotate_y(delta)
		if petals[i].position.y<G+.2: petals[i].position.y=5
	var move:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	camera.position+=camera.basis*move*delta*12
	camera.rotation.y+=(float(Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_RIGHT)))*delta
	camera.rotation.x+=(float(Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_DOWN)))*delta
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode>=KEY_1 and event.keycode<=KEY_5: set_view(event.keycode-KEY_1)
