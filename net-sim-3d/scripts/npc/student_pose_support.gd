class_name StudentPoseSupport
extends RefCounted

## Small CPU contact sample of the actual skinned soles. Cloth gets a local
## seated corrective shape; approved GLBs and Blender sources stay unchanged.
var student: StudentCharacter
var shoe_mesh: MeshInstance3D
var sole_samples: Dictionary = {"L": [], "R": []}
var plants: Dictionary = {}
var foot_bases: Dictionary = {}
var clothes: Array[MeshInstance3D] = []
var clothes_prepared := false
var sole_binds := PackedInt32Array()

func setup(owner_node: StudentCharacter) -> void:
	student=owner_node
	for mesh: MeshInstance3D in student.get_node("Visual").find_children("*","MeshInstance3D",true,false):
		if "Shoes" in mesh.name:shoe_mesh=mesh
		if "skirt" in mesh.name or "shorts" in mesh.name:clothes.append(mesh)
	if shoe_mesh==null:return
	var candidates:Dictionary={"L":[],"R":[]}
	var lowest:Dictionary={"L":INF,"R":INF}
	for surface in shoe_mesh.mesh.get_surface_count():
		var a:=shoe_mesh.mesh.surface_get_arrays(surface)
		var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var bones:PackedInt32Array=a[Mesh.ARRAY_BONES]
		var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
		var stride:int=bones.size()/v.size()
		var transforms:=skin_matrices(shoe_mesh)
		for i in v.size():
			var sample:Dictionary={"vertex":v[i],"bones":bones.slice(i*stride,(i+1)*stride),"weights":weights.slice(i*stride,(i+1)*stride)}
			var p:=skin_vertex(sample,transforms)
			var local:=student.global_transform.affine_inverse()*p
			var side:="L" if local.x>0 else "R"
			lowest[side]=minf(lowest[side],p.y)
			sample["height"]=p.y
			candidates[side].append(sample)
	for side in ["L","R"]:
		var low:Array=[]
		for point:Dictionary in candidates[side]:
			if point["height"]<float(lowest[side])+.009:low.append(point)
		# Keep all low sole vertices (typically 40-80), not high sock cuffs.
		sole_samples[side]=low
		for sample:Dictionary in low:
			for k in (sample["bones"] as PackedInt32Array).size():
				var b:int=sample["bones"][k]
				if sample["weights"][k]>.00001 and not sole_binds.has(b):sole_binds.append(b)

func skin_matrices(mesh: MeshInstance3D, used:PackedInt32Array=[]) -> Array[Transform3D]:
	var out:Array[Transform3D]=[]
	out.resize(mesh.skin.get_bind_count())
	var sk:=student.skeleton
	var indices:=used
	if indices.is_empty():
		for i in mesh.skin.get_bind_count():indices.append(i)
	for i in indices:
		var b:=mesh.skin.get_bind_bone(i)
		if b<0:b=sk.find_bone(mesh.skin.get_bind_name(i))
		out[i]=sk.global_transform*sk.get_bone_global_pose(b)*mesh.skin.get_bind_pose(i)
	return out

func skin_vertex(sample:Dictionary, transforms:Array[Transform3D]) -> Vector3:
	var out:=Vector3.ZERO
	var weights:PackedFloat32Array=sample["weights"]
	var bones:PackedInt32Array=sample["bones"]
	for k in weights.size():
		if weights[k]>.00001:out+=(transforms[bones[k]]*(sample["vertex"] as Vector3))*weights[k]
	return out

func sole_heights() -> Dictionary:
	var result:Dictionary={"L":INF,"R":INF}
	if shoe_mesh==null:return result
	var transforms:=skin_matrices(shoe_mesh,sole_binds)
	for side in ["L","R"]:
		for point:Dictionary in sole_samples[side]:
			result[side]=minf(result[side],skin_vertex(point,transforms).y)
	return result

func capture_plants() -> void:
	var sk:=student.skeleton
	var soles:=sole_heights()
	for side in ["L","R"]:
		var foot:=sk.get_bone_global_pose(sk.find_bone("foot."+side))
		plants[side]=sk.global_transform*foot.origin+Vector3.UP*(.003-float(soles[side]))
		foot_bases[side]=(sk.global_basis*foot.basis).orthonormalized()

func solve_limb(upper_name:String, lower_name:String, tip_name:String, goal:Vector3, pole:Vector3) -> void:
	var sk:=student.skeleton
	var upper:=sk.find_bone(upper_name)
	var lower:=sk.find_bone(lower_name)
	var tip:=sk.find_bone(tip_name)
	var a:=student._bone_pos(upper)
	var b:=student._bone_pos(lower)
	var c:=student._bone_pos(tip)
	var l1:=a.distance_to(b)
	var l2:=b.distance_to(c)
	var axis:=(goal-a).normalized()
	var distance:=clampf(a.distance_to(goal),absf(l1-l2)+.002,l1+l2-.002)
	var along:=(l1*l1-l2*l2+distance*distance)/(2*distance)
	var bend:=(pole-axis*pole.dot(axis)).normalized()
	var joint:=a+axis*along+bend*sqrt(maxf(0,l1*l1-along*along))
	student._aim(upper,b-a,joint-a)
	student._aim(lower,student._bone_pos(tip)-student._bone_pos(lower),goal-student._bone_pos(lower))

func plant_feet() -> void:
	if plants.is_empty():return
	var sk:=student.skeleton
	var inverse:=sk.global_transform.affine_inverse()
	for side in ["L","R"]:
		solve_limb("upperleg01."+side,"lowerleg01."+side,"foot."+side,inverse*(plants[side] as Vector3),Vector3(0,0,1))
		var b:=sk.find_bone("foot."+side)
		var parent:=sk.get_bone_parent(b)
		var wanted:Basis=sk.global_basis.inverse()*(foot_bases[side] as Basis)
		var local:Basis=sk.get_bone_global_pose(parent).basis.inverse()*wanted
		sk.set_bone_pose_rotation(b,local.orthonormalized().get_rotation_quaternion())

func rest_hands(amount:float) -> void:
	if amount<=0:return
	var sk:=student.skeleton
	for side in ["L","R"]:
		var names:=["upperarm01."+side,"lowerarm01."+side,"wrist."+side]
		var before:Array[Quaternion]=[]
		for name:String in names:before.append(sk.get_bone_pose_rotation(sk.find_bone(name)))
		var out:=1.0 if side=="L" else -1.0
		var knee:=student._bone_pos(sk.find_bone("lowerleg01."+side))
		solve_limb(names[0],names[1],names[2],knee+Vector3(out*.012,.085,-.04),Vector3(out*.25,0,-.3))
		var wrist:=sk.find_bone(names[2])
		var middle:=sk.find_bone("finger3-1."+side)
		student._aim(wrist,student._bone_pos(middle)-student._bone_pos(wrist),Vector3(0,-.10,1))
		# Do not roll the upper arm/shoulder: that twisted the uniform seam open.
		for i in names.size():
			var b:=sk.find_bone(names[i])
			sk.set_bone_pose_rotation(b,before[i].slerp(sk.get_bone_pose_rotation(b),amount))

func settle_planted_feet() -> void:
	# Near full extension a 2-bone leg cannot quite reach its locked contact.
	# Let the pelvis settle a little, then solve again instead of floating.
	for i in 2:
		var soles:=sole_heights()
		var lift:=minf(soles["L"],soles["R"])-.003
		if lift<.003:return
		(student.get_node("Visual") as Node3D).position.y-=minf(lift,.035)
		plant_feet()

func prepare_clothes() -> void:
	if clothes_prepared:return
	clothes_prepared=true
	var inverse:=student._bench.global_transform.affine_inverse()
	for instance in clothes:
		var old:=instance.mesh
		var new_mesh:=ArrayMesh.new()
		new_mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
		new_mesh.add_blend_shape("Seated fabric clearance")
		var transforms:=skin_matrices(instance)
		for surface in old.get_surface_count():
			var a:=old.surface_get_arrays(surface)
			var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var target:=vs.duplicate()
			var bones:PackedInt32Array=a[Mesh.ARRAY_BONES]
			var weights:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
			var stride:int=bones.size()/vs.size()
			for i in vs.size():
				var blended:=Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),Vector3.ZERO)
				for k in stride:
					var w:=weights[i*stride+k]
					var tr:=transforms[bones[i*stride+k]]
					blended.basis.x+=tr.basis.x*w
					blended.basis.y+=tr.basis.y*w
					blended.basis.z+=tr.basis.z*w
					blended.origin+=tr.origin*w
				var p:=inverse*(blended*vs[i])
				# Fabric drapes on the seat, rather than passing through its boards.
				# Extend just beyond the board edges so triangles also clear them.
				if absf(p.x)<.80 and p.z>-.35 and p.z<.40 and p.y<.462:
					p.y=.462
					target[i]=blended.affine_inverse()*(student._bench.global_transform*p)
			var morph:Array=[]
			morph.resize(Mesh.ARRAY_MAX)
			morph[Mesh.ARRAY_VERTEX]=target
			morph[Mesh.ARRAY_NORMAL]=normals(target,a[Mesh.ARRAY_INDEX])
			morph[Mesh.ARRAY_TANGENT]=a[Mesh.ARRAY_TANGENT]
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a,[morph])
			new_mesh.surface_set_material(surface,old.surface_get_material(surface))
		instance.mesh=new_mesh

func normals(v:PackedVector3Array,indices:PackedInt32Array) -> PackedVector3Array:
	var n:=PackedVector3Array()
	n.resize(v.size())
	for i in range(0,indices.size(),3):
		var a:=indices[i]
		var b:=indices[i+1]
		var c:=indices[i+2]
		var normal:=(v[b]-v[a]).cross(v[c]-v[a])
		n[a]+=normal
		n[b]+=normal
		n[c]+=normal
	for i in n.size():n[i]=n[i].normalized()
	return n

func blend_clothes(amount:float) -> void:
	if not clothes_prepared:return
	for mesh in clothes:mesh.set_blend_shape_value(0,amount)
