"""Phase 1 IT desk look-development; isolated working .blend and test export."""
import bpy, math, json, sys, hashlib, shutil, array
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend'
BASELINE = ROOT / '3Dmodel/ใช้ร่วมกัน/blend/classroom_shell.blend'
OUT = ROOT / 'Preview/โรงเรียนและเมือง/phase1'
OUT.mkdir(parents=True, exist_ok=True)
RENDERS = OUT / 'ใช้ร่วมกัน/renders'
RENDERS.mkdir(exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))

def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest()

def create_material(name,paths,metal=0,normal_strength=1):
    m=bpy.data.materials.new('P1 | '+name); m.use_nodes=True
    nodes=m.node_tree.nodes; links=m.node_tree.links; p=nodes.get('Principled BSDF')
    p.inputs['Metallic'].default_value=metal
    for channel in ('BaseColor','Roughness','Normal'):
        t=nodes.new('ShaderNodeTexImage'); im=bpy.data.images.load(str(paths[channel]),check_existing=True)
        if channel!='BaseColor': im.colorspace_settings.name='Non-Color'
        im.pack(); t.image=im; t.label=channel; t.location=(-520,260-190*len(nodes))
        if channel=='Normal':
            normal=nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=normal_strength
            links.new(t.outputs['Color'],normal.inputs['Color']); links.new(normal.outputs['Normal'],p.inputs['Normal'])
        else:
            links.new(t.outputs['Color'],p.inputs['Base Color' if channel=='BaseColor' else 'Roughness'])
    return m

def box_uv(o,scales):
    mesh=o.data; uv=mesh.uv_layers.get('P1_SurfaceUV') or mesh.uv_layers.new(name='P1_SurfaceUV')
    mesh.uv_layers.active=uv
    uv.active_render=True
    for p in mesh.polygons:
        material=mesh.materials[p.material_index] if p.material_index<len(mesh.materials) else None
        scale=scales.get(material.name if material else '',1.0)
        norm=(o.matrix_world.to_3x3().inverted().transposed()@p.normal).normalized()
        axis=max(range(3),key=lambda i:abs(norm[i]))
        for li in p.loop_indices:
            co=o.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co
            if axis==2: u,v=co.x,co.y
            elif axis==1: u,v=co.x,co.z
            else: u,v=co.y,co.z
            if norm[axis]<0: u=-u
            uv.data[li].uv=(u/scale,v/scale)

def add_bevel(o,width,segments=3):
    mod=o.modifiers.new('P1 edge highlight','BEVEL'); mod.width=width; mod.segments=segments; mod.limit_method='ANGLE'
    mod.angle_limit=math.radians(35)
    mod.affect='EDGES'; mod.use_clamp_overlap=True
    norm=o.modifiers.new('P1 weighted normals','WEIGHTED_NORMAL'); norm.keep_sharp=True; norm.weight=30

def build_corner():
    import phase1_surface_textures
    s=open_scene(WORK)
    assert not s.get('phase1_it_corner_revision'), 'Already built. Review existing file instead of overwriting.'
    backup=WORK.with_name('classroom_shell_lookdev_before_phase1.blend')
    assert not backup.exists(); shutil.copy2(WORK,backup)
    source_hash=sha(BASELINE)
    original={o.name:{'matrix':[list(r) for r in o.matrix_world], 'data':o.data, 'parent':o.parent.name if o.parent else None} for o in s.objects}
    paths=phase1_surface_textures.generate(OUT/'textures')
    materials={k:create_material(k,p,0) for k,p in paths.items()}
    scales={materials[k].name:v for k,v in {'Oak':1.4,'Paint':.35,'CoatedWhite':.3,'Polymer':.12,'PowderCoat':.15,'Rubber':.16,'Binder':.18,'Fabric':.24,'Tile':.6}.items()}
    changes=[]
    def replace(o,mapping,bevel=0):
        o.data=o.data.copy()
        for i,m in enumerate(list(o.data.materials)):
            if m and m.name in mapping: o.data.materials[i]=materials[mapping[m.name]]
        box_uv(o,scales)
        if bevel: add_bevel(o,bevel)
        changes.append(o.name)
    replace(bpy.data.objects['IT_PlayerDesk'],{'MAT_Desk_Light_Wood':'Oak','MAT_Teacher_Desk_Panel':'Oak','MAT_Desk_Frame_Charcoal':'PowderCoat','MAT_Desk_Black_Accent':'Rubber'},.0012)
    replace(bpy.data.objects['Chair_IT_PlayerDesk_1'],{'Chair | navy upholstery':'Fabric','Chair | graphite powder-coated steel':'PowderCoat','Chair | rubber floor glides':'Rubber'},.008)
    replace(bpy.data.objects['IT_Bookcase_North'],{'OF | white laminate':'CoatedWhite','OF | binder black':'Binder'},.0015)
    replace(bpy.data.objects['IT_Support_North_Floor'],{'MAP | IT pale warm grey':'Tile'})
    replace(bpy.data.objects['Left_Top_Wall_End'],{'MAT_Wall_Warm_White':'Paint'})
    # All components of the player's own computer; keep screen mesh untouched.
    root=bpy.data.objects['TeacherComputerSet_Root.001']
    for o in root.children_recursive:
        if o.type!='MESH' or 'Monitor_Display_Surface' in o.name: continue
        mapping={}
        for m in o.data.materials:
            if not m: continue
            if m.name.startswith('Polymer | charcoal'): mapping[m.name]='Polymer'
            elif m.name.startswith('Steel | graphite'): mapping[m.name]='PowderCoat'
            elif m.name.startswith('Rubber | grip'): mapping[m.name]='Rubber'
        if mapping: replace(o,mapping)
    # Blender-generated printed spine labels are geometry, so they export reliably.
    details=bpy.data.collections.new('P1 | IT corner surface details'); s.collection.children.link(details)
    bpy.ops.object.select_all(action='DESELECT')
    ink=bpy.data.materials.new('P1 | archive ink'); ink.diffuse_color=(.015,.025,.035,1); ink.use_nodes=True
    ink.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.015,.025,.035,1)
    ink.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.8
    for row in range(5):
        for col in range(27):
            x=-11.15-.9+.05+.03+col*.064
            if x>-10.34: continue
            d=bpy.data.curves.new('P1_Spine_Print','FONT'); d.body=f'IT\n{row+1:01d}-{col+1:02d}'; d.align_x='CENTER'; d.align_y='CENTER'; d.size=.009; d.space_line=1.25; d.resolution_u=1
            o=bpy.data.objects.new(f'P1_BinderLabel_{row+1}_{col+1:02d}',d); details.objects.link(o)
            o.location=(x,43.96-.38*.375-.026,row*.4+.022+.288*.6)
            o.rotation_euler=(math.pi/2,0,0); d.materials.append(ink)
            bpy.context.view_layer.objects.active=o; o.select_set(True)
            bpy.ops.object.convert(target='MESH'); o.select_set(False)
    # Do not move furniture or modify the interactive screen's dimensions.
    bpy.context.view_layer.update()
    assert all(o.name in s.objects for o in bpy.data.objects if o.name in original)
    for name,old in original.items():
        o=s.objects[name]
        assert max(abs(o.matrix_world[i][j]-old['matrix'][i][j]) for i in range(4) for j in range(4))<1e-6,name
        assert (o.parent.name if o.parent else None)==old['parent'],name
        if name not in changes: assert o.data==old['data'],name
    s['phase1_it_corner_revision']='PBR sample 2026-10-15; requires visual approval before rollout'
    s['phase1_changed_objects']=json.dumps(changes)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
    assert sha(BASELINE)==source_hash
    report={'working_file':str(WORK),'backup':str(backup),'source_map_unchanged':True,'changed_objects':changes,
            'new_detail_objects':[o.name for o in details.objects], 'all_original_names_parents_transforms_preserved':True,
            'interactive_screen_unchanged':True,'texture_files':{k:{c:str(p) for c,p in v.items()} for k,v in paths.items()},
            'scope_note':'Only player desk/chair/computer, north bookcase, IT north floor and north wall. North floor/wall are continuous meshes so their material changes cover that room surface.'}
    (OUT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('P1_SAVED',len(changes),'modified objects',flush=True)

def export_sample():
    import tempfile
    scratch=OUT/'export_temp'; scratch.mkdir(exist_ok=True)
    tempfile.tempdir=str(scratch)
    s=open_scene(WORK)
    selected=[]
    bpy.ops.object.select_all(action='DESELECT')
    required={'IT_Support_North_Floor','IT_North_Ceiling','Left_Top_Wall_End','Left_Top_Wall_End_Skirting'}
    for o in s.objects:
        if o.type!='MESH' or o.hide_render or o.name.startswith('Plan_'): continue
        points=[o.matrix_world@Vector(v) for v in o.bound_box]
        center=sum(points,Vector())/8
        if (-21.25<center.x<-9.15 and 37<center.y<44.4) or o.name in required:
            o.hide_set(False); o.select_set(True); selected.append(o)
    test=OUT/'godot_preview'; test.mkdir(exist_ok=True)
    bpy.context.view_layer.objects.active=selected[0]
    bpy.ops.export_scene.gltf(filepath=str(test/'it_corner.glb'),export_format='GLB',use_selection=True,export_apply=True,
                              export_animations=False,export_cameras=False,export_lights=False)
    (OUT/'export_selection.json').write_text(json.dumps([o.name for o in selected],indent=2),encoding='utf-8')
    print('SAMPLE_EXPORTED',len(selected),flush=True)

def refine():
    s=open_scene(WORK)
    for name in json.loads(s['phase1_changed_objects']):
        o=s.objects[name]
        o.data.uv_layers['P1_SurfaceUV'].active_render=True
    for name,strength in [('Polymer',.12),('PowderCoat',.15),('Rubber',.2),('Paint',.25)]:
        m=bpy.data.materials['P1 | '+name]
        for n in m.node_tree.nodes:
            if n.type=='NORMAL_MAP': n.inputs['Strength'].default_value=strength
    chair=s.objects['Chair_IT_PlayerDesk_1']
    chair.modifiers['P1 edge highlight'].angle_limit=math.radians(20)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)

def open_scene(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    return bpy.context.scene

def configure_preview(s):
    s.render.engine = 'CYCLES'
    s.cycles.samples = 32
    s.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'
        prefs.get_devices()
        for device in prefs.devices:
            device.use = device.type != 'CPU'
        s.cycles.device = 'GPU' if any(d.use for d in prefs.devices) else 'CPU'
    except Exception:
        s.cycles.device = 'CPU'
    s.render.resolution_x = 1440
    s.render.resolution_y = 1080
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'PNG'
    s.view_settings.view_transform = 'AgX'
    s.view_settings.exposure = 0
    s.render.film_transparent = False
    # Identical preview lighting for before and after, kept out of the map file.
    def light(name, pos, energy, size, color):
        d = bpy.data.lights.new(name, 'AREA'); d.energy=energy; d.shape='DISK'; d.size=size; d.color=color
        o = bpy.data.objects.new(name,d); s.collection.objects.link(o); o.location=pos
        o.rotation_euler = (Vector((-13.5,42.3,.8))-o.location).to_track_quat('-Z','Y').to_euler()
    light('P1_Preview_Key',(-15.2,40.3,2.8),160,2.0,(1.0,.91,.80))
    light('P1_Preview_Fill',(-10.8,41.8,2.7),100,1.8,(.80,.89,1.0))
    d=bpy.data.cameras.new('P1_Preview_Camera'); c=bpy.data.objects.new('P1_Preview_Camera',d)
    s.collection.objects.link(c); s.camera=c; d.clip_start=.04; d.clip_end=150
    return c

VIEWS = {
    'hero': ((-16.3,39.9,1.75),(-12.9,42.9,1.02),34),
    'detail': ((-14.85,41.45,1.46),(-13.58,42.55,.93),42),
    'surfaces': ((-12.6,42.2,1.2),(-11.3,43.85,1.02),48),
}

def render_views(label):
    s=bpy.context.scene; c=configure_preview(s)
    for name,(pos,target,lens) in VIEWS.items():
        c.location=pos; c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler(); c.data.lens=lens
        s.render.filepath=str(RENDERS/f'{label}_{name}.png'); bpy.ops.render.render(write_still=True)
        print('RENDERED',label,name,flush=True)

if __name__ == '__main__':
    mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'before'
    if mode=='before':
        open_scene(WORK)
        for name in ['IT_PlayerDesk','Chair_IT_PlayerDesk_1','IT_Bookcase_North','IT_PlayerDesk_Items','IT_Floor','IT_North_Floor','Left_Top_Wall_End']:
            o=bpy.data.objects.get(name)
            if o:
                print('TARGET',name,'materials',[m.name for m in o.data.materials],'scale',list(o.scale),'modifiers',[(m.name,m.type) for m in o.modifiers],flush=True)
        render_views('before')
    elif mode=='build':
        build_corner()
    elif mode=='after':
        open_scene(WORK); render_views('after')
    elif mode=='export':
        export_sample()
    elif mode=='refine':
        refine()
