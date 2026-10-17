import bpy,math,json,shutil,datetime,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
B=Path('D:/NetSim3D/3Dmodel');P=B/'ใช้ร่วมกัน/blend/classroom_shell.blend';KIT=B/'ใช้ร่วมกัน/blend/realistic_computer_cable_kit.blend'
kit_hash=hashlib.sha256(KIT.read_bytes()).hexdigest()
backup=P.with_name('classroom_shell_before_realistic_connections_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend');shutil.copy2(P,backup)
bpy.ops.wm.open_mainfile(filepath=str(P));bpy.context.preferences.filepaths.save_version=0;s=bpy.context.scene
assert not bpy.data.collections.get('15 | Realistic connected computer peripherals')
names=['01 AC power cord 1.8m','02 Wired USB mouse 1.5m','03 HDMI Type A 1.5m','08 Power strip 6 outlets 3m']
with bpy.data.libraries.load(str(KIT),link=False) as (src,dst):dst.collections=names
templates=dst.collections
def template(i,needle):return next(o for o in templates[i].objects if o.type=='EMPTY' and any(ch.name.startswith(needle) for ch in o.children))
AC=template(0,'Grounded mains plug grip');C13=template(0,'IEC C13 female');MOUSE=template(1,'Wired mouse body');USB=template(1,'USB A overmould');HDMI=template(2,'HDMI overmould');STRIP=template(3,'6-outlet extension housing')
rubber=next(o.data.materials[0] for o in templates[0].objects if o.name.startswith('Cable |'));pale=next(o.data.materials[0] for o in templates[1].objects if o.name.startswith('Cable |'))
col=bpy.data.collections.new('15 | Realistic connected computer peripherals');s.collection.children.link(col)
def clone(src,name):
 copies={}
 for o in [src]+list(src.children_recursive):
  n=o.copy();n.name=name+' | '+o.name;col.objects.link(n);copies[o]=n
 for o,n in copies.items():n.parent=copies.get(o.parent);n.matrix_parent_inverse=o.matrix_parent_inverse.copy()
 root=copies[src];root.parent=None;root.matrix_parent_inverse=Matrix.Identity(4);root.location=(0,0,0);root.rotation_euler=(0,0,0);return root
def orient(o,pos,forward,up):
 yy=Vector(forward).normalized();zz=Vector(up).normalized();xx=yy.cross(zz).normalized();zz=xx.cross(yy).normalized()
 o.location=pos;o.rotation_euler=Matrix((xx,yy,zz)).transposed().to_euler()
def port(root,needle):return next(o for o in root.children_recursive if needle in o.name and o.type=='EMPTY')
records=[]
def connector(src,anchor,depth,name):
 p=anchor.matrix_world.translation.copy();out=(anchor.matrix_world.to_3x3()@Vector((0,0,1))).normalized();up=(anchor.matrix_world.to_3x3()@Vector((0,1,0))).normalized()
 o=clone(src,name);orient(o,p+out*depth,-out,up);anchor['occupied']=True;anchor['connected_object']=o.name;o['socket']=anchor.name
 records.append({'connector':o.name,'socket':anchor.name,'offset_m':depth})
 return o,Vector(o.location),out
def plug(pos,up,name):
 o=clone(AC,name);orient(o,Vector(pos)+Vector((0,0,.064)),(0,0,-1),up)
 for child in o.children:
  if child.name.split(' | ')[-1].startswith('Mains flat metal pin'):
   child.location.x=math.copysign(.010,child.location.x);child.location.z=.007
  if 'Round earth pin' in child.name:child.location.z=-.013
 return o,Vector(o.location)
def curve(name,points,r,ma,nominal=None):
 # Clamped smooth sampled path; terminal points are exactly the connector cable entries.
 ps=[Vector(p) for p in points];out=[]
 for i in range(len(ps)-1):
  p0=ps[max(0,i-1)];p1=ps[i];p2=ps[i+1];p3=ps[min(len(ps)-1,i+2)]
  for j in range(24):
   t=j/24;out.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
 out.append(ps[-1]);d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=r;d.bevel_resolution=2;d.use_fill_caps=True;sp=d.splines.new('POLY');sp.points.add(len(out)-1)
 for q,p in zip(sp.points,out):q.co=(*p,1)
 ob=bpy.data.objects.new(name,d);col.objects.link(ob);d.materials.append(ma);ob['routed_length_m']=sum((b-a).length for a,b in zip(out,out[1:]));ob['nominal_asset_length_m']=nominal or ob['routed_length_m'];return ob
def slack(name,a,b,normal_a,normal_b,back,r,ma,length):
 # Bow behind the desk with a service loop. Solve its length without scaling the jacket.
 a,b=Vector(a),Vector(b);na,nb=Vector(normal_a),Vector(normal_b)
 def points(dip):
  middle=(a+b)*.5;middle.y=back;middle.z=min(a.z,b.z)-dip
  return [a,a+na*.035,Vector((a.x,back,a.z-.035)),middle,Vector((b.x,back,b.z-.035)),b+nb*.035,b]
 def measure(ps):
  total=0;last=None
  for i in range(len(ps)-1):
   p0=ps[max(0,i-1)];p1=ps[i];p2=ps[i+1];p3=ps[min(len(ps)-1,i+2)]
   for j in range(24):
    t=j/24;p=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
    if last is not None:total+=(p-last).length
    last=p
  return total+(ps[-1]-last).length
 lo,hi=.015,min(a.z,b.z)-.045
 if measure(points(lo))>length:raise RuntimeError(name+' route exceeds available length')
 for _ in range(30):
  mid=(lo+hi)/2
  if measure(points(mid))<length:lo=mid
  else:hi=mid
 ob=curve(name,points((lo+hi)/2),r,ma,length);assert abs(ob['routed_length_m']-length)<.005,(name,ob['routed_length_m']);return ob
# Retain architecture, all empty LAN raceways, adapters and their DC leads, wall outlets.
old=bpy.data.collections['POWER | outlets strips and cables'];remove=[]
keep_terms=['wall outlet','outlet slot','ground aperture','monitor AC DC adapter','monitor DC lead','DC barrel connector']
for o in list(old.objects):
 if not any(t in o.name for t in keep_terms):remove.append(o)
for o in remove:bpy.data.objects.remove(o,do_unlink=True)
roots=[o for o in s.objects if o.name.startswith('StudentPC_') and o.name.endswith('__TeacherComputerSet_Root')]+[bpy.data.objects['TeacherComputerSet_Root']]
assert len(roots)==21
desklist=sorted([o for o in s.objects if o.name.startswith('StudentDesk_Row')],key=lambda o:o.name)+[bpy.data.objects['TeacherDesk']]
strips=[];cablecount=0
for desk in desklist:
 teacher=desk.name=='TeacherDesk';sign=-1 if teacher else 1;x,y=desk.location.x,desk.location.y;back=y+sign*.29;tag='Teacher' if teacher else desk.name.removeprefix('StudentDesk_');far=y+sign*.46
 selected=[roots[-1]] if teacher else sorted([o for o in roots[:-1] if o.get('desk')==desk.name],key=lambda o:o['seat'])
 st=clone(STRIP,tag+' realistic 6-way strip');st.location=(x-.2915,back,.7675);st.rotation_euler.z=-math.pi/2;st['source_asset']='6-outlet kit strip';strips.append(st)
 # Compute fixture transforms explicitly to avoid global dependency updates per copy.
 rot=st.rotation_euler.to_matrix();smat=Matrix.Translation(st.location)@rot.to_4x4()
 slots=[smat@Vector((-.009,.067+i*.077,.021)) for i in range(6)]
 for k,root in enumerate(selected):
  ident=tag+f' PC{k+1}'
  c13,ca,na=connector(C13,port(root,'Socket_AC_Power_Inlet'),.060,ident+' IEC C13')
  ap,cb=plug(slots[k*2],rot@Vector((0,1,0)),ident+' AC mains plug')
  slack(ident+' AC power cord 1.8m',ca,cb,na,Vector((0,0,1)),far,.0034,rubber,1.8)
  # Retained monitor power adapter: replace its old mains lead, not its DC output.
  adapter=bpy.data.objects[tag+f' monitor AC DC adapter {k}']
  mp,mb=plug(slots[k*2+1],rot@Vector((0,1,0)),ident+' monitor mains plug')
  a=adapter.location-Vector((.05,0,0))
  curve(ident+' monitor adapter mains cable',[a,a+Vector((-.04,0,0)),Vector((a.x,back,.81)),mb+Vector((0,0,.025)),mb],.0028,rubber)
  h1,a,oa=connector(HDMI,port(root,'Socket_Rear_HDMI'),.054,ident+' HDMI at computer')
  h2,b,ob=connector(HDMI,port(root,'Socket_Monitor_HDMI'),.054,ident+' HDMI at monitor')
  slack(ident+' HDMI 1.5m',a,b,oa,ob,far+sign*.035,.003,rubber,1.5)
  # Replace original wireless mouse with the pale blue wired kit mouse at the same footprint.
  oldmouse=next(o for o in root.children if o.name.endswith('04_Mouse'))
  oldpos=oldmouse.matrix_world.translation.copy();rz=root.rotation_euler.z
  mouse=clone(MOUSE,ident+' wired mouse');mouse.rotation_euler.z=rz+math.pi
  mr=mouse.rotation_euler.to_matrix();mouse.location=oldpos+Vector((0,0,.0135))-mr@Vector((0,.071,0))
  for o in list(oldmouse.children_recursive)+[oldmouse]:bpy.data.objects.remove(o,do_unlink=True)
  u,ub,uo=connector(USB,port(root,'Socket_Rear_USB_A4'),.043,ident+' mouse USB A')
  ma=Vector(mouse.location);mf=mr@Vector((0,-1,0));
  # Route around the outer edge of each workstation, clear of the keys.
  side_x=root.location.x+(.33 if not teacher else -.33)
  curve(ident+' mouse USB cable',[ma,ma+mf*.05,Vector((side_x,y,.77)),Vector((side_x,far,.79)),ub+uo*.06,ub],.00155,pale,1.5)
 # Strip supply follows the existing side floor cover; no centre-aisle crossing.
 side=1 if x>0 else -1;wx=side*5.96;outer=x+side*(.8 if teacher else 1.10)
 wall=bpy.data.objects[tag+' wall outlet'];wp=Vector((wx-side*.019,back,.28))
 supply=clone(AC,tag+' grounded wall plug');direction=Vector((side,0,0));orient(supply,wp-direction*.065,direction,(0,0,1))
 entry=Vector(st.location);floor_y=back
 curve(tag+' strip supply cord routed',[entry,entry+Vector((-.045,0,0)),Vector((outer,back,.69)),Vector((outer,back,.035)),Vector((wx-side*.10,floor_y,.035)),Vector((wx-side*.10,back,.20)),Vector(supply.location)],.0035,rubber,5 if not teacher else 3)
 print('CONNECTED',tag,flush=True)
# Remove the unlinked template objects/collections after copies have been made. Meshes are shared locally.
for c in templates:
 for o in list(c.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(c)
bpy.context.view_layer.update()
assert len(strips)==11
assert len([o for o in col.objects if 'HDMI at computer | Connector' in o.name])==21
assert all(not o.get('occupied',False) for o in s.objects if 'Socket_LAN_RJ45' in o.name)
assert hashlib.sha256(KIT.read_bytes()).hexdigest()==kit_hash
col['status']='21 complete power / HDMI / wired mouse connections. Monitor DC adapters retained. No LAN cables. Geometry only; no game logic.'
col['routing_note']='C13 cords measured 1.8m and HDMI measured 1.5m. Other supply/mouse cable routes fitted to desk layout; see routed_length_m.'
bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.save_as_mainfile(filepath=str(P),compress=True)
(B/'temp/realistic_classroom_connections.json').write_text(json.dumps({'backup':str(backup),'computer_sets':21,'strips':11,'connections':records,'source_kit_sha256':kit_hash},indent=2))
print('SAVED_CONNECTED_CLASSROOM',flush=True)
d=bpy.data.cameras.new('Connected desk preview');cam=bpy.data.objects.new('Connected desk preview',d);s.collection.objects.link(cam);s.camera=cam;cam.location=(4.9,.15,2.2);target=Vector((2.7,-1.1,.76));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();d.lens=35
s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True;s.render.resolution_x=1500;s.render.resolution_y=1100;s.render.resolution_percentage=100;s.render.filepath=str(B/'ใช้ร่วมกัน/renders/classroom_realistic_connections.png');bpy.ops.render.render(write_still=True)
print('DONE',flush=True)
