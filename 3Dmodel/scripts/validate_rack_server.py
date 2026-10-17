"""Validate the actual reimported server GLB, its ports and modular hierarchy."""
from pathlib import Path
import json
import math
import struct

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/server")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
path = BASE / "ใช้ร่วมกัน/exports/rack_server_2u.glb"
with path.open("rb") as stream:
    magic, version, size = struct.unpack("<4sII", stream.read(12))
    length, kind = struct.unpack("<II", stream.read(8))
    gltf = json.loads(stream.read(length))
assert magic == b"glTF" and version == 2 and size == path.stat().st_size
assert not gltf.get("images") and not gltf.get("cameras") and not gltf.get("animations")
assert not any("uri" in buffer for buffer in gltf.get("buffers", []))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(path))
bpy.context.view_layer.update()
objects = bpy.context.scene.objects
required = ["RackServer_FS220_2U", "Server_Chassis", "Top_Lid", "Lid_Remove", "Motherboard_Fixed", "CPU_Heatsink_Fixed",
            "Cooling_Fan_Bank_Fixed", "Internal_Harnesses_Fixed", "RAM_A1", "RAM_B1", "Memory_Module_A1", "Memory_Module_B1",
            "Drive_01_Carrier", "Drive_02_Carrier", "Storage_Carrier_01", "Storage_Carrier_02",
            "Bay_03_Blank", "Bay_04_Blank", "NIC_PCIe_DualLAN", "NIC_Card_And_Bracket", "NIC_Port_Legends",
            "PSU_Module", "Power_Supply_Enclosure", "Port_AC_C14", "Socket_AC_Power",
            "Port_RJ45_LAN1", "Port_RJ45_LAN2", "Socket_RJ45_LAN1", "Socket_RJ45_LAN2",
            "Ports_USB_A", "Port_VGA_Console", "Button_Power", "LED_Power", "LED_Health"]
assert all(name in objects for name in required), [name for name in required if name not in objects]
assert not any(obj.type in {"LIGHT", "CAMERA", "CURVE", "FONT"} for obj in objects)
assert not any(obj.name.startswith("Studio") for obj in objects)
meshes = [obj for obj in objects if obj.type == "MESH"]
assert len(meshes) == 30, len(meshes)
triangles = 0
for obj in meshes:
    assert len(obj.data.polygons) > 0
    assert all(math.isfinite(value) for vertex in obj.data.vertices for value in vertex.co)
    assert all(abs(value - 1) < 1e-5 for value in obj.scale), (obj.name, list(obj.scale))
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
dimensions = [max(point[i] for point in corners) - min(point[i] for point in corners) for i in range(3)]
assert abs(dimensions[0] - 0.4826) < 0.0002, dimensions
assert 0.548 < dimensions[1] < 0.57, dimensions
assert 0.0874 < dimensions[2] < 0.0889, dimensions
root = objects["RackServer_FS220_2U"]
assert root.get("rack_units") == 2
assert root.get("power_state").startswith("OFF")
leds = [obj for obj in meshes if obj.name.startswith("LED_")]
assert len(leds) == 8, [obj.name for obj in leds]
assert all(obj.get("default_on") is False for obj in leds)
assert all(objects[f"Port_RJ45_LAN{i}"].get("contact_count") == 8 for i in (1, 2))

# Shoot through the actual opening, not at a label or decorative port rectangle.
port_tests = [
    ("Port_RJ45_LAN1", (-0.141, 0.34, 0.031)),
    ("Port_RJ45_LAN2", (-0.141, 0.34, 0.054)),
    ("Port_AC_C14", (0.139, 0.34, 0.039)),
    ("Ports_USB_A", (-0.040, 0.34, 0.020)),
    ("Port_VGA_Console", (0.006, 0.34, 0.025)),
]
for expected, origin in port_tests:
    hit, position, normal, face, obj, matrix = bpy.context.scene.ray_cast(
        bpy.context.evaluated_depsgraph_get(), Vector(origin), Vector((0, -1, 0)), distance=0.12)
    assert hit and obj.name == expected, (expected, obj.name if hit else "no hit", list(position))
for name in ("Socket_RJ45_LAN1", "Socket_RJ45_LAN2", "Socket_AC_Power", "Socket_USB_A1", "Socket_USB_A2", "Socket_VGA"):
    obj = objects[name]
    assert obj.type == "EMPTY"
    outward = (obj.matrix_world.to_3x3() @ Vector((0, -1, 0))).normalized()
    assert outward.y > 0.999, (name, list(outward))

# Confirm the chassis itself is open internally, not filled by a solid base box.
chassis = objects["Server_Chassis"]
origin = Vector((-0.070, 0.19, 0.070))
inv = chassis.matrix_world.inverted()
hit, position, normal, face = chassis.ray_cast(inv @ origin, inv.to_3x3() @ Vector((0, 0, -1)), distance=0.1)
assert hit
assert (chassis.matrix_world @ position).z < 0.002


def check_removal(parent_name, child_names, delta):
    parent = objects[parent_name]
    assert parent.type == "EMPTY"
    starts = {name: objects[name].matrix_world.translation.copy() for name in child_names}
    board_start = objects["Motherboard_Fixed"].matrix_world.copy()
    original = parent.location.copy()
    parent.location += Vector(delta)
    bpy.context.view_layer.update()
    for name, start in starts.items():
        assert ((objects[name].matrix_world.translation - start) - Vector(delta)).length < 1e-6, (parent_name, name)
    assert (objects["Motherboard_Fixed"].matrix_world.translation - board_start.translation).length < 1e-8
    parent.location = original
    bpy.context.view_layer.update()


check_removal("Lid_Remove", ["Top_Lid"], (0, 0.02, 0.08))
for suffix in ("A1", "B1"):
    check_removal("RAM_" + suffix, ["Memory_Module_" + suffix], (0, 0, 0.08))
    assert (objects["RAM_" + suffix].location - objects["Slot_RAM_" + suffix].location).length < 1e-6
for suffix in ("01", "02"):
    check_removal("Drive_" + suffix + "_Carrier", ["Storage_Carrier_" + suffix, "LED_Drive_" + suffix], (0, -0.16, 0))
check_removal("NIC_PCIe_DualLAN", ["NIC_Card_And_Bracket", "NIC_Port_Legends", "Port_RJ45_LAN1", "Port_RJ45_LAN2",
                                  "Socket_RJ45_LAN1", "Socket_RJ45_LAN2", "LED_LAN1_Link"], (0, 0, 0.10))
check_removal("PSU_Module", ["Power_Supply_Enclosure", "Port_AC_C14", "Socket_AC_Power"], (0, 0.18, 0))
report = {
    "result": "PASS", "test": "Blender GLB reimport; not Godot gameplay or manufacturer-fit certification",
    "mesh_objects": len(meshes), "triangles": triangles,
    "overall_dimensions_mm_including_handles": [round(value * 1000, 3) for value in dimensions],
    "ethernet_ports": 2, "contacts_each_ethernet_port": 8,
    "leds_off_by_default": True, "all_rear_socket_markers_face_outward": True,
    "ethernet_ac_usb_vga_rays_reach_correct_ports": True,
    "chassis_has_empty_internal_volume": True,
    "lid_ram_storage_nic_psu_move_independently": True,
    "nic_ports_leds_labels_move_with_card": True,
    "no_external_textures_or_studio_in_export": True, "scene_integrated": False,
}
(BASE / "ใช้ร่วมกัน/exports/rack_server_2u.roundtrip.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2), flush=True)
