"""Read-only GLB reimport test; writes only a task-local validation report."""
import json
from pathlib import Path

import bpy
from mathutils import Vector

asset_root = Path(__file__).resolve().parents[1]
assert asset_root.drive.upper() == "D:"
bpy.context.preferences.filepaths.temporary_directory = str(asset_root / "temp")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(asset_root / "ใช้ร่วมกัน/exports" / "office_switch_8port.glb"))

objects = bpy.context.scene.objects
expected_names = ["OfficeSwitch_8Port", "LED_Power", "Socket_DC"]
for index in range(1, 9):
    expected_names += [f"RJ45_Port_{index:02}", f"LED_Link_{index:02}", f"Socket_RJ45_{index:02}"]
assert not [name for name in expected_names if name not in objects], "Missing named components"
meshes = [obj for obj in objects if obj.type == "MESH"]
assert len(meshes) == 19, f"Unexpected mesh count: {len(meshes)}"
assert all(obj.type not in {"CAMERA", "LIGHT"} for obj in objects), "Studio leaked into GLB"
points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
bounds = [max(v[axis] for v in points) - min(v[axis] for v in points) for axis in range(3)]
assert 0.209 <= bounds[0] <= 0.213, bounds
assert 0.109 <= bounds[1] <= 0.116, bounds
assert 0.035 <= bounds[2] <= 0.040, bounds
assert all(objects[f"Socket_RJ45_{i:02}"].type == "EMPTY" for i in range(1, 9))
report = {
    "result": "PASS",
    "test": "Blender glTF importer roundtrip (not an in-Godot gameplay test)",
    "mesh_objects": len(meshes),
    "dimensions_mm_blender_xyz": [round(value * 1000, 3) for value in bounds],
    "all_named_ports_leds_and_socket_anchors_present": True,
    "no_studio_cameras_or_lights_exported": True,
}
(asset_root / "ใช้ร่วมกัน/exports" / "office_switch_8port.roundtrip.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
