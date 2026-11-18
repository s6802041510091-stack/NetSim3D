"""Teachers' room: real keyboards and mice on the five teacher workstations.

build_it_support_and_staff_room.py built TR_Computer_1-5 from plain boxes; the
keyboard was two flat boxes without keys and the mouse a block (60 triangles
for the whole computer). Agreed with the user 2026-11-18: keep the monitor,
tower and mouse pad, swap only the keyboard and mouse for copies of the
detailed NetCare Desktop v2 parts used elsewhere in the school:
- keyboard: TeacherComputerSet_Root / 03_Keyboard (104 keys)
- mouse:    TeacherComputerSet_Root.001 / 04_Mouse (wireless, no cable)

Copies go into one collection per desk named "... | Computer N" and the keys
are named "TR_Computer_N__Key_*", so optimize_school_for_web.py merges each
keyboard's keys into one object and decimates them like the other keyboards.

Run on the lookdev file (it is saved):
  blender -b "Preview/โรงเรียนและเมือง/working/classroom_shell_lookdev.blend" \
          --python 3Dmodel/scripts/replace_teacher_keyboards.py
Then re-export with optimize_school_for_web.py. Running it twice is safe:
already-swapped desks are skipped.
"""
import bmesh
import bpy
from mathutils import Matrix, Vector

DESKS = ["TR_Computer_%d" % i for i in range(1, 6)]
PARENT_COLLECTION = "19.1 | Teacher workstations"
KEYBOARD_SOURCE = ("TeacherComputerSet_Root", "03_Keyboard")
MOUSE_SOURCE = ("TeacherComputerSet_Root.001", "04_Mouse")
# Placeholder parts in TR_Computer local space (desk top = z 0, user at -Y).
# The real keyboard is 1.5 cm wider than the old box; 2 cm further left so its
# number pad clears the mouse pad.
KEYBOARD_AT = Vector((-0.06, -0.12, 0.0))
MOUSE_AT = Vector((0.30, -0.12, 0.003))   # on the kept mouse pad
PLACEHOLDER_MATERIALS = {"SCI | dark plastic", "OF | powder coat graphite"}


def subtree_meshes(root_name, child_name):
    root = bpy.data.objects[root_name]
    start = next(c for c in root.children if c.name.split(".")[0] == child_name)
    found = []

    def walk(obj):
        if obj.type == "MESH" and not obj.hide_render:
            found.append(obj)
        for child in obj.children:
            walk(child)
    walk(start)
    return root, found


def local_bounds(root, objects):
    to_root = root.matrix_world.inverted()
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for obj in objects:
        for corner in obj.bound_box:
            p = to_root @ obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def remove_placeholders(mesh):
    """Drop the keyboard, key-area and mouse boxes; keep monitor, tower, pad."""
    names = [m.name if m else "" for m in mesh.materials]
    bm = bmesh.new()
    bm.from_mesh(mesh)
    doomed = [f for f in bm.faces
              if names[f.material_index] in PLACEHOLDER_MATERIALS
              and f.calc_center_median().y < -0.02 and f.calc_center_median().z > -0.05]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return len(doomed)


def place_copies(desk, root, sources, target, prefix, collection):
    lo, hi = local_bounds(root, sources)
    shift = Matrix.Translation(Vector((target.x - (lo.x + hi.x) / 2, target.y - (lo.y + hi.y) / 2, target.z - lo.z)))
    to_root = root.matrix_world.inverted()
    copies = []
    for src in sources:
        copy = src.copy()  # linked mesh data, like the other duplicated computers
        copy.parent = None
        copy.name = prefix + src.name.split(".")[0]
        collection.objects.link(copy)
        copy.matrix_world = desk.matrix_world @ shift @ to_root @ src.matrix_world
        copies.append(copy)
    return copies, hi - lo


def main():
    parent = bpy.data.collections[PARENT_COLLECTION]
    kb_root, kb_parts = subtree_meshes(*KEYBOARD_SOURCE)
    ms_root, ms_parts = subtree_meshes(*MOUSE_SOURCE)
    print("SOURCES keyboard parts=%d mouse parts=%d" % (len(kb_parts), len(ms_parts)))
    cleaned = set()
    for index, desk_name in enumerate(DESKS, start=1):
        desk = bpy.data.objects[desk_name]
        name = "19.1 | Teacher workstation %d | Computer %d" % (index, index)
        if name in bpy.data.collections:
            print("SKIP", desk_name, "already has real peripherals")
            continue
        if desk.data.name not in cleaned:
            print("CLEAN", desk.data.name, "faces removed:", remove_placeholders(desk.data))
            cleaned.add(desk.data.name)
        collection = bpy.data.collections.new(name)
        parent.children.link(collection)
        prefix = desk_name + "__"
        keys, kb_size = place_copies(desk, kb_root, kb_parts, KEYBOARD_AT, prefix, collection)
        mice, ms_size = place_copies(desk, ms_root, ms_parts, MOUSE_AT, prefix, collection)
        print("PLACED %s keyboard=%d parts %s mouse=%d parts %s" % (desk_name, len(keys), tuple(round(v, 3) for v in kb_size), len(mice), tuple(round(v, 3) for v in ms_size)))
    bpy.ops.wm.save_mainfile()
    print("SAVED", bpy.data.filepath)


main()
