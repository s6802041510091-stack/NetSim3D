import bpy,json
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/blend/students/student_female_bob_cut.blend')
r=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
for b in r.pose.bones:
    if any(s in b.name for s in ['upperarm','lowerarm','wrist','upperleg','lowerleg','foot','shoulder']):
        print(b.name,'head',tuple(round(c,4) for c in r.matrix_world@b.head),'tail',tuple(round(c,4) for c in r.matrix_world@b.tail),'rot',tuple(round(c,3) for c in b.rotation_quaternion))
body=bpy.data.objects['Body | female head arms lower legs']
ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
vs=[ev.matrix_world@v.co for v in me.vertices]
for z in [.15,.25,.35,.45,.53,.7,.8,.9,1.,1.1,1.2,1.3]:
    pts=[p for p in vs if abs(p.z-z)<.015 and p.x>(.18 if z>.65 else .03)]
    if pts:print('SLICE',z,[(round(min(p[i] for p in pts),4),round(max(p[i] for p in pts),4)) for i in range(3)])
