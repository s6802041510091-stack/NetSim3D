"""Repair the existing female teacher; keep her original anatomy, outfit and rig.

Runs from the dated backup so repeated refinement never accumulates deformation.
After running this script, run rebuild_teacher_female_feet.py. It supersedes
the ankle taper below and the subsequent, rejected collar-compression attempt.
"""
import json
import math
import shutil
from collections import defaultdict, Counter
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector, Matrix

ROOT = Path('D:/NetSim3D/3Dmodel')
OUTPUT = ROOT / 'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm.blend'
BACKUP = ROOT / 'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm_before_limb_repair_20261109.blend'
if not BACKUP.exists():
    raise SystemExit('Historical input removed after approval. Use the approved teacher_female_khaki_160cm.blend; do not recreate this old snapshot from it.')
bpy.ops.wm.open_mainfile(filepath=str(BACKUP))
bpy.context.preferences.filepaths.save_version = 0
rig = bpy.data.objects['Teacher_Female_Rig']
body = bpy.data.objects['Body | female head arms lower legs']
asset = bpy.data.collections['TEACHER | female · 160 cm']
source = ROOT / 'temp/teacher_male/source'
female = ROOT / 'temp/teacher_female/source'
verts, uvs, faces, groups = [], [], [], []
group = ''
for line in (source / 'base.obj').read_text().splitlines():
    t = line.split()
    if not t: continue
    if t[0] == 'v': verts.append(Vector(tuple(map(float, t[1:4]))))
    elif t[0] == 'vt': uvs.append(tuple(map(float, t[1:3])))
    elif t[0] == 'g': group = t[1]
    elif t[0] == 'f':
        faces.append([(int(a.split('/')[0])-1, int(a.split('/')[1])-1) for a in t[1:]])
        groups.append(group)
for filename, influence in [('asian-female-young.target', .9), ('caucasian-female-young.target', .1), ('universal-female-young-averagemuscle-averageweight.target', 1.)]:
    for line in (female / filename).read_text().splitlines():
        t = line.split()
        if t and t[0].isdigit(): verts[int(t[0])] += Vector(tuple(float(x)*influence for x in t[1:4]))
floor = min(verts[i].y for f,g in zip(faces,groups) if g == 'body' for i,_ in f)
def co(p): return Vector((p.x*.105, -p.z*.105, (p.y-floor)*.105+.026))
weights = defaultdict(dict)
for bone, items in json.loads((source/'default_weights.mhw').read_text())['weights'].items():
    for index, weight in items: weights[index][bone] = weight
arm_names = set()
for side in ('L','R'):
    shoulder = rig.data.bones['shoulder01.'+side]
    arm_names.add(shoulder.name)
    arm_names.update(b.name for b in shoulder.children_recursive)
def matrices(): return {b.name:b.matrix @ b.bone.matrix_local.inverted() for b in rig.pose.bones}
def skin_matrix(obj, v, mats):
    total=0.; result=Matrix(((0.,)*4,)*4)
    for item in v.groups:
        name=obj.vertex_groups[item.group].name
        if name in mats:
            result += mats[name]*item.weight; total += item.weight
    return result*(1./total) if total>1e-8 else Matrix.Identity(4)

# Preserve the tailored garment's current posed surface while correcting arms.
old=matrices()
garment=[]
for obj in asset.objects:
    if obj.type!='MESH' or obj==body: continue
    for v in obj.data.vertices:
        if any(obj.vertex_groups[w.group].name in arm_names for w in v.groups):
            garment.append((obj,v.index,skin_matrix(obj,v,old) @ v.co))

# Recover source vertex identities through unchanged UVs, including seam splits.
def uvkey(p): return tuple(round(x,6) for x in p)
uv_sources=defaultdict(set)
for f,g in zip(faces,groups):
    if g=='body':
        for i,u in f: uv_sources[uvkey(uvs[u])].add(i)
votes=defaultdict(Counter)
for loop in body.data.loops:
    for i in uv_sources[uvkey(body.data.uv_layers.active.data[loop.index].uv)]:
        votes[loop.vertex_index][i]+=1
restored=0
for v in body.data.vertices:
    if any(body.vertex_groups[w.group].name in arm_names for w in v.groups):
        assert votes[v.index], ('Unmapped arm vertex',v.index)
        source_index=votes[v.index].most_common(1)[0][0]
        v.co=co(verts[source_index]); restored+=1

# Keep the upper-arm presentation angle; align forearms to a gentle forward bend.
# Rotation difference avoids adding a world-X bend to an already bent rest elbow.
for side in ('L','R'):
    lower=rig.pose.bones['lowerarm01.'+side]
    lower.rotation_quaternion=(1,0,0,0)
    bpy.context.view_layer.update()
    upper=rig.pose.bones['upperarm01.'+side]
    elbow=lower.head.copy()
    wrist=rig.pose.bones['lowerarm02.'+side].tail.copy()
    upper_direction=(elbow-upper.head).normalized()
    target=(upper_direction+Vector((0,-.14,0))).normalized()
    delta=(wrist-elbow).normalized().rotation_difference(target).to_matrix()
    rest=(lower.parent.matrix @ lower.parent.bone.matrix_local.inverted() @ lower.bone.matrix_local).to_3x3()
    lower.rotation_quaternion=(rest.inverted() @ delta @ rest).to_quaternion()
    bpy.context.view_layer.update()
new=matrices()
for obj,index,target in garment:
    obj.data.vertices[index].co=skin_matrix(obj,obj.data.vertices[index],new).inverted() @ target

# Remove only skin hidden inside the tailored short sleeves. Keeping the old
# shoulder warp would distort the visible elbow again; exposed arms stay native.
posed={v.index:skin_matrix(body,v,new) @ v.co for v in body.data.vertices}
arm_vertices={v.index for v in body.data.vertices if any(body.vertex_groups[w.group].name in arm_names and w.weight>.01 for w in v.groups)}
bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table()
hidden=[f for f in bm.faces if any(v.index in arm_vertices for v in f.verts) and min(abs(posed[v.index].x) for v in f.verts)>.09 and min(posed[v.index].z for v in f.verts)>1.195]
bmesh.ops.delete(bm,geom=hidden,context='FACES')
bm.to_mesh(body.data);bm.free()

# A small inset beneath each sleeve hem keeps the skin from grazing its outer
# edge after subdivision. The visible elbow and forearm are not modified.
for v in body.data.vertices:
    if not any(body.vertex_groups[w.group].name in arm_names and w.weight>.01 for w in v.groups): continue
    transform=skin_matrix(body,v,new)
    p=transform @ v.co
    if p.z<1.175 or abs(p.x)<.11: continue
    side='L' if p.x>0 else 'R'
    shoulder=rig.pose.bones['upperarm01.'+side].head
    elbow=rig.pose.bones['lowerarm01.'+side].head
    center=shoulder.lerp(elbow,(p.z-shoulder.z)/(elbow.z-shoulder.z))
    t=max(0.,min(1.,(p.z-1.175)/.025));t=t*t*(3-2*t)
    p.x=center.x+(p.x-center.x)*(1-.22*t)
    p.y=center.y+(p.y-center.y)*(1-.22*t)
    v.co=transform.inverted() @ p

# Remove the actual dark hosiery polygons, not merely their material/visibility.
shoe=bpy.data.objects['Shoes | black Oxford with socks']
bm=bmesh.new();bm.from_mesh(shoe.data)
black=[f for f in bm.faces if f.material_index==1]
removed=len(black)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=(0,0,.113),plane_no=(0,0,1),clear_outer=True)
for f in bm.faces: f.material_index=0
bm.to_mesh(shoe.data);bm.free()

# Restore continuous original lower-leg anatomy down inside the retained shoes.
# The old body stopped at 14.5 cm, which would leave a hole after removing socks.
bm=bmesh.new();bm.from_mesh(body.data)
old_leg=[v for v in bm.verts if v.co.z<.60]
bmesh.ops.delete(bm,geom=old_leg,context='VERTS')
bm.to_mesh(body.data);bm.free()
leg_faces=[]
for f,g in zip(faces,groups):
    if g!='body': continue
    points=[co(verts[i]) for i,_ in f]
    z=sum(p.z for p in points)/len(points)
    if .07<z<.59: leg_faces.append(f)
ids=sorted({i for f in leg_faces for i,_ in f});lookup={i:j for j,i in enumerate(ids)}
mesh=bpy.data.meshes.new('Original female lower legs through shoe collar')
mesh.from_pydata([co(verts[i]) for i in ids],[],[[lookup[i] for i,_ in f] for f in leg_faces]);mesh.update()
# Only the hidden portion inside the shoe is tapered; retain the visible ankle.
for v in mesh.vertices:
    t=max(0.,min(1.,(.145-v.co.z)/.055));t=t*t*(3-2*t)
    v.co.y=v.co.y*(1-t)+(-.018+(v.co.y+.018)*.35)*t
    center=.165 if v.co.x>0 else -.165
    v.co.x=v.co.x*(1-t)+(center+(v.co.x-center)*.75)*t
legs=bpy.data.objects.new('Restored ankles',mesh);asset.objects.link(legs)
legs.matrix_world=body.matrix_world.copy()
mesh.materials.append(body.data.materials[0])
layer=mesh.uv_layers.new(name=body.data.uv_layers.active.name)
for polygon,f in zip(mesh.polygons,leg_faces):
    polygon.use_smooth=True
    for loop,(_,uv) in zip(polygon.loop_indices,f):layer.data[loop].uv=uvs[uv]
for i,src in enumerate(ids):
    for name,weight in weights[src].items():
        vg=legs.vertex_groups.get(name) or legs.vertex_groups.new(name=name)
        vg.add([i],weight,'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
body.hide_set(False);body.select_set(True);legs.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.join()
for mod in body.modifiers:
    if mod.type=='ARMATURE':mod.use_deform_preserve_volume=True
rig['arm_revision']='Original female rest anatomy restored; neutral forearm bend; no baked shoulder warp, 2026-11-09'
rig['ankle_revision']='Removed dark hosiery geometry; restored original skin through shoe collar, 2026-11-09'
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get()
points=[]
for obj in asset.objects:
    if obj.type!='MESH': continue
    evaluated=obj.evaluated_get(dg);data=evaluated.to_mesh()
    points.extend(evaluated.matrix_world @ v.co for v in data.vertices)
    evaluated.to_mesh_clear()
height=max(p.z for p in points)-min(p.z for p in points)
assert abs(height-1.60)<.001, height
assert all(p.material_index==0 for p in shoe.data.polygons)
assert max(v.co.z for v in shoe.data.vertices)<.11301
angles={}
for side in ('L','R'):
    upper=rig.pose.bones['upperarm01.'+side]
    elbow=rig.pose.bones['lowerarm01.'+side].head
    wrist=rig.pose.bones['lowerarm02.'+side].tail
    angles[side]=math.degrees((elbow-upper.head).angle(wrist-elbow))
    assert 5<angles[side]<12, angles
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
cam=scene.camera
def render(name,loc,target,scale,x=900,y=700):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.resolution_x=x;scene.render.resolution_y=y
    scene.render.filepath=str(ROOT/('ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
render('arms_repaired',(1,-4,1.2),(0,0,1.13),1.03)
render('ankles_repaired',(1,-3,.55),(0,-.02,.17),.65)
render('side_repaired',(5,-.7,1.2),(0,0,1.05),1.1)
render('arms_low_angle',(.8,-1.6,.35),(0,0,1.18),1.0)
render('front_corrected',(0,-6,1),(0,0,.81),1.83,750,1000)
render('side_corrected',(6,0,1),(0,0,.81),1.83,750,1000)
render('preview',(2,-5.6,1.5),(0,0,.81),1.83,750,1000)
rig.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
report={'arm_vertices_restored':restored,'original_dark_sock_faces':removed,'ankle_vertices':len(ids),'height_m':height,'elbow_bend_degrees':angles,'backup':str(BACKUP)}
(ROOT/'ใช้ร่วมกัน/renders/teacher_female_limb_repair.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('LIMB_REPAIR',json.dumps(report),flush=True)
