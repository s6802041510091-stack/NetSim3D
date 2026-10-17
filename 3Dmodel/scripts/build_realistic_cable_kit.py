import bpy,math,json,shutil
from pathlib import Path
from mathutils import Vector
B=Path('D:/NetSim3D/3Dmodel');OUT=B/'ใช้ร่วมกัน/blend/realistic_computer_cable_kit.blend'
if OUT.exists():shutil.copy2(OUT,OUT.with_name('realistic_computer_cable_kit_first_draft.blend'))
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.unit_settings.system='METRIC';bpy.context.preferences.filepaths.save_version=0
def mat(n,c,metal=0,rough=.4):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
rubber=mat('Soft black PVC cable jacket',(.016,.019,.024),0,.54);plastic=mat('Moulded charcoal connector',(.027,.032,.038),0,.35);dark=mat('Socket cavity',(.004,.006,.008));ivory=mat('Ivory ABS housing',(.77,.80,.79));silver=mat('Nickel plated metal',(.58,.63,.68),.85,.23);gold=mat('Gold plated connector',(.64,.37,.075),.82,.22);red=mat('Red rocker switch',(.50,.018,.012),0,.27);blue=mat('Pale blue mouse',(.28,.46,.69),0,.33);lightcord=mat('Mouse pale gray cable',(.64,.69,.77));ink=mat('Markings',(.48,.53,.56));yellow=mat('Connector identifier',(.88,.52,.04))
current=None
def mesh(n,vs,fs,m,parent=None):
 d=bpy.data.meshes.new(n);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(n,d);current.objects.link(o);o.parent=parent
 if m:d.materials.append(m)
 return o
def box(n,p,d,m,parent=None,b=.001):
 vs=[(a*d[0]/2,c*d[1]/2,e*d[2]/2) for a,c,e in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
 o=mesh(n,vs,[tuple(reversed(f)) for f in faces],m,parent);o.location=p
 if b:mod=o.modifiers.new('Manufactured radii','BEVEL');mod.width=b;mod.segments=3
 return o
def empty(n,p=(0,0,0),parent=None):
 o=bpy.data.objects.new(n,None);current.objects.link(o);o.location=p;o.parent=parent;o.empty_display_size=.01;return o
def cyl(n,p,r,depth,m,parent=None,axis='Z',segments=32):
 vs=[]
 for z in [-depth/2,depth/2]:
  for i in range(segments):
   a=i*math.tau/segments;v=Vector((r*math.cos(a),r*math.sin(a),z));vs.append(tuple(v))
 fs=[tuple(reversed(range(segments))),tuple(range(segments,segments*2))]+[(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)]
 o=mesh(n,vs,fs,m,parent);o.location=p
 if axis=='Y':o.rotation_euler.x=math.pi/2
 if axis=='X':o.rotation_euler.y=math.pi/2
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def text(n,body,p,size,parent=None,rot=(0,0,0),ma=ink):
 d=bpy.data.curves.new(n,'FONT');d.body=body;d.size=size;d.align_x='CENTER';d.extrude=.00004;o=bpy.data.objects.new(n,d);current.objects.link(o);o.parent=parent;o.location=p;o.rotation_euler=rot;d.materials.append(ma);return o
def cut(o,p,d,parent):
 cutter=box('temporary recess',p,d,None,parent,b=0);bpy.context.view_layer.update();bpy.context.view_layer.objects.active=o
 mod=o.modifiers.new('True recessed opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;o.modifiers.move(len(o.modifiers)-1,0);bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
def curve(n,pts,r,m,parent):
 d=bpy.data.curves.new(n,'CURVE');d.dimensions='3D';d.bevel_depth=r;d.bevel_resolution=3;d.use_fill_caps=True;sp=d.splines.new('POLY');sp.points.add(len(pts)-1)
 for a,p in zip(sp.points,pts):a.co=(*p,1)
 o=bpy.data.objects.new(n,d);current.objects.link(o);o.parent=parent;d.materials.append(m);return o
reports=[]
def coil(root,length,diam,material):
 turns=max(1.25,length/.75);N=1200;pts=[]
 for i in range(N+1):
  t=i/N*turns*math.tau;r=.075+(diam+.003)*t/math.tau;pts.append(Vector((r*math.cos(t),r*math.sin(t),.020)))
 # Lead-in lifts over the turns then leaves the connector outside the coil.
 lead=[]
 controls=[Vector((.21,-.12,.02)),Vector((.21,-.025,.045)),Vector((.075,-.06,.055)),Vector((.075,0,.02))]
 for i in range(160):
  t=i/160;lead.append((1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3])
 pts=lead+pts
 low,high=.01,10
 for _ in range(45):
  scale=(low+high)/2;q=[Vector((p.x*scale,p.y*scale,p.z)) for p in pts];actual=sum((b-a).length for a,b in zip(q,q[1:]))
  if actual<length:low=scale
  else:high=scale
 pts=[Vector((p.x*scale,p.y*scale,p.z)) for p in pts]
 o=curve('Cable | continuous jacket',pts,diam/2,material,root);o['centerline_length_m']=sum((b-a).length for a,b in zip(pts,pts[1:]));o['diameter_m']=diam
 assert abs(o['centerline_length_m']-length)<1e-6
 ends=[]
 for p,v in [(pts[0],pts[0]-pts[1]),(pts[-1],pts[-1]-pts[-2])]:
  v.z=0
  e=empty('Connector | cable attachment',p,root);e.rotation_euler=v.to_track_quat('Y','Z').to_euler();ends.append(e)
 reports.append({'name':root.name,'length_m':o['centerline_length_m'],'diameter_m':diam})
 return ends
def boot(parent,r=.004):
 cyl('Flexible strain relief',(0,.012,0),r,.028,rubber,parent,'Y')
 for i in range(6):cyl('Strain relief moulded rib',(0,.003+i*.0035,0),r*1.23,.0013,plastic,parent,'Y')
def ac_plug(parent):
 boot(parent)
 box('Grounded mains plug grip',(0,.039,0),(.034,.043,.029),plastic,parent,.007)
 for x in [-1,1]:
  for i in range(4):box('Mains plug grip ridges',(x*.0165,.029+i*.005,0),(.0018,.0028,.016),rubber,parent,.0007)
 for x in [-.008,.008]:box('Mains flat metal pin',(x,.071,.004),(.006,.019,.0018),silver,parent,.0006)
 cyl('Round earth pin',(0,.073,-.006),.0024,.022,silver,parent,'Y')
 text('Plug marking','AC',(0,.038,.0152),.006,parent)
def c13(parent):
 boot(parent)
 body=box('IEC C13 female moulded housing',(0,.044,0),(.029,.047,.021),plastic,parent,.004)
 for x,z in [(-.007,-.0035),(.007,-.0035),(0,.0045)]:
  cut(body,(x,.066,z),(.0045,.018,.0035),parent);box('C13 socket dark interior',(x,.058,z),(.004,.001,.003),dark,parent,.0002)
 for side in [-1,1]:
  for j in range(5):box('C13 grip ribs',(side*.0143,.030+j*.005,0),(.0015,.0025,.013),rubber,parent,.0005)
 text('IEC marking','C13',(0,.043,.0107),.005,parent)
def hdmi(parent):
 boot(parent,.0035);cyl('Gold identifier band',(0,.020,0),.0048,.002,yellow,parent,'Y')
 box('HDMI overmould grip',(0,.038,0),(.020,.035,.011),plastic,parent,.003)
 # Hollow trapezoid metal shell, open at the mating face.
 outer=[(-.007,.0025),(.007,.0025),(.006,-.0025),(-.006,-.0025)];inner=[(x*.89,z*.72) for x,z in outer];vs=[]
 for y,profile in [(.053,outer),(.064,outer),(.053,inner),(.064,inner)]:vs += [(x,y,z) for x,z in profile]
 fs=[]
 for a,b in [(0,4),(8,12),(4,12),(0,8)]:
  for i in range(4):j=(i+1)%4;fs.append((a+i,a+j,b+j,b+i))
 mesh('HDMI Type A hollow gold shell',vs,fs,gold,parent)
 box('HDMI insulator tongue',(0,.058,0),(.011,.010,.001),dark,parent,.0002)
 for row,count in [(1,10),(-1,9)]:
  for i in range(count):box('HDMI contact',( (i-(count-1)/2)*.001,.060,row*.00058),(.00045,.006,.00016),gold,parent,.00005)
 text('HDMI grip mark','HDMI',(0,.034,.0057),.005,parent)
 for j in range(4):box('HDMI finger grip rib',(0,.024+j*.003,.0055),(.014,.0012,.0007),rubber,parent,.0003)
def usb(parent):
 boot(parent,.002);box('USB A overmould',(0,.029,0),(.017,.025,.008),lightcord,parent,.003)
 sh=box('USB A metal shell',(0,.046,0),(.012,.014,.0045),silver,parent,.0006)
 cut(sh,(0,.050,0),(.0105,.012,.0032),parent);box('USB A insulator',(0,.047,-.0008),(.009,.010,.0013),ivory,parent,.0001)
 for x in [-.003,-.001,.001,.003]:box('USB contact',(x,.047,0),(.0008,.007,.0002),gold,parent,.00003)
 text('USB mark','USB',(0,.027,.0042),.004,parent)
def mouse(parent):
 boot(parent,.0017)
 # Ergonomic ellipsoidal shell loft, base and split click panels.
 center=empty('Wired mouse body',(0,.071,-.009),parent)
 def shell(n,start,end,m,width=1):
  vs=[];fs=[];rows=80;cols=96
  for j in range(rows+1):
   a=start+(end-start)*j/rows
   for i in range(cols+1):
    t=math.pi*i/cols
    xx=.030*math.sin(a)*math.cos(t)*width;yy=-.052*math.cos(a);zz=.028*math.sin(a)**.75*math.sin(t)
    vs.append((xx,yy,zz))
  for j in range(rows):
   for i in range(cols):
    if j<43 and i==47:continue
    if j==42:continue
    if 20<=j<=29 and 44<=i<=51:continue
    q=j*(cols+1)+i;fs.append((q,q+1,q+cols+2,q+cols+1))
  o=mesh(n,vs,fs,m,center)
  for f in o.data.polygons:f.use_smooth=True
  sol=o.modifiers.new('Shell thickness','SOLIDIFY');sol.thickness=.001
  return o
 shell('Mouse main ergonomic shell',.03,math.pi-.03,blue)
 # Real seam cut through shell for independent left/right button region.
 box('Mouse dark inner chassis',(0,0,.011),(.039,.072,.013),dark,center,.010)
 cyl('Rubber scroll wheel',(0,-.012,.028),.008,.006,rubber,center,'X')
 for i in range(24):
  a=i*math.tau/24;ob=box('Wheel tread',(0,-.012+.008*math.cos(a),.028+.008*math.sin(a)),(.0065,.001,.001),plastic,center,.0002);ob.rotation_euler.x=a
 box('Mouse bottom plate',(0,.002,-.001),(.043,.081,.003),ivory,center,.008)
 for yy in [-.029,.030]:box('Mouse glide pad',(0,yy,-.003),(.027,.008,.001),dark,center,.003)
 box('Optical sensor recess',(0,.002,-.003),(.007,.009,.001),dark,center,.001)
 text('Mouse logo','NETCARE',(0,.023,.026),.004,center)
def strip(parent,slots,length):
 boot(parent)
 L=.077*slots+.065;cy=.028+L/2
 body=box(f'{slots}-outlet extension housing',(0,cy,0),(.070,L,.034),ivory,parent,.008)
 # Bottom seam and screw wells.
 box('Lower housing seam',(0,cy,-.012),(.0705,L-.010,.0012),gray if False else ink,parent,.0005)
 for i in range(slots):
  y=.067+i*.077
  pad=box('Recessed socket face',(-.009,y,.018),(.044,.056,.006),ivory,parent,.004)
  for dx,dy,ww,hh in [(-.010,.007,.005,.012),(.010,.007,.005,.012),(0,-.013,.007,.006)]:
   cut(pad,(-.009+dx,y+dy,.020),(ww,hh,.014),parent)
   cut(body,(-.009+dx,y+dy,.019),(ww,hh,.018),parent)
   box('Deep socket insert',(-.009+dx,y+dy,.014),(ww,hh,.001),dark,parent,.0001)
  box('Individual switch bezel',(.023,y,.020),(.016,.027,.006),dark,parent,.003)
  sw=box('Individual red rocker',(.023,y,.024),(.012,.021,.006),red,parent,.002);sw['interaction']='toggle outlet '+str(i+1)
  text('Switch I','I',(.023,y+.004,.0273),.004,parent,ma=ivory)
  text('Switch O','O',(.023,y-.007,.0273),.003,parent,ma=ivory)
 for yy in [.039,.028+L-.011]:
  cyl('Housing screw',(0,yy,.0176),.002,.001,silver,parent)
  box('Screw slot',(0,yy,.0183),(.003,.0005,.0002),dark,parent,.00005)
 text('Strip identification',f'NETCARE / {slots} WAY',(0,cy+L/2-.030,.018),.004,parent)
 body['nominal_cord_length_m']=length;body['electrical_note']='Visual game prop. No certification or electrical rating implied.'
def asset(name,pos):
 global current
 current=bpy.data.collections.new(name);s.collection.children.link(current);root=empty(name+' ROOT',pos);root['units']='metres';return root
root=asset('01 AC power cord 1.8m',(-1,1.1,0));a,b=coil(root,1.8,.0068,rubber);ac_plug(a);c13(b)
root=asset('02 Wired USB mouse 1.5m',(0,1.1,0));a,b=coil(root,1.5,.0031,lightcord);mouse(a);usb(b)
root=asset('03 HDMI Type A 1.5m',(1,1.1,0));a,b=coil(root,1.5,.006,rubber);hdmi(a);hdmi(b)
for i,(slots,length) in enumerate([(4,1.5),(4,3),(4,5),(6,1.5),(6,3),(6,5)]):
 root=asset(f'{i+4:02d} Power strip {slots} outlets {length}m',((i%3-1)*1.0,0-(i//3)*1.1,0));a,b=coil(root,length,.007,rubber);strip(a,slots,length);ac_plug(b)
current=bpy.data.collections.new('STUDIO | not game geometry');s.collection.children.link(current)
floor=box('Studio floor',(0,0,-.008),(5,5,.01),mat('Studio matte slate',(.09,.115,.14)),b=.001)
for i,r in enumerate(reports):
 root=bpy.data.objects[r['name']];text('Display caption',r['name'].replace(' ROOT',''),(root.location.x,root.location.y-.78,.002),.025,ma=ivory)
def area(n,pos,energy,size):
 d=bpy.data.lights.new(n,'AREA');d.energy=energy;d.shape='DISK';d.size=size;o=bpy.data.objects.new(n,d);current.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
area('Large softbox',(-1,-1,3),450,3);area('Rim softbox',(2,2,2.5),600,2)
s.world=bpy.data.worlds.new('Studio world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.6,.7,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
d=bpy.data.cameras.new('Kit camera');cam=bpy.data.objects.new('Kit camera',d);current.objects.link(cam);s.camera=cam
def camera(pos,target,scale):cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=scale
camera((0,-.2,6),(0,-.2,0),4.1)
s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True;s.render.resolution_x=1800;s.render.resolution_y=1800;s.render.resolution_percentage=100
s.render.filepath=str(B/'ใช้ร่วมกัน/renders/realistic_cable_kit_overview.png')
notes=bpy.data.texts.new('README');notes.write('Nine separate asset collections. Geometry in metres. Cable centerline lengths measured on editable POLY curves; excludes connector bodies. Cords are continuous with strain relief, no floating free cable ends. HDMI 19 contacts, USB 4 contacts; visual reference models, not manufacturing CAD or certified electrical products. Studio excluded from game exports. No classroom files modified. Convert curves and text to meshes before game export; no physics or interaction scripts included.')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True);print('SAVED_KIT',flush=True)
(B/'temp/realistic_cable_kit_validation.json').write_text(json.dumps(reports,indent=2))
bpy.ops.render.render(write_still=True)
for name,pos,target,scale in [('ac',(-.85,.85,.5),(-.97,1.06,0),.60),('mouse',(0,.75,.55),(.02,1.02,0),.60),('hdmi',(1,.8,.5),(1.02,1.07,0),.56),('strip',(-1,-1.7,.8),(-.90,-1.35,0),1.0)]:
 camera(pos,target,scale);s.render.resolution_x=1200;s.render.resolution_y=1000;s.render.filepath=str(B/'ใช้ร่วมกัน/renders'/f'realistic_cable_kit_{name}.png');bpy.ops.render.render(write_still=True)
print('COMPLETE_CABLE_KIT',flush=True)
