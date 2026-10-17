"""NetLife3D - Wi-Fi router + fiber ONT.

Rear panels face +Y in Blender (= -Z... see README: back of the device), LEDs on the top front edge.
Every port: Port_<NAME> plug point (local +Y in Blender -> -Z in Godot = insertion direction).
Run:  python3 router_ont.py [--no-render]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import bpy  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "router_ont")
os.makedirs(OUT, exist_ok=True)

OPEN_W, OPEN_H, OPEN_D = 0.0118, 0.0083, 0.016

def make_mats():
    global black_m, matte_m, white_m, grey_m, jack_m, pin_m, shield_m, wan_m, lan_m, sc_m, ink_w, ink_d, brand_m, led_off, led_red_off, rubber_m
    black_m = C.mat("Plastic_Black", (0.025, 0.026, 0.03), rough=0.35, coat=0.3)
    matte_m = C.mat("Plastic_Matte", (0.04, 0.042, 0.047), rough=0.7)
    white_m = C.mat("Plastic_White", (0.82, 0.83, 0.84), rough=0.4)
    grey_m = C.mat("Plastic_Grey", (0.35, 0.36, 0.38), rough=0.5)
    jack_m = C.mat("Plastic_Jack", (0.012, 0.012, 0.014), rough=0.7)
    pin_m = C.mat("Metal_Gold", (1.0, 0.76, 0.33), metallic=1.0, rough=0.25)
    shield_m = C.mat("Metal_Shield", (0.62, 0.63, 0.65), metallic=1.0, rough=0.3)
    wan_m = C.mat("Port_WAN_Blue", (0.05, 0.30, 0.85), rough=0.5)
    lan_m = C.mat("Port_LAN_Yellow", (0.95, 0.70, 0.08), rough=0.5)
    sc_m = C.mat("Fiber_SC_Green", (0.05, 0.55, 0.20), rough=0.45)
    ink_w = C.mat("Ink_White", (0.88, 0.89, 0.9), rough=0.5)
    ink_d = C.mat("Ink_Dark", (0.08, 0.08, 0.09), rough=0.6)
    brand_m = C.mat("Ink_Brand", (0.95, 0.45, 0.08), rough=0.45)
    led_off = C.mat("LED_Off", (0.10, 0.16, 0.12), rough=0.15, coat=0.5)
    led_red_off = C.mat("LED_Red_Off", (0.22, 0.05, 0.05), rough=0.15, coat=0.5)
    rubber_m = C.mat("Rubber_Foot", (0.02, 0.02, 0.02), rough=0.9)


def rj45(x, z, face_y, ring_mat=None):
    """Cutter + inner parts for one RJ-45 jack on a rear face at y=face_y (opening faces +Y)."""
    cy = face_y - OPEN_D / 2 + 0.004
    cut = [C.box("_c", (OPEN_W, OPEN_D + 0.006, OPEN_H), (x, cy, z), None),
           C.box("_n", (0.0064, OPEN_D + 0.006, 0.0030), (x, cy, z - OPEN_H / 2 - 0.0010), None)]
    parts = [C.box("_liner", (OPEN_W + 0.0004, 0.001, OPEN_H + 0.0006), (x, face_y - OPEN_D + 0.003, z), jack_m)]
    for i in range(8):
        parts.append(C.box("_pin", (0.00045, 0.007, 0.0006), (x + (i - 3.5) * 0.00102, face_y - OPEN_D + 0.008,
                                                               z + OPEN_H / 2 - 0.0007), pin_m))
    if ring_mat:
        frame = C.box("_frame", (OPEN_W + 0.003, 0.0012, OPEN_H + 0.0045), (x, face_y + 0.0004, z - 0.0005), ring_mat,
                      bev=0.0004)
        hole = C.box("_fh", (OPEN_W, 0.01, OPEN_H), (x, face_y, z), None)
        hole2 = C.box("_fn", (0.0064, 0.01, 0.0030), (x, face_y, z - OPEN_H / 2 - 0.0010), None)
        C.cut(frame, [hole, hole2])
        parts.append(frame)
    return cut, parts


def plug_point(name, x, z, face_y):
    return C.empty(name, loc=(x, face_y, z), rot=(0, 0, math.pi), size=0.006)


def led(name, x, y, z, mat=None):
    return C.box(name, (0.0040, 0.0040, 0.0008), (x, y, z), mat or led_off, bev=0.0008, segs=2)


# ------------------------------------------------------------ router
def router():
    W, D, H = 0.230, 0.150, 0.034
    FY = D / 2           # rear face
    root = C.empty("Router", size=0.06)
    shell = C.box("_shell", (W, D, H), (0, 0, H / 2 + 0.003), black_m, bev=0.008, segs=6)
    cutters, parts = [], []
    jacks = [("WAN", -0.045, wan_m)] + [(f"LAN{i}", -0.020 + (i - 1) * 0.016, lan_m) for i in range(1, 5)]
    zport = 0.003 + 0.0125
    for nm, x, rm in jacks:
        c, p = rj45(x, zport, FY, rm)
        cutters += c
        parts += p
    # power jack + reset hole + power button
    cutters.append(C.cyl("_dc", 0.0035, 0.02, (0.075, FY, zport), None, rot=(math.pi / 2, 0, 0), verts=24))
    cutters.append(C.cyl("_rst", 0.0011, 0.02, (0.058, FY, zport), None, rot=(math.pi / 2, 0, 0), verts=12))
    C.cut(shell, cutters)
    parts.append(C.cyl("_dcpin", 0.0010, 0.01, (0.075, FY - 0.008, zport), shield_m, rot=(math.pi / 2, 0, 0), verts=12))
    btn = C.box("Button_Power", (0.008, 0.003, 0.005), (0.092, FY + 0.0005, zport), matte_m, bev=0.001)
    # rear labels (on the face, rotated to face +Y)
    rr = (math.pi / 2, 0, math.pi)
    for nm, x, _ in jacks:
        parts.append(C.text(f"_l{nm}", nm, (x, FY + 0.0002, zport + 0.0098), 0.0026, ink_w, rot=rr))
    for nm, x in (("RESET", 0.058), ("POWER", 0.075), ("ON/OFF", 0.092)):
        parts.append(C.text(f"_l{nm}", nm, (x, FY + 0.0002, zport + 0.0098), 0.0022, ink_w, rot=rr))
    # top: glossy panel stripe, brand, LED row along the front edge
    parts.append(C.text("_brand", "NetCare", (0, -0.005, H + 0.0031), 0.014, brand_m))
    parts.append(C.text("_model", "AX1800 Wi-Fi 6 Router", (0, -0.022, H + 0.0031), 0.0045, ink_w))
    led_defs = [("Power", "PWR"), ("Internet", "WAN"), ("WiFi24", "2.4G"), ("WiFi5", "5G"),
                ("LAN1", "1"), ("LAN2", "2"), ("LAN3", "3"), ("LAN4", "4"), ("WPS", "WPS")]
    leds = []
    for i, (nm, lbl) in enumerate(led_defs):
        x = -0.072 + i * 0.018
        leds.append(led(f"LED_{nm}", x, -0.055, H + 0.0034))
        parts.append(C.text(f"_t{nm}", lbl, (x, -0.0625, H + 0.0031), 0.0030, ink_w))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(C.cyl("_foot", 0.007, 0.003, (sx * 0.09, sy * 0.055, 0.0015), rubber_m, verts=20))
    body = C.join("Router_Body", [shell] + parts)
    C.reparent([body, btn] + leds, root)
    # antennas: pivot at hinge, default upright, rotate X to tilt
    ants = []
    for i, x in enumerate((-0.095, -0.035, 0.035, 0.095), start=1):
        piv = C.empty(f"Antenna_{i}", loc=(x, FY - 0.006, H + 0.001), size=0.015)
        hinge = C.cyl(f"_hinge{i}", 0.0065, 0.014, (x, FY - 0.006, H + 0.001), matte_m, rot=(0, math.pi / 2, 0),
                      verts=24, bev=0.001)
        stick = C.box(f"_stick{i}", (0.013, 0.0055, 0.150), (x, FY - 0.006, H + 0.001 + 0.080), matte_m,
                      bev=0.0026, segs=4)
        a = C.join(f"Antenna_{i}_Mesh", [hinge, stick])
        C.reparent([a], piv)
        ants.append(piv)
    C.reparent(ants, root)
    pts = [plug_point(f"Port_{nm}", x, zport, FY) for nm, x, _ in jacks]
    pts.append(C.empty("Power_Inlet", loc=(0.075, FY, zport), rot=(0, 0, math.pi), size=0.006))
    C.reparent(pts, root)
    root["netlife_model"] = "router"
    return root


# ------------------------------------------------------------ ONT
def ont():
    W, D, H = 0.165, 0.115, 0.030
    FY = D / 2
    root = C.empty("ONT", size=0.05)
    shell = C.box("_oshell", (W, D, H), (0, 0, H / 2 + 0.002), white_m, bev=0.006, segs=5)
    cutters, parts = [], []
    zport = 0.002 + 0.012
    lan = [("LAN1", 0.010), ("LAN2", 0.028)]
    for nm, x in lan:
        c, p = rj45(x, zport, FY, grey_m)
        cutters += c
        parts += p
    # SC/APC fiber adaptor: square green housing with a slot
    sc_x = -0.040
    cutters.append(C.box("_scHole", (0.0085, 0.02, 0.0090), (sc_x, FY, zport), None))
    cutters.append(C.cyl("_odc", 0.0035, 0.02, (0.058, FY, zport), None, rot=(math.pi / 2, 0, 0), verts=24))
    C.cut(shell, cutters)
    sc = C.box("_sc", (0.0098, 0.010, 0.0100), (sc_x, FY - 0.003, zport), sc_m, bev=0.0006)
    sc_slot = C.box("_scs", (0.0068, 0.02, 0.0072), (sc_x, FY, zport), None)
    C.cut(sc, [sc_slot])
    ferrule = C.cyl("_ferrule", 0.00125, 0.008, (sc_x, FY - 0.006, zport), white_m, rot=(math.pi / 2, 0, 0), verts=16)
    parts += [sc, ferrule]
    rr = (math.pi / 2, 0, math.pi)
    for nm, x in lan + [("PON", sc_x), ("POWER", 0.058)]:
        parts.append(C.text(f"_ol{nm}", nm, (x, FY + 0.0002, zport + 0.0095), 0.0025, ink_d, rot=rr))
    # caution label for laser
    parts.append(C.text("_laser", "LASER", (sc_x, FY + 0.0002, zport - 0.0095), 0.0020, C.mat("Ink_Red", (0.7, 0.05, 0.05), rough=0.5), rot=rr))
    parts.append(C.text("_obrand", "NetCare", (-0.030, 0.012, H + 0.0021), 0.010, brand_m))
    parts.append(C.text("_omodel", "GPON ONT  NC-G120", (-0.030, 0.0, H + 0.0021), 0.0040, ink_d))
    led_defs = [("Power", "POWER", led_off), ("PON", "PON", led_off), ("LOS", "LOS", led_red_off),
                ("LAN1", "LAN1", led_off), ("LAN2", "LAN2", led_off)]
    leds = []
    for i, (nm, lbl, m) in enumerate(led_defs):
        x = -0.050 + i * 0.022
        leds.append(led(f"LED_{nm}", x, -0.040, H + 0.0024, m))
        parts.append(C.text(f"_ot{nm}", lbl, (x, -0.048, H + 0.0021), 0.0030, ink_d))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(C.cyl("_ofoot", 0.006, 0.002, (sx * 0.065, sy * 0.040, 0.001), rubber_m, verts=20))
    body = C.join("ONT_Body", [shell] + parts)
    C.reparent([body] + leds, root)
    pts = [C.empty("Port_PON", loc=(sc_x, FY, zport), rot=(0, 0, math.pi), size=0.006)]
    pts += [plug_point(f"Port_{nm}", x, zport, FY) for nm, x in lan]
    pts.append(C.empty("Power_Inlet", loc=(0.058, FY, zport), rot=(0, 0, math.pi), size=0.006))
    C.reparent(pts, root)
    root["netlife_model"] = "ont"
    return root


def light_preview(pairs):
    keep = {}
    for nm, m in pairs:
        ob = bpy.data.objects[nm]
        keep[nm] = ob.data.materials[0]
        ob.data.materials[0] = m
    return keep


if __name__ == "__main__":
    render = "--no-render" not in sys.argv
    # ---- router
    sc = C.reset_scene()
    make_mats()
    r = router()
    if render:
        on_g = C.mat("_on_g", (0.2, 1.0, 0.35), emission=(0.2, 1.0, 0.35), strength=14)
        on_b = C.mat("_on_b", (0.2, 0.6, 1.0), emission=(0.2, 0.6, 1.0), strength=14)
        keep = light_preview([("LED_Power", on_g), ("LED_Internet", on_b), ("LED_WiFi24", on_b), ("LED_WiFi5", on_b),
                              ("LED_LAN1", on_g), ("LED_LAN3", on_g)])
        for i, t in ((1, -12), (2, -4), (3, 4), (4, 12)):
            bpy.data.objects[f"Antenna_{i}"].rotation_euler = (math.radians(-8), math.radians(t), 0)
        floor = C.studio(sc, scale=0.8)
        C.shoot(sc, os.path.join(OUT, "router_preview.png"), (0.20, -0.40, 0.30), (0.0, 0.0, 0.05), lens=45, fstop=16)
        C.shoot(sc, os.path.join(OUT, "router_rear.png"), (-0.10, 0.34, 0.12), (0.01, 0.07, 0.015), lens=50, fstop=22)
        bpy.data.objects.remove(floor, do_unlink=True)
        for nm, m in keep.items():
            bpy.data.objects[nm].data.materials[0] = m
        for i in range(1, 5):
            bpy.data.objects[f"Antenna_{i}"].rotation_euler = (0, 0, 0)
    C.export(r, OUT, "router")
    # ---- ONT
    sc = C.reset_scene()
    make_mats()
    o = ont()
    if render:
        on_g = C.mat("_on_g", (0.2, 1.0, 0.35), emission=(0.2, 1.0, 0.35), strength=14)
        keep = light_preview([("LED_Power", on_g), ("LED_PON", on_g), ("LED_LAN1", on_g)])
        floor = C.studio(sc, scale=0.6)
        C.shoot(sc, os.path.join(OUT, "ont_preview.png"), (0.15, -0.30, 0.22), (0.0, 0.0, 0.02), lens=45, fstop=16)
        C.shoot(sc, os.path.join(OUT, "ont_rear.png"), (-0.08, 0.26, 0.09), (-0.01, 0.05, 0.012), lens=50, fstop=22)
        bpy.data.objects.remove(floor, do_unlink=True)
        for nm, m in keep.items():
            bpy.data.objects[nm].data.materials[0] = m
    C.export(o, OUT, "ont")
    print("DONE")
