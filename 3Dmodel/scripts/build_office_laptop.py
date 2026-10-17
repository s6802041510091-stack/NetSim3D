"""Original educational business laptop. No downloaded meshes or textures.

Run through run_build_laptop.ps1 to keep Blender config/cache/temp on D:.
Millimetre design values are converted to metre units; front is Blender -Y.
"""
from pathlib import Path
import json
import math
import struct

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
for folder in ("ใช้ร่วมกัน/blend", "ใช้ร่วมกัน/exports", "ใช้ร่วมกัน/renders", "temp/laptop"):
    (BASE / folder).mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/laptop")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for mat in list(bpy.data.materials):
    if not mat.users:
        bpy.data.materials.remove(mat)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "MILLIMETERS"
asset = bpy.data.collections.new("ASSET | NetCare WorkBook 14")
studio = bpy.data.collections.new("STUDIO | preview only")
scene.collection.children.link(asset)
scene.collection.children.link(studio)
root = bpy.data.objects.new("OfficeLaptop_14", None)
asset.objects.link(root)
root["asset_id"] = "netcare_workbook14_v1"
root["description"] = "Original 14-inch business laptop with integrated Ethernet NIC and full-size RJ45 jack."
root["power_source_preview"] = "internal battery; no charger connected"
root["network_preview"] = "disconnected; Ethernet LEDs off"


def mm(values):
    return tuple(v / 1000 for v in values)


def move_to(obj, collection):
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def material(name, rgb, metal=0, rough=0.4, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    if emission:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


aluminum = material("Housing | satin titanium", (0.20, 0.245, 0.28), 0.78, 0.33)
deck_mat = material("Deck | cool aluminum", (0.27, 0.315, 0.345), 0.7, 0.39)
dark = material("Recess | matte black", (0.009, 0.013, 0.018), 0, 0.48)
keys_mat = material("Keys | charcoal polymer", (0.025, 0.032, 0.042), 0, 0.42)
rubber = material("Rubber | feet and gasket", (0.014, 0.019, 0.024), 0, 0.76)
silver = material("Connectors | nickel shield", (0.51, 0.58, 0.63), 0.9, 0.23)
gold = material("Contacts | gold plating", (0.72, 0.43, 0.105), 0.84, 0.24)
ink = material("Key legends | off white", (0.80, 0.86, 0.90), 0, 0.5)
gray_ink = material("Housing legends | graphite", (0.042, 0.059, 0.073), 0.2, 0.5)
teal = material("Accent | restrained teal", (0.025, 0.37, 0.40), 0.35, 0.35)
trackpad_mat = material("Touchpad | matte glass", (0.135, 0.17, 0.195), 0.2, 0.5)
glass = material("Webcam | optical glass", (0.007, 0.023, 0.042), 0.45, 0.09)
usb_blue = material("USB-A | blue insulator", (0.025, 0.13, 0.40), 0, 0.45)
power_mat = material("LED Power | white ON", (0.6, 0.83, 0.85), 0, 0.25, 1.2)
link_mat = material("LED Ethernet Link | OFF", (0.010, 0.042, 0.02), 0, 0.4)
activity_mat = material("LED Ethernet Activity | OFF", (0.07, 0.036, 0.006), 0, 0.4)


def finish(obj, name, mat, bevel=0, parent=root):
    obj.name = name
    move_to(obj, asset)
    obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Machined edge radius", "BEVEL")
        modifier.width = bevel / 1000
        modifier.segments = 3
        modifier = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        modifier.keep_sharp = True
    return obj


def box(name, dims, pos, mat, bevel=0.2, parent=root):
    bpy.ops.mesh.primitive_cube_add(size=1, location=mm(pos))
    obj = bpy.context.object
    obj.dimensions = mm(dims)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel, parent)


def cylinder(name, radius, depth, pos, mat, rot=(0, 0, 0), bevel=0.12, parent=root, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius / 1000, depth=depth / 1000,
                                      location=mm(pos), rotation=rot)
    obj = bpy.context.object
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return finish(obj, name, mat, bevel, parent)


def wire(name, coords, radius, mat, parent=root):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius / 1000
    curve.bevel_resolution = 1
    curve.resolution_u = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(coords) - 1)
    for point, co in zip(spline.points, coords):
        point.co = (*mm(co), 1)
    obj = bpy.data.objects.new(name, curve)
    asset.objects.link(obj)
    obj.parent = parent
    curve.materials.append(mat)
    return obj


def text(name, content, pos, size, mat=ink, facing="top", align="CENTER", parent=root):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = content
    curve.size = size / 1000
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.resolution_u = 3
    obj = bpy.data.objects.new(name, curve)
    asset.objects.link(obj)
    obj.parent = parent
    obj.location = mm(pos)
    if facing == "front":
        obj.rotation_euler = (math.pi / 2, 0, 0)
    elif facing == "rear":
        obj.rotation_euler = (math.pi / 2, 0, math.pi)
    curve.materials.append(mat)
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
    parts = [meshify(obj) for obj in parts]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    return bpy.context.object


def empty(name, pos, parent=root, rotation=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    asset.objects.link(obj)
    obj.parent = parent
    obj.location = mm(pos)
    obj.rotation_euler = rotation
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.008
    return obj


def cut_box(target, name, dims, pos):
    cutter = meshify(box(name, dims, pos, None, 0.35))
    bpy.context.view_layer.objects.active = target
    modifier = target.modifiers.new(name, "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.solver = "EXACT"
    modifier.object = cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


# Real port cut-outs in the body; no rectangles painted over a solid case.
base_parts = []
shell = meshify(box("BaseHousing", (338, 234, 18), (0, 0, 12), aluminum, 2.5))
for name, dims, pos in [
    ("LAN_cut", (20, 17, 14.5), (-166, 70, 12.5)),
    ("USB_left_cut", (18, 14.4, 6), (-166, 33, 12.5)),
    ("USB_right_cut", (18, 14.4, 6), (166, 70, 12.5)),
    ("HDMI_cut", (18, 15.4, 6.6), (166, 35, 12.5)),
    ("DC_cut", (18, 7.5, 7.5), (-166, 99, 12.5)),
    ("Audio_cut", (18, 5.6, 5.6), (166, 5, 12.5)),
]:
    cut_box(shell, name, dims, pos)
base_parts.append(shell)
base_parts.append(box("UpperDeck", (337, 233, 2), (0, 0, 22), deck_mat, 1))
base_parts.append(box("BottomTray", (330, 226, 1.2), (0, 0, 3), aluminum, 0.55))
base_parts.append(box("KeyboardBed", (284, 120, 0.45), (0, 35, 23.22), dark, 3))
base_parts.append(box("TrackpadRim", (111, 63, 0.32), (0, -69, 23.11), silver, 2))
touchpad = box("Touchpad", (109.8, 61.8, 0.25), (0, -69, 23.34), trackpad_mat, 1.6)
for x in (-137, 137):
    for y in (-91, 92):
        base_parts.append(box("RubberFoot", (24, 8, 2.8), (x, y, 1.4), rubber, 1.3))
for x in (-146, 146):
    for y in (-97, 0, 94):
        base_parts.append(cylinder("BottomScrew", 1.3, 0.18, (x, y, 2.32), silver, bevel=0.04))
for x in (-119, 119):
    base_parts.append(cylinder("HingeBarrel", 5.3, 38, (x, 103, 23.5), aluminum,
                               (0, math.pi / 2, 0), 0.45, vertices=32))
    base_parts.append(cylinder("HingeEnd", 4.9, 0.7, (x - 19.2, 103, 23.5), dark,
                               (0, math.pi / 2, 0), 0.2))
for x in (-154, 154):
    for y in range(-6, 81, 4):
        base_parts.append(box("SpeakerGrille", (3.6, 1.15, 0.08), (x, y, 23.08), dark, 0.45))
for x in range(-94, 95, 7):
    base_parts.append(box("RearExhaust", (3.8, 0.2, 4), (x, 116.78, 13), dark, 0.4))
base_parts.append(box("LidLiftNotch", (28, 0.3, 1.35), (0, -116.66, 21.4), dark, 0.5))
join(base_parts, "Chassis_Base")

# Compact QWERTY layout, with correctly proportioned modifier keys.
keycaps, key_legends = [], []


def key(label, x, y, width, height=14, size=3):
    keycaps.append(box("Key_" + label, (width, height, 1.8), (x, y, 24.22), keys_mat, 1.05))
    if label:
        key_legends.append(text("Legend_" + label, label, (x, y, 25.16), size))


def row(keys, y):
    pitch = 18.3
    current = -15 * pitch / 2
    for label, units in keys:
        if label == "^ / v":
            key("^", current + units * pitch / 2, y + 3.9, units * pitch - 2.1, 6.1, 2.7)
            key("v", current + units * pitch / 2, y - 3.9, units * pitch - 2.1, 6.1, 2.7)
        else:
            key(label, current + units * pitch / 2, y, units * pitch - 2.1,
                size=2.5 if len(label) > 2 else 3.3)
        current += units * pitch


for i, label in enumerate(["Esc"] + [f"F{i}" for i in range(1, 13)] + ["Del"]):
    key(label, -128 + i * 19.7, 83, 16.4, 9, 2.5)
row([(x, 1) for x in ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]] + [("Back", 2)], 63)
row([("Tab", 1.5)] + [(x, 1) for x in "QWERTYUIOP[]"] + [("\\", 1.5)], 44)
row([("Caps", 1.8)] + [(x, 1) for x in "ASDFGHJKL;'"] + [("Enter", 2.2)], 25)
row([("Shift", 2.3)] + [(x, 1) for x in "ZXCVBNM,./"] + [("Shift", 2.7)], 6)
row([("Ctrl", 1.3), ("Fn", 1), ("Win", 1), ("Alt", 1.2), ("", 5.1), ("Alt", 1.2), ("Ctrl", 1.2),
     ("<", 1), ("^ / v", 1), (">", 1)], -13)
join(keycaps, "Keyboard_Keycaps")
join(key_legends, "Keyboard_Legends")
power_button = cylinder("PowerButton", 3.5, 0.7, (147, 101, 23.55), keys_mat, bevel=0.3, vertices=32)
power_led = box("LED_Power", (2.1, 0.65, 0.10), (147, 101, 23.94), power_mat, 0.2)
power_led["default_on"] = True
legends = [text("PalmBrand", "NETCARE", (108, -71, 23.08), 4, gray_ink),
           text("PalmModel", "WORKBOOK 14", (108, -79, 23.08), 2.3, gray_ink)]
for label, x, y in [("LAN", -158, 70), ("USB", -158, 33), ("DC", -158, 99),
                     ("USB", 158, 70), ("HDMI", 158, 35), ("AUDIO", 155, 5)]:
    obj = text("PortLabel_" + label, label, (x, y, 23.08), 2.4, gray_ink)
    obj.rotation_euler.z = -math.pi / 2 if x < 0 else math.pi / 2
    legends.append(obj)
join(legends, "Body_Legends")

# The Ethernet connector is made in its own local frame: front -Y, depth +Y.
lan_frame = empty("Ethernet_NIC_Port", (-169.15, 70, 12.5), rotation=(0, 0, -math.pi / 2))
lan_frame["role"] = "external jack for integrated Ethernet NIC; not a router or modem"
lan_parts = []
for sign in (-1, 1):
    lan_parts.append(box("RJ45ShieldSide", (0.65, 12, 13.5), (sign * 7.75, 5.8, 0), silver, 0.13, lan_frame))
    lan_parts.append(box("RJ45LinerSide", (0.8, 10, 11.8), (sign * 7.05, 5.6, 0), dark, 0.1, lan_frame))
    lan_parts.append(box("RJ45LatchShoulder", (4.3, 10, 1.6), (sign * 4.5, 5.6, -5.5), dark, 0.1, lan_frame))
lan_parts += [
    box("RJ45ShieldTop", (16.1, 12, 0.65), (0, 5.8, 6.6), silver, 0.13, lan_frame),
    box("RJ45ShieldBottom", (16.1, 12, 0.65), (0, 5.8, -6.6), silver, 0.13, lan_frame),
    box("RJ45Back", (14, 0.65, 12), (0, 11.5, 0), dark, 0.1, lan_frame),
    box("RJ45Ceiling", (14, 10, 0.7), (0, 5.6, 5.8), dark, 0.1, lan_frame),
    box("RJ45Floor", (14, 10, 0.45), (0, 5.6, -6), dark, 0.1, lan_frame),
]
for i in range(8):
    cx = (i - 3.5) * 1.02
    lan_parts.append(wire(f"LANContact_{i + 1}", [(cx, 10.9, 5.4), (cx, 8.9, 4.9), (cx, 2.2, 1.1), (cx, 0.9, 1)],
                          0.17, gold, lan_frame))
lan_jack = join(lan_parts, "Port_RJ45_LAN")
lan_jack["contact_count"] = 8
for name, x, mat in [("LED_LAN_Link", -5.7, link_mat), ("LED_LAN_Activity", 5.7, activity_mat)]:
    led = box(name, (1.1, 0.22, 0.85), (x, -0.24, 5.6), mat, 0.13, lan_frame)
    led["default_on"] = False
lan_socket = empty("Socket_RJ45_LAN", (0, -0.8, 0), lan_frame)
lan_socket["role"] = "Ethernet cable attachment"
lan_socket["local_outward_axis_blender"] = "-Y"
lan_socket["local_outward_axis_gltf"] = "+Z"


def usb_port(name, side, y):
    frame = empty(name + "_Mount", (side * 169.12, y, 12.5), rotation=(0, 0, side * math.pi / 2))
    parts = []
    for sign in (-1, 1):
        parts.append(box("USBShieldSide", (0.45, 10, 5.3), (sign * 6.65, 4.9, 0), silver, 0.1, frame))
        parts.append(box("USBShieldRail", (13.6, 10, 0.4), (0, 4.9, sign * 2.5), silver, 0.1, frame))
    parts.append(box("USBRecess", (12.7, 0.5, 4.5), (0, 9.6, 0), dark, 0.1, frame))
    parts.append(box("USBInsulator", (10.8, 8.5, 1.2), (0, 5.2, 0.3), usb_blue, 0.15, frame))
    for x in (-3, -1, 1, 3):
        parts.append(box("USBContact", (0.55, 5, 0.08), (x, 5.6, -0.35), gold, 0.03, frame))
    join(parts, name)
    empty("Socket_" + name, (0, -0.8, 0), frame)["role"] = "USB-A attachment placeholder"


usb_port("USB_A_Left", -1, 33)
usb_port("USB_A_Right", 1, 70)


def ring_mesh(name, outline, thickness, depth, mat, parent, inner_outline=None):
    # Extruded open ring for a recognizable HDMI Type-A shape.
    outer = outline
    inner = inner_outline if inner_outline is not None else [(x * (1 - thickness / 7.4), z * (1 - thickness / 3.0)) for x, z in outline]
    verts = []
    for y in (0, depth):
        for shape in (outer, inner):
            verts += [(x / 1000, y / 1000, z / 1000) for x, z in shape]
    n = len(outline)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces += [(i, j, n + j, n + i), (i, 2 * n + i, 2 * n + j, j),
                  (n + i, n + j, 3 * n + j, 3 * n + i),
                  (2 * n + i, 3 * n + i, 3 * n + j, 2 * n + j)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    asset.objects.link(obj)
    obj.parent = parent
    mesh.materials.append(mat)
    return obj


hdmi_frame = empty("HDMI_Mount", (169.15, 35, 12.5), rotation=(0, 0, math.pi / 2))
outline = [(-7.2, 2.8), (7.2, 2.8), (7.2, -0.6), (5.4, -2.8), (-5.4, -2.8), (-7.2, -0.6)]
hdmi_parts = [ring_mesh("HDMIShield", outline, 0.45, 9, silver, hdmi_frame),
              box("HDMIBack", (13, 0.4, 4.3), (0, 8.8, 0), dark, 0.1, hdmi_frame),
              box("HDMITongue", (10.3, 6.5, 1.1), (0, 5.4, 0), dark, 0.15, hdmi_frame)]
for i in range(10):
    hdmi_parts.append(box("HDMIContact", (0.33, 3.8, 0.06), ((i - 4.5) * 0.86, 5.4, 0.58), gold, 0.015, hdmi_frame))
join(hdmi_parts, "Port_HDMI")
empty("Socket_HDMI", (0, -0.8, 0), hdmi_frame)
other_ports = []
for name, side, y, radius in [("DC_IN", -1, 99, 3.2), ("Headset", 1, 5, 2.5)]:
    frame = empty(name + "_Mount", (side * 169.05, y, 12.5), rotation=(0, 0, side * math.pi / 2))
    outer = [(radius * math.cos(i * math.tau / 32), radius * math.sin(i * math.tau / 32)) for i in range(32)]
    inner_radius = radius - 0.6
    inner = [(inner_radius * math.cos(i * math.tau / 32), inner_radius * math.sin(i * math.tau / 32)) for i in range(32)]
    other_ports.append(ring_mesh(name + "OpenTube", outer, 0, 6, silver, frame, inner))
    other_ports.append(box(name + "RecessBack", (radius * 2.2, 0.5, radius * 2.2), (0, 6.3, 0), dark, 0.1, frame))
    if name == "DC_IN":
        other_ports.append(cylinder("DCPin", 0.65, 4, (0, 3.7, 0), silver, (math.pi / 2, 0, 0), 0.06, frame))
    empty("Socket_" + name, (0, -0.8, 0), frame)
join(other_ports, "Power_And_Audio_Jacks")

# Display children are authored relative to a genuine hinge pivot.
hinge = empty("Display_Hinge", (0, 103, 23.5), rotation=(-math.radians(12), 0, 0))
hinge["open_angle_degrees"] = 102
hinge["closed_rotation_x_degrees"] = 90
hinge["preview_rotation_x_degrees"] = -12
display_shell = [box("LidAluminum", (334, 7.2, 207), (0, 0, 110.5), aluminum, 2.4, hinge),
                 box("DisplayRubberGasket", (330, 0.6, 203), (0, -3.65, 110.5), rubber, 2.1, hinge),
                 box("ScreenBezel", (327, 0.8, 200), (0, -4.2, 110.5), dark, 1.6, hinge)]
display_shell.append(text("LidBrand", "NETCARE", (0, 3.64, 116), 12, ink, "rear", parent=hinge))
display_shell.append(text("BezelBrand", "NETCARE", (0, -4.64, 17), 3.7, ink, "front", parent=hinge))
join(display_shell, "Display_Housing")
screen_mat = material("Screen | navy LCD", (0.012, 0.030, 0.043), 0, 0.42, 0.35)
panel = box("Screen_Panel", (310, 0.22, 174.375), (0, -4.72, 114), screen_mat, 0.4, hinge)
panel["display_role"] = "Replace material or hide Screen_Demo_UI for live Godot UI"
panel["aspect_ratio"] = "16:9"
panel["diagonal_inches_approx"] = 14
camera_parts = [cylinder("WebcamRing", 1.8, 0.17, (0, -4.64, 207), silver, (math.pi / 2, 0, 0), 0.05, hinge),
                cylinder("WebcamLens", 1.25, 0.22, (0, -4.79, 207), glass, (math.pi / 2, 0, 0), 0.04, hinge)]
for x in (-8, 8):
    camera_parts.append(cylinder("Microphone", 0.45, 0.12, (x, -4.7, 207), dark, (math.pi / 2, 0, 0), 0.03, hinge, 12))
join(camera_parts, "Webcam_And_Microphones")

# A fictional disconnected workspace; separate static geometry, not gameplay.
ui_white = material("UI | warm white", (0.77, 0.86, 0.89), 0, 0.7, 0.25)
ui_muted = material("UI | muted blue gray", (0.27, 0.43, 0.5), 0, 0.8, 0.25)
ui_teal = material("UI | teal", (0.035, 0.5, 0.46), 0, 0.8, 0.4)
ui_panel = material("UI | window background", (0.032, 0.064, 0.080), 0, 0.8, 0.25)
ui_amber = material("UI | disconnected amber", (0.85, 0.43, 0.13), 0, 0.8, 0.3)
ui = []


def ui_text(label, x, z, size, mat=ui_white):
    obj = text("UI_" + label, label, (x, -5.1, z), size, mat, "front", "LEFT", hinge)
    ui.append(obj)


def ui_box(name, x, z, width, height, mat, radius=0.2):
    ui.append(box(name, (width, 0.08, height), (x, -4.98, z), mat, radius, hinge))


ui_text("NETCARE", -140, 186, 5.2)
ui_text("WORKSPACE", 94, 186, 3.1, ui_muted)
ui_box("UI_HeaderLine", 0, 175, 279, 0.35, ui_muted)
ui_box("UI_Window", 0, 112, 238, 105, ui_panel, 1)
ui_box("UI_Accent", -119, 112, 1.1, 104, ui_teal)
ui_text("Office network", -102, 145, 9)
ui_text("Not connected", -90, 126, 5, ui_amber)
ui_box("UI_DisconnectedDot", -99, 126, 2.5, 2.5, ui_amber, 0.5)
ui_text("Connect an Ethernet cable", -102, 101, 5.3)
ui_text("to the LAN port to begin.", -102, 91, 5.3)
ui_text("Shared resources become available after setup.", -102, 74, 3.2, ui_muted)
ui_text("DAY 1   /   GETTING STARTED", -140, 40, 3.1, ui_muted)
ui_text("BATTERY  86%", 96, 40, 3.0, ui_muted)
demo_ui = join(ui, "Screen_Demo_UI")
demo_ui["static_preview_only"] = True
demo_ui["hide_for_gameplay"] = "Replace with actual game-controlled screen, not automatic network state."

# LCD pixels are emissive, not highly reflective gray plastic under studio lights.
for mat in (screen_mat, ui_white, ui_muted, ui_teal, ui_panel, ui_amber):
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (0, 0, 0, 1)
    shader.inputs["Specular IOR Level"].default_value = 0
    shader.inputs["Roughness"].default_value = 1
    shader.inputs["Emission Color"].default_value = mat.diffuse_color
    shader.inputs["Emission Strength"].default_value = 1.0

# Offset the lid from its barrel axis, so closing it clears the keycaps.
# At rotation X=90 degrees the LCD front sits above, not inside, the keyboard.
for obj in list(hinge.children):
    obj.location.y += 0.0088
hinge["lid_offset_from_hinge_mm"] = 8.8
bpy.context.view_layer.update()

# Two pivoting metal links bridge the barrel to the offset display frame.
# Their local start is at the barrel axis, so the display never floats free.
hinge_links = [bpy.data.objects["Display_Housing"]]
for x in (-119, 119):
    link = box("HingeDisplayLink", (24, math.hypot(8.8, 7) + 3.5, 3.0),
               (x, 4.4, 3.5), aluminum, 0.7, hinge)
    link.rotation_euler.x = math.atan2(7, 8.8)
    hinge_links.append(link)
join(hinge_links, "Display_Housing")

# Real meshes and clean hierarchy, with only semantic components exported.
for obj in list(asset.objects):
    if obj.type in {"MESH", "CURVE", "FONT"}:
        meshify(obj)
bpy.ops.object.select_all(action="DESELECT")
for obj in asset.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
export_path = BASE / "ใช้ร่วมกัน/exports/office_laptop_14.glb"
bpy.ops.export_scene.gltf(filepath=str(export_path), export_format="GLB", use_selection=True,
    export_extras=True, export_yup=True, export_apply=True, export_animations=False,
    export_cameras=False, export_lights=False, export_materials="EXPORT")
with export_path.open("rb") as handle:
    magic, version, length = struct.unpack("<4sII", handle.read(12))
    json_length, json_kind = struct.unpack("<II", handle.read(8))
    gltf = json.loads(handle.read(json_length))
assert magic == b"glTF" and version == 2 and length == export_path.stat().st_size
names = [node.get("name", "") for node in gltf["nodes"]]
required = ["OfficeLaptop_14", "Chassis_Base", "Keyboard_Keycaps", "Keyboard_Legends", "Touchpad",
            "Display_Hinge", "Display_Housing", "Screen_Panel", "Screen_Demo_UI", "Port_RJ45_LAN",
            "Socket_RJ45_LAN", "LED_LAN_Link", "LED_LAN_Activity", "LED_Power"]
assert all(name in names for name in required), names
assert not gltf.get("images") and not gltf.get("cameras")
triangles = 0
for obj in asset.objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
report = {"asset": "office_laptop_14", "result": "PASS: structural GLB validation",
          "triangles": triangles, "mesh_objects": sum(obj.type == "MESH" for obj in asset.objects),
          "glb_bytes": export_path.stat().st_size, "base_dimensions_mm": [338, 234, 23],
          "display": "14-inch 16:9", "ethernet_ports": 1, "ethernet_contacts": 8,
          "power_preview": "ON / internal battery", "network_preview": "disconnected / link LEDs off",
          "front_axis_gltf": "+Z", "up_axis_gltf": "+Y", "scene_integrated": False,
          "note": "Generic original art, not manufacturer CAD. Screen UI is static placeholder geometry."}
(BASE / "ใช้ร่วมกัน/exports/office_laptop_14.validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("ASSET_VALIDATION", json.dumps(report), flush=True)

# Studio is saved in .blend but excluded from export.
floor_mat = material("Studio | light neutral", (0.38, 0.405, 0.425), 0, 0.75)
floor = box("StudioFloor", (3000, 3000, 3), (0, 0, -1.53), floor_mat, 0, None)
move_to(floor, studio)


def area(name, pos, target, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size = energy, size
    data.shape = "DISK"
    data.color = color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = mm(pos)
    obj.rotation_euler = (Vector(mm(target)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area("KeySoftbox", (-400, -260, 500), (0, 0, 65), 18, 0.42, (0.86, 0.93, 1))
area("FillSoftbox", (360, -230, 310), (0, 0, 80), 11, 0.35, (1, 0.91, 0.8))
area("RearRim", (30, 350, 480), (0, 30, 95), 24, 0.35, (0.83, 0.92, 1))
area("PortFill", (-380, 40, 70), (-160, 70, 13), 2.8, 0.24, (1, 1, 1))
scene.world = bpy.data.worlds.new("LaptopStudioWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.47, 0.53, 0.60, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.3
camera_data = bpy.data.cameras.new("Camera_Laptop")
camera = bpy.data.objects.new("Camera_Laptop", camera_data)
studio.objects.link(camera)
camera_data.type = "ORTHO"
camera_data.clip_start = 0.001
camera_data.clip_end = 20
scene.camera = camera


def camera_pose(pos, target, scale):
    camera.location = mm(pos)
    camera.rotation_euler = (Vector(mm(target)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = scale


camera_pose((-420, -580, 390), (0, 16, 108), 0.59)
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.render.resolution_x, scene.render.resolution_y = 1600, 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders/office_laptop_14_hero.png")
scene.view_settings.view_transform = "AgX"
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
            space.region_3d.view_distance = 0.59
            space.region_3d.view_location = (0, 0.01, 0.1)
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_perspective = "PERSP"
bpy.ops.wm.save_as_mainfile(filepath=str(BASE / "ใช้ร่วมกัน/blend/office_laptop_14.blend"))
print("BLEND_SAVED", flush=True)
for name, pos, target, scale, res in [
    ("hero", (-420, -580, 390), (0, 16, 108), 0.59, (1600, 1200)),
    ("front", (0, -600, 325), (0, 22, 103), 0.46, (1500, 1200)),
    ("ethernet_closeup", (-285, 15, 68), (-164, 70, 14), 0.080, (1400, 900)),
    ("rear", (390, 520, 345), (0, 22, 104), 0.51, (1500, 1100)),
]:
    camera_pose(pos, target, scale)
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders" / f"office_laptop_14_{name}.png")
    print("RENDER_START", name, flush=True)
    bpy.ops.render.render(write_still=True)
    print("RENDER_DONE", name, flush=True)
print("LAPTOP_BUILD_COMPLETE", flush=True)
