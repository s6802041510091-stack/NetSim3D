"""Derive the viewmodel from the EXACT avatar GLB used by the game.
Never edits the avatar. Retains skin/sleeve topology, UVs and materials.
"""
from pathlib import Path
import hashlib
import json
import tempfile
import bmesh
import bpy
from mathutils import Vector, Quaternion
import math
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'net-sim-3d/assets/models/it_support_male_180cm.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for name in ['upperarm01.R', 'lowerarm01.R', 'wrist.R', 'finger3-1.R']:
    bone = rig.data.bones[name]
    print('ARM_BONE', name, tuple(bone.head_local), tuple(bone.tail_local))
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        print('ARM_MESH', obj.name, len(obj.data.vertices), len(obj.vertex_groups))

scratch = ROOT / 'tmp/avatar_arm_export'
scratch.mkdir(exist_ok=True)
tempfile.tempdir = str(scratch)
elbow = rig.matrix_world @ rig.data.bones['lowerarm01.R'].head_local
wrist = rig.matrix_world @ rig.data.bones['wrist.R'].head_local
rotation = (wrist - elbow).normalized().rotation_difference(Vector((0, 0, 1)))
# Curl the avatar's existing finger joints into a relaxed grip; no new hand mesh.
across = (rig.data.bones['finger2-1.R'].head_local - rig.data.bones['finger5-1.R'].head_local).normalized()
relaxed = '--relaxed' in sys.argv
relaxed_angles = {2: (12, 20, 10), 3: (24, 30, 15), 4: (32, 35, 20), 5: (38, 40, 20)}
for finger in range(2, 6):
    angles = relaxed_angles[finger] if relaxed else (40, 55, 30)
    for segment, degrees in enumerate(angles, start=1):
        bone = rig.pose.bones[f'finger{finger}-{segment}.R']
        axis = bone.bone.matrix_local.to_3x3().inverted() @ across
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = Quaternion(axis.normalized(), math.radians(degrees))
bpy.context.view_layer.update()
derived = []
report = []
for obj in list(bpy.data.objects):
    if obj.type != 'MESH' or not obj.name.startswith(('Body |', 'Polo | short sleeve')):
        continue
    allowed = {g.index for g in obj.vertex_groups if g.name.endswith('.R') and g.name.startswith(('upperarm', 'lowerarm', 'wrist', 'finger', 'metacarpal'))}
    keep = {v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in allowed) >= 0.5}
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()), preserve_all_data_layers=True, depsgraph=bpy.context.evaluated_depsgraph_get())
    assert len(mesh.vertices) == len(obj.data.vertices), 'Evaluated topology changed'
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context='VERTS')
    bm.to_mesh(mesh)
    bm.free()
    for vertex in mesh.vertices:
        vertex.co = rotation @ (obj.matrix_world @ vertex.co - wrist)
    mesh.update()
    arm = bpy.data.objects.new('AvatarRightArm_' + ('Skin' if obj.name.startswith('Body') else 'OriginalSleeve'), mesh)
    bpy.context.collection.objects.link(arm)
    derived.append(arm)
    report.append({'source_mesh': obj.name, 'vertices': len(mesh.vertices), 'faces': len(mesh.polygons), 'materials': [m.name for m in mesh.materials]})
assert len(derived) == 2 and all(len(o.data.polygons) > 0 for o in derived)
bpy.ops.object.select_all(action='DESELECT')
for obj in derived:
    obj.select_set(True)
stem = 'player_right_arm_relaxed' if relaxed else 'player_right_arm'
output = ROOT / f'net-sim-3d/assets/models/{stem}.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_animations=False)
manifest = {'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'method': 'right-arm skin weights >= 0.5; original topology/UV/materials; original finger bones posed into relaxed grip; wrist-centered transform; no replacement geometry', 'meshes': report}
manifest['pose'] = 'relaxed reference C-shape' if relaxed else 'tool grip'
(ROOT / f'net-sim-3d/assets/models/{stem}.source.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print('AVATAR_RIGHT_ARM_EXPORTED', report)
