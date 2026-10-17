"""Rebuild desk cable management around real grommet holes; never move the PCs."""
import bpy,bmesh,math,json,shutil,datetime,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
B=Path('D:/NetSim3D/3Dmodel');P=B/'ใช้ร่วมกัน/blend/classroom_shell.blend'
backup=P.with_name('classroom_shell_before_underdesk_fix_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend');shutil.copy2(P,backup)
bpy.ops.wm.open_mainfile(filepath=str(P));s=bpy.context.scene;bpy.context.preferences.filepaths.save_version=0
C=bpy.data.collections['15 | Realistic connected computer peripherals'];OLD=bpy.data.collections['POWER | outlets strips and cables'];LAN=bpy.data.collections['LAN | empty conduits and sockets - NO CABLES']
FIX=bpy.data.collections.new('16 | Underdesk mounts and open grommets');s.collection.children.link(FIX)
rubber=bpy.data.materials['Soft black PVC cable jacket'];metal=bpy.data.materials['MAT_Desk_Frame_Charcoal'];white=bpy.data.materials['Ivory ABS housing']
removed=[]
for ob in list(LAN.objects):
 if any(t in ob.name for t in ['LAN connection box','empty RJ45 cavity','RJ45 shield','LAN label','EMPTY LAN riser','EMPTY LAN underdesk channel','EMPTY LAN box entry','LAN future distribution box','Future LAN label']):
  removed.append(ob.name);bpy.data.objects.remove(ob,do_unlink=True)
def mesh(n,vs,fs,mat,col=FIX):
 d=bpy.data.meshes.new(n);d.from_pydata(vs,[],fs);d.update();ob=bpy.data.objects.new(n,d);col.objects.link(ob)
 if mat:d.materials.append(mat)
 return ob
def box(n,p,size,mat=metal,bevel=.002):
 vs=[(a*size[0]/2,b*size[1]/2,c*size[2]/2) for a,b,c in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 fs=[(2,6,4,0),(5,7,3,1),(4,5,1,0),(3,7,6,2),(1,3,2,0),(6,7,5,4)]
 ob=mesh(n,vs,fs,mat);ob.location=p
 if bevel:m=ob.modifiers.new('Small edge radius','BEVEL');m.width=bevel;m.segments=2
 return ob
def cylinder(n,p,r,depth,mat=None):
 N=64;vs=[(r*math.cos(i*math.tau/N),r*math.sin(i*math.tau/N),z) for z in [-depth/2,depth/2] for i in range(N)]
 fs=[tuple(reversed(range(N))),tuple(range(N,N*2))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 o=mesh(n,vs,fs,mat);o.location=p;return o
def ring(n,center,outer,inner,z0,z1):
 N=64;vs=[]
 for z,r in [(z0,outer),(z1,outer),(z0,inner),(z1,inner)]:
  vs.extend([(center.x+r*math.cos(i*math.tau/N),center.y+r*math.sin(i*math.tau/N),z) for i in range(N)])
 fs=[]
 for a,b in [(0,N),(N,3*N),(3*N,2*N),(2*N,0)]:
  for i in range(N):j=(i+1)%N;fs.append((a+i,a+j,b+j,b+i))
 o=mesh(n,vs,fs,rubber)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();return o
students=sorted([o for o in s.objects if o.name.startswith('StudentDesk_Row')],key=lambda o:o.name);teacher=bpy.data.objects['TeacherDesk']
holes={}
for ob in [students[0],teacher]:
 ob.data=ob.data.copy();bm=bmesh.new();bm.from_mesh(ob.data)
 caps=set(v for f in bm.faces if 'Black_Accent' in ob.data.materials[f.material_index].name and min(v.co.z for v in f.verts)>.74 for v in f.verts)
 bmesh.ops.delete(bm,geom=list(caps),context='VERTS');bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 locs=[(-.48,.28)] if ob==teacher else [(-.55,.24),(.55,.24)]
 for hx,hy in locs:
  p=ob.matrix_world@Vector((hx,hy,.72));cut=cylinder('Temporary tabletop bore',p,.036,.24)
  bpy.context.view_layer.update();bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Real cable pass-through','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
if len(students)>1:
 for ob in students[1:]:ob.data=students[0].data
for desk in students+[teacher]:
 locs=[(-.48,.28)] if desk==teacher else [(-.55,.24),(.55,.24)]
 holes[desk.name]=[desk.matrix_world@Vector((hx,hy,.75)) for hx,hy in locs]
 for i,p in enumerate(holes[desk.name]):
  ring(desk.name+f' open cable grommet {i}',p,.045 if desk!=teacher else .050,.034,.750,.757)
  ring(desk.name+f' grommet sleeve {i}',p,.0355,.034,.671,.752)
  local=desk.matrix_world.inverted()@Vector((p.x,p.y,.90));assert not desk.ray_cast(local,Vector((0,0,-1)),distance=.25)[0],desk.name
def find(prefix,kind=None):
 result=[o for o in C.objects if o.name.startswith(prefix) and (not kind or o.type==kind)];assert len(result)==1,(prefix,len(result));return result[0]
def position(o):return Vector(o.matrix_world.translation)
def move_root(o,delta):o.location+=Vector(delta)
def rounded(ps,r=.025):
 ps=[Vector(p) for p in ps];out=[ps[0]]
 for i in range(1,len(ps)-1):
  prev,p,nex=ps[i-1:i+2];l1=(p-prev).length;l2=(nex-p).length
  if min(l1,l2)<1e-7:continue
  dist=min(r,l1*.28,l2*.28);a=p+(prev-p)*(dist/l1);b=p+(nex-p)*(dist/l2);out.append(a)
  for j in range(1,9):t=j/8;out.append((1-t)**2*a+2*(1-t)*t*p+t*t*b)
 out.append(ps[-1]);return out
routes=[]
def route(ob,ps,desk,r=.020,category='power'):
 pts=rounded(ps,r);ob.data=ob.data.copy();ob.data.splines.clear();sp=ob.data.splines.new('POLY');sp.points.add(len(pts)-1)
 for q,p in zip(sp.points,pts):q.co=(*p,1)
 ob['routed_length_m']=sum((b-a).length for a,b in zip(pts,pts[1:]));ob['management']='Rounded controlled path, real grommet and underdesk mount';ob['desk']=desk.name
 routes.append((ob,desk,pts,category));return pts
def clip(name,p,axis='X'):
 # Small open-sided clamp: two feet and one bridge, not a solid block through the cable.
 x,y,z=p
 if axis=='X':
  box(name+' foot A',(x,y-.011,z+.003),(.016,.004,.006),rubber,.001);box(name+' foot B',(x,y+.011,z+.003),(.016,.004,.006),rubber,.001);box(name+' strap',(x,y,z+.009),(.016,.027,.004),rubber,.001)
 else:
  box(name+' foot A',(x-.011,y,z+.003),(.004,.016,.006),rubber,.001);box(name+' foot B',(x+.011,y,z+.003),(.004,.016,.006),rubber,.001);box(name+' strap',(x,y,z+.009),(.027,.016,.004),rubber,.001)
def upper(start,out,g,desk,lane,teacher_route=False):
 start=Vector(start);ps=[start,start+Vector(out)*.025]
 if teacher_route:
  side=desk.location.x-.65;rear=desk.location.y-.355-lane
  ps += [Vector((start.x,rear,start.z)),Vector((side,rear,.785+lane)),Vector((side,g.y,.785+lane)),Vector((g.x,g.y,.785+lane))]
 else:
  rear=desk.location.y+.335+lane
  ps += [Vector((start.x,rear,start.z)),Vector((start.x,rear,.785+lane)),Vector((g.x,rear,.785+lane)),Vector((g.x,g.y,.785+lane))]
 ps += [Vector((g.x,g.y,.644))];return ps
def socket(root,needle):return next(o for o in root.children_recursive if o.type=='EMPTY' and needle in o.name)
allroots=[o for o in s.objects if o.name.startswith('StudentPC_') and o.name.endswith('__TeacherComputerSet_Root')]
for desk in students+[teacher]:
 ist=desk==teacher;tag='Teacher' if ist else desk.name.removeprefix('StudentDesk_');x,y=desk.location.x,desk.location.y;gx=holes[desk.name]
 # Tray sits inside the rear cross member, with 40 mm clearance below the tabletop.
 st=find(tag+' realistic 6-way strip | Connector','EMPTY');target=Vector((x-.50 if ist else x-.2915,y+.085,.545));delta=target-st.location;st.location=target
 trayx=x-.2085 if ist else x
 box(tag+' fixed underside cable tray',(trayx,y+.085,.524),(.73,.20,.012))
 for xx in [trayx-.345,trayx+.345]:
  box(tag+' tray mounting bracket',(xx,y+.15,.598),(.025,.028,.140));box(tag+' underside mounting foot',(xx,y+.13,.666),(.060,.070,.006))
 selected=[bpy.data.objects['TeacherComputerSet_Root']] if ist else sorted([o for o in allroots if o.get('desk')==desk.name],key=lambda o:o['seat'])
 for k,root in enumerate(selected):
  ident=tag+f' PC{k+1}';g=gx[0 if ist else k].copy();ag=g+Vector((-.010,0,0));dg=g+Vector((.012,0,0))
  acplug=find(ident+' AC mains plug | Connector','EMPTY');mp=find(ident+' monitor mains plug | Connector','EMPTY');move_root(acplug,delta);move_root(mp,delta)
  adapter=bpy.data.objects[tag+f' monitor AC DC adapter {k}'];adapter.location=(x-.50 if ist else x+(-.64 if k==0 else .64),y+.100,.553)
  box(ident+' adapter cradle',(adapter.location.x,adapter.location.y,.531),(.150,.080,.010))
  for yy in [-.019,.019]:box(ident+' adapter retaining band',(adapter.location.x,adapter.location.y+yy,.573),(.085,.008,.003),rubber,.001)
  ca=find(ident+' IEC C13 | Connector','EMPTY');ps=upper(ca.location,(0,-1 if ist else 1,0),ag,desk,0,ist)
  # Compact S-fold held on the tray; no free loops dipping through the desktop.
  lane_y=y+.14;z=.608
  ps += [Vector((ag.x,lane_y,z)),Vector((ag.x-.065,lane_y,z)),Vector((ag.x-.065,y-.010,z)),Vector((ag.x+.065,y-.010,z)),Vector((ag.x+.065,lane_y,z)),Vector((acplug.location.x,lane_y,z)),Vector((acplug.location.x,acplug.location.y,.644)),Vector(acplug.location)]
  route(find(ident+' AC power cord 1.8m','CURVE'),ps,desk)
  anchor=socket(root,'Socket_Monitor_DC_IN');out=anchor.matrix_world.to_3x3()@Vector((0,0,1));start=position(anchor)+out*.030
  ps=upper(start,out,dg,desk,.013,ist);ps += [Vector((dg.x,y+.08,.609)),Vector((adapter.location.x+.08,y+.08,.609)),Vector(adapter.location)+Vector((.065,0,0)),Vector(adapter.location)+Vector((.050,0,0))]
  dc=bpy.data.objects[tag+f' monitor DC lead {k}'];route(dc,ps,desk,category='dc')
  a=Vector(adapter.location)-Vector((.050,0,0));end=Vector(mp.location)
  route(find(ident+' monitor adapter mains cable','CURVE'),[a,a+Vector((-.025,0,0)),Vector((a.x,y+.03,.608)),Vector((end.x,y+.03,.608)),Vector((end.x,end.y,.644)),end],desk)
  # HDMI stays above the desktop in a shallow clipped rear channel; no large hanging loops.
  h1=find(ident+' HDMI at computer | Connector','EMPTY');h2=find(ident+' HDMI at monitor | Connector','EMPTY');a=Vector(h1.location);b=Vector(h2.location);side=-1 if ist else 1;rear=y+side*.360;zz=.777
  ps=[a,a+Vector((0,side*.025,0)),Vector((a.x,rear,a.z)),Vector((a.x,rear,zz)),Vector((b.x,rear,zz)),Vector((b.x,b.y+side*.032,zz)),Vector((b.x,b.y+side*.032,b.z)),b]
  route(find(ident+' HDMI 1.5m','CURVE'),ps,desk,category='hdmi')
  clip(ident+' HDMI rear guide',((a.x+b.x)/2,rear,.755))
  mouse=find(ident+' wired mouse | Connector','EMPTY');u=find(ident+' mouse USB A | Connector','EMPTY');a=Vector(mouse.location);b=Vector(u.location);side=-1 if ist else 1
  pathx=root.location.x+(-.295 if ist else .295);rear=y+side*.343
  ps=[a,a+Vector((0,side*.035,0)),Vector((pathx,a.y+side*.05,.768)),Vector((pathx,rear,.768)),Vector((b.x,rear,.768)),Vector((b.x,rear,b.z)),b]
  route(find(ident+' mouse USB cable','CURVE'),ps,desk,r=.014,category='usb')
  clip(ident+' mouse cable guide',(pathx,y+.08*side,.752),'Y')
  print('ROUTED',ident,flush=True)
 # Supply cable is restrained along the underside then descends by the outer desk leg.
 wp=find(tag+' grounded wall plug | Connector','EMPTY');start=Vector(st.location);wx=5.875 if x>0 else -5.875;side=1 if x>0 else -1
 if ist:
  ry=y+.405;outer=x+1.015
  ps=[start,start+Vector((-.028,0,0)),Vector((start.x,ry,.545)),Vector((outer,ry,.545)),Vector((outer,ry,.035)),Vector((wx,ry,.035)),Vector((wx,wp.location.y,.035)),Vector((wx,wp.location.y,.22)),Vector(wp.location)]
  box('Teacher rear floor supply cover',((outer+wx)/2,ry,.020),(abs(wx-outer)+.10,.10,.032),metal,.006)
 else:
  outer=x+side*1.135;ry=y+.17
  ps=[start,start+Vector((-.028,0,0)),Vector((outer,ry,.545)),Vector((outer,ry,.035)),Vector((outer,y+.29,.035)),Vector((wx,y+.29,.035)),Vector((wx,wp.location.y,.22)),Vector(wp.location)]
 route(find(tag+' strip supply cord routed','CURVE'),ps,desk,category='supply')
 st['mounting']='Fixed under desk in steel tray; sockets and plugs accessible from below.'
# Line-segment collision checks against the actual edited desk, not only its bounding box.
bpy.context.view_layer.update();hits=[]
for ob,desk,pts,cat in routes:
 inv=desk.matrix_world.inverted()
 for a,b in zip(pts,pts[1:]):
  aa=inv@a;bb=inv@b;d=bb-aa;dist=d.length
  if dist<1e-6:continue
  hit,loc,n,face=desk.ray_cast(aa,d/dist,distance=dist-.00005)
  if hit:hits.append({'cable':ob.name,'category':cat,'point':list(desk.matrix_world@loc)});break
print('DESK_INTERSECTIONS',json.dumps(hits),flush=True)
assert not hits,'Cable intersects desk - repair before saving'
assert len(holes)==11 and sum(map(len,holes.values()))==21
assert not any('LAN connection box' in o.name for o in s.objects)
assert all(not o.get('occupied',False) for o in s.objects if 'Socket_LAN_RJ45' in o.name)
C['routing_note']='Power/DC through 21 real open grommets; 11 strips and monitor adapters secured under desks. HDMI/USB clipped above tabletop. Installed paths tailored to furniture; catalog lengths remain nominal, not asserted for reshaped routes.'
FIX['removed_objects_count']=len(removed)
bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.save_as_mainfile(filepath=str(P),compress=True)
(B/'temp/underdesk_cable_fix_validation.json').write_text(json.dumps({'backup':str(backup),'removed_lan_objects':removed,'open_grommets':21,'underdesk_strips':11,'rerouted_cables':len(routes),'desk_intersections':hits},indent=2))
print('SAVED_UNDERDESK_FIX',flush=True)
camdata=bpy.data.cameras.new('Underdesk QA');cam=bpy.data.objects.new('Underdesk QA',camdata);s.collection.objects.link(cam);s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=20;s.cycles.use_denoising=True;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100
for name,pos,target,lens in [('student_top',(4.55,-.18,2.0),(2.7,-1.14,.76),34),('student_under',(3.15,-2.45,.42),(2.7,-1.07,.575),29),('teacher_top',(5.25,9.05,1.9),(3.8,8,.76),35)]:
 cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();camdata.lens=lens;s.render.filepath=str(B/'ใช้ร่วมกัน/renders'/f'classroom_cable_fix_{name}.png');bpy.ops.render.render(write_still=True)
print('QA_RENDERS_COMPLETE',flush=True)
