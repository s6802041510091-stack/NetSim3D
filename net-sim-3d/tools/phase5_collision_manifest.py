"""Build production collision data for the windowed school without editing its Blend.

Run with Blender: blender -b --python net-sim-3d/tools/phase5_collision_manifest.py
The original manifest supplies only the collider name/kind selection, NEVER
coordinates: the current school has a wider corridor and a translated right wing.
All transforms and evaluated geometry come from the current Blender scene.
The original collision manifest remains available as a rollback reference.
"""

import json
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend"
WINDOW_CHANGES = ROOT / "Preview/โรงเรียนและเมือง/exterior_windows/changes.json"
WINDOW_VERIFICATION = ROOT / "Preview/โรงเรียนและเมือง/exterior_windows/verification.json"
BASELINE = ROOT / "net-sim-3d/data/map_collisions.json"
OUTPUT = ROOT / "net-sim-3d/data/map_collisions_phase5.json"


def world_bounds(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    low = [min(point[axis] for point in corners) for axis in range(3)]
    high = [max(point[axis] for point in corners) for axis in range(3)]
    return low, high


def godot_bounds(obj):
    low, high = world_bounds(obj)
    center = [(low[0] + high[0]) / 2, (low[2] + high[2]) / 2, -(low[1] + high[1]) / 2]
    size = [max(high[0] - low[0], 0.02), max(high[2] - low[2], 0.02), max(high[1] - low[1], 0.02)]
    return [round(v, 4) for v in center], [round(v, 4) for v in size]


def mesh_faces(obj):
    obj.data.calc_loop_triangles()
    faces = []
    for triangle in obj.data.loop_triangles:
        for index in triangle.vertices:
            point = obj.matrix_world @ obj.data.vertices[index].co
            faces.extend((round(point.x, 5), round(point.z, 5), round(-point.y, 5)))
    if not faces:
        raise ValueError(f"Collision mesh has no faces: {obj.name}")
    return faces


def main():
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    changes = json.loads(WINDOW_CHANGES.read_text(encoding="utf-8"))
    verification = json.loads(WINDOW_VERIFICATION.read_text(encoding="utf-8"))
    if not verification["passed"]:
        raise ValueError("Exterior windows verification has not passed")
    modified = set(verification["modified_walls"])
    glass = {name for name in changes["new_objects"] if name.endswith(("_GlassL", "_GlassR"))}
    if len(modified) != 9 or len(glass) != 62:
        raise ValueError(f"Unexpected windowed geometry: {len(modified)} walls, {len(glass)} panes")

    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    selection = {record["name"]: record["kind"] for record in baseline}
    if not modified.issubset(selection):
        raise ValueError("Windowed walls are missing from the collision selection")
    selection.update({name: "window" for name in glass})
    # Include newly authored solid furniture without guessing from decorative names.
    for obj in bpy.data.objects:
        if obj.type == "MESH" and not obj.hide_render and obj.get("collision") == "box":
            selection.setdefault(obj.name, "furniture")

    records = []
    for name, kind in sorted(selection.items()):
        obj = bpy.data.objects.get(name)
        if obj is None or obj.type != "MESH" or obj.hide_render:
            raise ValueError(f"Collision source is missing or hidden: {name}")
        # Match the visual export's export_apply=True (booleans, bevels, etc.).
        evaluated = obj.evaluated_get(depsgraph)
        center, size = godot_bounds(evaluated)
        record = {"name": name, "kind": kind, "center": center, "size": size}
        # Preserve every architectural opening, not just the nine exterior walls.
        # Moving leaves are listed for auditing but skipped by MapCollision.
        if kind in ("wall", "door"):
            record["faces"] = mesh_faces(evaluated)
        records.append(record)

    OUTPUT.write_text(json.dumps(records, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"PHASE5_COLLISION: {len(records)} current-scene shapes, {len(modified)} carved exterior walls, {len(glass)} glass panes, {OUTPUT}", flush=True)


if __name__ == "__main__":
    main()
