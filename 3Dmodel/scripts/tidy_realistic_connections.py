import bpy,math
from pathlib import Path
from mathutils import Vector
B=Path('D:/NetSim3D/3Dmodel');P=B/'ใช้ร่วมกัน/blend/classroom_shell.blend';bpy.ops.wm.open_mainfile(filepath=str(P));s=bpy.context.scene;c=bpy.data.collections['15 | Realistic connected computer peripherals']
def smooth(ps):
 out=[]
 for i in range(len(ps)-1):
  p0=ps[max(0,i-1)];p1=ps[i];p2=ps[i+1];p3=ps[min(len(ps)-1,i+2)]
  for j in range(10):
   t=j/10;out.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
 return out+[ps[-1]]
count=0
for ob in c.objects:
 if ob.type!='CURVE' or not ('AC power cord 1.8m' in ob.name or 'HDMI 1.5m' in ob.name):continue
 old=[Vector(p.co[:3]) for p in ob.data.splines[0].points];a,b=old[0],old[-1];na=(old[1]-a).normalized();nb=(old[-2]-b).normalized();length=ob['nominal_asset_length_m'];far=old[len(old)//2].y
 desk=bpy.data.objects['TeacherDesk'] if ob.name.startswith('Teacher ') else bpy.data.objects['StudentDesk_'+ob.name.split(' PC')[0]]
 far=desk.location.y+(-.425 if ob.name.startswith('Teacher ') else .425)
 center=(a+b)/2;center.y=far;center.z=min(a.z,b.z)-.10
 def make(r):
  ps=[a,a+na*.04,Vector((a.x,far,center.z+.05))]
  for i in range(49):
   t=math.tau*i/48;ps.append(center+Vector((-r*math.cos(t),.010*i/48,r*math.sin(t))))
  ps.extend([Vector((b.x,far+.01,center.z+.05)),b+nb*.04,b]);return smooth(ps)
 def size(ps):return sum((v-u).length for u,v in zip(ps,ps[1:]))
 lo,hi=.008,.24
 if size(make(lo))>length:
  center.z=min(a.z,b.z)-.025
 assert size(make(lo))<length,(ob.name,size(make(lo)))
 for _ in range(32):
  mid=(lo+hi)/2
  if size(make(mid))<length:lo=mid
  else:hi=mid
 pts=make((lo+hi)/2);ob.data.splines.clear();sp=ob.data.splines.new('POLY');sp.points.add(len(pts)-1)
 for q,p in zip(sp.points,pts):q.co=(*p,1)
 ob['routed_length_m']=size(pts);ob['routing']='Service loop behind desk, ends fixed in sockets';assert abs(size(pts)-length)<.001;assert min(p.z for p in pts)>.35;count+=1
assert count==42
# Verify all connection tips against their intended socket markers.
linked=[o for o in c.objects if o.type=='EMPTY' and o.get('socket')];assert len(linked)==84
for o in linked:assert bpy.data.objects[o['socket']].get('occupied')
assert len([o for o in c.objects if 'wired mouse | Connector' in o.name])==21
assert len([o for o in c.objects if 'realistic 6-way strip | Connector' in o.name])==11
assert all(not o.get('occupied',False) for o in s.objects if 'Socket_LAN_RJ45' in o.name)
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(P),compress=True)
print('VALIDATED: 21 PCs, 21 HDMI links, 21 wired mice, 11 strips, 42 measured service loops; LAN unconnected',flush=True)
d=bpy.data.cameras.new('Connected desk preview');cam=bpy.data.objects.new('Connected desk preview',d);s.collection.objects.link(cam);s.camera=cam;cam.location=(4.9,.15,2.2);target=Vector((2.7,-1.1,.76));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();d.lens=35
s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True;s.render.resolution_x=1500;s.render.resolution_y=1100;s.render.resolution_percentage=100;s.render.filepath=str(B/'ใช้ร่วมกัน/renders/classroom_realistic_connections.png');bpy.ops.render.render(write_still=True)
