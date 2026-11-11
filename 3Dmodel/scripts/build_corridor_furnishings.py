"""Build approved corridor props, metres, floor origin; Blender -b --python this.py.

Independent source files: never changes classroom_shell.blend or character files.
Blender front is -Y (Godot +Z), long furniture axis X; export is Y-up.
"""
import bpy
import math
import random
import json
import shutil
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / '3Dmodel/ใช้ร่วมกัน'
BLEND = SHARED / 'blend/corridor'
EXPORT = SHARED / 'exports/corridor'
GAME = ROOT / 'net-sim-3d/assets/models/corridor'
TEXTURE = SHARED / 'textures/corridor'
for p in (BLEND, EXPORT, GAME, TEXTURE):
    p.mkdir(parents=True, exist_ok=True)
random.seed(11011)


def wood_image():
    """Author an original tileable wood grain texture inside Blender."""
    size = 512
    im = bpy.data.images.new('Corridor oak grain', width=size, height=size)
    pixels = []
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            warp = .8 * math.sin(2 * math.pi * u) + .2 * math.sin(6 * math.pi * u)
            grain = math.sin(2 * math.pi * (v * 49 + warp * .18))
            fine = math.sin(2 * math.pi * (v * 137 + warp * .42))
            band = math.sin(2 * math.pi * (v * 9 + .09 * math.sin(2 * math.pi * u)))
            tone = .028 * grain + .012 * fine + .022 * band
            pixels.extend((.80 + tone, .64 + tone * .84, .43 + tone * .55, 1))
    im.pixels.foreach_set(pixels)
    im.filepath_raw = str(TEXTURE / 'oak_grain.png')
    im.file_format = 'PNG'
    im.save()


wood_image()
REPORT = {}


def material(name, color, rough=.65, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    return m


def setup(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    s = bpy.context.scene
    s.unit_settings.system = 'METRIC'
    s.unit_settings.scale_length = 1
    root = bpy.data.objects.new(name, None)
    s.collection.objects.link(root)
    root['asset_role'] = name
    root['units'] = 'metres; floor Z=0; front -Y'
    wood = material('Oak | original fine grain', (.69, .47, .25), .62)
    tex = wood.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(TEXTURE / 'oak_grain.png'))
    wood.node_tree.links.new(tex.outputs['Color'], wood.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    mats = {
        'wood': wood,
        'metal': material('Navy | powder coated steel', (.035, .064, .083), .5, .35),
        'bolt': material('Steel | flush bolts', (.22, .25, .27), .38, .7),
        'black': material('Shoe | black leather', (.025, .032, .04), .42),
        'white': material('Shoe | off white canvas', (.78, .79, .76), .9),
        'sole': material('Shoe | dark rubber sole', (.012, .016, .021), .9),
    }
    return root, mats


def finish(o, root, mat, smooth=False):
    o.parent = root
    o.data.materials.append(mat)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def box(name, pos, dims, mat, root, bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o, root, mat)


def cylinder(name, pos, radius, depth, mat, root, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    o = bpy.context.object
    o.name = name
    return finish(o, root, mat, True)


def join_export(name, root):
    # One mesh per prop, shared materials; not hundreds of nodes at runtime.
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [o for o in root.children if o.type == 'MESH']
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = name + '_Mesh'
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.data.calc_loop_triangles()
    REPORT[name] = {'triangles': len(mesh.data.loop_triangles), 'mesh_objects': 1}
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.context.scene['design_reference'] = 'Preview/โถงทางเดิน/corridor-concept-v2.png'
    for im in bpy.data.images:
        if im.source == 'FILE':
            im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND / (name + '.blend')), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT / (name + '.glb')), export_format='GLB',
                              use_selection=True, export_apply=True, export_extras=True,
                              export_yup=True)
    shutil.copy2(EXPORT / (name + '.glb'), GAME / (name + '.glb'))


# 1. Bench, 1.5m long, seat 45cm, back 83cm.
root, m = setup('corridor_bench')
for x in (-.655, .655):
    for y in (-.175, .175):
        box('Steel leg', (x, y, .216), (.038, .038, .432), m['metal'], root)
    box('Seat cross support', (x, 0, .403), (.038, .43, .035), m['metal'], root)
    box('Back support', (x, .19, .618), (.032, .035, .43), m['metal'], root)
box('Long steel stretcher', (0, .12, .22), (1.34, .028, .035), m['metal'], root)
for y in (-.118, .118):
    box('Oak seat plank', (0, y, .432), (1.5, .225, .036), m['wood'], root, .006)
for z in (.65, .765):
    box('Oak back plank', (0, .198, z), (1.5, .028, .105), m['wood'], root, .004)
for x in (-.655, .655):
    for z in (.65, .765):
        bolt = cylinder('Flush back bolt', (x, .181, z), .005, .003, m['bolt'], root, 8)
        bolt.rotation_euler.x = math.pi / 2
root['seat_height_m'] = .45
join_export('corridor_bench', root)


def shoe(root, mat, cx, cy, floor, side):
    # Small closed-toe school shoe: lofted round toe, low instep and heel.
    rings = [(-.128, .005, .018), (-.115, .038, .034), (-.065, .046, .055),
             (.005, .043, .068), (.075, .035, .073), (.12, .03, .062), (.131, .016, .043)]
    verts, faces = [], []
    sides = 10
    for y, width, h in rings:
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append((cx + width * math.cos(a), cy + y,
                          floor + .017 + h * (.5 + .5 * math.sin(a))))
    for i in range(len(rings) - 1):
        for k in range(sides):
            faces.append((i*sides+k, i*sides+(k+1)%sides,
                          (i+1)*sides+(k+1)%sides, (i+1)*sides+k))
    faces += [tuple(reversed(range(sides))), tuple((len(rings)-1)*sides+k for k in range(sides))]
    mesh = bpy.data.meshes.new('School shoe upper')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new('School shoe ' + str(side), mesh)
    bpy.context.scene.collection.objects.link(o)
    finish(o, root, mat, True)
    box('Rubber sole', (cx, cy, floor+.011), (.087, .252, .018), m['sole'], root, .009)
    if mat == m['white']:
        for i in range(3):
            box('Canvas lace', (cx, cy-.015+i*.017, floor+.077), (.061, .006, .003), m['white'], root, .001)


# 2. Real 10-column x 3-row rack: one PAIR fits each 29cm-wide cubby.
root, m = setup('corridor_shoe_rack_30')
width, depth, top = 3.12, .35, .985
for x in (-1.54, 1.54):
    for y in (-.157, .157):
        box('Steel rack post', (x, y, top/2), (.035, .035, top), m['metal'], root)
for z in (.085, .375, .665, .955):
    box('Oak shelf', (0, 0, z), (3.09, depth, .025), m['wood'], root, .003)
for i in range(11):
    x = -1.525 + i * .305
    box('Cubby divider %02d' % i, (x, 0, .52), (.012, .336, .85), m['wood'], root, .001)
box('Ventilated back retaining rail', (0, .157, .53), (3.07, .025, .045), m['metal'], root)
for row in range(3):
    for col in range(10):
        if (row * 10 + col) % 7 in (3, 5):
            continue
        mid = -1.3725 + col*.305
        shoe_mat = m['white'] if (row+col)%3 == 0 else m['black']
        for side in (-1, 1):
            shoe(root, shoe_mat, mid+side*.052, -.005, .099+row*.29, side)
root['pair_capacity'] = 30
root['columns'] = 10
root['rows'] = 3
root['clear_cubby_width_m'] = .293
join_export('corridor_shoe_rack_30', root)


# 3. Broad-leaf indoor plant, 1.3m tall, subtle leaf curvature and colour variation.
root, m = setup('corridor_plant')
pot = material('Pot | warm matte ivory', (.72, .72, .67), .87)
soil = material('Soil | warm brown', (.065, .043, .024), 1)
stem_mat = material('Plant | stems', (.065, .17, .032), .78)
greens = [material('Leaf | green %d' % i, c, .7) for i,c in enumerate([
    (.10, .26, .045), (.15, .33, .07), (.20, .38, .09), (.075, .21, .032)])]
verts, faces = [], []
for radius,z in ((.158, .005), (.197, .36), (.181, .36), (.153, .025)):
    for k in range(32):
        a = k*math.tau/32
        verts.append((radius*math.cos(a), radius*math.sin(a), z))
for ring in range(3):
    for k in range(32):
        faces.append((ring*32+k, ring*32+(k+1)%32, (ring+1)*32+(k+1)%32, (ring+1)*32+k))
mesh=bpy.data.meshes.new('Tapered pot with real open rim')
mesh.from_pydata(verts, [], faces)
o=bpy.data.objects.new('Ivory planter',mesh)
bpy.context.scene.collection.objects.link(o)
finish(o,root,pot,True)
cylinder('Visible soil', (0,0,.337), .178, .018, soil, root,32)


def branch(name, a, b, radius):
    delta=Vector(b)-Vector(a)
    o=cylinder(name, (Vector(a)+Vector(b))/2, radius, delta.length, stem_mat,root,8)
    o.rotation_euler=delta.to_track_quat('Z','Y').to_euler()


for i in range(24):
    angle=i*2.39996
    length=.48 + .07*math.sin(i*.8)
    base=Vector((.025*math.cos(angle), .025*math.sin(angle), .40 + (i%6)*.073))
    start=Vector((.04*math.cos(angle), .04*math.sin(angle),base.z))
    branch('Leaf petiole', (base.x,base.y,.34), start, .004)
    vv, ff=[], []
    tangent=Vector((-math.sin(angle),math.cos(angle),0))
    outward=Vector((math.cos(angle),math.sin(angle),0))
    for j in range(10):
        t=j/9
        centre=start+outward*(length*t*.58)+Vector((0,0,length*(1.65*t-.85*t*t)))
        half=.105*math.sin(math.pi*t)**.8+.001
        for u in (-1,0,1):
            point=centre+tangent*(u*half)
            point.z-=abs(u)*.013*math.sin(math.pi*t)
            vv.append(tuple(point))
    for j in range(9):
        for k in range(2):
            ff.append((j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k))
    me=bpy.data.meshes.new('Curved broad leaf')
    me.from_pydata(vv,[],ff)
    obj=bpy.data.objects.new('Broad leaf %02d'%i,me)
    bpy.context.scene.collection.objects.link(obj)
    finish(obj,root,greens[i%4],True)
    # glTF explicitly double-sided: visible from either side without duplicated geometry.
    greens[i%4].use_backface_culling=False
root['pot_diameter_m']=.394
join_export('corridor_plant', root)

(EXPORT/'asset-report.json').write_text(json.dumps(REPORT,indent=2),encoding='utf-8')
print('CORRIDOR_ASSETS_BUILT',json.dumps(REPORT),flush=True)
