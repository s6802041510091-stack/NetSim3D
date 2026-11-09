"""Build simple models of Mission 1's network devices and render their pictures.

Run: blender -b --python 3Dmodel/scripts/render_device_thumbnails.py

- Router and Switched Hub 8 Port come from the existing phase3 lookdev models.
- Switched Hub 24/16 Port, Shared Hub 24 Port, Wireless Access Point,
  Repeater and Bridge are built here as simple shapes, reusing the RJ45 port
  from the 8-port switch so every device has the same look.
- Every device is rendered alone with the same camera angle and lights on a
  transparent background to net-sim-3d/assets/ui/devices/<name>.png.
- The assembled scene is saved to 3Dmodel/ใช้ร่วมกัน/blend/network_devices.blend
  so later missions (e.g. the wall rack in Mission 2) can reuse the models.
The phase3 source .blend files are only read, never saved.
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Preview/โรงเรียนและเมือง/phase3/assets"
OUT_DIR = ROOT / "net-sim-3d/assets/ui/devices"
BLEND_OUT = ROOT / "3Dmodel/ใช้ร่วมกัน/blend/network_devices.blend"
SIZE = (500, 300)


def material(name, color, metallic=0.0, roughness=0.5, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    # Set emission explicitly: the default is not "off" in every Blender version
    # (non-LED parts rendered white without this).
    bsdf.inputs["Emission Color"].default_value = (*(emission or (0.0, 0.0, 0.0)), 1.0)
    bsdf.inputs["Emission Strength"].default_value = 3.0 if emission else 0.0
    return mat


def box(name, size, location, mat, collection, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    _move_to(obj, collection)
    return obj


def cylinder(name, radius, depth, location, mat, collection, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, vertices=64)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 4
    _move_to(obj, collection)
    return obj


def _move_to(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)


def new_collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def append_objects(blend, keep, collection):
    """Append the mesh objects for which keep(obj_name) is true; keeps parenting."""
    with bpy.data.libraries.load(str(blend), link=False) as (src, dst):
        dst.objects = list(src.objects)
    added = []
    for obj in dst.objects:
        if obj is None:
            continue
        if obj.type in ("MESH", "EMPTY") and keep(obj.name):
            collection.objects.link(obj)
            added.append(obj)
        else:
            bpy.data.objects.remove(obj, do_unlink=True)
    return added


def port_row(template, count, start, step, collection, prefix):
    for i in range(count):
        copy = template.copy()
        copy.data = template.data  # linked mesh: light on memory
        copy.name = "%s_%02d" % (prefix, i + 1)
        copy.location = start + step * i
        copy.parent = None
        collection.objects.link(copy)


def build_rack_switch(name, ports, width, body_mat, port_template, leds_mat):
    col = new_collection(name)
    depth, height = 0.2, 0.044
    box(name + "_Body", (width, depth, height), (0, 0, height / 2), body_mat, col, bevel=0.003)
    # Rack ears.
    for side in (-1, 1):
        box(name + "_Ear", (0.018, 0.004, height), (side * (width / 2 + 0.009), -depth / 2 + 0.002, height / 2), body_mat, col)
    per_row = ports // 2 if ports >= 16 else ports
    rows = 2 if ports >= 16 else 1
    pitch = 0.0165
    x0 = width / 2 - 0.03 - (per_row - 1) * pitch
    for r in range(rows):
        z = height / 2 + (0.009 if rows == 2 else 0.0) - r * 0.018
        port_row(port_template, per_row, Vector((x0, -depth / 2 - 0.004, z - 0.007)), Vector((pitch, 0, 0)), col, "%s_Port_R%d" % (name, r + 1))
    for i in range(4):
        box(name + "_LED_%d" % i, (0.004, 0.002, 0.004), (-width / 2 + 0.03 + i * 0.012, -depth / 2 - 0.001, height * 0.62), leds_mat, col)
    return col


def frame_camera(cam, objects):
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        for corner in ev.bound_box:
            p = ev.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    center = (lo + hi) / 2
    radius = (hi - lo).length / 2
    direction = Vector((0.45, -1.0, 0.55)).normalized()  # front-right, slightly above
    # Fit the bounding sphere into the narrower (vertical) field of view.
    distance = radius / math.sin(cam.data.angle_y / 2) * 1.08
    cam.location = center + direction * distance
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


def trim_to_content(path, margin=0.06, alpha_cut=0.04):
    """Crop to the visible pixels (plus a margin) and fit back into SIZE, centred."""
    import numpy as np

    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    ys, xs = np.nonzero(px[:, :, 3] > alpha_cut)
    if len(xs) == 0:
        bpy.data.images.remove(img)
        return
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = px[y0:y1, x0:x1]
    cw, ch = x1 - x0, y1 - y0
    out_w, out_h = SIZE
    scale = min(out_w * (1 - 2 * margin) / cw, out_h * (1 - 2 * margin) / ch)
    nw, nh = max(1, int(cw * scale)), max(1, int(ch * scale))
    # Nearest-pixel sample of the crop into the new size (fine for a downscale).
    rows = np.clip((np.arange(nh) / scale).astype(int), 0, ch - 1)
    cols = np.clip((np.arange(nw) / scale).astype(int), 0, cw - 1)
    resized = crop[rows][:, cols]
    canvas = np.zeros((out_h, out_w, 4), dtype=np.float32)
    ox, oy = (out_w - nw) // 2, (out_h - nh) // 2
    canvas[oy:oy + nh, ox:ox + nw] = resized
    out = bpy.data.images.new(path.stem + "_trim", out_w, out_h, alpha=True)
    out.pixels[:] = canvas.ravel()
    out.filepath_raw = str(path)
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(img)
    bpy.data.images.remove(out)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 48
        scene.cycles.use_denoising = True
    except (TypeError, AttributeError):
        pass
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.9, 0.92, 0.95, 1)
    bg.inputs["Strength"].default_value = 0.35
    scene.world = world

    # Lights shared by every render.
    # Gentle studio light: the devices are only 10-44 cm wide, so stronger
    # lights blew dark plastic out to white.
    for name, loc, energy, size in (("Key", (0.6, -0.9, 0.9), 20, 0.6), ("Fill", (-0.9, -0.5, 0.5), 8, 0.8), ("Rim", (0.0, 0.8, 0.8), 10, 0.5)):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = size
        light = bpy.data.objects.new(name, data)
        light.location = loc
        light.rotation_euler = (Vector((0, 0, 0.03)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = 50
    cam_data.sensor_fit = "HORIZONTAL"
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    devices = {}
    devices["router"] = new_collection("Router")
    append_objects(ASSETS / "router_lookdev.blend", lambda n: not n.startswith(("Studio", "_")), devices["router"])
    devices["switched_hub_8_port"] = new_collection("Switched Hub 8 Port")
    switch_objs = append_objects(ASSETS / "switch8_lookdev.blend", lambda n: n != "StudioFloor", devices["switched_hub_8_port"])
    port_template = next(o for o in switch_objs if o.name.startswith("RJ45_Port_01"))

    graphite = material("Rack | graphite blue", (0.13, 0.16, 0.22), 0.35, 0.45)
    beige = material("Hub | old beige", (0.72, 0.66, 0.55), 0.0, 0.6)
    white = material("AP | white plastic", (0.92, 0.93, 0.94), 0.0, 0.35)
    gray = material("Small box | gray", (0.30, 0.32, 0.36), 0.2, 0.5)
    green = material("Bridge | dark green", (0.16, 0.26, 0.20), 0.2, 0.5)
    led_green = material("LED | green", (0.1, 0.9, 0.3), emission=(0.1, 1.0, 0.3))
    led_amber = material("LED | amber", (1.0, 0.6, 0.1), emission=(1.0, 0.6, 0.1))
    led_blue = material("LED | blue", (0.2, 0.5, 1.0), emission=(0.2, 0.5, 1.0))

    devices["switched_hub_24_port"] = build_rack_switch("Switched Hub 24 Port", 24, 0.44, graphite, port_template, led_green)
    devices["switched_hub_16_port"] = build_rack_switch("Switched Hub 16 Port", 16, 0.33, graphite, port_template, led_green)
    devices["shared_hub_24_port"] = build_rack_switch("Shared Hub 24 Port", 24, 0.44, beige, port_template, led_amber)

    col = devices["wireless_access_point"] = new_collection("Wireless Access Point")
    cylinder("AP_Disc", 0.1, 0.03, (0, 0, 0.015), white, col, bevel=0.012)
    cylinder("AP_Mount", 0.035, 0.012, (0, 0, -0.006), gray, col)
    cylinder("AP_LED", 0.008, 0.002, (0, 0, 0.031), led_blue, col)

    col = devices["repeater"] = new_collection("Repeater")
    box("Repeater_Body", (0.1, 0.07, 0.03), (0, 0, 0.015), gray, col, bevel=0.004)
    port_row(port_template, 2, Vector((-0.02, -0.039, 0.008)), Vector((0.04, 0, 0)), col, "Repeater_Port")
    box("Repeater_LED", (0.004, 0.002, 0.004), (-0.04, -0.036, 0.022), led_green, col)

    col = devices["bridge"] = new_collection("Bridge")
    box("Bridge_Body", (0.12, 0.08, 0.032), (0, 0, 0.016), green, col, bevel=0.004)
    port_row(port_template, 2, Vector((-0.03, -0.044, 0.009)), Vector((0.06, 0, 0)), col, "Bridge_Port")
    for i in range(2):
        box("Bridge_LED_%d" % i, (0.004, 0.002, 0.004), (-0.05 + i * 0.012, -0.041, 0.024), led_green, col)

    # A shadow catcher under the devices: a soft contact shadow stays in the
    # transparent PNG, so light devices (the white access point) stand out on a
    # white card.
    bpy.ops.mesh.primitive_plane_add(size=3.0, location=(0, 0, -0.0005))
    floor = bpy.context.active_object
    floor.name = "ShadowCatcher"
    floor.is_shadow_catcher = True

    # Each device sits at the origin; render one at a time, then trim the empty
    # space around it so the picture fills the card.
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for file_name, collection in devices.items():
        for other in devices.values():
            other.hide_render = other is not collection
        frame_camera(cam, list(collection.all_objects))
        path = OUT_DIR / (file_name + ".png")
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        trim_to_content(path)
        print("RENDERED", file_name, flush=True)
    for collection in devices.values():
        collection.hide_render = False
    bpy.data.objects.remove(floor, do_unlink=True)
    BLEND_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
    print("DEVICES_DONE", OUT_DIR, BLEND_OUT, flush=True)


if __name__ == "__main__":
    main()
