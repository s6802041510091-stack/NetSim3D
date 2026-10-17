import bpy,json
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend')
for n in ['StudentDesk_Row01_Left','TeacherDesk']:
 o=bpy.data.objects[n];faces=[p for p in o.data.polygons if 'Black_Accent' in o.data.materials[p.material_index].name and min(o.data.vertices[i].co.z for i in p.vertices)>.74]
 ids=set(i for p in faces for i in p.vertices);adj={i:set() for i in ids}
 for p in faces:
  for i in p.vertices:adj[i].update(p.vertices)
 comps=[]
 while ids:
  todo=[ids.pop()];comp=set(todo)
  while todo:
   v=todo.pop()
   for j in adj[v]&ids:ids.remove(j);comp.add(j);todo.append(j)
  coords=[o.data.vertices[i].co for i in comp];lo=Vector([min(p[k] for p in coords) for k in range(3)]);hi=Vector([max(p[k] for p in coords) for k in range(3)]);center=(lo+hi)/2
  print(n,'COMPONENT','center local',list(center),'bounds',list(lo),list(hi),'world',list(o.matrix_world@center),'verts',len(comp))
 print('table meshdata',o.data.name,'users',o.data.users)
 for x,y in ([(-.55,.24),(.55,.24)] if n.startswith('Student') else [(-.45,.28),(.65,.28)]):
  print('test',x,y,o.ray_cast(Vector((x,y,1)),Vector((0,0,-1)))[:3])
