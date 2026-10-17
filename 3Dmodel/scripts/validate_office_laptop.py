"""Reimport the authored GLB and verify node roles, scale and hinge clearance."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/laptop")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(BASE / "ใช้ร่วมกัน/exports/office_laptop_14.glb"))
objects = bpy.context.scene.objects
expected = ["OfficeLaptop_14", "Chassis_Base", "Keyboard_Keycaps", "Keyboard_Legends", "Touchpad",
            "Display_Hinge", "Display_Housing", "Screen_Panel", "Screen_Demo_UI", "Port_RJ45_LAN",
            "Socket_RJ45_LAN", "LED_LAN_Link", "LED_LAN_Activity", "LED_Power", "Port_HDMI",
            "USB_A_Left", "USB_A_Right", "Socket_DC_IN"]
assert not [name for name in expected if name not in objects], "Missing required nodes"
meshes = [obj for obj in objects if obj.type == "MESH"]
assert len(meshes) == 18
assert not any(obj.type in {"CAMERA", "LIGHT"} for obj in objects)
assert objects["Screen_Panel"].parent == objects["Display_Hinge"]
assert objects["Screen_Demo_UI"].parent == objects["Display_Hinge"]
assert objects["Port_RJ45_LAN"].get("contact_count") == 8
assert not objects["LED_LAN_Link"].get("default_on")
assert not objects["LED_LAN_Activity"].get("default_on")
assert objects["LED_Power"].get("default_on")


def points(obj):
    return [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]


verts = [vertex for obj in meshes for vertex in points(obj)]
bounds = [max(v[axis] for v in verts) - min(v[axis] for v in verts) for axis in range(3)]
assert 0.337 <= bounds[0] <= 0.342, bounds
assert 0.26 <= bounds[1] <= 0.30, bounds
assert 0.22 <= bounds[2] <= 0.25, bounds
anchor = objects["Socket_RJ45_LAN"]
assert anchor.type == "EMPTY"
outward = (anchor.matrix_world.to_3x3() @ Vector((0, -1, 0))).normalized()
assert outward.x < -0.99, outward

# Rotate the hinge in memory only; do not modify the original asset files.
hinge = objects["Display_Hinge"]
saved_quaternion = hinge.rotation_quaternion.copy()
saved_euler = hinge.rotation_euler.copy()
saved_mode = hinge.rotation_mode
hinge.rotation_mode = "XYZ"
hinge.rotation_euler = (math.pi / 2, 0, 0)
bpy.context.view_layer.update()
closed_screen_min_z = min(v.z for v in points(objects["Screen_Panel"]))
keycaps_max_z = max(v.z for v in points(objects["Keyboard_Keycaps"]))
clearance = closed_screen_min_z - keycaps_max_z
assert clearance >= 0.001, f"Screen intersects keycaps: clearance={clearance}"
hinge.rotation_mode = saved_mode
hinge.rotation_euler = saved_euler
hinge.rotation_quaternion = saved_quaternion
bpy.context.view_layer.update()
report = {"result": "PASS", "test": "Blender GLB roundtrip, not Godot gameplay test",
          "mesh_objects": len(meshes), "open_dimensions_mm_blender_xyz": [round(x * 1000, 2) for x in bounds],
          "closed_screen_to_keycap_clearance_mm": round(clearance * 1000, 3),
          "ethernet_socket_outward_blender": "-X / left side", "ethernet_contacts": 8,
          "display_hinge_preserved": True, "studio_excluded": True, "led_defaults_correct": True}
(BASE / "ใช้ร่วมกัน/exports/office_laptop_14.roundtrip.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2), flush=True)
