"""NetLife3D - RJ-45 Cable Tester (main unit + detachable remote unit).

Used in stage 3 (test 3 cables, cable 3 blinks) and stage 4 (test cables at the switch).
Run:  python3 cable_tester.py [--no-render]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import bpy  # noqa: E402

NAME = "cable_tester"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", NAME)
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------ dimensions (m)
W, H = 0.066, 0.026                 # width (X) and height (Z) of both units
MAIN_L, REM_L, GAP = 0.080, 0.034, 0.0008
MAIN_Y0, MAIN_Y1 = -MAIN_L / 2, MAIN_L / 2
REM_Y0 = MAIN_Y1 + GAP
REM_Y1 = REM_Y0 + REM_L
REM_CY = (REM_Y0 + REM_Y1) / 2
TOP = H
JACK_Z = 0.012                      # centre height of the RJ-45 opening
LED_PITCH = 0.0058

# ------------------------------------------------------------ materials
SCENE = C.reset_scene()
body_m = C.mat("Plastic_Body", (0.045, 0.047, 0.052), rough=0.55)
grip_m = C.mat("Rubber_Grip", (0.85, 0.36, 0.05), rough=0.75)
panel_m = C.mat("Panel_Label", (0.78, 0.79, 0.80), rough=0.45)
ink_m = C.mat("Ink_Dark", (0.03, 0.03, 0.035), rough=0.6)
brand_m = C.mat("Ink_Brand", (0.85, 0.36, 0.05), rough=0.5)
pin_m = C.mat("Metal_Gold", (1.0, 0.76, 0.33), metallic=1.0, rough=0.25)
jack_m = C.mat("Plastic_Jack", (0.012, 0.012, 0.014), rough=0.7)
led_g_m = C.mat("LED_Green_Off", (0.05, 0.22, 0.08), rough=0.15, coat=0.5)
led_r_m = C.mat("LED_Red_Off", (0.25, 0.04, 0.04), rough=0.15, coat=0.5)
btn_pwr_m = C.mat("Button_Red", (0.70, 0.06, 0.05), rough=0.5)
btn_test_m = C.mat("Button_Yellow", (0.95, 0.72, 0.08), rough=0.5)


def unit_body(prefix, y0, y1, port_face_y, port_dir):
    """Rounded body with a real RJ-45 opening cut into one end face.
    port_dir = +1 if the opening faces +Y, -1 if it faces -Y."""
    cy, L = (y0 + y1) / 2, y1 - y0
    body = C.box(f"{prefix}_Shell", (W, L, H), (0, cy, H / 2), body_m, bev=0.0035, segs=4)
    # RJ-45 opening: 11.8 x 8.3 mm, 16 mm deep, with latch notch on the bottom
    d = 0.016
    yc = port_face_y - port_dir * (d / 2 - 0.001)
    c1 = C.box("_cut1", (0.0118, d + 0.002, 0.0083), (0, yc, JACK_Z), None)
    c2 = C.box("_cut2", (0.0064, d + 0.002, 0.0030), (0, yc, JACK_Z - 0.0041 - 0.0010), None)
    C.cut(body, [c1, c2])
    parts = [body]
    # dark socket liner at the back of the hole + 8 gold contact pins on the ceiling
    back_y = port_face_y - port_dir * (d - 0.0006)
    parts.append(C.box("_liner", (0.0120, 0.001, 0.0086), (0, back_y, JACK_Z), jack_m))
    for i in range(8):
        x = (i - 3.5) * 0.00102
        pin_y = port_face_y - port_dir * 0.0105
        parts.append(C.box(f"_pin{i}", (0.00045, 0.008, 0.0006), (x, pin_y, JACK_Z + 0.0036), pin_m))
    # orange rubber grips on both long sides
    for sx in (-1, 1):
        parts.append(C.box("_grip", (0.0016, L - 0.014, H - 0.010), (sx * (W / 2 + 0.0002), cy, H / 2), grip_m,
                           bev=0.0006, segs=2))
    return parts


def led_row(prefix, y, labels_y, mat_led):
    leds, labels = [], []
    names = [str(i) for i in range(1, 9)] + ["G"]
    for i, n in enumerate(names):
        x = (i - 4) * LED_PITCH
        leds.append(C.dome(f"LED_{prefix}_{n}", 0.0019, (x, y, TOP + 0.0006), mat_led))
        labels.append(C.text(f"_lbl_{prefix}_{n}", n, (x, labels_y, TOP + 0.0006), 0.0030, ink_m))
    return leds, labels


def build():
    sc = SCENE
    root = C.empty("CableTester", size=0.05)
    main = C.empty("Main", parent=root, size=0.03)
    remote = C.empty("Remote", loc=(0, REM_CY, 0), parent=root, size=0.03)

    # ---------------- main unit
    mparts = unit_body("Main", MAIN_Y0, MAIN_Y1, MAIN_Y0, -1)
    mparts.append(C.box("_panel", (W - 0.010, MAIN_L - 0.012, 0.0006), (0, 0, TOP + 0.0003), panel_m, bev=0.0012, segs=2))
    mparts.append(C.text("_title", "NetCare", (0, 0.0300, TOP + 0.0006), 0.0042, brand_m))
    mparts.append(C.text("_sub", "RJ-45 CABLE TESTER", (0, 0.0255, TOP + 0.0006), 0.0024, ink_m))
    main_leds, labels = led_row("Main", 0.0175, 0.0115, led_g_m)
    mparts += labels
    mparts.append(C.text("_lbl_on", "ON", (-0.0230, -0.0045, TOP + 0.0006), 0.0026, ink_m))
    mparts.append(C.text("_lbl_pwr", "POWER", (-0.0120, -0.0275, TOP + 0.0006), 0.0028, ink_m))
    mparts.append(C.text("_lbl_test", "TEST", (0.0120, -0.0275, TOP + 0.0006), 0.0028, ink_m))
    mparts.append(C.text("_lbl_main", "MAIN", (0.0230, 0.0000, TOP + 0.0006), 0.0026, ink_m))
    led_power = C.dome("LED_Power", 0.0016, (-0.0230, 0.0003, TOP + 0.0006), led_r_m)
    btn_power = C.cyl("Button_Power", 0.0045, 0.0026, (-0.0120, -0.0170, TOP + 0.0013), btn_pwr_m,
                      verts=32, bev=0.0007, segs=3)
    btn_test = C.box("Button_Test", (0.0130, 0.0075, 0.0026), (0.0120, -0.0170, TOP + 0.0013), btn_test_m,
                     bev=0.0012, segs=3)
    # bezel rings around buttons
    mparts.append(C.cyl("_ring_pwr", 0.0056, 0.0008, (-0.0120, -0.0170, TOP + 0.0006), body_m, verts=32))
    mparts.append(C.box("_ring_test", (0.0150, 0.0095, 0.0008), (0.0120, -0.0170, TOP + 0.0006), body_m,
                        bev=0.0015, segs=2))
    main_body = C.join("Main_Body", mparts)
    plug_main = C.empty("Main_PlugPoint", loc=(0, MAIN_Y0, JACK_Z), size=0.012)
    C.reparent([main_body, btn_power, btn_test, led_power, plug_main] + main_leds, main)

    # ---------------- remote unit
    rparts = unit_body("Remote", REM_Y0, REM_Y1, REM_Y1, +1)
    rparts.append(C.box("_rpanel", (W - 0.010, REM_L - 0.008, 0.0006), (0, REM_CY, TOP + 0.0003), panel_m,
                        bev=0.0012, segs=2))
    rem_leds, rlabels = led_row("Remote", REM_CY - 0.0030, REM_CY - 0.0090, led_g_m)
    rparts += rlabels
    rparts.append(C.text("_lbl_remote", "REMOTE", (0, REM_CY + 0.0075, TOP + 0.0006), 0.0030, ink_m))
    remote_body = C.join("Remote_Body", rparts)
    plug_rem = C.empty("Remote_PlugPoint", loc=(0, REM_Y1, JACK_Z), rot=(0, 0, math.pi), size=0.012)
    C.reparent([remote_body, plug_rem] + rem_leds, remote)

    # custom properties exported as glTF extras -> Godot node metadata
    root["netlife_model"] = "cable_tester"
    root["netlife_version"] = 1
    return sc, root


if __name__ == "__main__":
    scene, tester = build()
    if "--no-render" not in sys.argv:
        floor = C.studio(scene, scale=0.35)
        C.shoot(scene, os.path.join(OUT, f"{NAME}_preview.png"), (0.17, -0.22, 0.20), (0, 0.012, 0.010), lens=60, fstop=14)
        C.shoot(scene, os.path.join(OUT, f"{NAME}_ports.png"), (-0.11, -0.19, 0.075), (0, 0.0, 0.012), lens=70, fstop=22)
        bpy.data.objects.remove(floor, do_unlink=True)
    C.export(tester, OUT, NAME)
    print("DONE")
