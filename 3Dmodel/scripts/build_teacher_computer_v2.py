"""Original, realistically proportioned educational desktop. Blender 5.2.
All dimensions authored in mm, stored in metres. No downloaded models/textures.
Builds a staging file; never overwrites a user's working .blend directly.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix

BASE = Path('D:/NetSim3D/3Dmodel')
TMP = BASE / 'temp/teacher_computer_set/v2'
TMP.mkdir(parents=True, exist_ok=True)
OUT = TMP / 'teacher_computer_set_v2.blend'
R = BASE / 'ใช้ร่วมกัน/renders'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection': bpy.data.collections.remove(c)
for m in list(bpy.data.materials):
    if not m.users: bpy.data.materials.remove(m)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.length_unit = 'METERS'
scene.unit_settings.scale_length = 1
bpy.context.preferences.filepaths.save_version = 0
bpy.context.preferences.filepaths.temporary_directory = str(TMP)
bpy.context.preferences.filepaths.use_auto_save_temporary_files = False
asset = bpy.data.collections.new('ASSET | NetCare Desktop v2')
studio = bpy.data.collections.new('STUDIO | render only')
scene.collection.children.link(asset); scene.collection.children.link(studio)

def mm(v): return tuple(x*.001 for x in v)
def link(o,c=asset):
    for old in list(o.users_collection): old.objects.unlink(o)
    c.objects.link(o)
    return o
def empty(name,parent=None,pos=(0,0,0)):
    o=bpy.data.objects.new(name,None); asset.objects.link(o); o.parent=parent
    o.location=mm(pos); o.empty_display_type='PLAIN_AXES'; o.empty_display_size=.012
    return o
root=empty('TeacherComputerSet_Root')
pc=empty('01_Case',root); mon=empty('02_Monitor',root); kb=empty('03_Keyboard',root); mouse=empty('04_Mouse',root)
root['asset_version']='2.0'; root['units']='metres'; root['placement']='Component roots Z=0 on tabletop; front is -Y'
root['state']='Unplugged, power OFF. Mount markers use local +Z outward; insertion is -Z.'

def mat(name,col,metal=0,rough=.4,micro=False):
    m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
    n=m.node_tree.nodes; bs=n.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*col,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    if micro:
        noise=n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=1800; noise.inputs['Detail'].default_value=2
        bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.12; bump.inputs['Distance'].default_value=.000018
        m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']); m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    return m
black=mat('Polymer | charcoal fine grain',(.018,.022,.028),0,.4,True)
powder=mat('Steel | graphite powder coat',(.032,.038,.046),.5,.38,True)
silver=mat('Metal | satin nickel',(.44,.48,.53),.88,.27)
alu=mat('Metal | anodised dark aluminium',(.095,.12,.145),.78,.33)
dark=mat('Socket interior | black',(.003,.004,.006),0,.6)
rubber=mat('Rubber | grip',(.009,.010,.012),0,.75)
gold=mat('Contacts | plated gold',(.68,.39,.08),.85,.25)
blue=mat('USB 3 tongue | blue',(.015,.075,.30),0,.45)
ink=mat('Printed legends | light grey',(.65,.71,.76),0,.53)
subink=mat('Printed secondary | grey',(.30,.36,.42),0,.55)
green=mat('LAN link LED | off',(.006,.075,.025),0,.23)
amber=mat('LAN activity LED | off',(.14,.06,.004),0,.23)
glass=mat('Display | dark anti-glare',(.008,.015,.020),.12,.24)
led=mat('Power indicator | off',(.075,.092,.10),.1,.25)

def finish(o,name,material,parent,bevel=0):
    o.name=name; link(o); o.parent=parent
    if material:o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('Manufactured edge radius','BEVEL'); mod.width=bevel*.001; mod.segments=3
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    if o.type=='MESH':
        for f in o.data.polygons: f.use_smooth=True
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=50
    return o
def box(name,dim,pos,material=black,parent=pc,bevel=.3):
    bpy.ops.mesh.primitive_cube_add(size=1,location=mm(pos)); o=bpy.context.object; o.dimensions=mm(dim)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,material,parent,bevel)
def cyl(name,r,depth,pos,material=black,parent=pc,rot=(0,0,0),segments=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r*.001,depth=depth*.001,location=mm(pos),rotation=rot)
    return finish(bpy.context.object,name,material,parent,.12)
def mesh(name,verts,faces,material,parent):
    d=bpy.data.meshes.new(name); d.from_pydata([mm(v) for v in verts],[],faces); d.update()
    bm=bmesh.new(); bm.from_mesh(d); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(d); bm.free()
    o=bpy.data.objects.new(name,d); asset.objects.link(o); o.parent=parent
    if material:d.materials.append(material)
    return o
def wire(name,coords,r,material=black,parent=pc):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.bevel_depth=r*.001; d.bevel_resolution=2
    s=d.splines.new('POLY'); s.points.add(len(coords)-1)
    for p,v in zip(s.points,coords):p.co=(*mm(v),1)
    o=bpy.data.objects.new(name,d); asset.objects.link(o); o.parent=parent; d.materials.append(material); return o
fontpath=Path('C:/Windows/Fonts/segoeui.ttf')
font=bpy.data.fonts.load(str(fontpath)) if fontpath.exists() else bpy.data.fonts[0]
def text(name,s,pos,size=3,material=ink,parent=pc,rotation=(0,0,0),align='CENTER'):
    d=bpy.data.curves.new(name,'FONT'); d.body=s; d.font=font; d.size=size*.001; d.align_x=align; d.align_y='CENTER'; d.resolution_u=3
    o=bpy.data.objects.new(name,d); asset.objects.link(o); o.parent=parent; o.location=mm(pos); o.rotation_euler=rotation; d.materials.append(material)
    return o

# Port coordinate frame: XY at receptacle mouth, Z points away from equipment.
FRONT=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
REAR=Matrix(((-1,0,0),(0,0,1),(0,1,0)))
TOP=Matrix.Identity(3)
def frame(name,pos,parent=pc,orient=REAR):
    o=empty(name,parent,pos); o.rotation_euler=orient.to_euler(); return o
def rr(w,h,r,n=4):
    pts=[]
    for cx,cy,a in [(w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)]:
        for j in range(n+1):
            t=math.radians(a+j*90/n); pts.append((cx+r*math.cos(t),cy+r*math.sin(t)))
    return pts
def prism(name,p,z0,z1,material,parent):
    n=len(p); v=[(x,y,z) for z in (z0,z1) for x,y in p]
    f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,f,material,parent)
def socket_ring(name,p,thick,depth,parent,material=silver):
    # Corresponding contours retain the distinctive HDMI/DP/RJ45 keying.
    w=max(x for x,y in p)-min(x for x,y in p); h=max(y for x,y in p)-min(y for x,y in p)
    outer=[(x*(1+2*thick/w),y*(1+2*thick/h)) for x,y in p]; n=len(p)
    v=[(x,y,z) for path,z in ((outer,.25),(p,.25),(p,-depth),(outer,-depth)) for x,y in path]
    f=[]
    for a,b in ((0,1),(1,2),(2,3),(3,0)):
        for i in range(n):j=(i+1)%n; f.append((a*n+i,a*n+j,b*n+j,b*n+i))
    return mesh(name,v,f,material,parent)
def cut(target,p,fr):
    # Fixed 0.15 mm clearance stays under socket lips, regardless of aperture size.
    # Percentage expansion left large open gaps around the grille and rear fan.
    w=max(x for x,y in p)-min(x for x,y in p)
    h=max(y for x,y in p)-min(y for x,y in p)
    cutter=prism('TEMP_opening',[(x*(1+.3/w),y*(1+.3/h)) for x,y in p],-20,4,None,fr)
    bpy.context.view_layer.update(); bpy.context.view_layer.objects.active=target
    mod=target.modifiers.new('Physical socket opening','BOOLEAN'); mod.operation='DIFFERENCE'; mod.solver='EXACT'; mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutter,do_unlink=True)

ports=[]
def port(kind,name,pos,panel,parent=pc,orient=REAR,label=None):
    fr=frame('Socket_'+name,pos,parent,orient); fr['connector_type']=kind; fr['insertion_axis']='-Z'; fr['occupied']=False
    if kind=='RJ45':
        p=[(-6.2,5),(6.2,5),(6.2,-2.3),(3.2,-2.3),(3.2,-4.9),(-3.2,-4.9),(-3.2,-2.3),(-6.2,-2.3)]
        socket_ring(name+'_shield',p,.8,14,fr)
        for i in range(8):
            wire(name+f'_gold_contact_{i+1}',[(-3.57+i*1.02,4.05,-2),(-3.57+i*1.02,2.9,-8.0),(-3.57+i*1.02,2.9,-12)],.18,gold,fr)
        box(name+'_backstop',(12,8,1),(0,0,-14),dark,fr,.1)
        for x,ma,ledname in [(-7.6,green,'Link'),(7.6,amber,'Activity')]:
            le=box(name+'_LED_'+ledname,(2.0,2.1,1),(x,3.6,.5),ma,fr,.25); le['default_on']=False
        fr['contact_count']=8; fr['mating_depth_m']=.012
    elif kind in ('USB_A_3','USB_A_2'):
        p=rr(12.5,5.5,.45); socket_ring(name+'_shield',p,.45,9,fr)
        box(name+'_tongue',(11.1,1.1,6.0),(0,.65,-4.5),blue if kind=='USB_A_3' else black,fr,.12)
        for i in range(4):box(name+f'_contact_{i+1}',(.65,.1,3.8),(-3.6+i*2.4,.06,-3.9),gold,fr,.03)
        if kind=='USB_A_3':
            for i in range(5):box(name+f'_ss_contact_{i+1}',(.45,.1,1.7),(-3.1+i*1.55,.06,-6.1),gold,fr,.03)
        box(name+'_back',(12.5,5.5,1),(0,0,-9),dark,fr,.1)
    elif kind=='USB_C':
        p=rr(8.4,2.6,1.25,8); socket_ring(name+'_shield',p,.4,7,fr)
        box(name+'_tongue',(6.55,.65,4.5),(0,0,-3.5),black,fr,.28)
        for side in (-1,1):
            for i in range(12):box(name+f'_contact_{side}_{i}',(.18,.04,1.8),(-2.75+i*.5,side*.34,-2.9),gold,fr,.015)
        box(name+'_back',(8.4,2.6,1),(0,0,-7),dark,fr,.1)
        fr['contact_count']=24
    elif kind=='HDMI':
        p=[(-6.9,2.25),(6.9,2.25),(6.9,-.7),(4.9,-2.25),(-4.9,-2.25),(-6.9,-.7)]
        socket_ring(name+'_shield',p,.45,8,fr)
        box(name+'_tongue',(10.3,.85,5.5),(0,0,-4),black,fr,.12)
        for side,count in ((-1,10),(1,9)):
            for i in range(count):box(name+f'_contact_{side}_{i}',(.30,.06,2),((i-(count-1)/2)*.8,side*.455,-3.3),gold,fr,.015)
        box(name+'_back',(13.8,4.5,1),(0,0,-8),dark,fr,.1); fr['contact_count']=19
    elif kind=='DP':
        p=[(-8,2.55),(6.1,2.55),(8,.65),(8,-2.55),(-8,-2.55)]
        socket_ring(name+'_shield',p,.45,8,fr)
        box(name+'_tongue',(12.2,.9,5.5),(0,0,-4),black,fr,.12)
        for side in (-1,1):
            for i in range(10):box(name+f'_contact_{side}_{i}',(.30,.06,2),((i-4.5)*1.05,side*.48,-3.3),gold,fr,.02)
        box(name+'_back',(16,5.1,1),(0,0,-8),dark,fr,.1); fr['contact_count']=20
    elif kind=='C14':
        p=[(-12,7),(-8,10),(8,10),(12,7),(12,-10),(-12,-10)]
        socket_ring(name+'_insulator',p,2.2,16,fr,black)
        for i,(x,y) in enumerate([(-7,-4),(7,-4),(0,4)]):box(name+f'_blade_{i}',(2,4,9),(x,y,-8),silver,fr,.15)
        box(name+'_back',(25,21,1),(0,0,-16),dark,fr,.1); fr['contact_count']=3
    elif kind=='DC':
        p=[(2.8*math.cos(i*math.tau/32),2.8*math.sin(i*math.tau/32)) for i in range(32)]
        socket_ring(name+'_barrel',p,.65,8,fr)
        cyl(name+'_centre_pin',.8,5,(0,0,-4),silver,fr)
    else:
        p=[(1.85*math.cos(i*math.tau/32),1.85*math.sin(i*math.tau/32)) for i in range(32)]
        socket_ring(name+'_jack',p,1,8,fr,silver); cyl(name+'_back',1.8,1,(0,0,-8),dark,fr)
    if panel:cut(panel,p,fr)
    if label:text(name+'_label',label,(0,-max(abs(y) for x,y in p)-4.0,1),2.6,ink,fr)
    fr['opening_width_m']=(max(x for x,y in p)-min(x for x,y in p))*.001
    fr['opening_height_m']=(max(y for x,y in p)-min(y for x,y in p))*.001
    ports.append(fr)
    return fr

def screw(name,pos,orient=REAR,parent=pc):
    f=frame(name+'_mount',pos,parent,orient)
    cyl(name,2.05,.55,(0,0,0),silver,f,segments=20)
    box(name+'_slot1',(2.6,.45,.12),(0,0,.31),dark,f,.05); box(name+'_slot2',(.45,2.6,.12),(0,0,.31),dark,f,.05)

# Business tower: 180 x 330 x 360 mm body, feet raise it 6 mm.
print('Building case and physically open I/O',flush=True)
box('Case_Chassis_Base',(176,326,2),(0,0,7),powder,pc,.65)
box('Case_Top_Cover',(180,330,2),(0,0,365),powder,pc,1)
box('Case_Left_Service_Panel',(2,325,355),(-89,0,187.5),powder,pc,.75)
box('Case_Right_Panel',(2,325,355),(89,0,187.5),powder,pc,.75)
front=box('Case_Front_Fascia',(176,3,354),(0,-164.5,187),black,pc,1)
rear=box('Case_Rear_Steel',(176,2,354),(0,164.5,187),powder,pc,.45)
for x in (-67,67):
    for y in (-125,125):box('Case_Foot',(24,34,6),(x,y,3),rubber,pc,2)
# Broad real grille opening with rounded vertical slats and inner dust screen.
grilleframe=frame('Front_Grille_Mount',(20,-166,170),pc,FRONT)
cut(front,rr(100,250,3),grilleframe)
socket_ring('Front_Grille_Border',rr(100,250,3),1.0,4,grilleframe,alu)
box('Front_Intake_Dust_Filter',(100,250,.6),(0,0,-9),dark,grilleframe,.1)
for i in range(21):box(f'Intake_Fin_{i:02d}',(1.65,241,4),(-46+i*4.6,0,-2),powder,grilleframe,.45)
for j in range(39):box(f'Intake_Mesh_{j:02d}',(98,.4,.35),(0,-120+j*6.3,-6),black,grilleframe,.05)
text('Case_Brand','NETCARE',(-10,-166.25,337),10,ink,pc,(math.pi/2,0,0))
text('Case_Model','DESKSTATION  S6',(-10,-166.28,322),3.5,subink,pc,(math.pi/2,0,0))
# Front power: a distinct clickable part with standard power glyph.
pf=frame('Front_Power_Mount',(-59,-166,331),pc,FRONT)
cyl('Power_Button_Recess',9.3,1,(0,0,0),dark,pf)
button=cyl('Button_PC_Power',7.9,1,(0,0,.5),black,pf); button['action']='power_toggle'; button['travel_m']=.001
wire('Power_Symbol_Arc',[(3.6*math.cos(math.radians(a)),3.6*math.sin(math.radians(a)),1.03) for a in range(135,406,9)],.38,ink,pf)
box('Power_Symbol_Stroke',(.65,4,.15),(0,3.05,1.06),ink,pf,.1)
pl=box('LED_PC_Power',(1.7,1.7,.2),(0,-12,0.6),led,pf,.45); pl['default_on']=False
port('AUDIO','Front_Headset',(-59,-166,289),front,pc,FRONT,'HEADSET')
port('USB_A_3','Front_USB_A1',(-59,-166,257),front,pc,FRONT,'USB 5G')
port('USB_A_3','Front_USB_A2',(-59,-166,232),front,pc,FRONT,'USB 5G')
port('USB_C','Front_USB_C',(-59,-166,204),front,pc,FRONT,'USB-C 10G')
# Rear motherboard I/O, left side when viewed from behind.
io=frame('Rear_IO_Bezel_Mount',(43,165.8,260),pc,REAR)
socket_ring('Rear_IO_Bezel',rr(61,154,2),1.5,1,io,silver)
port('AUDIO','Rear_Line_Out',(43,165.9,322),rear,pc,REAR,'LINE OUT')
port('DP','Rear_DisplayPort',(43,165.9,298),rear,pc,REAR,'DP OUT')
port('HDMI','Rear_HDMI',(43,165.9,276),rear,pc,REAR,'HDMI OUT')
port('USB_A_3','Rear_USB_A1',(58,165.9,252),rear,pc,REAR,'USB 5G')
port('USB_A_3','Rear_USB_A2',(28,165.9,252),rear,pc,REAR,'USB 5G')
port('USB_A_2','Rear_USB_A3',(58,165.9,230),rear,pc,REAR,'USB 2.0')
port('USB_A_2','Rear_USB_A4',(28,165.9,230),rear,pc,REAR,'USB 2.0')
lan=port('RJ45','LAN_RJ45',(43,165.9,202),rear,pc,REAR,'LAN / RJ45')
lan['purpose']='Ethernet cable attachment and cable-test gameplay'
# Fan grille has actual air gaps rather than a solid disc.
fan=frame('Rear_Exhaust_Mount',(-38,165.9,300),pc,REAR)
circle=[(36*math.cos(i*math.tau/64),36*math.sin(i*math.tau/64)) for i in range(64)]
cut(rear,circle,fan); socket_ring('Fan_Shroud',circle,2.0,11,fan,black)
cyl('Fan_Hub',11,5,(0,0,-8),black,fan)
for i in range(7):
    a=i*math.tau/7; pts=[]
    for r,theta in [(10,a),(31,a+.17),(32,a+.57),(12,a+.50)]:pts.append((r*math.cos(theta),r*math.sin(theta)))
    prism(f'Fan_Blade_{i}',pts,-9,-8,black,fan)
for rad in (13,22,31):wire('Fan_Guard_Ring',[(rad*math.cos(i*math.tau/64),rad*math.sin(i*math.tau/64),.65) for i in range(65)],.65,powder,fan)
for a in (45,135):
    v=Vector((math.cos(math.radians(a)),math.sin(math.radians(a))))
    wire('Fan_Guard_Brace',[(-35*v.x,-35*v.y,.55),(35*v.x,35*v.y,.55)],.7,powder,fan)
for x in (-30,30):
    for y in (-30,30):screw('Fan_Screw',(x,y,.5),TOP,fan)
# Expansion covers, chassis screws, and dedicated PSU opening.
for z in (145,126,107):
    cover=frame('Expansion_Cover_Mount',(-2,166,z),pc,REAR)
    box('Expansion_Blank',(136,14,1),(0,0,0),alu,cover,.5)
    for u in range(-58,59,7):box('Expansion_Vent',(3.5,8,.1),(u,0,.56),dark,cover,.7)
    screw('Expansion_Screw',(-64,0,.5),TOP,cover)
port('C14','AC_Power_Inlet',(38,165.9,55),rear,pc,REAR,'AC INPUT')
rock=frame('PSU_Switch_Mount',(2,166,55),pc,REAR)
box('PSU_Switch_Bezel',(14,20,1),(0,0,.2),dark,rock,1)
sw=box('Button_PSU_Rocker',(10,16,1.6),(0,0,1),black,rock,.6); sw['action']='psu_switch'; sw['default_state']='off'
text('PSU_On_Mark','I',(0,4.5,1.87),3.5,ink,rock); text('PSU_Off_Mark','O',(0,-4.5,1.87),3.5,ink,rock)
for u in range(13):box('PSU_Vent_Slot',(2,1,29),(-72+u*3.1,165.58,55),dark,pc,.45)
for x in (-79,79):
    for z in (18,354):screw('Chassis_Screw',(x,165.9,z))
text('Rear_Model_Label','NETCARE  S6  /  LAB EQUIPMENT',(-27,166,176),3.2,ink,pc,(math.pi/2,0,math.pi))

# Thin bezel 24-inch class display. No external UI texture; screen surface is separate.
print('Building monitor',flush=True)
back=box('Monitor_Back_Housing',(540,32,317),(0,0,317),black,mon,6)
box('Monitor_Bezel',(540,3,317),(0,-17.2,317),black,mon,3)
screen=box('Monitor_Display_Surface',(526,1.2,296),(0,-19.3,321),glass,mon,1.4)
screen['purpose']='Replace material with Godot SubViewport texture'; screen['aspect_ratio']='16:9'; screen['display_state']='off'
box('Monitor_Chin',(533,2,14),(0,-19.2,165.7),black,mon,1)
text('Monitor_Logo','NETCARE',(0,-20.3,165),4,subink,mon,(math.pi/2,0,0))
base=box('Monitor_Stand_Base',(230,185,8),(0,22,10),alu,mon,6)
for x in (-80,80):
    for y in (-45,85):box('Monitor_Stand_Foot',(26,18,6),(x,y,3),rubber,mon,2)
neck=box('Monitor_Stand_Upright',(47,35,252),(0,26,143),alu,mon,5)
# Real cable management hole through stand.
cf=frame('Monitor_Cable_Route',(0,8,108),mon,FRONT)
cut(neck,rr(24,39,10),cf)
# Above cut does not go through full stand: extend it with a dedicated cutter.
cutob=prism('TEMP_stand_hole',rr(24,39,10),-50,5,None,cf)
bpy.context.view_layer.update(); bpy.context.view_layer.objects.active=neck
mod=neck.modifiers.new('Through cable route','BOOLEAN'); mod.operation='DIFFERENCE'; mod.object=cutob
bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(cutob,do_unlink=True)
box('Monitor_VESA_Cover',(112,18,112),(0,21,306),black,mon,4)
for x in (-50,50):
    for z in (256,356):screw('Monitor_VESA_Screw',(x,32,z),REAR,mon)
for x in range(-210,211,12):box('Monitor_Top_Vent',(5,1,2.5),(x,16.4,452),dark,mon,.4)
# Visible labelled rear I/O with genuine cut-outs into lower housing.
port('HDMI','Monitor_HDMI',(-173,16.6,227),back,mon,REAR,'HDMI IN')
port('DP','Monitor_DP',(-127,16.6,227),back,mon,REAR,'DP IN')
port('DC','Monitor_DC_IN',(175,16.6,227),back,mon,REAR,'DC 19V')
text('Monitor_Rear_Model','NETCARE  /  VIEW 24',(168,17.0,307),5,subink,mon,(math.pi/2,0,math.pi))
mf=frame('Monitor_Controls_Mount',(-241,17,177),mon,REAR)
power=cyl('Button_Monitor_Power',3.8,1.3,(0,0,1),black,mf); power['action']='monitor_power'
text('Monitor_Power_Label','POWER',(0,8,1),2.3,ink,mf)
joy=cyl('Button_Monitor_OSD',3.8,3,(0,21,1),black,mf); joy['action']='osd_joystick'
text('Monitor_OSD_Label','MENU',(0,29,1),2.3,ink,mf)

# Standard ANSI 104-key keyboard, including real modifier widths and navigation block.
print('Building ANSI 104-key layout',flush=True)
kbottom=box('Keyboard_Bottom_Shell',(446,146,9),(0,0,6.5),black,kb,4)
ktop=box('Keyboard_Upper_Frame',(444,144,8),(0,0,14),powder,kb,3)
for x in (-182,182):
    for y in (-50,50):box('Keyboard_Rubber_Foot',(26,9,2),(x,y,1),rubber,kb,2)
keys=[]; legends=[]; key_bounds=[]; key_parts={}
P=19.05; left=-215
def key(label,x,y,u=1,h=1,ident=None,size=None):
    z=22; w=u*P-2.1; d=h*P-2.1
    safe=(ident or label).replace('\n','_')
    o=box('Key_'+safe, (w,d,5),(x,y,z),black,kb,1.1)
    o['key']=ident or label; o['press_axis']='-Z'; o['travel_m']=.0015; keys.append(o)
    key_parts[o.name]=[o]
    if label:
        siz=size or (3.4 if len(label)>3 else 4.0)
        tx=text('Legend_'+o.name,label,(x,y,24.54),siz,ink,kb); tx.data.space_line=.82; legends.append(tx);key_parts[o.name].append(tx)
    key_bounds.append((o.name,x-w/2,x+w/2,y-d/2,y+d/2))
    return o
def row(spec,y):
    x=left
    for i,(label,u) in enumerate(spec):key(label,x+u*P/2,y,u,ident=f'R{y}_{i}_{label}'); x+=u*P
    assert abs(x-left-15*P)<1e-5
row([(x,1) for x in ['~\n`','!\n1','@\n2','#\n3','$\n4','%\n5','^\n6','&\n7','*\n8','(\n9',')\n0','_\n-','+\n=']]+[('Backspace',2)],29)
row([('Tab',1.5)]+[(x,1) for x in ['Q','W','E','R','T','Y','U','I','O','P','{\n[','}\n]']]+[('|\n\\',1.5)],9.95)
row([('Caps Lock',1.75)]+[(x,1) for x in ['A','S','D','F','G','H','J','K','L',':\n;','"\n\'']]+[('Enter',2.25)],-9.1)
row([('Shift',2.25)]+[(x,1) for x in ['Z','X','C','V','B','N','M','<\n,','>\n.','?\n/']]+[('Shift',2.75)],-28.15)
row([('Ctrl',1.25),('Win',1.25),('Alt',1.25),('',6.25),('Alt',1.25),('Win',1.25),('Menu',1.25),('Ctrl',1.25)],-47.2)
key('Esc',left+P/2,58)
for i in range(12):
    x=left+P*(2.5+i+(i//4)*.5); key('F'+str(i+1),x,58)
nav=93.4; num=155.7
for i,l in enumerate(['PrtSc','ScrLk','Pause']):key(l,nav+i*P,58,size=2.8)
for y,labels in [(29,['Insert','Home','PgUp']),(9.95,['Delete','End','PgDn'])]:
    for i,l in enumerate(labels):key(l,nav+i*P,y,size=2.8)
key('↑',nav+P,-28.15)
for i,l in enumerate(['←','↓','→']):key(l,nav+i*P,-47.2)
for i,l in enumerate(['Num\nLock','/','*','-']):key(l,num+i*P,29,size=3)
for y,labels in [(9.95,['7','8','9']),(-9.1,['4','5','6']),(-28.15,['1','2','3'])]:
    for i,l in enumerate(labels):key(l,num+i*P,y)
key('+',num+3*P,.425,h=2)
key('Enter',num+3*P,-37.675,h=2,size=2.7)
key('0',num+P/2,-47.2,u=2); key('.',num+2*P,-47.2)
assert len(keys)==104,len(keys)
for o in keys:
    if o['key'].endswith('_F') or o['key'].endswith('_J'):
        bar=box('Tactile_Home_Bar',(4,.7,.22),(o.location.x*1000,o.location.y*1000-6.5,24.62),subink,kb,.1)
        key_parts[o.name].append(bar)
for i,label in enumerate(['NUM','CAPS','SCROLL']):
    x=160+i*24
    box('Keyboard_LED_'+label,(2.4,1.5,.15),(x,57,18.1),led,kb,.4)
    text('Keyboard_Status_'+label,label,(x,64,18.15),2.1,subink,kb)
kb['keyboard_layout']='ANSI US English 104 keys'; kb['key_count']=104
# Rear USB-C receptacle provides a cable anchor without a baked-in cable pose.
kpanel=box('Keyboard_Rear_Port_Inset',(32,1,8),(0,72.5,12),black,kb,.5)
kport=port('USB_C','Keyboard_USB_C',(0,73.1,12),kpanel,kb,REAR,None)
cut(ktop,rr(8.4,2.6,1.25,8),kport);cut(kbottom,rr(8.4,2.6,1.25,8),kport)

# Modern ergonomic mouse: smooth loft with separate shaped left/right buttons.
print('Building mouse',flush=True)
def mouse_shape(y):
    t=(y+59)/118
    width=35.5*(max(.0001,math.sin(math.pi*t))**.36)
    height=8+29*(max(0,math.sin(math.pi*t))**.7)
    return width,height
# Cross-section rings around an asymmetric low dome; underside remains flat.
v=[]; f=[]; ny=32; nx=32
for i in range(ny+1):
    y=-58.7+117.4*i/ny; w,h=mouse_shape(y)
    for j in range(nx):
        a=math.tau*j/nx; x=w*math.cos(a); z=7+(h-7)*max(math.sin(a),0)+3*min(math.sin(a),0)
        v.append((x,y,z))
for i in range(ny):
    for j in range(nx):a=i*nx+j;b=i*nx+(j+1)%nx;f.append((a,b,b+nx,a+nx))
f.extend([tuple(reversed(range(nx))),tuple(range(ny*nx,(ny+1)*nx))])
mo=mesh('Mouse_Palm_Shell',v,f,black,mouse)
for p in mo.data.polygons:p.use_smooth=True
box('Mouse_Base',(61,100,4),(0,0,3),rubber,mouse,1.8)
for side in (-1,1):
    verts=[]; faces=[]
    for i in range(18):
        y=5+i*2.85;w,h=mouse_shape(y)
        for j in range(9):
            x=side*(1.2+(w*.88-1.2)*j/8);z=7+(h-7)*math.sqrt(max(0,1-(x/w)**2))+.42
            verts.append((x,y,z))
    for i in range(17):
        for j in range(8):a=i*9+j;faces.append((a,a+1,a+10,a+9))
    bt=mesh('Button_Mouse_Left' if side<0 else 'Button_Mouse_Right',verts,faces,powder,mouse)
    for p in bt.data.polygons:p.use_smooth=True
    so=bt.modifiers.new('Button thickness','SOLIDIFY');so.thickness=.00055
    bt['action']='left_click' if side<0 else 'right_click'
wheel=cyl('Button_Mouse_ScrollWheel',8,7,(0,27,30),rubber,mouse,(0,math.pi/2,0),40);wheel['action']='scroll_middle_click'
for i in range(28):
    a=i*math.tau/28
    rib=box('Wheel_Rib',(7.2,1,.7),(0,27+8*math.cos(a),30+8*math.sin(a)),black,mouse,.15);rib.rotation_euler.x=a-math.pi/2
text('Mouse_Brand','NETCARE',(0,-28,35.7),3.3,subink,mouse)
for x in (-28,28):
    for y in range(-24,15,4):box('Mouse_Side_Grip',(.55,1.2,7),(x,y,12),dark,mouse,.2)
for y in (-39,39):box('Mouse_PTFE_Foot',(37,10,1),(0,y,.5),silver,mouse,.45)
box('Mouse_Optical_Sensor',(10,12,.7),(0,0,1.2),dark,mouse,.3)
mf=frame('Mouse_Rear_Charge_Mount',(0,59,10),mouse,REAR)
# Socket is part of the nose; close housing tip behind the socket can be removed for plugging animation.
port('USB_C','Mouse_USB_C',(0,59,10),None,mouse,REAR,None)
ms=box('Button_Mouse_Underside_Switch',(4,9,.6),(16,-20,1.1),black,mouse,.2);ms['action']='mouse_on_off'
mouse['power']='Rechargeable wireless mouse, USB-C at nose'; mouse['interaction']='separate left/right buttons and scroll wheel'

# Convert / merge static parts by component, keep controls, keys, markers and indicators independent.
print('Preparing editable assemblies',flush=True)
def convert(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    if o.type!='MESH':bpy.ops.object.convert(target='MESH');o=bpy.context.object
    for m in list(o.modifiers):
        try:bpy.ops.object.modifier_apply(modifier=m.name)
        except RuntimeError:pass
    o.select_set(False);return o
for o in list(asset.objects):
    if o.type in ('MESH','CURVE','FONT'):convert(o)
bpy.context.view_layer.update()
for keyname,parts in key_parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();parts[0].select_set(False)
def belongs(o,comp):
    p=o.parent
    while p:
        if p==comp:return True
        p=p.parent
    return False
for comp in (pc,mon,kb,mouse):
    parts=[o for o in asset.objects if o.type=='MESH' and belongs(o,comp) and not o.name.startswith(('Button_','Key_','LED_','Keyboard_LED_','Monitor_Display_Surface')) and '_LED_' not in o.name]
    if parts:
        for o in parts:
            matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=comp.name+'_StaticDetails'
        bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');o.parent=comp
        o.select_set(False)
# Each key includes its legend; no runtime animation is supplied in this file.
pc.location=mm((470,90,0));mon.location=mm((-80,85,0));kb.location=mm((-90,-180,0));mouse.location=mm((235,-174,0))
for comp in (pc,mon,kb,mouse):comp['tabletop_origin_z']=0.0

# UV unwrap mesh geometry for future baking/editing. Screen has a standard full-frame UV map.
for o in list(asset.objects):
    if o.type=='MESH' and not o.data.uv_layers:
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
screen=bpy.data.objects.get('Monitor_Display_Surface')
if screen:
    uv=screen.data.uv_layers.active
    for f in screen.data.polygons:
        for li in f.loop_indices:
            co=screen.data.vertices[screen.data.loops[li].vertex_index].co
            uv.data[li].uv=(co.x/.526+.5,co.z/.296+.5)

# Studio renders are saved separately; asset and studio collections are clearly separated.
floor=box('Studio_Backdrop',(12000,12000,10),(0,0,-5),mat('Studio | slate',(.075,.09,.11),0,.58),None,0);link(floor,studio)
camera_data=bpy.data.cameras.new('Camera_Hero'); camera=bpy.data.objects.new('Camera_Hero',camera_data);studio.objects.link(camera)
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,pos,power,size,col,target=(.15,0,.2)):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=col
    o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=pos;aim(o,target);return o
area('Key_Softbox',(-.6,-.6,1.25),38,.95,(1,.92,.82))
area('Fill_Softbox',(1.0,-.3,.8),22,.85,(.78,.88,1))
area('Edge_Softbox',(.45,.8,1.1),45,.75,(.8,.90,1))
world=bpy.data.worlds.new('Neutral Studio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.20,.24,1);world.node_tree.nodes['Background'].inputs[1].default_value=.25
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.cycles.max_bounces=6;scene.cycles.diffuse_bounces=3;scene.cycles.glossy_bounces=3
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=0
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB';scene.render.resolution_percentage=100
scene.render.film_transparent=False
shots={
 'hero':((1.26,-1.72,1.0),(.12,.015,.24),55,(1600,1100)),
 'rear_ports':((.81,.86,.52),(.47,.250,.235),63,(1200,1250)),
 'lan_closeup':((.505,.407,.257),(.513,.256,.202),63,(1300,950)),
 'keyboard':((-.07,-.40,.57),(-.02,-.17,.01),48,(1500,800)),
 'front_ports':((.27,-.53,.40),(.416,-.076,.267),65,(1050,1300)),
 'monitor_rear':((-.63,.83,.47),(-.08,.11,.28),58,(1300,950)),
}
def setshot(key):
    pos,target,lens,res=shots[key];camera.location=pos;aim(camera,target);camera.data.lens=lens;scene.camera=camera
    scene.render.resolution_x,scene.render.resolution_y=res;scene.render.filepath=str(R/f'teacher_computer_v2_{key}.png')
setshot('hero')
for screen_area in bpy.context.screen.areas if bpy.context.screen else []:
    if screen_area.type=='VIEW_3D':
        screen_area.spaces.active.region_3d.view_distance=1.8
        screen_area.spaces.active.region_3d.view_location=(.10,0,.2)
        screen_area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        screen_area.spaces.active.shading.type='MATERIAL'
bpy.context.view_layer.update()
tris=0
for o in asset.objects:
    if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
scene['asset_triangle_count']=tris;scene['asset_description']='NetCare contemporary office desktop; true socket openings; ANSI 104 keys; tabletop assemblies'
notes=bpy.data.texts.new('READ_ME | Teacher Desktop v2')
notes.write('NetCare educational computer model. Original design, real-device-informed proportions.\nFour component roots under TeacherComputerSet_Root. Metres; tabletop Z=0.\nAll connectors are receptacles with local +Z outward, insert along -Z. Socket_* empties are attachment anchors.\nLAN: 8 contacts; USB-C: 24 contacts; HDMI: 19; DP: 20. Power and link LEDs OFF by default.\n104 US ANSI keycaps; labels converted to geometry, no font dependency. Display material is replaceable; front UV fills 0..1.\nButtons are separate, interaction metadata supplied. Godot logic, collisions and LODs are not included.\nStudio collection holds lights/camera/background and must be excluded from game export.\nUnused USB ports and all connectors are empty for inspection; cables are not part of this set.\n')
# Purge unused blocks (including startup library references).
bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
print('BUILD_SAVED',OUT,'TRIANGLES',tris,'KEYS',len(keys),'PORTS',len(ports),flush=True)
audit={'triangles':tris,'key_count':len(keys),'ports':[{ 'name':p.name,'kind':p['connector_type'],'location':list(p.matrix_world.translation),'outward':list(p.matrix_world.to_3x3()@Vector((0,0,1)))} for p in ports],'key_bounds':key_bounds}
(TMP/'build_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
for shot in shots:
    setshot(shot);print('RENDER_START',shot,flush=True);bpy.ops.render.render(write_still=True);print('RENDER_DONE',shot,flush=True)
setshot('hero');bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
print('COMPLETE',flush=True)
