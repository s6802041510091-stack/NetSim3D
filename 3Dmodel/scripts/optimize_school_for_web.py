"""Build the web-budget school GLB from the full-detail lookdev (Phase B).

Run: blender -b --python 3Dmodel/scripts/optimize_school_for_web.py -- [--no-pack]

The lookdev .blend is opened and reduced IN MEMORY only; it is never saved, so
the detailed source stays the reference. Steps:
  R1  drop the rack-equipment detail overlay in the server room (the racks stay)
  R2  drop sub-centimetre peripheral details (ribs, contacts, glide pads ...),
      join each keyboard's keys and each peripheral's parts into one object,
      and decimate the remaining heavy, purely decorative meshes
Every object that gameplay or validation reads by name is left untouched:
collision sources, monitor screens, door parts, stairs, corridor/floor, glass.
The result is exported like Phase 5 (export_apply=True) and packed with
gltfpack -kn -km -noq into net-sim-3d/assets/models/classroom_shell.glb.
"""

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend"
COLLISIONS = ROOT / "net-sim-3d/data/map_collisions_phase5.json"
SCRATCH = ROOT / "tmp/web_budget"
RAW = SCRATCH / "school_web_raw.glb"
OUTPUT = ROOT / "net-sim-3d/assets/models/classroom_shell.glb"
GLTFPACK = ROOT / "tmp/godot-4.7.1/gltfpack/gltfpack.exe"
REPORT = SCRATCH / "school_web_report.json"

RACK_DETAIL_COLLECTION = "P3 | Rack equipment details"
PERIPHERAL_COLLECTION = "15 | Realistic connected computer peripherals"
# Collections that hold one computer (case, monitor, keyboard, buttons ...).
COMPUTER_COLLECTION = re.compile(r"(\| Computer \d+$|^Teacher Computer|^ASSET \| NetCare Desktop)")
# Interactive/validated name prefixes that must survive with their exact names.
PROTECTED_PREFIXES = (
    "Door_", "BackgroundClass_", "FemaleWC_", "MaleWC_", "ITSupport_", "Storage_",
    "Staff_", "Server_", "Stair", "Corridor_", "Floor_", "EW_",
)
# Details too small to read in first person at desk distance.
TINY_DETAIL = 0.012  # metres, largest dimension
TINY_NAME_HINTS = (
    "grip rib", "grip ridges", "strain relief moulded rib", "finger grip rib",
    "hdmi contact", "usb contact", "wheel tread", "metal pin", "glide pad",
    "socket dark interior", "deep socket insert",
)
# Decimation: decorative meshes heavier than this are reduced toward TARGET.
DECIMATE_ABOVE = 2000
DECIMATE_TARGET = 1500
GLOBAL_DECIMATE_ABOVE = 8000  # anything else in the school this heavy
GLOBAL_KEEP_RATIO = 0.25
# Box colliders are precomputed from the full-detail source, so these may be
# visually decimated; validate_map_alignment.gd checks their bounds still match.
DECIMATABLE_COLLIDER_KINDS = ("furniture", "chair", "desk")


def collision_kinds():
    return {record["name"]: record["kind"] for record in json.loads(COLLISIONS.read_text(encoding="utf-8"))}


def is_protected(obj, keep):
    name = obj.name
    return (name in keep or "Monitor_Display_Surface" in name
            or name.startswith(PROTECTED_PREFIXES) or bool(obj.get("collision")))


def may_decimate(obj, keep):
    """Visual-only reduction is allowed for box-collider furniture too."""
    if "Monitor_Display_Surface" in obj.name or obj.name.startswith(PROTECTED_PREFIXES):
        return False
    kind = keep.get(obj.name)
    if kind is not None:
        return kind in DECIMATABLE_COLLIDER_KINDS
    return not obj.get("collision") or obj.get("collision") == "box"


def exported(obj):
    return obj.type == "MESH" and not obj.hide_render and not obj.name.startswith("Plan_")


def collection_of(obj):
    return obj.users_collection[0].name if obj.users_collection else ""


def triangles(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def scene_stats():
    depsgraph = bpy.context.evaluated_depsgraph_get()
    objects = [obj for obj in bpy.context.scene.objects if exported(obj)]
    return {"objects": len(objects), "tris": sum(triangles(obj, depsgraph) for obj in objects)}


def bake_modifiers(objects):
    """Give each object its own mesh with modifiers applied (needed before join)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        baked = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph)
        # Keep object-linked materials, which new_from_object would otherwise drop.
        materials = [slot.material for slot in obj.material_slots]
        obj.modifiers.clear()
        obj.data = baked
        for index, material in enumerate(materials):
            if index < len(obj.material_slots):
                obj.material_slots[index].link = "DATA"
                obj.material_slots[index].material = material


def join(objects, name):
    if len(objects) < 2:
        return objects[0] if objects else None
    bake_modifiers(objects)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    return joined


MIN_COLLAPSE_RATIO = 0.25  # below this, collapse folded PC-case panels
# Rounded/small parts that stayed visually intact even at ~3% in screenshots.
AGGRESSIVE_NAMES = re.compile(r"(_Keys$|wired mouse|Monitor_StaticDetails|Keyboard_StaticDetails)")
AGGRESSIVE_MIN_RATIO = 0.04


def decimate(obj, target_tris, depsgraph_tris):
    """Planar dissolve first (keeps hard-surface silhouettes), then a bounded collapse."""
    planar = obj.modifiers.new("WebBudgetPlanar", "DECIMATE")
    planar.decimate_type = "DISSOLVE"
    planar.angle_limit = 0.0175  # 1 degree: only merges truly coplanar faces
    planar.use_dissolve_boundaries = False
    bpy.context.view_layer.update()
    remaining = depsgraph_tris(obj)
    if remaining > target_tris:
        modifier = obj.modifiers.new("WebBudgetDecimate", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        floor = AGGRESSIVE_MIN_RATIO if AGGRESSIVE_NAMES.search(obj.name) else MIN_COLLAPSE_RATIO
        modifier.ratio = max(target_tris / remaining, floor)
        modifier.use_collapse_triangulate = True
    # Collapsing loses the hard-surface custom normals and smears shading across
    # box edges (PC cases looked bent). Re-split sharp edges after decimation.
    split = obj.modifiers.new("WebBudgetEdgeSplit", "EDGE_SPLIT")
    split.split_angle = 0.5236  # 30 degrees
    split.use_edge_sharp = True


def reduce_scene():
    keep = collision_kinds()
    removed = joined_groups = decimated = 0

    # R1: rack detail overlay (2.25 M triangles of decoration).
    for obj in list(bpy.context.scene.objects):
        if collection_of(obj) == RACK_DETAIL_COLLECTION and not is_protected(obj, keep):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1

    # R2a: sub-centimetre details on computers and peripherals.
    for obj in list(bpy.context.scene.objects):
        if not exported(obj) or is_protected(obj, keep):
            continue
        collection = collection_of(obj)
        if collection != PERIPHERAL_COLLECTION and not COMPUTER_COLLECTION.search(collection):
            continue
        lowered = obj.name.lower()
        if max(obj.dimensions) < TINY_DETAIL or any(hint in lowered for hint in TINY_NAME_HINTS):
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1

    # R2b: one object per keyboard key set and per peripheral part group.
    groups = {}
    for obj in bpy.context.scene.objects:
        if not exported(obj) or is_protected(obj, keep):
            continue
        collection = collection_of(obj)
        if COMPUTER_COLLECTION.search(collection):
            key = re.match(r"^(.*?__)Key_", obj.name)
            if key:
                groups.setdefault((collection, key.group(1) + "Keys"), []).append(obj)
        elif collection == PERIPHERAL_COLLECTION and " | " in obj.name:
            groups.setdefault((collection, obj.name.split(" | ")[0].strip()), []).append(obj)
    for (_, name), members in groups.items():
        if len(members) > 1:
            join(members, name)
            joined_groups += 1

    # R2c: decimate heavy decorative meshes.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in list(bpy.context.scene.objects):
        if not exported(obj) or not may_decimate(obj, keep):
            continue
        collection = collection_of(obj)
        tris = triangles(obj, depsgraph)
        count = lambda o: triangles(o, bpy.context.evaluated_depsgraph_get())
        if collection == PERIPHERAL_COLLECTION or COMPUTER_COLLECTION.search(collection):
            if tris > DECIMATE_ABOVE:
                decimate(obj, DECIMATE_TARGET, count)
                decimated += 1
        elif tris > GLOBAL_DECIMATE_ABOVE:
            decimate(obj, tris * GLOBAL_KEEP_RATIO, count)
            decimated += 1
    return {"removed": removed, "joined_groups": joined_groups, "decimated": decimated}


def export_and_pack(pack=True):
    SCRATCH.mkdir(parents=True, exist_ok=True)
    tempfile.tempdir = str(SCRATCH)
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    # Same selection contract as fit_classroom_door.export / phase2_architecture.
    for obj in bpy.context.scene.objects:
        if exported(obj):
            obj.hide_set(False)
            obj.select_set(True)
            selected.append(obj)
    bpy.context.view_layer.objects.active = selected[0]
    bpy.ops.export_scene.gltf(
        filepath=str(RAW), export_format="GLB", use_selection=True,
        export_apply=True, export_animations=False, export_cameras=False,
        export_lights=False,
    )
    if pack:
        subprocess.run([str(GLTFPACK), "-i", str(RAW), "-o", str(OUTPUT), "-kn", "-km", "-noq"], check=True)
    return len(selected)


def main():
    pack = "--no-pack" not in sys.argv
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    before = scene_stats()
    actions = reduce_scene()
    after = scene_stats()
    exported_count = export_and_pack(pack)
    report = {"before": before, "after": after, "actions": actions, "exported_objects": exported_count,
              "raw_glb_bytes": RAW.stat().st_size, "packed": pack,
              "output_bytes": OUTPUT.stat().st_size if pack else None,
              "source_saved": False}
    REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("SCHOOL_WEB_BUDGET", json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
