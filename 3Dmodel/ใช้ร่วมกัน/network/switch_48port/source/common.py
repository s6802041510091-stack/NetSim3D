"""Shared helpers for NetLife3D Blender model scripts.

Conventions (agreed with the team):
- Units: metres, real-world size. Blender Z-up; glTF export converts to Godot Y-up.
- Every interactive part is its own object with an English name (Port_01, LED_Main_1, Button_Test ...).
- Plug/insertion points are empties named *_PlugPoint. In Godot their local -Z axis points
  INTO the socket (the direction a plug moves when inserted), +Y is up.
- Deliverables per model: <name>.blend, <name>.glb, <name>_preview.png
"""
import math
import os

import bpy  # noqa: F401  (must be imported before bmesh/mathutils)
import bmesh  # noqa: F401
from mathutils import Vector


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    return sc


_MATS = {}


def mat(name, color, metallic=0.0, rough=0.5, coat=0.0, emission=None, strength=0.0, alpha=1.0, transmission=0.0):
    """Principled material, cached by name so parts share materials (fewer draw calls in Godot)."""
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    p.inputs["Coat Weight"].default_value = coat
    p.inputs["Transmission Weight"].default_value = transmission
    if emission is not None:
        p.inputs["Emission Color"].default_value = (*emission, 1)
        p.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    _MATS[name] = m
    return m


def empty(name, loc=(0, 0, 0), parent=None, rot=(0, 0, 0), size=0.01):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.empty_display_size = size
    o.empty_display_type = "ARROWS"
    o.location = loc
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    return o


def _finish(o, name, material, parent, smooth_angle=35):
    o.name = name
    o.data.name = name
    if material:
        o.data.materials.append(material)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    if parent:
        o.parent = parent
    return o


def bevel(o, width, segments=3, angle=None):
    m = o.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    if angle:
        m.angle_limit = math.radians(angle)
    m.harden_normals = False
    return m


def box(name, size, loc, material, bev=0.0, segs=3, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bev:
        bevel(o, bev, segs)
    return _finish(o, name, material, parent)


def cyl(name, r, depth, loc, material, rot=(0, 0, 0), verts=24, bev=0.0, segs=2, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bev:
        bevel(o, bev, segs)
    return _finish(o, name, material, parent)


def prism(name, pts_xz, y0, y1, material, bev=0.0, segs=2, parent=None):
    """Extrude a 2D outline drawn in the X-Z plane (side view) along Y from y0 to y1."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y0, z)) for x, z in pts_xz]
    b = [bm.verts.new((x, y1, z)) for x, z in pts_xz]
    n = len(pts_xz)
    bm.faces.new(a[::-1])
    bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    if bev:
        bevel(o, bev, segs)
    return _finish(o, name, material, parent)


def torus(name, R, r, loc, material, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=32, minor_segments=12,
                                     location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, name, material, parent, smooth_angle=80)


def dome(name, r, loc, material, parent=None, segs=16):
    """Half sphere sitting on loc (LED lens)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=8, radius=r, location=loc)
    o = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-6], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    return _finish(o, name, material, parent, smooth_angle=80)


def apply_mods(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def cut(target, cutters):
    """Boolean difference with one or more cutters (target's own modifiers are applied first)."""
    if not isinstance(cutters, (list, tuple)):
        cutters = [cutters]
    apply_mods(target)
    for c in cutters:
        m = target.modifiers.new("Cut", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.object = c
        m.solver = "EXACT"
        m.use_self = True
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.modifier_apply(modifier="Cut")
        bpy.data.objects.remove(c, do_unlink=True)
    # re-shade: new faces from the cut must get sharp edges, and weighted normals keep
    # big flat faces flat (otherwise smooth shading smears across the n-gons)
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30))
    wn = target.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.mode = "FACE_AREA"


def reparent(objs, parent):
    """Parent while keeping world position, with a clean local transform (no parent-inverse)."""
    bpy.context.view_layer.update()
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = parent
        o.matrix_parent_inverse.identity()
        bpy.context.view_layer.update()
        o.matrix_world = mw


def text(name, body, loc, size, material, parent=None, rot=(0, 0, 0), align="CENTER", extrude=0.00008):
    """Flat label converted to mesh (no font dependency in Godot)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.resolution_u = 2
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    bpy.context.view_layer.objects.active = o
    for s in bpy.context.selected_objects:
        s.select_set(False)
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    o.data.materials.clear()
    o.data.materials.append(material)
    if parent:
        o.parent = parent
    return o


def join(name, objs, parent=None):
    """Merge several static decoration meshes into one object (keeps their materials)."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    if parent:
        mw = o.matrix_world.copy()
        o.parent = parent
        o.matrix_world = mw
    return o


# ---------------------------------------------------------------- studio / render
def studio(sc, scale=1.0, floor_color=(0.30, 0.31, 0.33)):
    world = bpy.data.worlds.new("Studio")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.57, 0.62, 1)
    bg.inputs["Strength"].default_value = 0.18

    fm = mat("_Floor", floor_color, rough=0.55)
    bpy.ops.mesh.primitive_plane_add(size=6 * scale, location=(0, 0, -0.0001))
    floor = bpy.context.active_object
    floor.name = "_Floor"
    floor.data.materials.append(fm)

    def area(name, loc, energy, size, color=(1, 1, 1)):
        bpy.ops.object.light_add(type="AREA", location=[c * scale for c in loc])
        l = bpy.context.active_object
        l.name = name
        l.data.energy = energy * scale * scale
        l.data.size = size * scale
        l.data.color = color
        d = Vector((0, 0, 0.05 * scale)) - l.location
        l.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        return l

    area("_Key", (0.6, -0.6, 0.8), 32, 0.8, (1.0, 0.96, 0.9))
    area("_Fill", (-0.8, -0.3, 0.5), 10, 1.2, (0.85, 0.9, 1.0))
    area("_Rim", (-0.2, 0.8, 0.6), 25, 0.6)

    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    return floor


def shoot(sc, out_path, loc, target, lens=55, fstop=8.0):
    cd = bpy.data.cameras.new("_Cam")
    cd.lens = lens
    cd.dof.use_dof = True
    cd.dof.aperture_fstop = fstop
    cam = bpy.data.objects.new("_Cam", cd)
    sc.collection.objects.link(cam)
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cd.dof.focus_distance = d.length
    sc.camera = cam
    sc.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def export(root, out_dir, name, save_blend=True):
    """Export the root hierarchy to .glb and save a .blend (studio objects start with '_')."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in [root] + list(root.children_recursive):
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, f"{name}.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, f"{name}.blend"), compress=True)
