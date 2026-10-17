"""Refit arm joint pivots to the actual female anatomy, retaining the outfit."""
import bpy, json, math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path('D:/NetSim3D/3Dmodel')
SRC = ROOT / 'temp/teacher_male/source'
FEMALE = ROOT / 'temp/teacher_female/source'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm_before_arm_fix.blend'))
bpy.context.preferences.filepaths.save_version = 0
rig = bpy.data.objects['Teacher_Female_Rig']
asset = bpy.data.collections['TEACHER | female · 160 cm']
body = bpy.data.objects['Body | female head arms lower legs']
verts, body_indices = [], set()
group = ''
for line in (SRC/'base.obj').read_text().splitlines():
    t = line.split()
    if not t: continue
    if t[0]=='v': verts.append(Vector(tuple(map(float,t[1:4]))))
    elif t[0]=='g': group=t[1]
    elif t[0]=='f' and group=='body': body_indices.update(int(a.split('/')[0])-1 for a in t[1:])
for name, influence in [('asian-female-young.target',.9),('caucasian-female-young.target',.1),('universal-female-young-averagemuscle-averageweight.target',1.)]:
    for line in (FEMALE/name).read_text().splitlines():
        t=line.split()
        if t and t[0].isdigit(): verts[int(t[0])] += Vector(tuple(float(x)*influence for x in t[1:4]))
floor = min(verts[i].y for i in body_indices)
def co(p): return Vector((p.x*.105,-p.z*.105,(p.y-floor)*.105+.026))
definition=json.loads((SRC/'default.mhskel').read_text())
def joint(name): return co(sum((verts[i] for i in definition['joints'][name]),Vector())/len(definition['joints'][name]))
arm_names=set()
for side in ('L','R'):
    shoulder=rig.data.bones['shoulder01.'+side]
    arm_names.add(shoulder.name)
    arm_names.update(b.name for b in shoulder.children_recursive)

def deform_matrices():
    return {b.name:b.matrix @ b.bone.matrix_local.inverted() for b in rig.pose.bones}

def blend(obj,v,matrices):
    total=0.; result=Matrix(((0.,)*4,)*4)
    for entry in v.groups:
        name=obj.vertex_groups[entry.group].name
        if name in matrices:
            result += matrices[name]*entry.weight
            total += entry.weight
    return result*(1./total) if total>0.00001 else Matrix.Identity(4)

# Retain the posed coordinates of clothing, details and hair during refitting.
old=deform_matrices()
snapshots=[]
body_targets={v.index:blend(body,v,old) @ v.co for v in body.data.vertices
              if any(body.vertex_groups[g.group].name in arm_names for g in v.groups)}
for obj in asset.objects:
    if obj.type!='MESH' or obj==body: continue
    convert=rig.matrix_world.inverted() @ obj.matrix_world
    for v in obj.data.vertices:
        if any(obj.vertex_groups[g.group].name in arm_names for g in v.groups):
            snapshots.append((obj,v.index,blend(obj,v,old) @ (convert @ v.co)))

rig.hide_set(False)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name in arm_names:
    entry=definition['bones'][name]
    b=rig.data.edit_bones[name]
    b.head=joint(entry['head']); b.tail=joint(entry['tail']); b.roll=0
bpy.ops.object.mode_set(mode='OBJECT')
for name in arm_names:
    rig.pose.bones[name].rotation_quaternion=(1,0,0,0)
bpy.context.view_layer.update()
def rotate_world(name,axis,angle):
    b=rig.pose.bones[name]
    rest=(b.parent.matrix @ b.parent.bone.matrix_local.inverted() @ b.bone.matrix_local).to_3x3()
    b.rotation_quaternion=(rest.inverted() @ Matrix.Rotation(angle,3,Vector(axis)) @ rest).to_quaternion()
    bpy.context.view_layer.update()
for sign,side in [(1,'L'),(-1,'R')]:
    rotate_world('upperarm01.'+side,(0,1,0),sign*math.radians(25))
    rotate_world('lowerarm01.'+side,(1,0,0),math.radians(32))
new=deform_matrices()
for index,old_position in body_targets.items():
    v=body.data.vertices[index]
    skin_matrix=blend(body,v,new)
    corrected=skin_matrix @ v.co
    # Preserve the already fitted shoulder under the sleeve and blend smoothly
    # into the anatomically corrected elbow; forearms keep the new joint fit.
    t=max(0.,min(1.,(old_position.z-1.06)/.15))
    t=t*t*(3.-2.*t)
    v.co=skin_matrix.inverted() @ corrected.lerp(old_position,t)
for obj,index,target in snapshots:
    convert=rig.matrix_world.inverted() @ obj.matrix_world
    v=obj.data.vertices[index]
    v.co=convert.inverted() @ (blend(obj,v,new).inverted() @ target)
bpy.context.view_layer.update()
rig.hide_set(True)
rig['arm_revision']='Female-anatomy arm joint pivots; existing outfit preserved'
scene=bpy.context.scene
scene.cycles.samples=24
scene.render.resolution_x=750
scene.render.resolution_y=1000
camera=scene.camera
for loc,name in [((6,0,1.0),'side_corrected'),((0,-6,1.0),'front_corrected'),((2,-5.6,1.5),'preview')]:
    camera.location=loc
    camera.rotation_euler=(Vector((0,0,.81))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=1.83
    scene.render.filepath=str(ROOT/('ใช้ร่วมกัน/renders/teacher_female_khaki_160cm_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'ใช้ร่วมกัน/blend/teacher_female_khaki_160cm.blend'))
print('ARMS_REFITTED',len(arm_names),'bones',len(snapshots),'preserved outfit vertices',flush=True)
