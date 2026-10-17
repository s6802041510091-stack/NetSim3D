"""NetLife3D - 48-port Gigabit switch, 1U rack mount (stage 1 equipment, stage 4 broken ports).

Ports: top row = odd (1,3,...,47), bottom row = even (2,...,48), 4 blocks of 12.
Each port: Port_XX (plug point empty) + LED_Port_XX (own mesh, recoloured from code).
Run:  python3 switch48.py [--no-render]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import bpy  # noqa: E402

NAME = "switch_48port"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", NAME)
os.makedirs(OUT, exist_ok=True)
SCENE = C.reset_scene()

W, D, H = 0.440, 0.230, 0.044
FRONT = -D / 2
PITCH = 0.0140
BLOCK_GAP = 0.006
ROW_Z = (0.0300, 0.0145)          # top row, bottom row centre heights
OPEN_W, OPEN_H, OPEN_D = 0.0118, 0.0083, 0.016
X0 = -0.155                       # centre of first column

case_m = C.mat("Metal_Case", (0.10, 0.105, 0.115), metallic=0.85, rough=0.42)
face_m = C.mat("Plastic_Face", (0.035, 0.037, 0.042), rough=0.5)
shield_m = C.mat("Metal_Shield", (0.62, 0.63, 0.65), metallic=1.0, rough=0.3)
jack_m = C.mat("Plastic_Jack", (0.012, 0.012, 0.014), rough=0.7)
pin_m = C.mat("Metal_Gold", (1.0, 0.76, 0.33), metallic=1.0, rough=0.25)
ink_m = C.mat("Ink_White", (0.85, 0.86, 0.88), rough=0.5)
brand_m = C.mat("Ink_Brand", (0.95, 0.45, 0.08), rough=0.45)
led_off = C.mat("LED_Green_Off", (0.04, 0.16, 0.06), rough=0.15, coat=0.5)
ear_m = C.mat("Metal_Ear", (0.10, 0.105, 0.115), metallic=0.85, rough=0.42)
vent_m = C.mat("Vent_Dark", (0.01, 0.01, 0.01), rough=0.9)


def col_x(c):
    """x centre of column c (0..23)."""
    return X0 + c * PITCH + (c // 6) * BLOCK_GAP


def port_pos(n):
    """port number 1..48 -> (x, z, is_top)"""
    c = (n - 1) // 2
    top = n % 2 == 1
    return col_x(c), ROW_Z[0] if top else ROW_Z[1], top


def build():
    root = C.empty("Switch48", size=0.1)
    ports = C.empty("Ports", parent=root, size=0.02)
    leds_grp = C.empty("PortLEDs", parent=root, size=0.02)

    # ---------- case + front face
    case = C.box("_case", (W, D, H), (0, 0, H / 2), case_m, bev=0.0015, segs=2)
    face = C.box("_face", (W - 0.004, 0.003, H - 0.004), (0, FRONT - 0.0005, H / 2), face_m, bev=0.0008)
    # jack blocks (metal shields) protruding slightly
    blocks = []
    for b in range(4):
        xa, xb = col_x(b * 6) - PITCH / 2 + 0.0008, col_x(b * 6 + 5) + PITCH / 2 - 0.0008
        blocks.append(C.box(f"_block{b}", (xb - xa, 0.020, 0.0315), ((xa + xb) / 2, FRONT + 0.0075, 0.0222),
                            shield_m, bev=0.0006))
    # openings: one combined cutter for all 48 ports (+ latch notches)
    cutters = []
    for n in range(1, 49):
        x, z, top = port_pos(n)
        cutters.append(C.box(f"_c{n}", (OPEN_W, OPEN_D + 0.006, OPEN_H), (x, FRONT + OPEN_D / 2 - 0.004, z), None))
        nz = z + (OPEN_H / 2 + 0.0010) * (1 if top else -1)
        cutters.append(C.box(f"_n{n}", (0.0064, OPEN_D + 0.006, 0.0030), (x, FRONT + OPEN_D / 2 - 0.004, nz), None))
    # console port (RJ-45) on the right
    cx = 0.205
    cutters.append(C.box("_console", (OPEN_W, OPEN_D + 0.006, OPEN_H), (cx, FRONT + OPEN_D / 2 - 0.004, 0.022), None))
    bpy.ops.object.select_all(action="DESELECT")
    for c in cutters:
        c.select_set(True)
    bpy.context.view_layer.objects.active = cutters[0]
    bpy.ops.object.join()
    cutter = bpy.context.active_object
    targets = [case, face] + blocks
    for t in targets:
        dup = cutter.copy()
        dup.data = cutter.data.copy()
        bpy.context.scene.collection.objects.link(dup)
        C.cut(t, dup)
    bpy.data.objects.remove(cutter, do_unlink=True)

    parts = [case, face] + blocks
    # liners + contact pins inside each opening
    for n in range(1, 49):
        x, z, top = port_pos(n)
        parts.append(C.box(f"_liner{n}", (OPEN_W + 0.0004, 0.001, OPEN_H + 0.0006), (x, FRONT + OPEN_D - 0.003, z), jack_m))
        pz = z + (OPEN_H / 2 - 0.0007) * (-1 if top else 1)
        for i in range(8):
            parts.append(C.box(f"_pin{n}_{i}", (0.00045, 0.007, 0.0006),
                               (x + (i - 3.5) * 0.00102, FRONT + OPEN_D - 0.008, pz), pin_m))
    parts.append(C.box("_cliner", (OPEN_W + 0.0004, 0.001, OPEN_H + 0.0006), (cx, FRONT + OPEN_D - 0.003, 0.022), jack_m))

    # ---------- labels
    TF = FRONT - 0.0021     # just in front of the face
    rot = (math.pi / 2, 0, 0)
    parts.append(C.text("_brand", "NetCare", (-0.213, TF, 0.031), 0.0062, brand_m, rot=rot, align="LEFT"))
    parts.append(C.text("_model", "NC-S48G", (-0.213, TF, 0.0235), 0.0042, ink_m, rot=rot, align="LEFT"))
    parts.append(C.text("_desc", "48-Port Gigabit", (-0.213, TF, 0.0185), 0.0020, ink_m, rot=rot, align="LEFT"))
    parts.append(C.text("_lpwr", "PWR", (-0.205, TF, 0.0085), 0.0022, ink_m, rot=rot))
    parts.append(C.text("_lsys", "SYS", (-0.193, TF, 0.0085), 0.0022, ink_m, rot=rot))
    parts.append(C.text("_lcon", "CONSOLE", (cx, TF, 0.0320), 0.0022, ink_m, rot=rot))
    for n in range(1, 49):
        x, z, top = port_pos(n)
        lz = 0.0242 if top else 0.0201
        parts.append(C.text(f"_num{n}", str(n), (x - 0.0035, FRONT - 0.0026, lz), 0.0021, C.mat("Ink_Dark", (0.03, 0.03, 0.035), rough=0.6), rot=rot))
    # rack ears with mounting holes
    for s in (-1, 1):
        ear = C.box(f"_ear{s}", (0.022, 0.002, H - 0.002), (s * (W / 2 + 0.011), FRONT + 0.001, H / 2), ear_m, bev=0.0006)
        holes = [C.cyl(f"_h{s}{k}", 0.0032, 0.01, (s * (W / 2 + 0.012), FRONT + 0.001, zz), None,
                       rot=(math.pi / 2, 0, 0), verts=20) for k, zz in enumerate((0.0115, 0.0325))]
        C.cut(ear, holes)
        parts.append(ear)
        parts.append(C.box(f"_earside{s}", (0.002, 0.030, H - 0.004), (s * (W / 2 + 0.001), FRONT + 0.016, H / 2), ear_m))
    # side vents + rear power socket
    for s in (-1, 1):
        for k in range(10):
            parts.append(C.box(f"_vent{s}{k}", (0.0006, 0.004, 0.024), (s * (W / 2 + 0.0002), -0.04 + k * 0.009, H / 2), vent_m))
    parts.append(C.box("_iec", (0.028, 0.004, 0.022), (0.17, D / 2 + 0.0015, H / 2), vent_m, bev=0.002))
    parts.append(C.text("_top", "NetCare  NC-S48G", (0, 0.02, H + 0.0001), 0.010, C.mat("Ink_Grey", (0.3, 0.31, 0.33), rough=0.5)))

    body = C.join("Switch_Body", parts)
    C.reparent([body], root)

    # ---------- LEDs + plug points
    led_objs, port_objs = [], []
    for n in range(1, 49):
        x, z, top = port_pos(n)
        lz = z + (0.0058 if top else -0.0058)
        led_objs.append(C.box(f"LED_Port_{n:02d}", (0.0026, 0.0008, 0.0014), (x + 0.0047, FRONT - 0.0029, lz), led_off))
        # insertion goes +Y (into the switch); top-row jacks are upside down (latch up)
        p = C.empty(f"Port_{n:02d}", loc=(x, FRONT, z), rot=(0, math.pi if top else 0, 0), size=0.006)
        p["port"] = n
        port_objs.append(p)
    C.reparent(led_objs, leds_grp)
    C.reparent(port_objs, ports)
    pwr = C.box("LED_Power", (0.0030, 0.0008, 0.0016), (-0.205, FRONT - 0.0024, 0.0125), led_off)
    sysl = C.box("LED_System", (0.0030, 0.0008, 0.0016), (-0.193, FRONT - 0.0024, 0.0125), led_off)
    con = C.empty("Port_Console", loc=(cx, FRONT, 0.022), size=0.006)
    pw_in = C.empty("Power_Inlet", loc=(0.17, D / 2 + 0.0035, H / 2), rot=(0, 0, math.pi), size=0.01)
    C.reparent([pwr, sysl, con, pw_in], root)
    root["netlife_model"] = "switch_48port"
    root["port_count"] = 48
    return root


if __name__ == "__main__":
    sw = build()
    if "--no-render" not in sys.argv:
        # light a few LEDs for the preview only
        on = C.mat("_LED_On_Preview", (0.2, 1.0, 0.3), emission=(0.2, 1.0, 0.3), strength=12)
        keep = {}
        for n in (1, 2, 3, 5, 6, 9, 12, 13, 14, 20, 25, 27, 30, 33, 41, 46):
            o = bpy.data.objects[f"LED_Port_{n:02d}"]
            keep[o.name] = o.data.materials[0]
            o.data.materials[0] = on
        for nm in ("LED_Power", "LED_System"):
            o = bpy.data.objects[nm]
            keep[nm] = o.data.materials[0]
            o.data.materials[0] = on
        floor = C.studio(SCENE, scale=1.2)
        C.shoot(SCENE, os.path.join(OUT, f"{NAME}_preview.png"), (0.20, -0.68, 0.30), (-0.03, 0.0, 0.02), lens=55, fstop=16)
        C.shoot(SCENE, os.path.join(OUT, f"{NAME}_closeup.png"), (-0.08, -0.22, 0.07), (-0.13, -0.11, 0.022),
                lens=60, fstop=22)
        bpy.data.objects.remove(floor, do_unlink=True)
        for nm, m in keep.items():
            bpy.data.objects[nm].data.materials[0] = m
    C.export(sw, OUT, NAME)
    print("DONE")
