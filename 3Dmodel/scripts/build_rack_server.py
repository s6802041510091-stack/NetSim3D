"""NetCare FS-220: original, modular, educational 2U rack server.

All authored dimensions are mm; world units metres. -Y front, +Z up.
Use run_build_server.ps1 to keep temporary/config/cache files on D:.
Not manufacturer CAD, a circuit schematic, or a live server simulation.
"""
from pathlib import Path
import json
import math
import struct

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
for folder in ("ใช้ร่วมกัน/blend", "ใช้ร่วมกัน/exports", "ใช้ร่วมกัน/renders", "temp/server"):
    (BASE / folder).mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/server")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.length_unit = "MILLIMETERS"
asset = bpy.data.collections.new("ASSET | NetCare 2U Rack Server")
studio = bpy.data.collections.new("STUDIO | preview only")
scene.collection.children.link(asset)
scene.collection.children.link(studio)


def mm(values):
    return tuple(float(value) / 1000 for value in values)


def anchor(name, position=(0, 0, 0), parent=None, rotation=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    asset.objects.link(obj)
    obj.parent, obj.location, obj.rotation_euler = parent, mm(position), rotation
    obj.empty_display_type, obj.empty_display_size = "ARROWS", 0.01
    return obj


root = anchor("RackServer_FS220_2U")
root["description"] = "Original single-socket 2U server with removable lid, ECC DIMMs, SSD carriers, NIC and enclosed PSU"
root["power_state"] = "OFF; no mains cable attached; all status LEDs off"
root["rack_units"] = 2
root["chassis_height_mm"] = 87.5
root["role"] = "Hardware can host File Server software; no file service or quest code included"
root["electrical_detail"] = "Illustrative board, sockets and harnesses, not manufacturing CAD or an electrical schematic"


def material(name, rgb, metal=0, rough=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    return mat


steel = material("Case | satin galvanized steel", (0.42, 0.47, 0.51), 0.76, 0.36)
dark = material("Bezel | graphite powder coat", (0.023, 0.031, 0.042), 0.25, 0.48)
black = material("Recess | black polymer", (0.006, 0.009, 0.012), 0, 0.67)
silver = material("Ports | nickel shield", (0.50, 0.55, 0.60), 0.88, 0.27)
gold = material("Contacts | gold plating", (0.72, 0.43, 0.11), 0.85, 0.25)
pcb = material("PCB | forest green soldermask", (0.017, 0.10, 0.052), 0.05, 0.55)
chip = material("IC | matte black", (0.009, 0.016, 0.023), 0, 0.7)
white = material("Markings | warm white", (0.72, 0.80, 0.81), 0, 0.65)
blue = material("Touch points | muted blue", (0.014, 0.16, 0.27), 0.08, 0.48)
green_off = material("LED | green OFF", (0.005, 0.035, 0.011), 0, 0.3)
amber_off = material("LED | amber OFF", (0.055, 0.023, 0.003), 0, 0.3)
copper = material("Heat spreader | copper", (0.46, 0.17, 0.060), 0.8, 0.32)


def move_collection(obj, target):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    target.objects.link(obj)


def finish(obj, name, mat, bevel=0, parent=root):
    obj.name = name
    move_collection(obj, asset)
    obj.parent = parent
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Manufactured edge", "BEVEL")
        mod.width, mod.segments = bevel / 1000, 2
        normal = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def box(name, dims, pos, mat, bevel=0.15, parent=root):
    bpy.ops.mesh.primitive_cube_add(size=1, location=mm(pos))
    obj = bpy.context.object
    obj.dimensions = mm(dims)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel, parent)


def cylinder(name, radius, depth, pos, mat, rotation=(0, 0, 0), bevel=0.1, parent=root, vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius / 1000, depth=depth / 1000, location=mm(pos), rotation=rotation)
    obj = bpy.context.object
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return finish(obj, name, mat, bevel, parent)


def wire(name, points, radius, mat, parent=root):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions, data.bevel_depth, data.bevel_resolution = "3D", radius / 1000, 1
    data.use_fill_caps = True
    spline = data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*mm(co), 1)
    obj = bpy.data.objects.new(name, data)
    asset.objects.link(obj)
    obj.parent = parent
    data.materials.append(mat)
    return obj


def label(name, words, pos, size, mat=white, facing="front", parent=root):
    data = bpy.data.curves.new(name, "FONT")
    data.body, data.size, data.align_x, data.align_y, data.resolution_u = words, size / 1000, "CENTER", "CENTER", 2
    obj = bpy.data.objects.new(name, data)
    asset.objects.link(obj)
    obj.parent, obj.location = parent, mm(pos)
    if facing == "front":
        obj.rotation_euler.x = math.pi / 2
    elif facing == "rear":
        obj.rotation_euler = (math.pi / 2, 0, math.pi)
    data.materials.append(mat)
    return obj


def meshify(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.type != "MESH":
        bpy.ops.object.convert(target="MESH")
        obj = bpy.context.object
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
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


def cut(target, name, dims, pos, bevel=0.1, parent=root):
    cutter = meshify(box(name, dims, pos, None, bevel, parent))
    boolean(target, cutter, name)


def boolean(target, cutter, name):
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = target
    mod = target.modifiers.new(name, "BOOLEAN")
    mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def screw(pos, parent=root, facing="top"):
    rotation = (math.pi / 2, 0, 0) if facing != "top" else (0, 0, 0)
    parts = [cylinder("ScrewHead", 2.3, 0.8, pos, silver, rotation, 0.12, parent)]
    x, y, z = pos
    if facing == "top":
        parts.append(box("ScrewSlot", (2.7, 0.45, 0.06), (x, y, z + 0.43), black, 0, parent))
    else:
        parts.append(box("ScrewSlot", (2.7, 0.06, 0.45), (x, y + (0.43 if facing == "rear" else -0.43), z), black, 0, parent))
    return parts


def ring(name, outer, inner, depth, mat, parent):
    vertices, faces, count = [], [], len(outer)
    for y in (0, depth):
        for polygon in (outer, inner):
            vertices.extend(mm((x, y, z)) for x, z in polygon)
    for i in range(count):
        j = (i + 1) % count
        faces += [(i, j, count + j, count + i), (i, 2 * count + i, 2 * count + j, j),
                  (count + i, count + j, 3 * count + j, 3 * count + i),
                  (2 * count + i, 3 * count + i, 3 * count + j, 2 * count + j)]
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    asset.objects.link(obj)
    obj.parent = parent
    data.materials.append(mat)
    return obj


# Real hollow folded-metal chassis, not a solid cube behind the removable lid.
chassis = [box("Floor", (430, 520, 1.2), (0, 0, 0.6), steel, 0.25)]
for side in (-1, 1):
    chassis.append(box("SideWall", (1.2, 520, 85), (side * 214.4, 0, 43.7), steel, 0.2))
    chassis.append(box("LidRail", (6, 514, 1.2), (side * 211, 0, 85.5), steel, 0.18))
    ear = meshify(box("RackEar", (26.3, 3, 87.5), (side * 228.15, -258.8, 43.75), dark, 0.7))
    for z in (12.7, 75.0):
        cut(ear, "RackMountSlot", (7, 8, 9), (side * 232.5, -258.8, z), 2.6)
    chassis.append(ear)
    chassis.append(wire("RackHandle", [(side * 219.5, -262, 22), (side * 219.5, -278, 25),
                                        (side * 219.5, -278, 62), (side * 219.5, -262, 65)], 2.4, dark))
front_upper = meshify(box("FrontHeader", (430, 4, 40), (0, -259, 66.25), dark, 0.7))
cut(front_upper, "AirIntakeWindow", (209, 10, 25), (15, -259, 66.5), 1.4)
chassis += [front_upper, box("FrontLowerRail", (430, 4, 12), (0, -259, 7.2), dark, 0.7)]
for x in (-209, -104, 0, 104, 209):
    chassis.append(box("DriveBayUpright", (2.0, 4, 33), (x, -259, 29.5), steel, 0.1))
for x in range(-86, 118, 5):
    chassis.append(box("IntakeVerticalWeb", (0.8, 2.5, 24), (x, -259, 66.5), dark, 0.1))
for z in (58, 66.5, 75):
    chassis.append(box("IntakeCrossWeb", (207, 2.5, 0.8), (15, -259, z), dark, 0.1))
rear = meshify(box("RearPanel", (427.6, 1.2, 85), (0, 259.4, 43.7), steel, 0.18))
for name, dims, pos in [
    ("NICCut", (22, 8, 72), (-141, 259.4, 46)),
    ("USBCut", (18, 8, 18), (-40, 259.4, 25)),
    ("VGACut", (34, 8, 17), (6, 259.4, 25)),
    ("PSUCut", (89, 8, 68), (156, 259.4, 40)),
    ("ExhaustCut", (63, 8, 45), (64, 259.4, 53)),
]:
    cut(rear, name, dims, pos, 0.5)
chassis.append(rear)
for x in range(35, 95, 5):
    chassis.append(box("RearVentWeb", (0.8, 1.2, 44), (x, 259.4, 53), steel, 0.08))
for z in range(33, 74, 8):
    chassis.append(box("RearVentCross", (62, 1.2, 0.8), (64, 259.4, z), steel, 0.08))
for x in (-184, -113, -86):
    chassis.append(box("UnusedLowProfileSlot", (18, 1.0, 68), (x, 260.1, 45), dark, 0.4))
    chassis += screw((x, 260.8, 79), facing="rear")
chassis.append(box("DriveBackplane", (413, 1.6, 33), (0, -109, 31), pcb, 0.1))
for x in (-156, -52, 52, 156):
    chassis.append(box("SATAReceptacle", (35, 5, 8), (x, -113, 27), black, 0.4))
    for side in (-1, 1):
        chassis.append(box("CarrierGuide", (2, 148, 16), (x + side * 51.5, -183, 22), steel, 0.2))
join(chassis, "Server_Chassis")

# Removable top lid. Components below it remain in the export.
lid_root = anchor("Lid_Remove", parent=root)
lid_root["removal_note"] = "Disconnect AC first. Slide back (+Y) then lift (+Z) in Blender; no animation included."
lid_sheet = meshify(box("LidSheet", (429.8, 518, 1.2), (0, 0, 86.9), steel, 0.35, lid_root))
cut(lid_sheet, "LatchRecess", (36, 25, 5), (0, 159, 86.9), 1.0, lid_root)
lid_parts = [lid_sheet,
             box("ServiceLatchInset", (37, 26, 0.8), (0, 159, 86.25), black, 0.6, lid_root),
             box("ServiceLatch", (30, 18, 0.5), (0, 159, 86.95), dark, 0.6, lid_root)]
for x in (-196, 196):
    lid_parts += screw((x, 238, 87.6), lid_root)
join(lid_parts, "Top_Lid")

# Front storage: two 2.5-inch SATA SSDs in wide carriers; two ventilated blanks.
drive_roots = []
for index, x in enumerate((-156, -52, 52, 156), 1):
    occupied = index <= 2
    drive = anchor(f"Drive_{index:02}_Carrier" if occupied else f"Bay_{index:02}_Blank", (x, -248, 14), root)
    drive["occupied"] = occupied
    drive["removal_axis_blender"] = "-Y"
    drive["removal_axis_gltf"] = "+Z"
    drive_roots.append(drive)
    face = meshify(box("CarrierFace", (101, 10, 30), (0, -10, 16), dark, 0.8, drive))
    for z in (11, 17, 23):
        cut(face, "CarrierAirSlot", (63, 16, 2.8), (-9, -10, z), 0.9, drive)
    parts = [face, box("CarrierRelease", (12, 1.8, 22), (40, -15.8, 16), blue if occupied else dark, 1.0, drive),
             label("BayNumber", f"{index:02}", (-43, -15.15, 16), 4.1, parent=drive)]
    if occupied:
        parts += [box("CarrierFloor", (100, 145, 1), (0, 65, 1.6), steel, 0.1, drive),
                  box("SSDCase", (69.85, 100, 7), (0, 83, 6.0), dark, 0.6, drive),
                  box("SSDSticker", (55, 69, 0.08), (0, 83, 9.57), white, 0.2, drive),
                  label("SSDType", "SATA SSD", (0, 94, 9.64), 4.5, black, "top", drive),
                  label("SSDCapacity", "480 GB", (0, 76, 9.64), 5.5, black, "top", drive)]
        for side in (-1, 1):
            parts.append(box("CarrierSide", (1.2, 144, 11), (side * 49.4, 65, 7), steel, 0.12, drive))
            parts += screw((side * 40, 57, 3.0), drive)
        # Short adapter PCB to the blind-mate backplane; data/power are illustrative.
        parts += [box("DriveAdapterPCB", (83, 8, 1.5), (0, 134, 9), pcb, 0.1, drive),
                  box("SATACombinedConnector", (35, 6, 8), (0, 137, 13), black, 0.3, drive)]
        for pin in range(22):
            parts.append(box("SATAContact", (0.7, 2, 0.12), (-15.1 + pin * 1.25, 139.8, 16.6), gold, 0, drive))
    join(parts, f"Storage_Carrier_{index:02}" if occupied else f"Storage_Blank_{index:02}")
    if occupied:
        led = box(f"LED_Drive_{index:02}", (1.2, 0.3, 2.3), (29, -15.2, 24), green_off, 0.2, drive)
        led["default_on"] = False
    anchor(f"Slot_Storage_{index:02}", (x, -248, 14), root)["kind"] = "SSD carrier" if occupied else "blank bay"

# Motherboard and CPU are pre-installed background assemblies for the quest.
board_parts = [box("MotherboardPCB", (270, 298, 1.6), (-56, 95, 8.8), pcb, 0.3)]
for x in (-183, 69):
    for y in (-44, 92, 235):
        board_parts.append(cylinder("Standoff", 2.6, 6.4, (x, y, 4.4), silver, bevel=0.1))
        board_parts += screw((x, y, 10.1))
for x, y, w, d in [(-156, 16, 17, 24), (-90, 199, 22, 22), (44, 215, 20, 18), (-182, 149, 12, 14)]:
    board_parts.append(box("BoardIC", (w, d, 2.8), (x, y, 11.2), chip, 0.35))
for x in (-115, -104, -93, -82, -71, -60):
    board_parts.append(cylinder("VRMCapacitor", 3.2, 9, (x, 20, 14.1), silver, bevel=0.15))
    board_parts.append(box("VRMChoke", (7, 7, 7), (x, 7, 13.2), chip, 0.3))
board_parts.append(cylinder("RTC2032", 10, 3.2, (-174, 83, 12), silver, bevel=0.2))
board_parts += [box("ATXPowerSocket", (13, 51, 9), (65, 170, 15), black, 0.5),
                box("PCIeSlot", (8, 104, 9), (-148.2, 196, 14), black, 0.4),
                label("BoardLegend", "NETCARE   SYSTEM BOARD", (-81, 233, 9.67), 4.4, white, "top")]
slot_centers = [(-8, "A1"), (4, "A2"), (16, "B1"), (28, "B2")]
for x, name in slot_centers:
    board_parts.append(box("DIMMSocket", (4.5, 142, 5.5), (x, 88, 12.4), black, 0.25))
    for y in (14, 162):
        board_parts.append(box("DIMMLatch", (6.5, 5, 7), (x, y, 14), blue if name.endswith("1") else black, 0.5))
    anchor(f"Slot_RAM_{name}", (x, 88, 14), root)["kind"] = "ECC DIMM; simplified keyed socket"
    board_parts.append(label("SlotName", name, (x, 173, 9.67), 3.3, white, "top"))
join(board_parts, "Motherboard_Fixed")
cpu = [box("CPUSocket", (65, 65, 4), (-66, 94, 12.3), black, 0.5),
       box("CPURetentionFrame", (57, 57, 1.8), (-66, 94, 15.3), silver, 0.3),
       box("CPUHeatSpreader", (49, 49, 2), (-66, 94, 17.0), silver, 0.4),
       box("CopperHeatsinkBase", (77, 81, 4), (-66, 94, 20.0), copper, 0.4)]
for x in range(-102, -29, 3):
    cpu.append(box("HeatsinkFin", (0.8, 81, 34), (x, 94, 39), steel, 0.1))
for x in (-108, -24):
    for y in (56, 132):
        cpu += screw((x, y, 20.4))
join(cpu, "CPU_Heatsink_Fixed")

# RAM roots sit at the insertion edge; all pieces move with their own DIMM.
ram_roots = []
for x, name in [(-8, "A1"), (16, "B1")]:
    ram = anchor(f"RAM_{name}", (x, 88, 14), root)
    ram["kind"], ram["capacity_gb"] = "ECC DIMM visual approximation", 16
    ram["remove_direction_gltf"] = "+Y"
    ram_roots.append(ram)
    board = meshify(box("DIMMBoard", (1.3, 133.35, 31.25), (0, 0, 16.6), pcb, 0.12, ram))
    cut(board, "DIMMKeyNotch", (5, 3.2, 4), (0, -15, 2), 0.3, ram)
    parts = [board]
    for side in (-1, 1):
        for i in range(64):
            y = -62.7 + i * 1.99
            if abs(y + 15) < 2.1:
                continue
            parts.append(box("ContactPad", (0.10, 1.55, 4.3), (side * 0.73, y, 4.2), gold, 0, ram))
        for i in range(9):
            parts.append(box("MemoryIC", (1.8, 11.5, 12.5), (side * 1.5, -55.5 + i * 13.9, 20.2), chip, 0.22, ram))
    parts.append(box("DIMMSticker", (0.08, 30, 9), (2.45, 0, 20.2), white, 0.1, ram))
    join(parts, f"Memory_Module_{name}")

# Four front-to-back fans. Circular openings are real mesh holes.
fans = []
for index, x in enumerate((-150, -50, 50, 150), 1):
    housing = meshify(box("FanHousing", (80, 34, 80), (x, -48, 43), black, 1.0))
    cutter = meshify(cylinder("FanOpening", 36, 42, (x, -48, 43), None, (math.pi / 2, 0, 0), 0, vertices=40))
    boolean(housing, cutter, "FanBore")
    fans.append(housing)
    fans.append(cylinder("FanHub", 11, 18, (x, -48, 43), black, (math.pi / 2, 0, 0), 0.6))
    for i in range(7):
        angle = i * math.tau / 7
        coords = []
        for radius, offset, y in [(10, 0, -51), (34, 0.05, -54), (34, 0.43, -45), (12, 0.55, -45)]:
            coords.append(mm((x + radius * math.cos(angle + offset), y, 43 + radius * math.sin(angle + offset))))
        data = bpy.data.meshes.new("FanBlade")
        data.from_pydata(coords, [], [(0, 1, 2, 3)])
        obj = bpy.data.objects.new("FanBlade", data)
        asset.objects.link(obj)
        obj.parent = root
        data.materials.append(dark)
        mod = obj.modifiers.new("BladeThickness", "SOLIDIFY")
        mod.thickness = 0.0008
        fans.append(obj)
    for dx in (-34, 34):
        for z in (9, 77):
            fans += screw((x + dx, -65.4, z), facing="front")
join(fans, "Cooling_Fan_Bank_Fixed")

# Rear removable low-profile PCIe NIC; two stacked LAN ports, not WAN ports.
nic = anchor("NIC_PCIe_DualLAN", (-141, 250, 14), root)
nic["role"] = "Dual-port Ethernet NIC, not router or switch"
nic["removal_axis_gltf"] = "+Y"
anchor("Slot_NIC_PCIe", (-141, 250, 14), root)
nic_parts = [box("NICPCB", (1.6, 110, 52), (-7.2, -63, 28), pcb, 0.25, nic),
             box("NICController", (3, 19, 19), (-4.6, -69, 31), chip, 0.3, nic)]
for y in range(-105, -38, 3):
    nic_parts.append(box("PCIeFinger", (0.10, 2.1, 5.3), (-6.35, y, 4), gold, 0, nic))
for z in range(23, 42, 3):
    nic_parts.append(box("NICHeatsinkFin", (10, 25, 0.6), (0.5, -69, z), steel, 0.08, nic))
bracket = meshify(box("NICBracket", (20, 1.2, 70), (0, 10.9, 31), silver, 0.3, nic))
for z in (17, 40):
    cut(bracket, "NICJackCut", (17.4, 8, 14.7), (0, 10.9, z), 0.2, nic)
nic_parts.append(bracket)
nic_parts += screw((0, 11.8, 64), nic, "rear")
join(nic_parts, "NIC_Card_And_Bracket")


def ethernet_port(index, pos, parent):
    frame = anchor(f"LAN_{index}_Mount", pos, parent, (0, 0, math.pi))
    parts = []
    for side in (-1, 1):
        parts += [box("ShieldSide", (0.65, 12, 13.5), (side * 7.75, 5.8, 0), silver, 0.12, frame),
                  box("LinerSide", (0.8, 10, 11.8), (side * 7.05, 5.6, 0), black, 0.1, frame),
                  box("LatchShoulder", (4.3, 10, 1.6), (side * 4.5, 5.6, -5.5), black, 0.1, frame)]
    parts += [box("ShieldTop", (16.1, 12, 0.65), (0, 5.8, 6.6), silver, 0.1, frame),
              box("ShieldBottom", (16.1, 12, 0.65), (0, 5.8, -6.6), silver, 0.1, frame),
              box("JackBack", (14, 0.65, 12), (0, 11.5, 0), black, 0.1, frame),
              box("JackCeiling", (14, 10, 0.7), (0, 5.6, 5.8), black, 0.1, frame),
              box("JackFloor", (14, 10, 0.45), (0, 5.6, -6), black, 0.1, frame)]
    for i in range(8):
        x = (i - 3.5) * 1.02
        parts.append(wire("LANContact", [(x, 10.9, 5.4), (x, 8.9, 4.9), (x, 2.2, 1.1), (x, 0.9, 1)], 0.17, gold, frame))
    port = join(parts, f"Port_RJ45_LAN{index}")
    port["contact_count"] = 8
    for name, x, mat in [("Link", -5.7, green_off), ("Activity", 5.7, amber_off)]:
        led = box(f"LED_LAN{index}_{name}", (1.1, 0.22, 0.85), (x, -0.24, 5.6), mat, 0.1, frame)
        led["default_on"] = False
    socket = anchor(f"Socket_RJ45_LAN{index}", (0, -0.8, 0), frame)
    socket["outward_local_gltf"] = "+Z"


ethernet_port(1, (0, 11.8, 17), nic)
ethernet_port(2, (0, 11.8, 40), nic)
join([label("LAN1Legend", "LAN 1", (0, 12, 27), 2.3, black, "rear", nic),
      label("LAN2Legend", "LAN 2", (0, 12, 50), 2.3, black, "rear", nic)], "NIC_Port_Legends")

# Onboard USB-A stack and VGA console, clearly distinct from network ports.
io_parts = []
for index, z in enumerate((20, 29), 1):
    frame = anchor(f"USB_A_{index}_Mount", (-40, 260.5, z), root, (0, 0, math.pi))
    shape = [(-7, -3.5), (7, -3.5), (7, 3.5), (-7, 3.5)]
    inner = [(x * 0.9, zz * 0.83) for x, zz in shape]
    io_parts += [ring("USBShield", shape, inner, 10, silver, frame),
                 box("USBBack", (13, 0.5, 6), (0, 9.8, 0), black, 0.1, frame),
                 box("USBTongue", (10.5, 7, 1), (0, 5, -1.1), black, 0.1, frame)]
    for x in (-3, -1, 1, 3):
        io_parts.append(box("USBContact", (0.6, 4, 0.1), (x, 4, -0.54), gold, 0, frame))
    anchor(f"Socket_USB_A{index}", (0, -0.5, 0), frame)
# Join in world space because these pieces have different parents.
for obj in io_parts:
    bpy.context.view_layer.update()
    matrix = obj.matrix_world.copy()
    obj.parent = root
    obj.matrix_world = matrix
join(io_parts, "Ports_USB_A")
vga = anchor("VGA_Mount", (6, 260.7, 25), root, (0, 0, math.pi))
outer = [(-14, -6), (14, -6), (16, 6), (-16, 6)]
inner = [(x * 0.88, z * 0.80) for x, z in outer]
vga_parts = [ring("VGAShield", outer, inner, 7, silver, vga),
             box("VGAFemaleInsert", (25, 2, 8), (0, 3, 0), blue, 0.8, vga)]
for row, z in enumerate((-2.4, 0, 2.4)):
    for i in range(5):
        vga_parts.append(cylinder("VGASocket", 0.5, 0.1, (-8.8 + i * 4.2 + (row % 2), 1.94, z), black, (math.pi / 2, 0, 0), 0, vga, 10))
join(vga_parts, "Port_VGA_Console")
anchor("Socket_VGA", (0, -0.4, 0), vga)

# Single enclosed removable PSU; do not expose hazardous mains internals.
psu = anchor("PSU_Module", (156, 260, 8), root)
psu["role"] = "Single AC PSU; not a UPS; no battery and no redundant second supply"
psu["removal_axis_gltf"] = "-Z"
psu["safety"] = "Disconnect mains before service. PSU internals are intentionally not modeled."
anchor("Slot_PSU", (156, 260, 8), root)
shell = meshify(box("PSUShell", (86, 234, 64), (0, -117, 32), steel, 0.6, psu))
cut(shell, "C14Cavity", (34, 30, 26), (-17, 0, 31), 1.3, psu)
cut(shell, "PSUExhaustPocket", (27, 26, 40), (23, 0, 32), 1.0, psu)
psu_parts = [shell, box("PSUExhaustBaffle", (26, 0.5, 39), (23, -10, 32), black, 0.1, psu)]
for x in (12, 17, 22, 27, 32):
    psu_parts.append(box("PSUGrilleVertical", (0.8, 1.0, 38), (x, 0.4, 32), steel, 0.08, psu))
for z in range(15, 50, 6):
    psu_parts.append(box("PSUGrilleCross", (25, 1, 0.8), (23, 0.4, z), steel, 0.08, psu))
psu_parts += [box("PSURelease", (9, 4, 16), (36, 2, 57), blue, 0.5, psu),
              wire("PSUPullHandle", [(-32, 0, 7), (-32, 17, 7), (18, 17, 7), (18, 0, 7)], 1.5, silver, psu),
              box("PSULabel", (67, 91, 0.08), (0, -109, 64.05), white, 0.3, psu),
              label("PSUName", "NETCARE PSU", (0, -93, 64.12), 5.2, black, "top", psu),
              label("PSURating", "400 W", (0, -112, 64.12), 7.5, black, "top", psu),
              label("PSUSafety", "DO NOT OPEN", (0, -133, 64.12), 4, black, "top", psu),
              label("PSUACLegend", "AC IN", (-17, 1.3, 49), 3.5, black, "rear", psu),
              box("PSUBLindMate", (38, 6, 14), (0, -234, 21), black, 0.6, psu)]
join(psu_parts, "Power_Supply_Enclosure")
power_frame = anchor("AC_Inlet_Mount", (-17, 1, 31), psu, (0, 0, math.pi))
shape = [(-15, -11), (15, -11), (15, 5.5), (10, 11), (-10, 11), (-15, 5.5)]
inner = [(x * 0.8, z * 0.76) for x, z in shape]
power_parts = [ring("C14Rim", shape, inner, 12, black, power_frame),
               box("C14Back", (26, 0.7, 17), (0, 11.8, 0), black, 0.4, power_frame)]
for x, z in [(-6.8, -3.7), (6.8, -3.7), (0, 4)]:
    power_parts.append(box("C14Blade", (2, 7.5, 4), (x, 6.5, z), silver, 0.15, power_frame))
join(power_parts, "Port_AC_C14")
anchor("Socket_AC_Power", (0, -0.8, 0), power_frame)

# Simplified harness paths remain with chassis, not with removable modules.
harness = [box("PSUPowerDistribution", (54, 15, 17), (156, 17, 24), black, 0.7),
           wire("MainPowerLoom", [(145, 16, 27), (128, 8, 22), (93, 8, 20), (86, 40, 19), (83, 152, 19), (65, 166, 19)], 3.5, black),
           wire("StoragePowerLoom", [(175, 16, 25), (196, 8, 20), (201, -72, 18), (190, -105, 25), (163, -109, 31)], 2.4, black),
           wire("StorageDataBundle", [(-186, -105, 28), (-198, -86, 22), (-198, -17, 17), (-185, -2, 13), (-152, 12, 13)], 2.4, blue)]
join(harness, "Internal_Harnesses_Fixed")

# Front controls and legends, with all LEDs unpowered by default.
button = cylinder("Button_Power", 4.2, 1.3, (181, -262, 68), dark, (math.pi / 2, 0, 0), 0.5)
led = cylinder("LED_Power", 1.25, 0.25, (164, -261.3, 68), green_off, (math.pi / 2, 0, 0), 0.1)
led["default_on"] = False
health = cylinder("LED_Health", 1.15, 0.25, (154, -261.3, 68), amber_off, (math.pi / 2, 0, 0), 0.1)
health["default_on"] = False
legends = [label("Brand", "NETCARE", (-152, -261.15, 70), 9),
           label("Model", "FS-220  /  2U SERVER", (-152, -261.15, 57), 3.4),
           label("PowerLegend", "POWER", (181, -261.15, 57), 3),
           label("USBLabel", "USB", (-40, 260.05, 40), 3.2, black, "rear"),
           label("VGALabel", "VGA", (6, 260.05, 40), 3.2, black, "rear")]
join(legends, "Case_Legends")


def export():
    for obj in list(asset.objects):
        if obj.type in {"MESH", "CURVE", "FONT"}:
            meshify(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in asset.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = BASE / "ใช้ร่วมกัน/exports/rack_server_2u.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_extras=True, export_yup=True, export_apply=True, export_animations=False,
        export_cameras=False, export_lights=False, export_materials="EXPORT")
    with path.open("rb") as stream:
        magic, version, size = struct.unpack("<4sII", stream.read(12))
        length, kind = struct.unpack("<II", stream.read(8))
        data = json.loads(stream.read(length))
    assert magic == b"glTF" and version == 2 and size == path.stat().st_size
    assert not data.get("cameras") and not data.get("images")
    names = {node.get("name") for node in data["nodes"]}
    required = ["RackServer_FS220_2U", "Lid_Remove", "RAM_A1", "RAM_B1", "Drive_01_Carrier", "Drive_02_Carrier",
                "NIC_PCIe_DualLAN", "PSU_Module", "Socket_RJ45_LAN1", "Socket_RJ45_LAN2", "Socket_AC_Power"]
    assert all(name in names for name in required)
    meshes = [obj for obj in asset.objects if obj.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    report = {"result": "PASS: structural export", "asset": "rack_server_2u", "mesh_objects": len(meshes),
              "triangles": triangles, "glb_bytes": path.stat().st_size, "ethernet_ports": 2,
              "contacts_per_lan_port": 8, "rack_units": 2, "case_height_mm": 87.5,
              "case_width_mm": 430, "rack_ear_span_mm": 482.6, "case_depth_mm": 520,
              "installed_ram_modules": 2, "storage_drives": 2, "empty_bay_blanks": 2,
              "psu_count": 1, "default_power": "OFF", "scene_integrated": False,
              "note": "Original educational design. Internal connectors/pad patterns are illustrative; no manufacturer fit or electrical certification."}
    (BASE / "ใช้ร่วมกัน/exports/rack_server_2u.validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("SERVER_EXPORT", json.dumps(report), flush=True)


export()

# Neutral product studio; never exported into Godot.
floor_mat = material("Studio | neutral gray", (0.32, 0.35, 0.38), rough=0.75)
floor = box("StudioFloor", (4000, 4000, 3), (0, 0, -1.55), floor_mat, 0, None)
move_collection(floor, studio)


def area(name, pos, target, power, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size, data.shape, data.color = power, size, "DISK", color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = mm(pos)
    obj.rotation_euler = (Vector(mm(target)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area("Key", (-450, -510, 810), (0, 0, 30), 28, 0.60, (0.92, 0.96, 1))
area("Fill", (610, -70, 470), (0, 0, 30), 20, 0.50, (1, 0.94, 0.85))
area("Rim", (30, 500, 700), (0, 0, 30), 32, 0.52, (0.85, 0.92, 1))
area("RearPortsFill", (-70, 570, 210), (-75, 250, 38), 3, 0.35, (1, 1, 1))
scene.world = bpy.data.worlds.new("ServerStudioWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.50, 0.55, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
camera_data = bpy.data.cameras.new("Camera_Server")
camera = bpy.data.objects.new("Camera_Server", camera_data)
studio.objects.link(camera)
camera_data.type, camera_data.clip_start, camera_data.clip_end = "ORTHO", 0.001, 20
scene.camera = camera


def pose(pos, target, scale, resolution):
    camera.location = mm(pos)
    camera.rotation_euler = (Vector(mm(target)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.ortho_scale = scale
    scene.render.resolution_x, scene.render.resolution_y = resolution


scene.render.engine = "CYCLES"
scene.cycles.samples, scene.cycles.use_denoising, scene.cycles.max_bounces = 48, True, 6
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"
scene.view_settings.exposure = -0.6
pose((690, -930, 610), (0, -8, 38), 0.91, (1600, 1100))
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for area_ui in screen.areas:
        if area_ui.type == "VIEW_3D":
            space = area_ui.spaces.active
            space.clip_start, space.clip_end = 0.001, 20
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.overlay.show_extras = False
            space.shading.type = "MATERIAL"
            space.region_3d.view_distance = 0.9
            space.region_3d.view_location = (0, 0, 0.04)
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders/rack_server_2u_hero.png")
bpy.ops.wm.save_as_mainfile(filepath=str(BASE / "ใช้ร่วมกัน/blend/rack_server_2u.blend"))

for name, pos, target, scale, resolution in [
    ("hero", (690, -930, 610), (0, -8, 38), 0.91, (1600, 1100)),
    ("rear", (-600, 900, 510), (0, 8, 40), 0.88, (1600, 1100)),
    ("interior", (540, -730, 1030), (0, 0, 20), 0.89, (1600, 1300)),
    ("ports_closeup", (-175, 630, 135), (-130, 255, 45), 0.17, (1400, 1100)),
]:
    lid = bpy.data.objects["Top_Lid"]
    lid.hide_render = name == "interior"
    pose(pos, target, scale, resolution)
    scene.render.filepath = str(BASE / "ใช้ร่วมกัน/renders" / f"rack_server_2u_{name}.png")
    print("RENDER_START", name, flush=True)
    bpy.ops.render.render(write_still=True)
    print("RENDER_DONE", name, flush=True)
print("SERVER_BUILD_COMPLETE", flush=True)
