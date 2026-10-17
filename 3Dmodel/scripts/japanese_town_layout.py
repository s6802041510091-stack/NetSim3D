"""Inspect and arrange the user-supplied CC-BY Japanese street, non-destructively."""
import bpy, json, math, sys, tempfile
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'Preview/โรงเรียนและเมือง/town'
SOURCE=ROOT/'3Dmodel/ใช้ร่วมกัน/external/japanese_town/stylized_little_japanese_town_street.glb'
def bounds(o):
    p=[o.matrix_world@Vector(v) for v in o.bound_box]
    return [[min(v[a] for v in p) for a in range(3)],[max(v[a] for v in p) for a in range(3)]]
def inspect():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    bpy.context.view_layer.update()
    report=[]
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            o.data.calc_loop_triangles()
            report.append({'name':o.name,'parent':o.parent.name if o.parent else '', 'bounds':bounds(o),'triangles':len(o.data.loop_triangles),'materials':[m.name for m in o.data.materials]})
    (OUT/'japanese_source_audit.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2),flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'japanese_source_inspected.blend'))
def build():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'japanese_source_inspected.blend'))
    scratch=OUT/'export_temp'; scratch.mkdir(exist_ok=True); tempfile.tempdir=str(scratch)
    groups={}
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH' and o.parent and o.parent.name not in ['DomekRdy_Podklad','DomekRdy_Ziemia']:
            groups.setdefault(o.parent.name,[]).append(o)
    prototypes=[]; records=[]
    for key,objects in groups.items():
        bb=[bounds(o) for o in objects]
        low=Vector([min(b[0][a] for b in bb) for a in range(3)])
        high=Vector([max(b[1][a] for b in bb) for a in range(3)])
        center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
        rotation=Matrix.Rotation(math.pi/2 if center.x>0 else -math.pi/2,4,'Z')
        for o in objects:
            world=o.matrix_world.copy(); o.data=o.data.copy()
            for v in o.data.vertices: v.co=rotation@((world@v.co-center)*.018)
            o.parent=None; o.matrix_world=Matrix.Identity(4)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        o=bpy.context.view_layer.objects.active; o.name='JP_'+key
        prototypes.append(o)
        o.data.calc_loop_triangles(); bpy.context.view_layer.update()
        records.append({'name':o.name,'bounds':bounds(o),'triangles':len(o.data.loop_triangles)})
    for o in list(bpy.context.scene.objects):
        if o not in prototypes: bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'godot_preview/japanese_buildings.glb'),export_format='GLB',use_selection=True,export_animations=False)
    for im in bpy.data.images:
        if im.has_data: im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'japanese_buildings.blend'))
    slots=[]
    # First row faces the school ring road; outer row adds depth within ~200 m square.
    for x in range(-65,69,11):
        slots.append((x,-55,math.pi)); slots.append((x,91,0))
    for y in range(-29,77,11):
        slots.append((-65,y,-math.pi/2)); slots.append((70,y,math.pi/2))
    for x in [-79,-50,-21,8,37,66,89]:
        slots.append((x,-76,math.pi)); slots.append((x,109,0))
    for y in [-43,-15,13,41,69,97]:
        slots.append((-91,y,-math.pi/2)); slots.append((94,y,math.pi/2))
    placements=[]
    for i,(x,y,rotation) in enumerate(slots):
        prototype=prototypes[(i*3+i//7)%len(prototypes)]
        placements.append({'prototype':prototype.name,'position':[x,y,-7.2],'rotation':rotation})
    report={'scale_from_source':.018,'source_license':'CC-BY-4.0','prototype_count':len(prototypes),'instance_count':len(placements),'prototypes':records,'placements':placements,'production_integration':False}
    (OUT/'godot_preview/japanese_layout.json').write_text(json.dumps(report,indent=2))
    print('JAPANESE_LAYOUT',len(prototypes),len(placements),flush=True)
def combine():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'school_with_town.blend'))
    with bpy.data.libraries.load(str(OUT/'japanese_buildings.blend'),link=False) as (source,target): target.objects=source.objects
    prototypes={o.name:o for o in target.objects}
    collection=bpy.data.collections.new('CITY | Michal Solarek CC-BY-4.0'); bpy.context.scene.collection.children.link(collection)
    report=json.loads((OUT/'godot_preview/japanese_layout.json').read_text())
    allbounds=[]
    for i,p in enumerate(report['placements']):
        o=prototypes[p['prototype']].copy(); o.data=prototypes[p['prototype']].data
        o.name=f'Japanese block {i+1:02d} | '+p['prototype']; collection.objects.link(o)
        o.location=p['position']; o.rotation_euler.z=p['rotation']
    bpy.context.view_layer.update()
    errors=[]
    for o in collection.objects:
        b=bounds(o); allbounds.append(b)
        if b[0][0]<48 and b[1][0]>-45 and b[0][1]<69 and b[1][1]>-35: errors.append('Campus overlap '+o.name)
        if abs(b[0][2]+7.2)>.001:errors.append('Ground alignment '+o.name)
    report['layout_bounds']=[[min(b[0][a] for b in allbounds) for a in range(3)],[max(b[1][a] for b in allbounds) for a in range(3)]]
    report['errors']=errors; report['passed']=not errors
    (OUT/'japanese_layout_verification.json').write_text(json.dumps(report,indent=2))
    assert not errors,errors
    bpy.context.scene['japanese_street_attribution']='Stylized Little Japanese Town Street by Michal Solarek, CC BY 4.0; isolated buildings, rescaled, repeated. See ATTRIBUTION.md.'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'school_with_japanese_town.blend'))
if __name__=='__main__':
    if '--build' in sys.argv:build()
    elif '--combine' in sys.argv:combine()
    else:inspect()
