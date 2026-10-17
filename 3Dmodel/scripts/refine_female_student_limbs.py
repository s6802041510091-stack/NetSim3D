"""Reversible female-only limb refit in posed space; retain UVs, rig and outfit."""
import bpy, math, json, shutil
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path('D:/NetSim3D/3Dmodel');FOLDER=ROOT/'ใช้ร่วมกัน/blend/students'
BACKUP=FOLDER/'backup_before_limb_refit';BACKUP.mkdir(exist_ok=True)
RENDER=ROOT/'ใช้ร่วมกัน/renders/students'
REPORT=[]

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

def mix(a,b,t):return a+(b-a)*t

def interp(samples,z):
    if z<=samples[0][0]:return samples[0][1:]
    for i in range(1,len(samples)):
        a,b=samples[i-1],samples[i]
        if z<=b[0]:
            t=(z-a[0])/(b[0]-a[0]);return [mix(x,y,t) for x,y in zip(a[1:],b[1:])]
    return samples[-1][1:]

def process(style):
    path=FOLDER/('student_female_'+style+'.blend');backup=BACKUP/path.name
    if not backup.exists():shutil.copy2(path,backup)
    bpy.ops.wm.open_mainfile(filepath=str(backup))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    body=bpy.data.objects['Body | female head arms lower legs']
    matrix={b.name:b.matrix@b.bone.matrix_local.inverted() for b in rig.pose.bones}
    convert=rig.matrix_world.inverted()@body.matrix_world
    positions=[];maps=[];arm_ids={};leg_ids={}
    for side in ('L','R'):
        arm_ids[side]={body.vertex_groups[n].index for n in matrix if n.endswith('.'+side) and ('upperarm' in n or 'lowerarm' in n or 'wrist' in n) and n in body.vertex_groups}
        leg_ids[side]={body.vertex_groups[n].index for n in matrix if n.endswith('.'+side) and ('leg' in n or 'foot' in n) and n in body.vertex_groups}
    for v in body.data.vertices:
        mat=Matrix(((0.,)*4,)*4);total=0
        for g in v.groups:
            name=body.vertex_groups[g.group].name
            if name in matrix:mat+=matrix[name]*g.weight;total+=g.weight
        mat=mat*(1/total) if total else Matrix.Identity(4)
        world=rig.matrix_world@mat@convert
        maps.append(world);positions.append(world@v.co)
    changed={'arms':0,'legs':0};maxmove=0
    for sign,side in [(1,'L'),(-1,'R')]:
        def weight(v,groups):return sum(g.weight for g in v.groups if g.group in groups)
        armpts=[p for v,p in zip(body.data.vertices,positions) if weight(v,arm_ids[side])>.60 and .81<p.z<1.24]
        sections=[]
        for j in range(42):
            z=.82+j*.01;sl=[p for p in armpts if abs(p.z-z)<.017]
            if len(sl)<4:continue
            xmin,xmax=min(p.x for p in sl),max(p.x for p in sl)
            ymin,ymax=min(p.y for p in sl),max(p.y for p in sl)
            sections.append([z,(xmin+xmax)/2,(ymin+ymax)/2,(xmax-xmin)/2,(ymax-ymin)/2])
        # Average adjacent sections; use a continuous centerline, no sharp elbow kink.
        smoothed=[]
        for i,s in enumerate(sections):
            near=sections[max(0,i-2):min(len(sections),i+3)]
            smoothed.append([s[0]]+[sum(p[k] for p in near)/len(near) for k in range(1,5)])
        wrist=rig.matrix_world@rig.pose.bones['wrist.'+side].head
        elbow=rig.matrix_world@rig.pose.bones['lowerarm01.'+side].head
        shoulder=rig.matrix_world@rig.pose.bones['upperarm01.'+side].head
        # Natural relaxed centerline through existing rig pivots, gently rounded at elbow.
        guide=sorted([(wrist.z,wrist.x,wrist.y-.010),(elbow.z,elbow.x,elbow.y-.004),(shoulder.z,shoulder.x,shoulder.y)])
        legpts=[p for v,p in zip(body.data.vertices,positions) if weight(v,leg_ids[side])>.6 and p.z<.62]
        legs=[]
        for j in range(51):
            z=.11+j*.01;sl=[p for p in legpts if abs(p.z-z)<.018]
            if len(sl)>=4:legs.append([z,(min(p.x for p in sl)+max(p.x for p in sl))/2,(min(p.y for p in sl)+max(p.y for p in sl))/2])
        for v,p in zip(body.data.vertices,positions):
            q=p.copy()
            if weight(v,leg_ids[side])>.6 and .13<p.z<.62:
                cx,cy=interp(legs,p.z)
                fade=smooth(.13,.23,p.z)
                q.x=cx+(p.x-cx)*(1-.26*fade)
                q.y=cy+(p.y-cy)*(1-.20*fade)
                changed['legs']+=1
            elif weight(v,arm_ids[side])>.60 and .825<p.z<1.23:
                cx,cy,rx,ry=interp(smoothed,p.z)
                tx,ty=interp(guide,p.z)
                strength=smooth(.825,.88,p.z)*(1-smooth(1.16,1.23,p.z))
                tx=mix(wrist.x,shoulder.x,(p.z-wrist.z)/(shoulder.z-wrist.z))
                radius=interp([(.825,.018),(.90,.022),(.96,.025),(1.035,.025),(1.10,.028),(1.20,.032)],p.z)[0]
                # Modest taper, with a smooth forearm rather than an abrupt bulge.
                q.x=mix(p.x,tx+(p.x-cx)*min(1.2,radius/max(rx,.015)),strength)
                q.y=mix(p.y,ty+(p.y-cy)*.90,strength)
                changed['arms']+=1
            if (q-p).length>1e-9:
                maxmove=max(maxmove,(q-p).length);v.co=maps[v.index].inverted()@q
    body.data.update();bpy.context.view_layer.update()
    rig['limb_revision']='2026-10-14: female calf width -26%, depth -20%, tapered ankles; relaxed arm contour aligned to existing rig.'
    rig['limb_backup']=str(backup)
    scene=bpy.context.scene;cam=scene.camera
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=650;scene.render.resolution_y=950;scene.render.resolution_percentage=100
    cam.data.type='ORTHO';cam.data.ortho_scale=1.84
    for name,pos in [('front_corrected',(0,-6,.92)),('side_corrected',(6,0,.92)),('preview',(2,-6,1.5))]:
        cam.location=pos;cam.rotation_euler=(Vector((0,0,.81))-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(RENDER/('student_female_'+style+('_'+name if name!='preview' else '')+'.png'))
        bpy.ops.render.render(write_still=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    REPORT.append({'file':str(path),'changed_vertices':changed,'max_displacement_m':maxmove,'backup':str(backup)})
    print('LIMB_REFIT '+json.dumps(REPORT[-1]),flush=True)

for name in ['bob_cut','wendy_cut','layer_cut']:process(name)
(FOLDER/'limb_refit_validation.json').write_text(json.dumps(REPORT,indent=2),encoding='utf-8')
