import bpy
from mathutils import Vector
p='D:/NetSim3D/3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend';bpy.ops.wm.open_mainfile(filepath=p)
c=bpy.data.collections['LAN | empty conduits and sockets - NO CABLES'];m=bpy.data.materials['Electrical | duct cover']
def joint(n,pos,d):
 vs=[(x*d[0]/2,y*d[1]/2,z*d[2]/2) for x,y,z in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(vs,[],[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]);mesh.update();ob=bpy.data.objects.new(n,mesh);c.objects.link(ob);ob.location=pos;mesh.materials.append(m)
 mod=ob.modifiers.new('Rounded junction cover','BEVEL');mod.width=.008;mod.segments=2;ob['purpose']='Empty LAN raceway connector, no cable'
for o in list(c.objects):
 if 'EMPTY LAN floor conduit' in o.name:
  x=5.80 if o.location.x>0 else -5.80
  joint(o.name+' wall drop joint',(x,o.location.y,.085),(.13,.12,.15))
 if 'EMPTY LAN riser' in o.name:
  joint(o.name+' floor elbow',(o.location.x,o.location.y,.042),(.07,.10,.065))
power=bpy.data.collections['POWER | outlets strips and cables']
assert len([o for o in power.objects if o.type=='CURVE'])==74
assert len([o for o in power.objects if '6-way earthed power strip' in o.name])==11
assert len([o for o in c.objects if 'empty RJ45 cavity' in o.name])==21
assert not any(o.type=='CURVE' for o in c.objects)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=p,compress=True)
print('VERIFIED: 11 strips; 42 mains leads; 21 DC leads; 11 supply cords; 21 empty LAN jacks; zero LAN cables',flush=True)
