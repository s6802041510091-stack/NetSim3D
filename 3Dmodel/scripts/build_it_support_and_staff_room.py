"""Furnish the IT Support room (= Data Center office), the equipment storage room
and the teachers' room (ห้องพักครู).

Run with Blender 5.2 (after build_science_lab_and_server_room.py):
    blender -b 3Dmodel/blend/classroom_shell.blend --python 3Dmodel/scripts/build_it_support_and_staff_room.py -- [--save OUT.blend]

* IT Support / Data Center office (left-top L-shaped room). The team's three
  desks (IT_HeadDesk, IT_PlayerDesk, IT_SpareDesk) with their computers stay
  exactly where they are. This script adds the monitoring wall, on-call board,
  supervisor credenza, bookcases, meeting table, wall network cabinet, repair
  bench, copier, equipment cabinet, signs and plants. The Mission 6 phone sits
  on IT_PlayerDesk (a Godot node in main.tscn).
* Equipment storage: big two-door steel cabinets, multi-drawer parts cabinets,
  a drawer island with a worktop and a cable-reel rack, all labelled.
* Teachers' room: five teacher workstations (screens named
  StaffPC_<n>_Monitor_Display_Surface, so Godot turns them into usable
  computers STAFF-PC-01..05), fabric partitions as on the floor plan, a
  meeting table, sofa corner, pantry with sink and fridge, lockers, bookcase,
  filing cabinets, notice board, timetable board and plants.

Objects with collision="box" get a box collider from tools/export_blender_assets.py.
Screens and items on desks are separate meshes without colliders so the
player's interact ray always reaches a computer screen or the phone.
Re-running removes what this script built before (collections 17, 18 and 19).
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_science_lab_and_server_room as base  # noqa: E402  (shared helpers + materials)

Item, dup, text, mat, collection, remove_collection = (
    base.Item, base.dup, base.text, base.mat, base.collection, base.remove_collection)

IT_NAME = "17 | IT Support - Data Center office"
ST_NAME = "18 | Equipment storage"
TR_NAME = "19 | Teachers room"

PI = math.pi
FACE_E, FACE_W, FACE_N, FACE_S = PI / 2, -PI / 2, PI, 0.0   # rz so the local -Y front faces that way


# ============================================================ materials

DARK = base.DARK
STEEL = base.STEEL
WHITE = base.WHITE
BOARD = base.BOARD
BOARD_FRAME = base.BOARD_FRAME
INK = base.INK
NAVY = base.NAVY
SIGN_TEXT = base.SIGN_TEXT
SIGN_RED = base.SIGN_RED
SIGN_GREEN = base.SIGN_GREEN
PORT = base.PORT
LED_GREEN = base.LED_GREEN
LED_AMBER = base.LED_AMBER
LED_BLUE = base.LED_BLUE
CABLE_BLUE = base.CABLE_BLUE
CABLE_YELLOW = base.CABLE_YELLOW
SCREEN_ON = base.SCREEN_ON
SCREEN_MAP = base.SCREEN_MAP
SCREEN_GRAPH = base.SCREEN_GRAPH
SCREEN_ALERT = base.SCREEN_ALERT
RACK = base.RACK
GLASSWARE = base.GLASSWARE
CHAIR_MESH = base.CHAIR

OAK = mat("OF | oak laminate", (0.62, 0.46, 0.30), 0.5)
WALNUT = mat("OF | walnut veneer", (0.36, 0.23, 0.14), 0.45)
WHITE_LAM = mat("OF | white laminate", (0.90, 0.90, 0.88), 0.45)
LEG_WHITE = mat("OF | powder coat white", (0.86, 0.87, 0.87), 0.4, 0.3)
LEG_DARK = mat("OF | powder coat graphite", (0.18, 0.19, 0.20), 0.4, 0.4)
STEEL_CAB = mat("OF | steel cabinet light grey", (0.70, 0.72, 0.72), 0.4, 0.35)
STEEL_CAB_BLUE = mat("OF | steel cabinet blue", (0.20, 0.36, 0.55), 0.4, 0.35)
DRAWER_RED = mat("OF | parts drawer red", (0.70, 0.12, 0.10), 0.5)
DRAWER_BIN = mat("OF | parts bin translucent", (0.55, 0.70, 0.85), 0.3)
HANDLE = mat("OF | handle chrome", (0.80, 0.81, 0.83), 0.2, 0.9)
LABEL = mat("OF | label paper", (0.97, 0.97, 0.92), 0.7)
PARTITION = mat("OF | partition fabric blue-grey", (0.50, 0.60, 0.68), 0.9)
PARTITION_TRIM = mat("OF | partition trim aluminium", (0.66, 0.68, 0.70), 0.3, 0.7)
SOFA = mat("OF | sofa fabric teal", (0.12, 0.38, 0.40), 0.9)
CUSHION = mat("OF | cushion mustard", (0.85, 0.62, 0.18), 0.9)
RUG = mat("OF | rug warm grey", (0.45, 0.42, 0.40), 0.95)
LEAF = mat("OF | plant leaf green", (0.13, 0.42, 0.16), 0.7)
LEAF_LIGHT = mat("OF | plant leaf light green", (0.30, 0.58, 0.20), 0.7)
POT = mat("OF | plant pot terracotta", (0.66, 0.33, 0.20), 0.7)
POT_WHITE = mat("OF | plant pot white", (0.92, 0.92, 0.90), 0.4)
SOIL = mat("OF | soil", (0.18, 0.12, 0.08), 0.95)
CARDBOARD = mat("OF | cardboard", (0.66, 0.50, 0.32), 0.85)
PAPER = mat("OF | paper white", (0.96, 0.96, 0.94), 0.8)
CORK = mat("OF | cork board", (0.68, 0.50, 0.32), 0.9)
BOOKS = [mat("OF | book red", (0.65, 0.12, 0.10), 0.7), mat("OF | book blue", (0.10, 0.25, 0.55), 0.7),
         mat("OF | book green", (0.12, 0.45, 0.25), 0.7), mat("OF | book yellow", (0.90, 0.70, 0.15), 0.7),
         mat("OF | book white", (0.92, 0.92, 0.90), 0.7), mat("OF | binder black", (0.08, 0.08, 0.09), 0.6)]
NOTE_COLORS = [mat("OF | note yellow", (0.98, 0.88, 0.30), 0.8), mat("OF | note pink", (0.95, 0.55, 0.65), 0.8),
               mat("OF | note green", (0.55, 0.88, 0.55), 0.8), mat("OF | note blue", (0.55, 0.75, 0.95), 0.8)]
MUG = mat("OF | mug white", (0.95, 0.95, 0.95), 0.3)
MUG_RED = mat("OF | mug red", (0.75, 0.10, 0.10), 0.3)
SCREEN_OFF = mat("OF | monitor screen glass", (0.008, 0.012, 0.018), 0.15, 0.1)
FRIDGE = mat("OF | appliance white", (0.93, 0.94, 0.94), 0.3, 0.1)
APPLIANCE_STEEL = mat("OF | appliance steel", (0.62, 0.64, 0.66), 0.25, 0.8)
COUNTER_TOP = mat("OF | counter quartz grey", (0.55, 0.56, 0.57), 0.3)
TILE_SPLASH = mat("OF | splashback tile white", (0.92, 0.94, 0.95), 0.2)
LOCKER = mat("OF | locker sage", (0.48, 0.60, 0.55), 0.45, 0.3)
WATER = mat("OF | water bottle blue", (0.35, 0.60, 0.90), 0.1, alpha=0.6)
FABRIC_CHAIR = mat("OF | chair fabric navy", (0.10, 0.14, 0.26), 0.9)
FABRIC_CHAIR_RED = mat("OF | chair fabric red", (0.55, 0.12, 0.10), 0.9)
FRAME_GOLD = mat("OF | frame gold", (0.75, 0.60, 0.25), 0.35, 0.8)
ANTISTATIC = mat("OF | anti-static mat blue", (0.15, 0.40, 0.62), 0.8)
COPIER = mat("OF | copier light grey", (0.82, 0.83, 0.83), 0.4)
PCB = mat("OF | pcb green", (0.05, 0.40, 0.18), 0.5)


# ============================================================ small helpers

def place(loc, rz, local):
    """World position of a point given in an object's local frame."""
    v = Matrix.Rotation(rz, 3, "Z") @ Vector(local)
    return (loc[0] + v.x, loc[1] + v.y, loc[2] + v.z)


def label(name, body, coll, loc, rz, size=0.05, m=None, z_off=0.0):
    """Flat text on the front (-Y) face of something placed at loc with rz."""
    return text(name, body, coll, (loc[0], loc[1], loc[2] + z_off), size, m or INK, rot=(PI / 2, 0, rz))


def office_chair(name, coll, loc, rz, fabric=FABRIC_CHAIR):
    """Task chair; the seat faces local -Y. No collider (like the DC chairs)."""
    c = Item(name)
    c.box((0.48, 0.47, 0.07), (0, 0, 0.47), fabric)
    c.box((0.46, 0.06, 0.52), (0, 0.25, 0.80), fabric, rx=-0.12)
    c.box((0.30, 0.03, 0.18), (0, 0.27, 0.52), DARK)
    for sx in (-0.26, 0.26):
        c.box((0.05, 0.28, 0.035), (sx, 0.02, 0.66), DARK)
        c.box((0.03, 0.03, 0.18), (sx, 0.08, 0.565), DARK)
    c.cyl(0.028, 0.36, (0, 0, 0.26), STEEL)
    for a in range(5):
        ang = a * 2 * PI / 5
        c.box((0.30, 0.04, 0.03), (math.cos(ang) * 0.15, math.sin(ang) * 0.15, 0.06), DARK, rz=ang)
        c.cyl(0.025, 0.04, (math.cos(ang) * 0.29, math.sin(ang) * 0.29, 0.025), DARK, seg=8)
    return c.build(coll, loc=loc, rz=rz)


def plant(name, coll, loc, h=1.2, pot=POT, big=True):
    p = Item(name)
    r = 0.2 if big else 0.13
    p.cyl(r, r * 1.8, (0, 0, r * 0.9), pot, r2=r * 0.78, seg=16)
    p.cyl(r * 0.92, 0.02, (0, 0, r * 1.8), SOIL, seg=16)
    p.cyl(0.02, h * 0.55, (0, 0, r * 1.8 + h * 0.27), WALNUT, seg=6)
    for i in range(7 if big else 5):
        ang = i * 2.4
        z = r * 1.8 + h * (0.35 + 0.09 * (i % 4))
        d = 0.14 + 0.05 * (i % 3)
        p.cyl(0.12 if big else 0.08, 0.05, (math.cos(ang) * d, math.sin(ang) * d, z),
              LEAF if i % 2 else LEAF_LIGHT, r2=0.02, seg=8, rx=0.5 * math.cos(ang), ry=-0.5 * math.sin(ang))
    p.cyl(0.17 if big else 0.11, 0.35 if big else 0.22, (0, 0, r * 1.8 + h * 0.75), LEAF, r2=0.03, seg=10)
    return p.build(coll, loc=loc, collide=big)


def tall_cabinet(name, w=0.95, d=0.5, h=2.0, body=STEEL_CAB, doors=2, glass=False):
    """Two-door steel storage cabinet, front faces local -Y."""
    c = Item(name)
    if glass:   # hollow carcass so the contents show through the glass doors
        t = 0.02
        for sx in (-w / 2 + t / 2, w / 2 - t / 2):
            c.box((t, d, h), (sx, 0, h / 2), body)
        c.box((w, t, h), (0, d / 2 - t / 2, h / 2), body)
        c.box((w, d, t), (0, 0, h - t / 2), body)
        c.box((w, d, t), (0, 0, 0.06 + t / 2), body)
    else:
        c.box((w, d, h), (0, 0, h / 2), body)
    c.box((w + 0.01, d + 0.01, 0.06), (0, 0, 0.03), LEG_DARK)            # plinth
    dw = (w - 0.03) / doors
    for i in range(doors):
        x = -w / 2 + 0.015 + dw * (i + 0.5)
        if glass:
            c.box((dw - 0.03, 0.01, h - 0.2), (x, -d / 2 - 0.004, h / 2 + 0.02), GLASSWARE)
        else:
            c.box((dw - 0.01, 0.012, h - 0.12), (x, -d / 2 - 0.006, h / 2 + 0.03), body)
            c.box((dw - 0.12, 0.004, 0.08), (x, -d / 2 - 0.013, h * 0.86), PORT)   # vent slots
            c.box((dw - 0.12, 0.004, 0.08), (x, -d / 2 - 0.013, 0.22), PORT)
    for i in range(doors - 1):
        hx = -w / 2 + 0.015 + dw * (i + 1)
        c.box((0.02, 0.03, 0.22), (hx - 0.04, -d / 2 - 0.02, h * 0.52), HANDLE)
        c.box((0.02, 0.03, 0.22), (hx + 0.04, -d / 2 - 0.02, h * 0.52), HANDLE)
    if doors == 1:
        c.box((0.02, 0.03, 0.22), (w / 2 - 0.08, -d / 2 - 0.02, h * 0.52), HANDLE)
    c.box((0.16, 0.004, 0.07), (0, -d / 2 - 0.014, h * 0.70), LABEL)     # label holder
    return c


def drawer_cabinet(name, w=0.9, d=0.45, h=1.0, rows=4, cols=1, body=STEEL_CAB, front=None, small=False):
    """Cabinet full of drawers, front faces local -Y."""
    c = Item(name)
    c.box((w, d, h), (0, 0, h / 2), body)
    front = front or body
    gap = 0.012
    dw = (w - 0.03) / cols
    dh = (h - 0.08) / rows
    for r in range(rows):
        for k in range(cols):
            x = -w / 2 + 0.015 + dw * (k + 0.5)
            z = 0.06 + dh * (r + 0.5)
            c.box((dw - gap, 0.015, dh - gap), (x, -d / 2 - 0.007, z), front)
            if small:
                c.box((dw * 0.45, 0.012, 0.012), (x, -d / 2 - 0.02, z - dh * 0.12), HANDLE)
                c.box((dw * 0.55, 0.004, dh * 0.28), (x, -d / 2 - 0.016, z + dh * 0.18), LABEL)
            else:
                c.box((min(0.22, dw * 0.5), 0.025, 0.02), (x, -d / 2 - 0.025, z + dh * 0.22), HANDLE)
                c.box((0.10, 0.004, 0.045), (x, -d / 2 - 0.016, z - dh * 0.1), LABEL)
    return c


def bookcase(name, w=1.0, d=0.38, h=2.0, body=WHITE_LAM, shelves=5, seed=0, binders=False):
    c = Item(name)
    t = 0.022
    for sx in (-w / 2 + t / 2, w / 2 - t / 2):
        c.box((t, d, h), (sx, 0, h / 2), body)
    c.box((w, t, h), (0, d / 2 - t / 2, h / 2), body)
    sh = h / shelves
    for i in range(shelves + 1):
        c.box((w, d, t), (0, 0, min(i * sh + t / 2, h - t / 2)), body)
    c.box((w, 0.02, 0.07), (0, -d / 2 + 0.01, 0.035), body)
    for s in range(shelves):
        x = -w / 2 + 0.05
        z0 = s * sh + t
        k = seed + s * 7
        while x < w / 2 - 0.08:
            k += 1
            bw = 0.06 if binders else 0.025 + 0.02 * ((k * 37) % 5) / 4
            bh = sh * (0.72 if binders else 0.55 + 0.25 * ((k * 13) % 7) / 6)
            if (k * 11) % 9 == 0 and not binders:
                x += 0.12
                continue
            m = BOOKS[5] if binders and k % 3 else BOOKS[k % len(BOOKS)]
            c.box((bw, d * 0.75, bh), (x + bw / 2, -0.02, z0 + bh / 2), m)
            if binders:
                c.box((bw * 0.6, 0.004, 0.06), (x + bw / 2, -d * 0.375 - 0.023, z0 + bh * 0.6), LABEL)
            x += bw + 0.004
    return c


def wall_board(name, w, h, kind="white"):
    """Whiteboard / notice board on a wall, front faces local -Y (thin along Y)."""
    b = Item(name)
    if kind == "cork":
        b.box((w, 0.025, h), (0, 0, 0), CORK)
    else:
        b.box((w, 0.02, h), (0, 0, 0), BOARD)
    b.box((w + 0.04, 0.035, 0.03), (0, 0, h / 2), BOARD_FRAME)
    b.box((w + 0.04, 0.035, 0.03), (0, 0, -h / 2), BOARD_FRAME)
    b.box((0.03, 0.035, h), (-w / 2 - 0.01, 0, 0), BOARD_FRAME)
    b.box((0.03, 0.035, h), (w / 2 + 0.01, 0, 0), BOARD_FRAME)
    if kind != "cork":
        b.box((w * 0.8, 0.08, 0.02), (0, -0.05, -h / 2 - 0.01), BOARD_FRAME)  # marker tray
        b.box((0.12, 0.02, 0.02), (-w * 0.25, -0.06, -h / 2 + 0.005), INK)
        b.box((0.12, 0.02, 0.02), (-w * 0.25 + 0.15, -0.06, -h / 2 + 0.005), SIGN_RED)
    return b


def pinned_notes(item, w, h, n=8, y=-0.016):
    for i in range(n):
        x = -w / 2 + 0.15 + (w - 0.3) * ((i * 37) % 11) / 10
        z = -h / 2 + 0.12 + (h - 0.25) * ((i * 23) % 7) / 6
        if i % 3 == 0:
            item.box((0.21, 0.004, 0.29), (x, y, z), PAPER)
            for ln in range(4):
                item.box((0.15, 0.002, 0.008), (x, y - 0.003, z + 0.09 - ln * 0.05), INK)
        else:
            item.box((0.09, 0.004, 0.09), (x, y, z), NOTE_COLORS[i % 4])
        item.cyl(0.008, 0.01, (x, y - 0.006, z + 0.1 if i % 3 == 0 else z + 0.03), SIGN_RED, seg=6, rx=PI / 2)


def wall_clock(name, coll, loc, rz):
    c = Item(name)
    c.cyl(0.17, 0.045, (0, 0, 0), DARK, seg=28, rx=PI / 2)
    c.cyl(0.155, 0.047, (0, 0, 0), WHITE, seg=28, rx=PI / 2)
    for i in range(12):
        a = i * PI / 6
        c.box((0.012, 0.01, 0.03), (math.sin(a) * 0.13, -0.025, math.cos(a) * 0.13), DARK, ry=a)
    c.box((0.012, 0.01, 0.09), (0.02, -0.03, 0.04), DARK, ry=0.5)
    c.box((0.008, 0.01, 0.12), (-0.03, -0.032, 0.05), DARK, ry=-0.6)
    return c.build(coll, loc=loc, rz=rz)


def split_ac(name, coll, loc, rz):
    a = Item(name)
    a.box((1.0, 0.25, 0.3), (0, 0, 0), WHITE)
    a.box((0.9, 0.01, 0.05), (0, -0.13, -0.1), base.VENT)
    a.box((0.05, 0.01, 0.015), (0.4, -0.127, 0.06), LED_BLUE)
    return a.build(coll, loc=loc, rz=rz)


def framed(name, coll, loc, rz, w, h, inner, border=FRAME_GOLD):
    f = Item(name)
    f.box((w, 0.025, h), (0, 0, 0), border)
    f.box((w - 0.06, 0.004, h - 0.06), (0, -0.014, 0), PAPER)
    f.box((w - 0.16, 0.004, h - 0.18), (0, -0.017, 0), inner)
    return f.build(coll, loc=loc, rz=rz)


def fire_extinguisher(name, coll, loc):
    src = bpy.data.objects.get("SCI_FireExtinguisher")
    if src:
        return dup(src, name, coll, loc, 0.0)
    e = Item(name)
    e.cyl(0.08, 0.5, (0, 0, 0), SIGN_RED)
    return e.build(coll, loc=loc)


# ---------------------------------------------------------------- office desk + computer

def office_desk(name, w=1.5, d=0.75, h=0.75, top=OAK, legs=LEG_WHITE, pedestal=True, modesty=True):
    """Desk; the user sits on the local -Y side. Collider = the desk only."""
    k = Item(name)
    k.box((w, d, 0.03), (0, 0, h - 0.015), top)
    k.box((w + 0.002, d + 0.002, 0.004), (0, 0, h - 0.031), legs)       # edge band
    for sx in (-w / 2 + 0.04, w / 2 - 0.04):
        k.box((0.05, d - 0.06, 0.03), (sx, 0, 0.015), legs)
        k.box((0.05, 0.05, h - 0.06), (sx, 0, (h - 0.03) / 2), legs)
        k.box((0.05, d - 0.1, 0.04), (sx, 0, h - 0.05), legs)
    if modesty:
        k.box((w - 0.12, 0.018, 0.38), (0, d / 2 - 0.06, h - 0.25), legs)
    if pedestal:
        px = w / 2 - 0.27
        k.box((0.4, 0.55, 0.6), (px, 0.02, 0.32), WHITE_LAM)
        for i, (zz, hh) in enumerate(((0.54, 0.12), (0.39, 0.15), (0.17, 0.26))):
            k.box((0.38, 0.012, hh - 0.012), (px, -0.256, zz), WHITE_LAM)
            k.box((0.14, 0.02, 0.015), (px, -0.268, zz + hh * 0.28), HANDLE)
        k.box((0.4, 0.5, 0.03), (px, 0.02, 0.015), LEG_DARK)
    return k


def computer_set(name, variant=0):
    """Monitor + stand, keyboard, mouse, mini tower. Screen is separate (see make_screen).
    Local origin = desk top centre; monitor at +Y, user at -Y."""
    p = Item(name)
    my = 0.18
    p.box((0.56, 0.035, 0.34), (0, my, 1.07 - 0.75), DARK)                # monitor body (z relative to desk top)
    p.box((0.56, 0.02, 0.02), (0, my - 0.012, 0.155), LEG_DARK)            # bottom bezel
    p.box((0.04, 0.03, 0.2), (0, my + 0.04, 0.12), DARK)                   # neck
    p.box((0.22, 0.16, 0.015), (0, my + 0.02, 0.0075), DARK)               # foot
    p.box((0.008, 0.006, 0.008), (0.24, my - 0.02, 0.152), LED_BLUE)       # power LED
    p.box((0.44, 0.14, 0.02), (-0.04, -0.12, 0.012), DARK)                 # keyboard
    p.box((0.42, 0.12, 0.006), (-0.04, -0.12, 0.024), LEG_DARK)            # key area
    p.box((0.065, 0.11, 0.03), (0.30, -0.12, 0.015), DARK)                 # mouse
    p.box((0.24, 0.20, 0.003), (0.30, -0.12, 0.0015), PORT)                # mouse pad
    if variant % 2 == 0:
        # mini tower beside the monitor
        p.box((0.19, 0.42, 0.42), (-0.5, 0.05, -0.75 + 0.22), LEG_DARK)       # tower under the desk
        p.box((0.008, 0.004, 0.008), (-0.5, -0.162, -0.75 + 0.38), LED_BLUE)
        p.box((0.08, 0.004, 0.014), (-0.5, -0.162, -0.75 + 0.34), PORT)
    else:
        # small desktop box under the monitor stand
        p.box((0.30, 0.22, 0.05), (0, my + 0.02, 0.025), LEG_DARK)
        p.box((0.008, 0.004, 0.008), (0.12, my - 0.092, 0.03), LED_BLUE)
    return p


def make_screen(name, coll, desk_loc, desk_rz, desk_top_z, local_xy=(0.0, 0.16)):
    """Separate screen mesh (0.52 x 0.29 m). Local -Y faces the user, height on local Z:
    exactly what ComputerStation expects (Godot +Z = Blender -Y)."""
    me = bpy.data.meshes.get("OF_Screen_Mesh")
    if me is None:
        s = Item("OF_Screen_Mesh")
        s.box((0.52, 0.004, 0.29), (0, 0, 0), SCREEN_OFF)
        o = s.build(coll)
        me = o.data
        bpy.data.objects.remove(o, do_unlink=True)
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    o.location = place(desk_loc, desk_rz, (local_xy[0], local_xy[1], desk_top_z + 0.32))
    o.rotation_euler.z = desk_rz
    o["note"] = "Usable computer screen (Godot ComputerStation)"
    return o


def desk_items(name, coll, loc, rz, top_z, seed):
    """Personal items on a teacher's desk: books, papers, mug, plant, lamp, photo."""
    it = Item(name)
    if seed % 2 == 0:
        for i in range(4):
            it.box((0.035, 0.2, 0.24 - 0.02 * i), (-0.62 + i * 0.038, 0.22, 0.12 - 0.01 * i), BOOKS[(seed + i) % 5])
    else:
        it.box((0.03, 0.22, 0.3), (-0.62, 0.2, 0.15), BOOKS[5])
        it.box((0.03, 0.22, 0.3), (-0.585, 0.2, 0.15), BOOKS[1])
    it.box((0.24, 0.32, 0.03), (0.5, 0.15, 0.015), PAPER)                  # stack of student work
    it.box((0.22, 0.30, 0.004), (0.51, 0.15, 0.032), PAPER, rz=0.12)
    it.cyl(0.04, 0.1, (0.62, -0.25, 0.05), MUG_RED if seed % 3 == 0 else MUG, seg=12)
    if seed % 3 != 1:
        it.cyl(0.06, 0.09, (0.68, -0.08, 0.045), POT_WHITE, r2=0.05, seg=12)  # small succulent
        it.cyl(0.07, 0.07, (0.68, -0.08, 0.12), LEAF_LIGHT, r2=0.02, seg=8)
    else:
        it.cyl(0.07, 0.02, (-0.6, -0.15, 0.01), DARK, seg=12)                   # desk lamp
        it.cyl(0.012, 0.35, (-0.6, -0.15, 0.18), DARK, seg=6)
        it.box((0.05, 0.22, 0.04), (-0.6, -0.25, 0.36), DARK, rx=-0.3)
    it.box((0.12, 0.015, 0.09), (-0.4, 0.3, 0.05), FRAME_GOLD, rx=-0.2)      # photo frame
    it.box((0.1, 0.004, 0.07), (-0.4, 0.29, 0.05), NOTE_COLORS[seed % 4], rx=-0.2)
    it.box((0.15, 0.06, 0.04), (0.2, 0.3, 0.02), DARK)                        # pen tray
    for i in range(3):
        it.cyl(0.005, 0.14, (0.16 + i * 0.03, 0.3, 0.08), (INK, SIGN_RED, DARK)[i], seg=6)
    return it.build(coll, loc=(loc[0], loc[1], top_z), rz=rz)


# ============================================================ IT Support / Data Center office

# North part of the L: x -21.15 .. -9.27, y 37.05 .. 44.16. Return strip by the corridor:
# x -12.37 .. -9.27, y 30.59 .. 37.05. Corridor door x -9.19, y 34.43..35.53 (opens inwards).
IX0, IX1, IY0, IY1 = -21.15, -9.27, 37.07, 44.16
SX0, SY0 = -12.37, 30.62


def build_it_room(c):
    furn = collection("17.1 | Furniture", c)
    wall = collection("17.2 | Wall equipment and signs", c)
    desk = collection("17.3 | Desk items", c)

    # ---- monitoring wall on the corridor (east) wall, seen from all three desks
    mw = Item("IT_Monitoring_Screens")
    shots = [SCREEN_MAP, SCREEN_GRAPH, SCREEN_ON]
    for i, s in enumerate(shots):
        x = -1.08 + i * 1.08
        mw.box((1.05, 0.05, 0.62), (x, 0, 0), DARK)
        mw.box((1.0, 0.008, 0.57), (x, -0.03, 0), s)
        for b in range(5):                                                  # dashboard bars
            hh = 0.06 + 0.035 * ((b * 3 + i) % 5)
            mw.box((0.1, 0.004, hh), (x - 0.34 + b * 0.17, -0.036, -0.2 + hh / 2), LED_GREEN if (b + i) % 4 else LED_AMBER)
        mw.box((0.6, 0.004, 0.02), (x, -0.036, 0.22), LED_BLUE)
    mw.box((3.3, 0.06, 0.05), (0, 0.02, -0.34), LEG_DARK)
    mw.build(wall, loc=(IX1 - 0.03, 40.7, 1.85), rz=FACE_W)
    text("IT_Monitoring_Title", "NETWORK MONITORING  ·  ศูนย์เฝ้าระบบ", wall, (IX1 - 0.02, 40.7, 2.33), 0.075, NAVY, rot=(PI / 2, 0, FACE_W))

    # low credenza under the monitoring wall with a printer and binders
    cr = Item("IT_Credenza_East")
    cr.box((3.2, 0.45, 0.72), (0, 0, 0.36), WHITE_LAM)
    cr.box((3.22, 0.47, 0.03), (0, 0, 0.735), WALNUT)
    for i in range(4):
        x = -1.2 + i * 0.8
        cr.box((0.78, 0.012, 0.62), (x, -0.231, 0.36), WHITE_LAM)
        cr.box((0.02, 0.025, 0.16), (x + (0.3 if i % 2 == 0 else -0.3), -0.245, 0.4), HANDLE)
    cr.build(furn, loc=(IX1 - 0.23, 40.7, 0), rz=FACE_W, collide=True, note="Credenza")
    top = Item("IT_Credenza_Items")
    top.box((0.46, 0.4, 0.3), (-1.1, 0.0, 0.9), COPIER)                      # laser printer
    top.box((0.36, 0.25, 0.02), (-1.1, -0.06, 1.06), DARK)
    top.box((0.3, 0.2, 0.01), (-1.1, -0.1, 0.81), PAPER)
    for i in range(6):                                                        # binders
        top.box((0.06, 0.3, 0.3), (0.2 + i * 0.065, 0.0, 0.9), BOOKS[5] if i % 2 else BOOKS[1])
        top.box((0.04, 0.004, 0.06), (0.2 + i * 0.065, -0.152, 0.92), LABEL)
    top.box((0.44, 0.24, 0.045), (1.0, 0.02, 0.775), DARK)                    # spare switch
    for p in range(8):
        top.box((0.03, 0.004, 0.018), (0.85 + p * 0.042, -0.1, 0.776), PORT)
        top.box((0.006, 0.004, 0.006), (0.85 + p * 0.042, -0.102, 0.792), LED_GREEN)
    top.build(desk, loc=(IX1 - 0.23, 40.7, 0), rz=FACE_W)
    plant("IT_Plant_Credenza", desk, place((IX1 - 0.23, 40.7, 0.75), FACE_W, (1.35, 0, 0)), h=0.5, pot=POT_WHITE, big=False)

    # ---- north wall: on-call whiteboard, logo sign, bookcase, wall network cabinet, clock
    wb = wall_board("IT_OnCall_Board", 2.2, 1.05)
    for r in range(5):                                                        # schedule grid
        wb.box((2.0, 0.003, 0.006), (0, -0.012, 0.35 - r * 0.17), INK)
    for k in range(6):
        wb.box((0.006, 0.003, 0.7), (-1.0 + k * 0.4, -0.012, 0.0), INK)
    for i in range(7):
        wb.box((0.25, 0.003, 0.06), (-0.8 + (i % 5) * 0.4, -0.013, 0.26 - (i // 2) * 0.17), NOTE_COLORS[i % 4])
    wb.build(wall, loc=(-15.8, IY1 - 0.02, 1.55), rz=FACE_S)
    text("IT_OnCall_Title", "ตารางเวร On-call / แจ้งปัญหาระบบ", wall, (-15.8, IY1 - 0.04, 2.17), 0.065, INK, rot=(PI / 2, 0, FACE_S))
    logo = Item("IT_Logo_Panel")
    logo.box((2.6, 0.03, 0.42), (0, 0, 0), NAVY)
    logo.box((2.6, 0.032, 0.03), (0, 0, -0.2), base.LED_BLUE)
    logo.build(wall, loc=(-15.8, IY1 - 0.02, 2.62), rz=FACE_S)
    text("IT_Logo_TH", "IT SUPPORT  ·  DATA CENTER", wall, (-15.8, IY1 - 0.04, 2.67), 0.2, SIGN_TEXT, rot=(PI / 2, 0, FACE_S))
    text("IT_Logo_EN", "ฝ่ายเทคโนโลยีสารสนเทศ วิทยาลัย", wall, (-15.8, IY1 - 0.04, 2.49), 0.075, SIGN_TEXT, rot=(PI / 2, 0, FACE_S))

    bc = bookcase("IT_Bookcase_North", w=1.8, d=0.38, h=2.0, body=WHITE_LAM, shelves=5, seed=3, binders=True)
    bc.build(furn, loc=(-11.15, IY1 - 0.2, 0), rz=FACE_S, collide=True, note="Manuals and binders")
    wr = Item("IT_Network_Cabinet_9U")
    wr.box((0.6, 0.45, 0.6), (0, 0, 0), RACK)
    wr.box((0.54, 0.01, 0.54), (0, -0.226, 0), GLASSWARE)
    for u in range(4):
        z = 0.18 - u * 0.12
        wr.box((0.48, 0.3, 0.04), (0, -0.05, z), base.SERVER_DARK)
        for p in range(12):
            wr.box((0.022, 0.004, 0.014), (-0.2 + p * 0.032, -0.202, z), PORT)
            if (p + u) % 3:
                wr.box((0.005, 0.004, 0.005), (-0.2 + p * 0.032, -0.204, z + 0.013), LED_GREEN if p % 5 else LED_AMBER)
    wr.box((0.3, 0.01, 0.01), (0, -0.23, 0.27), LED_BLUE)
    wr.build(wall, loc=(-9.72, IY1 - 0.25, 1.95), rz=FACE_S)
    text("IT_Network_Cabinet_Label", "MDF-01  Core Switch", wall, (-9.72, IY1 - 0.48, 2.3), 0.035, SIGN_TEXT, rot=(PI / 2, 0, FACE_S))
    cab = Item("IT_Cable_Trunking")
    cab.box((0.12, 0.06, 1.2), (0, 0, 0), WHITE_LAM)
    cab.build(wall, loc=(-9.72, IY1 - 0.04, 2.85), rz=FACE_S)
    plant("IT_Plant_NE", furn, (-9.75, 43.55, 0), h=1.25)
    wall_clock("IT_Clock", wall, (-15.8, IY0 + 0.03, 2.45), FACE_N)
    split_ac("IT_Split_AC_1", wall, (-19.6, IY1 - 0.14, 2.72), FACE_S)
    split_ac("IT_Split_AC_2", wall, (-13.6, IY0 + 0.14, 2.72), FACE_N)

    # ---- supervisor side (west wall): credenza, certificates, network plan, bookcase
    cw = Item("IT_Credenza_West")
    cw.box((3.0, 0.45, 0.72), (0, 0, 0.36), WALNUT)
    cw.box((3.02, 0.47, 0.03), (0, 0, 0.735), WALNUT)
    for i in range(3):
        x = -1.0 + i * 1.0
        cw.box((0.98, 0.012, 0.62), (x, -0.231, 0.36), WALNUT)
        cw.box((0.2, 0.025, 0.02), (x, -0.245, 0.62), HANDLE)
    cw.build(furn, loc=(IX0 + 0.23, 42.3, 0), rz=FACE_E, collide=True, note="Supervisor credenza")
    ci = Item("IT_Credenza_West_Items")
    ci.box((0.08, 0.25, 0.3), (-1.2, 0.0, 0.9), BOOKS[0])
    ci.box((0.08, 0.25, 0.3), (-1.11, 0.0, 0.9), BOOKS[1])
    ci.box((0.08, 0.25, 0.28), (-1.02, 0.0, 0.89), BOOKS[2])
    ci.cyl(0.07, 0.03, (0.3, 0.0, 0.765), FRAME_GOLD, seg=16)                 # trophy
    ci.cyl(0.03, 0.18, (0.3, 0.0, 0.87), FRAME_GOLD, seg=10)
    ci.cyl(0.07, 0.1, (0.3, 0.0, 1.0), FRAME_GOLD, r2=0.04, seg=16)
    ci.box((0.3, 0.22, 0.12), (0.8, 0.0, 0.81), CARDBOARD)                    # document box
    ci.build(desk, loc=(IX0 + 0.23, 42.3, 0), rz=FACE_E)
    plant("IT_Plant_West", desk, place((IX0 + 0.23, 42.3, 0.75), FACE_E, (-0.55, 0, 0)), h=0.45, pot=POT_WHITE, big=False)
    plan = Item("IT_Network_Plan_Frame")
    plan.box((1.5, 0.025, 0.95), (0, 0, 0), LEG_DARK)
    plan.box((1.42, 0.004, 0.87), (0, -0.014, 0), PAPER)
    nodes = [(0, 0.28), (-0.45, 0.0), (0.45, 0.0), (-0.6, -0.28), (-0.3, -0.28), (0.3, -0.28), (0.6, -0.28)]
    for (x, z) in nodes:
        plan.box((0.14, 0.004, 0.08), (x, -0.018, z), base.LED_BLUE if z > 0.1 else NAVY)
    for (a, b) in ((0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6)):
        (x1, z1), (x2, z2) = nodes[a], nodes[b]
        L = math.hypot(x2 - x1, z2 - z1)
        plan.box((L, 0.003, 0.008), ((x1 + x2) / 2, -0.017, (z1 + z2) / 2), INK, ry=-math.atan2(z2 - z1, x2 - x1))
    plan.build(wall, loc=(IX0 + 0.02, 42.3, 1.65), rz=FACE_E)
    text("IT_Network_Plan_Title", "แผนผังเครือข่ายวิทยาลัย", wall, (IX0 + 0.04, 42.3, 2.2), 0.06, INK, rot=(PI / 2, 0, FACE_E))
    framed("IT_Certificate_1", wall, (IX0 + 0.02, 40.9, 1.75), FACE_E, 0.42, 0.32, base.SIGN_GREEN)
    framed("IT_Certificate_2", wall, (IX0 + 0.02, 43.65, 1.75), FACE_E, 0.42, 0.32, NAVY)
    bw = bookcase("IT_Bookcase_West", w=1.2, d=0.4, h=2.0, body=WALNUT, shelves=5, seed=11)
    bw.build(furn, loc=(IX0 + 0.21, 39.0, 0), rz=FACE_E, collide=True)
    plant("IT_Plant_SW", furn, (IX0 + 0.3, IY0 + 0.35, 0), h=1.35)

    # supervisor desk items (IT_HeadDesk top z 0.758, desk x -18.41..-17.56, y 41.56..43.46)
    hd = Item("IT_HeadDesk_Items")
    hd.box((0.26, 0.06, 0.07), (0, 0, 0.035), WALNUT)                          # name plate
    hd.box((0.24, 0.004, 0.05), (0, -0.031, 0.04), FRAME_GOLD)
    hd.build(desk, loc=(-17.66, 41.82, 0.758), rz=FACE_E)
    text("IT_HeadDesk_NamePlate", "หัวหน้างาน Data Center", desk, place((-17.66, 41.82, 0.798), FACE_E, (0, -0.034, 0)), 0.022, DARK, rot=(PI / 2, 0, FACE_E))
    hp = Item("IT_HeadDesk_Phone_Mug")
    hp.box((0.2, 0.18, 0.06), (0, 0, 0.03), DARK)
    hp.box((0.2, 0.06, 0.04), (0, 0.05, 0.075), DARK)
    hp.box((0.08, 0.06, 0.004), (0.04, -0.03, 0.062), LEG_DARK)
    hp.cyl(0.04, 0.1, (0.0, -0.45, 0.05), MUG, seg=12)
    hp.build(desk, loc=(-18.2, 41.85, 0.758), rz=FACE_E)
    # player desk items (phone is the Godot DeskPhone node)
    pd = Item("IT_PlayerDesk_Items")
    pd.cyl(0.04, 0.1, (0, 0, 0.05), MUG_RED, seg=12)
    pd.box((0.21, 0.28, 0.015), (0.0, 0.25, 0.008), BOOKS[1])                  # notebook
    pd.build(desk, loc=(-13.35, 41.85, 0.758), rz=FACE_E)

    # ---- meeting table with four chairs (south-west of the head desk)
    mt = Item("IT_Meeting_Table")
    mt.cyl(0.6, 0.035, (0, 0, 0.735), WHITE_LAM, seg=40)
    mt.cyl(0.05, 0.7, (0, 0, 0.37), LEG_DARK, seg=12)
    mt.cyl(0.32, 0.03, (0, 0, 0.015), LEG_DARK, seg=24)
    mt.build(furn, loc=(-18.1, 39.25, 0), collide=True, note="Meeting table")
    mi = Item("IT_Meeting_Table_Items")
    mi.box((0.3, 0.22, 0.02), (-0.15, 0.05, 0.76), DARK)                       # laptop
    mi.box((0.3, 0.015, 0.2), (-0.15, 0.16, 0.86), DARK, rx=-0.3)
    mi.box((0.27, 0.004, 0.17), (-0.15, 0.15, 0.86), SCREEN_GRAPH, rx=-0.3)
    mi.box((0.21, 0.29, 0.004), (0.2, -0.15, 0.755), PAPER, rz=0.3)
    mi.build(desk, loc=(-18.1, 39.25, 0))
    for i, ang in enumerate((0.0, PI / 2, PI, -PI / 2)):
        d = 0.85
        office_chair("IT_Meeting_Chair_%d" % (i + 1), furn, (-18.1 + math.sin(ang) * d, 39.25 - math.cos(ang) * d, 0), ang + PI, FABRIC_CHAIR_RED)

    # ---- return strip by the corridor: repair bench, copier, equipment cabinet
    rb = Item("IT_Repair_Bench")
    rb.box((2.2, 0.75, 0.04), (0, 0, 0.88), OAK)
    for sx in (-1.06, 1.06):
        rb.box((0.06, 0.7, 0.86), (sx, 0, 0.43), LEG_DARK)
    rb.box((2.1, 0.7, 0.03), (0, 0, 0.16), LEG_DARK)
    rb.build(furn, loc=(-10.65, SY0 + 0.4, 0), rz=FACE_N, collide=True, note="Repair bench")
    ri = Item("IT_Repair_Bench_Items")
    ri.box((1.6, 0.55, 0.004), (0.1, 0.0, 0.902), ANTISTATIC)
    ri.box((0.2, 0.42, 0.42), (-0.55, 0.05, 1.11), STEEL)                       # open PC case
    ri.box((0.004, 0.36, 0.34), (-0.452, 0.05, 1.11), PCB)
    ri.box((0.004, 0.08, 0.05), (-0.45, 0.0, 1.18), DARK)
    ri.box((0.004, 0.2, 0.03), (-0.45, 0.05, 1.04), CABLE_BLUE)
    ri.box((0.08, 0.15, 0.04), (0.0, -0.1, 0.92), base.SIGN_YELLOW)               # multimeter
    ri.box((0.06, 0.06, 0.004), (0.0, -0.13, 0.943), SCREEN_OFF)
    ri.box((0.18, 0.14, 0.08), (0.35, 0.12, 0.94), SIGN_RED)                    # soldering station
    ri.cyl(0.006, 0.18, (0.48, 0.05, 0.98), STEEL, seg=6, rx=0.6)
    ri.cyl(0.08, 0.02, (0.75, 0.15, 0.91), DARK, seg=16)                        # magnifier lamp
    ri.cyl(0.012, 0.42, (0.75, 0.15, 1.12), DARK, seg=6)
    ri.cyl(0.09, 0.03, (0.65, 0.0, 1.3), DARK, seg=20, rx=0.9)
    ri.cyl(0.075, 0.032, (0.65, 0.0, 1.3), GLASSWARE, seg=20, rx=0.9)
    ri.box((0.5, 0.2, 0.3), (-0.05, 0.26, 1.05), DRAWER_RED)                    # small parts drawers
    for r in range(3):
        for k in range(5):
            ri.box((0.085, 0.004, 0.08), (-0.25 + k * 0.1, 0.158, 0.94 + r * 0.095), DRAWER_BIN)
    ri.box((2.2, 0.03, 0.9), (0, 0.39, 1.45), mat("OF | pegboard", (0.80, 0.74, 0.62), 0.7))
    for i in range(7):
        ri.box((0.03, 0.02, 0.15 + (i % 3) * 0.05), (-0.85 + i * 0.27, 0.365, 1.5), (DARK, SIGN_RED, base.SIGN_YELLOW)[i % 3])
    ri.cyl(0.12, 0.06, (0.95, 0.33, 1.55), CABLE_BLUE, seg=20, rx=PI / 2)       # hanging cable coil
    ri.build(desk, loc=(-10.65, SY0 + 0.4, 0), rz=FACE_N)
    stool = Item("IT_Repair_Stool")
    stool.cyl(0.18, 0.05, (0, 0, 0.66), DARK, seg=20)
    stool.cyl(0.025, 0.6, (0, 0, 0.35), STEEL, seg=8)
    stool.cyl(0.22, 0.03, (0, 0, 0.02), DARK, seg=5)
    stool.build(furn, loc=(-10.8, SY0 + 1.2, 0))
    text("IT_Repair_Sign", "จุดซ่อมและตรวจเช็กอุปกรณ์", wall, (-10.65, SY0 + 0.02, 2.05), 0.07, NAVY, rot=(PI / 2, 0, FACE_N))

    cp = Item("IT_Copier")
    cp.box((0.62, 0.66, 0.85), (0, 0, 0.425), COPIER)
    cp.box((0.62, 0.55, 0.22), (0, 0.05, 0.96), COPIER)
    cp.box((0.5, 0.4, 0.015), (0, 0.05, 1.075), GLASSWARE)
    cp.box((0.22, 0.12, 0.03), (0.15, -0.28, 1.04), DARK, rx=0.4)
    cp.box((0.1, 0.004, 0.06), (0.15, -0.33, 1.04), SCREEN_ON, rx=0.4)
    for i in range(3):
        cp.box((0.56, 0.01, 0.22), (0, -0.335, 0.15 + i * 0.25), COPIER)
        cp.box((0.2, 0.02, 0.02), (0, -0.345, 0.22 + i * 0.25), DARK)
    cp.build(furn, loc=(IX1 - 0.37, 32.25, 0), rz=FACE_W, collide=True, note="Multifunction copier")
    bx = Item("IT_Paper_Boxes")
    for i in range(3):
        bx.box((0.43, 0.3, 0.26), (0, 0, 0.13 + i * 0.26), CARDBOARD if i != 1 else PAPER)
    bx.build(furn, loc=(IX1 - 0.25, 33.2, 0), rz=FACE_W, collide=True)
    bin_ = Item("IT_Recycle_Bin")
    bin_.cyl(0.17, 0.55, (0, 0, 0.275), base.SIGN_GREEN, r2=0.19, seg=16)
    bin_.build(furn, loc=(IX1 - 0.23, 31.6, 0))
    fire_extinguisher("IT_Fire_Extinguisher", wall, (IX1 - 0.12, 33.75, 0.55))

    ec = tall_cabinet("IT_Equipment_Cabinet", w=1.0, d=0.45, h=1.9, body=WHITE_LAM, glass=True)
    for s in range(3):                                                          # laptops / projectors behind glass
        z = 0.45 + s * 0.5
        ec.box((0.94, 0.4, 0.02), (0, 0, z - 0.03), WHITE_LAM)
        for k in range(3):
            ec.box((0.25, 0.3, 0.06 if s < 2 else 0.12), (-0.3 + k * 0.3, 0.0, z + 0.03 if s < 2 else z + 0.06), DARK if s < 2 else COPIER)
    ec.build(furn, loc=(SX0 + 0.24, 32.7, 0), rz=FACE_E, collide=True, note="Equipment loan cabinet")
    text("IT_Equipment_Cabinet_Label", "อุปกรณ์ยืม-คืน", wall, place((SX0 + 0.24, 32.7, 1.98), FACE_E, (0, -0.24, 0)), 0.05, NAVY, rot=(PI / 2, 0, FACE_E))
    wd = Item("IT_Water_Dispenser")
    wd.box((0.32, 0.32, 1.0), (0, 0, 0.5), WHITE)
    wd.cyl(0.13, 0.42, (0, 0, 1.22), WATER, seg=16)
    wd.box((0.2, 0.012, 0.12), (0, -0.165, 0.85), DARK)
    wd.box((0.025, 0.02, 0.03), (-0.05, -0.17, 0.82), base.SIGN_RED)
    wd.box((0.025, 0.02, 0.03), (0.05, -0.17, 0.82), base.LED_BLUE)
    wd.build(furn, loc=(SX0 + 0.22, 31.05, 0), rz=FACE_E, collide=True)

    # notice board by the door + help desk sign
    nb = wall_board("IT_Notice_Board", 1.1, 0.8, kind="cork")
    pinned_notes(nb, 1.1, 0.8, 7)
    nb.build(wall, loc=(IX1 - 0.02, 37.0, 1.5), rz=FACE_W)
    text("IT_Notice_Title", "ขั้นตอนแจ้งซ่อม / Help Desk", wall, (IX1 - 0.04, 37.0, 2.0), 0.055, INK, rot=(PI / 2, 0, FACE_W))


def retitle_it_room():
    """The IT Support room is the Data Center office (team's mission story)."""
    m = bpy.data.materials.get("MAP | Sign white") or SIGN_TEXT
    o = bpy.data.objects.get("ITSupport_EN")
    if o:
        loc, rot, coll = o.location.copy(), o.rotation_euler.copy(), o.users_collection[0]
        bpy.data.objects.remove(o, do_unlink=True)
        text("ITSupport_EN", "DATA CENTER", coll, loc, 0.065, m, rot=rot)
    r = bpy.data.objects.get("Room_ITSupport")
    if r:
        r["label_th"] = "ห้อง IT SUPPORT (Data Center)"


# ============================================================ equipment storage

# x -21.15 .. -12.52, y 30.66 .. 36.88. Door x -12.44, y 34.91..36.07 swings into the room.
GX0, GX1, GY0, GY1 = -21.15, -12.52, 30.66, 36.86


def build_storage(c):
    furn = collection("18.1 | Cabinets and drawers", c)
    lab = collection("18.2 | Labels and small items", c)

    # west wall: five big two-door steel cabinets
    names = ["สาย LAN / CAT6", "Switch / Router", "Access Point Wi-Fi", "อะไหล่คอมพิวเตอร์", "จอภาพ / ทีวี"]
    big = tall_cabinet("ST_Cabinet_West_1", w=0.95, d=0.5, h=2.0, body=STEEL_CAB).build(furn, loc=(GX0 + 0.25, 31.73, 0), rz=FACE_E, collide=True)
    for i in range(5):
        y = 31.73 + i * 0.95
        o = big if i == 0 else dup(big, "ST_Cabinet_West_%d" % (i + 1), furn, (GX0 + 0.25, y, 0), FACE_E)
        label("ST_Label_West_%d" % (i + 1), names[i], lab, place((GX0 + 0.25, y, 1.4), FACE_E, (0, -0.27, 0)), FACE_E, 0.042)

    # north wall: six large cabinets (blue), door swing kept clear on the east side
    names_n = ["เครื่องมือช่าง", "เมาส์ / คีย์บอร์ด", "หมึกพิมพ์ / กระดาษ", "UPS / ปลั๊กพ่วง", "สายไฟ / อะแดปเตอร์", "เอกสารครุภัณฑ์"]
    nb = tall_cabinet("ST_Cabinet_North_1", w=1.0, d=0.55, h=2.0, body=STEEL_CAB_BLUE).build(furn, loc=(-20.05, GY1 - 0.28, 0), rz=FACE_S, collide=True)
    for i in range(6):
        x = -20.05 + i * 1.02
        o = nb if i == 0 else dup(nb, "ST_Cabinet_North_%d" % (i + 1), furn, (x, GY1 - 0.28, 0), FACE_S)
        label("ST_Label_North_%d" % (i + 1), names_n[i], lab, place((x, GY1 - 0.28, 1.4), FACE_S, (0, -0.295, 0)), FACE_S, 0.042, SIGN_TEXT)

    # south wall: tall multi-drawer parts cabinets alternating with lateral drawer cabinets
    parts = drawer_cabinet("ST_Parts_Drawers_1", w=0.9, d=0.45, h=1.8, rows=10, cols=4, body=STEEL_CAB, front=STEEL_CAB, small=True)
    parts_o = parts.build(furn, loc=(-20.15, GY0 + 0.23, 0), rz=FACE_N, collide=True, note="Small parts drawers")
    lateral = drawer_cabinet("ST_Lateral_Drawers_1", w=0.9, d=0.5, h=1.32, rows=4, cols=1, body=STEEL_CAB_BLUE)
    lat_o = lateral.build(furn, loc=(-19.23, GY0 + 0.25, 0), rz=FACE_N, collide=True, note="Lateral drawers")
    names_s = ["น็อต / สกรู / RJ45", "แฟ้มเอกสาร", "ขั้วต่อ / ตัวแปลง", "การ์ด / RAM / SSD", "สายต่อพ่วง", "อุปกรณ์สำรอง", "ชุดเข้าหัวสาย", "คู่มืออุปกรณ์"]
    for i in range(8):
        x = -20.15 + i * 0.915
        if i % 2 == 0:
            o = parts_o if i == 0 else dup(parts_o, "ST_Parts_Drawers_%d" % (i // 2 + 1), furn, (x, GY0 + 0.23, 0), FACE_N)
            label("ST_Label_South_%d" % (i + 1), names_s[i], lab, place((x, GY0 + 0.23, 1.86), FACE_N, (0, -0.2, 0)), FACE_N, 0.04)
        else:
            o = lat_o if i == 1 else dup(lat_o, "ST_Lateral_Drawers_%d" % (i // 2 + 1), furn, (x, GY0 + 0.25, 0), FACE_N)
            label("ST_Label_South_%d" % (i + 1), names_s[i], lab, place((x, GY0 + 0.25, 1.4), FACE_N, (0, -0.2, 0)), FACE_N, 0.04)

    # cardboard boxes on top of the cabinets
    boxes = Item("ST_Boxes_On_Top")
    for i, (x, w, h) in enumerate(((-0.4, 0.5, 0.35), (0.2, 0.45, 0.3), (1.1, 0.6, 0.4), (2.1, 0.4, 0.28), (3.3, 0.55, 0.38), (4.4, 0.5, 0.3))):
        boxes.box((w, 0.45, h), (x, 0, 2.0 + h / 2), CARDBOARD)
        boxes.box((w * 0.5, 0.004, 0.08), (x, -0.227, 2.0 + h * 0.6), LABEL)
        boxes.box((w + 0.005, 0.06, 0.004), (x, 0, 2.0 + h + 0.002), mat("OF | packing tape", (0.75, 0.62, 0.38), 0.5))
    boxes.build(lab, loc=(-20.05, GY1 - 0.28, 0), rz=FACE_S)

    # central drawer island with a worktop (drawers on both long sides)
    isl = Item("ST_Drawer_Island")
    W, D, H = 2.6, 0.9, 0.88
    isl.box((W, D - 0.04, H - 0.04), (0, 0, (H - 0.04) / 2), STEEL_CAB)
    isl.box((W + 0.04, D + 0.04, 0.04), (0, 0, H - 0.02), OAK)
    for side in (-1, 1):
        for k in range(4):
            for r in range(3):
                x = -W / 2 + 0.33 + k * 0.65
                z = 0.17 + r * 0.26
                isl.box((0.62, 0.015, 0.24), (x, side * (D / 2 - 0.01), z), STEEL_CAB_BLUE if r == 2 else STEEL_CAB)
                isl.box((0.2, 0.02, 0.018), (x, side * (D / 2 + 0.005), z + 0.07), HANDLE)
                isl.box((0.1, 0.004, 0.04), (x, side * (D / 2 + 0.001), z - 0.04), LABEL)
    isl.build(furn, loc=(-17.4, 33.75, 0), collide=True, note="Drawer island with worktop")
    it = Item("ST_Island_Items")
    it.box((0.4, 0.3, 0.18), (-0.8, 0.05, 0.97), CARDBOARD)                     # boxed switch
    it.box((0.3, 0.004, 0.08), (-0.8, -0.102, 0.98), LABEL)
    it.cyl(0.15, 0.1, (-0.1, 0.0, 0.93), CABLE_BLUE, seg=24)                    # LAN cable roll
    it.cyl(0.06, 0.102, (-0.1, 0.0, 0.93), CARDBOARD, seg=16)
    it.box((0.2, 0.06, 0.03), (0.35, -0.15, 0.895), base.SIGN_YELLOW)           # crimping tool
    it.box((0.12, 0.08, 0.04), (0.35, 0.1, 0.9), DARK)                          # cable tester
    it.box((0.04, 0.03, 0.004), (0.35, 0.08, 0.922), LED_GREEN)
    it.box((0.3, 0.2, 0.04), (0.9, 0.0, 0.9), DRAWER_BIN)                       # tray of RJ45 plugs
    for i in range(10):
        it.box((0.015, 0.02, 0.012), (0.8 + (i % 5) * 0.045, -0.05 + (i // 5) * 0.08, 0.926), GLASSWARE)
    it.build(lab, loc=(-17.4, 33.75, 0))

    # east wall (south of the door swing): cable reel rack
    rr = Item("ST_Cable_Reel_Rack")
    for z in (0.05, 0.75, 1.45):
        rr.box((2.9, 0.5, 0.03), (0, 0, z), LEG_DARK)
    for sx in (-1.43, 0, 1.43):
        rr.box((0.04, 0.5, 1.75), (sx, 0, 0.875), LEG_DARK)
    cols = [CABLE_BLUE, CABLE_YELLOW, base.SIGN_GREEN, WHITE, CABLE_BLUE, SIGN_RED]
    for lvl, z in enumerate((0.07, 0.77)):
        for k in range(4):
            x = -1.05 + k * 0.7
            rr.box((0.36, 0.36, 0.34), (x, 0, z + 0.17), CARDBOARD)              # boxed CAT6 305 m
            rr.box((0.2, 0.004, 0.08), (x, -0.182, z + 0.2), cols[(k + lvl) % 6])
    for k in range(5):
        x = -1.15 + k * 0.57
        rr.cyl(0.2, 0.12, (x, 0, 1.68), cols[k], seg=20, rx=PI / 2)              # cable reels
        rr.cyl(0.06, 0.13, (x, 0, 1.68), CARDBOARD, seg=12, rx=PI / 2)
    rr.build(furn, loc=(GX1 - 0.26, 32.75, 0), rz=FACE_W, collide=True, note="Cable reel rack")
    label("ST_Label_Reels", "สายสัญญาณ CAT6 / ม้วนสาย", lab, place((GX1 - 0.26, 32.75, 1.98), FACE_W, (0, -0.26, 0)), FACE_W, 0.045)
    fire_extinguisher("ST_Fire_Extinguisher", lab, (GX1 - 0.12, 34.65, 0.55))
    text("ST_Room_Title", "ห้องเก็บอุปกรณ์ IT  ·  กรุณาลงชื่อเบิก-คืนทุกครั้ง", lab, (-17.0, GY0 + 0.02, 2.35), 0.07, NAVY, rot=(PI / 2, 0, FACE_N))
    cl = Item("ST_Clipboard_Log")
    cl.box((0.24, 0.015, 0.33), (0, 0, 0), WALNUT)
    cl.box((0.21, 0.004, 0.28), (0, -0.01, -0.01), PAPER)
    cl.box((0.08, 0.02, 0.03), (0, -0.01, 0.15), STEEL)
    cl.build(lab, loc=(GX1 - 0.02, 34.4, 1.45), rz=FACE_W)


# ============================================================ teachers' room

# x -6.0 .. 6.0, y 9.9 .. 30.44. Corridor door on the west wall, y 25.13..26.29 (opens inwards).
TX0, TX1, TY0, TY1 = -5.98, 5.98, 9.92, 30.42
TEACHER_DESKS = [
    # name, desk centre, rz (user side), partition owner
    ("StaffPC_1", (TX1 - 0.4, 28.0), FACE_W),     # NE office behind the long partition
    ("StaffPC_2", (TX1 - 0.4, 21.45), FACE_W),    # cubicle 2
    ("StaffPC_3", (TX1 - 0.4, 16.8), FACE_W),     # cubicle 3
    ("StaffPC_4", (TX1 - 0.4, 12.2), FACE_W),     # cubicle 4 (south-east)
    ("StaffPC_5", (0.9, TY0 + 0.4), FACE_N),      # south wall desk
]


def partition(name, coll, length, h=1.5, loc=(0, 0, 0), rz=0.0, glass_top=True):
    """Fabric office partition (thin along Y), collider."""
    p = Item(name)
    p.box((length, 0.05, h), (0, 0, h / 2 + 0.03), PARTITION)
    p.box((length + 0.02, 0.06, 0.035), (0, 0, h + 0.045), PARTITION_TRIM)
    for sx in (-length / 2, length / 2):
        p.box((0.06, 0.07, h + 0.06), (sx, 0, (h + 0.06) / 2), PARTITION_TRIM)
    p.box((length, 0.06, 0.03), (0, 0, 0.015), PARTITION_TRIM)
    if glass_top:
        p.box((length - 0.04, 0.012, 0.3), (0, 0, h + 0.21), GLASSWARE)
        p.box((length + 0.02, 0.05, 0.025), (0, 0, h + 0.37), PARTITION_TRIM)
    return p.build(coll, loc=loc, rz=rz, collide=True, note="Office partition")


def build_teachers_room(c):
    work = collection("19.1 | Teacher workstations", c)
    furn = collection("19.2 | Lounge, pantry and storage", c)
    wall = collection("19.3 | Wall boards and signs", c)
    small = collection("19.4 | Small items", c)

    # partitions as on the floor plan: long one from the north wall, short cubicle walls on the east
    partition("TR_Partition_Office_Long", furn, 4.5, h=1.7, loc=(3.0, TY1 - 2.25, 0), rz=PI / 2)
    partition("TR_Partition_Office_Front", furn, 1.2, h=1.7, loc=(3.6, TY1 - 4.5, 0), rz=0.0)
    for i, y in enumerate((23.7, 19.1, 14.5)):
        partition("TR_Partition_Cubicle_%d" % (i + 1), furn, 1.75, loc=(TX1 - 0.875, y, 0), rz=0.0)
    partition("TR_Partition_Desk5_Side", furn, 1.0, h=1.3, loc=(2.0, TY0 + 0.5, 0), rz=PI / 2, glass_top=False)

    # five teacher workstations (desk + computer + usable screen + chair + items)
    desk_src = office_desk("TR_Teacher_Desk_1", w=1.5, d=0.75).build(work, loc=(0, 0, 0), collide=True, note="Teacher desk")
    pc_even = computer_set("TR_Computer_A", 0).build(work)
    pc_odd = computer_set("TR_Computer_B", 1).build(work)
    for i, (name, (x, y), rz) in enumerate(TEACHER_DESKS):
        if i == 0:
            desk_src.location = (x, y, 0)
            desk_src.rotation_euler.z = rz
        else:
            dup(desk_src, "TR_Teacher_Desk_%d" % (i + 1), work, (x, y, 0), rz)
        pc = pc_even if i == 0 else (pc_odd if i == 1 else None)
        if pc is not None:
            pc.location = (x, y, 0.75)
            pc.rotation_euler.z = rz
            pc.name = "TR_Computer_%d" % (i + 1)
        else:
            dup(pc_even if i % 2 == 0 else pc_odd, "TR_Computer_%d" % (i + 1), work, (x, y, 0.75), rz)
        make_screen(name + "_Monitor_Display_Surface", work, (x, y, 0), rz, 0.75, local_xy=(0.0, 0.162))
        office_chair("TR_Chair_%d" % (i + 1), work, place((x, y, 0), rz, (-0.1, -0.75, 0)), rz + PI)
        desk_items("TR_Desk_Items_%d" % (i + 1), small, (x, y, 0), rz, 0.75, i)

    # shelves above the cubicle desks (on the partitions) and name plates
    shelf = Item("TR_Cubicle_Shelf")
    shelf.box((1.2, 0.3, 0.02), (0, 0, 0), WHITE_LAM)
    shelf.box((0.02, 0.3, 0.2), (-0.6, 0, -0.1), LEG_WHITE)
    shelf.box((0.02, 0.3, 0.2), (0.6, 0, -0.1), LEG_WHITE)
    for k in range(9):
        shelf.box((0.04, 0.22, 0.24 - 0.015 * (k % 3)), (-0.5 + k * 0.05, 0.0, 0.13), BOOKS[k % 6])
    shelf.box((0.3, 0.22, 0.12), (0.35, 0.0, 0.07), CARDBOARD)
    shelf_o = shelf.build(small, loc=(TX1 - 0.18, 28.0, 1.45), rz=FACE_W)
    for i, y in enumerate((21.45, 16.8, 12.2)):
        dup(shelf_o, "TR_Cubicle_Shelf_%d" % (i + 2), small, (TX1 - 0.18, y, 1.45), FACE_W)
    for i, (name, (x, y), rz) in enumerate(TEACHER_DESKS):
        nm = place((x, y, 0), rz, (0.55, -0.37, 0))
        text("TR_Desk_Name_%d" % (i + 1), "STAFF-PC-%02d" % (i + 1), small, (nm[0], nm[1], 0.80), 0.03, NAVY, rot=(PI / 2, 0, rz))

    # NE office extras: guest chair, bookcase, plant, framed certificate
    office_chair("TR_Guest_Chair_1", furn, (4.55, 26.75, 0), FACE_N, FABRIC_CHAIR_RED)
    bookcase("TR_Office_Bookcase", w=1.6, d=0.36, h=2.0, body=WALNUT, shelves=5, seed=5).build(furn, loc=(4.6, TY1 - 0.2, 0), rz=FACE_S, collide=True)
    plant("TR_Plant_Office", furn, (3.4, TY1 - 0.4, 0), h=1.3)
    framed("TR_Office_Certificate", wall, (TX1 - 0.02, 28.0, 1.95), FACE_W, 0.5, 0.36, base.SIGN_GREEN)

    # ---- lounge corner (north-west, away from the door swing): L-sofa, coffee table, rug
    rug = Item("TR_Rug")
    rug.box((3.0, 2.2, 0.012), (0, 0, 0.006), RUG)
    rug.box((2.8, 2.0, 0.013), (0, 0, 0.0065), mat("OF | rug inner", (0.55, 0.50, 0.46), 0.95))
    rug.build(furn, loc=(-4.2, 28.7, 0))
    # L-shaped sofa as two pieces, so each gets its own box collider (an L in one
    # box would also block the floor inside the L where the coffee table stands)
    sofa = Item("TR_Sofa_Main")
    sofa.box((2.6, 0.85, 0.42), (0, 0, 0.21), SOFA)                              # seat base along the north wall
    sofa.box((2.6, 0.22, 0.45), (0, 0.32, 0.63), SOFA)                           # back
    sofa.box((0.2, 0.85, 0.6), (1.4, 0, 0.3), SOFA)                              # arm
    for i, x in enumerate((-0.6, 0.1, 0.8)):
        sofa.box((0.62, 0.62, 0.12), (x, -0.08, 0.48), SOFA)
        sofa.box((0.42, 0.14, 0.38), (x, 0.17, 0.72), CUSHION if i % 2 == 0 else SOFA, rx=-0.2)
    sofa.build(furn, loc=(-4.6, TY1 - 0.45, 0), collide=True, note="Sofa")
    ch = Item("TR_Sofa_Chaise")
    ch.box((0.85, 1.5, 0.42), (0, 0, 0.21), SOFA)                               # chaise along the west wall
    ch.box((0.22, 1.5, 0.45), (-0.315, 0, 0.63), SOFA)
    ch.box((0.85, 0.2, 0.6), (0, -0.75, 0.3), SOFA)
    ch.box((0.62, 1.3, 0.12), (0, 0.02, 0.48), SOFA)
    ch.box((0.14, 0.42, 0.38), (-0.18, 0.2, 0.72), CUSHION, rz=0.0, ry=0.2)
    ch.build(furn, loc=(-4.6 - 0.875, TY1 - 0.45 - 1.17, 0), collide=True, note="Sofa chaise")
    ct = Item("TR_Coffee_Table")
    ct.box((1.1, 0.6, 0.035), (0, 0, 0.42), WALNUT)
    ct.box((1.0, 0.5, 0.02), (0, 0, 0.12), WALNUT)
    for sx in (-0.5, 0.5):
        for sy in (-0.25, 0.25):
            ct.box((0.04, 0.04, 0.42), (sx, sy, 0.21), LEG_DARK)
    ct.cyl(0.04, 0.1, (0.3, 0.1, 0.49), MUG, seg=12)
    ct.cyl(0.04, 0.1, (0.15, -0.1, 0.49), MUG_RED, seg=12)
    ct.box((0.3, 0.22, 0.02), (-0.25, 0.0, 0.448), BOOKS[3])
    ct.cyl(0.12, 0.03, (-0.2, 0.0, 0.14), GLASSWARE, seg=16)
    ct.build(furn, loc=(-4.0, 28.6, 0), collide=True)
    plant("TR_Plant_Lounge", furn, (-1.95, TY1 - 0.35, 0), h=1.4)
    framed("TR_Lounge_Picture", wall, (-4.4, TY1 - 0.02, 1.75), FACE_S, 1.2, 0.7, mat("OF | painting landscape", (0.35, 0.55, 0.62), 0.8), LEG_DARK)

    # ---- pantry along the north wall, between the lounge and the long partition
    pk = Item("TR_Pantry_Counter")
    L = 2.72
    pk.box((L, 0.6, 0.86), (0, 0, 0.43), WHITE_LAM)
    pk.box((L + 0.02, 0.63, 0.04), (0, -0.01, 0.88), COUNTER_TOP)
    for k in range(4):
        x = -L / 2 + 0.34 + k * 0.68
        pk.box((0.66, 0.015, 0.76), (x, -0.305, 0.43), WHITE_LAM)
        pk.box((0.02, 0.025, 0.16), (x + 0.26, -0.32, 0.65), HANDLE)
    pk.box((L, 0.02, 0.6), (0, 0.29, 1.2), TILE_SPLASH)                          # splashback
    pk.box((L, 0.35, 0.7), (0, 0.13, 2.05), WHITE_LAM)                           # wall cabinets
    for k in range(4):
        x = -L / 2 + 0.34 + k * 0.68
        pk.box((0.66, 0.015, 0.66), (x, -0.05, 2.05), WHITE_LAM)
        pk.box((0.02, 0.025, 0.14), (x + 0.26, -0.065, 1.8), HANDLE)
    pk.build(furn, loc=(0.51, TY1 - 0.3, 0), collide=True, note="Pantry counter")
    pa = Item("TR_Pantry_Appliances")
    pa.box((0.55, 0.4, 0.02), (-0.8, -0.02, 0.905), STEEL)                       # sink
    pa.box((0.45, 0.32, 0.02), (-0.8, -0.02, 0.89), DARK)
    pa.cyl(0.015, 0.3, (-0.8, 0.18, 1.05), base.CHROME, seg=8)
    pa.box((0.03, 0.18, 0.03), (-0.8, 0.1, 1.2), base.CHROME)
    pa.box((0.5, 0.38, 0.3), (0.05, 0.0, 1.05), APPLIANCE_STEEL)                  # microwave
    pa.box((0.32, 0.01, 0.2), (0.0, -0.195, 1.05), DARK)
    pa.box((0.06, 0.01, 0.05), (0.23, -0.195, 1.12), LED_GREEN)
    pa.box((0.22, 0.28, 0.36), (0.55, 0.02, 1.08), DARK)                          # coffee machine
    pa.cyl(0.04, 0.1, (0.55, -0.08, 0.95), MUG, seg=12)
    pa.cyl(0.09, 0.22, (0.98, 0.0, 1.01), APPLIANCE_STEEL, r2=0.07, seg=16)      # kettle
    pa.box((0.25, 0.18, 0.12), (-0.4, 0.12, 0.96), mat("OF | dish rack", (0.80, 0.82, 0.84), 0.4))
    pa.build(small, loc=(0.51, TY1 - 0.3, 0))
    fr = Item("TR_Fridge")
    fr.box((0.7, 0.68, 1.8), (0, 0, 0.9), FRIDGE)
    fr.box((0.68, 0.012, 1.15), (0, -0.345, 0.6), FRIDGE)
    fr.box((0.68, 0.012, 0.58), (0, -0.345, 1.5), FRIDGE)
    fr.box((0.03, 0.03, 0.4), (-0.28, -0.365, 0.95), APPLIANCE_STEEL)
    fr.box((0.03, 0.03, 0.25), (-0.28, -0.365, 1.38), APPLIANCE_STEEL)
    fr.build(furn, loc=(2.27, TY1 - 0.36, 0), collide=True, note="Fridge")
    wdp = Item("TR_Water_Dispenser")
    wdp.box((0.32, 0.32, 1.0), (0, 0, 0.5), WHITE)
    wdp.cyl(0.13, 0.42, (0, 0, 1.22), WATER, seg=16)
    wdp.box((0.025, 0.02, 0.03), (-0.05, -0.17, 0.82), SIGN_RED)
    wdp.box((0.025, 0.02, 0.03), (0.05, -0.17, 0.82), LED_BLUE)
    wdp.build(furn, loc=(-1.25, TY1 - 0.22, 0), collide=True)
    text("TR_Pantry_Sign", "มุมเครื่องดื่ม · กรุณาล้างแก้วหลังใช้งาน", wall, (0.51, TY1 - 0.02, 2.55), 0.06, NAVY, rot=(PI / 2, 0, FACE_S))

    # ---- meeting table in the middle of the room
    mr = Item("TR_Meeting_Rug")
    mr.box((3.0, 4.6, 0.012), (0, 0, 0.006), mat("OF | rug blue-grey", (0.30, 0.36, 0.42), 0.95))
    mr.box((2.8, 4.4, 0.013), (0, 0, 0.0065), mat("OF | rug blue-grey inner", (0.38, 0.44, 0.50), 0.95))
    mr.build(furn, loc=(-1.0, 18.6, 0))
    mt = Item("TR_Meeting_Table")
    mt.box((1.2, 3.2, 0.04), (0, 0, 0.74), OAK)
    for sy in (-1.3, 1.3):
        mt.box((1.0, 0.08, 0.04), (0, sy, 0.02), LEG_DARK)
        mt.box((0.08, 0.08, 0.7), (0, sy, 0.37), LEG_DARK)
    mt.box((0.08, 2.6, 0.06), (0, 0, 0.65), LEG_DARK)
    mt.build(furn, loc=(-1.0, 18.6, 0), collide=True, note="Meeting table")
    mi = Item("TR_Meeting_Table_Items")
    for i, (x, y, r) in enumerate(((-0.3, -1.1, 0.2), (0.25, -0.2, -0.3), (-0.2, 0.7, 0.1), (0.3, 1.2, 0.5))):
        mi.box((0.21, 0.29, 0.004), (x, y, 0.762), PAPER, rz=r)
    mi.box((0.33, 0.24, 0.02), (0.2, 0.5, 0.77), DARK)                            # laptop
    mi.box((0.33, 0.015, 0.22), (0.2, 0.62, 0.87), DARK, rx=-0.3)
    mi.box((0.30, 0.004, 0.19), (0.2, 0.61, 0.87), SCREEN_ON, rx=-0.3)
    mi.cyl(0.1, 0.06, (-0.1, 0.0, 0.79), GLASSWARE, seg=16)                       # water jug tray
    mi.cyl(0.05, 0.22, (-0.1, 0.0, 0.87), WATER, seg=12)
    mi.build(small, loc=(-1.0, 18.6, 0))
    for side in (-1, 1):
        for k in range(4):
            y = 18.6 - 1.2 + k * 0.8
            office_chair("TR_Meeting_Chair_%s%d" % ("W" if side < 0 else "E", k + 1), furn, (-1.0 + side * 0.85, y, 0), FACE_E if side < 0 else FACE_W)
    office_chair("TR_Meeting_Chair_Head", furn, (-1.0, 18.6 + 2.0, 0), FACE_S)

    # ---- west wall (south of the door): lockers, pigeon-hole mailboxes, bookcase
    lk = Item("TR_Lockers")
    n = 6
    for k in range(n):
        x = -1.0 + k * 0.4 + 0.2 - 0.2
        lk.box((0.39, 0.45, 1.85), (x - 0.0, 0, 0.925), LOCKER)
        for r in range(2):
            z = 0.47 + r * 0.92
            lk.box((0.36, 0.012, 0.88), (x, -0.226, z), LOCKER)
            lk.box((0.02, 0.025, 0.1), (x + 0.13, -0.24, z + 0.1), HANDLE)
            lk.box((0.1, 0.004, 0.04), (x, -0.233, z + 0.33), LABEL)
            for v in range(3):
                lk.box((0.18, 0.004, 0.012), (x, -0.233, z + 0.2 - v * 0.03), PORT)
    lk.build(furn, loc=(TX0 + 0.23, 21.5, 0), rz=FACE_E, collide=True, note="Teacher lockers")
    text("TR_Lockers_Sign", "ตู้ล็อกเกอร์ครู", wall, (TX0 + 0.02, 21.5, 2.15), 0.07, NAVY, rot=(PI / 2, 0, FACE_E))
    mb = Item("TR_Mailboxes")
    mb.box((1.2, 0.35, 0.9), (0, 0, 0.45), WALNUT)
    for r in range(4):
        for k in range(5):
            x = -0.48 + k * 0.24
            z = 0.12 + r * 0.21
            mb.box((0.22, 0.02, 0.19), (x, -0.165, z + 0.06), DARK)
            if (r + k) % 3 == 0:
                mb.box((0.18, 0.004, 0.06), (x, -0.17, z + 0.02), PAPER)
            mb.box((0.08, 0.004, 0.025), (x, -0.176, z + 0.16), LABEL)
    mb.box((1.22, 0.37, 0.03), (0, 0, 0.915), OAK)
    mb.build(furn, loc=(TX0 + 0.19, 19.35, 0), rz=FACE_E, collide=True, note="Pigeon-hole mailboxes")
    text("TR_Mailbox_Sign", "ช่องรับเอกสารครู", wall, (TX0 + 0.02, 19.35, 1.45), 0.05, NAVY, rot=(PI / 2, 0, FACE_E))
    bookcase("TR_Bookcase_West", w=1.6, d=0.36, h=2.0, body=OAK, shelves=5, seed=21).build(furn, loc=(TX0 + 0.19, 17.3, 0), rz=FACE_E, collide=True)

    nb = wall_board("TR_Notice_Board", 2.0, 1.1, kind="cork")
    pinned_notes(nb, 2.0, 1.1, 12)
    nb.build(wall, loc=(TX0 + 0.02, 14.2, 1.55), rz=FACE_E)
    text("TR_Notice_Title", "ป้ายประกาศ / ข่าวสารวิทยาลัย", wall, (TX0 + 0.04, 14.2, 2.22), 0.07, INK, rot=(PI / 2, 0, FACE_E))
    plant("TR_Plant_West", furn, (TX0 + 0.35, 15.6, 0), h=1.3)

    # ---- south wall: copier, filing cabinets, timetable board, clock
    cp = bpy.data.objects.get("IT_Copier")
    if cp:
        dup(cp, "TR_Copier", furn, (TX0 + 0.45, TY0 + 0.4, 0), FACE_N)
    fc = drawer_cabinet("TR_Filing_Cabinet_1", w=0.47, d=0.62, h=1.32, rows=4, cols=1, body=STEEL_CAB)
    fc_o = fc.build(furn, loc=(-4.5, TY0 + 0.32, 0), rz=FACE_N, collide=True, note="Filing cabinet")
    for k in range(1, 4):
        dup(fc_o, "TR_Filing_Cabinet_%d" % (k + 1), furn, (-4.5 + k * 0.5, TY0 + 0.32, 0), FACE_N)
    for k, nm in enumerate(("แผนการสอน", "ใบงาน", "ทะเบียน", "พัสดุ")):
        label("TR_Filing_Label_%d" % (k + 1), nm, small, place((-4.5 + k * 0.5, TY0 + 0.32, 1.2), FACE_N, (0, -0.33, 0)), FACE_N, 0.035)
    tb = wall_board("TR_Timetable_Board", 2.4, 1.1)
    for r in range(6):
        tb.box((2.2, 0.003, 0.006), (0, -0.012, 0.42 - r * 0.15), INK)
    for k in range(7):
        tb.box((0.006, 0.003, 0.8), (-1.08 + k * 0.36, -0.012, 0.02), INK)
    for i in range(14):
        tb.box((0.3, 0.003, 0.1), (-0.9 + (i % 6) * 0.36, -0.013, 0.34 - (i // 6) * 0.15 - (i % 2) * 0.15), NOTE_COLORS[i % 4])
    tb.build(wall, loc=(-3.0, TY0 + 0.02, 1.65), rz=FACE_N)
    text("TR_Timetable_Title", "ตารางสอน ภาคเรียนที่ 2", wall, (-3.0, TY0 + 0.04, 2.33), 0.07, INK, rot=(PI / 2, 0, FACE_N))
    wall_clock("TR_Clock", wall, (0.9, TY0 + 0.03, 2.05), FACE_N)
    calendar = Item("TR_Calendar")
    calendar.box((0.4, 0.01, 0.55), (0, 0, 0), PAPER)
    calendar.box((0.4, 0.012, 0.18), (0, 0, 0.18), mat("OF | calendar photo", (0.30, 0.55, 0.75), 0.7))
    for r in range(4):
        for k in range(7):
            calendar.box((0.04, 0.012, 0.03), (-0.16 + k * 0.053, -0.002, 0.03 - r * 0.07), SIGN_RED if k == 0 else DARK)
    calendar.build(wall, loc=(TX0 + 0.02, 24.0, 1.6), rz=FACE_E)

    # ---- east wall of the open room, room sign, ACs, plants, umbrella stand
    split_ac("TR_Split_AC_1", wall, (TX0 + 0.14, 16.0, 2.72), FACE_E)
    split_ac("TR_Split_AC_2", wall, (TX0 + 0.14, 28.4, 2.72), FACE_E)
    split_ac("TR_Split_AC_3", wall, (TX1 - 0.14, 18.9, 2.72), FACE_W)
    plant("TR_Plant_Center_1", furn, (2.9, 23.4, 0), h=1.25)
    plant("TR_Plant_Center_2", furn, (2.9, 14.0, 0), h=1.1)
    plant("TR_Plant_SW", furn, (-2.3, TY0 + 0.35, 0), h=1.0)
    us = Item("TR_Umbrella_Stand")
    us.cyl(0.13, 0.5, (0, 0, 0.25), LEG_DARK, seg=16)
    for i, m in enumerate((NAVY, SIGN_RED, base.SIGN_GREEN)):
        us.cyl(0.012, 0.85, (math.cos(i * 2.1) * 0.05, math.sin(i * 2.1) * 0.05, 0.45), m, seg=6, rx=0.08 * (i - 1))
    us.build(furn, loc=(TX0 + 0.25, 24.55, 0))
    welcome = Item("TR_Welcome_Panel")
    welcome.box((2.4, 0.03, 0.42), (0, 0, 0), mat("OF | panel sage", (0.36, 0.52, 0.45), 0.6))
    welcome.build(wall, loc=(-1.0, TY0 + 0.02, 2.95 - 0.3), rz=FACE_N)
    text("TR_Welcome_TH", "ห้องพักครู แผนกวิชาคอมพิวเตอร์", wall, (-1.0 + 0.0, TY0 + 0.04, 2.66), 0.1, SIGN_TEXT, rot=(PI / 2, 0, FACE_N))
    text("TR_Welcome_EN", "TEACHERS' ROOM", wall, (-1.0, TY0 + 0.04, 2.52), 0.06, SIGN_TEXT, rot=(PI / 2, 0, FACE_N))


# ============================================================ main

def main():
    for name in (IT_NAME, ST_NAME, TR_NAME):
        remove_collection(name)
    it = collection(IT_NAME)
    st = collection(ST_NAME)
    tr = collection(TR_NAME)
    build_it_room(it)
    retitle_it_room()
    build_storage(st)
    build_teachers_room(tr)
    built = [o for coll in (it, st, tr) for o in coll.all_objects if o.type == "MESH"]
    screens = [o.name for o in built if "Monitor_Display_Surface" in o.name]
    print("BUILT_OBJECTS", len(built), "COLLIDERS", sum(1 for o in built if o.get("collision") == "box"),
          "SCREENS", screens, flush=True)

    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = args[args.index("--save") + 1] if "--save" in args else bpy.data.filepath
    bpy.ops.wm.save_as_mainfile(filepath=out, compress=True)
    print("SAVED", out, flush=True)


if __name__ == "__main__":
    main()
