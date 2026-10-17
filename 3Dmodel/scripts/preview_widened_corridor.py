"""Reopen and render widened map; preview visibility changes are not saved."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT = Path('D:/NetSim3D/3Dmodel')
OUT = ROOT / 'ใช้ร่วมกัน/renders/corridor_widened'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'ใช้ร่วมกัน/blend/classroom_shell.blend'))
s = bpy.context.scene
assert abs(s['map_clear_corridor_width_m'] - 5.929014084507041) < 1e-5
assert len(s.objects) == 10376
print('REOPEN_VERIFIED', s['map_clear_corridor_width_m'], len(s.objects), flush=True)
s.render.engine = 'CYCLES'
s.cycles.samples = 24
s.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'OPTIX'
    prefs.get_devices()
    gpu = False
    for d in prefs.devices:
        d.use = d.type != 'CPU'
        gpu |= d.use
    s.cycles.device = 'GPU' if gpu else 'CPU'
except Exception:
    s.cycles.device = 'CPU'
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
s.render.film_transparent = False
hidden = {}
for o in s.objects:
    if any(c.name.startswith('07 | Ceilings') for c in o.users_collection) or o.name.startswith('StairShell_Upper') or o.name == 'StairShell_Stairwell_Roof':
        hidden[o.name] = o.hide_render
        o.hide_render = True
s.camera = bpy.data.objects['Map_Camera_Top']
s.camera.data.type = 'ORTHO'
s.camera.data.ortho_scale = 58.5
s.render.resolution_x = 1200
s.render.resolution_y = 2100
s.render.filepath = str(OUT / 'corridor_double_width_top.png')
bpy.ops.render.render(write_still=True)
print('TOP_RENDER_DONE', flush=True)
for name, value in hidden.items():
    bpy.data.objects[name].hide_render = value
camera_data = bpy.data.cameras.new('Preview_Corridor_Double_Width')
camera = bpy.data.objects.new('Preview_Corridor_Double_Width', camera_data)
s.collection.objects.link(camera)
camera.location = (-6.15, -7.7, 1.65)
camera.rotation_euler = (Vector((-6.15, 14, 1.65)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.lens = 22
s.camera = camera
s.render.resolution_x = 1400
s.render.resolution_y = 900
s.cycles.samples = 32
s.render.filepath = str(OUT / 'corridor_double_width_eye_level.png')
bpy.ops.render.render(write_still=True)
print('ALL_PREVIEWS_DONE_NO_SCENE_VISIBILITY_CHANGED_ON_DISK', flush=True)
