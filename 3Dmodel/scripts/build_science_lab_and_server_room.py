"""Furnish the Science classroom and the Server room (Data Center + Server zones).

Run with Blender 5.2:
    blender -b 3Dmodel/blend/classroom_shell.blend --python 3Dmodel/scripts/build_science_lab_and_server_room.py -- [--save OUT.blend]

* Science classroom = the left-bottom room of the floor plan (Room_BackgroundClass,
  sign "ห้องเรียนวิทยาศาสตร์"): lab islands with sinks and gas taps, stools,
  teacher demonstration bench, whiteboard, fume hood, glassware and chemical
  cabinets, safety shower + eyewash, periodic table, microscopes and glassware.
* Server room = one room in two zones split by a glass partition:
  - Data Center zone (by the corridor door): operators work here. The NOC desk
    with the phone and DATACENTER-PC (Mission 6) is a Godot scene and stays;
    this script adds the video wall, a second NOC desk, chairs, filing cabinet,
    repair bench, printer table, whiteboard and wall equipment.
  - Server zone (behind the glass): raised floor, two rack rows in a hot/cold
    aisle layout, overhead cable trays, precision air-conditioning, UPS and
    battery cabinets, FM-200 fire suppression, CCTV and an access-controlled door.

Everything is built from simple meshes (one joined mesh per piece of furniture,
linked duplicates for repeated items) so the Web export stays light.
Objects with the custom property collision="box" get a box collider from
net-sim-3d/tools/export_blender_assets.py. Re-running the script first removes
what it built before (collections "15 | Science lab" and "16 | Server room").
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
FONT_PATH = ROOT / "net-sim-3d" / "assets" / "fonts" / "Sarabun-Bold.ttf"
SCI_NAME = "15 | Science lab"
SRV_NAME = "16 | Server room - Data Center and Server zones"

scene = bpy.context.scene


# ============================================================ helpers

def remove_collection(name):
    c = bpy.data.collections.get(name)
    if not c:
        return
    for child in list(c.children_recursive):
        for o in list(child.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(child)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(c)


def collection(name, parent=None):
    c = bpy.data.collections.new(name)
    (parent.children if parent else scene.collection.children).link(c)
    return c


MATS = {}


def mat(name, color, rough=0.6, metal=0.0, emit=None, emit_strength=0.0, alpha=1.0):
    """Principled material, reused by name."""
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, alpha)
    if bpy.app.version < (5, 0, 0) and not m.use_nodes:
        m.use_nodes = True  # Always on from Blender 5.0.
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = emit_strength
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
    MATS[name] = m
    return m


class Item:
    """Builds one joined mesh from boxes and cylinders (local coordinates)."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _slot(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _finish(self, verts, m, pos, rz=0.0, rx=0.0, ry=0.0):
        rot = Matrix.Rotation(rz, 3, "Z") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X")
        bmesh.ops.rotate(self.bm, cent=(0, 0, 0), matrix=rot, verts=verts)
        bmesh.ops.translate(self.bm, vec=Vector(pos), verts=verts)
        idx = self._slot(m)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = idx
        return self

    def box(self, size, pos, m, rz=0.0, rx=0.0, ry=0.0):
        verts = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        bmesh.ops.scale(self.bm, vec=Vector(size), verts=verts)
        return self._finish(verts, m, pos, rz, rx, ry)

    def cyl(self, r, h, pos, m, r2=None, seg=16, rx=0.0, ry=0.0, rz=0.0):
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                      radius1=r, radius2=r if r2 is None else r2, depth=h)["verts"]
        return self._finish(verts, m, pos, rz, rx, ry)

    def build(self, coll, loc=(0, 0, 0), rz=0.0, collide=False, note=""):
        me = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(self.name, me)
        coll.objects.link(o)
        o.location = loc
        o.rotation_euler.z = rz
        if collide:
            o["collision"] = "box"
        if note:
            o["note"] = note
        return o


def dup(src, name, coll, loc, rz=0.0):
    """Linked duplicate (shares the mesh, so the GLB stores it once)."""
    o = bpy.data.objects.new(name, src.data)
    coll.objects.link(o)
    o.location = loc
    o.rotation_euler.z = rz
    for k in src.keys():
        o[k] = src[k]
    return o


_font = None


def text(name, body, coll, loc, size, m, rot=(math.pi / 2, 0, 0), align="CENTER"):
    """Text converted to a mesh (the exporter only exports meshes)."""
    global _font
    if _font is None:
        _font = bpy.data.fonts.load(str(FONT_PATH)) if FONT_PATH.exists() else None
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    if _font:
        cu.font = _font
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.resolution_u = 2
    o = bpy.data.objects.new(name, cu)
    coll.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    cu.materials.append(m)
    me = bpy.data.meshes.new_from_object(o)
    mesh_obj = bpy.data.objects.new(name, me)
    coll.objects.link(mesh_obj)
    mesh_obj.matrix_world = o.matrix_world
    bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.curves.remove(cu)
    mesh_obj.name = name
    return mesh_obj


# ============================================================ materials

# Own glass material: alpha blended, so it stays see-through after the glTF export.
GLASS = mat("FX | clear glass", (0.78, 0.88, 0.93), 0.05, 0.0, alpha=0.18)
EPOXY = mat("SCI | black epoxy worktop", (0.035, 0.037, 0.04), 0.35)
LAB_CAB = mat("SCI | cabinet pale grey", (0.80, 0.82, 0.80), 0.55)
LAB_DOOR = mat("SCI | cabinet door sage", (0.55, 0.68, 0.62), 0.5)
STEEL = mat("SCI | stainless steel", (0.70, 0.72, 0.74), 0.25, 0.85)
CHROME = mat("SCI | chrome", (0.85, 0.86, 0.88), 0.15, 0.95)
GAS_TAP = mat("SCI | gas tap yellow", (0.95, 0.72, 0.05), 0.4)
STOOL_SEAT = mat("SCI | stool seat blue", (0.10, 0.28, 0.55), 0.5)
DARK = mat("SCI | dark plastic", (0.06, 0.065, 0.07), 0.5)
BOARD = mat("SCI | whiteboard", (0.93, 0.95, 0.95), 0.2)
BOARD_FRAME = mat("SCI | aluminium frame", (0.62, 0.64, 0.66), 0.3, 0.7)
INK = mat("SCI | marker ink blue", (0.05, 0.15, 0.55), 0.4)
SIGN_GREEN = mat("SCI | safety sign green", (0.0, 0.52, 0.30), 0.4)
SIGN_RED = mat("SCI | fire red", (0.78, 0.06, 0.05), 0.4)
SIGN_YELLOW = mat("SCI | flammable yellow", (0.95, 0.78, 0.05), 0.45)
WHITE = mat("SCI | white", (0.95, 0.95, 0.95), 0.4)
WOOD = mat("SCI | beech wood", (0.72, 0.55, 0.36), 0.55)
GLASSWARE = mat("SCI | glassware", (0.75, 0.88, 0.92), 0.05, alpha=0.35)
LIQ_BLUE = mat("SCI | solution blue", (0.10, 0.35, 0.85), 0.1, alpha=0.75)
LIQ_GREEN = mat("SCI | solution green", (0.15, 0.70, 0.25), 0.1, alpha=0.75)
LIQ_ORANGE = mat("SCI | solution orange", (0.95, 0.45, 0.08), 0.1, alpha=0.75)
BROWN_BOTTLE = mat("SCI | amber bottle", (0.35, 0.16, 0.04), 0.2)
PT_COLORS = [mat("SCI | table metals", (0.98, 0.78, 0.55), 0.6), mat("SCI | table nonmetals", (0.65, 0.90, 0.60), 0.6),
             mat("SCI | table noble gases", (0.70, 0.75, 0.98), 0.6), mat("SCI | table transition", (0.98, 0.62, 0.62), 0.6),
             mat("SCI | table metalloids", (0.95, 0.90, 0.55), 0.6)]
POSTER_BG = mat("SCI | poster paper", (0.97, 0.97, 0.95), 0.7)

RACK = mat("DC | rack cabinet black", (0.035, 0.038, 0.045), 0.45, 0.3)
RACK_MESH = mat("DC | rack perforated door", (0.09, 0.10, 0.11), 0.6, 0.4)
SERVER_FACE = mat("DC | server bezel silver", (0.55, 0.57, 0.60), 0.35, 0.6)
SERVER_DARK = mat("DC | server bezel graphite", (0.16, 0.17, 0.19), 0.4, 0.4)
LED_GREEN = mat("DC | LED green", (0.1, 0.95, 0.3), 0.3, emit=(0.1, 1.0, 0.3), emit_strength=6.0)
LED_BLUE = mat("DC | LED blue", (0.1, 0.4, 1.0), 0.3, emit=(0.15, 0.45, 1.0), emit_strength=6.0)
LED_AMBER = mat("DC | LED amber", (1.0, 0.6, 0.1), 0.3, emit=(1.0, 0.55, 0.05), emit_strength=6.0)
PORT = mat("DC | network port", (0.02, 0.02, 0.025), 0.6)
CABLE_BLUE = mat("DC | patch cable blue", (0.05, 0.25, 0.75), 0.5)
CABLE_YELLOW = mat("DC | patch cable yellow", (0.95, 0.75, 0.05), 0.5)
TRAY = mat("DC | cable tray yellow", (0.90, 0.70, 0.05), 0.45, 0.3)
TILE = mat("DC | raised floor tile", (0.70, 0.72, 0.72), 0.55)
TILE_PERF = mat("DC | perforated tile", (0.38, 0.40, 0.42), 0.6, 0.5)
TILE_LINE = mat("DC | tile gap", (0.18, 0.19, 0.2), 0.7)
CRAC = mat("DC | precision AC white", (0.90, 0.91, 0.90), 0.45)
VENT = mat("DC | vent grille", (0.25, 0.27, 0.29), 0.6, 0.4)
UPS = mat("DC | UPS charcoal", (0.13, 0.14, 0.16), 0.45, 0.2)
SCREEN_ON = mat("DC | screen dashboard", (0.02, 0.10, 0.18), 0.2, emit=(0.05, 0.35, 0.65), emit_strength=1.6)
SCREEN_MAP = mat("DC | screen network map", (0.02, 0.12, 0.08), 0.2, emit=(0.08, 0.6, 0.35), emit_strength=1.4)
SCREEN_ALERT = mat("DC | screen alert panel", (0.18, 0.06, 0.02), 0.2, emit=(0.85, 0.35, 0.05), emit_strength=1.3)
SCREEN_GRAPH = mat("DC | screen graph", (0.05, 0.05, 0.12), 0.2, emit=(0.45, 0.30, 0.95), emit_strength=1.3)
DESK_TOP = mat("DC | desk laminate grey", (0.55, 0.56, 0.55), 0.5)
DESK_FRAME = mat("DC | desk frame graphite", (0.15, 0.16, 0.17), 0.4, 0.5)
CHAIR = mat("DC | chair mesh black", (0.05, 0.05, 0.06), 0.7)
CABINET = mat("DC | filing cabinet grey", (0.62, 0.64, 0.66), 0.4, 0.4)
FRAME = mat("DC | partition aluminium", (0.55, 0.57, 0.60), 0.3, 0.75)
NAVY = mat("DC | sign navy", (0.03, 0.09, 0.16), 0.4)
SIGN_TEXT = mat("DC | sign white", (0.95, 0.96, 0.96), 0.4)
FM200 = mat("DC | FM-200 cylinder red", (0.75, 0.05, 0.04), 0.35, 0.3)
PIPE = mat("DC | suppression pipe", (0.70, 0.12, 0.10), 0.4, 0.4)


# ============================================================ room bounds (Blender metres)

# Science classroom (old "background classroom"): inner faces of its walls.
SX0, SX1 = -21.20, -9.27
SY0, SY1 = -9.75, 9.74
SDOOR_Y = 7.83            # corridor door centre on the east wall (x = -9.19)
# Server room.
RX0, RX1 = -6.00, 6.00
RY0, RY1 = 30.60, 44.17
RDOOR_Y = 35.49           # corridor door centre on the west wall (x = -6.075)
SPLIT_Y = 37.00           # glass partition between Data Center (south) and Server (north) zones
GDOOR_X0, GDOOR_X1 = 3.20, 4.30   # glass door opening in the partition


# ============================================================ science lab

def build_science_lab(c):
    furn = collection("15.1 | Lab benches and stools", c)
    wall = collection("15.2 | Wall equipment and safety", c)
    small = collection("15.3 | Glassware and instruments", c)

    # --- student lab island: 2.4 x 1.2 m, epoxy top, central service spine, sink at one end
    b = Item("SCI_LabBench_Island")
    b.box((2.36, 1.16, 0.84), (0, 0, 0.42), LAB_CAB)                 # carcass
    for sx in (-1, 1):
        for i in range(3):
            b.box((0.70, 0.01, 0.62), ((i - 1) * 0.76, sx * 0.585, 0.43), LAB_DOOR)   # doors both sides
            b.box((0.12, 0.02, 0.015), ((i - 1) * 0.76, sx * 0.595, 0.70), STEEL)     # handles
    b.box((2.44, 1.24, 0.035), (0, 0, 0.8575), EPOXY)                 # worktop
    b.box((1.70, 0.16, 0.32), (-0.25, 0, 1.035), LAB_CAB)            # service spine
    b.box((1.70, 0.18, 0.02), (-0.25, 0, 1.205), EPOXY)
    for i in range(4):                                                # gas taps both sides
        x = -0.95 + i * 0.47
        for sx in (-1, 1):
            b.cyl(0.012, 0.09, (x, sx * 0.12, 1.0), CHROME, rx=math.pi / 2)
            b.box((0.03, 0.02, 0.05), (x, sx * 0.165, 1.0), GAS_TAP)
        b.box((0.06, 0.012, 0.09), (x + 0.2, 0.086, 1.10), WHITE)   # power socket plates
        b.box((0.06, 0.012, 0.09), (x + 0.2, -0.086, 1.10), WHITE)
    b.box((0.42, 0.34, 0.02), (0.92, 0, 0.871), STEEL)               # sink rim
    b.box((0.36, 0.28, 0.16), (0.92, 0, 0.80), DARK)                 # basin (dark inside)
    b.cyl(0.012, 0.32, (0.92, -0.15, 1.03), CHROME)                  # swan-neck tap
    b.cyl(0.010, 0.16, (0.92, -0.08, 1.18), CHROME, rx=math.pi / 2)
    bench = b.build(furn, collide=True, note="Science lab island: sink, gas taps, sockets")

    # --- stool
    s = Item("SCI_LabStool")
    s.cyl(0.17, 0.05, (0, 0, 0.66), STOOL_SEAT, seg=20)
    s.cyl(0.025, 0.62, (0, 0, 0.33), STEEL)
    s.cyl(0.14, 0.012, (0, 0, 0.26), STEEL, seg=16)                  # foot ring
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        s.box((0.03, 0.03, 0.66), (math.cos(ang) * 0.12, math.sin(ang) * 0.12, 0.31), STEEL)
    stool = s.build(furn, collide=False)

    cols = (-17.55, -12.75)
    rows = (3.30, -0.70, -4.70)
    n = 0
    for y in rows:
        for x in cols:
            n += 1
            o = bench if n == 1 else dup(bench, "SCI_LabBench_Island", furn, (0, 0, 0))
            o.location = (x, y, 0)
            o.name = "SCI_LabBench_%d" % n
            for k, (dx, dy) in enumerate([(-0.75, 0.95), (0.35, 0.95), (-0.75, -0.95), (0.35, -0.95)]):
                st = stool if (n == 1 and k == 0) else dup(stool, "SCI_LabStool", furn, (0, 0, 0))
                st.location = (x + dx, y + dy, 0)
                st.name = "SCI_LabStool_%d_%d" % (n, k + 1)
    stool.location = (cols[0] - 0.75, rows[0] + 0.95, 0)

    # --- teacher demonstration bench (front, facing the class)
    t = Item("SCI_TeacherDemoBench")
    t.box((3.0, 0.85, 0.86), (0, 0, 0.43), LAB_CAB)
    for i in range(4):
        t.box((0.68, 0.01, 0.62), (-1.1 + i * 0.73, -0.43, 0.43), LAB_DOOR)
    t.box((3.08, 0.92, 0.04), (0, 0, 0.88), EPOXY)
    t.box((0.45, 0.36, 0.02), (1.15, 0.05, 0.895), STEEL)
    t.box((0.38, 0.30, 0.16), (1.15, 0.05, 0.82), DARK)
    t.cyl(0.012, 0.32, (1.15, 0.22, 1.05), CHROME)
    t.cyl(0.010, 0.16, (1.15, 0.15, 1.2), CHROME, rx=math.pi / 2)
    for i in range(2):
        t.cyl(0.012, 0.08, (-0.6 + i * 0.4, 0.38, 0.95), CHROME)
        t.box((0.03, 0.02, 0.05), (-0.6 + i * 0.4, 0.38, 1.0), GAS_TAP)
    # laptop + document camera on the bench
    t.box((0.34, 0.24, 0.02), (-0.9, -0.05, 0.91), DARK)
    t.box((0.34, 0.015, 0.23), (-0.9, 0.07, 1.03), DARK, rx=-0.25)
    t.box((0.30, 0.004, 0.19), (-0.9, 0.06, 1.03), SCREEN_ON, rx=-0.25)
    t.build(furn, loc=(-15.2, 7.45, 0), rz=math.pi, collide=True, note="Teacher demonstration bench")

    teacher_chair = Item("SCI_TeacherChair")
    teacher_chair.cyl(0.22, 0.06, (0, 0, 0.48), DARK, seg=20)
    teacher_chair.box((0.42, 0.05, 0.45), (0, 0.2, 0.78), DARK, rx=-0.12)
    teacher_chair.cyl(0.03, 0.42, (0, 0, 0.26), STEEL)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        teacher_chair.box((0.30, 0.04, 0.03), (math.cos(ang) * 0.15, math.sin(ang) * 0.15, 0.05), DARK, rz=ang)
    teacher_chair.build(furn, loc=(-14.2, 8.55, 0), rz=math.pi)

    # --- whiteboard on the front (north) wall + projector screen box
    wb = Item("SCI_Whiteboard")
    wb.box((4.2, 0.03, 1.25), (0, 0, 0), BOARD)
    wb.box((4.28, 0.05, 0.04), (0, -0.01, 0.645), BOARD_FRAME)
    wb.box((4.28, 0.05, 0.04), (0, -0.01, -0.645), BOARD_FRAME)
    wb.box((0.04, 0.05, 1.33), (2.14, -0.01, 0), BOARD_FRAME)
    wb.box((0.04, 0.05, 1.33), (-2.14, -0.01, 0), BOARD_FRAME)
    wb.box((4.0, 0.12, 0.03), (0, -0.07, -0.66), BOARD_FRAME)        # pen tray
    wb.box((4.4, 0.10, 0.10), (0, -0.04, 1.03), WHITE)               # roll-down screen box
    wb.build(wall, loc=(-15.2, SY1 - 0.02, 1.55))
    text("SCI_Whiteboard_Text1", "การทดลองที่ 3: การไทเทรตกรด-เบส", wall, (-15.6, SY1 - 0.045, 1.85), 0.13, INK, rot=(math.pi / 2, 0, 0))
    text("SCI_Whiteboard_Text2", "pH = -log[H+]    สวมแว่นตานิรภัยทุกครั้ง", wall, (-15.6, SY1 - 0.045, 1.55), 0.11, INK, rot=(math.pi / 2, 0, 0))
    text("SCI_Room_Sign_Board", "ห้องปฏิบัติการวิทยาศาสตร์", wall, (-15.2, SY1 - 0.045, 2.45), 0.16, SIGN_GREEN, rot=(math.pi / 2, 0, 0))

    # --- fume hood (west wall, front corner)
    h = Item("SCI_FumeHood")
    h.box((1.5, 0.8, 0.86), (0, 0, 0.43), LAB_CAB)
    h.box((1.56, 0.86, 0.04), (0, 0, 0.88), EPOXY)
    h.box((1.5, 0.05, 1.3), (0, 0.38, 1.55), LAB_CAB)               # back
    h.box((0.06, 0.8, 1.3), (-0.72, 0, 1.55), LAB_CAB)
    h.box((0.06, 0.8, 1.3), (0.72, 0, 1.55), LAB_CAB)
    h.box((1.5, 0.8, 0.5), (0, 0, 2.45), LAB_CAB)                   # top with airflow
    h.box((1.38, 0.02, 0.75), (0, -0.38, 1.55), GLASS)               # sash glass
    h.box((1.40, 0.04, 0.05), (0, -0.39, 1.18), STEEL)               # sash handle
    h.box((0.3, 0.02, 0.12), (0.5, -0.41, 2.35), SCREEN_MAP)         # airflow monitor
    h.cyl(0.18, 0.5, (0, 0.1, 2.95), STEEL, seg=20)                  # exhaust duct
    h.box((0.03, 0.03, 0.12), (-0.5, -0.38, 0.75), GAS_TAP)
    h.build(furn, loc=(SX0 + 0.42, 5.4, 0), rz=math.pi / 2, collide=True, note="Fume hood with sash")
    text("SCI_FumeHood_Label", "ตู้ดูดควัน (Fume Hood)", wall, (SX0 + 0.82, 5.4, 2.48), 0.08, DARK, rot=(math.pi / 2, 0, math.pi / 2))

    # --- wall cabinets with glass doors + base cupboards on the back (south) wall
    wc = Item("SCI_GlasswareCabinet")
    wc.box((1.0, 0.42, 2.0), (0, 0, 1.0), LAB_CAB)
    wc.box((0.46, 0.02, 1.0), (-0.24, -0.215, 1.45), GLASS)
    wc.box((0.46, 0.02, 1.0), (0.24, -0.215, 1.45), GLASS)
    wc.box((0.92, 0.02, 0.8), (0, -0.215, 0.45), LAB_DOOR)
    for z in (1.05, 1.45, 1.85):
        wc.box((0.94, 0.38, 0.015), (0, 0, z), WHITE)
    for z in (1.05, 1.45, 1.85):                                     # beakers / flasks on shelves
        for i in range(5):
            x = -0.36 + i * 0.18
            if i % 2:
                wc.cyl(0.05, 0.13, (x, -0.05, z + 0.075), GLASSWARE, seg=12)
            else:
                wc.cyl(0.07, 0.15, (x, -0.05, z + 0.085), GLASSWARE, r2=0.02, seg=12)
    cab = wc.build(furn, collide=True, note="Glassware cabinet")
    cab.location = (-19.6, SY0 + 0.23, 0)
    cab.rotation_euler.z = math.pi
    for i, x in enumerate((-18.5, -17.4, -16.3)):
        dup(cab, "SCI_GlasswareCabinet_%d" % (i + 2), furn, (x, SY0 + 0.23, 0), math.pi)

    # --- chemical storage cabinet (yellow, flammable) + acid cabinet (blue)
    for name, color, label, x in (("SCI_ChemCabinet_Flammable", SIGN_YELLOW, "FLAMMABLE", -14.6), ("SCI_ChemCabinet_Corrosive", mat("SCI | acid cabinet blue", (0.12, 0.35, 0.75), 0.45), "CORROSIVE", -13.6)):
        k = Item(name)
        k.box((0.9, 0.46, 1.65), (0, 0, 0.825), color)
        k.box((0.02, 0.48, 1.55), (0, 0, 0.83), DARK)                # door split
        k.box((0.3, 0.012, 0.22), (0, -0.236, 1.3), SIGN_RED)       # hazard label
        k.box((0.04, 0.03, 0.18), (0.08, -0.24, 0.9), STEEL)
        k.build(furn, loc=(x, SY0 + 0.25, 0), rz=math.pi, collide=True, note="Chemical storage cabinet")
        text(name + "_Label", label, wall, (x, SY0 + 0.505, 1.3), 0.06, WHITE, rot=(math.pi / 2, 0, math.pi))

    # --- side counter with sink, balance and drying rack along the back wall (east part)
    sc = Item("SCI_SideCounter")
    sc.box((3.4, 0.62, 0.86), (0, 0, 0.43), LAB_CAB)
    sc.box((3.44, 0.66, 0.035), (0, 0, 0.8775), EPOXY)
    sc.box((0.5, 0.4, 0.02), (1.2, 0, 0.89), STEEL)
    sc.box((0.44, 0.34, 0.16), (1.2, 0, 0.82), DARK)
    sc.cyl(0.012, 0.32, (1.2, 0.2, 1.05), CHROME)
    sc.box((0.5, 0.05, 0.7), (1.2, 0.28, 1.25), STEEL)               # drying rack
    for i in range(6):
        sc.cyl(0.006, 0.18, (1.0 + i * 0.08, 0.22, 1.2), STEEL, rx=0.6)
    sc.box((0.32, 0.30, 0.10), (-0.6, 0, 0.945), WHITE)              # analytical balance
    sc.box((0.22, 0.22, 0.20), (-0.6, 0.02, 1.09), GLASSWARE)
    sc.box((0.12, 0.01, 0.04), (-0.6, -0.15, 0.95), SCREEN_MAP)
    sc.box((0.4, 0.3, 0.3), (-1.3, 0, 1.05), STEEL)                  # incubator / oven
    sc.box((0.3, 0.01, 0.2), (-1.3, -0.15, 1.05), DARK)
    sc.build(furn, loc=(-11.3, SY0 + 0.33, 0), rz=math.pi, collide=True, note="Side counter: sink, balance, oven")

    # --- reagent shelves on the west wall
    rs = Item("SCI_ReagentShelf")
    for z in (1.25, 1.6, 1.95):
        rs.box((0.30, 1.8, 0.025), (0, 0, z), WOOD)
        for i in range(9):
            y = -0.8 + i * 0.2
            m = BROWN_BOTTLE if i % 3 else GLASSWARE
            rs.cyl(0.04, 0.16, (0, y, z + 0.09), m, seg=10)
            rs.cyl(0.018, 0.03, (0, y, z + 0.185), DARK, seg=8)
    rs.box((0.05, 0.03, 0.8), (-0.13, 0.85, 1.6), WOOD)
    rs.box((0.05, 0.03, 0.8), (-0.13, -0.85, 1.6), WOOD)
    rs.build(wall, loc=(SX0 + 0.16, 0.6, 0))

    # --- periodic table poster (one mesh, coloured cells)
    pt = Item("SCI_PeriodicTable_Poster")
    pt.box((2.0, 0.01, 1.2), (0, 0, 0), POSTER_BG)
    layout = ["1.................2", "34..........567899", "34..........567899",
              "4444444444445678 9", "4444444444445678 9", "44444444444456789", "44444444444456789"]
    cw, chh = 0.105, 0.13
    for r, line in enumerate(layout):
        for col, ch in enumerate(line[:18]):
            if ch in ". ":
                continue
            kind = {"1": 1, "2": 2, "3": 0, "4": 0, "5": 4, "6": 1, "7": 1, "8": 1, "9": 2}[ch]
            if r >= 3 and 2 <= col <= 11:
                kind = 3
            pt.box((cw * 0.9, 0.012, chh * 0.88), (-0.9 + col * cw, -0.006, 0.42 - r * chh), PT_COLORS[kind])
    for col in range(14):                                            # lanthanides / actinides rows
        for r in range(2):
            pt.box((cw * 0.9, 0.012, chh * 0.88), (-0.6 + col * cw, -0.006, -0.52 - r * chh * 0.9), PT_COLORS[3])
    pt.build(wall, loc=(SX0 + 0.012, -2.6, 1.75), rz=math.pi / 2)
    text("SCI_PeriodicTable_Title", "ตารางธาตุ (Periodic Table)", wall, (SX0 + 0.03, -2.6, 2.48), 0.1, DARK, rot=(math.pi / 2, 0, math.pi / 2))

    # --- safety: emergency shower + eyewash (north-west corner), fire extinguisher + blanket by the door, first aid
    sh = Item("SCI_SafetyShower_Eyewash")
    sh.cyl(0.03, 2.3, (0, 0, 1.15), mat("SCI | safety green pipe", (0.1, 0.6, 0.25), 0.4, 0.3))
    sh.cyl(0.03, 0.55, (0.27, 0, 2.28), STEEL, rx=0, ry=math.pi / 2)
    sh.cyl(0.14, 0.06, (0.52, 0, 2.22), STEEL, r2=0.05, seg=20)
    sh.cyl(0.1, 0.05, (0.3, 0, 1.0), SIGN_YELLOW, seg=16)            # eyewash bowl
    sh.box((0.05, 0.3, 0.02), (0.05, 0, 1.6), SIGN_GREEN)            # pull handle
    sh.build(furn, loc=(SX0 + 0.12, SY1 - 0.45, 0))
    for name, body, loc, rot in (("SCI_Sign_SafetyShower", "ฝักบัวฉุกเฉิน / ที่ล้างตา", (SX0 + 0.03, SY1 - 0.45, 2.55), (math.pi / 2, 0, math.pi / 2)),):
        text(name, body, wall, loc, 0.08, SIGN_GREEN, rot=rot)

    fe = Item("SCI_FireExtinguisher")
    fe.cyl(0.08, 0.5, (0, 0, 0.25), SIGN_RED, seg=16)
    fe.cyl(0.03, 0.08, (0, 0, 0.54), DARK)
    fe.box((0.12, 0.03, 0.03), (0.04, 0, 0.58), DARK)
    fe.box((0.03, 0.03, 0.3), (-0.09, 0, 0.3), DARK)
    ext = fe.build(wall, loc=(-9.38, 9.3, 0.55), rz=math.pi)
    fb = Item("SCI_FireBlanket")
    fb.box((0.28, 0.08, 0.36), (0, 0, 0), SIGN_RED)
    fb.box((0.2, 0.09, 0.05), (0, 0, -0.14), WHITE)
    fb.build(wall, loc=(-9.33, 6.6, 1.55), rz=math.pi / 2)
    fa = Item("SCI_FirstAid")
    fa.box((0.4, 0.14, 0.32), (0, 0, 0), WHITE)
    fa.box((0.16, 0.15, 0.05), (0, 0, 0), SIGN_GREEN)
    fa.box((0.05, 0.15, 0.16), (0, 0, 0), SIGN_GREEN)
    fa.build(wall, loc=(-10.5, SY1 - 0.08, 1.5))

    # --- microscopes + glassware on the benches (linked duplicates)
    mic = Item("SCI_Microscope")
    mic.box((0.16, 0.2, 0.03), (0, 0, 0.015), DARK)
    mic.box((0.04, 0.06, 0.3), (0, 0.07, 0.17), DARK, rx=0.15)
    mic.cyl(0.02, 0.16, (0, 0.0, 0.33), DARK, rx=-0.6)
    mic.box((0.12, 0.12, 0.012), (0, 0, 0.14), DARK)
    mic.cyl(0.035, 0.04, (0, 0.03, 0.25), CHROME)
    mic = mic.build(small)
    flask = Item("SCI_Flask_Set")
    flask.cyl(0.06, 0.13, (0, 0, 0.065), GLASSWARE, r2=0.018, seg=14)
    flask.cyl(0.05, 0.06, (0, 0, 0.03), LIQ_BLUE, r2=0.03, seg=14)
    flask.cyl(0.04, 0.11, (0.14, 0.02, 0.055), GLASSWARE, seg=14)
    flask.cyl(0.037, 0.05, (0.14, 0.02, 0.025), LIQ_GREEN, seg=14)
    flask.box((0.16, 0.05, 0.06), (-0.16, 0.02, 0.03), WOOD)         # test tube rack
    for i in range(5):
        flask.cyl(0.009, 0.12, (-0.22 + i * 0.03, 0.02, 0.08), GLASSWARE if i % 2 else LIQ_ORANGE, seg=8)
    flask.cyl(0.03, 0.12, (0.28, -0.05, 0.06), STEEL, seg=12)       # bunsen burner
    flask.cyl(0.05, 0.015, (0.28, -0.05, 0.007), DARK, seg=12)
    flask = flask.build(small)
    n = 0
    for y in rows:
        for x in cols:
            n += 1
            m = mic if n == 1 else dup(mic, "SCI_Microscope", small, (0, 0, 0))
            m.name = "SCI_Microscope_%d" % n
            m.location = (x - 0.85, y + 0.35, 0.875)
            f = flask if n == 1 else dup(flask, "SCI_Flask_Set", small, (0, 0, 0))
            f.name = "SCI_Glassware_%d" % n
            f.location = (x + 0.2, y - 0.38, 0.875)
    # demo set on the teacher bench
    dup(flask, "SCI_Glassware_Demo", small, (-15.6, 7.45, 0.9))

    # --- room sign beside the corridor door (replaces "ห้องเรียนประกอบฉาก")
    return ext


def retitle_science_room():
    """The plan names this room ห้องเรียนวิทยาศาสตร์ — rebuild the door sign text."""
    navy = bpy.data.materials.get("MAP | Sign white") or SIGN_TEXT
    for old in ("BackgroundClass_TH", "BackgroundClass_EN"):
        o = bpy.data.objects.get(old)
        if o:
            loc = o.location.copy()
            rot = o.rotation_euler.copy()
            coll = o.users_collection[0]
            size = 0.12 if old.endswith("TH") else 0.062
            body = "ห้องเรียนวิทยาศาสตร์" if old.endswith("TH") else "SCIENCE CLASSROOM"
            bpy.data.objects.remove(o, do_unlink=True)
            text(old, body, coll, loc, size, navy, rot=rot)
    r = bpy.data.objects.get("Room_BackgroundClass")
    if r:
        r["label_th"] = "ห้องเรียนวิทยาศาสตร์"


# ============================================================ server room

def build_rack(name, coll, with_door_glass=False):
    """42U rack 0.6 x 1.07 x 2.0 m, front facing -Y (local), filled with servers."""
    r = Item(name)
    r.box((0.60, 1.07, 2.00), (0, 0, 1.0), RACK)
    r.box((0.56, 0.01, 1.86), (0, -0.536, 1.0), PORT)                # dark interior behind the front
    r.box((0.60, 0.02, 0.06), (0, -0.54, 1.97), RACK)
    r.box((0.60, 0.02, 0.06), (0, -0.54, 0.05), RACK)
    r.box((0.03, 0.02, 1.9), (-0.285, -0.54, 1.0), RACK)
    r.box((0.03, 0.02, 1.9), (0.285, -0.54, 1.0), RACK)
    z = 0.14
    pattern = ["2u", "1u", "1u", "2u", "sw", "pp", "2u", "2u", "1u", "1u", "2u", "4u", "2u", "1u", "1u", "2u", "sw", "pp"]
    for kind in pattern:
        hgt = {"1u": 0.044, "2u": 0.088, "4u": 0.176, "sw": 0.044, "pp": 0.044}[kind]
        if z + hgt > 1.92:
            break
        face = SERVER_DARK if kind in ("sw", "pp", "4u") else SERVER_FACE
        r.box((0.52, 0.02, hgt - 0.004), (0, -0.552, z + hgt / 2), face)
        if kind in ("sw", "pp"):
            for p in range(12):
                r.box((0.014, 0.006, 0.012), (-0.2 + p * 0.032, -0.565, z + hgt / 2), PORT)
            for p in range(0, 12, 2):
                r.box((0.006, 0.004, 0.006), (-0.2 + p * 0.032, -0.568, z + hgt / 2 + 0.012), LED_GREEN)
            if kind == "pp":   # patch cables hanging to the side
                r.box((0.36, 0.012, 0.012), (-0.02, -0.57, z + 0.004), CABLE_BLUE)
        else:
            for d in range(4 if hgt > 0.05 else 3):
                r.box((0.08, 0.006, hgt * 0.6), (-0.17 + d * 0.09, -0.565, z + hgt / 2), SERVER_DARK)
            r.box((0.008, 0.004, 0.008), (0.21, -0.566, z + hgt * 0.7), LED_BLUE if kind == "4u" else LED_GREEN)
            r.box((0.008, 0.004, 0.008), (0.23, -0.566, z + hgt * 0.7), LED_GREEN)
            if kind == "2u":
                r.box((0.008, 0.004, 0.008), (0.23, -0.566, z + hgt * 0.3), LED_AMBER)
        z += hgt + 0.004
    # rear: vertical PDUs and cable bundles
    r.box((0.05, 0.02, 1.7), (-0.22, 0.54, 1.0), SERVER_DARK)
    r.box((0.05, 0.02, 1.7), (0.22, 0.54, 1.0), SERVER_DARK)
    r.box((0.04, 0.03, 1.6), (-0.12, 0.53, 1.05), CABLE_BLUE)
    r.box((0.04, 0.03, 1.6), (0.12, 0.53, 1.05), CABLE_YELLOW)
    r.box((0.56, 0.012, 1.86), (0, 0.537, 1.0), RACK_MESH)          # rear perforated door
    if with_door_glass:
        r.box((0.56, 0.01, 1.86), (0, -0.575, 1.0), GLASS)
    return r


def build_server_room(c):
    dc = collection("16.1 | Data Center zone - operators", c)
    sv = collection("16.2 | Server zone - racks and plant", c)
    shell = collection("16.3 | Glass partition, floor and trays", c)

    # ---------- glass partition with access door
    posts = [RX0, -4.0, -2.0, 0.0, 2.0, GDOOR_X0, GDOOR_X1, RX1]
    for i in range(len(posts) - 1):
        a, b = posts[i], posts[i + 1]
        if (a, b) == (GDOOR_X0, GDOOR_X1):
            continue
        w = b - a
        p = Item("Server_Glass_Partition_Panel_%d" % (i + 1))
        p.box((w, 0.012, 2.4), (0, 0, 1.4), GLASS)
        p.box((w, 0.06, 0.2), (0, 0, 0.1), FRAME)                    # base rail
        p.box((w, 0.06, 0.05), (0, 0, 2.62), FRAME)
        p.box((w, 0.06, 0.6), (0, 0, 2.95), FRAME)                   # bulkhead to ceiling
        p.box((w, 0.014, 0.08), (0, 0, 1.35), mat("DC | frosted band", (0.9, 0.92, 0.93), 0.4, alpha=0.6))
        p.build(shell, loc=((a + b) / 2, SPLIT_Y, 0), collide=True)
    for i, x in enumerate(posts):
        p = Item("Server_Partition_Post_%d" % (i + 1))
        p.box((0.06, 0.08, 3.2), (0, 0, 1.6), FRAME)
        p.build(shell, loc=(x, SPLIT_Y, 0))
    hdr = Item("Server_Glass_Door_Header")
    hdr.box((GDOOR_X1 - GDOOR_X0, 0.08, 1.0), (0, 0, 2.7), FRAME)
    hdr.build(shell, loc=((GDOOR_X0 + GDOOR_X1) / 2, SPLIT_Y, 0))
    # sliding glass leaf parked open (behind panel 6) + handle
    leaf = Item("Server_Glass_Sliding_Door")
    leaf.box((1.05, 0.02, 2.15), (0, 0, 1.1), GLASS)
    leaf.box((1.05, 0.03, 0.04), (0, 0, 0.04), FRAME)
    leaf.box((1.05, 0.03, 0.04), (0, 0, 2.17), FRAME)
    leaf.box((0.03, 0.05, 0.6), (-0.45, -0.03, 1.05), STEEL)
    leaf.build(shell, loc=(GDOOR_X0 - 0.55, SPLIT_Y + 0.06, 0))
    # card reader + biometric, signs
    cr = Item("Server_Access_Card_Reader")
    cr.box((0.09, 0.03, 0.15), (0, 0, 0), DARK)
    cr.box((0.05, 0.01, 0.03), (0, -0.02, 0.04), LED_GREEN)
    cr.box((0.06, 0.01, 0.06), (0, -0.02, -0.03), SCREEN_ON)
    cr.build(shell, loc=(GDOOR_X1 + 0.2, SPLIT_Y - 0.05, 1.25))
    sign = Item("Server_Zone_Sign")
    sign.box((1.4, 0.015, 0.34), (0, 0, 0), NAVY)
    sign.build(shell, loc=((GDOOR_X0 + GDOOR_X1) / 2, SPLIT_Y - 0.05, 2.4))
    text("Server_Zone_Sign_TH", "SERVER ZONE - เฉพาะเจ้าหน้าที่", shell, ((GDOOR_X0 + GDOOR_X1) / 2, SPLIT_Y - 0.06, 2.4), 0.09, SIGN_TEXT, rot=(math.pi / 2, 0, 0))
    text("Server_Zone_Rule", "ห้ามนำอาหารและเครื่องดื่มเข้า", shell, (GDOOR_X1 + 0.75, SPLIT_Y - 0.03, 1.75), 0.06, SIGN_RED, rot=(math.pi / 2, 0, 0))

    # ---------- raised floor tiles (server zone) — one mesh, perforated tiles in the cold aisle
    rf = Item("Server_Raised_Floor")
    rf.box((RX1 - RX0, RY1 - SPLIT_Y, 0.03), (0, 0, 0.015), TILE_LINE)
    t = 0.6
    nx = int((RX1 - RX0) / t)
    ny = int((RY1 - SPLIT_Y - 0.05) / t)
    cold_y0, cold_y1 = 39.70, 41.40
    for i in range(nx):
        for j in range(ny):
            x = RX0 + 0.3 + i * t
            y = SPLIT_Y + 0.35 + j * t
            m = TILE_PERF if cold_y0 < y < cold_y1 and -5.4 < x < 1.8 else TILE
            rf.box((t - 0.012, t - 0.012, 0.012), (x - (RX0 + RX1) / 2, y - (SPLIT_Y + RY1) / 2, 0.034), m)
    rf.build(shell, loc=((RX0 + RX1) / 2, (SPLIT_Y + RY1) / 2, 0))

    # ---------- racks: two rows, fronts facing the cold aisle
    rack = build_rack("DC_Rack_Template", sv).build(sv, collide=True, note="42U rack with servers, switches and patch panels")
    labels = []
    xs = [-5.4 + i * 0.6 for i in range(10)]          # -5.4 .. 0.0 (rack centres -5.1 .. 0.3)
    k = 0
    for row, (y, rz) in enumerate(((39.15, math.pi), (41.95, 0.0))):
        for i, x in enumerate(xs):
            k += 1
            o = rack if k == 1 else dup(rack, "DC_Rack", sv, (0, 0, 0))
            o.name = "DC_Rack_%s%02d" % ("AB"[row], i + 1)
            o.location = (x + 0.3, y, 0.045)
            o.rotation_euler.z = rz
            labels.append((o.name, x + 0.3, y, rz))
    for name, x, y, rz in labels:
        front = -1 if rz == 0 else 1
        text(name + "_Label", name[3:].replace("_", " "), sv, (x, y + front * 0.585, 2.12), 0.05, SIGN_TEXT,
             rot=(math.pi / 2, 0, 0 if front < 0 else math.pi))
    # aisle containment end panel + row end caps
    for row_y in (39.15, 41.95):
        cap = Item("DC_Row_End_Panel")
        cap.box((0.05, 1.07, 2.0), (0, 0, 1.0), RACK)
        cap.build(sv, loc=(xs[-1] + 0.63, row_y, 0.045), collide=False)
    cold = Item("DC_Cold_Aisle_Door")
    cold.box((0.04, 1.7, 2.05), (0, 0, 1.06), GLASS)
    cold.box((0.06, 1.72, 0.06), (0, 0, 2.09), FRAME)
    cold.box((0.05, 0.04, 0.4), (0.03, 0.6, 1.05), STEEL)
    cold.build(sv, loc=(xs[-1] + 0.65, 40.55, 0.045))
    roof = Item("DC_Cold_Aisle_Top_Cover")
    roof.box((6.05, 1.70, 0.02), (0, 0, 0), GLASS)
    roof.build(sv, loc=((xs[0] + xs[-1]) / 2 + 0.3, 40.55, 2.09))

    # ---------- overhead cable trays (ladder type) above each row + feeder to the wall
    def tray(name, length, loc, rz):
        tr = Item(name)
        tr.box((length, 0.025, 0.08), (0, -0.15, 0), TRAY)
        tr.box((length, 0.025, 0.08), (0, 0.15, 0), TRAY)
        n = int(length / 0.3)
        for i in range(n):
            tr.box((0.025, 0.3, 0.012), (-length / 2 + 0.15 + i * 0.3, 0, -0.03), TRAY)
        tr.box((length * 0.95, 0.16, 0.05), (0, 0, 0.0), CABLE_BLUE)   # cable bundle
        for i in range(int(length / 1.2) + 1):
            tr.cyl(0.008, 0.55, (-length / 2 + 0.1 + i * 1.2, -0.17, 0.3), STEEL)
            tr.cyl(0.008, 0.55, (-length / 2 + 0.1 + i * 1.2, 0.17, 0.3), STEEL)
        tr.build(sv, loc=loc, rz=rz)
    tray("DC_CableTray_RowA", 6.4, (-2.1, 39.15, 2.38), 0)
    tray("DC_CableTray_RowB", 6.4, (-2.1, 41.95, 2.38), 0)
    tray("DC_CableTray_Feeder", 3.6, (1.4, 40.55, 2.38), math.pi / 2)

    # ---------- precision air conditioning (east wall) + UPS / batteries (north wall)
    ac = Item("DC_Precision_AC")
    ac.box((1.8, 0.85, 1.95), (0, 0, 0.975), CRAC)
    for i in range(3):
        ac.box((0.52, 0.01, 1.5), (-0.6 + i * 0.6, -0.43, 1.0), VENT)
    ac.box((0.26, 0.01, 0.16), (0.55, -0.436, 1.72), SCREEN_MAP)
    ac.box((1.8, 0.85, 0.06), (0, 0, 1.98), DARK)
    ac_o = ac.build(sv, collide=True, note="Precision air conditioner (CRAC)")
    ac_o.location = (RX1 - 0.45, 39.3, 0.045)
    ac_o.rotation_euler.z = -math.pi / 2
    dup(ac_o, "DC_Precision_AC_2", sv, (RX1 - 0.45, 42.4, 0.045), -math.pi / 2)

    ups = Item("DC_UPS_Cabinet")
    ups.box((0.6, 0.85, 1.95), (0, 0, 0.975), UPS)
    ups.box((0.18, 0.01, 0.12), (0, -0.426, 1.55), SCREEN_GRAPH)
    for i in range(3):
        ups.box((0.012, 0.01, 0.012), (-0.06 + i * 0.06, -0.428, 1.42), LED_GREEN)
    ups.box((0.5, 0.01, 0.8), (0, -0.428, 0.6), VENT)
    ups_o = ups.build(sv, collide=True, note="UPS cabinet")
    batt = Item("DC_Battery_Cabinet")
    batt.box((0.8, 0.85, 1.95), (0, 0, 0.975), UPS)
    batt.box((0.7, 0.01, 1.7), (0, -0.428, 1.0), RACK_MESH)
    batt_o = batt.build(sv, collide=True, note="UPS battery cabinet")
    for i, (o, x) in enumerate(((ups_o, -5.55), (None, -4.9), (batt_o, -4.1), (None, -3.25))):
        if o is None:
            o = dup(ups_o if i == 1 else batt_o, "DC_UPS_%d" % (i + 1), sv, (0, 0, 0))
        o.location = (x, RY1 - 0.45, 0.045)
        o.rotation_euler.z = math.pi
    # electrical distribution board
    db = Item("DC_Power_Distribution_Board")
    db.box((0.9, 0.25, 1.2), (0, 0, 0), mat("DC | electrical panel grey", (0.72, 0.73, 0.70), 0.5))
    db.box((0.3, 0.012, 0.2), (0, -0.13, 0.35), SIGN_YELLOW)
    db.build(sv, loc=(-1.7, RY1 - 0.15, 1.35), rz=math.pi)

    # ---------- FM-200 fire suppression (north-east corner) + nozzles
    for i in range(2):
        cy = Item("DC_FM200_Cylinder_%d" % (i + 1))
        cy.cyl(0.18, 1.35, (0, 0, 0.675), FM200, seg=20)
        cy.cyl(0.18, 0.25, (0, 0, 1.35), FM200, r2=0.06, seg=20)
        cy.cyl(0.04, 0.15, (0, 0, 1.55), STEEL)
        cy.box((0.12, 0.08, 0.1), (0, 0, 1.66), DARK)
        cy.cyl(0.025, 1.4, (0, 0, 2.38), PIPE)
        cy.build(sv, loc=(RX1 - 0.3 - i * 0.42, RY1 - 0.3, 0.045), collide=(i == 0))
    pipe = Item("DC_FM200_Pipe_Network")
    pipe.cyl(0.025, 5.6, (0, 0, 0), PIPE, ry=math.pi / 2)
    for i in range(4):
        pipe.cyl(0.02, 0.18, (-2.2 + i * 1.5, 0, -0.09), PIPE)
        pipe.cyl(0.04, 0.04, (-2.2 + i * 1.5, 0, -0.19), CHROME)
    pipe.build(sv, loc=(-0.4, 40.55, 3.05))
    panel = Item("DC_Fire_Alarm_Panel")
    panel.box((0.45, 0.12, 0.55), (0, 0, 0), SIGN_RED)
    panel.box((0.25, 0.01, 0.12), (0, -0.065, 0.12), SCREEN_ALERT)
    panel.build(sv, loc=(RX1 - 0.07, 38.0, 1.5), rz=-math.pi / 2)
    text("DC_FM200_Sign", "FM-200 ระบบดับเพลิงอัตโนมัติ", sv, (RX1 - 0.02, RY1 - 1.2, 2.3), 0.07, SIGN_RED, rot=(math.pi / 2, 0, -math.pi / 2))

    # ---------- environment sensors, CCTV, emergency light
    for i, loc in enumerate(((-5.97, 40.5, 1.6), (RX1 - 0.03, 44.0 - 3.4, 1.6))):
        s = Item("DC_Temp_Humidity_Sensor_%d" % (i + 1))
        s.box((0.03, 0.12, 0.12), (0, 0, 0), WHITE)
        s.box((0.01, 0.08, 0.04), (0.015 if i == 0 else -0.015, 0, 0.02), SCREEN_MAP)
        s.build(sv, loc=loc)
    for i, loc in enumerate(((RX0 + 0.25, RY1 - 0.25, 3.05), (RX1 - 0.25, SPLIT_Y + 0.3, 3.05), (RX0 + 0.25, RY0 + 0.25, 3.05))):
        cam = Item("DC_CCTV_Dome_%d" % (i + 1))
        cam.cyl(0.09, 0.03, (0, 0, 0.13), WHITE, seg=16)
        cam.cyl(0.07, 0.07, (0, 0, 0.08), mat("DC | smoked dome", (0.1, 0.1, 0.12), 0.1, alpha=0.7), r2=0.04, seg=16)
        cam.build(sv if i < 2 else dc, loc=loc)

    # ================= Data Center zone (operators)
    # video wall above the NOC desks on the south wall (2 x 3 screens)
    vw = Item("DC_Video_Wall")
    screens = [SCREEN_MAP, SCREEN_ON, SCREEN_GRAPH, SCREEN_ON, SCREEN_ALERT, SCREEN_MAP]
    for r in range(2):
        for col in range(3):
            x = -0.96 + col * 0.96
            z = 0.29 - r * 0.56
            vw.box((0.95, 0.06, 0.55), (x, 0, z), DARK)
            vw.box((0.91, 0.01, 0.51), (x, -0.035, z), screens[r * 3 + col])
            # simple dashboard bars
            for b in range(4):
                vw.box((0.12, 0.004, 0.05 + b * 0.04), (x - 0.3 + b * 0.16, -0.042, z - 0.2 + (0.05 + b * 0.04) / 2), LED_GREEN if (r + col + b) % 3 else LED_AMBER)
    vw.box((2.9, 0.08, 0.06), (0, 0.03, -0.3), DESK_FRAME)
    vw.build(dc, loc=(-2.85, RY0 + 0.05, 2.0), rz=math.pi)
    text("DC_Room_Sign", "DATA CENTER - ศูนย์ควบคุมเครือข่าย", dc, (-2.85, RY0 + 0.03, 2.7), 0.1, NAVY, rot=(math.pi / 2, 0, math.pi))

    # second NOC desk (beside the Godot mission desk at x -3.6) with 2 monitors
    nd = Item("DC_NOC_Desk_2")
    nd.box((1.6, 0.75, 0.04), (0, 0, 0.73), DESK_TOP)
    for sx in (-0.75, 0.75):
        nd.box((0.05, 0.7, 0.71), (sx, 0, 0.355), DESK_FRAME)
    nd.box((1.5, 0.02, 0.4), (0, 0.34, 0.45), DESK_FRAME)
    for i, m in enumerate((SCREEN_ON, SCREEN_MAP)):
        x = -0.32 + i * 0.64
        nd.box((0.56, 0.03, 0.33), (x, 0.18, 1.07), DARK)
        nd.box((0.52, 0.005, 0.29), (x, 0.163, 1.07), m)
        nd.box((0.04, 0.03, 0.2), (x, 0.2, 0.86), DARK)
        nd.box((0.2, 0.15, 0.015), (x, 0.2, 0.757), DARK)
    nd.box((0.44, 0.14, 0.02), (0, -0.12, 0.76), DARK)
    nd.box((0.06, 0.1, 0.025), (0.32, -0.12, 0.762), DARK)
    nd.box((0.2, 0.15, 0.03), (-0.6, -0.1, 0.765), mat("DC | notebook", (0.85, 0.2, 0.15), 0.6))
    nd.build(dc, loc=(-1.75, RY0 + 0.4, 0), rz=math.pi, collide=True, note="Second NOC desk")

    chair = Item("DC_Chair_Template")
    chair.box((0.48, 0.48, 0.07), (0, 0, 0.48), CHAIR)
    chair.box((0.46, 0.06, 0.55), (0, 0.24, 0.82), CHAIR, rx=-0.1)
    chair.box((0.05, 0.3, 0.04), (-0.25, 0.02, 0.66), DARK)
    chair.box((0.05, 0.3, 0.04), (0.25, 0.02, 0.66), DARK)
    chair.cyl(0.03, 0.4, (0, 0, 0.25), STEEL)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        chair.box((0.32, 0.04, 0.03), (math.cos(ang) * 0.16, math.sin(ang) * 0.16, 0.05), DARK, rz=ang)
    ch = chair.build(dc)
    ch.name = "DC_Chair_NOC_1"
    ch.location = (-1.75, RY0 + 1.25, 0)
    ch.rotation_euler.z = math.pi
    dup(ch, "DC_Chair_NOC_2", dc, (-3.05, RY0 + 1.55, 0), math.pi + 0.5)

    # filing cabinet + printer table near the corridor wall (clear of the door swing)
    fc = Item("DC_Filing_Cabinet")
    fc.box((0.47, 0.62, 1.32), (0, 0, 0.66), CABINET)
    for i in range(4):
        fc.box((0.42, 0.01, 0.28), (0, -0.315, 0.2 + i * 0.32), CABINET)
        fc.box((0.12, 0.02, 0.02), (0, -0.325, 0.3 + i * 0.32), STEEL)
    fc.build(dc, loc=(RX0 + 0.35, 31.0, 0), rz=-math.pi / 2, collide=True)
    pt = Item("DC_Printer_Table")
    pt.box((0.8, 0.6, 0.04), (0, 0, 0.72), DESK_TOP)
    for sx in (-0.37, 0.37):
        for sy in (-0.27, 0.27):
            pt.box((0.04, 0.04, 0.7), (sx, sy, 0.35), DESK_FRAME)
    pt.box((0.45, 0.4, 0.32), (0, 0, 0.9), WHITE)                    # printer
    pt.box((0.36, 0.3, 0.02), (0, -0.05, 1.07), DARK)
    pt.box((0.12, 0.01, 0.05), (0.13, -0.205, 0.95), SCREEN_ON)
    pt.box((0.3, 0.22, 0.01), (0, -0.12, 0.775), WHITE)
    pt.build(dc, loc=(RX0 + 0.4, 32.2, 0), rz=-math.pi / 2, collide=True, note="Network printer")

    # repair / staging bench along the glass partition (Data Center side)
    rb = Item("DC_Repair_Bench")
    rb.box((2.2, 0.75, 0.04), (0, 0, 0.9), WOOD)
    for sx in (-1.05, 1.05):
        rb.box((0.06, 0.7, 0.88), (sx, 0, 0.44), DESK_FRAME)
    rb.box((2.1, 0.7, 0.03), (0, 0, 0.18), DESK_FRAME)
    rb.box((2.2, 0.05, 0.9), (0, 0.36, 1.35), mat("DC | pegboard", (0.75, 0.70, 0.60), 0.7))
    for i in range(6):                                               # hanging tools
        rb.box((0.03, 0.02, 0.18 + (i % 3) * 0.05), (-0.8 + i * 0.3, 0.33, 1.4), DARK)
    rb.box((0.44, 0.24, 0.045), (-0.55, -0.05, 0.945), DARK)         # 8-port switch on the bench
    for p in range(8):
        rb.box((0.03, 0.005, 0.018), (-0.7 + p * 0.042, -0.172, 0.945), PORT)
        rb.box((0.006, 0.004, 0.006), (-0.7 + p * 0.042, -0.175, 0.962), LED_GREEN)
    rb.cyl(0.13, 0.08, (0.15, 0.0, 0.96), CABLE_BLUE, seg=20, rx=0)  # cable reel
    rb.cyl(0.05, 0.081, (0.15, 0.0, 0.96), WOOD, seg=12)
    rb.box((0.34, 0.24, 0.02), (0.65, -0.05, 0.93), DARK)            # laptop
    rb.box((0.34, 0.015, 0.23), (0.65, 0.07, 1.05), DARK, rx=-0.25)
    rb.box((0.30, 0.004, 0.19), (0.65, 0.06, 1.05), SCREEN_ON, rx=-0.25)
    rb.box((0.25, 0.18, 0.12), (0.95, -0.1, 0.98), SIGN_RED)        # tool box
    rb.build(dc, loc=(0.4, SPLIT_Y - 0.45, 0), rz=0.0, collide=True, note="Repair / staging bench")

    # whiteboard with a network diagram on the east wall of the Data Center zone
    wb = Item("DC_Whiteboard")
    wb.box((0.03, 2.0, 1.1), (0, 0, 0), BOARD)
    wb.box((0.05, 2.06, 0.04), (0, 0, 0.57), BOARD_FRAME)
    wb.box((0.05, 2.06, 0.04), (0, 0, -0.57), BOARD_FRAME)
    for (y, z) in ((0.0, 0.35), (-0.5, 0.0), (0.5, 0.0), (-0.75, -0.35), (-0.25, -0.35), (0.25, -0.35), (0.75, -0.35)):
        wb.box((0.005, 0.18, 0.1), (-0.018, y, z), INK)
    wb.box((0.005, 0.01, 0.3), (-0.018, 0.0, 0.18), INK)
    wb.box((0.005, 1.0, 0.01), (-0.018, 0.0, 0.03), INK)
    wb.build(dc, loc=(RX1 - 0.02, 33.6, 1.5))
    text("DC_Whiteboard_Title", "Network Topology - Star", dc, (RX1 - 0.04, 33.6, 1.95), 0.07, INK, rot=(math.pi / 2, 0, -math.pi / 2))

    # wall split-type AC + wall clock + emergency light
    wac = Item("DC_Wall_AC")
    wac.box((0.25, 1.0, 0.3), (0, 0, 0), WHITE)
    wac.box((0.01, 0.9, 0.04), (-0.13, 0, -0.1), VENT)
    wac.build(dc, loc=(RX1 - 0.13, 35.5, 2.7))
    clock = Item("DC_Wall_Clock")
    clock.cyl(0.16, 0.04, (0, 0, 0), WHITE, seg=24, rx=math.pi / 2)
    clock.box((0.012, 0.01, 0.1), (0, -0.025, 0.04), DARK)
    clock.box((0.07, 0.01, 0.012), (0.03, -0.025, 0), DARK)
    clock.build(dc, loc=(-2.85, RY0 + 0.03, 2.95), rz=math.pi)
    fe = bpy.data.objects.get("SCI_FireExtinguisher")
    if fe:
        dup(fe, "DC_Fire_Extinguisher_CO2", dc, (RX0 + 0.12, 34.6, 0.55), 0.0)


def main():
    remove_collection(SCI_NAME)
    remove_collection(SRV_NAME)
    sci = collection(SCI_NAME)
    srv = collection(SRV_NAME)
    build_science_lab(sci)
    retitle_science_room()
    build_server_room(srv)
    # Furniture must never hide the Blender room markers used by other scripts.
    built = [o for o in list(sci.all_objects) + list(srv.all_objects) if o.type == "MESH"]
    print("BUILT_OBJECTS", len(built), "COLLIDERS", sum(1 for o in built if o.get("collision") == "box"), flush=True)

    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[args.index("--save") + 1] if "--save" in args else bpy.data.filepath
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    print("SAVED", out, flush=True)


if __name__ == "__main__":
    main()
