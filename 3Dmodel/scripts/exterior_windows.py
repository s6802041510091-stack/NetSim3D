"""Exterior window addition, isolated lookdev revision before Phase 5."""
import bpy, sys, json, shutil, math
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
import phase2_architecture as p2
WORK=p2.WORK
OUT=WORK.parents[1]/'exterior_windows'
BACKUP=WORK.with_name('classroom_shell_lookdev_before_exterior_windows.blend')
def write(name,data):
    (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def plans():
    result=[]
    def add(wall,axis,const,room,centers,width=2.2,sill=1.,height=1.4):
        for center in centers:result.append(dict(wall=wall,axis=axis,const=const,room=room,center=center,width=width,sill=sill,height=height,id=f'EW_{len(result)+1:02d}'))
    east=9.03950704225352;west=-21.236830985915493
    add('Wall_Right_With_Three_Windows','Y',east,'Classroom',[7.1])
    add('Right_Outer_Extension_End','Y',east,'Staff',[12.2,16.8,21.45,25.4,28.6],2.2,2.25,.7)
    add('Left_Outer_Wall_End','Y',west,'BackgroundClass',[-7.2,-4.9,2.95,7.65])
    add('Left_Outer_Wall_End','Y',west,'Storage',[32.5,35.0],1.8,2.25,.7)
    add('Left_Outer_Wall_End','Y',west,'ITSupport',[38.95,41.1,43.25],1.8,2.25,.7)
    add('Left_Outer_Wall_End','Y',west,'Stairs',[27.3],2.2,2.45,.5)
    add('StairShell_Upper_WestWall','Y',west,'Stairs',[25.6,29.0],2.2,4.45,1.4)
    add('Left_Bottom_Wall_End','X',-9.825,'BackgroundClass',[-19.,-15.3,-11.6],2.2,2.25,.7)
    add('Wall_Rear_NegativeY','X',-9.825,'Classroom',[-.7,3.,6.7])
    add('Corridor_South_End_End','X',-9.825,'Corridor',[-7.6,-4.7],1.8)
    add('Corridor_North_End_End','X',44.25205314009662,'Corridor',[-7.6,-4.7],1.8)
    add('Left_Top_Wall_End','X',44.25205314009662,'ITSupport',[-18.2,-13.45],1.8)
    add('Left_Top_Wall_End','X',44.25205314009662,'ITSupport',[-10.95],1.8,2.45,.5)
    return result
def xyz(p,u,z,depth=0):
    return Vector((p['const']+depth,u,z) if p['axis']=='Y' else (u,p['const']+depth,z))
def box(name,p,u,z,width,height,depth,mat,coll):
    size=Vector((depth,width,height) if p['axis']=='Y' else (width,depth,height))
    me=bpy.data.meshes.new(name)
    me.from_pydata([(x*size.x/2,y*size.y/2,z*size.z/2) for x,y,z in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]],[],[tuple(reversed(f)) for f in [(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]])
    ob=bpy.data.objects.new(name,me);coll.objects.link(ob);ob.location=xyz(p,u,z)
    if mat:me.materials.append(mat)
    return ob
def hits(wall,p,u,z):
    inv=wall.matrix_world.inverted();a=inv@xyz(p,u,z,-.4);b=inv@xyz(p,u,z,.4)
    return wall.ray_cast(a,(b-a).normalized(),distance=(b-a).length)[0]
def verify_data(before,plan,new_names):
    now=p2.snapshot();changed={p['wall'] for p in plan};errors=[]
    for name,old in before.items():
        if name not in now:errors.append('missing '+name);continue
        for field in ('matrix','parent','properties','hidden','materials'):
            if old[field]!=now[name][field]:errors.append(field+' '+name)
        if name not in changed and old['geometry']!=now[name]['geometry']:errors.append('geometry '+name)
    rays=0
    for p in plan:
        assert p['room'] not in ('Server','MaleWC','FemaleWC')
        wall=bpy.data.objects[p['wall']]
        for u in (-.35,0,.35):
            for v in (.15,.5,.85):
                rays+=1
                if hits(wall,p,p['center']+u*p['width'],p['sill']+v*p['height']):errors.append('blocked '+p['id'])
        for u,z in [(p['center'],p['sill']-.12),(p['center'],p['sill']+p['height']+.12),(p['center']-p['width']/2-.05,p['sill']+.2),(p['center']+p['width']/2+.05,p['sill']+.2)]:
            if not hits(wall,p,u,z):errors.append('missing wall border '+p['id'])
    protected=0
    for room in ('FemaleWC','MaleWC','Server'):
        x0,x1,y0,y1=bpy.data.objects['Room_'+room]['bounds_m']
        p=dict(axis='Y',const=x1 if room=='Server' else x0)
        wall=bpy.data.objects['Right_Outer_Extension_End' if room=='Server' else 'Left_Outer_Wall_End']
        for i in range(1,20):
            for z in (.5,1.1,1.7,2.3,2.9):
                protected+=1
                if not hits(wall,p,y0+(y1-y0)*i/20,z):errors.append('excluded room opening '+room)
    for name in new_names:
        o=bpy.data.objects.get(name)
        if not o or not o.data.uv_layers:errors.append('missing object or UV '+name)
    files=json.loads((WORK.parents[1]/'phase0/baseline.json').read_text())['file_hashes']
    for name,digest in files.items():
        if p2.p1.sha(p2.ROOT/name)!=digest:errors.append('source modified '+name)
    report={'passed':not errors,'errors':errors,'original_objects_checked':len(before),'new_windows':len(plan),'new_objects':len(new_names),'modified_walls':sorted(changed),'opening_test_rays':rays,'excluded_room_solid_wall_tests':protected,'screens_preserved':sum('Monitor_Display_Surface' in n for n in before),'source_files_checked':len(files),'production_collision_updated':False}
    write('verification.json',report);assert not errors,errors[:20]
    print('EW_VERIFIED',json.dumps(report),flush=True)
def build():
    if BACKUP.exists():assert p2.p1.sha(WORK)==p2.p1.sha(BACKUP),'Working file changed after backup: refusing rebuild'
    bpy.ops.wm.open_mainfile(filepath=str(WORK));scene=bpy.context.scene
    assert not scene.get('exterior_window_revision')
    plan=plans();before=p2.snapshot()
    if not BACKUP.exists():shutil.copy2(WORK,BACKUP)
    write('before_snapshot.json',before)
    for i,a in enumerate(plan):
        for b in plan[i+1:]:
            if a['wall']==b['wall']:
                overlap=abs(a['center']-b['center'])<(a['width']+b['width'])/2+.04 and max(a['sill'],b['sill'])<min(a['sill']+a['height'],b['sill']+b['height'])+.04
                assert not overlap,('overlapping frames',a['id'],b['id'])
    coll=bpy.data.collections.new('20 | Exterior windows');scene.collection.children.link(coll)
    frame=bpy.data.materials['P1 | PowderCoat'];glass=bpy.data.materials['P2 | Clear glass'];new=[]
    for p in plan:
        wall=bpy.data.objects[p['wall']];wall.data=wall.data.copy()
        cutter=box(p['id']+'_cut',p,p['center'],p['sill']+p['height']/2,p['width'],p['height'],.7,wall.data.materials[0],coll)
        bpy.context.view_layer.update();bpy.context.view_layer.objects.active=wall
        mod=wall.modifiers.new(p['id']+'_opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_move_to_index(modifier=mod.name,index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
        for i,m in enumerate(wall.data.materials):
            if m is None:wall.data.materials[i]=bpy.data.materials['P1 | Paint']
        w,h,c,s=p['width'],p['height'],p['center'],p['sill']
        parts=[('JambL',c-w/2+.03,s+h/2,.06,h,.20,frame),('JambR',c+w/2-.03,s+h/2,.06,h,.20,frame),('Head',c,s+h-.03,w-.12,.06,.20,frame),('Sill',c,s+.03,w-.12,.06,.20,frame),('Mullion',c,s+h/2,.045,h-.12,.12,frame)]
        for side in (-1,1):parts.append(('GlassL' if side<0 else 'GlassR',c+side*(w/4-.015),s+h/2,w/2-.09,h-.12,.006,glass))
        for suffix,u,z,width,height,depth,mat in parts:
            o=box(p['id']+'_'+suffix,p,u,z,width,height,depth,mat,coll);o['window_id']=p['id'];o['room_id']=p['room'];new.append(o.name)
            p2.assign_uv(o,{'P1 | PowderCoat':.15,'P2 | Clear glass':1})
            if mat==frame:p2.p1.add_bevel(o,.0015,2)
            else:o.display_type='WIRE'
        print('EW_ADDED',p['id'],p['room'],flush=True)
    bpy.context.view_layer.update()
    for name in {p['wall'] for p in plan}:p2.assign_uv(bpy.data.objects[name],{'P1 | Paint':.35})
    write('changes.json',{'windows':plan,'new_objects':new,'backup':str(BACKUP)})
    verify_data(before,plan,new)
    scene['exterior_window_revision']='2026-10-16: perimeter windows; Server and both WCs excluded'
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK),compress=True)
    print('EW_SAVED',str(WORK),flush=True)
def verify():
    bpy.ops.wm.open_mainfile(filepath=str(WORK));c=json.loads((OUT/'changes.json').read_text());verify_data(json.loads((OUT/'before_snapshot.json').read_text()),c['windows'],c['new_objects'])
VIEWS={
 'east':((68,17,16),(9,17,1.8),32),
 'west':((-80,17,16),(-21,17,2.0),32),
 'south':((-6,-48,11),(-6,-9.8,1.5),38),
 'north':((-6,82,11),(-6,44.2,1.5),38),
 'staff_inside':((5.4,21,1.65),(9,24,2.0),24),
 'science_inside':((-16.5,-3,1.65),(-21,-5,1.8),28),
}
def render():
    bpy.ops.wm.open_mainfile(filepath=str(WORK));s=bpy.context.scene;c=p2.p1.configure_preview(s)
    s.render.resolution_x=1600;s.render.resolution_y=1000;s.cycles.samples=24
    d=bpy.data.lights.new('EW review sun','SUN');d.energy=2;d.angle=.15
    sun=bpy.data.objects.new('EW review sun',d);s.collection.objects.link(sun)
    for name,(pos,aim,lens) in VIEWS.items():
        c.location=pos;c.rotation_euler=(Vector(aim)-c.location).to_track_quat('-Z','Y').to_euler();c.data.lens=lens
        sun.rotation_euler=(Vector(aim)-Vector(pos)-Vector((0,0,12))).to_track_quat('-Z','Y').to_euler()
        s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True);print('EW_RENDER',name,flush=True)
def bounds(o):
    pts=[o.matrix_world@Vector(v) for v in o.bound_box]
    return [[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]]
def audit():
    bpy.ops.wm.open_mainfile(filepath=str(WORK))
    data={'rooms':{},'objects':{}}
    for o in bpy.context.scene.objects:
        if o.name.startswith('Room_'):data['rooms'][o.name]={k:list(o[k]) if k=='bounds_m' else o[k] for k in o.keys() if k in ('room_id','label_th','bounds_m')}
        if o.type=='MESH' and not o.hide_render:
            data['objects'][o.name]={'bounds':bounds(o),'materials':[m.name if m else None for m in o.data.materials],'collections':[c.name for c in o.users_collection]}
    (OUT/'audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print('ROOMS',json.dumps(data['rooms'],ensure_ascii=False),flush=True)
    for name,record in data['objects'].items():
        if any(k in name for k in ('Outer','Bottom_Wall','Top_Wall','Wall_Right','Wall_Back','Wall_Front','Window_','Corridor_North_End_End','Corridor_South_End_End')) and 'Skirting' not in name:print(name,record['bounds'],flush=True)
if __name__=='__main__':
    mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'audit'
    {'audit':audit,'build':build,'verify':verify,'render':render}[mode]()
