"""Build the Mission 04 serviceable PC. Run Blender -b --python this_file.py.
Geometry is authored in millimetres, stored/exported in metres. No dependencies.
The saved asset contains no studio, lights, cameras, or unapplied modifiers.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
(OUT / 'exports').mkdir(exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
INTERACTIONS = {
    'Cover_Screw_1': {'action': 'unscrew_cover_top', 'axis_blender': [0,1,0],
        'axis_godot': [0,0,-1], 'travel_m': .012, 'pick_box_size_godot_m': [.018,.018,.014]},
    'Cover_Screw_2': {'action': 'unscrew_cover_bottom', 'axis_blender': [0,1,0],
        'axis_godot': [0,0,-1], 'travel_m': .012, 'pick_box_size_godot_m': [.018,.018,.014]},
    'NIC_Bracket_Screw': {'action': 'unscrew_nic', 'axis_blender': [-1,0,0],
        'axis_godot': [-1,0,0], 'travel_m': .012, 'pick_box_size_godot_m': [.014,.016,.016]},
    'Power_Button': {'action': 'press_power', 'axis_blender': [0,1,0],
        'axis_godot': [0,0,-1], 'travel_m': .001, 'pick_box_size_godot_m': [.022,.022,.008]},
    'Power_Cable_Plug': {'action': 'unplug_power', 'axis_blender': [0,1,0],
        'axis_godot': [0,0,-1], 'travel_m': .045, 'pick_box_size_godot_m': [.032,.026,.032],
        'pick_box_center_godot_m': [0,0,-.013]},
}
groups = {k: [] for k in ('Case_Body', 'Side_Cover', 'Interior', 'NIC_Card', 'Power_LED', 'NIC_Link_LED', *INTERACTIONS)}

def mat(name, color, metal=0, rough=.45, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m

coat = mat('Graphite powder-coated steel', (.035, .044, .055), .55)
plastic = mat('Charcoal polymer', (.014, .019, .025))
black = mat('Socket cavities and rubber', (.004, .006, .009), rough=.7)
silver = mat('Brushed aluminium', (.52, .59, .66), .8, .3)
steel = mat('Steel chassis', (.23, .29, .34), .75)
pcb = mat('Green solder mask', (.018, .18, .085), .15)
trace = mat('PCB traces', (.065, .30, .15), .3)
gold = mat('Gold contacts', (.73, .43, .10), .8, .28)
white = mat('Silkscreen and labels', (.70, .77, .79), rough=.65)
blue = mat('Blue USB insert', (.025, .14, .42))
red = mat('SATA cable red', (.40, .025, .018))
copper = mat('Copper heatpipes', (.59, .25, .09), .8, .25)
power = mat('Power LED blue', (.08, .45, 1), emission=2)
link = mat('NIC link LED green', (.04, .8, .16), emission=2)

def mm(v):
    return Vector(v) * .001

def finish(o, name, material, group, bevel=0):
    o.name = name
    o.data.materials.append(material)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Edge radius', 'BEVEL')
        mod.width = bevel * .001
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    groups[group].append(o)
    return o

def box(name, size, pos, material=plastic, group='Interior', bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=mm(pos))
    o = bpy.context.object
    o.dimensions = mm(size)
    return finish(o, name, material, group, bevel)

def cyl(name, radius, depth, pos, material=silver, group='Interior', axis='Z', n=16):
    rot = {'X': (0, math.pi/2, 0), 'Y': (math.pi/2, 0, 0), 'Z': (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=radius*.001, depth=depth*.001,
                                      location=mm(pos), rotation=rot)
    return finish(bpy.context.object, name, material, group)

def line(name, points, radius, material=black, group='Interior', sides=6):
    for a, b in zip(points, points[1:]):
        a, b = Vector(a), Vector(b)
        o = cyl(name, radius, (b-a).length, (a+b)/2, material, group, n=sides)
        o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()

def text_mesh(text, pos, size, material=white, group='Interior', plane='side'):
    curve = bpy.data.curves.new('Engraved legend', 'FONT')
    curve.body = text
    curve.size = size*.001
    curve.align_x = 'CENTER'
    curve.resolution_u = 2
    o = bpy.data.objects.new('Legend '+text, curve)
    scene.collection.objects.link(o)
    o.location = mm(pos)
    # Text normal: side -X; front -Y; top +Z.
    o.rotation_euler = {'side': (math.pi/2, 0, -math.pi/2), 'front': (math.pi/2, 0, 0),
                        'top': (0, 0, 0)}[plane]
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, o.name, material, group)

def ring(name, radius, tube, pos, material, group='Interior', axis='Y'):
    rot = {'X': (0, math.pi/2, 0), 'Y': (math.pi/2, 0, 0), 'Z': (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=4,
        major_radius=radius*.001, minor_radius=tube*.001, location=mm(pos), rotation=rot)
    return finish(bpy.context.object, name, material, group)

def fan(name, center, radius, group='Interior', axis='Y'):
    c = Vector(center)
    u = Vector((1, 0, 0))
    v = Vector((0, 0, 1)) if axis=='Y' else Vector((0, 1, 0))
    normal = Vector((0, 1, 0)) if axis=='Y' else Vector((0, 0, 1))
    ring(name+' shroud', radius+2, 2.4, c, plastic, group, axis)
    cyl(name+' hub', radius*.25, 7, c, plastic, group, axis, 20)
    for i in range(7):
        theta = i*math.tau/7
        points = []
        for r, a, depth in [(radius*.23, theta, -1), (radius*.80, theta+.13, -2),
                             (radius*.96, theta+.48, 1), (radius*.48, theta+.69, 3)]:
            points.append(c + u*(r*math.cos(a)) + v*(r*math.sin(a)) + normal*depth)
        verts = [mm(p) for p in points] + [mm(p+normal*1.2) for p in points]
        faces = [(0,3,2,1), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)]
        mesh = bpy.data.meshes.new(name+' blade')
        mesh.from_pydata(verts, [], faces)
        o = bpy.data.objects.new(name+' blade', mesh)
        scene.collection.objects.link(o)
        finish(o, o.name, steel, group)
    for s in (-1, 1):
        for t in (-1, 1):
            p = c+u*s*(radius+3)+v*t*(radius+3)
            size = (8, 10, 8) if axis=='Y' else (8, 8, 6)
            box(name+' lug', size, p, plastic, group, 1)
            cyl(name+' screw', 1.8, 11 if axis=='Y' else 7, p, silver, group, axis, 8)

# Exact outer envelope: x +-95, y +-200, z 0..400 mm, feet included.
for x in (-70, 70):
    for y in (-163, 163):
        box('Rubber foot', (27, 32, 6), (x, y, 3), black, 'Case_Body', 1)
box('Floor pan', (184, 388, 3), (0, 0, 7.5), coat, 'Case_Body')
box('Right panel', (3, 388, 390), (93.5, 0, 203), coat, 'Case_Body', .6)
box('Roof', (190, 400, 3), (0, 0, 398.5), coat, 'Case_Body', .6)
for x in (-87, 87):
    box('Front fascia upright', (16, 6, 388), (x, -197, 203), plastic, 'Case_Body', 1)
box('Front control panel', (158, 4.8, 100), (0,-197,348), plastic, 'Case_Body', .5)
box('Front lower panel', (158, 4.8, 48), (0,-197,33), plastic, 'Case_Body', .5)
box('Front inset', (154, 1, 240), (0, -195, 172), black, 'Case_Body')
for z in range(65, 282, 7):
    box('Front ventilation louvre', (148, 2, 2), (0, -199, z), coat, 'Case_Body')
text_mesh('NETSIM', (0, -199.5, 317), 8, white, 'Case_Body', 'front')
text_mesh('WORKSTATION  /  04', (0, -199.5, 304), 3, white, 'Case_Body', 'front')
cyl('Power switch', 8, 2, (58, -199, 366), steel, 'Power_Button', 'Y', 24)
cyl('Power indicator', 3, 1, (58, -200+.5, 366), power, 'Power_LED', 'Y', 16)
for x in (-58, -33):
    box('Front USB rim', (16, 2, 8), (x, -199, 366), silver, 'Case_Body')
    box('Front USB recess', (13, 1, 5.5), (x, -199.5, 366), black, 'Case_Body')
    box('Front USB tongue', (11, .4, 1.5), (x, -199.8, 365), blue, 'Case_Body')
cyl('Headset jack', 3.4, 1, (-6, -199.5, 366), silver, 'Case_Body', 'Y')
cyl('Headset hole', 2, 1, (-6, -199.9+.5, 366), black, 'Case_Body', 'Y')

# Rear frame with an open horizontal service slot at NIC height.
for x in (-91, 90):
    box('Rear upright', (6, 3, 258), (x, 198.5, 268), coat, 'Case_Body')
box('Rear lower PSU band', (184, 3, 98), (0, 197, 58), coat, 'Case_Body')
box('Rear top band', (184, 3, 17), (0, 198.5, 388.5), coat, 'Case_Body')
box('Rear expansion upper panel', (177, 3, 74), (0, 197, 180), coat, 'Case_Body')
box('Rear fan left strip', (12, 3, 163), (-82, 198.5, 298), coat, 'Case_Body')
box('Rear IO divider', (8, 3, 163), (42, 198.5, 298), coat, 'Case_Body')
for z in (229, 367):
    box('Rear fan surround', (111, 3, 18), (-17, 198.5, z), coat, 'Case_Body')
for z in range(245, 360, 10):
    box('Exhaust grille bar', (108, 2, 1.5), (-17, 199, z), steel, 'Case_Body')
for x in (-66, -17, 32):
    box('Exhaust grille brace', (1.5, 2, 118), (x, 199, 301), steel, 'Case_Body')
box('Rear IO shield', (37, 2, 157), (66, 198, 299), silver, 'Interior')
for z in (351, 334, 317):
    for x in (58, 74):
        box('USB shield', (12, 12, 7), (x, 193, z), steel)
        box('USB well', (10, 1, 5), (x, 199, z), black)
        box('USB contact tongue', (8, 1, 1.4), (x, 199.4, z-1), blue)
box('HDMI socket', (16, 1, 6), (66, 199, 290), black)
box('HDMI tongue', (12, 1, 2), (66, 199.4, 290), gold)
box('Display port', (17, 1, 8), (66, 199, 274), black)
for z, m in ((253, blue), (242, pcb), (231, red)):
    cyl('Audio ring', 3.4, 2, (66, 199, z), m, axis='Y')
    cyl('Audio socket', 1.8, 1, (66, 199.5, z), black, axis='Y')

box('Removable side panel', (3, 388, 386), (-93.5, 0, 203), coat, 'Side_Cover', .6)
box('Side grip recess', (.6, 39, 8), (-94.7, 155, 203), black, 'Side_Cover')
for name,z in (('Cover_Screw_2',40), ('Cover_Screw_1',366)):
    cyl('Side screw shaft', 1.8, 8, (-89,197,z), steel, name, 'Y', 12)
    cyl('Thumb screw head', 4.5, 5, (-89,203.5,z), silver, name, 'Y', 24)
    for i in range(12):
        a=i*math.tau/12
        cyl('Thumb screw knurl', .45, 4, (-89+4.3*math.cos(a),203.5,z+4.3*math.sin(a)), steel, name, 'Y', 6)
    box('Phillips recess horizontal', (5,.1,1), (-89,206.05,z), black, name)
    box('Phillips recess vertical', (1,.1,5), (-89,206.05,z), black, name)

# ATX board: 240 mm deep x 290 mm tall, mounted to the +X wall.
box('ATX motherboard', (2, 240, 290), (87, 35, 246), pcb, bevel=.6)
for y in (-74, 35, 144):
    for z in (108, 246, 384):
        cyl('Board standoff', 3.3, 4, (90, y, z), gold, axis='X', n=8)
        cyl('Motherboard screw', 2.7, 1.5, (85.5, y, z), silver, axis='X', n=8)
for i in range(22):
    y = -78+i*9
    z = 140+(i%5)*34
    line('PCB routed trace', [(85.8,y,z), (85.8,y,z+17), (85.8,y+6,z+23), (85.8,y+6,z+36)], .3, trace, sides=4)
for y in (-70, -49, 129, 145):
    for z in (167, 215, 263, 359):
        box('Surface mount controller', (2.2, 9, 9), (84.5, y, z), black)
        for dz in (-6, 6):
            box('SMD resistor', (1.5, 3, 1.4), (84.5, y, z+dz), silver)
for y in (60, 76, 92, 108, 124):
    for z in (251, 362):
        cyl('Capacitor sleeve', 3.3, 9, (80, y, z), plastic, axis='X', n=10)
        cyl('Capacitor crown', 3, .5, (75.3, y, z), silver, axis='X', n=10)
box('CPU socket retention', (5, 54, 54), (82, 60, 306), steel, bevel=1)
box('CPU heat spreader', (4, 38, 38), (77.5, 60, 306), silver, bevel=1)
for y in (40, 60, 80):
    line('Copper CPU heat pipe', [(75,y,291), (13,y,291), (-4,y,299), (-4,y,337)], 2.1, copper, sides=8)
for x in range(-6, 71, 4):
    box('CPU aluminium fin', (1, 74, 81), (x, 60, 309), silver)
fan('CPU cooler fan', (30, 17, 309), 37)
for y in (-25, -41):
    box('DIMM slot', (7, 8, 137), (81, y, 309), plastic)
    box('RAM PCB', (29, 1.8, 128), (66, y, 309), pcb)
    for z in range(259, 362, 15):
        box('RAM memory package', (15, 2.5, 11), (64, y-2, z), black)
    box('RAM heatspreader spine', (4, 5, 126), (51, y, 309), steel, bevel=.4)
    for z in (241, 377):
        box('DIMM latch', (10, 9, 6), (79, y, z), white)
box('Chipset heatsink base', (6, 35, 34), (81, -27, 181), steel)
for y in range(-41, -10, 5):
    box('Chipset fin', (6, 1.5, 32), (76, y, 181), silver)
box('M2 SSD', (2, 80, 22), (82, 52, 212), pcb)
box('M2 controller', (3, 12, 14), (79.5, 24, 212), black)
box('M2 label', (1, 42, 17), (80, 64, 212), white)
text_mesh('NVMe  512', (79.4, 64, 209), 3.2, plastic)
cyl('M2 retention', 2, 2, (80, 90, 212), silver, axis='X', n=8)
for z, length in ((118, 31), (155, 87), (182, 31), (237, 87)):
    center_y = 151-length/2
    box('PCIe slot housing', (11, length, 9), (80, center_y, z), plastic)
    box('PCIe slot channel', (.7, length-3, 2.2), (74.2, center_y, z), black)
    if z!=118:
        box('Rear blank expansion bracket', (103, 1.5, 17), (22, 199, z), silver)
        for x in range(-19, 62, 8):
            box('Bracket vent', (4, .5, 9), (x, 199.7, z), black)

# PSU and drive cage remain below the card extraction plane.
box('PSU', (148, 148, 82), (6, 119, 51), plastic, bevel=2)
box('PSU side label', (.5, 93, 49), (-68.3, 118, 51), white)
text_mesh('450 W', (-68.7, 118, 58), 13, plastic)
text_mesh('ATX  /  80 PLUS', (-68.7, 118, 44), 4.4, plastic)
text_mesh('AC 100-240 V', (-68.7, 118, 34), 3.5, plastic)
fan('PSU fan', (6, 120, 94), 45, axis='Z')
for r in (18, 27, 36, 45):
    ring('PSU grille ring', r, .7, (6,120,99), steel, axis='Z')
box('IEC mains inlet', (27, .5, 20), (53, 199.6, 48), black)
for x in (46, 53, 60):
    box('IEC pin', (2, 1, 7), (x, 199.5, 48), silver)
# Separate removable C13-style mains connector; the fixed inlet stays in Interior.
box('Power plug insertion nose', (23,5,16), (53,199.5,48), black, 'Power_Cable_Plug', .6)
box('Moulded power plug grip', (27,26,20), (53,213,48), plastic, 'Power_Cable_Plug', 1.5)
for y in (206,211,216,221):
    for x in (39.3,66.7):
        box('Plug grip rib', (.8,1.2,14), (x,y,48), black, 'Power_Cable_Plug', .2)
cyl('Plug strain relief', 4.1, 12, (53,231,48), black, 'Power_Cable_Plug', 'Y', 16)
for y in (227,230,233,236):
    cyl('Strain relief rib', 4.7, 1.2, (53,y,48), plastic, 'Power_Cable_Plug', 'Y', 16)
line('Hanging mains cable', [(53,237,48),(53,242,47),(53,247,43),(53,250,37),
     (53,251,27),(53,251,7),(53,250,-13),(53,248,-33),(53,246,-52)], 3, black, 'Power_Cable_Plug', 12)
box('PSU switch', (11, 2, 16), (23, 199, 48), plastic)
for x in range(-65, 5, 7):
    for z in (30, 40, 50, 60, 70, 80):
        box('PSU rear vent', (3, .5, 5), (x, 199.7, z), black, 'Case_Body')
for x in (-67, 49):
    box('Drive cage rail', (3, 135, 86), (x, -115, 52), steel)
for z in (11, 53, 96):
    box('Drive shelf', (116, 131, 2), (-9, -115, z), steel)
box('HDD housing 3.5 inch', (101, 135, 26), (-9, -116, 27), plastic, bevel=1)
box('HDD steel lid', (99, 132, 1), (-9, -116, 40.5), silver, bevel=1)
box('HDD label', (57, 62, .5), (-9, -110, 41.3), white)
text_mesh('HDD  1 TB', (-9, -110, 41.7), 5, plastic, plane='top')
box('SSD 2.5 inch', (70, 100, 7), (-9, -116, 59), plastic, bevel=1)
box('SSD label', (49, 64, .5), (-9, -116, 62.8), white)
text_mesh('SATA SSD', (-9, -116, 63.2), 4.7, plastic, plane='top')
fan('Front intake', (-10, -180, 273), 53)
fan('Rear exhaust', (-17, 185, 301), 51)

# Routed wiring: nothing crosses the NIC removal envelope.
box('24 pin power connector', (12, 11, 49), (78, -77, 301), plastic)
for i in range(6):
    line('24 pin sleeved wire', [(75,-77,281+i*4),(68,-91,281+i*4),(68,-98,108),(65,-30,103),(55,48,88)], 1.2)
for z in (150, 240):
    box('ATX cable tie', (7, 7, 3), (68,-98,z), steel)
box('CPU 8 pin', (10, 19, 10), (79,124,377), plastic)
for i in range(3):
    line('8 pin CPU wire', [(77,124+i*3,377),(72,165+i*3,377),(76,179+i*3,175),(78,180+i*3,100),(58,163,89)], 1)
line('SATA data', [(83,-60,145),(80,-96,145),(77,-107,83),(24,-48,71),(22,-48,60)], 1.5, red)
line('SATA power', [(44,49,45),(44,18,35),(36,-36,35),(20,-46,28)], 2.3)
line('SSD power', [(36,-36,35),(37,-40,61),(20,-46,60)], 1.7)
line('Front panel harness', [(38,-187,365),(79,-176,375),(80,-139,375),(81,-117,109),(81,-75,107)], 1.3)

# NIC PCIe x1: horizontal PCB, real open RJ45 mouth, eight contacts.
box('NIC PCB', (63, 102, 1.6), (45,141,118), pcb, 'NIC_Card', .3)
box('NIC controller', (15, 15, 2.2), (43,143,120), black, 'NIC_Card', .3)
box('NIC oscillator', (5, 9, 2), (61,154,120), silver, 'NIC_Card')
for y in (128, 135, 142, 149):
    box('NIC memory and regulator', (5, 3, 1.2), (24,y,119.4), black, 'NIC_Card')
for i in range(18):
    box('PCIe gold finger', (7, 1.15, .15), (77.5,123+i*1.5,118.9), gold, 'NIC_Card')
for y in (119, 151, 168):
    line('NIC traces', [(32,y,118.85),(51,y,118.85),(60,y+7,118.85),(70,y+7,118.85)], .25, trace, 'NIC_Card', 4)
text_mesh('NET / 1G', (45,102,119), 3.8, white, 'NIC_Card', 'top')
# Split bracket leaves a genuine aperture, instead of a dark painted rectangle.
for x, width in ((7,40),(61,32)):
    box('NIC steel bracket', (width,1.4,19), (x,198,126), silver, 'NIC_Card')
for z in (118,135):
    box('NIC bracket aperture edge', (18,1.4,2), (36,198,z), silver, 'NIC_Card')
box('NIC bracket fixing tab', (8,8,1.4), (77,194,135), silver, 'NIC_Card')
cyl('NIC screw shaft', 1.6, 7, (78,194,135), steel, 'NIC_Bracket_Screw', 'X', 12)
cyl('NIC retaining screw head', 4.2, 2.5, (73.3,194,135), silver, 'NIC_Bracket_Screw', 'X', 24)
box('NIC screw cross slot Y', (.1,5,.9), (72,194,135), black, 'NIC_Bracket_Screw')
box('NIC screw cross slot Z', (.1,.9,5), (72,194,135), black, 'NIC_Bracket_Screw')
for x in (27.5,44.5):
    box('RJ45 shield side', (1,21,14), (x,188.5,126), silver, 'NIC_Card')
for z in (119.5,132.5):
    box('RJ45 shield roof floor', (18,21,1), (36,188.5,z), silver, 'NIC_Card')
box('RJ45 black rear cavity', (16,1,12), (36,180,126), black, 'NIC_Card')
for i in range(8):
    line('RJ45 gold spring contact', [(31.55+i*1.27,182,130),(31.55+i*1.27,194,128)], .28, gold, 'NIC_Card', 4)
box('RJ45 latch notch left', (5,2,2), (29.5,197,121), plastic, 'NIC_Card')
box('RJ45 latch notch right', (5,2,2), (42.5,197,121), plastic, 'NIC_Card')
box('Link LED', (2.8,1,2), (47,199,131), link, 'NIC_Link_LED')

# Merge each interactive assembly separately and normalize transforms.
origins = {'Case_Body':(0,0,0), 'Interior':(0,0,0), 'Side_Cover':(-93.5,0,203),
           'NIC_Card':(45,145,118), 'Power_LED':(58,-199.5,366), 'NIC_Link_LED':(47,199,131),
           'Cover_Screw_1':(-89,203.5,366), 'Cover_Screw_2':(-89,203.5,40),
           'NIC_Bracket_Screw':(73.3,194,135), 'Power_Button':(58,-199,366), 'Power_Cable_Plug':(53,200,48)}
objects = {}
for name, parts in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts)>1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    scene.cursor.location = mm(origins[name])
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    # Recalculate normals on all hand-authored blades and joined geometry.
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(o.data)
    bm.free()
    objects[name] = o
root = bpy.data.objects.new('PC_Tower', None)
scene.collection.objects.link(root)
root['front'] = '-Y in Blender / +Z in Godot'
root['side_cover'] = '-X'
root['units'] = 'metres'
parents = {'NIC_Link_LED':'NIC_Card'}
for name, o in objects.items():
    world = o.matrix_world.copy()
    o.parent = objects[parents[name]] if name in parents else root
    o.matrix_world = world
    if name in INTERACTIONS:
        o['interaction_id'] = name
        o['interaction_action'] = INTERACTIONS[name]['action']
port = bpy.data.objects.new('NIC_Port_Point', None)
scene.collection.objects.link(port)
port.empty_display_type = 'ARROWS'
port.empty_display_size = .015
port.parent = objects['NIC_Card']
port.location = mm(Vector((36,200,126))-Vector(origins['NIC_Card']))
port.rotation_euler = (math.pi/2*-1, 0, 0)
port['insertion_axis'] = '-Z local; Blender -Y; Godot +Z'
objects['Side_Cover']['remove_direction'] = '-X, relative to its rest position'
objects['NIC_Card']['remove_direction'] = '-X; detach cable and remove NIC_Bracket_Screw first'
target = bpy.data.objects.new('PCIe_Slot_Target', None)
scene.collection.objects.link(target)
target.parent = root
target.location = mm(origins['NIC_Card'])
target.empty_display_type = 'SPHERE'
target.empty_display_size = .008
scene.cursor.location = (0,0,0)
bpy.context.view_layer.update()

triangles = {}
for name, o in objects.items():
    o.data.calc_loop_triangles()
    triangles[name] = len(o.data.loop_triangles)
assert sum(triangles.values()) <= 20000, triangles
assert all(len(o.modifiers)==0 for o in objects.values())
points = [o.matrix_world@v.co for name,o in objects.items() if name not in INTERACTIONS for v in o.data.vertices]
low = [min(p[i] for p in points) for i in range(3)]
high = [max(p[i] for p in points) for i in range(3)]
assert all(abs((high[i]-low[i])-s)<.0001 for i,s in enumerate((.19,.40,.40))), (low,high,triangles)
all_points = [o.matrix_world@v.co for o in objects.values() for v in o.data.vertices]
all_low = [min(p[i] for p in all_points) for i in range(3)]
all_high = [max(p[i] for p in all_points) for i in range(3)]
for name, data in INTERACTIONS.items():
    pos = objects[name].matrix_world.translation
    data['parent'] = objects[name].parent.name
    data['origin_blender_m'] = list(pos)
    data['origin_godot_m'] = [pos.x,pos.z,-pos.y]
    local = objects[name].location
    data['rest_local_godot_m'] = [local.x,local.z,-local.y]
    data.setdefault('pick_box_center_godot_m', [0,0,0])
(OUT/'exports'/'pc_tower_interactions.json').write_text(json.dumps(INTERACTIONS,indent=2),encoding='utf-8')
direction = port.matrix_world.to_3x3()@Vector((0,0,-1))
assert (direction-Vector((0,-1,0))).length < .00001
report = {'triangles':sum(triangles.values()), 'per_object_triangles':triangles,
          'dimensions_blender_m':[high[i]-low[i] for i in range(3)],
          'bounds_blender_m':[low, high], 'textures':0, 'material_count':len(bpy.data.materials),
          'overall_dimensions_with_plug_blender_m':[all_high[i]-all_low[i] for i in range(3)],
          'interactive_meshes':list(INTERACTIONS),
          'nic_origin_blender_m':list(objects['NIC_Card'].matrix_world.translation),
          'port_blender_m':list(port.matrix_world.translation), 'port_insert_blender':list(direction),
          'port_insert_godot':[direction.x,direction.z,-direction.y]}
(OUT/'exports'/'pc_tower_nic_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='SELECT')
scene['asset_triangle_count'] = sum(triangles.values())
# Save only the clean asset. Preview studio is created afterwards and never saved.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pc_tower_nic.blend'), compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'exports'/'pc_tower_nic.glb'), export_format='GLB',
    use_selection=True, export_yup=True, export_apply=True, export_cameras=False, export_lights=False,
    export_extras=True)
print('ASSET_VALIDATED',json.dumps(report),flush=True)

def aim(o, target):
    o.rotation_euler = (Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

ground = box('Preview floor', (2000,2000,10), (0,0,-85), mat('Studio floor',(.12,.15,.19)))
box('Preview tabletop', (1200,1000,20), (0,-290,-10), mat('Tabletop',(.16,.18,.20)))
cam_data = bpy.data.cameras.new('Preview camera')
cam = bpy.data.objects.new('Preview camera',cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam_data.type='ORTHO'
cam_data.ortho_scale=.73
for name,pos,energy,size in [('Key',(-.65,-.5,.9),55,.7),('Fill',(-.6,.5,.5),35,.6),('Rim',(.5,.25,.9),65,.6)]:
    d=bpy.data.lights.new(name,'AREA')
    d.energy=energy
    d.shape='DISK'
    d.size=size
    o=bpy.data.objects.new(name,d)
    scene.collection.objects.link(o)
    o.location=pos
    aim(o,(0,0,.2))
world=bpy.data.worlds.new('Studio world')
world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.2,.25,.32,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.4
scene.world=world
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.cycles.max_bounces=6
scene.render.resolution_x=1400
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
for name,pos in [('closed',(-.75,-.9,.65)),('open',(-1,.56,.61)),('service_parts',(-.55,.85,.46))]:
    objects['Side_Cover'].hide_render = name=='open'
    for screw in ('Cover_Screw_1','Cover_Screw_2'):
        objects[screw].hide_render = name=='open'
    cam.location=pos
    aim(cam,(0,0,.20))
    scene.render.filepath=str(OUT/'previews'/('pc_tower_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('PREVIEW_DONE',name,flush=True)
