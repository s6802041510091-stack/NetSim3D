"""Original NetCare LP-210N educational Ethernet laser printer.

Use the PowerShell runner to redirect all task cache/config/output to D:.
Dimensions use millimetre helpers, metre world units, +Z up, -Y front.
"""
from pathlib import Path
import json
import math
import struct
import sys

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
for folder in ("ใช้ร่วมกัน/blend", "ใช้ร่วมกัน/exports", "ใช้ร่วมกัน/renders", "temp/printer"):
    (BASE / folder).mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/printer")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "MILLIMETERS"
asset = bpy.data.collections.new("ASSET | NetCare Network Printer")
paper_collection = bpy.data.collections.new("OPTIONAL | A4 printed sheet")
studio = bpy.data.collections.new("STUDIO | preview only")
for collection in (asset, paper_collection, studio):
    scene.collection.children.link(collection)
root = bpy.data.objects.new("NetworkPrinter_LP210N", None)
asset.objects.link(root)
root["description"] = "Original desktop monochrome laser network printer; integrated Ethernet NIC; no scanner."
root["preview_state"] = "Power on for product preview; mains cable omitted; LAN disconnected."
root["power_source"] = "AC mains, NOT battery power or PoE"


def mm(values):
    return tuple(value / 1000 for value in values)


def relocate(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def material(name, color, metal=0, rough=0.5, emit=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = rough
    if emit:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emit
    return mat


ivory = material("Housing | warm white ABS", (0.69, 0.72, 0.72), rough=0.38)
lower_gray = material("Base | stone gray ABS", (0.27, 0.30, 0.32), rough=0.45)
graphite = material("Tray | matte graphite", (0.019, 0.027, 0.034), rough=0.63)
black = material("Recess | black polymer", (0.005, 0.008, 0.011), rough=0.68)
rubber = material("Rollers and feet | rubber", (0.012, 0.017, 0.019), rough=0.8)
silver = material("Connector | nickel shield", (0.48, 0.54, 0.60), 0.9, 0.25)
gold = material("Connector | gold contacts", (0.71, 0.42, 0.11), 0.85, 0.25)
ink = material("Labels | charcoal", (0.025, 0.045, 0.055), rough=0.65)
white_ink = material("Labels | white", (0.70, 0.80, 0.83), rough=0.6)
teal = material("Paper guides | teal", (0.018, 0.29, 0.32), rough=0.4)
paper_mat = material("A4 | white paper", (0.85, 0.84, 0.80), rough=0.92)
link_off = material("Ethernet Link | OFF", (0.009, 0.04, 0.018), rough=0.45)
activity_off = material("Ethernet Activity | OFF", (0.06, 0.030, 0.007), rough=0.45)
ready_mat = material("Ready LED | ON", (0.08, 0.65, 0.28), rough=0.3, emit=1.5)


def finish(obj, name, mat, bevel=0, parent=root):
    obj.name = name
    relocate(obj, asset)
    obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Molded edge radius", "BEVEL")
        modifier.width = bevel / 1000
        modifier.segments = 3
        modifier = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        modifier.keep_sharp = True
    return obj


def box(name, dimensions, position, mat, bevel=0.2, parent=root):
    bpy.ops.mesh.primitive_cube_add(size=1, location=mm(position))
    obj = bpy.context.object
    obj.dimensions = mm(dimensions)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel, parent)


def cylinder(name, radius, depth, position, mat, rotation=(0, 0, 0), bevel=0.1, parent=root):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius / 1000, depth=depth / 1000,
                                      location=mm(position), rotation=rotation)
    obj = bpy.context.object
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return finish(obj, name, mat, bevel, parent)


def wire(name, points, radius, mat, parent=root):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius / 1000
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, coordinate in zip(spline.points, points):
        point.co = (*mm(coordinate), 1)
    obj = bpy.data.objects.new(name, curve)
    asset.objects.link(obj)
    obj.parent = parent
    curve.materials.append(mat)
    return obj


def label(name, value, position, size, mat=ink, facing="front", align="CENTER", parent=root):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body, curve.size = value, size / 1000
    curve.align_x, curve.align_y = align, "CENTER"
    curve.resolution_u = 3
    obj = bpy.data.objects.new(name, curve)
    asset.objects.link(obj)
    obj.parent = parent
    obj.location = mm(position)
    if facing == "front":
        obj.rotation_euler.x = math.pi / 2
    elif facing == "rear":
        obj.rotation_euler = (math.pi / 2, 0, math.pi)
    elif facing == "bottom":
        obj.rotation_euler.x = math.pi
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
    parts = [meshify(part) for part in parts]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    return bpy.context.object


def cut(target, name, dimensions, position, bevel=1):
    cutter = meshify(box(name, dimensions, position, None, bevel))
    bpy.context.view_layer.objects.active = target
    modifier = target.modifiers.new(name, "BOOLEAN")
    modifier.operation, modifier.solver, modifier.object = "DIFFERENCE", "EXACT", cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def anchor(name, position, parent=root, rotation=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    asset.objects.link(obj)
    obj.parent = parent
    obj.location, obj.rotation_euler = mm(position), rotation
    obj.empty_display_type, obj.empty_display_size = "ARROWS", 0.009
    return obj


def ring(name, outer, inner, depth, mat, parent):
    vertices = []
    for y in (0, depth):
        for polygon in (outer, inner):
            vertices.extend((x / 1000, y / 1000, z / 1000) for x, z in polygon)
    count, faces = len(outer), []
    for i in range(count):
        j = (i + 1) % count
        faces += [(i, j, count + j, count + i), (i, 2 * count + i, 2 * count + j, j),
                  (count + i, count + j, 3 * count + j, 3 * count + i),
                  (2 * count + i, 3 * count + i, 3 * count + j, 2 * count + j)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    asset.objects.link(obj)
    obj.parent = parent
    mesh.materials.append(mat)
    return obj


# Molded shell with true output, cassette, ventilation and connector openings.
base_parts = []
lower = meshify(box("LowerShell", (350, 338, 104), (0, 0, 60), lower_gray, 6))
cut(lower, "CassetteOpening", (334, 340, 65), (0, -15, 50), 2)
cut(lower, "ACOpening", (35, 24, 28), (-110, 170, 51), 2)
base_parts.append(lower)
upper = meshify(box("UpperShell", (360, 348, 140), (0, 0, 180), ivory, 8))
cut(upper, "OutputTrayOpening", (260, 310, 46), (0, -35, 246), 4)
cut(upper, "PaperExitOpening", (232, 27, 9), (0, 126, 231), 1)
cut(upper, "RearIOPocket", (88, 24, 79), (104, 173, 158), 3)
cut(upper, "EthernetJackDepthClearance", (18, 20, 16), (87, 155, 156), 0.4)
cut(upper, "USBJackDepthClearance", (15, 18, 15), (120, 155, 156), 0.5)
for side in (-1, 1):
    cut(upper, "SideVentOpening", (18, 106, 36), (side * 177, 28, 151), 2)
    base_parts.append(box("VentDarkBaffle", (1, 104, 34), (side * 166, 28, 151), black, 0.2))
    for z in range(136, 168, 6):
        base_parts.append(box("VentLouver", (4, 102, 3), (side * 177, 28, z), ivory, 0.9))
base_parts.append(upper)
base_parts.append(box("Underbody", (330, 320, 4), (0, 0, 7), graphite, 2))
for x in (-148, 148):
    for y in (-142, 142):
        base_parts.append(cylinder("RubberFoot", 11, 5, (x, y, 2.5), rubber, bevel=1))
base_parts.append(box("TonerDoorSeam", (332, 1, 114), (0, -174.2, 157), graphite, 3))
base_parts.append(box("TonerAccessCover", (329, 2.0, 111), (0, -175.0, 157), ivory, 2.6))
base_parts.append(box("TonerCoverGrip", (73, 1.0, 4.2), (0, -176.2, 203), graphite, 1.8))
base_parts.append(box("RearServiceDoorSeam", (150, 0.7, 110), (-55, 174.2, 180), graphite, 3))
base_parts.append(box("RearServiceDoor", (147, 1.2, 107), (-55, 174.8, 180), ivory, 2.5))
base_parts.append(box("RearServiceGrip", (42, 1.2, 5), (-55, 175.5, 221), graphite, 1.8))
for x in (-120, 10):
    for z in (136, 225):
        base_parts.append(cylinder("RearScrew", 1.8, 0.4, (x, 175.55, z), silver, (math.pi / 2, 0, 0), 0.07))
join(base_parts, "Printer_Chassis")

# A shallow, open output basin is visibly separate from the enclosed feed cassette.
output = [box("OutputBasin", (254, 287, 1.4), (0, -30.5, 223.7), graphite, 0.6),
          box("ExitDarkBack", (230, 0.8, 8), (0, 137.5, 231), black, 0.2)]
for x in range(-104, 105, 26):
    output.append(box("OutputGuideRib", (1.1, 214, 0.45), (x, -48, 224.6), lower_gray, 0.2))
for x in (-83, 0, 83):
    output.append(cylinder("ExitRoller", 3.2, 25, (x, 128, 231.5), rubber, (0, math.pi / 2, 0), 0.25))
join(output, "Output_Tray_And_Rollers")
output_anchor = anchor("Paper_Output", (0, 122, 230))
output_anchor["feed_direction_blender"] = "-Y"
output_anchor["feed_direction_gltf"] = "+Z"
output_anchor["note"] = "Attachment reference only; implement feed motion/visibility in game."

# A real removable tray, including guides and an illustrative stack of A4 paper.
cassette_root = anchor("Input_Cassette_Slide", (0, 0, 0))
cassette_root["slide_axis_blender"] = "-Y"
cassette_root["slide_axis_gltf"] = "+Z"
cassette_root["suggested_open_offset_m"] = 0.22
front = meshify(box("CassetteFront", (329, 8, 59), (0, -172.2, 49), ivory, 3, cassette_root))
cut(front, "CassetteHandleCut", (101, 18, 20), (0, -178, 62), 4)
cassette = [front,
    box("CassetteFloor", (322, 311, 3), (0, -12, 21), graphite, 1.2, cassette_root),
    box("CassetteHandleGrip", (95, 5, 4), (0, -174.9, 52.6), ivory, 1.5, cassette_root),
    box("CassetteBack", (322, 3, 29), (0, 143, 36), graphite, 0.5, cassette_root)]
for side in (-1, 1):
    cassette.append(box("CassetteWall", (3, 308, 29), (side * 160, -12, 36), graphite, 0.5, cassette_root))
    cassette.append(box("PaperGuide", (4, 224, 15), (side * 108, -12, 31), teal, 0.9, cassette_root))
cassette.append(box("A4InputStack", (210, 297, 8), (0, -8, 28), paper_mat, 0.2, cassette_root))
cassette.append(label("CassetteA4", "A4", (140, -176.25, 37), 5, ink, parent=cassette_root))
join(cassette, "Input_Paper_Cassette")

# Rear I/O bay: Ethernet and USB-B are different openings and device roles.
io_plate = meshify(box("IOInsetPlate", (81, 2, 72), (104, 162, 158), graphite, 2))
cut(io_plate, "RJ45PanelCut", (17, 10, 14.5), (87, 162, 156), 0.3)
cut(io_plate, "USBPanelCut", (13.5, 10, 13.3), (120, 162, 156), 0.6)
lan_frame = anchor("Ethernet_NIC_Port", (87, 163.5, 156), rotation=(0, 0, math.pi))
lan_frame["role"] = "RJ45 connection to internal Ethernet NIC"
lan = []
for sign in (-1, 1):
    lan += [box("RJ45ShieldSide", (0.65, 12, 13.5), (sign * 7.75, 5.8, 0), silver, 0.13, lan_frame),
            box("RJ45LinerSide", (0.8, 10, 11.8), (sign * 7.05, 5.6, 0), black, 0.1, lan_frame),
            box("RJ45LatchShoulder", (4.3, 10, 1.6), (sign * 4.5, 5.6, -5.5), black, 0.1, lan_frame)]
lan += [box("RJ45ShieldTop", (16.1, 12, 0.65), (0, 5.8, 6.6), silver, 0.13, lan_frame),
        box("RJ45ShieldBottom", (16.1, 12, 0.65), (0, 5.8, -6.6), silver, 0.13, lan_frame),
        box("RJ45Back", (14, 0.65, 12), (0, 11.5, 0), black, 0.1, lan_frame),
        box("RJ45Ceiling", (14, 10, 0.7), (0, 5.6, 5.8), black, 0.1, lan_frame),
        box("RJ45Floor", (14, 10, 0.45), (0, 5.6, -6), black, 0.1, lan_frame)]
for i in range(8):
    x = (i - 3.5) * 1.02
    lan.append(wire(f"EthernetContact_{i + 1}", [(x, 10.9, 5.4), (x, 8.9, 4.9), (x, 2.2, 1.1), (x, 0.9, 1)], 0.17, gold, lan_frame))
lan_port = join(lan, "Port_RJ45_LAN")
lan_port["contact_count"] = 8
for name, x, mat in [("LED_LAN_Link", -5.7, link_off), ("LED_LAN_Activity", 5.7, activity_off)]:
    obj = box(name, (1.1, 0.22, 0.85), (x, -0.24, 5.6), mat, 0.13, lan_frame)
    obj["default_on"] = False
anchor("Socket_RJ45_LAN", (0, -0.8, 0), lan_frame)["role"] = "Ethernet cable attachment"
usb_frame = anchor("USB_B_Mount", (120, 163.5, 156), rotation=(0, 0, math.pi))
usb_shape = [(-6, -5.8), (6, -5.8), (6, 2.8), (3.6, 5.8), (-3.6, 5.8), (-6, 2.8)]
usb_inner = [(x * 0.88, z * 0.87) for x, z in usb_shape]
usb = [ring("USB_B_Shield", usb_shape, usb_inner, 9.5, silver, usb_frame),
       box("USB_B_Back", (10.5, 0.5, 10), (0, 9.4, 0), black, 0.2, usb_frame),
       box("USB_B_Insulator", (6.4, 7, 4.2), (0, 6.0, 0), black, 0.3, usb_frame)]
for x in (-1.7, 1.7):
    for sign in (-1, 1):
        usb.append(box("USB_B_Contact", (0.8, 4, 0.1), (x, 5.4, sign * 2.16), gold, 0.02, usb_frame))
usb_port = join(usb, "Port_USB_B")
usb_port["role"] = "USB Type-B device port, not Ethernet"
anchor("Socket_USB_B", (0, -0.8, 0), usb_frame)

# Recessed IEC C14 mains inlet with three male blades, not an Ethernet jack.
power_frame = anchor("AC_Inlet_Mount", (-110, 170, 51), rotation=(0, 0, math.pi))
power_shape = [(-15, -11), (15, -11), (15, 5.5), (10, 11), (-10, 11), (-15, 5.5)]
power_inner = [(x * 0.80, z * 0.76) for x, z in power_shape]
power_parts = [ring("IEC_C14_Rim", power_shape, power_inner, 12, black, power_frame),
               box("IEC_C14_Back", (26, 0.7, 17), (0, 11.8, 0), black, 0.6, power_frame)]
for x, z in [(-6.8, -3.7), (6.8, -3.7), (0, 4.0)]:
    power_parts.append(box("IEC_C14_Blade", (2, 7.5, 4), (x, 6.5, z), silver, 0.2, power_frame))
join(power_parts, "Port_AC_C14")
anchor("Socket_AC_Power", (0, -0.8, 0), power_frame)

# Minimal top-right control strip. LAN state is explicitly disconnected.
control_parts = [box("ControlPanelBezel", (42, 87, 1.4), (153, -100, 250.5), graphite, 2),
                 box("LCDFrame", (33, 35, 0.5), (153, -79, 251.4), black, 1.2)]
join(control_parts, "Control_Panel")
lcd_mat = material("LCD | navy backlight", (0.012, 0.040, 0.05), rough=1, emit=1)
lcd_shader = lcd_mat.node_tree.nodes.get("Principled BSDF")
lcd_shader.inputs["Base Color"].default_value = (0, 0, 0, 1)
lcd_shader.inputs["Specular IOR Level"].default_value = 0
lcd = box("Status_LCD", (29, 30, 0.16), (153, -79, 251.76), lcd_mat, 0.4)
lcd["static_preview_only"] = True
lcd_ink = material("LCD | pale teal text", (0.35, 0.8, 0.73), rough=1, emit=0.8)
lcd_labels = [label("ReadyText", "READY", (153, -72, 251.9), 4.3, lcd_ink, "top"),
              label("LANOffText", "LAN OFF", (153, -81, 251.9), 3.0, lcd_ink, "top"),
              label("PaperText", "A4", (153, -88, 251.9), 2.8, lcd_ink, "top")]
join(lcd_labels, "Status_LCD_Text")
cylinder("Button_Power", 5, 1.1, (153, -111, 251.7), lower_gray, bevel=0.5)
cylinder("Button_Go", 5.5, 1.1, (153, -131, 251.7), teal, bevel=0.5)
ready = cylinder("LED_Ready", 1.1, 0.35, (165, -111, 251.6), ready_mat, bevel=0.08)
ready["default_on"] = True
legends = [label("Brand", "NETCARE", (-137, -176.13, 176), 10, align="LEFT"),
           label("Model", "LP-210N", (124, -176.13, 176), 5.5),
           label("Type", "NETWORK LASER PRINTER", (-137, -176.13, 162), 3.5, align="LEFT"),
           label("LANLabel", "LAN", (87, 163.12, 174), 3.9, white_ink, "rear"),
           label("USBLabel", "USB-B", (120, 163.12, 174), 3.5, white_ink, "rear"),
           label("ACLabel", "AC IN", (-110, 169.15, 74), 4.8, white_ink, "rear"),
           label("PowerLabel", "POWER", (153, -121, 251.3), 2.3, white_ink, "top"),
           label("GoLabel", "GO", (153, -141, 251.3), 2.6, white_ink, "top")]
join(legends, "Printed_Legends")

# Separate A4 sheet: never baked into the main printer GLB.
# The face-down output example has print on its underside, not its upper face.
paper_root = anchor("PrintedSheet_A4", (0, 0, 0), parent=None)
relocate(paper_root, paper_collection)
paper_root["size_mm"] = [210, 297]
paper_root["note"] = "Optional static sample. Visibility and paper-feed animation must be implemented in game."
vertices, faces = [], []
segments = 16
for step in range(segments + 1):
    t = step / segments
    vertices += [(-0.105, -0.297 * t, -0.005 * t), (0.105, -0.297 * t, -0.005 * t)]
for step in range(segments):
    faces.append((2 * step, 2 * step + 2, 2 * step + 3, 2 * step + 1))
paper_mesh = bpy.data.meshes.new("A4_SheetMesh")
paper_mesh.from_pydata(vertices, [], faces)
paper_mesh.update()
paper_obj = bpy.data.objects.new("Paper_Sheet", paper_mesh)
paper_collection.objects.link(paper_obj)
paper_obj.parent = paper_root
paper_mesh.materials.append(paper_mat)
modifier = paper_obj.modifiers.new("Paper thickness", "SOLIDIFY")
modifier.thickness, modifier.offset = 0.00012, 0
meshify(paper_obj)
slope = 5 / 297
paper_marks = []
for words, y, size in [("NETCARE", -46, 10), ("NETWORK PRINTER TEST PAGE", -68, 5),
                        ("Educational preview sample", -88, 3.5), ("LP-210N", -238, 4)]:
    obj = label("SamplePrint", words, (0, y, y * slope - 0.085), size, ink, "bottom", parent=paper_root)
    obj.rotation_euler.x += math.atan(slope)
    paper_marks.append(obj)
for i in range(7):
    y = -113 - i * 12
    obj = box("SamplePrintRule", (142 - (i % 3) * 19, 0.7, 0.016), (0, y, y * slope - 0.077), ink, 0, paper_root)
    obj.rotation_euler.x = math.atan(slope)
    paper_marks.append(obj)
paper_print = join(paper_marks, "Paper_Print_Underside")
relocate(paper_print, paper_collection)


def export_glb(collection, path, active_root):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(collection.objects):
        if obj.type in {"MESH", "CURVE", "FONT"}:
            meshify(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active_root
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_extras=True, export_yup=True, export_apply=True, export_animations=False,
        export_cameras=False, export_lights=False, export_materials="EXPORT")
    with path.open("rb") as stream:
        magic, version, length = struct.unpack("<4sII", stream.read(12))
        json_length, chunk_kind = struct.unpack("<II", stream.read(8))
        gltf = json.loads(stream.read(json_length))
    assert magic == b"glTF" and version == 2 and length == path.stat().st_size
    assert not gltf.get("images") and not gltf.get("cameras")
    return gltf


printer_path = BASE / "ใช้ร่วมกัน/exports/office_network_printer.glb"
gltf = export_glb(asset, printer_path, root)
names = [node.get("name", "") for node in gltf["nodes"]]
required = ["NetworkPrinter_LP210N", "Printer_Chassis", "Input_Cassette_Slide", "Input_Paper_Cassette",
            "Port_RJ45_LAN", "Socket_RJ45_LAN", "LED_LAN_Link", "LED_LAN_Activity", "Port_USB_B",
            "Port_AC_C14", "Socket_AC_Power", "Status_LCD", "LED_Ready", "Paper_Output"]
assert all(name in names for name in required), names
assert "Paper_Sheet" not in names
export_glb(paper_collection, BASE / "ใช้ร่วมกัน/exports/printer_printed_sheet_a4.glb", paper_root)
paper_root.location = mm((0, 122, 230))
paper_collection.hide_render = True
paper_collection.hide_viewport = True
triangle_count = 0
for obj in asset.objects:
    if obj.type == "MESH":
        obj.data.calc_loop_triangles()
        triangle_count += len(obj.data.loop_triangles)
report = {"asset": "office_network_printer", "result": "PASS: structural GLB validation",
          "mesh_objects": sum(obj.type == "MESH" for obj in asset.objects), "triangles": triangle_count,
          "glb_bytes": printer_path.stat().st_size, "ethernet_ports": 1, "ethernet_contacts": 8,
          "main_case_dimensions_mm_approx": [360, 352, 253], "power_connector": "IEC C14 AC mains inlet",
          "usb_connector": "USB Type-B device port", "lan_default": "disconnected / LEDs off",
          "optional_paper_export": "printer_printed_sheet_a4.glb", "scene_integrated": False,
          "note": "Original generic design, not manufacturer CAD; no live printing logic or automatic network state."}
(BASE / "ใช้ร่วมกัน/exports/office_network_printer.validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("ASSET_VALIDATION", json.dumps(report), flush=True)

# Studio excluded from exported assets.
floor_mat = material("Studio | soft neutral", (0.36, 0.385, 0.40), rough=0.75)
floor = box("StudioFloor", (3000, 3000, 3), (0, 0, -1.53), floor_mat, 0, None)
relocate(floor, studio)


def area(name, position, target, watts, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.shape, data.color = watts, size, "DISK", color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = mm(position)
    obj.rotation_euler = (Vector(mm(target)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area("KeySoftbox", (-380, -440, 600), (0, 0, 140), 18, 0.45, (0.90, 0.96, 1))
area("FillSoftbox", (430, -180, 430), (0, 0, 140), 12, 0.40, (1, 0.94, 0.86))
area("RearRim", (70, 440, 540), (0, 40, 140), 20, 0.38, (0.85, 0.93, 1))
area("RearPortFill", (150, 410, 220), (80, 165, 145), 2.5, 0.24, (1, 1, 1))
scene.world = bpy.data.worlds.new("PrinterStudioWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.50, 0.56, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
camera_data = bpy.data.cameras.new("Camera_Printer")
camera = bpy.data.objects.new("Camera_Printer", camera_data)
studio.objects.link(camera)
camera_data.type, camera_data.clip_start, camera_data.clip_end = "ORTHO", 0.001, 20
scene.camera = camera


def camera_pose(position, target, scale):
    camera.location = mm(position)
    camera.rotation_euler = (Vector(mm(target)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = scale


camera_pose((470, -650, 455), (0, -6, 131), 0.68)
scene.render.engine = "CYCLES"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.render.resolution_x, scene.render.resolution_y = 1600, 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders/office_network_printer_hero.png")
scene.view_settings.view_transform = "AgX"
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for region in screen.areas:
        if region.type == "VIEW_3D":
            space = region.spaces.active
            space.clip_start, space.clip_end = 0.001, 20
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.shading.type = "MATERIAL"
            space.region_3d.view_distance = 0.75
            space.region_3d.view_location = (0, 0, 0.13)
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_perspective = "PERSP"
bpy.ops.wm.save_as_mainfile(filepath=str(BASE / "ใช้ร่วมกัน/blend/office_network_printer.blend"))
print("BLEND_SAVED", flush=True)
for name, position, target, scale, resolution, show_paper in [
    ("hero", (470, -650, 455), (0, -6, 131), 0.68, (1600, 1200), False),
    ("rear", (420, 650, 370), (0, 10, 130), 0.65, (1500, 1100), False),
    ("ports_closeup", (145, 465, 211), (103, 165, 157), 0.112, (1400, 1050), False),
    ("paper_preview", (410, -600, 570), (0, -8, 141), 0.67, (1500, 1200), True),
]:
    if "--ports-only" in sys.argv and name not in {"rear", "ports_closeup"}:
        continue
    camera_pose(position, target, scale)
    paper_collection.hide_render = not show_paper
    paper_collection.hide_viewport = not show_paper
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders" / f"office_network_printer_{name}.png")
    print("RENDER_START", name, flush=True)
    bpy.ops.render.render(write_still=True)
    print("RENDER_DONE", name, flush=True)
print("PRINTER_BUILD_COMPLETE", flush=True)
