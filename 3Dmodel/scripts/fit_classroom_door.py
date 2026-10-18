"""Fit ONLY the original computer-classroom leaf to its current frame.

Run with Blender -b --python this_file -- apply|export.
Apply saves a recoverable copy first and leaves every other object unchanged.
Export refreshes the same school-only GLB used by Phase 5 (not the town).
"""

import argparse
import hashlib
import json
import shutil
import sys
import tempfile
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend"
BACKUP = SOURCE.with_name("classroom_shell_lookdev_before_door_frame_fix.blend")
EXPORT = ROOT / "Preview/โรงเรียนและเมือง/town/godot_preview/architecture.glb"
LEAF = "Door_Leaf_Open_63deg"
SIDE_GAP = 0.004
TOP_GAP = 0.004
FLOOR_GAP = 0.008


def bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (Vector([min(p[i] for p in points) for i in range(3)]),
            Vector([max(p[i] for p in points) for i in range(3)]))


def fingerprint(obj):
    """Catch accidental changes to any other scene object before saving."""
    geometry = None
    if obj.type == "MESH":
        geometry = hashlib.sha256(b"".join(
            str(tuple(v.co)).encode("ascii") for v in obj.data.vertices)).hexdigest()
    return (tuple(tuple(row) for row in obj.matrix_world), geometry,
            obj.parent.name if obj.parent else None, obj.hide_render, obj.hide_viewport)


def apply():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.view_layer.update()
    leaf = bpy.data.objects[LEAF]
    # Do not apply this calculation silently to a different door convention.
    assert leaf.parent is None and abs(leaf.rotation_euler.z - 1.09955743) < 1e-5
    before = {obj.name: fingerprint(obj) for obj in bpy.context.scene.objects if obj.name != LEAF}
    front_low, front_high = bounds(bpy.data.objects["Door_Frame_Front_Jamb"])
    rear_low, rear_high = bounds(bpy.data.objects["Door_Frame_Rear_Jamb"])
    header_low, _ = bounds(bpy.data.objects["Door_Frame_Header"])
    # Closed leaf rotates 180 degrees about Blender Z: +local Y -> -world Y.
    opening_width = front_low.y - rear_high.y
    width = opening_width - 2 * SIDE_GAP
    height = header_low.z - TOP_GAP - FLOOR_GAP
    low = Vector([min(v.co[i] for v in leaf.data.vertices) for i in range(3)])
    high = Vector([max(v.co[i] for v in leaf.data.vertices) for i in range(3)])
    leaf.data = leaf.data.copy()
    for vertex in leaf.data.vertices:
        vertex.co.y = SIDE_GAP + (vertex.co.y - low.y) * width / (high.y - low.y)
        vertex.co.z = -height / 2 + (vertex.co.z - low.z) * height / (high.z - low.z)
    leaf.scale = (1, 1, 1)
    leaf.location = ((front_low.x + front_high.x) / 2,
                     front_low.y, FLOOR_GAP + height / 2)
    leaf.data.update()
    bpy.context.view_layer.update()
    after = {obj.name: fingerprint(obj) for obj in bpy.context.scene.objects if obj.name != LEAF}
    assert before == after, "An unrelated object changed; refusing to save"
    if not BACKUP.exists():
        shutil.copy2(SOURCE, BACKUP)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)
    print("CLASSROOM_DOOR_FIT", json.dumps({
        "only_changed_object": LEAF, "opening_width_m": opening_width,
        "leaf_width_m": width, "leaf_height_m": height,
        "side_gap_m": SIDE_GAP, "top_gap_m": TOP_GAP,
        "floor_gap_m": FLOOR_GAP, "blender_origin": list(leaf.location),
        "other_objects_unchanged": len(before), "backup": str(BACKUP),
    }), flush=True)


def export():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    # Same selection contract as phase2_architecture.export / the town preview.
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and not obj.hide_render and not obj.name.startswith("Plan_"):
            obj.hide_set(False)
            obj.select_set(True)
            selected.append(obj)
    bpy.context.view_layer.objects.active = selected[0]
    scratch = ROOT / "tmp/godot-4.7.1/classroom_door_export"
    scratch.mkdir(parents=True, exist_ok=True)
    tempfile.tempdir = str(scratch)
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), export_format="GLB", use_selection=True,
        export_apply=True, export_animations=False, export_cameras=False,
        export_lights=False,
    )
    print("CLASSROOM_DOOR_EXPORTED", len(selected), str(EXPORT), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("apply", "export"))
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    apply() if args.mode == "apply" else export()
