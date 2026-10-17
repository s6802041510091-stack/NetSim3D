import bpy
for file in ['realistic_computer_cable_kit','classroom_shell']:
 bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/'+file+'.blend')
 print('FILE',file)
 if file.startswith('realistic'):
  for c in bpy.data.collections:
   if c.name.startswith(('01 ','02 ','03 ','08 ')):
    print('COL',c.name)
    for o in c.objects:
     if o.type=='EMPTY':print(o.name,'parent',o.parent.name if o.parent else None,'kids',[ch.name for ch in o.children][:8])
 else:
  root=bpy.data.objects['TeacherComputerSet_Root']
  for o in root.children_recursive:
   if o.name.startswith(('Socket_','04_Mouse')):print(o.name,list(o.matrix_world.translation))
