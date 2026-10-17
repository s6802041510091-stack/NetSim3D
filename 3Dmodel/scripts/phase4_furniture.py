"""Phase 4 furniture lookdev. Never rebuild the production scene.

Commands: audit, build, refine, before [view], after [view], verify, export.
Original texture patterns are generated locally; no external media is used.
"""
import bpy, bmesh, sys, json, math, re, shutil, tempfile, hashlib
from pathlib import Path
from collections import Counter
from mathutils import Vector, Matrix
import numpy as np
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import phase1_it_corner as p1
import phase1_surface_textures as tex
import phase2_architecture as p2
WORK = p1.WORK
OUT = ROOT / 'Preview/โรงเรียนและเมือง/phase4'
BACKUP = WORK.with_name('classroom_shell_lookdev_before_phase4.blend')
VIEWS = {
    'classroom': ((2.6, .0, 1.6), (.25, 4.5, .65), 34),
    'it_office': ((-16.2, 39.8, 1.65), (-11.4, 43.7, 1.05), 30),
    'lounge': ((1.6, 26.0, 1.6), (-1.0, 29.65, .75), 33),
    'pantry': ((1.1, 27.5, 1.65), (3.5, 30.1, 1.2), 34),
    'staff': ((4.9, 14.8, 1.65), (1.1, 19.1, .9), 29),
    'storage': ((-13.7, 32, 1.65), (-18.9, 35.6, 1.1), 27),
    'science': ((-10.3, 1.1, 1.65), (-14.7, 3.2, .85), 31),
    'noc': ((3.0, 34.2, 1.65), (-.5, 31.0, 1.0), 30),
    'plant': ((2.2, 28.4, 1.55), (1.02, 30, .9), 50),
    'workstation': ((7.6,26.7,1.35), (8.46,27.32,.87), 50),
}
# Explicit source material -> approved or new finish. Existing P1/P2/P3 untouched.
REUSE = {
 'MAT_Desk_Light_Wood':'P1 | Oak', 'MAT_Teacher_Desk_Panel':'P1 | Oak',
 'MAT_Desk_Frame_Charcoal':'P1 | PowderCoat', 'MAT_Desk_Black_Accent':'P1 | Rubber',
 'Chair | navy upholstery':'P1 | Fabric', 'Chair | graphite powder-coated steel':'P1 | PowderCoat',
 'Chair | rubber floor glides':'P1 | Rubber', 'OF | oak laminate':'P1 | Oak',
 'OF | white laminate':'P1 | CoatedWhite', 'OF | powder coat graphite':'P1 | PowderCoat',
 'OF | binder black':'P1 | Binder', 'OF | partition trim aluminium':'P2 | Aluminium',
 'SCI | aluminium frame':'P2 | Aluminium', 'SCI | dark plastic':'P1 | Polymer',
 'SCI | white':'P1 | CoatedWhite', 'SCI | whiteboard':'P1 | CoatedWhite',
 'DC | desk frame graphite':'P1 | PowderCoat', 'DC | chair mesh black':'P1 | Fabric',
 'DC | notebook':'P1 | Binder', 'DC | vent grille':'P1 | Polymer',
 'SCI | stainless steel':'P3 | Satin metal', 'OF | appliance steel':'P3 | Satin metal',
 'OF | handle chrome':'P4 | Chrome', 'SCI | chrome':'P4 | Chrome',
}
STYLES = {
 'OF | walnut veneer':('Walnut','wood',(.30,.20,.12),.46),
 'SCI | beech wood':('Beech','wood',(.64,.48,.29),.48),
 'OF | sofa fabric teal':('Fabric teal','fabric',(.08,.34,.35),.86),
 'OF | cushion mustard':('Fabric mustard','fabric',(.66,.45,.10),.86),
 'OF | chair fabric navy':('Fabric navy','fabric',(.085,.125,.17),.86),
 'OF | chair fabric red':('Fabric burgundy','fabric',(.39,.09,.08),.86),
 'OF | partition fabric blue-grey':('Fabric blue grey','fabric',(.46,.56,.62),.9),
 'OF | rug warm grey':('Rug border','fabric',(.32,.29,.27),.94),
 'OF | rug inner':('Rug warm','fabric',(.45,.40,.36),.94),
 'OF | rug blue-grey':('Rug blue border','fabric',(.24,.30,.36),.94),
 'OF | rug blue-grey inner':('Rug blue','fabric',(.33,.40,.46),.94),
 'OF | cardboard':('Cardboard','paper',(.57,.42,.25),.88),
 'OF | paper white':('Paper','paper',(.88,.88,.85),.84),
 'OF | label paper':('Label','paper',(.91,.91,.85),.8),
 'SCI | poster paper':('Paper','paper',(.88,.88,.85),.84),
 'OF | cork board':('Cork','cork',(.52,.36,.21),.94),
 'OF | soil':('Soil','cork',(.12,.075,.04),.99),
 'OF | plant leaf green':('Leaf green','leaf',(.08,.28,.085),.54),
 'OF | plant leaf light green':('Leaf light','leaf',(.18,.39,.10),.58),
 'OF | plant pot terracotta':('Terracotta','coating',(.56,.27,.15),.8),
 'OF | plant pot white':('Ceramic','coating',(.85,.85,.82),.29),
 'OF | mug white':('Ceramic','coating',(.85,.85,.82),.29),
 'OF | mug red':('Ceramic red','coating',(.55,.07,.055),.29),
 'OF | powder coat white':('Coat white','coating',(.82,.83,.81),.43),
 'OF | steel cabinet light grey':('Cabinet grey','coating',(.58,.62,.62),.46),
 'OF | steel cabinet blue':('Cabinet blue','coating',(.14,.29,.46),.46),
 'OF | locker sage':('Cabinet sage','coating',(.37,.51,.45),.46),
 'OF | parts drawer red':('Drawer red','coating',(.55,.08,.06),.52),
 'OF | appliance white':('Appliance','coating',(.84,.86,.85),.34),
 'OF | copier light grey':('Appliance','coating',(.84,.86,.85),.34),
 'OF | counter quartz grey':('Quartz','stone',(.49,.51,.52),.34),
 'OF | splashback tile white':('Splash tile','tile',(.84,.87,.86),.3),
 'SCI | black epoxy worktop':('Epoxy','coating',(.055,.066,.071),.36),
 'SCI | cabinet pale grey':('Lab cabinet','coating',(.70,.74,.73),.47),
 'SCI | cabinet door sage':('Lab sage','coating',(.42,.59,.52),.47),
 'SCI | acid cabinet blue':('Cabinet blue','coating',(.14,.29,.46),.46),
 'SCI | stool seat blue':('Stool blue','coating',(.12,.25,.40),.51),
 'DC | desk laminate grey':('Desk grey','coating',(.51,.54,.54),.47),
 'DC | filing cabinet grey':('Cabinet grey','coating',(.58,.62,.62),.46),
}
for color, rgb in [('red',(.52,.09,.07)),('blue',(.07,.20,.45)),('green',(.08,.34,.17)),('yellow',(.76,.55,.10)),('white',(.82,.83,.80))]:
    STYLES['OF | book '+color] = ('Book '+color,'paper',rgb,.74)
SCALES = {'P1 | Oak':1.4,'P1 | CoatedWhite':.30,'P1 | PowderCoat':.15,'P1 | Rubber':.16,'P1 | Fabric':.24,'P1 | Binder':.18,'P1 | Polymer':.12,'P2 | Aluminium':.15,'P3 | Satin metal':.12}
EXISTING_PRINT_OWNERS = ('ST_Cabinet_West_', 'ST_Cabinet_North_', 'TR_Filing_Cabinet_')

def write(name, data):
    path=OUT/name; path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')

def target(o):
    if o.type!='MESH' or o.hide_render or p2.target(o): return False
    if o.name in ['IT_PlayerDesk','Chair_IT_PlayerDesk_1','IT_Bookcase_North']: return False
    if re.search('Computer|Monitor|Screen|StaffPC|Socket|Button|Keyboard',o.name,re.I): return False
    if o.name.startswith(('P1_','P3_')):return False
    return (o.name.startswith(('StudentDesk_','TeacherDesk','Chair_','IT_','TR_','ST_','SCI_')) or
            o.name.startswith(('DC_NOC_Desk','DC_Chair','DC_Filing','DC_Repair_Bench','DC_Printer_Table','DC_Whiteboard')))

def bounds(o):
    return [[min(v[i] for v in o.bound_box) for i in range(3)],[max(v[i] for v in o.bound_box) for i in range(3)]]

def audit():
    bpy.ops.wm.open_mainfile(filepath=str(WORK)); objects=[]; usage=Counter()
    for o in bpy.context.scene.objects:
        if not target(o):continue
        mats=[m.name if m else None for m in o.data.materials]
        if not any(m in REUSE or m in STYLES for m in mats):continue
        usage.update(m for m in mats if m)
        objects.append({'name':o.name,'mesh':o.data.name,'users':o.data.users,'bounds':bounds(o),'matrix':[list(r) for r in o.matrix_world],'materials':mats})
    write('audit.json',{'targets':objects,'material_usage':dict(usage)})
    print('P4_AUDIT',len(objects),'objects',len(set(o['mesh'] for o in objects)),'meshes',flush=True)

def materials():
    folder=OUT/'textures'; folder.mkdir(parents=True,exist_ok=True)
    result={}; paths={}; n=512; y,x=np.mgrid[0:n,0:n]/n
    micro=tex.noise(n,.8,.8,401); broad=tex.noise(n,10,10,402)
    for name,kind,rgb,rough in sorted(set(STYLES.values())):
        grain=micro*.002+broad*.003; height=micro*.05
        if kind=='wood':
            grain=.035*tex.noise(n,2,65,403)+.02*tex.noise(n,15,100,404)
            grain+=.01*np.sin(2*np.pi*(x*53+.2*np.sin(y*2*np.pi)))
            height=grain*2
        elif kind=='fabric':
            weave=np.sin(x*2*np.pi*96)*np.sin(y*2*np.pi*96)
            grain=.012*weave+.003*micro; height=weave*.18
        elif kind=='paper': grain=.003*micro+.003*tex.noise(n,.6,9,405); height=grain*3
        elif kind=='cork': grain=.035*tex.noise(n,3,3,406)+.008*micro; height=grain*1.5
        elif kind=='stone': grain=.008*broad+.01*np.maximum(micro-1.5,0); height=grain*.5
        elif kind=='leaf':
            midrib=np.exp(-((x-.5)/.012)**2)
            veins=np.exp(-(np.sin((y-np.abs(x-.5)*.5)*2*np.pi*8)/.10)**2)
            grain=.015*midrib+.009*veins+.002*broad; height=midrib*.08+veins*.025
        color=np.stack([v+grain for v in rgb],axis=2)
        roughmap=rough+.012*micro
        if kind=='tile':
            edge=np.minimum.reduce([x,1-x,y,1-y]); joint=np.clip((edge-.004)/.006,0,1)
            color=color*joint[:,:,None]+np.array([.43,.46,.45])*(1-joint[:,:,None]); height=joint*.3
            roughmap=roughmap+(1-joint)*.35
        mp=tex.maps(folder,name.replace(' ','_'),color,roughmap,height,1)
        m=p1.create_material('temp',mp,0,.22 if kind in ('leaf','fabric') else .12);m.name='P4 | '+name
        if kind=='leaf': m.use_backface_culling=False
        paths[m.name]={k:str(v) for k,v in mp.items()}
        SCALES[m.name]=1.4 if kind=='wood' else .24 if kind=='fabric' else .12 if kind in ('paper','coating') else .6
    chrome=bpy.data.materials.new('P4 | Chrome'); p=chrome.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(.65,.68,.70,1);p.inputs['Metallic'].default_value=.9;p.inputs['Roughness'].default_value=.24
    ink=bpy.data.materials.new('P4 | Printed ink');ink.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.012,.02,.028,1)
    for old,new in REUSE.items():result[old]=bpy.data.materials[new]
    for old,spec in STYLES.items():result[old]=bpy.data.materials['P4 | '+spec[0]]
    return result,paths

def uv_local(o):
    me=o.data;uv=me.uv_layers.get('P4_SurfaceUV') or me.uv_layers.new(name='P4_SurfaceUV');me.uv_layers.active=uv;uv.active_render=True
    for face in me.polygons:
        m=me.materials[face.material_index] if face.material_index<len(me.materials) else None
        scale=SCALES.get(m.name if m else '',.3)
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        for li in face.loop_indices:
            co=me.vertices[me.loops[li].vertex_index].co
            xyz=[co[i]*abs(o.scale[i]) for i in range(3)]
            u,v=(xyz[0],xyz[1]) if axis==2 else (xyz[0],xyz[2]) if axis==1 else (xyz[1],xyz[2])
            uv.data[li].uv=(u/scale,v/scale)

def components(bm, predicate):
    remaining={v for f in bm.faces if predicate(f) for v in f.verts};groups=[]
    while remaining:
        v=remaining.pop();group={v};todo=[v]
        while todo:
            for e in todo.pop().link_edges:
                for n in e.verts:
                    if n in remaining:remaining.remove(n);group.add(n);todo.append(n)
        groups.append(group)
    return groups

def refine_geometry(o):
    me=o.data; names=[m.name if m else '' for m in me.materials]
    cloth={i for i,n in enumerate(names) if n.startswith('P4 | Fabric') or n=='P1 | Fabric'}
    leaf={i for i,n in enumerate(names) if n.startswith('P4 | Leaf')}
    if not cloth and not leaf:return []
    bm=bmesh.new();bm.from_mesh(me);actions=[]
    if cloth and ('Chair' in o.name or 'Sofa' in o.name):
        groups=components(bm,lambda f:f.material_index in cloth)
        for group in groups:
            # Rebuild each original cuboid with clean outward winding. Source boxes
            # have inconsistent normals; beveling those directly leaves broken seams.
            if len(group)!=8:continue
            mi=next(f.material_index for v in group for f in v.link_faces if f.material_index in cloth)
            coords=np.array([v.co[:] for v in group]);center=coords.mean(axis=0)
            _,axes=np.linalg.eigh(np.cov((coords-center).T))
            if np.linalg.det(axes)<0:axes[:,0]*=-1
            extent=np.max(np.abs((coords-center)@axes),axis=0)
            bmesh.ops.delete(bm,geom=list(group),context='VERTS')
            cushion=bmesh.new();bmesh.ops.create_cube(cushion,size=2)
            for v in cushion.verts:v.co=Vector(np.array(v.co[:])*extent)
            bmesh.ops.recalc_face_normals(cushion,faces=list(cushion.faces))
            width=min(.035 if 'Sofa' in o.name else .018,float(min(extent))*.65)
            bmesh.ops.bevel(cushion,geom=list(cushion.verts)+list(cushion.edges),offset=width,segments=5,profile=.5,affect='EDGES',clamp_overlap=True)
            cushion.normal_update();vertices={v:bm.verts.new(Vector(center+axes@np.array(v.co[:]))) for v in cushion.verts}
            for f in cushion.faces:
                face=bm.faces.new([vertices[v] for v in f.verts]);face.material_index=mi
                face.smooth=max(abs(c) for c in f.normal)<.999
            cushion.free()
        if groups:
            actions.append('rounded upholstery edges')
    if leaf:
        groups=components(bm,lambda f:f.material_index in leaf)
        envelope=bounds(o);stem_mi=next((i for i,n in enumerate(names) if n=='P4 | Walnut'),0)
        stems=[]
        def blade(start,end,width,mi):
            along=end-start;side=along.cross(Vector((0,0,1)))
            if side.length<.001:side=Vector((1,0,0))
            side.normalize();up=side.cross(along).normalized();rows=[]
            for j in range(13):
                t=j/12;half=max(.001,math.sin(math.pi*t)**.85);row=[]
                for k in (-1,0,1):
                    point=start+along*t+side*(k*width*half)+up*(.035*math.sin(math.pi*t)*(1-.45*abs(k)))
                    for axis in range(3):point[axis]=max(envelope[0][axis]+.001,min(envelope[1][axis]-.001,point[axis]))
                    row.append(bm.verts.new(point))
                rows.append(row)
            for j in range(12):
                for k in range(2):
                    face=bm.faces.new((rows[j][k],rows[j+1][k],rows[j+1][k+1],rows[j][k+1]));face.material_index=mi;face.smooth=True
        def stem(start,end):
            direction=end-start;side=direction.cross(Vector((0,0,1)))
            if side.length<.001:side=Vector((1,0,0))
            side.normalize();up=side.cross(direction).normalized();rings=[]
            for pos,radius in ((start,.005),(end,.0025)):
                rings.append([bm.verts.new(pos+radius*(math.cos(i*math.tau/6)*side+math.sin(i*math.tau/6)*up)) for i in range(6)])
            for i in range(6):
                f=bm.faces.new((rings[0][i],rings[0][(i+1)%6],rings[1][(i+1)%6],rings[1][i]));f.material_index=stem_mi;f.smooth=True
        for group in groups:
            mi=next(f.material_index for v in group for f in v.link_faces if f.material_index in leaf)
            lo=Vector([min(v.co[i] for v in group) for i in range(3)]);hi=Vector([max(v.co[i] for v in group) for i in range(3)])
            center=(lo+hi)*.5;extent=(hi-lo)*.5
            bmesh.ops.delete(bm,geom=list(group),context='VERTS')
            if len(groups)==1:
                # Desk-item meshes contain an offset miniature succulent, not a
                # plant whose trunk is at the object's origin. Keep its own bounds.
                root=Vector((center.x,center.y,lo.z+.003))
                for angle in (0,1.26,2.51,3.77,5.03):
                    end=Vector((center.x+math.cos(angle)*extent.x*.80,center.y+math.sin(angle)*extent.y*.80,hi.z-.004))
                    blade(root,end,min(extent.x,extent.y)*.32,mi)
                continue
            radial=Vector((center.x,center.y,0))
            if radial.length>.04:
                direction=radial.normalized();root=Vector((0,0,center.z-.07))
                start=root+direction*.045;end=center+direction*max(extent.x,extent.y)*.8+Vector((0,0,.015))
                stem(root,start);blade(start,end,min(.09,max(extent.x,extent.y)*.7),mi)
            else:
                root=Vector((0,0,lo.z-.06));stems.append(root)
                for angle in (0,2.1,4.2):
                    end=Vector((math.cos(angle)*extent.x*.85,math.sin(angle)*extent.y*.85,hi.z-.012))
                    blade(root,end,max(extent.x,extent.y)*.40,mi)
        if stems:
            # A central tapered shoot joins the crown to the pre-existing trunk.
            top=max(stems,key=lambda v:v.z);stem(Vector((0,0,top.z-.30)),top)
        actions.append('curved pointed leaves replacing cone foliage')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();me.update()
    return actions

def refine():
    """Refresh only Phase 4 soft furniture/foliage from the immutable pre-phase mesh."""
    bpy.ops.wm.open_mainfile(filepath=str(WORK))
    changes=json.loads((OUT/'changes.json').read_text(encoding='utf-8'))
    audit=json.loads((OUT/'audit.json').read_text(encoding='utf-8'))
    source_names={v['name']:v['mesh'] for v in audit['targets']}
    wanted=sorted({source_names[n] for n in changes['geometry_changes']})
    with bpy.data.libraries.load(str(BACKUP),link=False) as (src,dst):dst.meshes=wanted.copy()
    sources=dict(zip(wanted,dst.meshes));cache={}
    for name in changes['geometry_changes']:
        o=bpy.data.objects[name];mats=list(o.data.materials)
        key=(source_names[name],tuple(m.name if m else None for m in mats),tuple(o.scale))
        if key not in cache:
            o.data=sources[source_names[name]].copy()
            for i,m in enumerate(mats):o.data.materials[i]=m
            refine_geometry(o);uv_local(o);cache[key]=o.data
        else:o.data=cache[key]
    # Preserve the original room/cabinet labels; discard only our added overlays.
    removed=[]
    for name in list(changes['new_details']):
        if name.removeprefix('P4_Print_').startswith(EXISTING_PRINT_OWNERS):
            obj=bpy.data.objects.get(name)
            if obj:bpy.data.objects.remove(obj,do_unlink=True)
            changes['new_details'].remove(name);removed.append(name)
    changes['excluded_existing_label_owners']=list(EXISTING_PRINT_OWNERS)
    changes['views']=VIEWS
    write('changes.json',changes)
    bpy.context.view_layer.update()
    before=json.loads((OUT/'before_snapshot.json').read_text());oldbounds=json.loads((OUT/'before_bounds.json').read_text())
    check(before,p2.snapshot(),changes,oldbounds)
    bpy.context.scene['phase4_revision']='Furniture and set dressing 2026-10-16 / visual polish 2'
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
    print('P4_REFINED',len(changes['geometry_changes']),'print groups',len(changes['new_details']),'redundant overlays removed',len(removed),flush=True)

def label_details(o, coll):
    """Print on existing label plates and upright book spines; joined per owner."""
    if o.name=='IT_Bookcase_North':return None
    if o.name.startswith(EXISTING_PRINT_OWNERS):return None
    slots=[m.name if m else '' for m in o.data.materials]
    candidates=[]
    for f in o.data.polygons:
        mat=slots[f.material_index]
        if mat=='P4 | Label' and f.normal.y<-.95 and f.area>.00025:candidates.append((f,False))
        elif (mat.startswith('P4 | Book') or mat=='P1 | Binder') and f.normal.y<-.95:
            points=[o.data.vertices[i].co for i in f.vertices]
            if max(v.z for v in points)-min(v.z for v in points)>.12 and f.area>.003:candidates.append((f,True))
    if not candidates:return None
    verts=[];faces=[];mis=[]; ink=bpy.data.materials['P4 | Printed ink'];paper=bpy.data.materials['P4 | Label']
    for index,(f,book) in enumerate(candidates):
        pts=[o.data.vertices[i].co for i in f.vertices];lo=Vector([min(v[i] for v in pts) for i in range(3)]);hi=Vector([max(v[i] for v in pts) for i in range(3)])
        w=hi.x-lo.x;h=hi.z-lo.z
        if w<.014:continue
        pos=f.center.copy();pos.y-=.0007
        if book:
            w*=.75;h=min(h*.30,.065)
            base=len(verts);verts.extend([(pos.x-w/2,pos.y,pos.z-h/2),(pos.x+w/2,pos.y,pos.z-h/2),(pos.x+w/2,pos.y,pos.z+h/2),(pos.x-w/2,pos.y,pos.z+h/2)])
            faces.append(tuple(base+i for i in range(4)));mis.append(1);pos.y-=.0005
        cu=bpy.data.curves.new('P4 print','FONT');cu.body=('REF' if book else 'PARTS' if o.name.startswith('ST_') else 'FILE')+'\n%03d'%(index+1);cu.size=min(w/3.6,h/2.8);cu.align_x='CENTER';cu.align_y='CENTER';cu.resolution_u=1
        temp=bpy.data.objects.new('P4 print temp',cu);coll.objects.link(temp)
        bpy.context.view_layer.update();mesh=bpy.data.meshes.new_from_object(temp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        base=len(verts);rot=Matrix.Rotation(math.pi/2,3,'X')
        verts.extend([pos+rot@v.co for v in mesh.vertices]);faces.extend([tuple(base+i for i in p.vertices) for p in mesh.polygons]);mis.extend([0]*len(mesh.polygons))
        bpy.data.objects.remove(temp,do_unlink=True);bpy.data.meshes.remove(mesh);bpy.data.curves.remove(cu)
    if not verts:return None
    me=bpy.data.meshes.new('P4 print '+o.name);me.from_pydata(verts,[],faces);me.materials.append(ink);me.materials.append(paper)
    for f,mi in zip(me.polygons,mis):f.material_index=mi
    detail=bpy.data.objects.new('P4_Print_'+o.name,me);coll.objects.link(detail);detail.parent=o;detail.matrix_parent_inverse=Matrix.Identity(4);detail.matrix_basis=Matrix.Identity(4);uv_local(detail)
    return detail.name

def build():
    assert not BACKUP.exists(),'Phase 4 backup exists: inspect state instead of rebuilding'
    bpy.ops.wm.open_mainfile(filepath=str(WORK));s=bpy.context.scene
    assert not s.get('phase4_revision')
    shutil.copy2(WORK,BACKUP);before=p2.snapshot();write('before_snapshot.json',before)
    oldbounds={o.name:bounds(o) for o in s.objects if o.type=='MESH'};write('before_bounds.json',oldbounds)
    mapping,paths=materials();changed=[];geometry={};cache={};new=[];bevelled=[]
    detailcoll=bpy.data.collections.new('P4 | Furniture printed details');s.collection.children.link(detailcoll)
    for o in list(s.objects):
        if not target(o):continue
        mapped=[mapping.get(m.name,m) if m else None for m in o.data.materials]
        if mapped==list(o.data.materials):continue
        kind='plant' if any(m and m.name.startswith('P4 | Leaf') for m in mapped) else 'soft' if 'Chair' in o.name or 'Sofa' in o.name else 'hard'
        key=(o.data.name,tuple(m.name if m else None for m in mapped),tuple(o.scale),kind)
        if key in cache:
            o.data,actions=cache[key]
        else:
            o.data=o.data.copy()
            for i,m in enumerate(mapped):o.data.materials[i]=m
            actions=refine_geometry(o);uv_local(o);cache[key]=(o.data,actions)
        if actions:geometry[o.name]=actions
        # Small highlights on furniture only. Do not bevel tiny printed legends or glassware.
        if not actions and any(k in o.name for k in ('Desk','Table','Cabinet','Locker','Bookcase','Shelf','Bench','Counter','Fridge','Partition','Drawer','Credenza')) and not o.modifiers:
            p1.add_bevel(o,.0012,2);bevelled.append(o.name)
        printed=label_details(o,detailcoll)
        if printed:new.append(printed)
        changed.append(o.name)
    bpy.context.view_layer.update()
    s['phase4_revision']='Furniture and set dressing 2026-10-16'
    report={'changed_objects':changed,'geometry_changes':geometry,'new_details':new,'bevel_objects':bevelled,'unique_processed_meshes':len(cache),'texture_files':paths,'backup':str(BACKUP),'views':VIEWS}
    write('changes.json',report)
    check(before,p2.snapshot(),report,oldbounds)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
    print('P4_SAVED',len(changed),'objects',len(geometry),'geometry refinements',len(new),'print groups',len(paths),'PBR sets',flush=True)

def check(before,after,changes,oldbounds):
    errors=[];allowed=set(changes['changed_objects']);geos=set(changes['geometry_changes'])
    for name,old in before.items():
        if name not in after:errors.append('missing '+name);continue
        for field in ['matrix','parent','properties','hidden']:
            if old[field]!=after[name][field]:errors.append(field+' '+name)
        if name not in geos and old['geometry']!=after[name]['geometry']:errors.append('geometry '+name)
        if name not in allowed and old['materials']!=after[name]['materials']:errors.append('materials '+name)
        if name in geos:
            now=bounds(bpy.data.objects[name]); prev=oldbounds[name]
            if any(now[0][i]<prev[0][i]-.002 or now[1][i]>prev[1][i]+.002 for i in range(3)):errors.append('expanded bounds '+name)
    assert not errors,errors[:20]
    return errors

def verify():
    bpy.ops.wm.open_mainfile(filepath=str(WORK));before=json.loads((OUT/'before_snapshot.json').read_text());changes=json.loads((OUT/'changes.json').read_text());oldbounds=json.loads((OUT/'before_bounds.json').read_text())
    errors=check(before,p2.snapshot(),changes,oldbounds)
    for name in changes['changed_objects']+changes['new_details']:
        o=bpy.data.objects[name];uv=o.data.uv_layers.get('P4_SurfaceUV')
        if not uv or not uv.active_render or any(not math.isfinite(x) for q in uv.data for x in q.uv):errors.append('UV '+name)
    files=json.loads((ROOT/'Preview/โรงเรียนและเมือง/phase0/baseline.json').read_text())['file_hashes']
    for name,h in files.items():
        if p1.sha(ROOT/name)!=h:errors.append('source '+name)
    oldmeshes={};newmeshes={}
    for o in bpy.context.scene.objects:
        if o.type=='MESH':newmeshes[o.data.name]=sum(len(p.vertices)-2 for p in o.data.polygons)
    report={'passed':not errors,'errors':errors,'original_objects_checked':len(before),'changed_objects':len(changes['changed_objects']),'geometry_refined':len(changes['geometry_changes']),'new_print_groups':len(changes['new_details']),'screens_preserved':sum('Monitor_Display_Surface' in n for n in before),'source_files_checked':len(files),'all_original_names_transforms_parents_properties_preserved':True,'refined_geometry_within_original_bounds':True,'unique_base_mesh_triangles':sum(newmeshes.values()),'production_interactions_tested':False,'web_performance_tested':False}
    write('verification.json',report);print('P4_VERIFY',json.dumps(report),flush=True);assert not errors

def render(label,only=None):
    bpy.ops.wm.open_mainfile(filepath=str(BACKUP if label=='before' else WORK));s=bpy.context.scene;c=p1.configure_preview(s)
    s.render.resolution_x=1440;s.render.resolution_y=960;s.cycles.samples=24
    for name,(pos,aim,lens) in VIEWS.items():
        if only and name!=only:continue
        c.location=pos;c.rotation_euler=(Vector(aim)-c.location).to_track_quat('-Z','Y').to_euler();c.data.lens=lens
        lights=[]
        for loc,energy,size in [(Vector(pos)+Vector((0,0,.8)),110,2),(Vector(aim)+Vector((.3,-.3,1.5)),90,1.5)]:
            d=bpy.data.lights.new('P4 review fill','AREA');d.energy=energy;d.shape='DISK';d.size=size
            lamp=bpy.data.objects.new('P4 review fill',d);s.collection.objects.link(lamp);lamp.location=loc;lamp.rotation_euler=(Vector(aim)-loc).to_track_quat('-Z','Y').to_euler();lights.append(lamp)
        folder=OUT/'ใช้ร่วมกัน/renders';folder.mkdir(exist_ok=True);s.render.filepath=str(folder/f'{label}_{name}.png');bpy.ops.render.render(write_still=True)
        for lamp in lights:bpy.data.objects.remove(lamp,do_unlink=True)
        print('P4_RENDERED',label,name,flush=True)

def export():
    changes=json.loads((OUT/'changes.json').read_text(encoding='utf-8'))
    # Only require materials actually referenced by exported visible meshes.
    bpy.ops.wm.open_mainfile(filepath=str(WORK))
    used={m.name for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render for m in o.data.materials if m}
    write('godot_preview/expectations.json',{'materials':sorted(set(changes['texture_files']) & used),'print_groups':len(changes['new_details']),'views':VIEWS})
    p2.WORK=WORK;p2.OUT=OUT;p2.export()
    path=OUT/'godot_preview/architecture.glb';path.replace(path.with_name('furniture_map.glb'))

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:];mode=args[0]
    if mode=='audit':audit()
    elif mode=='build':build()
    elif mode=='refine':refine()
    elif mode=='verify':verify()
    elif mode in ('before','after'):render(mode,args[1] if len(args)>1 else None)
    elif mode=='export':export()
