import bpy
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend')
for o in bpy.data.objects:
 if o.name.startswith(('StudentDesk_Row','TeacherComputerSet','01_Case','02_Monitor','03_Keyboard','04_Mouse')):
  pts=[q.matrix_world@Vector(c) for q in ([o] if o.type=='MESH' else o.children_recursive) if q.type=='MESH' for c in q.bound_box]
  print(o.name,'LOC',list(o.location),'ROT',list(o.rotation_euler),'SCALE',list(o.scale),'PARENT',o.parent.name if o.parent else None,'BOUNDS',[[round(f(p[i] for p in pts),4) for i in range(3)] for f in [min,max]] if pts else [])
