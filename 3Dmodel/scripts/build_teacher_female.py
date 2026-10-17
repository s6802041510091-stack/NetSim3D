"""Build a 160 cm female teacher from the established NetSim3D character rig.

The original male teacher .blend is only read. MakeHuman anatomy, morph targets,
skin, eyebrow, eyes and tied-back hair are CC0; uniform changes are authored here.
"""

import json
import math
import random
from collections import defaultdict
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path("D:/NetSim3D/3Dmodel")
SOURCE = ROOT / "temp/teacher_male/source"
FEMALE = ROOT / "temp/teacher_female/source"
SYSTEM = ROOT / "temp/teacher_male/system_assets"
OUTPUT = ROOT / "ใช้ร่วมกัน/blend/teacher_female_khaki_160cm.blend"
PREVIEW = ROOT / "ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_preview.png"
BACK = ROOT / "ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_back.png"

random.seed(24)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "ใช้ร่วมกัน/blend/teacher_male_khaki_180cm.blend"))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
rig = bpy.data.objects["Teacher_Male_Rig"]
rig.hide_set(False)
rig.name = "Teacher_Female_Rig"
asset = bpy.data.collections["TEACHER | male · 180 cm"]
asset.name = "TEACHER | female · 160 cm"
studio = bpy.data.collections["STUDIO | excluded from game export"]


def read_obj(path):
    vertices, uvs, faces, groups = [], [], [], []
    group = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        tokens = line.split()
        if not tokens:
            continue
        if tokens[0] == "v":
            vertices.append(Vector(tuple(map(float, tokens[1:4]))))
        elif tokens[0] == "vt":
            uvs.append(tuple(map(float, tokens[1:3])))
        elif tokens[0] == "g":
            group = tokens[1]
        elif tokens[0] == "f":
            faces.append([(int(term.split("/")[0]) - 1, int(term.split("/")[1]) - 1 if "/" in term and term.split("/")[1] else 0) for term in tokens[1:]])
            groups.append(group)
    return vertices, uvs, faces, groups


base, base_uv, base_faces, base_groups = read_obj(SOURCE / "base.obj")
verts = [v.copy() for v in base]
for filename, influence in (
    ("asian-female-young.target", 0.90),
    ("caucasian-female-young.target", 0.10),
    ("universal-female-young-averagemuscle-averageweight.target", 1.0),
):
    for line in (FEMALE / filename).read_text(encoding="utf-8").splitlines():
        tokens = line.split()
        if tokens and tokens[0].isdigit():
            verts[int(tokens[0])] += Vector(tuple(float(x) * influence for x in tokens[1:4]))

floor = min(verts[index].y for face, group in zip(base_faces, base_groups) if group == "body" for index, _ in face)


def co(p):
    return Vector((p.x * 0.105, -p.z * 0.105, (p.y - floor) * 0.105 + 0.026))


def mesh(name, points, faces, material, collection=asset):
    data = bpy.data.meshes.new(name + " Mesh")
    data.from_pydata(points, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    if material:
        data.materials.append(material)
    for polygon in data.polygons:
        polygon.use_smooth = True
    return obj


def material(name, color, roughness=0.65, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def add_texture(mat, path, alpha=False):
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(path), check_existing=True)
    mat.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        mat.node_tree.links.new(texture.outputs["Alpha"], bsdf.inputs["Alpha"])
    return texture


skin = material("Female skin | warm natural complexion", (0.58, 0.36, 0.25), 0.56)
skin.node_tree.nodes.get("Principled BSDF").inputs["Subsurface Weight"].default_value = 0.075
add_texture(skin, SYSTEM / "skins/young_asian_female/young_lightskinned_female_diffuse3.png")

# Replace the male anatomy and clothing parts; preserve the proven deform rig
# and khaki uniform detailing from the earlier character.
remove_names = (
    "Body | head neck arms hands",
    "Uniform_Trousers | straight tailored leg",
    "Uniform | trouser stitching",
    "Eyes | fitted cornea iris sclera",
    "Eyebrows | natural dark brows",
    "Hair | teacher sculpted side sweep",
)
for name in remove_names:
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

weight_data = json.loads((SOURCE / "default_weights.mhw").read_text(encoding="utf-8"))["weights"]
weights = defaultdict(dict)
for bone, items in weight_data.items():
    for index, weight in items:
        weights[index][bone] = weight


def attach(obj, ids=None, bone=None):
    bins = defaultdict(list)
    if bone:
        bins[bone] = [(i, 1.0) for i in range(len(obj.data.vertices))]
    elif ids:
        for local_index, source_index in enumerate(ids):
            for name, influence in weights.get(source_index, {}).items():
                if influence > 0.0001:
                    bins[name].append((local_index, influence))
    for name, items in bins.items():
        group = obj.vertex_groups.new(name=name)
        for index, influence in items:
            group.add([index], influence, "REPLACE")
    armature = obj.modifiers.new("Humanoid deformation", "ARMATURE")
    armature.object = rig
    obj.parent = rig


# The skirt hides the hips and thighs; only visible skin is generated. This
# avoids a second internal body surface poking through the cloth in Godot.
visible_faces = []
for face, group in zip(base_faces, base_groups):
    if group != "body":
        continue
    average = sum((verts[index] for index, _ in face), Vector()) / len(face)
    if average.y > 3.15 or (abs(average.x) > 1.65 and average.y > -0.18) or (average.y < -1.80 and co(average).z > 0.145):
        visible_faces.append(face)
ids = sorted({index for face in visible_faces for index, _ in face})
lookup = {index: local for local, index in enumerate(ids)}
body = mesh("Body | female head arms lower legs", [co(verts[index]) for index in ids], [[lookup[index] for index, _ in face] for face in visible_faces], skin)
body_uv = body.data.uv_layers.new(name="MakeHuman_UV")
for polygon, face in zip(body.data.polygons, visible_faces):
    for loop, (_, uv_index) in zip(polygon.loop_indices, face):
        body_uv.data[loop].uv = base_uv[uv_index]
attach(body, ids=ids)
sub = body.modifiers.new("Smooth anatomical surface", "SUBSURF")
sub.levels = 1
sub.render_levels = 1


def fit_proxy(folder, stem, name, mat, bone=None):
    points, uvs, faces, _ = read_obj(folder / (stem + ".obj"))
    fitted = []
    scales = {}
    active = False
    for line in (folder / (stem + ".mhclo")).read_text(encoding="utf-8").splitlines():
        tokens = line.split()
        if not tokens or tokens[0].startswith("#"):
            continue
        if tokens[0].endswith("_scale"):
            axis = {"x": 0, "y": 1, "z": 2}[tokens[0][0]]
            scales[axis] = abs(verts[int(tokens[1])][axis] - verts[int(tokens[2])][axis]) / float(tokens[3])
        elif tokens[0] == "verts":
            active = True
        elif active and tokens[0].lstrip("-").isdigit() and len(fitted) < len(points):
            if len(tokens) == 1:
                fitted.append(verts[int(tokens[0])].copy())
            elif len(tokens) >= 9:
                point = sum((verts[int(tokens[j])] * float(tokens[j + 3]) for j in range(3)), Vector())
                point += Vector(tuple(float(tokens[j + 6]) * scales.get(j, 1.0) for j in range(3)))
                fitted.append(point)
    assert len(fitted) == len(points), (stem, len(fitted), len(points))
    obj = mesh(name, [co(point) for point in fitted], [[index for index, _ in face] for face in faces], mat)
    layer = obj.data.uv_layers.new(name="Texture_UV")
    for polygon, face in zip(obj.data.polygons, faces):
        for loop, (_, uv_index) in zip(polygon.loop_indices, face):
            layer.data[loop].uv = uvs[uv_index]
    if bone:
        attach(obj, bone=bone)
    return obj


hair_material = material("Hair | tidy dark brown tied-back", (0.06, 0.034, 0.022), 0.6)
add_texture(hair_material, SYSTEM / "hair/ponytail01/ponytail01_diffuse.png", True)
hair = fit_proxy(SYSTEM / "hair/ponytail01", "ponytail01", "Hair | neat tied ponytail", hair_material, "head")
hair_sub = hair.modifiers.new("Smooth fitted hairstyle", "SUBSURF")
hair_sub.levels = 1
hair_sub.render_levels = 1

brow_material = material("Brows | soft dark brown", (0.08, 0.04, 0.025), 0.72)
add_texture(brow_material, SYSTEM / "eyebrows/eyebrow001/eyebrow001.png", True)
brows = fit_proxy(SYSTEM / "eyebrows/eyebrow001", "eyebrow001", "Eyebrows | fitted dark brows", brow_material, "head")

eye_material = material("Eyes | warm brown iris", (0.8, 0.8, 0.8), 0.23)
add_texture(eye_material, SOURCE / "brown_eye.png", True)
eyes = fit_proxy(SOURCE, "high-poly", "Eyes | fitted cornea iris sclera", eye_material, "head")

# Feminize the existing tailored uniform: narrower shoulder/waist, modest bust
# ease, while retaining pockets, epaulets, buttons and the editable nameplate.
uniform_names = (
    "Uniform_Shirt | short sleeve",
    "Uniform | chest pockets",
    "Uniform | epaulets",
    "Uniform | buttons and placket",
    "Uniform | editable name badge",
    "Uniform | belt and buckle",
)
for name in uniform_names:
    obj = bpy.data.objects.get(name)
    if not obj:
        continue
    for vertex in obj.data.vertices:
        point = vertex.co
        shoulder = min(1.0, max(0.0, (point.z - 1.18) / 0.30))
        point.x *= 0.86 - 0.10 * shoulder
        waist = math.exp(-((point.z - 1.03) / 0.17) ** 2)
        point.x *= 1.0 - 0.04 * waist
        bust = math.exp(-((point.z - 1.31) / 0.12) ** 2 - (point.x / 0.23) ** 4)
        if point.y < -0.015:
            point.y -= 0.035 * bust
        sleeve_ease = math.exp(-((point.z - 1.37) / 0.16) ** 2) * min(1.0, max(0.0, (abs(point.x) - 0.15) / 0.08))
        point.x *= 1.0 + 0.13 * sleeve_ease
        if point.z > 0.97:
            point.z = 0.97 + (point.z - 0.97) * 0.77

# Straight knee-length khaki skirt with a gently tapered silhouette.
shirt_material = bpy.data.objects["Uniform_Shirt | short sleeve"].data.materials[0]
skirt_material = shirt_material.copy()
skirt_material.name = "Uniform | khaki pencil skirt"
bsdf = skirt_material.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.25, 0.176, 0.079, 1)
ring_specs = [
    (0.985, 0.172, 0.125),
    (0.950, 0.183, 0.130),
    (0.890, 0.213, 0.143),
    (0.805, 0.224, 0.150),
    (0.690, 0.218, 0.148),
    (0.585, 0.225, 0.151),
    (0.565, 0.228, 0.153),
]
segments = 48
skirt_points = []
for height, rx, ry in ring_specs:
    for k in range(segments):
        theta = 2 * math.pi * k / segments
        skirt_points.append((rx * math.cos(theta), -0.01 + ry * math.sin(theta), height))
skirt_faces = []
for row in range(len(ring_specs) - 1):
    for k in range(segments):
        following = (k + 1) % segments
        skirt_faces.append((row * segments + k, row * segments + following, (row + 1) * segments + following, (row + 1) * segments + k))
skirt_faces.append(tuple(reversed(range(segments))))
skirt = mesh("Uniform | tailored knee-length skirt", skirt_points, skirt_faces, skirt_material)
for index, vertex in enumerate(skirt.data.vertices):
    row = index // segments
    side = 1 if vertex.co.x > 0 else -1
    pelvis = "pelvis.L" if side > 0 else "pelvis.R"
    thigh = "upperleg01.L" if side > 0 else "upperleg01.R"
    waist_weight = max(0.25, 0.95 - row * 0.09)
    skirt.vertex_groups.get(pelvis) or skirt.vertex_groups.new(name=pelvis)
    skirt.vertex_groups.get(thigh) or skirt.vertex_groups.new(name=thigh)
    skirt.vertex_groups[pelvis].add([index], waist_weight, "REPLACE")
    skirt.vertex_groups[thigh].add([index], 1.0 - waist_weight, "REPLACE")
armature = skirt.modifiers.new("Humanoid deformation", "ARMATURE")
armature.object = rig
skirt.parent = rig
solid = skirt.modifiers.new("Woven skirt thickness", "SOLIDIFY")
solid.thickness = 0.003
subdivision = skirt.modifiers.new("Tailored smoothing", "SUBSURF")
subdivision.levels = 1
subdivision.render_levels = 1

# Retain the original closed Oxford shoes: unlike the fitted proxy shoes,
# these enclose the entire foot and already have sound rig weights.
shoes = bpy.data.objects["Shoes | black Oxford with socks"]
for vertex in shoes.data.vertices:
    vertex.co.x *= 0.90
sock_material = material("Shoes | dark uniform hosiery", (0.018, 0.019, 0.020), 0.8)
shoes.data.materials.append(sock_material)
for polygon in shoes.data.polygons:
    average_z = sum(shoes.data.vertices[index].co.z for index in polygon.vertices) / len(polygon.vertices)
    if average_z > 0.115:
        polygon.material_index = 1

rig.data.pose_position = "POSE"
bpy.context.view_layer.update()


def bounds():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in asset.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        evaluated_mesh = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ vertex.co for vertex in evaluated_mesh.vertices)
        evaluated.to_mesh_clear()
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]


low, high = bounds()
factor = 1.60 / (high[2] - low[2])
old_rig_z = rig.location.z
rig.scale = tuple(value * factor for value in rig.scale)
rig.location.z -= old_rig_z + factor * (low[2] - old_rig_z)
bpy.context.view_layer.update()
low, high = bounds()
assert abs(high[2] - low[2] - 1.60) < 0.0005, (low, high)
assert abs(low[2]) < 0.0005, low

rig["height_m"] = 1.60
rig["role"] = "Female teacher, khaki short-sleeve uniform and knee-length skirt"
rig["front_axis"] = "-Y"
rig["source"] = "MakeHuman CC0 female anatomy/morph/skin/hair/eyes/brows; NetSim3D tailored khaki uniform"
rig["animation_status"] = "163-bone deform skeleton, no animation clips; refine weights before production animation"

readme = bpy.data.texts.new("README | Female Teacher")
readme.write(
    "NETSIM3D / FEMALE TEACHER / 160 CM\n\n"
    "Standalone asset. Feet at Z=0, +Z up, front faces -Y, 1 Blender unit = 1 metre.\n"
    "Use the TEACHER | female collection for game export; STUDIO is preview only.\n"
    "Includes 163 deform bones, no animation clips. Hair is fitted and tied back.\n"
    "All image textures are packed into this .blend file.\n\n"
    "MakeHuman body mesh, morphs, default skeleton/weights, skin, eyes, brows and hair: CC0.\n"
    "Source: https://github.com/makehumancommunity/makehuman\n"
    "Original male teacher file was not modified.\n"
)

for image in bpy.data.images:
    if image.source == "FILE" and not image.packed_file:
        image.pack()

camera = scene.camera


def aim_camera(location, target, orthographic_scale):
    camera.location = location
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = orthographic_scale


aim_camera((2.0, -5.6, 1.95), (0, 0, 0.8), 1.88)
scene.render.engine = "CYCLES"
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.filepath = str(PREVIEW)

for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        space = area.spaces.active
        space.shading.type = "MATERIAL"
        space.overlay.show_overlays = False
        space.region_3d.view_location = (0, 0, 0.8)
        space.region_3d.view_distance = 2.6

rig.hide_set(True)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = None
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
bpy.ops.render.render(write_still=True)
aim_camera((1.7, 5.3, 1.9), (0, 0, 0.8), 1.88)
scene.render.filepath = str(BACK)
bpy.ops.render.render(write_still=True)
aim_camera((2.0, -5.6, 1.95), (0, 0, 0.8), 1.88)
scene.render.filepath = str(PREVIEW)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))

print("FEMALE_TEACHER_REPORT", json.dumps({
    "file": str(OUTPUT),
    "height_m": high[2] - low[2],
    "feet_z": low[2],
    "mesh_objects": sum(obj.type == "MESH" for obj in asset.objects),
    "bones": len(rig.data.bones),
    "preview": str(PREVIEW),
}), flush=True)
