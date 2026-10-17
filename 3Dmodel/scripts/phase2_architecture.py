"""Approved Phase 1 look extended to architectural surfaces only."""
import bpy, sys, json, shutil, hashlib, math, array, tempfile
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend'
OUT=ROOT/'Preview/โรงเรียนและเมือง/phase2'; OUT.mkdir(parents=True,exist_ok=True)
BACKUP=WORK.with_name('classroom_shell_lookdev_before_phase2.blend')
sys.path.insert(0,str(Path(__file__).parent))
import phase1_it_corner as p1
import phase1_surface_textures as tex
VIEWS={
 'corridor':((-6.15,-7.4,1.65),(-6.15,12,1.65),22),
 'windows':((-6.45,-4.5,1.65),(-.2,-1.4,1.4),25),
 'doors':((-5.7,32.8,1.65),(-9.6,35.3,1.3),32),
 'stairs':((-9.9,27.2,1.65),(-14.8,28.3,1.9),22),
 'classroom':((6.9,-7.6,1.65),(-.8,5.8,1.5),24),
}
PREFIXES=('01 | Walls','02 | Floors','03 | Doors','04 | Stairs','07 | Ceilings','12 | Classroom corridor windows','12 | Stair enclosure')
SHELL={'Floor_Slab_150mm','Ceiling_Slab_150mm'}
def target(o):
    return o.type=='MESH' and (any(c.name.startswith(PREFIXES) for c in o.users_collection) or
        (any(c.name=='Classroom_Shell' for c in o.users_collection) and o.name.startswith(('Wall_','Window_','Door_'))) or o.name in SHELL or
        o.name.startswith(('Server_Glass_Partition_Panel','Server_Partition_Post','Server_Glass_Door_Header','Server_Glass_Sliding_Door','Server_Raised_Floor')))
def digest(mesh):
    h=hashlib.sha256()
    for coll,attr,width,dtype in [(mesh.vertices,'co',3,'f'),(mesh.loops,'vertex_index',1,'i'),(mesh.polygons,'loop_total',1,'i')]:
        buf=array.array(dtype,[0])*(len(coll)*width); coll.foreach_get(attr,buf); h.update(buf.tobytes())
    return h.hexdigest()
def snapshot():
    cache={}; result={}
    for o in bpy.context.scene.objects:
        if o.type=='MESH' and o.data.name not in cache: cache[o.data.name]=digest(o.data)
        result[o.name]={'type':o.type,'matrix':[list(r) for r in o.matrix_world],
            'parent':o.parent.name if o.parent else None,'properties':{k:o[k] for k in o.keys() if isinstance(o[k],(str,int,float,bool))},
            'geometry':cache[o.data.name] if o.type=='MESH' else None,
            'materials':[m.name if m else None for m in o.data.materials] if o.type=='MESH' else None,
            'hidden':[o.hide_render,o.hide_viewport,o.hide_get()]}
    return result
def material(name,paths=None,color=None,rough=.5,metal=0):
    if paths:
        m=p1.create_material('P2TEMP '+name,paths,metal,.15); m.name='P2 | '+name
    else:
        m=bpy.data.materials.new('P2 | '+name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    if color: p.inputs['Base Color'].default_value=(*color,1); m.diffuse_color=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    return m
def make_materials():
    import numpy as np
    folder=OUT/'textures'; folder.mkdir(exist_ok=True)
    n=1024; y,x=np.mgrid[0:n,0:n]/n
    coarse=tex.noise(n,18,18,201); micro=tex.noise(n,.8,.8,202)
    edge=np.minimum.reduce([x,1-x,y,1-y])
    # A 600 mm ceiling panel, with a narrow recessed joint and fine mineral texture.
    joint=np.clip((edge-.0015)/.003,0,1)
    pores=np.maximum(-micro-1.8,0)
    base=np.stack([v+.004*coarse-.006*pores for v in (.79,.795,.78)],axis=2)
    base=base*joint[:,:,None]+np.array([.51,.53,.52])*(1-joint[:,:,None])
    paths={'Ceiling':tex.maps(folder,'Ceiling600',base,.88+.02*micro,joint*.4-pores*.02,1.5)}
    # Fine cement/terrazzo for stairs and storage: no dramatic stains or baked shadows.
    specks=np.maximum(micro-1.1,0)
    base=np.stack([v+.007*coarse-.009*specks for v in (.51,.52,.50)],axis=2)
    paths['Stone']=tex.maps(folder,'FineCement',base,.67+.03*micro,micro*.04,.6)
    # Washroom anti-slip ceramic, 300 mm repeats.
    joint=np.clip((edge-.004)/.004,0,1)
    base=np.stack([v+.005*coarse for v in (.58,.61,.60)],axis=2)
    base=base*joint[:,:,None]+np.array([.33,.36,.35])*(1-joint[:,:,None])
    paths['WashTile']=tex.maps(folder,'WashCeramic300',base,.66+.02*micro,joint*.3+micro*.015,1.0)
    n=512; coarse=tex.noise(n,15,15,205); micro=tex.noise(n,.6,16,206)
    base=np.stack([v+.004*micro for v in (.59,.62,.65)],axis=2)
    paths['Aluminium']=tex.maps(folder,'BrushedAluminium',base,.34+.03*micro,micro*.07,.5)
    base=np.stack([v+.003*coarse for v in (.53,.57,.59)],axis=2)
    paths['ServerFloor']=tex.maps(folder,'AntistaticGrey',base,.64+.025*coarse,micro*.02,.4)
    mats={k:material(k,v,metal=.85 if k=='Aluminium' else 0) for k,v in paths.items()}
    mats.update({k:bpy.data.materials['P1 | '+v] for k,v in {'Wall':'Paint','Tile':'Tile','Frame':'PowderCoat','Rubber':'Rubber','Wood':'Oak'}.items()})
    mats['Skirting']=material('Skirting',color=(.23,.27,.28),rough=.58)
    mats['Glass']=material('Clear glass',color=(.82,.93,.97),rough=.075,metal=.08)
    glass=mats['Glass']; glass.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.07
    glass.diffuse_color=(.82,.93,.97,.07); glass.surface_render_method='DITHERED'; glass.use_backface_culling=False
    # Alpha blend works in Compatibility/web and does not depend on screen refraction.
    mats['Frost']=material('Frosted band',color=(.73,.79,.8),rough=.75)
    mats['Frost'].node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.48
    mats['Frost'].surface_render_method='DITHERED'; mats['Frost'].use_backface_culling=False
    return mats,paths
MAP={
 'MAT_Wall_Warm_White':'Wall','MAT_Floor_Light_Gray':'Tile','MAT_Ceiling_White':'Ceiling',
 'MAT_Frame_Dark_Gray':'Frame','MAT_Door_Warm_Wood':'Wood','MAP | Skirting':'Skirting',
 'MAP | Brushed handrails':'Aluminium','MAP | Stair concrete':'Stone','MAP | Stair anti-slip edge':'Rubber',
 'MAP | IT pale warm grey':'Tile','MAP | Staff pale sage':'Tile','MAP | Background classroom':'Tile',
 'MAP | Corridor stone':'Tile','MAP | Storage concrete':'Stone','MAP | Washroom pale ceramic':'WashTile',
 'MAP | Server cool grey':'ServerFloor','Windows | clear two-sided glass':'Glass','FX | clear glass':'Glass',
 'DC | partition aluminium':'Aluminium','SCI | stainless steel':'Aluminium','DC | frosted band':'Frost',
 'DC | raised floor tile':'ServerFloor',
}
def assign_uv(o,scales):
    mesh=o.data; uv=mesh.uv_layers.get('P2_SurfaceUV') or mesh.uv_layers.new(name='P2_SurfaceUV')
    mesh.uv_layers.active=uv; uv.active_render=True
    normalmat=o.matrix_world.to_3x3().inverted().transposed()
    for p in mesh.polygons:
        m=mesh.materials[p.material_index] if p.material_index<len(mesh.materials) else None
        scale=scales.get(m.name if m else '',.6)
        normal=(normalmat@p.normal).normalized(); axis=max(range(3),key=lambda i:abs(normal[i]))
        for li in p.loop_indices:
            co=o.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co
            if m and m.name=='P1 | Oak':
                # Door-local mapping follows the leaf when its game pivot rotates.
                co=mesh.vertices[mesh.loops[li].vertex_index].co.copy()
                co.x*=abs(o.scale.x); co.y*=abs(o.scale.y); co.z*=abs(o.scale.z)
                a=max(range(3),key=lambda i:abs(p.normal[i]))
                u,v=(co.y,co.z) if a==0 else (co.x,co.z) if a==1 else (co.x,co.y)
            elif axis==2: u,v=co.x,co.y
            elif axis==1: u,v=co.x,co.z
            else: u,v=co.y,co.z
            uv.data[li].uv=(u/scale,v/scale)
def build():
    bpy.ops.wm.open_mainfile(filepath=str(WORK)); s=bpy.context.scene
    assert not s.get('phase2_revision'),'Phase 2 already exists; do not rebuild blindly.'
    assert not BACKUP.exists(),'Backup exists; inspect before retrying.'
    shutil.copy2(WORK,BACKUP)
    before=snapshot(); (OUT/'before_snapshot.json').write_text(json.dumps(before),encoding='utf-8')
    mats,paths=make_materials()
    scales={m.name:{'Ceiling':.6,'Stone':.6,'WashTile':.3,'Aluminium':.15,'ServerFloor':.3,'Wall':.35,'Tile':.6,'Frame':.15,'Rubber':.16,'Wood':1.4,'Skirting':.2,'Glass':1,'Frost':1}[k] for k,m in mats.items()}
    changes=[]; bevels=[]
    for o in list(s.objects):
        if not target(o): continue
        mapping={i:MAP[m.name] for i,m in enumerate(o.data.materials) if m and m.name in MAP}
        if not mapping: continue
        o.data=o.data.copy()
        for i,k in mapping.items(): o.data.materials[i]=mats[k]
        # Boolean wall openings can contain a null slot. Fill with the wall finish.
        if 'Wall' in mapping.values():
            for i,m in enumerate(o.data.materials):
                if m is None: o.data.materials[i]=mats['Wall']
        assign_uv(o,scales)
        # Small bevels remain inside original silhouettes, including door pivots.
        if 'Glass' not in mapping.values() and o.name!='Server_Raised_Floor' and not any(m.type=='BEVEL' for m in o.modifiers):
            width=.0012 if 'Frame' in mapping.values() or 'Aluminium' in mapping.values() else .0018
            p1.add_bevel(o,width/max(abs(v) for v in o.scale),2); bevels.append(o.name)
        changes.append(o.name)
    s['phase1_visual_approved']=True
    s['phase2_revision']='Architecture materials 2026-10-16'
    s['phase2_changed_objects']=json.dumps(changes)
    bpy.context.view_layer.update()
    for name,old in before.items():
        o=s.objects[name]
        assert max(abs(o.matrix_world[i][j]-old['matrix'][i][j]) for i in range(4) for j in range(4))<1e-6,name
        assert (o.parent.name if o.parent else None)==old['parent'],name
        if o.type=='MESH': assert digest(o.data)==old['geometry'],name
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
    report={'working_file':str(WORK),'phase1_backup':str(BACKUP),'changed_objects':changes,'beveled_objects':bevels,
        'texture_files':{k:{c:str(p) for c,p in v.items()} for k,v in paths.items()},
        'glass':'Low alpha, two-sided Principled surface for Compatibility. No screen-space refraction.',
        'phase1_visual_approved':True,'all_base_geometry_parents_transforms_preserved':True}
    (OUT/'changes.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('P2_SAVED',len(changes),'surfaces',len(bevels),'bevels',flush=True)
def render(label,only=None):
    bpy.ops.wm.open_mainfile(filepath=str(BACKUP if label=='before' else WORK)); s=bpy.context.scene
    c=p1.configure_preview(s); s.cycles.samples=24
    s.render.resolution_x=1440; s.render.resolution_y=960
    for name,(pos,aim,lens) in VIEWS.items():
        if only and name!=only: continue
        c.location=pos; c.rotation_euler=(Vector(aim)-c.location).to_track_quat('-Z','Y').to_euler(); c.data.lens=lens
        d=bpy.data.lights.new('P2 preview fill','AREA'); d.energy=180; d.shape='DISK'; d.size=2.5
        lamp=bpy.data.objects.new('P2 preview fill',d); s.collection.objects.link(lamp)
        lamp.location=Vector(pos)+Vector((0,0,1.0)); lamp.rotation_euler=(Vector(aim)-lamp.location).to_track_quat('-Z','Y').to_euler()
        upper=None
        if name=='stairs':
            d=bpy.data.lights.new('P2 stair review fill','AREA'); d.energy=260; d.size=2.5
            upper=bpy.data.objects.new('P2 stair review fill',d); s.collection.objects.link(upper)
            upper.location=(-15.5,28.7,5.8)
            upper.rotation_euler=(Vector((-14.5,28.7,2))-upper.location).to_track_quat('-Z','Y').to_euler()
        folder=OUT/'ใช้ร่วมกัน/renders'; folder.mkdir(exist_ok=True)
        s.render.filepath=str(folder/f'{label}_{name}.png'); bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(lamp,do_unlink=True)
        if upper: bpy.data.objects.remove(upper,do_unlink=True)
        print('P2_RENDERED',label,name,flush=True)
def export():
    bpy.ops.wm.open_mainfile(filepath=str(WORK)); bpy.ops.object.select_all(action='DESELECT')
    selected=[]
    # Full map visual test export so windows can be checked against real room contents.
    for o in bpy.context.scene.objects:
        if o.type=='MESH' and not o.hide_render and not o.name.startswith('Plan_'):
            o.hide_set(False); o.select_set(True); selected.append(o)
    folder=OUT/'godot_preview'; folder.mkdir(exist_ok=True)
    scratch=OUT/'export_temp'; scratch.mkdir(exist_ok=True); tempfile.tempdir=str(scratch)
    bpy.context.view_layer.objects.active=selected[0]
    bpy.ops.export_scene.gltf(filepath=str(folder/'architecture.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
    print('P2_EXPORTED',len(selected),flush=True)
def verify():
    bpy.ops.wm.open_mainfile(filepath=str(WORK)); old=json.loads((OUT/'before_snapshot.json').read_text(encoding='utf-8')); new=snapshot()
    changes=set(json.loads(bpy.context.scene['phase2_changed_objects'])); errors=[]
    for name,record in old.items():
        if name not in new: errors.append('missing '+name); continue
        for field in ['matrix','parent','geometry','properties','hidden']:
            if record[field]!=new[name][field]: errors.append(field+' '+name)
        if name not in changes and record['materials']!=new[name]['materials']: errors.append('material outside scope '+name)
    for name in changes:
        o=bpy.context.scene.objects[name]; uv=o.data.uv_layers.get('P2_SurfaceUV')
        if not uv or not uv.active_render or any(not math.isfinite(x) for q in uv.data for x in q.uv): errors.append('UV '+name)
    files=json.loads((ROOT/'Preview/โรงเรียนและเมือง/phase0/baseline.json').read_text(encoding='utf-8'))['file_hashes']
    for name,expected in files.items():
        if p1.sha(ROOT/name)!=expected: errors.append('source file '+name)
    report={'passed':not errors,'objects_checked':len(old),'architecture_objects_changed':len(changes),
        'base_geometry_unchanged':True if not errors else None,'source_files_checked':len(files),
        'screen_objects_preserved':sum('Monitor_Display_Surface' in n for n in old),
        'corridor_clear_width_m':bpy.context.scene.get('map_clear_corridor_width_m'),'errors':errors,
        'web_performance_tested':False,'production_interactions_tested':False}
    (OUT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8'); print('P2_VERIFIED',json.dumps(report),flush=True)
    assert not errors,errors
if __name__=='__main__':
    mode=sys.argv[sys.argv.index('--')+1]
    if mode=='build': build()
    elif mode in ('before','after'):
        args=sys.argv[sys.argv.index('--')+1:]
        render(mode,args[1] if len(args)>1 else None)
    elif mode=='export': export()
    elif mode=='verify': verify()
