import bpy,math,shutil,datetime,json
from pathlib import Path
from mathutils import Vector
B=Path('D:/NetSim3D/3Dmodel');P=B/'ใช้ร่วมกัน/blend/classroom_shell.blend'
backup=P.with_name('classroom_shell_before_power_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'.blend');shutil.copy2(P,backup)
bpy.ops.wm.open_mainfile(filepath=str(P));bpy.context.preferences.filepaths.save_version=0
s=bpy.context.scene
assert not bpy.data.collections.get('14 | Computer room power and empty LAN routes')
main=bpy.data.collections.new('14 | Computer room power and empty LAN routes');s.collection.children.link(main)
def collection(n):
 c=bpy.data.collections.new(n);main.children.link(c);return c
power=collection('POWER | outlets strips and cables');network=collection('LAN | empty conduits and sockets - NO CABLES');ducts=collection('ROUTES | separate power raceways')
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.48;p.inputs['Metallic'].default_value=metal;return m
white=mat('Electrical | ivory plastic',(.73,.75,.72));black=mat('Electrical | cable rubber',(.012,.016,.019));dark=mat('Electrical | socket recess',(.018,.02,.024));gray=mat('Electrical | duct cover',(.32,.36,.39));blue=mat('LAN | blue identifiers',(.035,.18,.35));red=mat('Electrical | switch',(.45,.025,.016));silver=mat('Electrical | contacts',(.45,.48,.51),.7)
def box(n,p,d,m,c=power,bevel=.002):
 verts=[(a*d[0]/2,b*d[1]/2,e*d[2]/2) for a,b,e in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 faces=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(n,mesh);c.objects.link(o);o.location=p;o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=2
 return o
def wire(n,points,r=.003,c=power):
 cu=bpy.data.curves.new(n,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=2;cu.resolution_u=10
 sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for b,p in zip(sp.bezier_points,points):b.co=p;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 ob=bpy.data.objects.new(n,cu);c.objects.link(ob);cu.materials.append(black);return ob
def label(n,txt,p,rot=(0,0,0),size=.014,c=power):
 cu=bpy.data.curves.new(n,'FONT');cu.body=txt;cu.size=size;cu.align_x='CENTER';cu.extrude=.00015
 o=bpy.data.objects.new(n,cu);c.objects.link(o);o.location=p;o.rotation_euler=rot;cu.materials.append(blue);return o
def route(n,a,b,c,ma,width=.10,height=.024):
 a,b=Vector(a),Vector(b);v=b-a
 o=box(n,(a+b)/2,(width,v.length,height),ma,c,.008);o.rotation_euler=v.to_track_quat('Y','Z').to_euler();o['purpose']='EMPTY LAN conduit - no cables' if c==network else 'Power cable cover';return o
def outlet(n,x,y):
 # Vertical wall plate facing the room. Socket holes are recessed dark inserts.
 side=-1 if x>0 else 1
 plate=box(n+' wall outlet',(x,y,.32),(.035,.14,.19),white)
 for z in [.28,.36]:
  for dy in [-.023,.023]:box(n+' outlet slot',(x+side*.019,y+dy,z),(.002,.006,.016),dark,bevel=.001)
  box(n+' ground aperture',(x+side*.019,y,z-.025),(.002,.012,.008),dark)
 plug=box(n+' supply plug',(x+side*.040,y,.29),(.048,.044,.046),black)
 return (x+side*.067,y,.29)
def station(desk,roots,tag):
 x,y=desk.location.x,desk.location.y
 # Tabletop is 0.75 m; raised cable grommets are not used as tabletop height.
 z=.7505;back=y+(.29 if tag!='Teacher' else -.29)
 strip=box(tag+' 6-way earthed power strip',(x,back,z+.026),(.54,.078,.052),white)
 slots=[]
 for i in range(6):
  px=x-.205+i*.075;slots.append(Vector((px,back,z+.055)))
  box(tag+f' socket {i+1} inset',(px,back,z+.0525),(.058,.058,.003),gray)
  for dx in [-.013,.013]:box(tag+' socket live neutral recess',(px+dx,back+.006,z+.055),(.006,.016,.004),dark,bevel=.001)
  box(tag+' socket earth recess',(px,back-.014,z+.055),(.009,.008,.004),dark,bevel=.001)
 box(tag+' rocker power switch',(x+.245,back,z+.056),(.024,.037,.012),red)
 label(tag+' power label','POWER',(x,back-.021,z+.058),size=.011)
 for k,root in enumerate(roots):
  for j,needle in enumerate(['Socket_AC_Power_Inlet','Socket_Monitor_DC_IN']):
   anchor=next(o for o in root.children_recursive if needle in o.name)
   start=anchor.matrix_world.translation;out=(anchor.matrix_world.to_3x3()@Vector((0,0,1))).normalized()
   plug=box(tag+f' {k} '+('IEC C13 connector' if j==0 else 'DC barrel connector'),start+out*.014,(.024,.019,.036) if j==0 else (.010,.010,.025),black)
   plug.rotation_euler=out.to_track_quat('Z','Y').to_euler();anchor['occupied']=True;anchor['connection']='POWER ONLY'
   end=slots[k*2+j];box(tag+f' mains plug {k*2+j}',end+Vector((0,0,.016)),(.036,.037,.028),black)
   if j==1:
    adapter=Vector((root.location.x+.32,back-.09,z+.022))
    box(tag+f' monitor AC DC adapter {k}',adapter,(.105,.045,.035),black)
    wire(tag+f' monitor DC lead {k}',[start+out*.028,start+out*.07,Vector((adapter.x,adapter.y,z+.095)),adapter+Vector((.05,0,0))],.002)
    wire(tag+f' monitor mains lead {k}',[adapter-Vector((.05,0,0)),Vector((adapter.x-.08,back-.07,z+.075)),end+Vector((0,0,.04))])
   else:wire(tag+f' PC mains cable {k}',[start+out*.034,start+out*.10,Vector((start.x,back,z+.14)),end+Vector((0,0,.04))])
 # LAN faceplate with two empty jacks per desk (teacher uses one).
 lx=x-.42
 box(tag+' LAN connection box',(lx,back,z+.036),(.16,.07,.072),white,network)
 for i in range(2 if tag!='Teacher' else 1):
  xx=lx-.04+i*.08
  box(tag+' empty RJ45 cavity',(xx,back-.036,z+.038),(.016,.004,.014),dark,network,.001)
  box(tag+' RJ45 shield',(xx,back-.037,z+.047),(.020,.005,.002),silver,network,.0005)
  label(tag+' LAN label','LAN '+str(i+1),(xx,back-.039,z+.057),(math.pi/2,0,0),.009,network)
 # Separate low-profile routes from the side wall, leaving the centre aisle free.
 side=1 if x>0 else -1;wallx=side*5.96;outer=x+side*1.10
 supply=outlet(tag,wallx,back)
 wire(tag+' strip supply cord',[Vector((x-.27,back,z+.028)),Vector((outer,back,.68)),Vector((outer,back,.08)),Vector((wallx-side*.10,back,.045)),Vector(supply)],.004)
 route(tag+' POWER floor cover',(wallx-side*.08,back,.03),(outer,back,.03),ducts,gray)
 route(tag+' EMPTY LAN floor conduit',(wallx-side*.08,back+.15,.03),(outer,back+.15,.03),network,blue,.09)
 route(tag+' EMPTY LAN riser',(outer,back+.15,.05),(outer,back+.15,.69),network,gray,.035,.035)
 route(tag+' EMPTY LAN underdesk channel',(outer,back+.15,.69),(lx,back+.15,.69),network,gray,.035,.035)
 route(tag+' EMPTY LAN box entry',(lx,back+.15,.69),(lx,back,.76),network,gray,.027,.027)
 print('DESK_COMPLETE',tag,flush=True)
 return {'desk':desk.name,'computer_count':len(roots),'mains_connections':len(roots)*2}
studentroots=[o for o in s.objects if o.name.startswith('StudentPC_') and o.name.endswith('__TeacherComputerSet_Root')]
assert len(studentroots)==20
records=[]
for desk in sorted([o for o in s.objects if o.name.startswith('StudentDesk_Row')],key=lambda d:d.name):
 roots=sorted([o for o in studentroots if o.get('desk')==desk.name],key=lambda o:o['seat']);assert len(roots)==2
 records.append(station(desk,roots,desk.name.removeprefix('StudentDesk_')))
records.append(station(bpy.data.objects['TeacherDesk'],[bpy.data.objects['TeacherComputerSet_Root']],'Teacher'))
# Empty LAN perimeter routes meet at a reserved termination box near the teacher.
for xx in [-5.80,5.80]:route('EMPTY LAN perimeter', (xx,-7.15,.12),(xx,9.55,.12),network,gray,.10,.08)
route('EMPTY LAN front cross connection',(-5.80,9.55,.12),(5.80,9.55,.12),network,gray,.10,.08)
box('LAN future distribution box - EMPTY',(5.81,9.40,.48),(.25,.20,.45),white,network)
label('Future LAN label','LAN / EMPTY',(5.80,9.295,.48),(math.pi/2,0,0),.023,network)
main['scope']='Visual game asset only; not an electrical installation plan. No LAN cables created. Supplies and circuits are not electrically simulated.'
network['contains_lan_cables']=False
bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.save_as_mainfile(filepath=str(P),compress=True)
(B/'temp/classroom_power_validation.json').write_text(json.dumps({'backup':str(backup),'stations':records,'lan_cables':0},indent=2))
print('SAVED_POWER_21_COMPUTERS_42_DEVICE_LEADS_11_STRIPS_NO_LAN_CABLES',flush=True)
# Close preview of a two-computer student desk.
d=bpy.data.cameras.new('Power preview');cam=bpy.data.objects.new('Power preview',d);s.collection.objects.link(cam);cam.location=(5.3,-.05,2.6);target=Vector((2.8,-1.0,.7));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();d.lens=29;s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.resolution_x=1400;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.filepath=str(B/'ใช้ร่วมกัน/renders/classroom_power_and_lan_routes.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.open_mainfile(filepath=str(P));assert bpy.data.collections.get('14 | Computer room power and empty LAN routes')
print('REOPENED_OK',flush=True)
