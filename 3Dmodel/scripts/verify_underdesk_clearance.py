import bpy,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
B=Path('D:/NetSim3D/3Dmodel');P=B/'ใช้ร่วมกัน/blend/classroom_shell.blend';bpy.ops.wm.open_mainfile(filepath=str(P));s=bpy.context.scene
# The vertical supports belong at the front edge of the tray, clear of rear cable lanes.
fix=bpy.data.collections['16 | Underdesk mounts and open grommets']
for o in fix.objects:
 shift=.04 if o.name.startswith('Teacher') else -.16
 if 'tray mounting bracket' in o.name:o.location.y+=shift
 if 'underside mounting foot' in o.name:o.location.y+=shift
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
desks=['StudentDesk_Row01_Left','TeacherDesk'];issues=[]
for dn in desks:
 desk=bpy.data.objects[dn];tag='Teacher' if dn=='TeacherDesk' else 'Row01_Left'
 pcroots=[bpy.data.objects['TeacherComputerSet_Root']] if tag=='Teacher' else [o for o in s.objects if o.get('desk')==dn and o.type=='EMPTY' and 'TeacherComputerSet_Root' in o.name]
 candidates=[]
 for root in pcroots:
  candidates.extend(o for o in root.children_recursive if o.type=='MESH')
 candidates.extend(o for o in fix.objects if o.name.startswith(tag) and o.type=='MESH' and not any(t in o.name for t in ['grommet','retaining band','guide','floor supply cover']))
 caches=[]
 for o in candidates:
  bb=[o.matrix_world@Vector(p) for p in o.bound_box];lo=Vector([min(p[k] for p in bb) for k in range(3)]);hi=Vector([max(p[k] for p in bb) for k in range(3)]);caches.append((o,lo,hi,o.matrix_world.inverted()))
 cables=[o for o in s.objects if o.type=='CURVE' and o.get('desk')==dn]
 for cable in cables:
  ps=[Vector(p.co[:3]) for p in cable.data.splines[0].points];seen=set()
  for a,b in zip(ps,ps[1:]):
   seglo=Vector([min(a[k],b[k]) for k in range(3)]);seghi=Vector([max(a[k],b[k]) for k in range(3)])
   for ob,lo,hi,inv in caches:
    if ob.name in seen or any(seghi[k]<lo[k]-.001 or seglo[k]>hi[k]+.001 for k in range(3)):continue
    aa=inv@a;d=inv@b-aa;dist=d.length
    if dist<1e-7:continue
    hit,p,n,face=ob.ray_cast(aa,d/dist,distance=dist-.00001)
    if hit:issues.append({'cable':cable.name,'object':ob.name,'point':list(ob.matrix_world@p)});seen.add(ob.name)
print('DEVICE_AND_MOUNT_CLEARANCE',json.dumps(issues),flush=True)
assert not issues,'Device or mounting bracket intersects cable'
assert len([o for o in fix.objects if 'open cable grommet' in o.name])==21
strips=[o for o in s.objects if o.type=='EMPTY' and 'realistic 6-way strip | Connector' in o.name];assert len(strips)==11 and all(o.location.z<.60 for o in strips)
assert not any('LAN connection box' in o.name for o in s.objects)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(P),compress=True)
print('SAVED_AND_VALIDATED_21_GROMMETS_11_UNDERDESK_STRIPS',flush=True)
