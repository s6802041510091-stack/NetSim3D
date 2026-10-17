"""Original Cat6 U/UTP 5 m patch lead and reusable 8P8C modular plug.

Coordinates are authored in millimetres and converted to metres. The reusable
plug has its mating face at the origin, tip towards Blender +Y, contacts +Z,
latch -Z and cable exit -Y. Use the D:-only PowerShell launcher.
"""
from pathlib import Path
import json
import math
import struct

import bpy
import numpy as np
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
for folder in ("ใช้ร่วมกัน/blend", "ใช้ร่วมกัน/exports", "ใช้ร่วมกัน/renders", "temp/cat6"):
    (BASE / folder).mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/cat6")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "MILLIMETERS"
asset = bpy.data.collections.new("ASSET | Cat6 patch cable 5m")
source = bpy.data.collections.new("SOURCE | editable cable path")
master = bpy.data.collections.new("MODULE | reusable RJ45 plug")
studio = bpy.data.collections.new("STUDIO | preview only")
for collection in (asset, source, master, studio):
    scene.collection.children.link(collection)


def mm(values):
    return tuple(float(value) / 1000 for value in values)


def relocate(obj, collection):
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)


def empty(name, position=(0, 0, 0), parent=None, collection=asset):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    obj.location = mm(position)
    obj.empty_display_type, obj.empty_display_size = "ARROWS", 0.004
    return obj


root = empty("Cat6_PatchCable_5m")
root["category_design"] = "Cat6 U/UTP patch cable, original educational art (not manufacturing CAD)"
root["wiring"] = "T568B at both ends, straight-through"
root["nominal_end_to_end_length_m"] = 5.0
root["jacket_diameter_mm"] = 6.2
root["deformation_note"] = "GLB is a static coiled mesh; reroute with source Curve or future Godot tube generation."
plug_root = empty("RJ45_Plug_Module", collection=master)
plug_root["mating_direction_blender"] = "+Y"
plug_root["mating_direction_gltf"] = "-Z"
plug_root["nose_origin"] = "Front mating face; body and cable extend away along glTF +Z"
plug_root["suggested_initial_insertion_depth_mm"] = 8.0
plug_root["contact_count"] = 8
plug_root["wire_order_pin_1_to_8"] = "white/orange,orange,white/green,blue,white/blue,green,white/brown,brown"


def material(name, rgb, metallic=0, roughness=0.45, alpha=1):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, alpha)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Alpha"].default_value = alpha
    if alpha < 1:
        mat.surface_render_method = "DITHERED"
        if hasattr(mat, "use_transparency_overlap"):
            mat.use_transparency_overlap = False
    return mat


blue = material("Jacket | muted network blue", (0.025, 0.16, 0.30), roughness=0.46)
boot_blue = material("Boot | flexible blue PVC", (0.02, 0.12, 0.23), roughness=0.5)
clear = material("Plug | clear polycarbonate approximation", (0.20, 0.28, 0.31), roughness=0.16, alpha=0.16)
clear_rim = material("Plug edges | translucent polymer", (0.27, 0.37, 0.40), roughness=0.20, alpha=0.33)
gold = material("Contacts | gold finish", (0.76, 0.45, 0.115), 0.87, 0.25)
white = material("Conductor | white insulation", (0.78, 0.80, 0.77), roughness=0.53)
orange = material("Conductor | orange", (0.85, 0.23, 0.023), roughness=0.52)
green = material("Conductor | green", (0.024, 0.32, 0.095), roughness=0.52)
wire_blue = material("Conductor | blue", (0.022, 0.15, 0.60), roughness=0.52)
brown = material("Conductor | brown", (0.24, 0.083, 0.028), roughness=0.52)
ink = material("Boot legend | white", (0.67, 0.79, 0.85), roughness=0.6)


def finish(obj, name, mat, bevel=0, parent=plug_root, collection=master):
    obj.name = name
    relocate(obj, collection)
    obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Molded edges", "BEVEL")
        modifier.width, modifier.segments = bevel / 1000, 3
        modifier = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        modifier.keep_sharp = True
    return obj


def box(name, dimensions, position, mat, bevel=0.08, parent=plug_root, collection=master):
    bpy.ops.mesh.primitive_cube_add(size=1, location=mm(position))
    obj = bpy.context.object
    obj.dimensions = mm(dimensions)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel, parent, collection)


def tube(name, points, radius, mat, parent=plug_root, collection=master, resolution=2):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 1
    data.bevel_depth, data.bevel_resolution = radius / 1000, resolution
    data.use_fill_caps = True
    spline = data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*mm(coordinate), 1)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.parent = parent
    data.materials.append(mat)
    return obj


def label(name, words, position, size):
    data = bpy.data.curves.new(name, "FONT")
    data.body, data.size = words, size / 1000
    data.align_x, data.align_y, data.resolution_u = "CENTER", "CENTER", 3
    data.materials.append(ink)
    obj = bpy.data.objects.new(name, data)
    master.objects.link(obj)
    obj.parent, obj.location = plug_root, mm(position)
    return obj


def meshify(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.type != "MESH":
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.object
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def join(parts, name):
    parts = [meshify(part) for part in parts]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    return bpy.context.object


# Hollow transparent plug shell; contact pads remain on the OUTSIDE of the top.
shell = [box("PlugBottom", (11.6, 20.5, 0.35), (0, -10.25, -3.53), clear),
         box("PlugRoof", (11.6, 20.5, 0.35), (0, -10.25, 3.53), clear),
         box("PlugFront", (11.6, 0.35, 7.1), (0, -0.18, 0), clear)]
for side in (-1, 1):
    shell.append(box("PlugSide", (0.35, 20.5, 7.1), (side * 5.62, -10.25, 0), clear))
    shell.append(box("ContactGuardRail", (0.9, 8.5, 0.52), (side * 5.24, -4.4, 3.8), clear_rim))
shell.append(box("CableClamp", (9.3, 2.4, 4.4), (0, -16.6, -0.3), clear_rim, 0.3))
housing = join(shell, "Plug_Housing")
housing["mating_body_width_mm"] = 11.6
housing["mating_body_height_mm"] = 7.4

contact_parts, conductor_parts = [], []
colors = [(white, orange, "white/orange"), (orange, None, "orange"),
          (white, green, "white/green"), (wire_blue, None, "blue"),
          (white, wire_blue, "white/blue"), (green, None, "green"),
          (white, brown, "white/brown"), (brown, None, "brown")]
for index, (insulation, stripe, color_name) in enumerate(colors, 1):
    x = (index - 4.5) * 1.02
    contact_parts.append(box("GoldPad", (0.58, 6.4, 0.24), (x, -3.6, 3.87), gold, 0.05))
    contact_parts.append(box("CrimpBlade", (0.30, 0.6, 1.9), (x, -5.0, 2.93), gold, 0.035))
    conductor_parts.append(tube("InsulatedWire", [(x, -14.0, 1.7), (x, -0.7, 1.7)], 0.40, insulation, resolution=1))
    if stripe:
        stripe_points = []
        for step in range(65):
            y = -14 + 13.3 * step / 64
            angle = step / 64 * math.tau * 2.8
            stripe_points.append((x + 0.388 * math.cos(angle), y, 1.7 + 0.388 * math.sin(angle)))
        conductor_parts.append(tube("WireStripe", stripe_points, 0.060, stripe, resolution=0))
    marker = empty(f"Pin_{index:02}", (x, -3.6, 4.02), plug_root, master)
    marker.empty_display_type, marker.empty_display_size = "PLAIN_AXES", 0.0005
    marker["pin_number"], marker["insulation_color"] = index, color_name
contacts = join(contact_parts, "Contacts_8Pin")
contacts["contact_count"] = 8
join(conductor_parts, "Termination_Conductors")

# Cantilever latch under the plug; only the front catch enters the socket.
latch_parts = []
start, end = Vector((0, -2.8, -3.6)), Vector((0, -17.5, -6.0))
mid = (start + end) / 2
arm = box("LatchSpring", (3.7, (end - start).length, 0.65), mid, clear_rim, 0.18)
arm.rotation_euler.x = math.atan2(end.z - start.z, end.y - start.y)
latch_parts.append(arm)
latch_parts.append(box("LatchCatch", (4.05, 1.7, 1.0), (0, -7.8, -4.82), clear_rim, 0.16))
latch_parts.append(box("LatchReleasePad", (4.3, 3.2, 0.7), (0, -17.2, -6.0), clear_rim, 0.25))
latch = join(latch_parts, "Latch_Clip")
latch["role"] = "release tab; press toward plug body before pulling"


def boot_loft(name, sections):
    vertices, faces, steps = [], [], 32
    for y, width, height in sections:
        for i in range(steps):
            angle = i * math.tau / steps
            cx, sz = math.cos(angle), math.sin(angle)
            x = math.copysign(abs(cx) ** 0.55, cx) * width / 2
            z = math.copysign(abs(sz) ** 0.55, sz) * height / 2
            vertices.append(mm((x, y, z)))
    for row in range(len(sections) - 1):
        for i in range(steps):
            j = (i + 1) % steps
            faces.append((row * steps + i, row * steps + j, (row + 1) * steps + j, (row + 1) * steps + i))
    faces.append(tuple(reversed(range(steps))))
    faces.append(tuple((len(sections) - 1) * steps + i for i in range(steps)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    master.objects.link(obj)
    obj.parent = plug_root
    mesh.materials.append(boot_blue)
    for polygon in mesh.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    return obj


boot_parts = [boot_loft("BootBody", [(-18.5, 11.6, 9.4), (-20, 11.6, 9.4), (-23.5, 10.2, 8.8),
                                    (-30.8, 7.8, 7.5), (-34.5, 6.5, 6.5)])]
for y, width, height in [(-25.7, 9.8, 8.65), (-28.3, 9, 8.2), (-31.0, 8.1, 7.7)]:
    boot_parts.append(boot_loft("FlexRib", [(y + 0.42, width, height), (y + 0.12, width + 0.5, height + 0.5),
                                           (y - 0.12, width + 0.5, height + 0.5), (y - 0.42, width, height)]))
join(boot_parts, "Strain_Relief_Boot")
meshify(label("Boot_Legend", "CAT6", (0, -22.0, 4.67), 2.0))
empty("MatingTip", (0, 0, 0), plug_root, master)
empty("CableExit", (0, -34.5, 0), plug_root, master)


def bezier(a, b, c, d, steps):
    a, b, c, d = (np.array(point, dtype=float) for point in (a, b, c, d))
    result = []
    for t in np.linspace(0, 1, steps + 1):
        result.append((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t ** 2 * c + t ** 3 * d)
    return result


# Four loose non-intersecting turns; the inner tail bridges over the outer turns.
lead_a = bezier((-240, -255, 7), (-180, -220, 7), (-130, -195, 28), (-90, -170, 28), 48)
lead_b = bezier((-90, -170, 28), (-60, -151, 28), (-24, -144.723, 3.2), (0, -145, 3.2), 48)
coil = []
for t in np.linspace(0, 1, 769):
    theta = -math.pi / 2 + t * math.tau * 4
    radius = 145 + t * 42
    coil.append(np.array((radius * math.cos(theta), radius * math.sin(theta), 3.2)))
tail_b = bezier((0, -187, 3.2), (45, -187.401, 3.2), (110, -245, 7), (240, -270, 7), 64)
unscaled = np.array(lead_a + lead_b[1:] + coil[1:] + tail_b[1:])


def jacket_length(scale):
    values = unscaled.copy()
    values[:, :2] *= scale
    return float(np.linalg.norm(np.diff(values, axis=0), axis=1).sum())


low, high = 0.5, 2.0
for _ in range(50):
    mid = (low + high) / 2
    if jacket_length(mid) < 4931.0:
        low = mid
    else:
        high = mid
scale = (low + high) / 2
path_mm = unscaled.copy()
path_mm[:, :2] *= scale
path_length = float(np.linalg.norm(np.diff(path_mm, axis=0), axis=1).sum())
arc = np.concatenate(([0.0], np.cumsum(np.linalg.norm(np.diff(path_mm, axis=0), axis=1))))
dense_s = np.linspace(0, arc[-1], math.ceil(arc[-1] / 2) + 1)
dense = np.stack([np.interp(dense_s, arc, path_mm[:, axis]) for axis in range(3)], axis=1)
minimum_gap = math.inf
closest_points = None
for start_index in range(0, len(dense), 128):
    chunk = dense[start_index:start_index + 128]
    distances = np.linalg.norm(chunk[:, None, :] - dense[None, :, :], axis=2)
    local = np.abs(dense_s[start_index:start_index + len(chunk), None] - dense_s[None, :]) < 50
    distances[local] = np.inf
    if float(distances.min()) < minimum_gap:
        minimum_gap = float(distances.min())
        ia, ib = np.unravel_index(distances.argmin(), distances.shape)
        closest_points = (chunk[ia].tolist(), dense[ib].tolist())
print("PATH_CHECK", path_length, "min_nonlocal_centerline_mm", minimum_gap, flush=True)
print("CLOSEST_POINTS", closest_points, flush=True)
assert minimum_gap > 6.7, f"Cable intersects itself or is too close: {minimum_gap} mm"
source_curve = tube("Cable_Path_EDIT", path_mm, 3.1, blue, root, source, 2)
source_curve["centerline_length_m"] = path_length / 1000
source_curve["purpose"] = "Editable source. After editing, replace/re-export baked Cable_Jacket mesh."
jacket = source_curve.copy()
jacket.data = source_curve.data.copy()
asset.objects.link(jacket)
jacket.name = "Cable_Jacket"
meshify(jacket)
source.hide_render, source.hide_viewport = True, True


def clone_end(tag, point, inward_direction):
    direction = Vector((float(inward_direction[0]), float(inward_direction[1]), 0)).normalized()
    endpoint = empty(f"Plug_{tag}", parent=root)
    endpoint.rotation_euler.z = math.atan2(direction.y, direction.x) + math.pi / 2
    endpoint.location = Vector(mm(point)) - direction * 0.0345
    endpoint["wiring"] = "T568B"
    for original in list(master.objects):
        if original == plug_root:
            continue
        duplicate = original.copy()
        duplicate.name = original.name + "_" + tag
        duplicate.parent = endpoint
        asset.objects.link(duplicate)
    return endpoint


plug_a = clone_end("A", path_mm[0], np.array((60, 35, 0)))
plug_b = clone_end("B", path_mm[-1], np.array((-130, -25, 0)))
empty("Cable_Start", path_mm[0], root)
empty("Cable_End", path_mm[-1], root)
bpy.context.view_layer.update()
for tag, point in (("A", path_mm[0]), ("B", path_mm[-1])):
    assert (bpy.data.objects["CableExit_" + tag].matrix_world.translation - Vector(mm(point))).length < 0.000001

def export_glb(collection, path, active_root):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active_root
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_extras=True, export_yup=True, export_apply=True, export_animations=False,
        export_cameras=False, export_lights=False, export_materials="EXPORT")
    with path.open("rb") as handle:
        magic, version, length = struct.unpack("<4sII", handle.read(12))
        count, kind = struct.unpack("<II", handle.read(8))
        data = json.loads(handle.read(count))
    assert magic == b"glTF" and version == 2 and length == path.stat().st_size
    assert not data.get("images") and not data.get("cameras")
    return data


for obj in list(master.objects):
    if obj.type in {"CURVE", "FONT", "MESH"}:
        meshify(obj)
module_path = BASE / "ใช้ร่วมกัน/exports/rj45_cat6_plug.glb"
module_gltf = export_glb(master, module_path, plug_root)
whole_path = BASE / "ใช้ร่วมกัน/exports/lan_cable_cat6_5m.glb"
whole_gltf = export_glb(asset, whole_path, root)
names = {node.get("name", "") for node in whole_gltf["nodes"]}
assert all(name in names for name in ("Cat6_PatchCable_5m", "Cable_Jacket", "Plug_A", "Plug_B",
    "Contacts_8Pin_A", "Contacts_8Pin_B", "Latch_Clip_A", "Latch_Clip_B", "CableExit_A", "CableExit_B"))
assert "Cable_Path_EDIT" not in names
assert all(f"Pin_{i:02}_{end}" in names for end in ("A", "B") for i in range(1, 9))
assert any(mat.get("alphaMode") == "BLEND" for mat in whole_gltf["materials"]), "Clear plastic must retain transparency"
triangle_count = 0
for obj in asset.objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangle_count += len(obj.data.loop_triangles)
report = {"asset": "lan_cable_cat6_5m", "result": "PASS: structural GLB and path validation",
          "end_to_end_centerline_length_mm": round(path_length + 69, 6),
          "jacket_centerline_length_mm": round(path_length, 6), "jacket_diameter_mm": 6.2,
          "minimum_nonlocal_centerline_separation_mm": round(minimum_gap, 3),
          "path_sample_count": len(path_mm), "mesh_objects": sum(obj.type == "MESH" for obj in asset.objects),
          "triangles": triangle_count, "glb_bytes": whole_path.stat().st_size,
          "contacts_each_end": 8, "wiring": "T568B / T568B straight-through",
          "pin_colors": [item[2] for item in colors], "source_curve_in_blend": "Cable_Path_EDIT",
          "standalone_plug": module_path.name, "scene_integrated": False,
          "note": "Static coiled GLB; transparent polymer is an alpha approximation. No cable physics or game logic."}
(BASE / "ใช้ร่วมกัน/exports/lan_cable_cat6_5m.validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
(BASE / "ใช้ร่วมกัน/exports/lan_cable_cat6_5m.path.json").write_text(json.dumps({
    "units": "metres", "coordinate_system": "Blender Z-up, not glTF axes",
    "points": (path_mm / 1000).tolist(), "cable_radius": 0.0031,
    "note": "Source polyline, not automatically consumed by Godot."}, indent=2), encoding="utf-8")
print("ASSET_VALIDATION", json.dumps(report), flush=True)
master.hide_render, master.hide_viewport = True, True

# Review studio and optional macro-only cable stub, excluded from all GLBs.
floor_mat = material("Studio | warm gray", (0.34, 0.365, 0.38), roughness=0.75)
floor = box("StudioFloor", (3000, 3000, 3), (0, 0, -1.55), floor_mat, 0, None, studio)
preview_stub = tube("Studio_PlugCableStub", [(0, -34.5, 0), (0, -80, 0)], 3.1, blue, plug_root, studio)
preview_stub.hide_render = True


def area(name, position, target, watts, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.shape, data.color = watts, size, "DISK", color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = mm(position)
    obj.rotation_euler = (Vector(mm(target)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area("KeySoftbox", (-380, -360, 650), (0, -20, 5), 24, 0.46, (0.91, 0.96, 1))
area("FillSoftbox", (480, -70, 430), (0, -20, 5), 15, 0.38, (1, 0.91, 0.80))
area("RimSoftbox", (60, 420, 530), (0, 0, 5), 25, 0.40, (0.83, 0.92, 1))
scene.world = bpy.data.worlds.new("CableStudioWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.51, 0.58, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
camera_data = bpy.data.cameras.new("Camera_Cable")
camera = bpy.data.objects.new("Camera_Cable", camera_data)
studio.objects.link(camera)
camera_data.type, camera_data.clip_start, camera_data.clip_end = "ORTHO", 0.0005, 20
scene.camera = camera


def camera_fit(position, target, collection, resolution, margin=1.17):
    camera.location = mm(position)
    camera.rotation_euler = (Vector(mm(target)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = resolution
    bpy.context.view_layer.update()
    inverse = camera.matrix_world.inverted()
    points = [inverse @ (obj.matrix_world @ vertex.co) for obj in collection.objects if obj.type == "MESH" for vertex in obj.data.vertices]
    lo_x, hi_x = min(p.x for p in points), max(p.x for p in points)
    lo_y, hi_y = min(p.y for p in points), max(p.y for p in points)
    rotation = camera.rotation_euler.to_matrix()
    camera.location += rotation @ Vector(((lo_x + hi_x) / 2, (lo_y + hi_y) / 2, 0))
    camera_data.ortho_scale = max(hi_x - lo_x, (hi_y - lo_y) * resolution[0] / resolution[1]) * margin


scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 8
scene.cycles.transparent_max_bounces = 12
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.view_settings.exposure = -1.6
camera_fit((630, -820, 870), (0, -35, 5), asset, (1600, 1200))
scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders/lan_cable_cat6_5m_hero.png")
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for region in screen.areas:
        if region.type == "VIEW_3D":
            space = region.spaces.active
            space.clip_start, space.clip_end = 0.0005, 20
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.overlay.show_extras = False
            space.shading.type = "MATERIAL"
            space.region_3d.view_distance = 0.85
            space.region_3d.view_location = (0, -0.04, 0.007)
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_perspective = "PERSP"
bpy.ops.wm.save_as_mainfile(filepath=str(BASE / "ใช้ร่วมกัน/blend/lan_cable_cat6_5m.blend"))
print("BLEND_SAVED", flush=True)
for name in ("hero", "connector_closeup", "latch_closeup"):
    macro = name != "hero"
    asset.hide_render, asset.hide_viewport = macro, macro
    master.hide_render, master.hide_viewport = not macro, not macro
    preview_stub.hide_render = not macro
    if macro:
        plug_root.location.z = 0.0065 if name == "connector_closeup" else 0.00485
        plug_root.rotation_euler.y = 0 if name == "connector_closeup" else math.pi
        camera_fit((34, 43, 51), (0, -12, 5), master, (1500, 1100), 1.25)
    else:
        camera_fit((630, -820, 870), (0, -35, 5), asset, (1600, 1200))
    scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders" / f"lan_cable_cat6_5m_{name}.png")
    print("RENDER_START", name, flush=True)
    bpy.ops.render.render(write_still=True)
    print("RENDER_DONE", name, flush=True)
print("CAT6_BUILD_COMPLETE", flush=True)
