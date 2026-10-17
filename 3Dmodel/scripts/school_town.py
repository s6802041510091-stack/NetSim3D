"""Deterministic, isolated anime-town backdrop; never edits the school source."""
import bpy, math, random, sys, json, tempfile
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
OUT=ROOT/'Preview/โรงเรียนและเมือง/town'
random.seed(43)
G=-7.2
def mat(name,c):
    m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Roughness'].default_value=.8
    return m
def box(n,loc,size,m):
    mesh=bpy.data.meshes.new(n); mesh.from_pydata([(-.5,-.5,-.5),(.5,-.5,-.5),(.5,.5,-.5),(-.5,.5,-.5),(-.5,-.5,.5),(.5,-.5,.5),(.5,.5,.5),(-.5,.5,.5)],[],[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    o=bpy.data.objects.new(n,mesh); bpy.context.collection.objects.link(o); o.location=loc; o.scale=size; mesh.materials.append(m)
    uv=mesh.uv_layers.new()
    for poly in mesh.polygons:
        for j,li in enumerate(poly.loop_indices): uv.data[li].uv=[(0,0),(1,0),(1,1),(0,1)][j]
    return o
def ball(n,loc,size,m):
    if not hasattr(ball,'mesh'):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1); t=bpy.context.object; ball.mesh=t.data.copy(); bpy.data.objects.remove(t,do_unlink=True)
    o=bpy.data.objects.new(n,ball.mesh.copy()); bpy.context.collection.objects.link(o); o.location=loc; o.scale=size; o.data.materials.append(m); return o
def rod(n,a,b,r,m):
    d=Vector(b)-Vector(a); verts=[(r*math.cos(i*math.tau/8),r*math.sin(i*math.tau/8),z) for z in [-d.length/2,d.length/2] for i in range(8)]; faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh=bpy.data.meshes.new(n); mesh.from_pydata(verts,[],faces); o=bpy.data.objects.new(n,mesh); bpy.context.collection.objects.link(o); o.location=(Vector(a)+Vector(b))/2; o.rotation_euler=d.to_track_quat('Z','Y').to_euler(); mesh.materials.append(m)
def build():
    scratch=OUT/'export_temp'; scratch.mkdir(exist_ok=True); tempfile.tempdir=str(scratch)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    global cream,white,green,pink,wood,glass,road
    cream=mat('Warm ivory plaster',(.89,.80,.61)); white=mat('Warm white trim',(.97,.95,.83)); green=mat('Spring lawn',(.39,.66,.26)); pink=mat('Sakura blush',(.98,.46,.61)); wood=mat('Cedar',(.31,.16,.10)); glass=mat('Sky blue window panels',(.23,.57,.70)); road=mat('Soft blue asphalt',(.20,.26,.32))
    paving=mat('Sandstone paths',(.76,.67,.52)); foliage=mat('Mint foliage',(.22,.51,.26)); field=mat('Sports turf',(.31,.57,.25)); clay=mat('Track terracotta',(.72,.37,.27))
    colors=[mat('House '+str(i),c) for i,c in enumerate([(.93,.65,.59),(.92,.83,.52),(.61,.80,.77),(.72,.71,.87),(.90,.83,.69)])]
    roofs=[mat('Roof '+str(i),c) for i,c in enumerate([(.27,.43,.56),(.64,.30,.28),(.36,.49,.46)])]
    # Small packed tile texture, generated locally. UV repetition is intentionally subtle.
    import numpy as np
    from phase1_surface_textures import save_image
    rng=np.random.default_rng(8); tex=np.ones((256,256,3),dtype=np.float32)*[.60,.65,.70]; tex+=rng.normal(0,.025,(256,256,1)); tex[::32,:,:]*=.88
    path=OUT/'textures/asphalt.png'; save_image(path,tex)
    image=bpy.data.images.load(str(path)); image.pack(); nodes=road.node_tree.nodes; t=nodes.new('ShaderNodeTexImage'); t.image=image; road.node_tree.links.new(t.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    box('Town ground',(0,15,G-.25),(1000,1000,.5),green)
    if '--campus-only' in sys.argv:
        # Continuous urban plots outside the existing school ring road.
        for x,w in [(-78,44),(80,42)]: box('Japanese district paving',(x,17,G+.015),(w,200,.03),paving)
        for y in [-64.5,98.5]: box('Japanese district paving',(1.5,y,G+.015),(115,37,.03),paving)
        for x in [-81,83]: box('Outer residential lane',(x,17,G+.04),(5,163,.035),road)
        for y in [-65,100]: box('Outer residential lane',(1,y,G+.04),(164,5,.035),road)
    for x in [-52,55]: box('Ring road',(x,17,G+.015),(8,118,.03),road)
    for y in [-42,76]: box('Ring road',(1.5,y,G+.015),(115,8,.03),road)
    for x in [-46.5,49.5]: box('Sidewalk',(x,17,G+.12),(3,112,.24),paving)
    for y in [-36.5,70.5]: box('Sidewalk',(1.5,y,G+.12),(99,3,.24),paving)
    for x in range(-48,56,7):
        for y in [-42,76]: box('Lane marking',(x,y,G+.04),(3,.12,.02),white)
    for y in range(-37,76,7):
        for x in [-52,55]: box('Lane marking',(x,y,G+.04),(.12,3,.02),white)
    for x in [-45,48]: box('Low school boundary',(x,17,G+.55),(.3,104,1.1),cream)
    box('North school boundary',(1.5,69,G+.55),(93,.3,1.1),cream)
    for x,w in [(-28,34),(25,46)]: box('South boundary gate gap',(x,-35,G+.55),(w,.3,1.1),cream)
    for x in [-11,2]: box('Gate pillar',(x,-35,G+1.3),(.8,.8,2.6),cream)
    for y in [-44,-42,-40]:
        for x in [-9,-7,-5,-3,-1]: box('Crosswalk',(x,y,G+.05),(1.1,1.5,.02),white)
    # Two supporting floors below the unchanged playable third-floor coordinate origin.
    box('Lower school storeys',(-6.061,17.21,G+3.6),(30.426,54.227,7.18),cream)
    for z in [G+3.55,-.10]: box('School floor belt',(-6.061,17.21,z),(30.8,54.6,.22),white)
    for z in [G+1.9,G+5.5]:
        for y in range(-7,44,4):
            for x in [-21.30,9.18]:
                box('Lower floor window',(x,y,z),(.04,2.4,1.45),glass)
                box('Window mullion',(x+(-.03 if x<0 else .03),y,z),(.05,.065,1.5),white)
        for x in range(-18,9,4):
            for y in [-10.0,44.4]: box('Lower floor window',(x,y,z),(2.4,.04,1.45),glass)
    box('Entry approach',(-4,-23,G+.08),(9,24,.16),paving)
    box('Entrance doors',(-4,-10.03,G+1.4),(5,.06,2.8),glass)
    box('Entrance canopy',(-4,-12,G+3),(8,4,.22),white)
    box('Running track',(29,15,G+.03),(28,43,.06),clay)
    box('Playing field',(29,15,G+.08),(23,37,.08),field)
    for x in [18,40]: box('Pitch line',(x,15,G+.14),(.12,35,.02),white)
    for y in [-2.5,15,32.5]: box('Pitch line',(29,y,G+.14),(22,.12,.02),white)
    for y in [-2,32]:
        for x in [26.5,31.5]: rod('Goal upright',(x,y,G+.15),(x,y,G+2.3),.07,white)
        rod('Goal bar',(26.5,y,G+2.3),(31.5,y,G+2.3),.07,white)
    box('Garden path',(-32,16,G+.06),(3,93,.12),paving)
    box('Garden cross path',(-32,48,G+.07),(22,3,.12),paving)
    def tree(x,y,s=1,cherry=False):
        rod('Tree trunk',(x,y,G),(x,y,G+3*s),.21*s,wood)
        for dx,dy,dz in [(0,0,4),(-1,0,3.6),(1,.4,3.8),(0,-1,3.7)]: ball('Sakura crown' if cherry else 'Tree crown',(x+dx*s,y+dy*s,G+dz*s),(1.7*s,1.5*s,1.4*s),pink if cherry else foliage)
    for y in range(-27,64,10):
        tree(-39,y,1.05,True); tree(44,y,.85,y%3==0)
    for x in [-26,-16,16,28,39]: tree(x,58,1.2,True)
    for y in [-22,4,28,52]:
        box('Garden bench',(-29,y,G+.55),(2.3,.65,.15),wood); box('Bench back',(-29,y+.3,G+1.0),(2.3,.12,.7),wood)
        for x in [-29.9,-28.1]: box('Bench leg',(x,y,G+.26),(.12,.5,.52),road)
    for i in range(65):
        x=random.uniform(-42,-34); y=random.uniform(-28,64)
        ball('Garden flower',(x,y,G+.22),(.15,.15,.18),pink if i%2 else white)
    def house(x,y,i,shop=False):
        w=8 if shop else 7; d=7; h=5.8 if shop else random.choice([5.6,6.8,8.0]); c=colors[i%len(colors)]
        box('Shop' if shop else 'Townhouse',(x,y,G+h/2),(w,d,h),c)
        verts=[(-w/2-.4,-d/2-.4,0),(w/2+.4,-d/2-.4,0),(-w/2-.4,d/2+.4,0),(w/2+.4,d/2+.4,0),(0,-d/2-.4,2),(0,d/2+.4,2)]
        mesh=bpy.data.meshes.new('Gable'); mesh.from_pydata(verts,[],[(0,4,1),(2,3,5),(0,2,5,4),(1,4,5,3),(0,1,3,2)]); mesh.update(); ob=bpy.data.objects.new('Gabled roof',mesh); bpy.context.collection.objects.link(ob); ob.location=(x,y,G+h); ob.data.materials.append(roofs[i%3])
        for z in [1.7,4.4]:
            for dx in [-2,2]:
                for dy in [-3.54,3.54]:
                    box('House window trim',(x+dx,y+dy,G+z),(1.65,.09,1.75),white); box('House window',(x+dx,y+dy+(.06 if dy>0 else -.06),G+z),(1.4,.04,1.5),glass)
        box('Front door',(x,y+3.57,G+1.15),(1.2,.1,2.3),wood)
        if shop:
            for j in range(10):
                box('Striped shop awning',(x-3.6+j*.8,y+4.2,G+3),(.8,1.8,.15),pink if j%2 else white)
            bpy.ops.object.text_add(location=(x,y+3.65,G+4.1),rotation=(math.pi/2,0,math.pi)); o=bpy.context.object; o.name='Shop sign'; o.data.body=['SAKURA CAFE','BAKERY','BOOKS','FLOWERS'][i%4]; o.data.align_x='CENTER'; o.data.size=.48; o.data.extrude=.01; o.data.materials.append(wood); bpy.ops.object.convert(target='MESH')
    if '--campus-only' not in sys.argv:
        for i,x in enumerate(range(-74,81,13)): house(x,-57,i,True); house(x,91,i+2)
        for i,y in enumerate(range(-25,77,14)): house(-68,y,i); house(72,y,i+1)
    for i in range(30):
        x=random.choice([-110,113] if '--campus-only' in sys.argv else [-88,92])+random.uniform(-4,4); y=random.uniform(-60,105); tree(x,y,random.uniform(1,1.7))
    for x in [-46,49]:
        for y in [-27,-7,13,33,53]:
            rod('Lamp pole',(x,y,G),(x,y,G+4),.07,road); ball('Lamp globe',(x,y,G+4),(.3,.3,.3),white)
    # Far skyline/mountains/clouds are now a painted 2D background, not low-poly hills.
    # Hand-styled tile textures: roof seams, paving joints, wood grain and soft plaster.
    from phase1_surface_textures import maps, noise
    from phase2_architecture import assign_uv
    yy,xx=np.mgrid[0:256,0:256]/256
    scales={}
    textured=[cream,wood,green,field,paving,road]+colors+roofs
    for index,m in enumerate(textured):
        detail=noise(256,1.4,1.4,index+40)*.013
        height=detail.copy(); repeat=3.0
        if m in roofs:
            seam=(np.mod(yy*6,1)<.045)|(np.mod(xx*4+(np.floor(yy*6)%2)*.5,1)<.025)
            detail-=seam*.085; height-=seam*.3; repeat=2.5
        elif m==paving:
            seam=(np.mod(yy*4,1)<.035)|(np.mod(xx*4+(np.floor(yy*4)%2)*.5,1)<.035)
            detail-=seam*.09; height-=seam*.25; repeat=2.4
        elif m==wood:
            detail+=np.sin(xx*90+noise(256,5,50,19))*.035; height=detail; repeat=1.8
        elif m in [green,field]:
            detail+=noise(256,12,12,11)*.025; repeat=6
        base=np.array(m.diffuse_color[:3]); color=np.clip(base[None,None,:]+detail[:,:,None],.01,1)**(1/2.2)
        paths=maps(OUT/'textures',m.name.replace(' ','_'),color,np.clip(.8+detail,0,1),height,.35)
        nodes=m.node_tree.nodes; links=m.node_tree.links; p=nodes.get('Principled BSDF')
        for channel,socket in [('BaseColor','Base Color'),('Roughness','Roughness')]:
            im=bpy.data.images.load(str(paths[channel])); im.pack()
            if channel!='BaseColor': im.colorspace_settings.name='Non-Color'
            node=nodes.new('ShaderNodeTexImage'); node.image=im; links.new(node.outputs['Color'],p.inputs[socket])
        im=bpy.data.images.load(str(paths['Normal'])); im.colorspace_settings.name='Non-Color'; im.pack(); node=nodes.new('ShaderNodeTexImage'); node.image=im
        normal=nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value=.3; links.new(node.outputs['Color'],normal.inputs['Color']); links.new(normal.outputs['Normal'],p.inputs['Normal'])
        scales[m.name]=repeat
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            o.data.update()
            while o.data.uv_layers: o.data.uv_layers.remove(o.data.uv_layers[0])
            assign_uv(o,scales)
    # Batch by material; keep logical unbatched scene editable in Blender.
    bpy.context.scene['ground_z_m']=G; bpy.context.scene['playable_floor_z_m']=0.0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'town.blend'))
    groups={}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH': groups.setdefault(o.data.materials[0].name,[]).append(o)
    for name,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.context.object.name='Town_'+name
    bpy.ops.export_scene.gltf(filepath=str(OUT/'godot_preview/town.glb'),export_format='GLB',export_apply=True,export_animations=False)
    (OUT/'static_report.json').write_text(json.dumps({'ground_z':G,'eye_height_above_ground':8.85,'material_batches':len(groups),'triangles':sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH'),'school_source_modified':False},indent=2))
if __name__=='__main__':
    if '--combine' in sys.argv:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend'))
        collection=bpy.data.collections.new('EXTERIOR | Sakura town'); bpy.context.scene.collection.children.link(collection)
        with bpy.data.libraries.load(str(OUT/'town.blend'),link=False) as (source,target): target.objects=source.objects
        for o in target.objects:
            if o: collection.objects.link(o)
        # Blender equivalent of the runtime sky: a 2D painted image on an inward dome.
        # Kept out of town.glb; Godot uses a sky shader instead of this preview geometry.
        panorama=OUT/'godot_preview/town_panorama_v1.png'
        if panorama.exists():
            verts=[]; faces=[]; nu=128; nv=64
            for j in range(nv+1):
                lat=-math.pi/2+math.pi*j/nv
                for i in range(nu+1):
                    angle=math.tau*i/nu
                    verts.append((1500*math.cos(lat)*math.sin(angle),15-1500*math.cos(lat)*math.cos(angle),1500*math.sin(lat)))
            for j in range(nv):
                for i in range(nu):
                    a=j*(nu+1)+i; faces.append((a,a+1,a+nu+2,a+nu+1))
            mesh=bpy.data.meshes.new('Painted panorama dome'); mesh.from_pydata(verts,[],faces); mesh.update()
            dome=bpy.data.objects.new('BACKGROUND 2D | painted city mountains sky',mesh); collection.objects.link(dome)
            dome.visible_shadow=False; dome.display_type='WIRE'
            uv=mesh.uv_layers.new(name='PanoramaUV')
            for poly in mesh.polygons:
                for li in poly.loop_indices:
                    vi=mesh.loops[li].vertex_index; j,i=divmod(vi,nu+1); lat=-math.pi/2+math.pi*j/nv
                    uv.data[li].uv=(1-abs(i/nu*2-1),1-max(0,min(1,.80-lat*.90)))
            m=bpy.data.materials.new('2D panorama | unlit'); m.use_nodes=True; nodes=m.node_tree.nodes; nodes.clear()
            tex=nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(panorama)); tex.image.pack(); tex.extension='EXTEND'
            emission=nodes.new('ShaderNodeEmission'); output=nodes.new('ShaderNodeOutputMaterial')
            m.node_tree.links.new(tex.outputs['Color'],emission.inputs['Color']); m.node_tree.links.new(emission.outputs[0],output.inputs['Surface']); mesh.materials.append(m)
            for screen in bpy.data.screens:
                for area in screen.areas:
                    if area.type=='VIEW_3D': area.spaces.active.clip_end=5000
            for obj in bpy.context.scene.objects:
                if obj.type=='CAMERA': obj.data.clip_end=5000
        bpy.context.scene['town_ground_z']=-7.2
        bpy.context.scene['town_preview_only']=True
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'school_with_town.blend'))
    elif '--school' in sys.argv:
        import phase2_architecture as p2
        p2.OUT=OUT; p2.export()
    else: build()
