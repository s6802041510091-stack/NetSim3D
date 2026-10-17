import bpy,json
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/realistic_computer_cable_kit.blend')
pads=[o for o in bpy.data.objects if o.name.startswith('Recessed socket face')];assert len(pads)==30
dg=bpy.context.evaluated_depsgraph_get()
for o in pads:
 ev=o.evaluated_get(dg)
 for x,y in [(-.010,.007),(.010,.007),(0,-.013)]:
  hit=ev.ray_cast(Vector((x,y,.03)),Vector((0,0,-1)),distance=.06)[0]
  assert not hit,(o.name,x,y,'blocked socket')
curves=[o for o in bpy.data.objects if o.name.startswith('Cable | continuous jacket')];assert len(curves)==9
for o in curves:
 pts=[Vector(p.co[:3]) for p in o.data.splines[0].points];length=sum((b-a).length for a,b in zip(pts,pts[1:]));assert abs(length-o['centerline_length_m'])<.00001
print('VERIFIED: 30 three-hole outlet faces, 90 open apertures; 9 measured continuous cables; file reopened',flush=True)
