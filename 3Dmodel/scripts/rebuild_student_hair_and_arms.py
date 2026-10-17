"""Fit CC0 MakeHuman short/tied hairstyles to each student's actual head.
Recover female arm anatomy from source UV correspondence; preserve slim legs.
Existing filenames are retained so references remain valid.
"""
import bpy,bmesh,math,json,shutil,sys
from pathlib import Path
from mathutils import Vector,Matrix

ROOT=Path('D:/NetSim3D/3Dmodel');FOLDER=ROOT/'ใช้ร่วมกัน/blend/students'
BACKUP=FOLDER/'backup_before_simple_hair_v2';BACKUP.mkdir(exist_ok=True)
RENDER=ROOT/'ใช้ร่วมกัน/renders/students';ASSETS=ROOT/'temp/teacher_male/system_assets'
SOURCE=ROOT/'temp/teacher_male/source';FEMALE=ROOT/'temp/teacher_female/source'

def read_obj(path):
    vs=[];uv=[];fs=[];groups=[];group=''
    for line in path.read_text(encoding='utf-8').splitlines():
        t=line.split()
        if not t:continue
        if t[0]=='v':vs.append(Vector(tuple(map(float,t[1:4]))))
        elif t[0]=='vt':uv.append(tuple(map(float,t[1:3])))
        elif t[0]=='g':group=t[1]
        elif t[0]=='f':
            fs.append([(int(a.split('/')[0])-1,int(a.split('/')[1])-1) for a in t[1:]]);groups.append(group)
    return vs,uv,fs,groups

def anatomy(sex):
    vs,uv,fs,groups=read_obj(SOURCE/'base.obj')
    targets=[(FEMALE/'asian-female-young.target',.90),(FEMALE/'caucasian-female-young.target',.10),(FEMALE/'universal-female-young-averagemuscle-averageweight.target',1)] if sex=='female' else [(SOURCE/'asian-male-young.target',.85),(SOURCE/'caucasian-male-young.target',.15),(SOURCE/'universal-male-young-maxmuscle-averageweight.target',.15)]
    for path,k in targets:
        for line in path.read_text().splitlines():
            t=line.split()
            if t and t[0].isdigit():vs[int(t[0])]+=Vector(tuple(float(x)*k for x in t[1:4]))
    floor=min(vs[i].y for f,g in zip(fs,groups) if g=='body' for i,_ in f)
    co=lambda p:Vector((p.x*.105,-p.z*.105,(p.y-floor)*.105+.026))
    return vs,uv,fs,groups,co

def bind_head(ob,rig):
    ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
    vg=ob.vertex_groups.new(name='head');vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Head deformation','ARMATURE');mod.object=rig

def fit_hair(stem,label,sex,rig,asset):
    vs,_,_,_,co=anatomy(sex);folder=ASSETS/'hair'/stem
    points,uv,faces,_=read_obj(folder/(stem+'.obj'))
    fitted=[];scales={};active=False
    for line in (folder/(stem+'.mhclo')).read_text().splitlines():
        t=line.split()
        if not t or t[0].startswith('#'):continue
        if t[0].endswith('_scale'):
            axis={'x':0,'y':1,'z':2}[t[0][0]];scales[axis]=abs(vs[int(t[1])][axis]-vs[int(t[2])][axis])/float(t[3])
        elif t[0]=='verts':active=True
        elif active and t[0].lstrip('-').isdigit() and len(fitted)<len(points):
            if len(t)==1:p=vs[int(t[0])].copy()
            elif len(t)>=9:
                p=sum((vs[int(t[j])]*float(t[j+3]) for j in range(3)),Vector())
                p+=Vector(tuple(float(t[j+6])*scales.get(j,1) for j in range(3)))
            else:continue
            fitted.append(co(p))
    assert len(fitted)==len(points)
    me=bpy.data.meshes.new(label);me.from_pydata(fitted,[],[[i for i,_ in f] for f in faces]);me.update()
    ob=bpy.data.objects.new('Hair | '+label,me);asset.objects.link(ob)
    layer=me.uv_layers.new(name='Hair UV')
    for poly,f in zip(me.polygons,faces):
        poly.use_smooth=True
        for li,(_,ui) in zip(poly.loop_indices,f):layer.data[li].uv=uv[ui]
    mat=bpy.data.materials.new('Hair | '+label+' textured');mat.use_nodes=True;mat.diffuse_color=(.026,.018,.012,1)
    p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.61;p.inputs['Specular IOR Level'].default_value=.22
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(folder/(stem+'_diffuse.png')),check_existing=True)
    mult=mat.node_tree.nodes.new('ShaderNodeMixRGB');mult.blend_type='MULTIPLY';mult.inputs[0].default_value=.55;mult.inputs[2].default_value=(.28,.22,.18,1)
    mat.node_tree.links.new(tex.outputs['Color'],mult.inputs[1]);mat.node_tree.links.new(mult.outputs[0],p.inputs['Base Color']);mat.node_tree.links.new(tex.outputs['Alpha'],p.inputs['Alpha'])
    me.materials.append(mat);bind_head(ob,rig)
    sub=ob.modifiers.new('Smooth fitted hair','SUBSURF');sub.levels=1;sub.render_levels=1
    return ob

def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)

def recover_arms(body,rig):
    vs,uv,fs,groups,co=anatomy('female')
    by_uv={}
    for f,g in zip(fs,groups):
        if g=='body':
            for i,ui in f:by_uv[tuple(round(x,6) for x in uv[ui])]=i
    original={}
    for loop in body.data.loops:
        key=tuple(round(x,6) for x in body.data.uv_layers.active.data[loop.index].uv)
        if key in by_uv:original[loop.vertex_index]=co(vs[by_uv[key]])
    arm_names=set()
    for side in ('L','R'):
        root=rig.data.bones['upperarm01.'+side];arm_names.add(root.name);arm_names.update(b.name for b in root.children_recursive)
    count=0
    matrices={b.name:b.matrix@b.bone.matrix_local.inverted() for b in rig.pose.bones}
    for v in body.data.vertices:
        aw=sum(g.weight for g in v.groups if body.vertex_groups[g.group].name in arm_names)
        if aw>.5 and v.index in original:
            # Keep the shoulder fit under the sleeve, restore the source elbow,
            # wrist, hand and forearm as one continuous anatomical surface.
            p=original[v.index]
            posed=Vector();total=0
            for g in v.groups:
                name=body.vertex_groups[g.group].name
                if name in matrices:posed+=(matrices[name]@v.co)*g.weight;total+=g.weight
            z=(rig.matrix_world@(posed/max(total,.000001))).z
            fade=1-smooth((z-1.085)/.075)
            if fade>0:v.co=v.co.lerp(p,fade);count+=1
    body.data.update();bpy.context.view_layer.update()
    return count

def turn_tail_to_bun(hair,rig,asset,body):
    # Locate skull and tie in local mesh coordinates (same bind space).
    top=max(v.co.z for v in body.data.vertices)
    scalp=[v.co for v in body.data.vertices if v.co.z>top-.17]
    back=max(p.y for p in scalp);cz=top-.12
    # Fold only the hanging ponytail upward; fitted scalp remains untouched.
    for v in hair.data.vertices:
        p=v.co
        if p.y>back-.016 and p.z<cz:
            t=min(1,max(0,(cz-p.z)/.22));p.z=cz-.008-.018*t;p.y=back+.012+.017*t
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24)
    bun=bpy.context.object;bun.name='Hair | compact tied bun'
    for c in list(bun.users_collection):c.objects.unlink(bun)
    asset.objects.link(bun)
    for v in bun.data.vertices:
        p=v.co.copy();angle=math.atan2(p.z,p.x)
        ripple=1+.018*math.cos(angle*22+3*p.y)
        v.co=(p.x*.048*ripple,back+.035+p.y*.043,cz+.012+p.z*.048*ripple)
    for p in bun.data.polygons:p.use_smooth=True
    m=hair.data.materials[0].copy();m.name='Hair | bun matching strands'
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.68
    for link in list(p.inputs['Alpha'].links):m.node_tree.links.remove(link)
    p.inputs['Alpha'].default_value=1
    for loop in bun.data.uv_layers.active.data:
        u,v=loop.uv;loop.uv=(.475+.025*u,.13+.30*v)
    wave=m.node_tree.nodes.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='DIAGONAL'
    wave.inputs['Scale'].default_value=25;wave.inputs['Distortion'].default_value=2.5;wave.inputs['Detail'].default_value=2
    bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.32;bump.inputs['Distance'].default_value=.0012
    m.node_tree.links.new(wave.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
    bun.data.materials.append(m);bind_head(bun,rig)

def bounds(asset):
    dg=bpy.context.evaluated_depsgraph_get();pts=[]
    for ob in asset.all_objects:
        if ob.type!='MESH':continue
        ev=ob.evaluated_get(dg);me=ev.to_mesh();pts.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
    return min(p.z for p in pts),max(p.z for p in pts)

SPECS=[('male_mullet','male','short01','Short crop',1.65),('male_two_block','male','short04','Side part',1.65),('female_bob_cut','female','short02','Short pixie',1.60),('female_wendy_cut','female','ponytail01','Ponytail',1.60),('female_layer_cut','female','ponytail01','Tied bun',1.60)]
def build(stem,sex,proxy,label,height):
    path=FOLDER/('student_'+stem+'.blend');backup=BACKUP/path.name
    if not backup.exists():shutil.copy2(path,backup)
    bpy.ops.wm.open_mainfile(filepath=str(backup));bpy.context.preferences.filepaths.save_version=0
    asset=next(c for c in bpy.data.collections if c.name.startswith('STUDENT |'));rig=next(o for o in asset.all_objects if o.type=='ARMATURE')
    body=next(o for o in asset.all_objects if o.name.startswith('Body |'))
    for ob in list(asset.all_objects):
        if ob.name.startswith('Hair |'):bpy.data.objects.remove(ob,do_unlink=True)
    hair=fit_hair(proxy,label,sex,rig,asset)
    if label=='Tied bun':turn_tail_to_bun(hair,rig,asset,body)
    changed=recover_arms(body,rig) if sex=='female' else 0
    bpy.context.view_layer.update();lo,hi=bounds(asset)
    factor=height/(hi-lo);rig.scale*=factor;rig.location*=factor;bpy.context.view_layer.update()
    lo,hi=bounds(asset);rig.location.z-=lo;bpy.context.view_layer.update()
    rig['hairstyle']=label;rig['hair_revision']='Fitted CC0 textured hair, 2026-10-14';rig['height_m']=height
    if sex=='female':rig['arm_revision']='Source female anatomy restored by UV correspondence, keeping slim leg revision.'
    asset.name='STUDENT | '+sex+' | '+label
    for im in bpy.data.images:
        if im.source=='FILE' and im.users and not im.packed_file:im.pack()
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_percentage=100;cam=scene.camera;cam.data.type='ORTHO'
    def view(pos,target,scale,suffix,w=650,h=650):
        cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.filepath=str(RENDER/('student_'+stem+suffix+'.png'))
        bpy.ops.render.render(write_still=True)
    view((1,-4,height+.03),(0,0,height-.15),.52,'_hair')
    view((4,1,height-.05),(0,0,height-.16),.53,'_side')
    if sex=='female':view((4,-.2,1.03),(.23,-.025,1.00),.55,'_arm_detail',600,900)
    view((2,-6,1.5),(0,0,height*.51),height*1.16,'',600,850)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print('HAIR_AND_ARM_REVISION '+json.dumps({'file':str(path),'hair':label,'recovered_arm_vertices':changed,'height_m':bounds(asset)[1],'backup':str(backup)}),flush=True)

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if (FOLDER/'students_lineup.blend').exists() and not (BACKUP/'students_lineup.blend').exists():shutil.copy2(FOLDER/'students_lineup.blend',BACKUP/'students_lineup.blend')
    for spec in SPECS:
        if not wanted or spec[0] in wanted:build(*spec)
