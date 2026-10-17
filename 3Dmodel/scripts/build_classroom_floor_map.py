"""Extend the saved classroom into the user's floor plan, preserving original geometry."""
import bpy, bmesh, math, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

BASE=Path('D:/NetSim3D/3Dmodel')
TMP=BASE/'temp/classroom_floor_map'
TMP.mkdir(parents=True,exist_ok=True)
OUT=TMP/'classroom_shell_map.blend'
RENDERS=BASE/'ใช้ร่วมกัน/renders'
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1
H=3.2
TH=.15
SX=12.15/355
SY=19.65/621
def X(px): return -6.075+(px-578)*SX
def Y(py): return 9.825+(1190-py)*SY
XL,XC,XR,XE=X(135),X(487),X(578),X(933)
YB,YC,YF,YST,YMA,YFE,YTOP=Y(1811),Y(1190),Y(536),Y(739),Y(963),Y(1190),Y(102)
XS=X(392)
YS=Y(332)

def fingerprint(o):
    h=hashlib.sha256(str([list(r) for r in o.matrix_world]).encode())
    if o.type=='MESH':
        for v in o.data.vertices: h.update(str(tuple(v.co)).encode())
    return h.hexdigest()
originals={o.name:fingerprint(o) for o in scene.objects if o.type=='MESH'}

def collection(name,parent=None):
    c=bpy.data.collections.new(name)
    (parent.children if parent else scene.collection.children).link(c)
    return c
MAP=collection('MAP | Floor 01')
WALLS=collection('01 | Walls and frames',MAP)
FLOORS=collection('02 | Floors',MAP)
DOORS=collection('03 | Doors',MAP)
STAIRS=collection('04 | Stairs up and down',MAP)
IT=collection('05 | IT Support desks',MAP)
SIGNS=collection('06 | Room signs',MAP)
CEIL=collection('07 | Ceilings - toggle for interior',MAP)
GUIDES=collection('08 | Plan labels - not game geometry',MAP)
LIGHTS=collection('09 | Interior lighting',MAP)
PRESENT=collection('10 | Map cameras and preview lighting',MAP)
REGIONS=collection('11 | Room and spawn markers',MAP)

def mat(name,color,rough=.65,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
wall=bpy.data.materials['MAT_Wall_Warm_White']
ceilingmat=bpy.data.materials['MAT_Ceiling_White']
wood=bpy.data.materials['MAT_Door_Warm_Wood']
frame_mat=bpy.data.materials['MAT_Frame_Dark_Gray']
trim=mat('MAP | Skirting',(.30,.34,.37))
floor_it=mat('MAP | IT pale warm grey',(.60,.65,.65))
floor_storage=mat('MAP | Storage concrete',(.38,.43,.47))
floor_corridor=mat('MAP | Corridor stone',(.57,.58,.54))
floor_staff=mat('MAP | Staff pale sage',(.64,.70,.64))
floor_server=mat('MAP | Server cool grey',(.39,.51,.59))
floor_toilet=mat('MAP | Washroom pale ceramic',(.63,.72,.73))
floor_class=mat('MAP | Background classroom',(.68,.69,.66))
metal=mat('MAP | Brushed handrails',(.29,.36,.40),.3,.65)
stair_mat=mat('MAP | Stair concrete',(.48,.51,.53))
edge_mat=mat('MAP | Stair anti-slip edge',(.16,.19,.20))
ink=mat('MAP | Sign white',(.92,.95,.93))
labelink=mat('MAP | Plan lettering',(.07,.13,.16))
navy=mat('MAP | Sign midnight blue',(.035,.095,.13))
teal=mat('MAP | IT accent',(.06,.32,.33))
whiteboard=mat('MAP | Whiteboard',(.87,.90,.89),.3)

def link(o,c):
    for old in list(o.users_collection): old.objects.unlink(o)
    c.objects.link(o)
    return o
def box(name,size,pos,ma,c=WALLS,bevel=0,parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    link(o,c)
    if ma:o.data.materials.append(ma)
    if parent:o.parent=parent
    if bevel:
        m=o.modifiers.new('Rounded edges','BEVEL');m.width=bevel;m.segments=2
        bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');m.keep_sharp=True
    return o
def empty(name,c,pos=(0,0,0),parent=None):
    o=bpy.data.objects.new(name,None);c.objects.link(o);o.location=pos;o.parent=parent
    o.empty_display_type='PLAIN_AXES';o.empty_display_size=.18
    return o
font=bpy.data.fonts.load('C:/Windows/Fonts/tahoma.ttf')
def text(name,body,pos,size,ma,c=SIGNS,rot=(0,0,0)):
    d=bpy.data.curves.new(name,'FONT');d.body=body;d.font=font;d.size=size;d.align_x='CENTER';d.align_y='CENTER';d.resolution_u=3
    o=bpy.data.objects.new(name,d);c.objects.link(o);o.location=pos;o.rotation_euler=rot;d.materials.append(ma)
    bpy.context.view_layer.objects.active=o;bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    bpy.ops.object.convert(target='MESH');o.select_set(False)
    return o
def bar(name,a,b,r=.025,ma=metal,c=STAIRS):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(ma);link(o,c)
    return o

room_info=[]
door_info=[]
wall_objs=[]
def floor(name,x0,x1,y0,y1,material,z=0,c=FLOORS):
    return box(name,(x1-x0,y1-y0,.15),((x0+x1)/2,(y0+y1)/2,z-.075),material,c)
def ceil(name,x0,x1,y0,y1):
    return box(name,(x1-x0,y1-y0,.15),((x0+x1)/2,(y0+y1)/2,H+.075),ceilingmat,CEIL)
def region(name,thai,bounds,center=None):
    x0,x1,y0,y1=bounds
    center=center or ((x0+x1)/2,(y0+y1)/2)
    e=empty('Room_'+name,REGIONS,(*center,.02));e['room_id']=name;e['label_th']=thai;e['bounds_m']=list(bounds)
    room_info.append({'id':name,'label':thai,'bounds':list(bounds),'center':center})
    text('Plan_'+name,thai,(*center,.025),.64,labelink,GUIDES)
    return e
def wall_line(name,axis,const,lo,hi,doors=()):
    # Door gaps are constructed from wall segments and lintels, never a solid wall behind a leaf.
    intervals=sorted((mid-width/2,mid+width/2) for mid,width in doors)
    cursor=lo
    def piece(a,b,z0,z1,suffix):
        if b-a < .001:return
        size=(TH,b-a,z1-z0) if axis=='Y' else (b-a,TH,z1-z0)
        pos=(const,(a+b)/2,(z0+z1)/2) if axis=='Y' else ((a+b)/2,const,(z0+z1)/2)
        ob=box(name+suffix,size,pos,wall);wall_objs.append(ob)
        if z0==0:
            for side in (-1,1):
                tpos=(const+side*(TH/2+.012),(a+b)/2,.05) if axis=='Y' else ((a+b)/2,const+side*(TH/2+.012),.05)
                tsize=(.02,b-a,.10) if axis=='Y' else (b-a,.02,.10)
                box(name+suffix+'_Skirting',tsize,tpos,trim,WALLS,.003)
    for n,(a,b) in enumerate(intervals):
        assert lo<a<b<hi,(name,a,b,lo,hi)
        piece(cursor,a,0,H,'_Segment_'+str(n))
        piece(a,b,2.2,H,'_Header_'+str(n))
        cursor=b
    piece(cursor,hi,0,H,'_End')

def door(name,x,y,inside,thai,english,width=1.16):
    # Hinge at the north jamb; open 65 degrees into its room.
    for side in (-1,1):
        box(name+'_Jamb',(TH+.05,.06,2.2),(x,y+side*(width/2-.03),1.1),frame_mat,DOORS,.004)
    box(name+'_Frame_Header',(TH+.05,width,.06),(x,y,2.17),frame_mat,DOORS,.004)
    hinge=empty('Door_'+name+'_Hinge',DOORS,(x,y+width/2-.06,.015))
    hinge.rotation_euler.z=math.radians(65*inside)
    hinge['interaction']='hinged_door';hinge['closed_z_rotation']=0.;hinge['open_z_rotation']=hinge.rotation_euler.z
    leaf=box(name+'_Leaf',(.045,width-.12,2.12),(0,-(width-.12)/2,1.06),wood,DOORS,.012,hinge)
    for side in (-1,1):
        box(name+'_Kick_Plate',(.005,width-.22,.19),(side*.025,-(width-.12)/2,.2),metal,DOORS,.002,hinge)
        box(name+'_Handle_Base',(.016,.055,.17),(side*.031,-width+.25,1.00),metal,DOORS,.006,hinge)
        box(name+'_Lever',(.06,.15,.024),(side*.06,-width+.30,1.02),metal,DOORS,.008,hinge)
    # Corridor-facing sign; its text's local axes map right along corridor, up along world Z.
    outward=-inside
    signx=x+outward*(TH/2+.019)
    plaque=box(name+'_Sign',(.032,1.75,.32),(signx,y,2.57),navy,SIGNS,.014)
    basis=Matrix(((0,0,outward),(outward,0,0),(0,1,0)))
    text(name+'_TH',thai,(signx+outward*.020,y,2.62),.135,ink,SIGNS,basis.to_euler())
    text(name+'_EN',english,(signx+outward*.021,y,2.48),.062,ink,SIGNS,basis.to_euler())
    door_info.append({'name':name,'x':x,'y':y,'width':width,'height':2.2,'inside_sign':inside})

# Use the existing classroom at its exact saved coordinates as the lower-right room.
old_ceiling=bpy.data.objects['Ceiling_Slab_150mm']
link(old_ceiling,CEIL)
floor('Corridor_Floor',XC+TH/2,XR-TH/2,YB-TH/2,YTOP+TH/2,floor_corridor)
ceil('Corridor_Ceiling',XC,XR,YB,YTOP)
region('Corridor','ทางเดินกลาง',(XC,XR,YB,YTOP),((XC+XR)/2,14.8))
bpy.data.objects['Plan_Corridor'].rotation_euler.z=math.pi/2
for xx in (XC+.23,XR-.23):box('Corridor_Edge_Inlay',(.04,YTOP-YB,.002),(xx,(YTOP+YB)/2,.002),trim,FLOORS)

floor('Staff_Room_Floor',XR+TH/2,XE+TH/2,YC+TH/2,YF-TH/2,floor_staff)
floor('Server_Room_Floor',XR+TH/2,XE+TH/2,YF-TH/2,YTOP+TH/2,floor_server)
ceil('Staff_Room_Ceiling',XR,XE,YC,YF);ceil('Server_Room_Ceiling',XR,XE,YF,YTOP)
region('Staff','ห้องพักครู',(XR,XE,YC,YF))
region('Server','ห้อง Server ss.',(XR,XE,YF,YTOP))
region('Classroom','ห้องเรียนคอมพิวเตอร์',(XR,XE,YB,YC),(0,-8.9))

floor('Background_Classroom_Floor',XL-TH/2,XC-TH/2,YB-TH/2,YC-TH/2,floor_class)
floor('Female_Washroom_Floor',XL-TH/2,XC-TH/2,YC-TH/2,YMA-TH/2,floor_toilet)
floor('Male_Washroom_Floor',XL-TH/2,XC-TH/2,YMA-TH/2,YST-TH/2,floor_toilet)
for n,a,b in [('Background_Classroom',YB,YC),('Female_Washroom',YC,YMA),('Male_Washroom',YMA,YST)]:ceil(n+'_Ceiling',XL,XC,a,b)
region('BackgroundClass','ห้องเรียน\nประกอบฉาก',(XL,XC,YB,YC))
region('FemaleWC','ห้องน้ำหญิง',(XL,XC,YC,YMA))
region('MaleWC','ห้องน้ำชาย',(XL,XC,YMA,YST))

# L-shaped IT room. The storage room occupies its southwest corner.
floor('IT_Support_North_Floor',XL-TH/2,XC-TH/2,YS,YTOP+TH/2,floor_it)
floor('IT_Support_Return_Floor',XS+TH/2,XC-TH/2,YF+TH/2,YS,floor_it)
floor('Equipment_Storage_Floor',XL-TH/2,XS+TH/2,YF+TH/2,YS,floor_storage)
ceil('IT_North_Ceiling',XL,XC,YS,YTOP)
ceil('IT_Return_Ceiling',XS,XC,YF,YS)
ceil('Storage_Ceiling',XL,XS,YF,YS)
region('ITSupport','ห้อง IT SUPPORT',(XL,XC,YF,YTOP),(X(300),Y(245)))
region('Storage','ห้องเก็บอุปกรณ์',(XL,XS,YF,YS))

left_doors=[(Y(1253),1.16),(Y(1026),1.16),(Y(780),1.16),(Y(395),1.16)]
right_doors=[(Y(688),1.16),(Y(379),1.16)]
wall_line('Left_Outer_Wall','Y',XL,YB,YTOP)
wall_line('Left_Bottom_Wall','X',YB,XL,XC)
wall_line('Left_Top_Wall','X',YTOP,XL,XC)
wall_line('Left_Corridor_South','Y',XC,YB,YST,doors=left_doors[:3])
wall_line('Left_Corridor_North','Y',XC,YF,YTOP,doors=left_doors[3:])
for n,y in [('Background_Female_Partition',YC),('Female_Male_Partition',YMA),('Male_Stair_Partition',YST),('Stair_IT_Partition',YF)]:
    wall_line(n,'X',y,XL,XC)
wall_line('Storage_North_Wall','X',YS,XL,XS)
wall_line('Storage_East_Wall','Y',XS,YF,YS,doors=[(Y(379),1.16)])
wall_line('Right_Outer_Extension','Y',XE,YC+TH/2,YTOP)
wall_line('Right_Corridor_Extension','Y',XR,YC+TH/2,YTOP,doors=right_doors)
wall_line('Staff_Server_Partition','X',YF,XR,XE)
wall_line('Right_Top_Wall','X',YTOP,XR,XE)
wall_line('Corridor_North_End','X',YTOP,XC,XR)
wall_line('Corridor_South_End','X',YB,XC,XR)
for args in [('BackgroundClass',XC,Y(1253),-1,'ห้องเรียนประกอบฉาก','BACKGROUND CLASSROOM'),('FemaleWC',XC,Y(1026),-1,'ห้องน้ำหญิง','WOMEN'),('MaleWC',XC,Y(780),-1,'ห้องน้ำชาย','MEN'),('ITSupport',XC,Y(395),-1,'IT SUPPORT','TECHNICAL SUPPORT'),('Storage',XS,Y(379),-1,'ห้องเก็บอุปกรณ์','EQUIPMENT STORAGE'),('Staff',XR,Y(688),1,'ห้องพักครู','TEACHERS ROOM'),('Server',XR,Y(379),1,'ห้อง Server ss.','SERVER ROOM')]:
    door(*args)

# Keep the existing corrected classroom door untouched; add its corridor sign only.
box('Classroom_Door_Sign',(.032,1.75,.32),(XR-.094,8.45,2.57),navy,SIGNS,.014)
basis=Matrix(((0,0,-1),(-1,0,0),(0,1,0)))
text('Classroom_Door_TH','ห้องเรียนคอมพิวเตอร์',(XR-.113,8.45,2.62),.12,ink,SIGNS,basis.to_euler())
text('Classroom_Door_EN','COMPUTER CLASSROOM',(XR-.114,8.45,2.48),.065,ink,SIGNS,basis.to_euler())

# Desk placements in IT follow the three green rectangles in the plan.
teacher=bpy.data.objects['TeacherDesk']
for name,px,py,thai in [('IT_HeadDesk',230,157,'โต๊ะหัวหน้างาน'),('IT_PlayerDesk',359,153,'โต๊ะผู้เล่น'),('IT_SpareDesk',359,286,'โต๊ะว่าง')]:
    o=teacher.copy();o.data=teacher.data;IT.objects.link(o);o.name=name
    o.location=(X(px),Y(py),0);o.rotation_euler=(0,0,math.pi/2)
    o['role']=thai
    text('Plan_'+name,thai,(X(px)+1.3,Y(py),.03),.26,labelink,GUIDES,(0,0,math.pi/2))

# Board shown on the reference plan, mounted to the classroom front wall.
box('Classroom_Board_Frame',(3.7,.06,1.35),(0,9.68,1.80),frame_mat,IT,.018)
box('Classroom_Whiteboard',(3.60,.015,1.25),(0,9.641,1.80),whiteboard,IT,.006)
box('Classroom_Board_Tray',(3.60,.14,.025),(0,9.59,1.12),metal,IT,.008)

# Append only the computer asset collection. Its studio lights and floor are excluded.
with bpy.data.libraries.load(str(BASE/'ใช้ร่วมกัน/blend/teacher_computer_set.blend'),link=False) as (src,dst):
    assert 'ASSET | NetCare Desktop v2' in src.collections
    dst.collections=['ASSET | NetCare Desktop v2']
computer=dst.collections[0]
computer.name='Teacher Computer | On desk'
scene.collection.children.link(computer)
root=bpy.data.objects['TeacherComputerSet_Root']
root.location=(teacher.location.x,teacher.location.y,.7505)
root.rotation_euler=(0,0,math.pi)
root['placement']='On teacher desk; display and keyboard face teacher at north side'

# Two straight flights start at the common landing beside the corridor.
# Their terminal landings mark adjacent floor levels; additional floors are not fabricated.
stair_mid=(YST+YF)/2
east=XC-.12
start=XC-2.10
run=6.30
west=start-run
count=20
rise=3.35/count
tread=run/count
flight_width=2.35
y_up=stair_mid+1.48
y_down=stair_mid-1.48
floor('Stair_Main_Landing',start,east,YST+TH/2,YF-TH/2,stair_mat,c=STAIRS)
floor('Stair_West_Service_Strip',XL+TH/2,west-1.25,YST+TH/2,YF-TH/2,stair_mat,c=STAIRS)
for suffix,ya,yb in [('South_Edge',YST+TH/2,y_down-flight_width/2),('Between_Flights',y_down+flight_width/2,y_up-flight_width/2),('North_Edge',y_up+flight_width/2,YF-TH/2)]:
    floor('Stair_'+suffix,west-1.25,start,ya,yb,stair_mat,c=STAIRS)
for name,cy,direction in [('UP',y_up,1),('DOWN',y_down,-1)]:
    for i in range(count):
        top=(i+1)*rise*direction
        cx=start-(i+.5)*tread
        # Closed risers supported by a continuous sloping underside.
        bottom=top-rise-.14
        step=box('Stair_'+name+'_Step_%02d'%(i+1),(tread+.001,flight_width,top-bottom),(cx,cy,(top+bottom)/2),stair_mat,STAIRS,.003)
        box('Stair_'+name+'_Nosing_%02d'%(i+1),(.04,flight_width,.007),(cx+tread/2-.02,cy,top+.004),edge_mat,STAIRS,.002)
    floor('Stair_'+name+'_Terminal_Landing',west-1.25,west,cy-flight_width/2,cy+flight_width/2,stair_mat,3.35*direction,STAIRS)
    endz=3.35*direction
    for yy in (cy-flight_width/2+.06,cy+flight_width/2-.06):
        for xx in (west-1.19,west):
            bar('Stair_'+name+'_Landing_Post',(xx,yy,endz),(xx,yy,endz+1.0),.021)
        bar('Stair_'+name+'_Landing_Rail',(west-1.19,yy,endz+1.0),(west,yy,endz+1.0),.034)
    bar('Stair_'+name+'_Landing_End_Rail',(west-1.19,cy-flight_width/2+.06,endz+1.0),(west-1.19,cy+flight_width/2-.06,endz+1.0),.034)
    for side in (-1,1):
        yy=cy+side*(flight_width/2-.06)
        for i in range(0,count+1,2):
            xx=start-i*tread
            zz=i*rise*direction
            bar('Stair_'+name+'_Baluster',(xx,yy,zz),(xx,yy,zz+1.0),.021)
        bar('Stair_'+name+'_Handrail',(start,yy,1.0),(west,yy,3.35*direction+1.0),.034)
        bar('Stair_'+name+'_Midrail',(start,yy,.50),(west,yy,3.35*direction+.50),.019)
    marker=empty('Stair_'+name+'_Level_Exit',REGIONS,(west-.5,cy,3.35*direction))
    marker['target_level_offset']=direction
    marker['status']='Landing only; adjacent floor not built'
    text('Plan_Stair_'+name,'ขึ้น' if direction==1 else 'ลง',(start-.9,cy,3.45 if direction==1 else .05),.55,labelink,GUIDES)
region('Stairs','บันได ขึ้น–ลง',(XL,XC,YST,YF),((XL+XC)/2,stair_mid))
# Rail the open west strip so a player cannot accidentally enter the descending void.
for cy in (YST+.13,YF-.13):
    bar('Stair_End_Rail',(XL+.15,cy,1.0),(west-1.35,cy,1.0),.03)

# Simple lighting fixtures for entering the rooms later. Ceilings are grouped for inspection.
em=mat('MAP | Light diffuser',(.88,.94,1))
p=em.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.88,.94,1,1);p.inputs['Emission Strength'].default_value=2
def area(name,pos,power,size,c=LIGHTS):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);c.objects.link(o);o.location=pos
    return o
for room in room_info:
    if room['id'] in ('Stairs','Corridor'):continue
    x0,x1,y0,y1=room['bounds']
    for ix in (.3,.7):
        for iy in (.25,.75):
            xx=x0+(x1-x0)*ix;yy=y0+(y1-y0)*iy
            if room['id']=='ITSupport' and xx<XS and yy<YS:continue
            box('Light_Panel_'+room['id'],(1.18,.3,.045),(xx,yy,3.15),em,CEIL,.012)
            area('Room_Light_'+room['id'],(xx,yy,3.08),220,2.2)
for yy in [YB+2+i*4.5 for i in range(12)]:
    if yy<YTOP:
        xx=(XC+XR)/2
        box('Corridor_Light_Panel',(.4,1.10,.045),(xx,yy,3.15),em,CEIL,.012)
        area('Corridor_Light',(xx,yy,3.08),160,1.8)

spawn=empty('Player_Spawn_ITSupport',REGIONS,(X(359)+1.1,Y(153),.02))
spawn['role']='suggested player start beside player desk'
startmark=empty('Floor01_Origin_Classroom',REGIONS,(0,0,0));startmark['units']='metres'

# Validate original mesh state and physical placement before saving.
bpy.context.view_layer.update()
assert all(fingerprint(bpy.data.objects[n])==sig for n,sig in originals.items()),'Original room geometry changed'
assert len([o for o in bpy.data.objects if o.name.startswith('StudentDesk_Row')])==10
def bounds(objects):
    coords=[o.matrix_world@Vector(c) for o in objects if o.type=='MESH' for c in o.bound_box]
    return [min(p[i] for p in coords) for i in range(3)],[max(p[i] for p in coords) for i in range(3)]
computer_bounds={}
for name in ('01_Case','02_Monitor','03_Keyboard','04_Mouse'):
    comp=bpy.data.objects[name]
    lo,hi=bounds(list(comp.children_recursive))
    assert abs(lo[2]-.7505)<.002,(name,'not on tabletop',lo)
    assert lo[0]>2.90 and hi[0]<4.70 and lo[1]>7.60 and hi[1]<8.40,(name,'outside desk',lo,hi)
    computer_bounds[name]={'min':lo,'max':hi}
assert len([o for o in computer.all_objects if o.name.startswith('Key_') and o.type=='MESH'])==104
assert len([o for o in computer.all_objects if o.name.startswith('Socket_')])==18
# Check doorway passages by casting only against architecture walls at ankle and chest height.
for entry in door_info:
    for zz in (.15,1.2,2.05):
        p=Vector((entry['x']-.4,entry['y'],zz));d=Vector((1,0,0))
        for ob in wall_objs:
            im=ob.matrix_world.inverted()
            hit=ob.ray_cast(im@p,(im.to_3x3()@d).normalized(),distance=.8)[0]
            assert not hit,(entry['name'],'blocked doorway',ob.name,zz)

# Top view and a separate high-angle view make the floor plan immediately reviewable.
for o in scene.objects:
    if o.type=='LIGHT' and o.name.startswith(('Preview_','Desk_Preview')):o.hide_render=True
world=scene.world or bpy.data.worlds.new('Map World');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.68,.74,.79,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.65
sd=bpy.data.lights.new('Map_Sun','SUN');sd.energy=1.8;sd.angle=math.radians(20)
sun=bpy.data.objects.new('Map_Sun',sd);PRESENT.objects.link(sun);sun.rotation_euler=(.36,-.42,-.3)
def camera(name,pos,target,scale):
    d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);PRESENT.objects.link(o)
    o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO';d.ortho_scale=scale;d.clip_end=500
    return o
cx=(XL+XE)/2;cy=(YB+YTOP)/2
top=camera('Map_Camera_Top',(cx,cy,85),(cx,cy,0),YTOP-YB+4.0)
iso=camera('Map_Camera_Overview',(cx+36,cy-42,65),(cx,cy,0),YTOP-YB+11)
detail=camera('Map_Camera_TeacherDesk',(4.4,9.2,2.2),(3.8,7.95,1.0),2.55)
detail.data.type='PERSP';detail.data.lens=35;detail.data.clip_start=.01
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.cycles.max_bounces=5
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGB'
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.camera=top
scene.render.resolution_x=1500;scene.render.resolution_y=2400
CEIL.hide_viewport=True;CEIL.hide_render=True
GUIDES.hide_render=False
for area in bpy.context.screen.areas if bpy.context.screen else []:
    if area.type=='VIEW_3D':
        s=area.spaces.active;s.region_3d.view_location=(cx,cy,0);s.region_3d.view_distance=60
        s.region_3d.view_rotation=Quaternion((1,0,0,0));s.region_3d.view_perspective='ORTHO';s.clip_end=500
        s.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True);bpy.context.view_layer.objects.active=root
scene['map_reference']='User floor plan: IT+storage/stairs/men/women/background classroom left; server/staff/classroom right; centre corridor.'
scene['map_clear_corridor_width_m']=XR-XC-TH
scene['map_extent_m']=[XE-XL,YTOP-YB]
notes=bpy.data.texts.new('READ_ME | Floor map')
notes.write('Floor map built around the saved 12 x 19.5 m classroom. Original classroom mesh and door coordinates preserved.\n'+
    'Ceilings: MAP | Floor 01 > 07 | Ceilings - toggle for interior. Hidden for map inspection; present in this file.\n'+
    '08 | Plan labels are optional layout annotation meshes, not intended for game export.\n'+
    'Four computer assemblies appended locally onto TeacherDesk, tabletop Z=0.7505 m. No source file linking.\n'+
    'IT support has three desks. Other new rooms are shells awaiting furniture and equipment.\n'+
    'Stair UP and DOWN landings terminate at +3.35 and -3.35 m. Adjacent floors are not modeled.\n'+
    'Doors are open with separate hinge pivots. Collision, navigation and runtime door logic are not added.\n')
report={'original_mesh_objects_preserved':len(originals),'room_regions':room_info,'new_doors':door_info,'clear_corridor_width_m':XR-XC-TH,'extent_m':[XE-XL,YTOP-YB],'computer_bounds':computer_bounds,'student_desks':10,'IT_desks':3,'computer_keys':104,'computer_sockets':18,'source_classroom_sha256':hashlib.sha256((BASE/'ใช้ร่วมกัน/blend/classroom_shell.blend').read_bytes()).hexdigest(),'source_computer_sha256':hashlib.sha256((BASE/'ใช้ร่วมกัน/blend/teacher_computer_set.blend').read_bytes()).hexdigest()}
(TMP/'map_validation.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT),compress=True)
print('MAP_SAVED',str(OUT),'ROOMS',len(room_info),'DOORS',len(door_info),'COMPUTER_PLACEMENT_OK',flush=True)
def render(cam,name,w,h):
    scene.camera=cam;scene.render.resolution_x=w;scene.render.resolution_y=h
    scene.render.filepath=str(RENDERS/name)
    print('RENDER_START',name,flush=True);bpy.ops.render.render(write_still=True);print('RENDER_DONE',name,flush=True)
render(top,'classroom_floor_map_top.png',1500,2400)
GUIDES.hide_render=True
render(iso,'classroom_floor_map_overview.png',1800,1600)
render(detail,'classroom_teacher_computer_placed.png',1400,1100)
print('MAP_COMPLETE',flush=True)
