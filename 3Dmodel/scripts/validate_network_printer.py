"""Read-only GLB reimport tests; report and Blender work files remain on D:."""
from pathlib import Path
import json

import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parents[1]
assert BASE.drive.upper() == "D:"
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/printer")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def bounds(meshes):
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    return [max(point[axis] for point in points) - min(point[axis] for point in points) for axis in range(3)]


clear_scene()
bpy.ops.import_scene.gltf(filepath=str(BASE / "ใช้ร่วมกัน/exports/office_network_printer.glb"))
objects = bpy.context.scene.objects
required = ["NetworkPrinter_LP210N", "Printer_Chassis", "Input_Cassette_Slide", "Input_Paper_Cassette",
            "Output_Tray_And_Rollers", "Paper_Output", "Port_RJ45_LAN", "Socket_RJ45_LAN",
            "LED_LAN_Link", "LED_LAN_Activity", "Port_USB_B", "Socket_USB_B", "Port_AC_C14",
            "Socket_AC_Power", "Status_LCD", "Status_LCD_Text", "Button_Power", "Button_Go", "LED_Ready"]
assert all(name in objects for name in required), [name for name in required if name not in objects]
meshes = [obj for obj in objects if obj.type == "MESH"]
assert len(meshes) == 16, len(meshes)
assert not any(obj.type in {"CAMERA", "LIGHT"} for obj in objects)
assert "Paper_Sheet" not in objects, "Optional output paper must not be baked into main asset"
assert objects["Port_RJ45_LAN"].get("contact_count") == 8
assert not objects["LED_LAN_Link"].get("default_on")
assert not objects["LED_LAN_Activity"].get("default_on")
assert objects["LED_Ready"].get("default_on")
dimensions = bounds(meshes)
assert 0.358 <= dimensions[0] <= 0.365, dimensions
assert 0.348 <= dimensions[1] <= 0.36, dimensions
assert 0.251 <= dimensions[2] <= 0.26, dimensions
# Verify that the case does not fill the jack cavities behind the rear panel.
for port, x, z in [("Port_RJ45_LAN", 0.087, 0.154), ("Port_USB_B", 0.120, 0.156)]:
    hit, location, normal, face, hit_object, matrix = bpy.context.scene.ray_cast(
        bpy.context.evaluated_depsgraph_get(), Vector((x, 0.20, z)), Vector((0, -1, 0)), distance=0.07)
    assert hit and hit_object.name == port, (port, hit_object.name if hit else "no hit")
for name in ("Socket_RJ45_LAN", "Socket_USB_B", "Socket_AC_Power"):
    obj = objects[name]
    assert obj.type == "EMPTY"
    outward = (obj.matrix_world.to_3x3() @ Vector((0, -1, 0))).normalized()
    assert outward.y > 0.99, (name, outward)
cassette = objects["Input_Paper_Cassette"]
slide = objects["Input_Cassette_Slide"]
assert cassette.parent == slide
before = cassette.matrix_world.translation.copy()
slide.location.y -= 0.22
bpy.context.view_layer.update()
translation = cassette.matrix_world.translation - before
assert abs(translation.y + 0.22) < 0.00001
assert abs(translation.x) < 0.00001 and abs(translation.z) < 0.00001
slide.location.y += 0.22
bpy.context.view_layer.update()
report = {"result": "PASS", "test": "Blender GLB roundtrip; not Godot gameplay validation",
          "printer_mesh_objects": len(meshes), "printer_dimensions_mm": [round(value * 1000, 3) for value in dimensions],
          "ports_face_rear": True, "ethernet_contacts": 8, "led_defaults_correct": True,
          "cassette_slide_parent_preserved": True, "studio_and_optional_sheet_excluded": True,
          "ethernet_and_usb_cavities_clear_of_chassis": True}

clear_scene()
bpy.ops.import_scene.gltf(filepath=str(BASE / "ใช้ร่วมกัน/exports/printer_printed_sheet_a4.glb"))
objects = bpy.context.scene.objects
assert all(name in objects for name in ("PrintedSheet_A4", "Paper_Sheet", "Paper_Print_Underside"))
sheet_dimensions = bounds([objects["Paper_Sheet"]])
assert abs(sheet_dimensions[0] - 0.21) < 0.0001
assert abs(sheet_dimensions[1] - 0.297) < 0.0001
assert objects["Paper_Sheet"].parent == objects["PrintedSheet_A4"]
assert objects["Paper_Print_Underside"].parent == objects["PrintedSheet_A4"]
report["separate_A4_sheet_valid"] = True
(BASE / "ใช้ร่วมกัน/exports/office_network_printer.roundtrip.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2), flush=True)
