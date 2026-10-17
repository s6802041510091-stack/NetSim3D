"""Reimport both Cat6 GLBs and validate geometry, markers, wiring and path.

This tests exported assets in Blender, not live Godot gameplay or certification.
Use run_build_cat6.ps1 -ValidateOnly to keep temporary files on D:.
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
bpy.context.preferences.filepaths.temporary_directory = str(BASE / "temp/cat6")
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
COLORS = ["white/orange", "orange", "white/green", "blue", "white/blue", "green", "white/brown", "brown"]


def read_glb(name):
    path = BASE / "ใช้ร่วมกัน/exports" / name
    with path.open("rb") as handle:
        magic, version, total = struct.unpack("<4sII", handle.read(12))
        length, kind = struct.unpack("<II", handle.read(8))
        data = json.loads(handle.read(length))
    assert magic == b"glTF" and version == 2 and total == path.stat().st_size
    assert kind == 0x4E4F534A
    assert not data.get("cameras") and not data.get("images")
    assert not data.get("animations")
    assert not any("uri" in buffer for buffer in data.get("buffers", []))
    assert any(mat.get("alphaMode") == "BLEND" for mat in data["materials"])
    return data


def import_clean(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(BASE / "ใช้ร่วมกัน/exports" / name))
    bpy.context.view_layer.update()
    objects = bpy.context.scene.objects
    assert not any(obj.type in {"CAMERA", "LIGHT", "CURVE"} for obj in objects)
    assert not any(obj.name.startswith("Studio") for obj in objects)
    assert "Cable_Path_EDIT" not in objects
    for obj in objects:
        if obj.type == "MESH":
            assert len(obj.data.polygons) > 0
            assert all(math.isfinite(value) for vertex in obj.data.vertices for value in vertex.co)
            assert all(abs(value - 1) < 1e-5 for value in obj.scale)
    return objects


def assert_close(a, b, tolerance=0.000002):
    assert (Vector(a) - Vector(b)).length < tolerance, (list(a), list(b))


def check_pins(objects, suffix, parent_name):
    parent = objects[parent_name]
    contacts = objects["Contacts_8Pin" + suffix]
    assert contacts.get("contact_count") == 8
    assert contacts.parent == parent
    for index, color in enumerate(COLORS, 1):
        pin = objects[f"Pin_{index:02}" + suffix]
        assert pin.type == "EMPTY" and pin.parent == parent
        assert pin.get("pin_number") == index
        assert pin.get("insulation_color") == color
        assert_close(pin.location, ((index - 4.5) * 0.00102, -0.0036, 0.00402))
    for name in ("Plug_Housing", "Latch_Clip", "Strain_Relief_Boot", "Termination_Conductors", "Boot_Legend"):
        assert objects[name + suffix].parent == parent
    assert_close(objects["MatingTip" + suffix].location, (0, 0, 0))
    assert_close(objects["CableExit" + suffix].location, (0, -0.0345, 0))


whole_data = read_glb("lan_cable_cat6_5m.glb")
module_data = read_glb("rj45_cat6_plug.glb")
path_data = json.loads((BASE / "ใช้ร่วมกัน/exports/lan_cable_cat6_5m.path.json").read_text(encoding="utf-8"))
assert path_data["units"] == "metres"
points = np.array(path_data["points"], dtype=float)
assert np.isfinite(points).all() and points.shape[1] == 3
segment_lengths = np.linalg.norm(np.diff(points, axis=0), axis=1)
assert (segment_lengths > 0).all()
path_length = float(segment_lengths.sum())
assert abs(path_length - 4.931) < 0.000001
assert abs(path_data["cable_radius"] - 0.0031) < 1e-9
# Repeat clearance check independently at 1 mm spacing (builder uses 2 mm).
arc = np.concatenate(([0.0], np.cumsum(segment_lengths)))
samples = np.linspace(0, arc[-1], math.ceil(arc[-1] / 0.001) + 1)
dense = np.stack([np.interp(samples, arc, points[:, axis]) for axis in range(3)], axis=1)
minimum_separation = math.inf
for start in range(0, len(dense), 128):
    chunk = dense[start:start + 128]
    distances = np.linalg.norm(chunk[:, None, :] - dense[None, :, :], axis=2)
    distances[np.abs(samples[start:start + len(chunk), None] - samples[None, :]) < 0.05] = np.inf
    minimum_separation = min(minimum_separation, float(distances.min()))
assert minimum_separation > 0.0067, minimum_separation

objects = import_clean("lan_cable_cat6_5m.glb")
meshes = [obj for obj in objects if obj.type == "MESH"]
assert len(meshes) == 13, len(meshes)
root = objects["Cat6_PatchCable_5m"]
assert objects["Cable_Jacket"].parent == root
assert root.get("nominal_end_to_end_length_m") == 5.0
assert root.get("jacket_diameter_mm") == 6.2
for tag, expected in (("A", points[0]), ("B", points[-1])):
    check_pins(objects, "_" + tag, "Plug_" + tag)
    assert objects["Plug_" + tag].parent == root
    assert objects["Plug_" + tag].get("wiring") == "T568B"
    assert_close(objects["CableExit_" + tag].matrix_world.translation, expected)
assert_close(objects["Cable_Start"].matrix_world.translation, points[0])
assert_close(objects["Cable_End"].matrix_world.translation, points[-1])
whole_triangles = 0
for obj in meshes:
    obj.data.calc_loop_triangles()
    whole_triangles += len(obj.data.loop_triangles)

objects = import_clean("rj45_cat6_plug.glb")
assert len([obj for obj in objects if obj.type == "MESH"]) == 6
assert "Cable_Jacket" not in objects
root = objects["RJ45_Plug_Module"]
assert_close(root.location, (0, 0, 0))
assert_close(root.rotation_euler, (0, 0, 0))
check_pins(objects, "", "RJ45_Plug_Module")
assert root.get("contact_count") == 8
assert root.get("mating_direction_gltf") == "-Z"
housing = objects["Plug_Housing"]
coordinates = [housing.matrix_world @ vertex.co for vertex in housing.data.vertices]
body_width = max(point.x for point in coordinates) - min(point.x for point in coordinates)
assert abs(body_width - 0.0116) < 0.0001, body_width
# Moving the reusable module carries the tip, latch, body, and cable anchor together.
anchor = objects["CableExit"]
before = anchor.matrix_world.translation.copy()
root.location.x += 0.02
bpy.context.view_layer.update()
assert_close(anchor.matrix_world.translation - before, (0.02, 0, 0))

report = {
    "result": "PASS",
    "test": "Blender GLB roundtrip; not Godot gameplay or physical connector-fit certification",
    "full_cable_mesh_objects": 13,
    "full_cable_triangles": whole_triangles,
    "reusable_plug_mesh_objects": 6,
    "end_to_end_centerline_length_mm": round((path_length + 0.069) * 1000, 6),
    "minimum_nonlocal_centerline_separation_mm_at_1mm_sampling": round(minimum_separation * 1000, 3),
    "connector_body_width_mm": round(body_width * 1000, 3),
    "contacts_per_end": 8,
    "straight_through_T568B_colors_preserved": True,
    "cable_exit_anchors_match_jacket_endpoints": True,
    "nose_origin_and_independent_latch_preserved": True,
    "transparent_materials_preserved": True,
    "self_contained_glb_without_external_textures": True,
    "studio_and_source_curve_excluded": True,
    "scene_integrated": False,
}
(BASE / "ใช้ร่วมกัน/exports/lan_cable_cat6_5m.roundtrip.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2), flush=True)
