"""Refit the existing teacher's uniform; retain her anatomy, hair and scale."""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path('D:/NetSim3D/3Dmodel')
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm_before_proportion_fix.blend'))
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
rig = bpy.data.objects['Teacher_Female_Rig']
asset = bpy.data.collections['TEACHER | female · 160 cm']

# The old male shirt was shortened but retained its full front/back depth.
# Refit all attached tailoring details with the same continuous mapping.
for obj in asset.objects:
    if obj.type != 'MESH' or not obj.name.startswith(('Uniform_Shirt', 'Uniform |')):
        continue
    if 'skirt' in obj.name:
        continue
    for v in obj.data.vertices:
        p = v.co
        neck_blend = max(0.0, min(1.0, (p.z - 1.27) / 0.13))
        neck_blend = neck_blend * neck_blend * (3.0 - 2.0 * neck_blend)
        if p.y < 0:
            # Keep adequate bust ease; reduce excess fabric at the waist.
            chest = math.exp(-((p.z - 1.22) / 0.11) ** 2)
            fitted = 0.73 + 0.13 * chest
        else:
            fitted = 0.62
            sleeve = min(1.0, max(0.0, (abs(p.x)-0.10)/0.08)) * min(1.0, max(0.0, (p.z-1.16)/0.08))
            fitted += (0.90-fitted) * sleeve
        p.y *= fitted + (1.0 - fitted) * neck_blend

# Rebuild a continuous waist-to-hip profile aligned with the actual belt.
skirt = bpy.data.objects['Uniform | tailored knee-length skirt']
specs = [
    (0.976, 0.140, 0.096), (0.960, 0.141, 0.097),
    (0.935, 0.151, 0.102), (0.890, 0.166, 0.109),
    (0.835, 0.176, 0.113), (0.780, 0.177, 0.112),
    (0.680, 0.180, 0.110), (0.585, 0.183, 0.108),
    (0.565, 0.184, 0.108),
]
n = 64
points = [(rx * math.cos(k * math.tau/n), -0.016 + (ry + max(0, (0.94-z)/0.375)*0.046 if math.sin(k*math.tau/n)<0 else ry) * math.sin(k * math.tau/n), z)
          for z, rx, ry in specs for k in range(n)]
faces = [(r*n+k, r*n+(k+1)%n, (r+1)*n+(k+1)%n, (r+1)*n+k)
         for r in range(len(specs)-1) for k in range(n)]
faces.append(tuple(reversed(range(n))))
mat = skirt.data.materials[0]
data = bpy.data.meshes.new('Refitted skirt | continuous waist and hip')
data.from_pydata(points, [], faces)
data.materials.append(mat)
data.update()
skirt.data = data
skirt.vertex_groups.clear()
for name in ('pelvis.L', 'pelvis.R', 'upperleg01.L', 'upperleg01.R'):
    skirt.vertex_groups.new(name=name)
for v in data.vertices:
    side = 'L' if v.co.x > 0 else 'R'
    weight = max(0.45, min(1.0, (v.co.z - 0.56) / 0.42))
    skirt.vertex_groups['pelvis.' + side].add([v.index], weight, 'REPLACE')
    skirt.vertex_groups['upperleg01.' + side].add([v.index], 1.0-weight, 'REPLACE')
for polygon in data.polygons:
    polygon.use_smooth = True

# The original body included hidden upper thighs. Trim just those disconnected
# leg islands under the opaque skirt; retain a straight overlap at the hem.
body = bpy.data.objects['Body | female head arms lower legs']
bm = bmesh.new()
bm.from_mesh(body.data)
remaining = set(bm.verts)
components = []
while remaining:
    seed = remaining.pop()
    component, stack = {seed}, [seed]
    while stack:
        for edge in stack.pop().link_edges:
            for vertex in edge.verts:
                if vertex in remaining:
                    remaining.remove(vertex)
                    component.add(vertex)
                    stack.append(vertex)
    components.append(component)
for component in components:
    if max(v.co.z for v in component) < 0.95 and min(v.co.z for v in component) < 0.3:
        edges = {e for v in component for e in v.link_edges}
        faces = {f for v in component for f in v.link_faces}
        bmesh.ops.bisect_plane(bm, geom=list(component)+list(edges)+list(faces),
            dist=0.00001, plane_co=(0, 0, 0.574), plane_no=(0, 0, 1), clear_outer=True)
bm.to_mesh(body.data)
bm.free()

bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
points = []
for obj in asset.objects:
    if obj.type == 'MESH':
        evaluated = obj.evaluated_get(dg)
        data = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ v.co for v in data.vertices)
        evaluated.to_mesh_clear()
height = max(p.z for p in points) - min(p.z for p in points)
assert abs(height - 1.60) < 0.001, height
rig['proportion_revision'] = 'Refitted front/back shirt depth; continuous belt-to-skirt profile, 2026-10-12'

camera = scene.camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 750
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100

def view(location, name):
    camera.location = location
    camera.rotation_euler = (Vector((0, 0, 0.81)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 1.83
    scene.render.filepath = str(ROOT / ('ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_' + name + '.png'))
    bpy.ops.render.render(write_still=True)

view((0, -6, 0.95), 'front_corrected')
view((6, 0, 0.95), 'side_corrected')
view((1.7, 5.3, 1.4), 'back')
view((2, -5.6, 1.5), 'preview')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm.blend'))
print('PROPORTIONS_FIXED height_m=', height, flush=True)
