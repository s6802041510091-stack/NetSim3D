"""Export the existing Blender scene and characters for Godot.

Run with: blender -b --python tools/export_blender_assets.py -- map|character ...
The source .blend files are read, never saved back.
"""

import json
import os
import sys

import bpy
from mathutils import Vector


# Repository root (this file is net-sim-3d/tools/export_blender_assets.py), so the
# script works wherever the project is cloned.
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJECT = os.path.join(ROOT, "net-sim-3d")
BLEND = os.path.join(ROOT, "3Dmodel", "ใช้ร่วมกัน", "blend")
MODELS = os.path.join(PROJECT, "assets", "models")
DATA = os.path.join(PROJECT, "data")


def world_bounds(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    lo = [min(v[i] for v in corners) for i in range(3)]
    hi = [max(v[i] for v in corners) for i in range(3)]
    return lo, hi


def collision_kind(name):
    if name.startswith(("Plan_", "Floor01_Origin", "Room_Stairs")):
        return None
    if name == "Floor_Slab_150mm" or name.endswith("_Floor") or "LowerFloor_" in name or "UpperFloor_" in name:
        return "floor"
    if "Ceiling" in name or name.endswith("_Roof"):
        return "ceiling"
    if name.startswith(("Stair_UP_Step", "Stair_DOWN_Step")) or "_Terminal_Landing" in name or name == "Stair_Main_Landing":
        return "stairs"
    if name.startswith("StairShell_"):
        if "Guard" in name or "Rail" in name or "SolidUnderside" in name:
            return None
        return "wall"
    if "Wall" in name or "Partition" in name or name.startswith(("Corridor_North_End", "Corridor_South_End", "Left_Corridor_", "Right_Corridor_", "Right_Outer_Extension_", "Left_Outer_Wall_", "Left_Top_Wall_", "Left_Bottom_Wall_", "Right_Top_Wall_")):
        if "Skirting" in name:
            return None
        return "wall"
    if name.startswith("Chair_"):
        return "chair"
    if name.endswith("_Leaf") or name == "Door_Leaf_Open_63deg":
        return "door"
    if name in ("TeacherDesk", "IT_PlayerDesk", "IT_HeadDesk", "IT_SpareDesk") or name.startswith("StudentDesk_Row") and name.endswith(("_Left", "_Right")):
        return "desk"
    if "ClearGlass" in name or name.endswith(("_Jamb", "_Mullion", "_Sill", "_Rail")):
        return "window"
    return None


def export_map(do_export=True):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(BLEND, "classroom_shell.blend"))
    bpy.context.view_layer.update()
    records = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        # Furniture built by 3Dmodel/scripts/*.py marks itself with collision="box".
        kind = "furniture" if obj.get("collision") == "box" else collision_kind(obj.name)
        if kind is None:
            continue
        low, high = world_bounds(obj)
        dims = [high[i] - low[i] for i in range(3)]
        # Discard thin decorative details misidentified by their names.
        if kind in ("floor", "ceiling") and dims[0] * dims[1] < 0.15:
            continue
        if kind == "wall" and dims[2] < 0.35:
            continue
        if kind == "window" and max(dims[0], dims[1]) < 0.2:
            continue
        # Blender Z-up -> Godot Y-up, with Blender Y becoming Godot -Z.
        center = [(low[0] + high[0]) / 2, (low[2] + high[2]) / 2, -(low[1] + high[1]) / 2]
        size = [max(dims[0], 0.02), max(dims[2], 0.02), max(dims[1], 0.02)]
        record = {"name": obj.name, "kind": kind, "center": [round(v, 4) for v in center], "size": [round(v, 4) for v in size]}
        # These are single meshes with real door/window openings. An AABB would
        # seal the doorway, so preserve their triangle geometry for static collision.
        if obj.name in ("Wall_Left_With_Door", "Wall_Right_With_Three_Windows") or kind == "door":
            obj.data.calc_loop_triangles()
            faces = []
            for tri in obj.data.loop_triangles:
                for index in tri.vertices:
                    co = obj.matrix_world @ obj.data.vertices[index].co
                    faces.extend((round(co.x, 5), round(co.z, 5), round(-co.y, 5)))
            record["faces"] = faces
        records.append(record)

    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, "map_collisions.json"), "w", encoding="utf-8") as out:
        json.dump(records, out, ensure_ascii=False, separators=(",", ":"))
    print("COLLISION_COUNTS", {kind: sum(r["kind"] == kind for r in records) for kind in sorted(set(r["kind"] for r in records))}, flush=True)

    if not do_export:
        return

    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        if obj.name.startswith(("Plan_", "Floor01_Origin", "Room_Stairs")) or obj.name == "Desk_Preview_Area":
            continue
        obj.select_set(True)
        selected.append(obj)
    if selected:
        bpy.context.view_layer.objects.active = selected[0]
    print("EXPORT_MAP_OBJECTS", len(selected), flush=True)
    os.makedirs(MODELS, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(MODELS, "classroom_shell.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    print("EXPORTED_MAP", flush=True)


def export_character(stem):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(BLEND, stem + ".blend"))
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for obj in bpy.data.objects:
        if obj.type not in ("MESH", "ARMATURE"):
            continue
        if obj.name.lower().startswith(("studio floor", "preview floor")) or obj.hide_render:
            continue
        if obj.type == "ARMATURE":
            obj.hide_set(False)
            obj.hide_viewport = False
        obj.select_set(True)
        selected.append(obj)
    rig = next((obj for obj in selected if obj.type == "ARMATURE"), selected[0])
    bpy.context.view_layer.objects.active = rig
    print("EXPORT_CHARACTER", stem, len(selected), "rig_bones", len(rig.data.bones), flush=True)
    os.makedirs(MODELS, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(MODELS, stem + ".glb"),
        export_format="GLB",
        use_selection=True,
        # Applying the Armature modifier would bake the pose and remove skins.
        export_apply=False,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    print("EXPORTED_CHARACTER", stem, flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args and args[0] == "map":
        export_map()
    elif args and args[0] == "manifest":
        export_map(do_export=False)
    elif len(args) == 2 and args[0] == "character":
        export_character(args[1])
    else:
        raise SystemExit("Usage: -- map | character <blend_stem>")
