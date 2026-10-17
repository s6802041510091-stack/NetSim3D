import bpy,json
from mathutils import Vector
for name in ['classroom_shell','Map']:
 bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/'+name+'.blend')
 print('FILE',name,'OBJECTS',len(bpy.data.objects))
 for o in bpy.data.objects:
  if o.type=='MESH' and any(s in o.name.lower() for s in ['wall','corridor_south','window','classroom_floor']):
   pts=[o.matrix_world@Vector(p) for p in o.bound_box]
   print(o.name,[[round(fn(p[i] for p in pts),3) for i in range(3)] for fn in [min,max]])
