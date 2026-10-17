"""Five standalone school-uniform variants of the existing CC0-based characters.
Retains deform rigs. Source teacher files are read-only inputs.
"""
import bpy, bmesh, math, json, hashlib, sys
from pathlib import Path
from collections import defaultdict
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path('D:/NetSim3D/3Dmodel')
OUT=ROOT/'blend/students'; OUT.mkdir(exist_ok=True)
REND=ROOT/'renders/students'; REND.mkdir(exist_ok=True)
SRC=ROOT/'temp/teacher_male/source'

def mat(name,color,rough=.65,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    return m

def mesh(name,vs,fs,material,col):
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update()
    ob=bpy.data.objects.new(name,me); col.objects.link(ob); me.materials.append(material)
    for p in me.polygons:p.use_smooth=True
    return ob

def bound(objects):
    dg=bpy.context.evaluated_depsgraph_get(); pts=[]
    for ob in objects:
        if ob.type!='MESH':continue
        ev=ob.evaluated_get(dg); me=ev.to_mesh()
        pts.extend(ev.matrix_world@v.co for v in me.vertices); ev.to_mesh_clear()
    return Vector(tuple(min(p[i] for p in pts) for i in range(3))),Vector(tuple(max(p[i] for p in pts) for i in range(3)))

def rigid_world(ob,rig,bone):
    # Author in the visible posed world, then undo the bone deformation to bind.
    tr=(rig.matrix_world @ rig.pose.bones[bone].matrix @ rig.data.bones[bone].matrix_local.inverted()).inverted()
    for v in ob.data.vertices:v.co=tr@v.co
    ob.parent=rig; ob.matrix_parent_inverse=Matrix.Identity(4); ob.matrix_basis=Matrix.Identity(4)
    g=ob.vertex_groups.new(name=bone); g.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    m=ob.modifiers.new('Deform skeleton','ARMATURE'); m.object=rig

def add_lower_legs(asset,rig,skin):
    vs=[]; uv=[]; fs=[]; grp=''
    for line in (SRC/'base.obj').read_text().splitlines():
        t=line.split()
        if not t:continue
        if t[0]=='v':vs.append(Vector(tuple(map(float,t[1:4]))))
        elif t[0]=='vt':uv.append(tuple(map(float,t[1:3])))
        elif t[0]=='g':grp=t[1]
        elif t[0]=='f' and grp=='body':fs.append([(int(a.split('/')[0])-1,int(a.split('/')[1])-1) for a in t[1:]])
    for fn,k in [('asian-male-young.target',.85),('caucasian-male-young.target',.15),('universal-male-young-maxmuscle-averageweight.target',.15)]:
        for line in (SRC/fn).read_text().splitlines():
            t=line.split()
            if t and t[0].isdigit():vs[int(t[0])]+=Vector(tuple(float(x)*k for x in t[1:4]))
    floor=min(vs[i].y for f in fs for i,_ in f)
    pts=[Vector((p.x*.105,-p.z*.105,(p.y-floor)*.105+.026)) for p in vs]
    selected=[f for f in fs if .12 < sum(pts[i].z for i,_ in f)/len(f) < .71]
    ids=sorted({i for f in selected for i,_ in f}); lut={i:j for j,i in enumerate(ids)}
    ob=mesh('Skin | knees and lower legs',[pts[i] for i in ids],[[lut[i] for i,_ in f] for f in selected],skin,asset)
    layer=ob.data.uv_layers.new(name='MakeHuman_UV')
    for p,f in zip(ob.data.polygons,selected):
        for li,(_,ui) in zip(p.loop_indices,f):layer.data[li].uv=uv[ui]
    weights=json.loads((SRC/'default_weights.mhw').read_text())['weights']
    for bn,items in weights.items():
        chosen=[(lut[i],w) for i,w in items if i in lut]
        if chosen:
            g=ob.vertex_groups.new(name=bn)
            for i,w in chosen:g.add([i],w,'REPLACE')
    ob.parent=rig; m=ob.modifiers.new('Deform skeleton','ARMATURE');m.object=rig
    m=ob.modifiers.new('Anatomy smoothing','SUBSURF');m.levels=1;m.render_levels=1

def hairstyle(body,rig,asset,style):
    dg=bpy.context.evaluated_depsgraph_get(); ev=body.evaluated_get(dg); me=ev.to_mesh()
    vs=[ev.matrix_world@v.co for v in me.vertices]; fs=[tuple(p.vertices) for p in me.polygons]
    tree=BVHTree.FromPolygons(vs,fs)
    top=max(p.z for p in vs); head=[p for p in vs if p.z>top-.13]
    cy=(min(p.y for p in head)+max(p.y for p in head))*.5
    center=Vector((0,cy,top-.105))
    rx=max(abs(p.x) for p in head)+.001
    ry=max(abs(p.y-cy) for p in head)+.002
    ev.to_mesh_clear()
    hair=mat('Hair | natural near-black',(.009,.007,.006),.72)
    highlight=mat('Hair | strand sheen',(.012,.009,.008),.70)
    for material in (hair,highlight):material.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.17
    length={'mullet':.105,'two_block':0,'bob_cut':.072,'wendy_cut':.15,'layer_cut':.23}[style]
    long=style not in ('mullet','two_block')
    def sample(theta,u,raise_by=0):
        front=max(0,math.cos(theta)); back=max(0,-math.cos(theta))
        # Front hairline stays high; side curtains begin outside the eye line.
        curtain=max(0,min(1,(.70-math.cos(theta))/.35))
        end=1.10+.60*curtain
        if style=='mullet':end=1.08+.20*curtain+.43*back
        if style in ('wendy_cut','layer_cut'):end-=.18*front*math.exp(-(math.sin(theta)/.28)**2)
        phi=.012+min(u/.72,1)*(end-.012)
        if not long and style=='two_block':phi=.012+u*(1.55-.012)
        direction=Vector((math.sin(phi)*math.sin(theta),-math.sin(phi)*math.cos(theta),math.cos(phi)))
        # Smooth skull envelope avoids copying ears or small facial features into hair.
        hit=center+Vector((direction.x*rx,direction.y*ry,direction.z*.105))
        vol=.009 + .010*math.sin(phi)**2
        if style=='two_block':vol+=.012*math.sin(math.pi*u)**2
        if style=='mullet':vol+=.010*math.sin(phi)*(.5+.5*math.cos(theta*4+u*5))
        if long:vol+=.012*curtain
        ridge=.0012*math.cos(theta*48+u*2)*math.sin(phi)**2
        p=hit+direction*(vol+ridge+raise_by)
        if u>.72 and style!='two_block':
            t=(u-.72)/.28
            tail=length*curtain*back**2 if style=='mullet' else length*curtain
            if style in ('wendy_cut','layer_cut'):tail*=.50+.50*back
            if style=='wendy_cut':tail*=.85+.15*math.cos(theta*5)
            if style=='layer_cut':tail*=.86+.14*math.cos(theta*7)
            p.z-=tail*t
            p.x+=math.sin(theta)*(.013*math.sin(t*math.pi/2) if long else -.004*t)
            if style=='bob_cut':p.x-=math.sin(theta)*.019*t*t
            p.y+=back*(.04 if long else .012)*t
            if style in ('wendy_cut','layer_cut'):
                p.x+=math.sin(theta)*.012*t**4
                p.z+=.012*t**4*math.cos(theta*12)
        # Parted front fringe remains above the brows rather than crossing eyes.
        p.z+=.008*front**4*math.exp(-(math.sin(theta)/.15)**2)*math.sin(phi)**2
        if style=='mullet':p.z+=.006*front**4*math.sin(theta*19+u*3)*u**4
        return p
    n=160; rows=36
    points=[sample(k*math.tau/n,j/rows) for j in range(rows+1) for k in range(n)]
    faces=[(r*n+k,r*n+(k+1)%n,(r+1)*n+(k+1)%n,(r+1)*n+k) for r in range(rows) for k in range(n)]
    faces.append(tuple(reversed(range(n))))
    ob=mesh('Hair | '+style,points,faces,hair,asset);rigid_world(ob,rig,'head')
    m=ob.modifiers.new('Closed hair shell','SOLIDIFY');m.thickness=.002;m.offset=-1
    # Narrow tapered sculpted locks give directional highlights without alpha cards.
    verts=[]; faces=[]
    for k in range(56):
        theta=(k+.32)*math.tau/56; start=len(verts)
        for j in range(16):
            u=.10+.90*j/15; width=.004*math.sin(math.pi*j/15)**.5
            shift=.10*math.sin(u*math.pi)*(1 if math.sin(theta)>0 else -1)
            for delta in (-width,0,width):verts.append(sample(theta+shift+delta,u,.0020 if delta else .0025))
        for j in range(15):
            a=start+j*3
            faces.extend([(a,a+1,a+4,a+3),(a+1,a+2,a+5,a+4)])
    # Strand ridges are integrated into the shell to avoid overlapping surfaces.
    return top

def make(style,sex,height):
    source=ROOT/('blend/teacher_male_khaki_180cm.blend' if sex=='male' else 'blend/teacher_female_khaki_160cm.blend')
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
    scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE');rig.hide_set(False)
    asset=next(c for c in bpy.data.collections if c.name.startswith('TEACHER |'))
    asset.name='STUDENT | '+sex+' | '+style
    rig.name='Student_'+sex+'_'+style+'_Rig'
    white=mat('School uniform | white cotton',(.83,.85,.87),.82)
    black=mat('School uniform | black fabric',(.012,.015,.021),.85)
    beltmat=mat('Belt | black leather',(.012,.014,.018),.48)
    silver=mat('Buckle | brushed silver',(.34,.37,.40),.3,.8)
    # Remove all adult rank decorations, nameplates and former hair variants.
    for ob in list(bpy.data.objects):
        if ob.name.startswith(('Hair |','Uniform | epaulets','Uniform | editable name badge','Uniform | chest pockets','Uniform | trouser stitching')):
            bpy.data.objects.remove(ob,do_unlink=True)
    for ob in asset.objects:
        if ob.type!='MESH':continue
        if ob.name.startswith(('Uniform_Shirt','Uniform | buttons')):
            for i in range(len(ob.data.materials)):ob.data.materials[i]=white
        elif 'belt and buckle' in ob.name:
            for i,m in enumerate(ob.data.materials):ob.data.materials[i]=silver if m and any(k in m.name.lower() for k in ('gold','brass')) else beltmat
        elif 'skirt' in ob.name or ob.name.startswith('Uniform_Trousers'):
            for i in range(len(ob.data.materials)):ob.data.materials[i]=black
    body=next(o for o in asset.objects if o.name.startswith('Body |'))
    if sex=='male':
        pants=bpy.data.objects['Uniform_Trousers | straight tailored leg']
        bm=bmesh.new();bm.from_mesh(pants.data)
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=(0,0,.66),plane_no=(0,0,1),clear_inner=True)
        bm.to_mesh(pants.data);bm.free();pants.name='Uniform | black knee-length school shorts'
        add_lower_legs(asset,rig,body.data.materials[0])
    else:
        skirt=next(o for o in asset.objects if 'skirt' in o.name)
        # Knife-pleat-like radial folds, gathered into a continuous waistband.
        for v in skirt.data.vertices:
            x,y,z=v.co;theta=math.atan2((y+.016)/.13,x/.18)
            fall=max(0,min(1,(.96-z)/.19))
            fold=1+.043*fall*math.cos(theta*16)
            v.co.x*=fold;v.co.y=-.016+(y+.016)*fold
        skirt.name='Uniform | black pleated knee-length skirt'
    shoes=next(o for o in asset.objects if o.name.startswith('Shoes |'))
    shoes.data.materials.append(white);slot=len(shoes.data.materials)-1
    if sex=='female':
        # The teacher's original tall sock geometry projects beyond her ankles.
        # A short school sock cuff avoids that flare while keeping the foot covered.
        for v in shoes.data.vertices:
            if v.co.z>.115:v.co.z=.115+(v.co.z-.115)*.32
    for p in shoes.data.polygons:
        if sum(shoes.data.vertices[i].co.z for i in p.vertices)/len(p.vertices)>.113:p.material_index=slot
    bpy.context.view_layer.update()
    # A plain open chest pocket distinguishes the school shirt from the teacher uniform.
    shirt=bpy.data.objects.get('Uniform_Shirt | short sleeve')
    ev=shirt.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
    tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in me.vertices],[tuple(p.vertices) for p in me.polygons]);ev.to_mesh_clear()
    _,body_high=bound([body]);cz=body_high.z-.40
    pocket_points=[];pocket_faces=[];n=8
    for j in range(n+1):
        for i in range(n+1):
            x=.045+.071*i/n;z=cz-.072*j/n
            p=tree.ray_cast(Vector((x,-.6,z)),Vector((0,1,0)),1)[0]
            pocket_points.append(p+Vector((0,-.004,0)) if p is not None else Vector((x,-.12,z)))
    for j in range(n):
        for i in range(n):
            a=j*(n+1)+i;pocket_faces.extend([(a,a+n+1,a+1),(a+1,a+n+1,a+n+2)])
    pocket=mesh('Uniform | open school shirt chest pocket',pocket_points,pocket_faces,white,asset)
    rigid_world(pocket,rig,'spine03')
    m=pocket.modifiers.new('Pocket fabric thickness','SOLIDIFY');m.thickness=.001
    top=hairstyle(body,rig,asset,style)
    low,high=bound(asset.all_objects);factor=height/(high.z-low.z)
    rig.scale*=factor;rig.location*=factor;bpy.context.view_layer.update()
    low,high=bound(asset.all_objects);rig.location.z-=low.z;bpy.context.view_layer.update()
    low,high=bound(asset.all_objects)
    assert abs(high.z-low.z-height)<.0001
    rig['role']='High school student';rig['hairstyle']=style;rig['height_m']=height
    rig['animation_status']='Deform skeleton retained; no animation clips. Test skin weights before production animation.'
    for im in bpy.data.images:
        if im.source=='FILE' and im.users and not im.packed_file:im.pack()
    # Remove stale teacher descriptions, retain source attribution in a new note.
    for t in list(bpy.data.texts):
        if t.name.startswith('README'):bpy.data.texts.remove(t)
    t=bpy.data.texts.new('README | Student')
    t.write(f'NetSim3D high-school student: {sex}, {style}, {height:.2f} m including hair and shoes.\n'
            'White short-sleeved school shirt, black school uniform, white socks, black shoes.\n'
            'Export STUDENT collection only; STUDIO is for previews. Textures packed.\n'
            'Deform skeleton retained. No animation clips; verify skin weights and retargeting in Godot.\n'
            'MakeHuman CC0 anatomy, morphs, skin, eyes, brows, base garments and skeleton.\n'
            'https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.ASSETS.md\n'
            'School clothing adaptations and solid sculpted hairstyle authored for NetSim3D.\n')
    cam=scene.camera;cam.data.type='ORTHO'
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
    def view(pos,target,scale,name,w,h):
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(REND/(name+'.png'))
    stem='student_'+sex+'_'+style
    view((2,-6,1.50),(0,0,height*.51),height*1.16,stem,600,850)
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.overlay.show_overlays=False;sp.shading.type='MATERIAL'
            sp.region_3d.view_location=(0,0,height*.5);sp.region_3d.view_distance=2.7
    bpy.ops.object.select_all(action='DESELECT');rig.hide_set(True)
    path=OUT/(stem+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(path))
    bpy.ops.render.render(write_still=True)
    view((2,-5,height-.04),(0,0,height-.13),.48,stem+'_hair',600,600);bpy.ops.render.render(write_still=True)
    view((5,1,height-.1),(0,0,height-.17),.60,stem+'_side',600,600);bpy.ops.render.render(write_still=True)
    assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
    report={'file':str(path),'height_m':high.z-low.z,'feet_z':low.z,'bones':len(rig.data.bones),'source_unchanged':True,'hairstyle':style}
    print('STUDENT_COMPLETE '+json.dumps(report),flush=True)

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for style,sex,h in [('mullet','male',1.65),('two_block','male',1.65),('bob_cut','female',1.60),('wendy_cut','female',1.60),('layer_cut','female',1.60)]:
        if not wanted or style in wanted:make(style,sex,h)
