"""NetLife3D - stage 2 tools: RJ-45 crimping tool + rotary UTP cable stripper.

Crimper: plier-style. Fixed part = upper jaw (8P die, blades) + lower handle.
         Moving part (node "Jaw_Moving") = lower jaw + upper handle, rotating on the pivot.
         Modelled CLOSED; the Godot script opens it.
Run:  python3 crimp_tools.py [--no-render]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402
import bpy  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "crimp_tools")
os.makedirs(OUT, exist_ok=True)
SCENE = C.reset_scene()

steel = C.mat("Steel", (0.55, 0.57, 0.60), metallic=1.0, rough=0.32)
steel_dark = C.mat("Steel_Dark", (0.12, 0.125, 0.135), metallic=0.9, rough=0.45)
blade_m = C.mat("Steel_Blade", (0.80, 0.81, 0.83), metallic=1.0, rough=0.15)
grip_blue = C.mat("Grip_Blue", (0.04, 0.22, 0.62), rough=0.7)
grip_black = C.mat("Grip_Black", (0.02, 0.02, 0.022), rough=0.8)
ink_white = C.mat("Ink_White", (0.9, 0.9, 0.9), rough=0.5)
plastic_blue = C.mat("Plastic_StripperBlue", (0.05, 0.35, 0.80), rough=0.45)
plastic_yellow = C.mat("Plastic_Yellow", (0.95, 0.75, 0.10), rough=0.5)

T = 0.007   # half thickness of the head (Y)
OPEN_DEG = 16


def mirror_z(pts):
    return [(x, -z) for x, z in pts]


# ------------------------------------------------------------ crimper
def crimper():
    root = C.empty("CrimpingTool", size=0.05)
    jaw_pivot = C.empty("Jaw_Moving", parent=root, size=0.03)

    # ---- fixed part: upper jaw + lower handle
    upper_jaw = [(-0.008, 0.012), (0.004, 0.0012), (0.070, 0.0012), (0.080, 0.008), (0.080, 0.020),
                 (0.070, 0.027), (0.010, 0.027)]
    jaw_up = C.prism("_jaw_up", upper_jaw, -T, T, steel_dark, bev=0.0012)
    # 8P die cavity (plug enters along +Y), 12 x 8 mm, through the whole jaw
    die = C.box("_die", (0.0122, 0.03, 0.0085), (0.054, 0, 0.0055), None)
    # cutter and stripper notches
    strip_n = C.box("_strip", (0.004, 0.03, 0.004), (0.036, 0, 0.002), None)
    C.cut(jaw_up, [die, strip_n])
    handle_lo_pts = [(0.004, -0.006), (-0.006, 0.006), (-0.150, -0.012), (-0.150, -0.022)]
    handle_lo = C.prism("_handle_lo", handle_lo_pts, -0.005, 0.005, steel_dark, bev=0.0015)
    grip_lo = C.prism("_grip_lo", [(-0.060, -0.003), (-0.060, 0.0045), (-0.156, -0.009), (-0.156, -0.025),
                                   (-0.150, -0.028), (-0.066, -0.014)],
                      -0.0085, 0.0085, grip_blue, bev=0.003, segs=3)
    blade_up = C.box("_blade_up", (0.014, 0.0025, 0.004), (0.021, 0, 0.0032), blade_m, bev=0.0004)
    hub = C.cyl("_hub", 0.0125, 2 * T + 0.002, (0, 0, 0), steel_dark, rot=(math.pi / 2, 0, 0), verts=40,
                bev=0.0008)
    bolt = C.cyl("_bolt", 0.0055, 2 * T + 0.005, (0, 0, 0), steel, rot=(math.pi / 2, 0, 0), verts=24, bev=0.0006)
    labels = [
        C.text("_t8p", "8P", (0.054, -T - 0.0002, 0.0185), 0.0055, ink_white, rot=(math.pi / 2, 0, 0)),
        C.text("_tcut", "CUT", (0.021, -T - 0.0002, 0.0185), 0.0040, ink_white, rot=(math.pi / 2, 0, 0)),
        C.text("_tstrip", "STRIP", (0.036, -T - 0.0002, 0.0125), 0.0030, ink_white, rot=(math.pi / 2, 0, 0)),
        C.text("_brand", "NetCare", (-0.110, -0.0087, -0.012), 0.0060, ink_white,
               rot=(math.pi / 2, math.radians(4.2), 0)),
    ]
    body = C.join("Body_Fixed", [jaw_up, handle_lo, grip_lo, blade_up, hub, bolt] + labels)
    C.reparent([body], root)

    # ---- moving part: lower jaw (crimp teeth) + upper handle
    lower_jaw = mirror_z(upper_jaw)
    jaw_lo = C.prism("_jaw_lo", lower_jaw, -T, T, steel_dark, bev=0.0012)
    handle_up = C.prism("_handle_up", mirror_z(handle_lo_pts), -0.0048, 0.0048, steel_dark, bev=0.0015)
    grip_up = C.prism("_grip_up", mirror_z([(-0.060, -0.003), (-0.060, 0.0045), (-0.156, -0.009), (-0.156, -0.025),
                                            (-0.150, -0.028), (-0.066, -0.014)]),
                      -0.0085, 0.0085, grip_black, bev=0.003, segs=3)
    blade_lo = C.box("_blade_lo", (0.014, 0.0025, 0.004), (0.021, 0, -0.0032), blade_m, bev=0.0004)
    teeth = [C.box(f"_tooth{i}", (0.0006, 0.010, 0.0030), (0.054 + (i - 3.5) * 0.00102, 0, 0.0005), blade_m)
             for i in range(8)]
    strain = C.box("_strain", (0.0035, 0.010, 0.0020), (0.0468, 0, 0.0001), blade_m)
    moving = C.join("Jaw_Lower", [jaw_lo, handle_up, grip_up, blade_lo, strain] + teeth)
    C.reparent([moving], jaw_pivot)

    # ---- interaction points (local +Y in Blender = -Z in Godot = insertion direction)
    die_pt = C.empty("Crimp_Slot", loc=(0.054, -T, 0.0055), size=0.01)
    cut_pt = C.empty("Cut_Point", loc=(0.021, -T, 0.0), size=0.01)
    strip_pt = C.empty("Strip_Point", loc=(0.036, -T, 0.002), size=0.01)
    grip_pt = C.empty("Hand_Grip", loc=(-0.11, 0, 0), size=0.02)
    C.reparent([die_pt, cut_pt, strip_pt, grip_pt], root)
    root["netlife_model"] = "crimping_tool"
    root["open_deg"] = OPEN_DEG
    return root


# ------------------------------------------------------------ rotary stripper
def stripper(x_off):
    root = C.empty("CableStripper", loc=(x_off, 0, 0), size=0.04)
    # body: rounded slab lying flat, cable hole through it along Y near the front
    outline = [(0.000, 0.000), (0.050, 0.000), (0.058, 0.004), (0.060, 0.012), (0.056, 0.019),
               (0.046, 0.022), (0.008, 0.022), (0.000, 0.016)]
    body = C.prism("_sbody", [(x - 0.030, z) for x, z in outline], -0.009, 0.009, plastic_blue, bev=0.004, segs=4)
    hole = C.cyl("_hole", 0.0038, 0.05, (0.018, 0, 0.011), None, rot=(math.pi / 2, 0, 0), verts=32)
    slit = C.box("_slit", (0.020, 0.05, 0.0012), (0.026, 0, 0.011), None)
    C.cut(body, [hole, slit])
    blade = C.box("_sblade", (0.0012, 0.004, 0.006), (0.018, 0, 0.0152), blade_m)
    screw = C.cyl("_screw", 0.0022, 0.0006, (0.018, 0, 0.0221), steel, verts=16)
    ring = C.torus("_ring", 0.0115, 0.0032, (-0.040, 0, 0.011), plastic_blue)
    neck = C.box("_neck", (0.010, 0.008, 0.008), (-0.028, 0, 0.011), plastic_blue, bev=0.002)
    grip_pad = C.box("_pad", (0.030, 0.0186, 0.0012), (-0.008, 0, 0.0224), plastic_yellow, bev=0.0005)
    sbody = C.join("Stripper_Body", [body, blade, screw, ring, neck, grip_pad])
    C.reparent([sbody], root)
    sp = C.empty("Cable_Hole", loc=(x_off + 0.018, -0.009, 0.011), size=0.01)
    C.reparent([sp], root)
    root["netlife_model"] = "cable_stripper"
    return root


if __name__ == "__main__":
    crimp = crimper()
    strip = stripper(0.0)
    strip.location = (0.04, -0.09, 0)
    if "--no-render" not in sys.argv:
        # preview: crimper slightly open, laid on its side like on a desk
        mv = bpy.data.objects["Jaw_Moving"]
        mv.rotation_euler = (0, math.radians(OPEN_DEG), 0)
        crimp.rotation_euler = (math.radians(-90), 0, math.radians(-10))
        crimp.location = (0.0, 0.03, T + 0.0085)
        floor = C.studio(SCENE, scale=0.6)
        C.shoot(SCENE, os.path.join(OUT, "crimp_tools_preview.png"), (0.14, -0.34, 0.30), (-0.02, -0.01, 0.0),
                lens=50, fstop=16)
        C.shoot(SCENE, os.path.join(OUT, "crimp_head_closeup.png"), (0.10, -0.07, 0.13), (0.042, 0.022, 0.008),
                lens=60, fstop=22)
        bpy.data.objects.remove(floor, do_unlink=True)
        mv.rotation_euler = (0, 0, 0)
        crimp.rotation_euler = (0, 0, 0)
        crimp.location = (0, 0, 0)
    strip.location = (0, 0, 0)
    C.export(crimp, OUT, "crimping_tool", save_blend=False)
    C.export(strip, OUT, "cable_stripper", save_blend=False)
    strip.location = (0.04, -0.09, 0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "crimp_tools.blend"), compress=True)
    print("DONE")
