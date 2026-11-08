"""One-time targeted migration of town.blend, keeping all other town objects."""
import sys
import shutil
import tempfile
from pathlib import Path
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import school_town

scratch = school_town.ROOT / 'tmp/stairwell_export'
scratch.mkdir(exist_ok=True)
tempfile.tempdir = str(scratch)

source = school_town.OUT / 'town.blend'
backup = school_town.ROOT / 'tmp/town_before_stairwell_fix.blend'
if not backup.exists():
    shutil.copy2(source, backup)
bpy.ops.wm.open_mainfile(filepath=str(source))
floor_backup = school_town.ROOT / 'tmp/town_before_floor_visibility_fix.blend'
if not floor_backup.exists():
    shutil.copy2(source, floor_backup)
targets = [obj for obj in bpy.data.objects if obj.name == 'Lower school storeys' or obj.name.startswith('School floor belt')]
assert len(targets) == 3, [obj.name for obj in targets]
if not bpy.context.scene.get('stairwell_infill_opened', False):
    school_town.open_stairwell(targets)
    bpy.context.scene['stairwell_infill_opened'] = True
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
for obj in targets:
    if obj.name.startswith('School floor belt') and obj.location.z > -1.0:
        obj.location.z = -0.27
bpy.ops.wm.save_as_mainfile(filepath=str(source))
groups = {}
for obj in list(bpy.context.scene.objects):
    if obj.type == 'MESH':
        groups.setdefault(obj.data.materials[0].name, []).append(obj)
for name, objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = 'Town_' + name
output = school_town.OUT / 'godot_preview/town.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_apply=True, export_animations=False)
shutil.copy2(output, school_town.ROOT / 'net-sim-3d/assets/exterior/town.glb')
print('STAIRWELL_INFILL_OPENED: 3 backdrop objects; school and collision untouched')
