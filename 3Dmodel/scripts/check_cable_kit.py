import bpy
bpy.ops.wm.open_mainfile(filepath='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/realistic_computer_cable_kit.blend')
for n in ['Recessed socket face','Deep socket insert','4-outlet extension housing','IEC C13 female moulded housing']:
 o=bpy.data.objects[n];print(n,len(o.data.vertices),list(o.location),[(m.name,m.type) for m in o.modifiers])
 print('bounds',list(o.dimensions))
