"""NetSim3D male teacher. MakeHuman CC0 anatomy, original tailored uniform.
Coordinates are authored in MakeHuman decimetres, converted to Blender metres.
Only builds this new asset; does not open or modify any classroom file.
"""
import bpy, bmesh, math, json, random, sys
from pathlib import Path
from collections import defaultdict
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

BASE=Path('D:/NetSim3D/3Dmodel')
SRC=BASE/'temp/teacher_male/source'
SYS=BASE/'temp/teacher_male/system_assets'
OUT=BASE/'ใช้ร่วมกัน/blend/teacher_male_khaki_180cm.blend'
RENDER=BASE/'ใช้ร่วมกัน/renders'
random.seed(14)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name!='Collection':bpy.data.collections.remove(c)
scene=bpy.context.scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
bpy.context.preferences.filepaths.save_version=0
asset=bpy.data.collections.new('TEACHER | male · 180 cm')
studio=bpy.data.collections.new('STUDIO | excluded from game export')
scene.collection.children.link(asset);scene.collection.children.link(studio)

def read_obj(path):
    vs=[];uv=[];fs=[];groups=[];group=''
    for ln in path.read_text().splitlines():
        t=ln.split()
        if not t:continue
        if t[0]=='v':vs.append(Vector(tuple(map(float,t[1:4]))))
        elif t[0]=='vt':uv.append(tuple(map(float,t[1:3])))
        elif t[0]=='g':group=t[1]
        elif t[0]=='f':
            fs.append([(int(a.split('/')[0])-1,int(a.split('/')[1])-1 if '/' in a and a.split('/')[1] else 0) for a in t[1:]])
            groups.append(group)
    return vs,uv,fs,groups
verts,uvs,faces,groups=read_obj(SRC/'base.obj')
for fn,fac in [('asian-male-young.target',.85),('caucasian-male-young.target',.15),('universal-male-young-maxmuscle-averageweight.target',.15)]:
    for ln in (SRC/fn).read_text().splitlines():
        t=ln.split()
        if t and not t[0].startswith('#'):
            verts[int(t[0])]+=Vector(tuple(float(a)*fac for a in t[1:4]))
floor=min(verts[a[0]].y for f,g in zip(faces,groups) if g=='body' for a in f)
S=.105
def co(p):return Vector((p[0]*S,-p[2]*S,(p[1]-floor)*S+.026))
def bodyco(p):return co(p)
def link(obj,col=asset):
    for old in list(obj.users_collection):old.objects.unlink(obj)
    col.objects.link(obj);return obj
def mat(name,col,rough=.5,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    b=m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value=(*col,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal
    return m
def grain(m,scale,strength,distance):
    n=m.node_tree.nodes;l=m.node_tree.links;b=n.get('Principled BSDF')
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=2
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=strength;bump.inputs['Distance'].default_value=distance
    l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],b.inputs['Normal'])
skin=mat('Skin | warm natural complexion',(.34,.17,.085),.52)
skin.node_tree.nodes.get('Principled BSDF').inputs['Subsurface Weight'].default_value=.07
grain(skin,280,.13,.00014)
shirtmat=mat('Uniform | khaki cotton twill',(.29,.205,.093),.74);grain(shirtmat,900,.14,.00009)
pantsmat=mat('Uniform | khaki tailored trousers',(.25,.176,.078),.68);grain(pantsmat,1000,.11,.00008)
thread=mat('Stitching | tonal khaki',(.32,.227,.105),.8)
gold=mat('Hardware | satin brass',(.62,.39,.12),.3,.72)
goldedge=mat('Insignia | woven gold',(.54,.32,.074),.5,.25)
black=mat('Name badge | black enamel',(.009,.012,.014),.3)
leather=mat('Shoes | polished black leather',(.013,.017,.021),.26);grain(leather,360,.1,.00012)
solemat=mat('Shoes | stacked rubber sole',(.009,.012,.015),.7)
hairmat=mat('Hair | dark swept crop',(.009,.006,.004),.62)
hairhi=mat('Hair | fine strands',(.020,.012,.007),.54)
for hm in [hairmat,hairhi]:hm.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.22
browmat=mat('Brows | dark brown',(.02,.009,.004),.7)
nailmat=mat('Nails | natural',(.5,.29,.185),.38)
lipmat=mat('Lips | muted warm rose',(.33,.105,.082),.48)

def mesh(name,vs,fs,material,sub=0,col=asset):
    me=bpy.data.meshes.new(name+'Mesh');me.from_pydata(vs,[],fs);me.update()
    ob=bpy.data.objects.new(name,me);col.objects.link(ob)
    if material:me.materials.append(material)
    for p in me.polygons:p.use_smooth=True
    if sub:
        m=ob.modifiers.new('Smooth anatomical surface','SUBSURF');m.levels=sub;m.render_levels=sub
    return ob
def objpart(name,which,material,transform=None,sub=0):
    ff=[f for f,g in zip(faces,groups) if g==which]
    ids=sorted(set(a[0] for f in ff for a in f));mapping={a:i for i,a in enumerate(ids)}
    vv=[transform(verts[a].copy()) if transform else co(verts[a]) for a in ids]
    ob=mesh(name,vv,[[mapping[a[0]] for a in f] for f in ff],material,sub)
    uv=ob.data.uv_layers.new(name='MakeHuman_UV')
    for p,f in zip(ob.data.polygons,ff):
        for li,a in zip(p.loop_indices,f):uv.data[li].uv=uvs[a[1]]
    return ob,ids
def garment_mesh(folder,stem,material):
    vv,uv,ff,gg=read_obj(folder/(stem+'.obj'));fitted=[];scales={};active=False
    for ln in (folder/(stem+'.mhclo')).read_text().splitlines():
        t=ln.split()
        if not t or t[0].startswith('#'):continue
        if t[0].endswith('_scale'):
            k={'x':0,'y':1,'z':2}[t[0][0]];scales[k]=abs(verts[int(t[1])][k]-verts[int(t[2])][k])/float(t[3])
        elif t[0]=='verts':active=True
        elif active and t[0].lstrip('-').isdigit() and len(fitted)<len(vv):
            if len(t)==1:fitted.append(verts[int(t[0])].copy())
            elif len(t)>=9:
                p=sum((verts[int(t[j])]*float(t[j+3]) for j in range(3)),Vector())
                p+=Vector(tuple(float(t[j+6])*scales.get(j,1) for j in range(3)));fitted.append(p)
    assert len(fitted)==len(vv)
    ob=mesh(stem,[co(p) for p in fitted],[[a[0] for a in f] for f in ff],material)
    layer=ob.data.uv_layers.new(name='Garment_UV')
    for p,f in zip(ob.data.polygons,ff):
        for li,a in zip(p.loop_indices,f):layer.data[li].uv=uv[a[1]]
    return ob
body,bodyids=objpart('Body | head neck arms hands', 'body',skin,sub=1)
basepos={i:co(v) for i,v in enumerate(verts)}

# Preserve the CC0 anatomical skin weights. Clothes use nearest-body interpolation.
rigdata=json.loads((SRC/'default.mhskel').read_text())
weightdata=json.loads((SRC/'default_weights.mhw').read_text())['weights']
weights=defaultdict(dict)
for bone,items in weightdata.items():
    for i,w in items:weights[i][bone]=w
arm=bpy.data.armatures.new('Teacher_Humanoid_Skeleton')
rig=bpy.data.objects.new('Teacher_Male_Rig',arm);asset.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
joint=lambda name:sum((verts[i] for i in rigdata['joints'][name]),Vector())/len(rigdata['joints'][name])
for name,entry in rigdata['bones'].items():
    b=arm.edit_bones.new(name);b.head=co(joint(entry['head']));b.tail=co(joint(entry['tail']))
    if (b.tail-b.head).length<.00001:b.tail.z+=.003
for name,entry in rigdata['bones'].items():
    if entry['parent']:arm.edit_bones[name].parent=arm.edit_bones[entry['parent']]
bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
rig.show_in_front=True;arm.display_type='OCTAHEDRAL'
tree=KDTree(len(bodyids))
for i in bodyids:tree.insert(basepos[i],i)
tree.balance()
def bind(ob,ids=None,bone=None):
    if ob.type!='MESH':return
    bins=defaultdict(list)
    for v in ob.data.vertices:
        if bone:ww={bone:1.}
        elif ids is not None:ww=weights.get(ids[v.index],{})
        else:
            near=tree.find_n(ob.matrix_world@v.co,3);ww=defaultdict(float)
            total=sum(1/max(d,.0002)**3 for _,_,d in near)
            for _,idx,d in near:
                influence=1/max(d,.0002)**3/total
                for bn,w in weights.get(idx,{}).items():ww[bn]+=w*influence
        total=sum(ww.values())
        for bn,w in ww.items():
            if w>.0001:bins[bn].append((v.index,w/total))
    for bn,items in bins.items():
        vg=ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)
        for i,w in items:vg.add([i],w,'REPLACE')
    mod=ob.modifiers.new('Humanoid deformation','ARMATURE');mod.object=rig
    # Deform before subdivision so clothing and body share the same rest pose.
    bpy.context.view_layer.objects.active=ob
    while ob.modifiers.find(mod.name)>0:bpy.ops.object.modifier_move_up(modifier=mod.name)
    ob.parent=rig
bind(body,bodyids)

# Anatomical skin colour masks (lips, nail plates), retain editable vertex colours.
colattr=body.data.color_attributes.new(name='SkinTint',type='FLOAT_COLOR',domain='POINT')
for idx,bid in enumerate(bodyids):
    p=verts[bid];c=Vector((.34,.17,.085))
    # Soft cheek variation rather than flat plastic skin.
    cheek=math.exp(-((abs(p.x)-.48)/.25)**2-((p.y-6.75)/.32)**2)*max(0,min(1,(p.z-.7)/.6))
    c=c.lerp(Vector((.37,.143,.079)),cheek*.35)
    lip=math.exp(-((p.y-6.43)/.125)**4-(abs(p.x)/.265)**6)*max(0,min(1,(p.z-1.33)/.09))
    c=c.lerp(Vector((.255,.072,.059)),lip*.70)
    stubble=math.exp(-((p.y-6.18)/.42)**4-(abs(p.x)/.52)**6)*max(0,min(1,(p.z-1.10)/.24))*(1-lip)
    c=c.lerp(Vector((.22,.118,.065)),stubble*.12)
    colattr.data[idx].color=(*c,1)
n=skin.node_tree.nodes;attr=n.new('ShaderNodeVertexColor');attr.layer_name='SkinTint'
skin.node_tree.links.new(attr.outputs['Color'],n.get('Principled BSDF').inputs['Base Color'])

def cut(ob,point,normal,clear_outer=True,region=None):
    bm=bmesh.new();bm.from_mesh(ob.data)
    if region:
        ff=[f for f in bm.faces if all(region(v.co) for v in f.verts)]
        ee=set(e for f in ff for e in f.edges);vv=set(v for f in ff for v in f.verts)
        geom=list(vv)+list(ee)+ff
    else:geom=list(bm.verts)+list(bm.edges)+list(bm.faces)
    bmesh.ops.bisect_plane(bm,geom=geom,dist=.000001,plane_co=co(point),plane_no=Vector((normal[0],-normal[2],normal[1])),clear_outer=clear_outer,clear_inner=not clear_outer)
    bm.to_mesh(ob.data);bm.free();ob.data.update()
def solid(ob,thickness=.0015):
    m=ob.modifiers.new('True fabric thickness','SOLIDIFY');m.thickness=thickness;m.offset=0
def smooth(ob,levels=2):
    m=ob.modifiers.new('Tailoring smoothness','SUBSURF');m.levels=levels;m.render_levels=levels
def clothshape(p):
    x,y,z=p
    if y>0:
        if abs(x)<1.85:
            x*=1.07;z=(z-.12)*1.16+.12
            if y<3.2:z+=.025*math.sin(x*8+y*5)
        else:
            # Sleeve ease around upper-arm centreline.
            center=Vector((math.copysign(2.60,x),3.85,.10))
            p=Vector((x,y,z));axis=Vector((math.copysign(.67,x),-.74,0));d=p-center
            p+= (d-axis*d.dot(axis))*.18
            x,y,z=p
    else:
        cx=math.copysign(1.0+max(0,-y)*.11,x)
        if y<-.6:
            t=min(1,max(0,(-y-.6)/6.7))
            rx=.88*(1-t)+.70*t;rz=.95*(1-t)+.69*t
            dx=x-cx;dz=z-.13
            angle=math.atan2(dz/.8,dx/.75)
            factor=.32+.60*t
            x=(1-factor)*x+factor*(cx+rx*math.cos(angle))
            z=(1-factor)*z+factor*(.13+rz*math.sin(angle))
            # Small seam-aligned breaks at the knee and hem.
            ripple=.020*math.sin(y*11+angle*2)*math.exp(-((y+3.7)/.65)**2)+.025*math.sin(y*15+angle*3)*math.exp(-((y+7.2)/.4)**2)
            x+=math.cos(angle)*ripple;z+=math.sin(angle)*ripple
            z+=math.copysign(.027*math.exp(-((x-cx)/.075)**2),z-.13)
        else:x*=1.055;z=(z-.1)*1.10+.1
    return co((x,y,z))

NATIVE_COLLAR=True
shirt=garment_mesh(SYS/'clothes/male_casualsuit01','male_casualsuit01',shirtmat);shirt.name='Uniform_Shirt | short sleeve'
# Raise the front neckline on its existing boundary so the uniform is buttoned
# higher than the casual-shirt source, without adding an overlapping patch.
bm=bmesh.new();bm.from_mesh(shirt.data)
for v in []:
    p=v.co;x=p.x/S;y=p.z/S+floor-.026/S;z=-p.y/S
    if any(e.is_boundary for e in v.link_edges) and 4.0<y<5.30 and abs(x)<.65 and z>.50:
        factor=max(0,1-abs(x)/.65)
        v.co.z+=.53*S*factor;v.co.y+=.16*S*factor
bm.to_mesh(shirt.data);bm.free()
# Removing lower half before sleeve clipping avoids accidental disconnected cuts.
cut(shirt,(0,.83,0),(0,-1,0))
if not NATIVE_COLLAR:cut(shirt,(0,5.60,0),(0,1,0))
cut(shirt,(2.90,3.78,.10),(.67,-.74,0),region=lambda p:p.x>1.7*S and p.z>co((0,2.7,0)).z)
cut(shirt,(-2.90,3.78,.10),(-.67,-.74,0),region=lambda p:p.x<-1.7*S and p.z>co((0,2.7,0)).z)
bm=bmesh.new();bm.from_mesh(shirt.data)
ff=[]
for f in bm.faces:
    p=f.calc_center_median();x=p.x/S;y=p.z/S+floor-.026/S
    z=-p.y/S
    if abs(x)>3.25 or (abs(x)>1.97 and y<3.0) or (not NATIVE_COLLAR and z>.42 and abs(x)<.62 and y>5.01+abs(x)*.96):ff.append(f)
bmesh.ops.delete(bm,geom=ff,context='FACES');bm.to_mesh(shirt.data);bm.free()
# Shape the neckline down to an open V at the centre front.
for v in ([] if NATIVE_COLLAR else shirt.data.vertices):
    p=v.co
    if abs(p.z-co((0,5.60,0)).z)<.0001 and p.y<-.30*S and abs(p.x)<.8*S:
        y=4.78+min(1,abs(p.x)/(.65*S))*.82
        p.z=co((0,y,0)).z
smooth(shirt,1);solid(shirt,.002);bind(shirt)
pants,_=objpart('Uniform_Trousers | straight tailored leg','helper-tights',pantsmat,clothshape)
cut(pants,(0,1.35,0),(0,1,0));cut(pants,(0,-7.42,0),(0,-1,0))
smooth(pants,1);solid(pants,.002);bind(pants)

def curve(name,points,radius,material,bone=None,taper=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=6 if 'hair' in name.lower() else 12;cu.bevel_depth=radius*S;cu.bevel_resolution=1 if 'hair' in name.lower() else 2
    sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
    for i,(b,p) in enumerate(zip(sp.bezier_points,points)):
        b.co=co(p);b.handle_left_type='AUTO';b.handle_right_type='AUTO'
        if taper:b.radius=.18+.82*math.sin(math.pi*i/(len(points)-1))**.5
    ob=bpy.data.objects.new(name,cu);asset.objects.link(ob);cu.materials.append(material)
    if bone:
        bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob.select_set(False);bind(ob,bone=bone)
    return ob
def panel(name,points,material,thick=.012,bevel=.01,bone=None):
    ob=mesh(name,[co(p) for p in points],[list(range(len(points)))],material)
    m=ob.modifiers.new('Panel thickness','SOLIDIFY');m.thickness=thick*S
    if bevel:
        m=ob.modifiers.new('Soft tailored edge','BEVEL');m.width=bevel*S;m.segments=3
    if bone:bind(ob,bone=bone)
    else:bind(ob)
    return ob
def uvball(name,center,size,material,bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=co(center))
    ob=link(bpy.context.object);ob.name=name;ob.scale=(size[0]*S,size[2]*S,size[1]*S)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(material)
    for p in ob.data.polygons:p.use_smooth=True
    if bone:bind(ob,bone=bone)
    else:bind(ob)
    ob.select_set(False);return ob
def button(name,x,y,z,r=.050,bone=None):
    ob=uvball(name,(x,y,z),(r,r,.023),gold,bone)
    for dx in [-.014,.014]:
        uvball(name+' thread hole',(x+dx,y,z+.023),(.006,.008,.004),thread,bone)
    return ob

# Chest patches follow the shirt curvature. Pockets and epaulets are not painted on.
bpy.context.view_layer.update()
clothbvh=BVHTree.FromObject(shirt,bpy.context.evaluated_depsgraph_get())
pantsbvh=BVHTree.FromObject(pants,bpy.context.evaluated_depsgraph_get())
def chestz(x,y):
    # Query the final cloth mesh in the frontal plane.
    origin=co((x,y,5));direction=Vector((0,1,0))
    loc,normal,idx,dist=clothbvh.ray_cast(origin,direction)
    return -loc.y/S+.032 if loc is not None else 1.15
def shouldery(x,z):
    loc,normal,idx,dist=clothbvh.ray_cast(co((x,7,z)),Vector((0,0,-1)))
    return loc.z/S+floor-.026/S+.020 if loc is not None else 5.5
def patch(name,xmin,xmax,ymin,ymax,offset=.035,flap=False):
    vv=[];ff=[];NX=10;NY=6
    for j in range(NY+1):
        v=j/NY
        for i in range(NX+1):
            u=i/NX;x=xmin+(xmax-xmin)*u
            low=ymin+(.11 if flap else .07)*abs(2*u-1)
            y=low+(ymax-low)*v;z=chestz(x,y)+offset
            vv.append(co((x,y,z)))
    for j in range(NY):
        for i in range(NX):
            a=j*(NX+1)+i;ff.append((a,a+1,a+NX+2,a+NX+1))
    ob=mesh(name,vv,ff,shirtmat,1);solid(ob,.0014);bind(ob);return ob
for sign,side in [(-1,'R'),(1,'L')]:
    xx=[sign*.35,sign*1.25];xlo,xhi=sorted(xx)
    def pt(x,y,offset=.018):return (x,y,chestz(x,y)+offset)
    pocket=[pt(xlo,3.62),pt(xhi,3.62),pt(xhi,2.55),pt((xhi+xlo)/2,2.46),pt(xlo,2.55)]
    patch('Chest pocket.'+side,xlo,xhi,2.46,3.62,.048)
    curve('Pocket double stitch.'+side,[pt(xlo+.04,3.52,.04),pt(xlo+.04,2.60,.04),pt((xlo+xhi)/2,2.52,.04),pt(xhi-.04,2.60,.04),pt(xhi-.04,3.52,.04)],.005,thread)
    flap=[pt(xlo-.035,3.66,.052),pt(xhi+.035,3.66,.052),pt(xhi+.015,3.35,.065),pt((xlo+xhi)/2,3.25,.075),pt(xlo-.015,3.35,.065)]
    patch('Pocket flap.'+side,xlo-.02,xhi+.02,3.25,3.66,.093,True)
    button('Pocket button.'+side,sign*.8,3.37,chestz(sign*.8,3.37)+.115,.048)
    # Epaulet bridge sits on the shoulder with gold braid.
    def ep(x,z,lift=0):return (sign*x,shouldery(sign*x,z)+lift,z)
    eps=[ep(.80,-.14),ep(1.94,-.14),ep(1.94,.28),ep(.80,.28)]
    epvs=[];epfs=[]
    for j in range(5):
        for i in range(13):epvs.append(co(ep(.80+1.14*i/12,-.14+.42*j/4)))
    for j in range(4):
        for i in range(12):
            a=j*13+i;epfs.append((a,a+1,a+14,a+13))
    epob=mesh('Epaulet.'+side,epvs,epfs,shirtmat,1);solid(epob,.0015);bind(epob)
    curve('Epaulet braid front.'+side,[ep(.88,.26,.008),ep(1.38,.26,.008),ep(1.88,.26,.008)],.013,goldedge)
    curve('Epaulet braid rear.'+side,[ep(.88,-.12,.008),ep(1.37,-.12,.008),ep(1.88,-.12,.008)],.013,goldedge)
    for j in range(11):
        t=j/11;x=sign*(.96+.83*t);y=5.45-.25*t
        curve('Epaulet woven thread.'+side+str(j),[ep(abs(x),-.11,.008),ep(abs(x),.08,.009),ep(abs(x),.25,.008)],.009,goldedge)
    uvball('Epaulet fastening.'+side,ep(.84,.08,.030),(.053,.014,.055),gold)

# Raised collar stand and two folded wings; open V at centre front.
bvs=[];bfs=[]
for j in [0,1]:
    for i in range(49):
        t=.34+(math.tau-.68)*i/48
        bvs.append(co((.62*math.sin(t),5.43+j*.27,.16+.66*math.cos(t))))
for i in range(48):bfs.append((i,i+1,i+50,i+49))
if not NATIVE_COLLAR:
    band=mesh('Collar stand | open neck',bvs,bfs,shirtmat,1);solid(band,.002);bind(band)
for s,side in ([] if NATIVE_COLLAR else [(-1,'R'),(1,'L')]):
    collar=[(s*.20,5.52,.90),(s*.44,5.68,.65),(s*.60,5.55,.30),
            (s*.13,5.06,chestz(s*.13,5.06)+.06),(s*.66,4.94,chestz(s*.66,4.94)+.065),(s*.90,5.37,chestz(s*.90,5.37)+.045)]
    ob=mesh('Folded collar.'+side,[co(p) for p in collar],[(0,1,4,3),(1,2,5,4)],shirtmat)
    solid(ob,.0024);m=ob.modifiers.new('Soft collar edge','BEVEL');m.width=.001;m.segments=3;bind(ob)
    curve('Collar edge stitching.'+side,[(x,y,z+.015) for x,y,z in [collar[3],collar[4],collar[5]]],.003,thread)
    uvball('Collar plain pin.'+side,(s*.52,5.22,.90),(.025,.044,.012),gold)

ys=[1.05,1.3,1.9,2.5,3.1,3.7,4.35]
for a,b in zip(ys[:-1],ys[1:]):
    panel('Shirt placket', [(-.09,a,chestz(0,a)+.025),(.09,a,chestz(0,a)+.025),(.09,b,chestz(0,b)+.025),(-.09,b,chestz(0,b)+.025)],shirtmat,.01,.008)
for y in [1.25,1.88,2.51,3.14,3.77,4.30]:button('Shirt button',0,y,chestz(0,y)+.075,.045)

namex=-.78;namey=3.96;nz=chestz(namex,namey)+.06
panel('Nameplate | editable',[(namex-.33,namey-.071,nz),(namex+.33,namey-.071,nz),(namex+.33,namey+.071,nz),(namex-.33,namey+.071,nz)],gold,.016,.008)
panel('Nameplate inset',[(namex-.305,namey-.055,nz+.02),(namex+.305,namey-.055,nz+.02),(namex+.305,namey+.055,nz+.02),(namex-.305,namey+.055,nz+.02)],black,.01,.003)
cu=bpy.data.curves.new('Teacher nameplate text','FONT');cu.body='TEACHER';cu.align_x='CENTER';cu.align_y='CENTER';cu.size=.065*S;cu.extrude=.00004
tx=bpy.data.objects.new('Nameplate text | TEACHER',cu);asset.objects.link(tx);tx.location=co((namex,namey,nz+.035));tx.rotation_euler=(math.pi/2,0,0);cu.materials.append(gold)
bpy.context.view_layer.objects.active=tx;tx.select_set(True);bpy.ops.object.convert(target='MESH');tx.select_set(False);bind(tx)

# Belt: continuous 3D loop, loops, metal frame and prong.
def ovalband(name,y,rx,rz,depth,height,material):
    vs=[];fs=[];N=96
    for yy,dd in [(y-height/2,0),(y+height/2,0),(y+height/2,-depth),(y-height/2,-depth)]:
        for i in range(N):
            t=i*math.tau/N
            loc,normal,idx,dist=clothbvh.ray_cast(co((0,yy,.1)),Vector((math.cos(t),-math.sin(t),0)))
            loc2,n2,i2,d2=pantsbvh.ray_cast(co((0,yy,.1)),Vector((math.cos(t),-math.sin(t),0)))
            if loc2 is not None and (loc is None or d2>dist):loc=loc2
            if loc is None:loc=co((rx*math.cos(t),yy,.1+rz*math.sin(t)))
            loc+=Vector((math.cos(t),-math.sin(t),0))*(.05+dd)*S;vs.append(loc)
    for j in range(4):
        for i in range(N):fs.append((j*N+i,j*N+(i+1)%N,((j+1)%4)*N+(i+1)%N,((j+1)%4)*N+i))
    ob=mesh(name,vs,fs,material);bind(ob);return ob
ovalband('Belt | full wrap',.92,1.80,1.17,.05,.28,pantsmat)
for x in [-1.35,-.68,.68,1.35]:
    z=chestz(x,.92)+.075
    panel('Belt loop',[(x-.035,.70,z),(x+.035,.70,z),(x+.035,1.11,z),(x-.035,1.11,z)],shirtmat,.027,.01)
bz=chestz(0,.94)+.10
panel('Buckle brass face',[(-.20,.755,bz),(.20,.755,bz),(.20,1.085,bz),(-.20,1.085,bz)],gold,.045,.03)
curve('Buckle inset frame',[(-.155,.80,bz+.034),(.155,.80,bz+.034),(.155,1.04,bz+.034),(-.155,1.04,bz+.034),(-.155,.80,bz+.034)],.008,goldedge)
uvball('Buckle plain crest',(0,.92,bz+.045),(.07,.10,.009),goldedge)
curve('Trouser fly seam',[(.14,.69,1.18),(.14,.1,1.16),(.08,-.45,1.03)],.005,thread)
for s in [-1,1]:
    curve('Slanted trouser pocket',[(s*1.21,.63,.82),(s*1.57,.03,.65),(s*1.67,-.35,.54)],.009,thread)

# Shoes: sculpted Oxford silhouette with welt, sole, heel, quarters and laces.
def shoe(s):
    center=s*1.82;N=64
    rings=[(-8.42,.48,.97,.82),(-8.35,.51,1.00,.82),(-8.20,.51,1.0,.82),(-8.08,.49,.96,.82),(-7.91,.43,.88,.77),(-7.69,.32,.57,.42),(-7.43,.25,.36,.15)]
    vs=[];fs=[]
    for y,rx,rz,cz in rings:
        for i in range(N):
            t=i*math.tau/N
            # Forefoot has a broad rounded toe; heel is narrower.
            zz=cz+rz*math.sin(t)
            width=rx*(1+.08*math.sin(t))
            vs.append(co((center+width*math.cos(t),y,zz)))
    fs.append(tuple(reversed(range(N))))
    for j in range(len(rings)-1):
        for i in range(N):fs.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
    fs.append(tuple((len(rings)-1)*N+i for i in range(N)))
    ob=mesh('Oxford shoe.'+str(s),vs,fs,leather,1);ob.data.materials.append(solemat)
    for p in ob.data.polygons:
        if p.center.z<co((0,-8.18,0)).z:p.material_index=1
    bind(ob,bone='foot.L' if s>0 else 'foot.R')
    bn='foot.L' if s>0 else 'foot.R'
    for y in [-8.20,-8.10]:
        pts=[(center+.50*math.cos(t),y,.82+.98*math.sin(t)) for t in [i*math.tau/48 for i in range(49)]]
        curve('Shoe welt stitch',pts,.007,solemat,bn)
    curve('Oxford toe cap seam',[(center-.37,-7.99,1.30),(center,-7.96,1.39),(center+.37,-7.99,1.30)],.010,solemat,bn)
    for k in range(5):
        zz=.36+.105*k;yy=-7.52-.068*k
        curve('Black shoe lace',[(center-.15,yy,zz),(center,yy+.013,zz+.033),(center+.15,yy,zz)],.012,solemat,bn)
shoe(-1);shoe(1)

# Eyes fitted with MakeHuman's official three-vertex correspondence.
ev,euv,ef,eg=read_obj(SRC/'high-poly.obj');mapping=[];scales={};active=False
for ln in (SRC/'high-poly.mhclo').read_text().splitlines():
    t=ln.split()
    if not t or t[0].startswith('#'):continue
    if t[0].endswith('_scale'):
        ax={'x':0,'y':1,'z':2}[t[0][0]];scales[ax]=abs(verts[int(t[1])][ax]-verts[int(t[2])][ax])/float(t[3])
    elif t[0]=='verts':active=True
    elif active:
        try:
            if len(t)==1:mapping.append(verts[int(t[0])].copy())
            elif len(t)>=9:
                p=sum((verts[int(t[j])]*float(t[3+j]) for j in range(3)),Vector())
                p+=Vector(tuple(float(t[6+j])*scales.get(j,1) for j in range(3)));mapping.append(p)
            else:active=False
        except ValueError:active=False
assert len(mapping)==len(ev),(len(mapping),len(ev))
eyemat=mat('Eyes | warm brown iris',(.8,.8,.8),.23)
nt=eyemat.node_tree;tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(SRC/'brown_eye.png'));nt.links.new(tex.outputs['Color'],nt.nodes.get('Principled BSDF').inputs['Base Color'])
nt.links.new(tex.outputs['Alpha'],nt.nodes.get('Principled BSDF').inputs['Alpha'])
for p in mapping:p.z+=.012
eye=mesh('Eyes | fitted cornea iris sclera',[co(p) for p in mapping],[[a[0] for a in f] for f in ef],eyemat,1)
luv=eye.data.uv_layers.new(name='Eye_UV')
for p,f in zip(eye.data.polygons,ef):
    for li,a in zip(p.loop_indices,f):
        q=Vector(euv[a[1]]);centers=[Vector((.284,.278)),Vector((.717,.719))];center=min(centers,key=lambda c:(q-c).length);d=q-center;r=d.length
        luv.data[li].uv=q
bind(eye,bone='head')

# Hair uses the head's own anatomy, giving a fitted hairline rather than a sphere.
hf=[]
for f,g in zip(faces,groups):
    if g!='body':continue
    p=sum((verts[a[0]] for a in f),Vector())/len(f)
    # Front hairline rises over the forehead; sides taper above the ears.
    ang=abs(math.atan2(p.x,p.z-.35))
    line=7.64 if ang<.7 else (7.64-(ang-.7)*.60 if ang<1.9 else 6.92)
    if abs(p.x)>.68 and -.05<p.z<.68:line=max(line,7.33)
    if p.y>line and p.y>6.85 and not(abs(p.x)>.78 and p.y<7.55):hf.append(f)
hids=sorted(set(a[0] for f in hf for a in f));hmap={a:i for i,a in enumerate(hids)}
hv=[]
for i in hids:
    p=verts[i].copy();center=Vector((0,7.15,.34));d=p-center
    p+=d.normalized()*.035
    lift=max(0,min(1,(p.y-7.35)/.9))
    p.y+=.18*lift;p.x-=.09*lift;p.z+=.06*lift
    hv.append(co(p))
hair=mesh('Hair | side swept short cut',hv,[[hmap[a[0]] for a in f] for f in hf],hairmat,2);solid(hair,.002);bind(hair,bone='head')
hn=hairmat.node_tree.nodes;hl=hairmat.node_tree.links
noise=hn.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=170;noise.inputs['Detail'].default_value=2
bump=hn.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.35;bump.inputs['Distance'].default_value=.0006
hl.new(noise.outputs['Fac'],bump.inputs['Height']);hl.new(bump.outputs['Normal'],hn.get('Principled BSDF').inputs['Normal'])
bpy.context.view_layer.update()
hairbvh=BVHTree.FromObject(hair,bpy.context.evaluated_depsgraph_get())
def hairpoint(p,offset=.014):
    loc,nor,idx,dist=hairbvh.find_nearest(co(p))
    loc+=nor*(offset*S)
    return (loc.x/S,loc.z/S+floor-.026/S,-loc.y/S)
for k in range(150):
    x=-.66+1.31*k/149
    jitter=random.uniform(-.007,.007)
    pts=[(x,7.65+.15*(abs(x)/.66)**2,1.43),
         (x-.16,7.98,1.29),(x-.23,8.34,.94),
         (x-.18,8.47,.43),(x-.10,8.21,-.20),(x,7.60,-.52)]
    pts=[hairpoint(p,.012+jitter) for p in pts]
    curve('Swept hair strand',pts,random.uniform(.003,.006),hairhi if k%4 else hairmat,'head',True)
for s in [-1,1]:
    for k in range(38):
        t=k/37
        pts=[(s*(.64+.1*t),7.66-.33*t,.92-.5*t),
             (s*.77,7.55-.32*t,.34-.30*t),
             (s*.63,7.49-.38*t,-.29),
             (s*.31,7.42-.40*t,-.51)]
        curve('Tapered side hair',[hairpoint(p) for p in pts],.004,hairhi,'head',True)

# Eyebrows follow the brow ridge and taper at both ends.
bpy.context.view_layer.update()
skinbvh=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
def facez(x,y):
    loc,_,_,_=skinbvh.ray_cast(co((x,y,3)),Vector((0,1,0)))
    return -loc.y/S+.014 if loc is not None else 1.3
for s in [-1,1]:
    pts=[(s*x,y,facez(s*x,y)) for x,y in [(.15,7.365),(.27,7.395),(.43,7.377),(.58,7.31)]]
    curve('Natural brow.'+str(s),pts,.021,browmat,'head',True)
    for k in range(24):
        t=k/23;x=s*(.16+.41*t);y=7.365+.035*math.sin(t*math.pi)-.05*t;z=facez(x,y)+.012
        curve('Brow hairs',[(x,y-.012,z+.01),(x+s*.015,y+.022,z+.008)],.004,browmat,'head')

# Official CC0 texture and fitted hair/shoes, now available after approval resumed.
def fit_proxy(folder,stem,material,sub=1,bone=None):
    pv,pu,pf,pg=read_obj(folder/(stem+'.obj'));fitted=[];scales={};active=False
    for ln in (folder/(stem+'.mhclo')).read_text().splitlines():
        t=ln.split()
        if not t or t[0].startswith('#'):continue
        if t[0].endswith('_scale'):
            ax={'x':0,'y':1,'z':2}[t[0][0]];scales[ax]=abs(verts[int(t[1])][ax]-verts[int(t[2])][ax])/float(t[3])
        elif t[0]=='verts':active=True
        elif active and t[0].lstrip('-').isdigit() and len(fitted)<len(pv):
            try:
                if len(t)==1:fitted.append(verts[int(t[0])].copy())
                elif len(t)>=9:
                    p=sum((verts[int(t[j])]*float(t[j+3]) for j in range(3)),Vector())
                    p+=Vector(tuple(float(t[j+6])*scales.get(j,1) for j in range(3)));fitted.append(p)
                else:active=False
            except ValueError:active=False
    assert len(fitted)==len(pv),(stem,len(fitted),len(pv))
    ob=mesh(stem,[co(p) for p in fitted],[[a[0] for a in f] for f in pf],material,sub)
    uv=ob.data.uv_layers.new(name='Texture_UV')
    for p,f in zip(ob.data.polygons,pf):
        for li,a in zip(p.loop_indices,f):uv.data[li].uv=pu[a[1]]
    bind(ob,bone=bone);return ob
def diffuse_image(material,path,alpha=False):
    n=material.node_tree.nodes;l=material.node_tree.links;b=n.get('Principled BSDF')
    im=n.new('ShaderNodeTexImage');im.image=bpy.data.images.load(str(path));l.new(im.outputs['Color'],b.inputs['Base Color'])
    if alpha:l.new(im.outputs['Alpha'],b.inputs['Alpha'])
    return im
skintex=diffuse_image(skin,SYS/'skins/young_asian_male/young_lightskinned_male_diffuse3.png')
def tint_image(material,texture,color):
    n=material.node_tree.nodes;l=material.node_tree.links
    mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1)
    l.new(texture.outputs['Color'],mix.inputs[1]);l.new(mix.outputs[0],n.get('Principled BSDF').inputs['Base Color'])
tint_image(skin,skintex,(.80,.70,.59))
for ob in list(asset.objects):
    if any(ob.name.startswith(prefix) for prefix in ['Hair |','Swept hair strand','Tapered side hair','Natural brow','Brow hairs','Oxford shoe','Shoe welt','Oxford toe','Black shoe lace']):
        bpy.data.objects.remove(ob,do_unlink=True)
hairpro=mat('Hair | textured swept short cut',(.015,.010,.006),.55)
hairpro.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.23
hairtex=diffuse_image(hairpro,SYS/'hair/short04/short04_diffuse.png',True);tint_image(hairpro,hairtex,(.12,.10,.08))
hair=fit_proxy(SYS/'hair/short04','short04',hairpro,1,'head');hair.name='Hair | swept short cut'
browtexmat=mat('Brows | textured dark hairs',(.015,.009,.006),.72)
browimage=diffuse_image(browtexmat,SYS/'eyebrows/eyebrow001/eyebrow001.png',True);tint_image(browtexmat,browimage,(.30,.25,.20))
brows=fit_proxy(SYS/'eyebrows/eyebrow001','eyebrow001',browtexmat,1,'head');brows.name='Eyebrows | natural dark brows'
shoemat=mat('Shoes | textured black leather',(.015,.018,.02),.34)
diffuse_image(shoemat,SYS/'clothes/shoes04/shoes04_diffuse.png')
nn=shoemat.node_tree.nodes;ll=shoemat.node_tree.links
texn=nn.new('ShaderNodeTexImage');texn.image=bpy.data.images.load(str(SYS/'clothes/shoes04/shoes04_normal.png'));texn.image.colorspace_settings.name='Non-Color'
normal=nn.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65
ll.new(texn.outputs['Color'],normal.inputs['Color']);ll.new(normal.outputs['Normal'],nn.get('Principled BSDF').inputs['Normal'])
shoes=fit_proxy(SYS/'clothes/shoes04','shoes04',shoemat,1);shoes.name='Shoes | black Oxford with socks'

# Hide the body under the uniform (non-destructive geometry selection).
bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table()
remove=[]
for f in bm.faces:
    ps=[verts[bodyids[v.index]] for v in f.verts];p=sum(ps,Vector())/len(ps)
    # Keep all head/neck and lower arms/hands; discard feet and covered torso/legs.
    if p.y<4.00 and not (abs(p.x)>1.68 and p.y>-.15):remove.append(f)
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()

# Curves not bound above are converted and skinned for a self-contained game asset.
for ob in list(asset.objects):
    if ob.type=='CURVE':
        bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH');bind(ob);ob.select_set(False)

# Bring the relaxed rest arms closer to the body for the presentation pose.
# Bone-local rotations derive from a desired world-axis rotation and preserve rest joints.
def world_rotation(name,axis,angle):
    pb=rig.pose.bones[name]
    rest=(pb.parent.matrix@pb.parent.bone.matrix_local.inverted()@pb.bone.matrix_local).to_3x3() if pb.parent else pb.bone.matrix_local.to_3x3()
    rot=Matrix.Rotation(angle,3,Vector(axis))
    pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(rest.inverted()@rot@rest).to_quaternion()
for s,side in [(1,'L'),(-1,'R')]:
    world_rotation('upperarm01.'+side,(0,1,0),s*math.radians(25))
    bpy.context.view_layer.update()
    world_rotation('lowerarm01.'+side,(1,0,0),math.radians(32))

# Normalise evaluated asset height (including shoes and hair) to exactly 1.80 m.
bpy.context.view_layer.update()
def bounds():
    dg=bpy.context.evaluated_depsgraph_get();points=[]
    for ob in asset.objects:
        if ob.type!='MESH':continue
        ev=ob.evaluated_get(dg);me=ev.to_mesh()
        points.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
    return tuple(min(p[k] for p in points) for k in range(3)),tuple(max(p[k] for p in points) for k in range(3))
lo,hi=bounds();scale=1.8/(hi[2]-lo[2]);rig.scale=(scale,scale,scale);rig.location.z=-lo[2]*scale
rig['height_m']=1.80;rig['role']='Male teacher, khaki short-sleeve civil-service-inspired uniform'
rig['front_axis']='-Y';rig['rest_pose']='A-pose; displayed in relaxed pose. Clear pose rotations before retargeting.'
rig['source']='MakeHuman CC0 anatomy, skin, eyes, brows, hair, shoes and weights. Original NetSim3D khaki uniform and detailing.'
rig['reference']='User-supplied khaki teacher uniform; plain generic epaulets, not a specific official rank.'
rig['export_note']='Export TEACHER collection only. Studio is presentation-only. Scene units: metres.'

# Studio, deliberately separated from the model.
ground=mat('Studio | warm gray',(.19,.21,.23),.9)
bpy.ops.mesh.primitive_plane_add(size=200);g=link(bpy.context.object,studio);g.name='Studio floor';g.data.materials.append(ground);g.location.z=-.004
def light(name,pos,power,size,target=(0,0,.9)):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);studio.objects.link(ob);ob.location=pos;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
light('Key softbox',(-3,-4,4),520,3)
light('Fill softbox',(3,-2,2.5),250,3)
light('Shoulder rim',(0,2.0,3.1),420,2)
world=bpy.data.worlds.new('Soft studio environment');world.use_nodes=True;world.node_tree.nodes.get('Background').inputs[0].default_value=(.32,.37,.45,1);world.node_tree.nodes.get('Background').inputs[1].default_value=.3;scene.world=world
camdata=bpy.data.cameras.new('Teacher presentation');cam=bpy.data.objects.new('Teacher presentation',camdata);studio.objects.link(cam);scene.camera=cam
def camera(pos,target,ortho):
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=ortho
camera((2.3,-6.5,2.15),(0,0,.91),2.13)
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1050;scene.render.resolution_y=1400;scene.render.resolution_percentage=75
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=2.8;area.spaces.active.region_3d.view_location=(0,0,.9)
        area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion();area.spaces.active.clip_end=100
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.context.view_layer.update();lo,hi=bounds()
report={'height_m':hi[2]-lo[2],'bounds':[lo,hi],'mesh_objects':len([o for o in asset.objects if o.type=='MESH']),'bones':len(arm.bones),'source_vertices':len(bodyids),'output':str(OUT)}
print('TEACHER_REPORT',json.dumps(report),flush=True)
(BASE/'temp/teacher_male/build_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for im in bpy.data.images:
    if im.source=='FILE':im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
if '--no-preview' in sys.argv:sys.exit(0)
scene.render.filepath=str(RENDER/'teacher_male_khaki_180cm_preview.png');bpy.ops.render.render(write_still=True)
camera((.32,-4,1.64),(0,0,1.49),.74);scene.render.resolution_x=1100;scene.render.resolution_y=1100
scene.render.filepath=str(RENDER/'teacher_male_khaki_detail.png');bpy.ops.render.render(write_still=True)
print('TEACHER_COMPLETE',flush=True)
