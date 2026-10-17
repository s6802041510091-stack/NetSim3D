import bpy,json
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend')
for n in ['StudentDesk_Row01_Left','TeacherDesk']:
 d=bpy.data.objects[n];print('DESK',n,d.type,list(d.location),'verts',len(d.data.vertices))
 print('mats',[m.name for m in d.data.materials]);print('mods',[(m.name,m.type) for m in d.modifiers])
 for m in d.data.materials:
  if any(t in m.name.lower() for t in ['black','hole','grommet','rubber','dark']):
   pts=[d.matrix_world@d.data.vertices[i].co for p in d.data.polygons if d.data.materials[p.material_index]==m for i in p.vertices]
   print('DARK',m.name,'bounds',[[f(p[i] for p in pts) for i in range(3)] for f in [min,max]] if pts else [])
for o in bpy.data.objects:
 if any(t in o.name.lower() for t in ['grommet','cable_hole']):print('HOLE',o.name,list(o.matrix_world.translation),list(o.dimensions))
for c in bpy.data.collections:
 if c.name.startswith(('LAN |','POWER |','15 |','ROUTES |')):
  print('COL',c.name,len(c.objects))
  if c.name.startswith('LAN |'):print([o.name for o in c.objects])
for o in bpy.data.collections['15 | Realistic connected computer peripherals'].objects:
 if o.name.startswith('Teacher') and (o.type in ['CURVE','EMPTY']):
  print('TEACHER',o.name,list(o.matrix_world.translation),dict(o.items()))
