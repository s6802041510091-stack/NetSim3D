"""Build the original NetCare GS-08 educational switch asset in Blender.

Run with run_build_switch.ps1; all authored files and Blender work files stay on D:.
No third-party meshes or textures. Dimensions are authored in millimetres and
converted to metres. Blender +Z is up; Blender -Y is the front of the switch.
"""
from pathlib import Path
import json
import math
import os
import struct
import sys

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:", "This task requires D: storage only."
for folder in ("ใช้ร่วมกัน/blend", "ใช้ร่วมกัน/exports", "ใช้ร่วมกัน/renders", "temp", "ใช้ร่วมกัน/textures"):
    (BASE / folder).mkdir(parents=True, exist_ok=True)
TEMP = BASE / "temp"
bpy.context.preferences.filepaths.temporary_directory = str(TEMP)
if hasattr(bpy.context.preferences.filepaths, "use_save_preview_images"):
    bpy.context.preferences.filepaths.use_save_preview_images = False
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.context.preferences.filepaths.save_version = 0

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for collection in list(bpy.data.collections):
    if collection.users == 0:
        bpy.data.collections.remove(collection)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "MILLIMETERS"
scene.unit_settings.scale_length = 1.0
asset_collection = bpy.data.collections.new("ASSET | GS-08 Switch")
scene.collection.children.link(asset_collection)
studio_collection = bpy.data.collections.new("STUDIO | preview only")
scene.collection.children.link(studio_collection)


def mm(values):
    return tuple(float(v) / 1000 for v in values)


def move_to(obj, collection=asset_collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def material(name, rgb, metallic=0.0, roughness=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


body_mat = material("Housing | graphite blue powder coat", (0.032, 0.057, 0.079), 0.62, 0.34)
panel_mat = material("Front | satin graphite", (0.023, 0.034, 0.043), 0.5, 0.31)
base_mat = material("Base | anodized charcoal", (0.025, 0.029, 0.033), 0.55, 0.4)
silver = material("RJ45 | nickel shield", (0.47, 0.53, 0.57), 0.9, 0.27)
liner_mat = material("RJ45 | black polymer liner", (0.007, 0.009, 0.011), 0, 0.55)
gold = material("RJ45 | eight gold contacts", (0.68, 0.4, 0.092), 0.82, 0.24)
ink = material("Legend | warm white", (0.78, 0.85, 0.88), 0.12, 0.43)
subtle_ink = material("Legend | cool gray", (0.35, 0.45, 0.51), 0.1, 0.5)
accent = material("Accent | teal blue", (0.025, 0.37, 0.46), 0.55, 0.29)
rubber = material("Feet | nonslip rubber", (0.009, 0.011, 0.013), 0, 0.8)
power_mat = material("Power LED | ON", (0.12, 0.85, 0.24), 0.05, 0.22, 2)
screw_mat = material("Fasteners | dark steel", (0.10, 0.13, 0.16), 0.86, 0.28)

root = bpy.data.objects.new("OfficeSwitch_8Port", None)
asset_collection.objects.link(root)
root["asset_id"] = "netcare_gs08_v1"
root["description"] = "Original educational desktop Ethernet switch; 8 RJ45 8P8C ports; no wireless antennas."
root["dimensions_mm"] = [210.0, 110.0, 36.0]
root["port_count"] = 8
root["power_state_preview"] = "on; cable and external adapter not shown"
root["link_state_preview"] = "all off: no connected cables"


def finish(obj, name, mat, bevel=0):
    obj.name = name
    move_to(obj)
    obj.parent = root
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        mod.width = bevel / 1000
        mod.segments = 3
        mod.affect = "EDGES"
        mod = obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
    return obj


def box(name, dims, pos, mat, bevel=0.15):
    bpy.ops.mesh.primitive_cube_add(size=1, location=mm(pos))
    obj = bpy.context.object
    obj.dimensions = mm(dims)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)


def cylinder(name, radius, depth, pos, mat, rotation=(0, 0, 0), vertices=24, bevel=0.12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius/1000, depth=depth/1000, location=mm(pos), rotation=rotation)
    obj = bpy.context.object
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return finish(obj, name, mat, bevel)


def wire(name, points, radius, mat):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius/1000
    curve.bevel_resolution = 2
    curve.resolution_u = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points)-1)
    for point, co in zip(spline.points, points):
        point.co = (*mm(co), 1)
    obj = bpy.data.objects.new(name, curve)
    asset_collection.objects.link(obj)
    obj.parent = root
    curve.materials.append(mat)
    return obj


def text_obj(name, content, pos, size, mat=ink, facing="front", align="CENTER"):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = content
    curve.size = size/1000
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.resolution_u = 4
    obj = bpy.data.objects.new(name, curve)
    asset_collection.objects.link(obj)
    obj.parent = root
    obj.location = mm(pos)
    if facing == "front":
        obj.rotation_euler = (math.pi/2, 0, 0)
    elif facing == "rear":
        obj.rotation_euler = (math.pi/2, 0, math.pi)
    curve.materials.append(mat)
    return obj


def apply_mesh(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.type != "MESH":
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.object
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def join_objects(objects, name):
    objects = [apply_mesh(obj) for obj in objects]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    return obj


# Hollow folded-metal chassis. Front is assembled around real openings.
static = []
static.append(box("Lid", (210, 110, 1.8), (0, 0, 35.1), body_mat, 0.8))
static.append(box("LowerTray", (208.5, 108.5, 2.0), (0, 0, 5.0), base_mat, 0.8))
static.append(box("FrontUpperRail", (208, 1.8, 8.0), (0, -54, 30), panel_mat, 0.3))
static.append(box("FrontLowerRail", (208, 1.8, 4.8), (0, -54, 8.4), panel_mat, 0.25))
port_xs = [-60 + 20*i for i in range(8)]
front_intervals = [(-104, port_xs[0]-8.2)]
front_intervals += [(x+8.2, x+20-8.2) for x in port_xs[:-1]]
front_intervals.append((port_xs[-1]+8.2, 104))
for i, (left, right) in enumerate(front_intervals):
    static.append(box(f"FrontWeb_{i}", (right-left, 1.8, 15.2), ((left+right)/2, -54, 18.4), panel_mat, 0.16))
static.append(box("RearPanel", (207, 1.8, 28), (0, 54, 20), base_mat, 0.4))

# Physical ventilation openings, rather than painted-on texture slots.
for side in (-1, 1):
    sx = side * 104
    static.append(box(f"SideLower_{side}", (1.8, 108, 10), (sx, 0, 10.9), body_mat, 0.3))
    static.append(box(f"SideUpper_{side}", (1.8, 108, 10), (sx, 0, 29.1), body_mat, 0.3))
    for i in range(14):
        lo = -54 + i*8
        if lo >= 54:
            break
        static.append(box(f"VentRib_{side}_{i}", (1.8, min(4,54-lo), 8.2), (sx, lo+min(4,54-lo)/2, 20), body_mat, 0.3))
    # Dark baffle behind the openings prevents seeing through the complete case.
    static.append(box(f"VentBaffle_{side}", (0.8, 105, 11), (side*101.1, 0, 20), liner_mat, 0.1))

for x in (-88, 88):
    for y in (-39, 39):
        static.append(cylinder("RubberFoot", 7, 4, (x, y, 2), rubber, vertices=32, bevel=0.55))
for x in (-96, 96):
    for y in (-45, 45):
        static.append(cylinder("LidScrew", 1.5, 0.26, (x, y, 36.07), screw_mat, vertices=20, bevel=0.07))
        static.append(box("ScrewRecessX", (1.7, 0.28, 0.06), (x, y, 36.22), liner_mat, 0.04))
        static.append(box("ScrewRecessY", (0.28, 1.7, 0.06), (x, y, 36.22), liner_mat, 0.04))

# Product identity: restrained, generic NetCare educational equipment.
legends = []
legends.append(text_obj("TopBrand", "NETCARE", (-85, 25, 36.035), 8, ink, "top", "LEFT"))
legends.append(text_obj("TopModel", "GS-08", (-85, 13, 36.035), 5, subtle_ink, "top", "LEFT"))
legends.append(text_obj("TopDescription", "8-PORT GIGABIT SWITCH", (-85, 4, 36.035), 3.5, subtle_ink, "top", "LEFT"))
static.append(box("BrandAccent", (1.1, 26, 0.10), (-91, 17, 36.04), accent, 0.04))
legends.append(text_obj("FrontModel", "GS-08", (-89, -55.03, 29.5), 3.1))
legends.append(text_obj("PowerLegend", "PWR", (-89, -55.03, 11.5), 2.4, subtle_ink))
legends.append(text_obj("FrontRate", "10 / 100 / 1000 Mbps", (10, -55.03, 7.3), 2.0, subtle_ink))

# Power LED is independent of each Link/Activity LED.
static.append(cylinder("PowerBezel", 2.0, 0.9, (-89, -55.05, 19), liner_mat, (math.pi/2,0,0), bevel=0.1))
power_led = cylinder("LED_Power", 1.3, 0.65, (-89, -55.65, 19), power_mat, (math.pi/2,0,0), vertices=24, bevel=0.18)
power_led["role"] = "power_indicator"
power_led["default_on"] = True

port_meshes = []
for number, x in enumerate(port_xs, 1):
    parts = []
    # 8P8C metal shield and black cavity. Clear opening is 12.8 x 10.6 mm.
    parts.append(box("ShieldTop", (16.2, 10.8, 1.0), (x, -51.0, 24.5), silver, 0.19))
    parts.append(box("ShieldBottom", (16.2, 10.8, 1.0), (x, -51.0, 11.3), silver, 0.19))
    for sign in (-1,1):
        parts.append(box("ShieldSide", (0.8, 10.8, 12.2), (x+sign*7.7, -51.0, 17.9), silver, 0.18))
        parts.append(box("InsulatingSide", (1.0, 9.5, 10.8), (x+sign*6.9, -50.55, 17.9), liner_mat, 0.08))
        # Stepped bottom opening leaves a central latch keyway.
        parts.append(box("LatchShoulder", (4.3, 9.4, 1.35), (x+sign*4.45, -50.7, 12.5), liner_mat, 0.08))
    parts.append(box("JackCeiling", (13.8, 9.5, 0.8), (x, -50.55, 23.4), liner_mat, 0.1))
    parts.append(box("JackBack", (14, 0.65, 11.6), (x, -45.2, 18), liner_mat, 0.1))
    parts.append(box("JackFloor", (13.8, 9.5, 0.4), (x, -50.55, 11.95), liner_mat, 0.08))
    for contact in range(8):
        cx = x + (contact-3.5)*1.02
        parts.append(wire(f"Contact_{contact+1}", [(cx,-45.7,22.8),(cx,-47.3,22.3),(cx,-52.7,18.8),(cx,-54.35,18.7)], 0.17, gold))
    for sign in (-1,1):
        parts.append(box("ShieldGroundTab", (0.20, 3.1, 2.0), (x+sign*7.17,-53.1,17.8), silver, 0.07))
    port = join_objects(parts, f"RJ45_Port_{number:02d}")
    port["port_number"] = number
    port["connector"] = "8P8C modular Ethernet jack (commonly called RJ45)"
    port["contact_count"] = 8
    port_meshes.append(port)
    legends.append(text_obj(f"PortNumber_{number}", str(number), (x-1.4, -55.05, 29.5), 3.1))
    static.append(box(f"LEDBezel_{number}", (3.6,0.75,2.3), (x+4.3,-55.2,29.4), liner_mat, 0.38))
    led_mat = material(f"Link_{number:02d} | OFF", (0.014, 0.07, 0.025), 0, 0.26)
    led = box(f"LED_Link_{number:02d}", (2.4,0.35,1.3), (x+4.3,-55.66,29.4), led_mat, 0.30)
    led["port_number"] = number
    led["role"] = "link_activity_indicator"
    led["default_on"] = False
    anchor = bpy.data.objects.new(f"Socket_RJ45_{number:02d}", None)
    asset_collection.objects.link(anchor)
    anchor.parent = root
    anchor.location = mm((x,-56.5,17.9))
    anchor.empty_display_type = "ARROWS"
    anchor.empty_display_size = 0.004
    anchor["role"] = "cable_attachment"
    anchor["port_number"] = number
    anchor["outward_axis_blender"] = "-Y"
    anchor["outward_axis_gltf"] = "+Z"

# Rear external power inlet (no adapter/cable is part of this asset).
static.append(box("DCPowerMount", (15,1.5,15), (81,55.1,20), panel_mat, 1.0))
static.append(cylinder("DCPowerMetalRing", 3.5, 1.8, (81,56.1,20), silver, (math.pi/2,0,0), vertices=32, bevel=0.12))
static.append(cylinder("DCPowerRecess", 2.75, 0.5, (81,57.06,20), liner_mat, (math.pi/2,0,0), vertices=32, bevel=0.12))
static.append(cylinder("DCPowerPin", 0.65, 1.0, (81,57.5,20), silver, (math.pi/2,0,0), vertices=16, bevel=0.10))
legends.append(text_obj("DCPowerLabel", "DC IN", (81,55.1,31.1), 2.8, ink, "rear"))
legends.append(text_obj("RearDescription", "NETCARE   |   GS-08   |   DESKTOP ETHERNET SWITCH", (0,55.1,20), 2.5, subtle_ink, "rear"))
anchor = bpy.data.objects.new("Socket_DC", None)
asset_collection.objects.link(anchor)
anchor.parent = root
anchor.location = mm((81,58,20))
anchor.empty_display_type = "ARROWS"
anchor.empty_display_size = 0.004
anchor["role"] = "dc_power_attachment"

join_objects(static, "Chassis")
join_objects(legends, "Printed_Legends")
apply_mesh(power_led)
for obj in list(asset_collection.objects):
    if obj.type in {"MESH", "CURVE", "FONT"}:
        apply_mesh(obj)

# Export only the switch. Studio elements never enter the GLB.
bpy.ops.object.select_all(action="DESELECT")
for obj in asset_collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
export_path = BASE / "ใช้ร่วมกัน/exports" / "office_switch_8port.glb"
bpy.ops.export_scene.gltf(filepath=str(export_path), export_format="GLB", use_selection=True,
    export_extras=True, export_yup=True, export_apply=True, export_animations=False,
    export_cameras=False, export_lights=False, export_materials="EXPORT")

# Validate the exported GLB structure rather than only checking its file size.
with export_path.open("rb") as handle:
    magic, version, length = struct.unpack("<4sII", handle.read(12))
    json_length, json_kind = struct.unpack("<II", handle.read(8))
    exported = json.loads(handle.read(json_length))
assert magic == b"glTF" and version == 2
names = [node.get("name", "") for node in exported["nodes"]]
for prefix in ("RJ45_Port_", "LED_Link_", "Socket_RJ45_"):
    expected = [f"{prefix}{i:02d}" for i in range(1,9)]
    assert all(name in names for name in expected), (prefix, names)
assert "LED_Power" in names and "Socket_DC" in names
assert not exported.get("cameras")
assert not exported.get("images"), "Asset should be self-contained with solid PBR materials."
triangles = sum(len(mesh.loop_triangles) for mesh in [])
for obj in asset_collection.objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
report = {
    "asset": "office_switch_8port", "dimensions_mm": [210,110,36],
    "units": "meters", "ports":8, "contacts_per_port":8,
    "mesh_objects": sum(o.type == "MESH" for o in asset_collection.objects),
    "triangles":triangles, "glb_bytes":export_path.stat().st_size,
    "validation":"PASS: 8 ports, 8 independent link LEDs, 8 socket anchors, power LED, DC anchor",
    "export_front_axis":"+Z", "export_up_axis":"+Y",
    "notes":["Original generic educational design, not a manufacturer's CAD model.",
             "LEDs and sockets are prepared for future integration; this file contains no game logic.",
             "Power LED on; all link LEDs off because no network cables are attached."]
}
(BASE / "ใช้ร่วมกัน/exports" / "office_switch_8port.validation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("ASSET_VALIDATION:", json.dumps(report), flush=True)

# Studio camera and lighting for the reviewable Blender file and preview images.
floor_mat = material("Studio | warm neutral", (0.32,0.35,0.38), 0.0, 0.67)
floor = box("StudioFloor", (2000,2000,2), (0,0,-1.02), floor_mat, 0)
floor.parent = None
move_to(floor, studio_collection)


def area(name, pos, target, watts, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = watts
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    studio_collection.objects.link(obj)
    obj.location = mm(pos)
    obj.rotation_euler = (Vector(mm(target))-obj.location).to_track_quat("-Z","Y").to_euler()
    return obj


area("KeySoftbox", (-180,-170,280), (0,0,15), 8.0, 0.25, (0.84,0.91,1.0))
area("FillSoftbox", (210,-100,130), (0,-25,18), 5.5, 0.19, (1.0,0.88,0.74))
area("TopRim", (10,130,240), (0,0,20), 9.0, 0.22, (0.80,0.91,1.0))
area("FrontPortFill", (-5,-220,60), (0,-47,18), 1.8, 0.18, (1,1,1))
scene.world = bpy.data.worlds.new("StudioWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45,0.50,0.60,1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.28

camera_data = bpy.data.cameras.new("Camera_Product")
camera = bpy.data.objects.new("Camera_Product", camera_data)
studio_collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.lens = 60
camera_data.clip_start = 0.001
camera_data.clip_end = 20


def camera_pose(pos, target, ortho):
    camera.location = mm(pos)
    camera.rotation_euler = (Vector(mm(target))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera_data.ortho_scale = ortho


camera_pose((240,-350,240), (0,0,16), 0.31)
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.filepath = str(BASE/"ใช้ร่วมกัน/renders"/"office_switch_8port_hero.png")
scene.view_settings.view_transform = "AgX"

# When opened, the .blend starts in a close material-preview view of the asset.
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for ar in screen.areas:
        if ar.type == "VIEW_3D":
            space = ar.spaces.active
            space.clip_start = 0.001
            space.clip_end = 20
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.shading.type = "MATERIAL"
            space.region_3d.view_distance = 0.34
            space.region_3d.view_location = (0,0,0.018)
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_perspective = "PERSP"

bpy.ops.wm.save_as_mainfile(filepath=str(BASE/"ใช้ร่วมกัน/blend"/"office_switch_8port.blend"))
print("BLEND_SAVED", flush=True)

for name, pos, target, ortho, res in [
    ("hero", (240,-350,240), (0,0,16), 0.31, (1600,1000)),
    ("front", (0,-340,64), (0,-48,19), 0.238, (1800,700)),
    ("ports_closeup", (16,-185,56), (0,-52,19), 0.088, (1200,720)),
    ("rear", (-220,330,175), (0,0,18), 0.29, (1400,900)),
]:
    camera_pose(pos,target,ortho)
    scene.render.resolution_x,scene.render.resolution_y = res
    scene.render.filepath = str(BASE/"ใช้ร่วมกัน/renders"/f"office_switch_8port_{name}.png")
    print("RENDER_START", name, flush=True)
    bpy.ops.render.render(write_still=True)
    print("RENDER_DONE", name, flush=True)
print("BUILD_COMPLETE", flush=True)
