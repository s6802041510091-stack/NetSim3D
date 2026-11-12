class_name StudentThighs
extends RefCounted

## The approved female student models have bare legs only from the ankle to
## just above the knee; the skirt covers the rest while standing. Seated, the
## skirt opens at the front and the cut leg ends show. This adds a skinned
## thigh at runtime, from the cut up to the hip joint, inside the skirt.
## The GLB files stay unchanged.
const RINGS := 10
const SEGMENTS := 24

static func add_to(root: Node) -> void:
	var body: MeshInstance3D
	var has_skirt := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if String(mi.name).begins_with("Body"):
			body = mi
		if "skirt" in String(mi.name):
			has_skirt = true
	if body == null or not has_skirt or body.skin == null or body.mesh == null:
		return
	var skeleton := body.get_node_or_null(body.skeleton) as Skeleton3D
	if skeleton == null:
		return
	var skin := body.skin
	var bind_of := {}
	var rest_of := {}
	for i in skin.get_bind_count():
		var bone_name := skin.get_bind_name(i)
		if bone_name == "":
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(i))
		bind_of[bone_name] = i
		rest_of[bone_name] = skin.get_bind_pose(i).affine_inverse().origin
	if not (bind_of.has("upperleg01.L") and bind_of.has("lowerleg01.L") and bind_of.has("upperleg01.R")):
		return
	var arrays_out := {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
		"b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
	var material: Material
	var stride := 4
	for side in ["L", "R"]:
		var hip: Vector3 = rest_of["upperleg01." + side]
		var knee: Vector3 = rest_of["lowerleg01." + side]
		var sign := signf(hip.x)
		# The open top edge of the bare leg on this side.
		var ring: Array = [] # [position, uv, bones, weights]
		var cut := -INF
		for surface in body.mesh.get_surface_count():
			var a := body.mesh.surface_get_arrays(surface)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var s := bones.size() / maxi(vs.size(), 1)
			var found := false
			for i in vs.size():
				var p := vs[i]
				if p.x * sign > .02 and p.y > knee.y - .1 and p.y < hip.y - .15:
					if p.y > cut + .012:
						ring.clear()
						cut = p.y
					if p.y > cut - .012:
						ring.append([p, uvs[i] if uvs.size() > i else Vector2.ZERO, bones.slice(i * s, (i + 1) * s), weights.slice(i * s, (i + 1) * s)])
						found = true
					cut = maxf(cut, p.y)
			if found:
				stride = s
				material = body.get_active_material(surface)
		# Leftovers from before the true top was found.
		ring = ring.filter(func(r): return (r[0] as Vector3).y > cut - .012)
		if ring.size() < 8:
			continue
		var centre := Vector3.ZERO
		for r in ring:
			centre += r[0]
		centre /= ring.size()
		var average := 0.0
		for r in ring:
			average += Vector2((r[0] as Vector3).x - centre.x, (r[0] as Vector3).z - centre.z).length()
		average /= ring.size()
		# One clean skin texel from the front of the shin, so the thigh matches
		# the leg instead of picking up the knee's darker shading.
		var skin_uv: Vector2 = ring[0][1]
		var shin := Vector3(centre.x, cut - .13, centre.z + average)
		var best := INF
		for surface in body.mesh.get_surface_count():
			var a := body.mesh.surface_get_arrays(surface)
			var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			if uvs.size() != vs.size() or body.get_active_material(surface) != material:
				continue
			for i in vs.size():
				var d := vs[i].distance_squared_to(shin)
				if d < best:
					best = d
					skin_uv = uvs[i]
		# Slim enough to stay under the skirt when it lifts off the seated thigh.
		var top := Vector3(hip.x * .92, hip.y - .06, hip.z - .005)
		var start := Vector3(centre.x, cut - .012, centre.z)
		var thigh_bind: int = bind_of["upperleg01." + side]
		var pelvis_bind: int = bind_of.get("pelvis." + side, thigh_bind)
		var base: int = (arrays_out["v"] as PackedVector3Array).size()
		for ri in RINGS:
			var t := float(ri) / (RINGS - 1)
			var c := start.lerp(top, t)
			var round_r := lerpf(average, average * 1.12, smoothstep(0.0, .6, t)) * (1.0 - .25 * smoothstep(.75, 1.0, t))
			for k in SEGMENTS:
				var angle := TAU * k / SEGMENTS
				var nearest: Array = _ring_at(ring, centre, angle)
				var leg_r: float = nearest[1] * (.955 if ri == 0 else .985)
				var r := lerpf(leg_r, round_r, smoothstep(0.0, .35, t))
				var dir := Vector3(cos(angle), 0, sin(angle))
				arrays_out["v"].append(c + Vector3(dir.x * r, 0, dir.z * r))
				arrays_out["n"].append(dir)
				arrays_out["uv"].append(nearest[0][1])
				# The leg's own skinning at the cut; above it the same thigh/pelvis
				# hand-over as the skirt, so both fold alike at the hip crease.
				var mix := {}
				var src_b: PackedInt32Array = nearest[0][2]
				var src_w: PackedFloat32Array = nearest[0][3]
				var up := smoothstep(.25, 1.0, t)
				for j in src_b.size():
					mix[src_b[j]] = float(mix.get(src_b[j], 0.0)) + src_w[j] * (1.0 - up)
				var follow := StudentThighs.skirt_follow(c.y, hip.y)
				mix[thigh_bind] = float(mix.get(thigh_bind, 0.0)) + up * follow
				mix[pelvis_bind] = float(mix.get(pelvis_bind, 0.0)) + up * (1.0 - follow)
				var keys := mix.keys()
				keys.sort_custom(func(x, y): return mix[x] > mix[y])
				var total := 0.0
				for j in mini(stride, keys.size()):
					total += mix[keys[j]]
				for j in stride:
					arrays_out["b"].append(keys[j] if j < keys.size() else 0)
					arrays_out["w"].append(mix[keys[j]] / total if j < keys.size() else 0.0)
		for ri in RINGS - 1:
			for k in SEGMENTS:
				var a0: int = base + ri * SEGMENTS + k
				var a1: int = base + ri * SEGMENTS + (k + 1) % SEGMENTS
				var b0: int = a0 + SEGMENTS
				var b1: int = a1 + SEGMENTS
				arrays_out["i"].append_array([a0, b0, a1, a1, b0, b1])
	if arrays_out["i"].is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = arrays_out["v"]
	arrays[Mesh.ARRAY_NORMAL] = arrays_out["n"]
	arrays[Mesh.ARRAY_TEX_UV] = arrays_out["uv"]
	arrays[Mesh.ARRAY_BONES] = arrays_out["b"]
	arrays[Mesh.ARRAY_WEIGHTS] = arrays_out["w"]
	arrays[Mesh.ARRAY_INDEX] = arrays_out["i"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0)
	var skin_material := (material.duplicate() if material else StandardMaterial3D.new()) as Material
	if skin_material is BaseMaterial3D:
		(skin_material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		(skin_material as BaseMaterial3D).normal_enabled = false
		(skin_material as BaseMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mesh.surface_set_material(0, skin_material)
	var thighs := MeshInstance3D.new()
	thighs.name = "Thighs (runtime)"
	thighs.mesh = mesh
	thighs.skin = skin
	body.get_parent().add_child(thighs)
	thighs.transform = body.transform
	thighs.skeleton = thighs.get_path_to(skeleton)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if "skirt" in String(node.name):
			_skirt_follows_thighs(node as MeshInstance3D, skeleton, bind_of, rest_of)

## The skirt reaches the knee, but it is skinned to the pelvis, so seated it
## hangs from the waist and leaves the thighs bare. Hand its lower part over
## to the thigh bones (both near the middle), as a knee-length skirt drapes.
static func _skirt_follows_thighs(skirt: MeshInstance3D, skeleton: Skeleton3D, bind_of: Dictionary, rest_of: Dictionary) -> void:
	if skirt.skin == null or skirt.mesh == null:
		return
	var skirt_bind := {}
	for i in skirt.skin.get_bind_count():
		var bone_name := skirt.skin.get_bind_name(i)
		if bone_name == "":
			bone_name = skeleton.get_bone_name(skirt.skin.get_bind_bone(i))
		skirt_bind[bone_name] = i
	if not (skirt_bind.has("upperleg01.L") and skirt_bind.has("upperleg01.R")):
		return
	var hip_y: float = (rest_of["upperleg01.L"] as Vector3).y
	var old := skirt.mesh
	var mesh := ArrayMesh.new()
	if old is ArrayMesh:
		mesh.blend_shape_mode = (old as ArrayMesh).blend_shape_mode
		for b in (old as ArrayMesh).get_blend_shape_count():
			mesh.add_blend_shape((old as ArrayMesh).get_blend_shape_name(b))
	for surface in old.get_surface_count():
		var a := old.surface_get_arrays(surface)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var stride := bones.size() / maxi(vs.size(), 1)
		for i in vs.size():
			var v := vs[i]
			var follow := skirt_follow(v.y, hip_y)
			if follow <= 0:
				continue
			var left := clampf(.5 + v.x / .1, 0, 1)
			var mix := {}
			for k in stride:
				mix[bones[i * stride + k]] = float(mix.get(bones[i * stride + k], 0.0)) + weights[i * stride + k] * (1.0 - follow)
			for pair in [[skirt_bind["upperleg01.L"], left], [skirt_bind["upperleg01.R"], 1.0 - left]]:
				mix[pair[0]] = float(mix.get(pair[0], 0.0)) + follow * pair[1]
			var keys := mix.keys()
			keys.sort_custom(func(x, y): return mix[x] > mix[y])
			var total := 0.0
			for k in mini(stride, keys.size()):
				total += mix[keys[k]]
			for k in stride:
				bones[i * stride + k] = keys[k] if k < keys.size() else 0
				weights[i * stride + k] = mix[keys[k]] / total if k < keys.size() else 0.0
		a[Mesh.ARRAY_BONES] = bones
		a[Mesh.ARRAY_WEIGHTS] = weights
		var shapes := old.surface_get_blend_shape_arrays(surface)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, shapes, {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0)
		mesh.surface_set_material(surface, old.surface_get_material(surface))
	skirt.mesh = mesh

## Share of the thigh bone (vs the pelvis) at a height, for skirt and thigh.
static func skirt_follow(y: float, hip_y: float) -> float:
	return smoothstep(hip_y - .03, hip_y - .25, y)

## The leg-edge vertex closest in angle around the leg, and its radius.
static func _ring_at(ring: Array, centre: Vector3, angle: float) -> Array:
	var best: Array = ring[0]
	var best_d := INF
	for r in ring:
		var p: Vector3 = r[0]
		var d := absf(angle_difference(angle, atan2(p.z - centre.z, p.x - centre.x)))
		if d < best_d:
			best_d = d
			best = r
	var bp: Vector3 = best[0]
	return [best, Vector2(bp.x - centre.x, bp.z - centre.z).length()]
