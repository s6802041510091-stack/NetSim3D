import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/NetSim3D/3Dmodel')
sys.path.insert(0,str(ROOT/'scripts'))
from rebuild_student_hair_and_arms import anatomy
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blend/cleaner_female_apron_160cm.blend'))
r=bpy.data.objects['Cleaner_Female_Rig'];body=bpy.data.objects['Body | female head arms lower legs']
vs,uv,fs,groups,co=anatomy('female');byuv={}
for f,g in zip(fs,groups):
    if g=='body':
        for i,ui in f:byuv[tuple(round(x,6) for x in uv[ui])]=i
original={}
for loop in body.data.loops:
    key=tuple(round(x,6) for x in body.data.uv_layers.active.data[loop.index].uv)
    if key in byuv:original[loop.vertex_index]=co(vs[byuv[key]])
arm_names={b.name for b in r.data.bones['upperarm01.L'].children_recursive}|{'upperarm01.L'}
matrices={b.name:r.matrix_world@b.matrix@b.bone.matrix_local.inverted() for b in r.pose.bones}
current=[];source=[];deltas=[]
for v in body.data.vertices:
    weight=sum(g.weight for g in v.groups if body.vertex_groups[g.group].name in arm_names)
    if weight<.5 or v.index not in original:continue
    transform=Matrix(((0.,)*4,)*4);total=0
    for g in v.groups:
        n=body.vertex_groups[g.group].name
        if n in matrices:transform+=matrices[n]*g.weight;total+=g.weight
    transform*=1/total
    p=transform@v.co;q=transform@original[v.index]
    current.append(p);source.append(q);deltas.append((p.z,(p-q).length))
for label,points in [('CURRENT',current),('SOURCE',source)]:
    for j in range(40):
        z=.82+j*.01;sl=[p for p in points if abs(p.z-z)<.012]
        if len(sl)<4:continue
        mm=[(min(p[i] for p in sl),max(p[i] for p in sl)) for i in range(2)]
        print(label,'SLICE',round(z,3), 'centre',tuple(round((a+b)/2,4) for a,b in mm),'radius',tuple(round((b-a)/2,4) for a,b in mm))
print('REST_DIFF',[(round(z,3),round(max((d for zz,d in deltas if abs(zz-z)<.02),default=0),4)) for z in [.85,.9,.95,1,1.05,1.1,1.15,1.2]])
# Preview an undistorted source arm with the current pose, no source file writes.
for v in body.data.vertices:
    w=sum(g.weight for g in v.groups if body.vertex_groups[g.group].name.startswith(('upperarm','lowerarm','wrist','finger','thumb')))
    if w>.50 and v.index in original:v.co=original[v.index]
scene=bpy.context.scene;scene.cycles.samples=20;scene.cycles.use_denoising=True
scene.render.resolution_x=850;scene.render.resolution_y=950
cam=scene.camera;cam.location=(0,-6,1.05);cam.rotation_euler=(Vector((0,0,1.02))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.87
scene.render.filepath=str(ROOT/'renders/cleaner/diagnostic_source_arms.png');bpy.ops.render.render(write_still=True)
