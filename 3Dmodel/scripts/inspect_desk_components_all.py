import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend')
for name in ['TeacherDesk','StudentDesk_Row01_Left']:
 o=bpy.data.objects[name];adj={v.index:set() for v in o.data.vertices};ids=set(adj)
 for e in o.data.edges:a,b=e.vertices;adj[a].add(b);adj[b].add(a)
 print(name)
 while ids:
  todo=[ids.pop()];group=set(todo)
  while todo:
   for j in adj[todo.pop()]&ids:ids.remove(j);group.add(j);todo.append(j)
  ps=[o.data.vertices[i].co for i in group];print([[round(fn(p[k] for p in ps),3) for k in range(3)] for fn in [min,max]])
