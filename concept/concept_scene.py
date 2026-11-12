"""Concept art: toy-diorama restaurant cutaway. Run: Blender -b -P concept_scene.py -- out.png"""
import bpy, sys, math

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene

_mats = {}
def mat(rgb, emit=0.0, alpha=1.0):
    key = (rgb, emit, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 0.85
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    _mats[key] = m
    return m

def hexc(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))

def box(x, y, z, sx, sy, sz, col, bevel=0.04, **kw):
    """Box centred at x,y with its base at z."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z + sz / 2))
    o = bpy.context.object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    o.data.materials.append(mat(hexc(col), **kw))
    return o

def cyl(x, y, z, r, h, col, verts=32, **kw):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=(x, y, z + h / 2))
    o = bpy.context.object
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat(hexc(col), **kw))
    return o

def ball(x, y, z, r, col, **kw):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z))
    o = bpy.context.object
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat(hexc(col), **kw))
    return o

MOOD = {"joy": "#5fd38d", "meh": "#ffd34e", "mad": "#ff6b5e"}
SKIN = ["#f2c9a1", "#c68958", "#8a5a3c", "#f7dcc0"]

def person(x, y, shirt, skin=0, mood=None, seated=False, hat=None, plate=False):
    z = 0.0 if not seated else 0.12
    h = 0.62 if not seated else 0.48
    cyl(x, y, z, 0.2, h, shirt)
    ball(x, y, z + h, 0.2, shirt)
    ball(x, y, z + h + 0.34, 0.27, SKIN[skin])
    if hat == "chef":
        cyl(x, y, z + h + 0.52, 0.2, 0.22, "#ffffff")
        ball(x, y, z + h + 0.76, 0.23, "#ffffff")
    if plate:
        cyl(x + 0.32, y - 0.1, z + 0.5, 0.17, 0.03, "#ffffff")
        ball(x + 0.32, y - 0.1, z + 0.56, 0.09, "#e8873a")
    if mood:
        ball(x, y, z + h + 0.95, 0.13, MOOD[mood], emit=1.5)

def counter(x, y, top="#f4ead8", body="#3f7f86"):
    box(x, y, 0, 0.94, 0.94, 0.8, body)
    box(x, y, 0.8, 1.0, 1.0, 0.08, top, bevel=0.02)

def table(x, y, moods, shirts):
    cyl(x, y, 0, 0.09, 0.62, "#7a5235")
    cyl(x, y, 0.62, 0.62, 0.07, "#f6efe2")
    for i, dx in enumerate((-0.95, 0.95)):
        box(x + dx, y, 0, 0.42, 0.42, 0.36, "#d9534f" if i == 0 else "#e9a23b")
        if moods[i]:
            person(x + dx, y, shirts[i], skin=(i + int(x)) % 4, mood=moods[i], seated=True)
            cyl(x + dx * 0.4, y, 0.69, 0.15, 0.03, "#ffffff")

# ---------- ground & street ----------
box(5, 2, -0.6, 60, 60, 0.5, "#f3e3c8", bevel=0)           # backdrop
box(5, 3.5, -0.12, 10.5, 7.5, 0.12, "#5a4636", bevel=0.03)  # slab
box(5, -1.3, -0.12, 10.5, 2.0, 0.1, "#cdbfae", bevel=0.03)  # sidewalk

# ---------- floors ----------
for ix in range(4):
    for iy in range(7):
        box(ix + 0.5, iy + 0.5, 0, 0.98, 0.98, 0.02, "#f4ead8" if (ix + iy) % 2 else "#8fc7c3", bevel=0)
for iy in range(7):
    box(7, iy + 0.5, 0, 5.98, 0.96, 0.02, "#d9a066" if iy % 2 else "#cf9458", bevel=0)

# ---------- cutaway walls ----------
box(5, 7.1, 0, 10.4, 0.2, 2.2, "#fff6e6")
box(-0.1, 3.5, 0, 0.2, 7.4, 2.2, "#fff6e6")
box(7, 6.98, 1.1, 5.8, 0.05, 0.9, "#e56b5d", bevel=0)       # dining wainscot colour band
for wx in (5.5, 8.5):                                       # windows
    box(wx, 6.97, 1.05, 1.3, 0.08, 0.9, "#9fd4ea", bevel=0.02)
box(2, 6.98, 1.45, 3.0, 0.1, 0.06, "#7a5235", bevel=0)       # kitchen shelf
for i, c in enumerate(["#e9a23b", "#d9534f", "#5fd38d", "#ffffff", "#e9a23b"]):
    cyl(0.9 + i * 0.55, 6.9, 1.48, 0.1, 0.22, c)

# ---------- kitchen ----------
box(0.5, 6.5, 0, 0.9, 0.9, 1.9, "#e8eef0")                   # fridge
box(0.93, 6.2, 0.9, 0.05, 0.08, 0.5, "#8a949a", bevel=0)
counter(1.5, 6.5, top="#33373b", body="#8a949a")            # stove
for dx, dy in ((-0.22, -0.2), (0.22, -0.2), (-0.22, 0.2), (0.22, 0.2)):
    cyl(1.5 + dx, 6.5 + dy, 0.88, 0.14, 0.02, "#ff6b5e", emit=2.0)
cyl(1.28, 6.3, 0.9, 0.17, 0.16, "#2b2e31")                   # pot
counter(2.5, 6.5)
box(2.5, 6.5, 0.88, 0.5, 0.35, 0.04, "#c98a4b")              # chopping board
ball(2.4, 6.5, 0.97, 0.08, "#d9534f"); ball(2.6, 6.55, 0.97, 0.08, "#5fd38d")
counter(3.5, 6.5)
box(3.5, 6.5, 0.86, 0.6, 0.5, 0.04, "#7fb8d6", bevel=0.02)   # sink
for y in (4.5, 3.5):
    counter(0.5, y)
for i in range(3):
    cyl(0.5, 4.5, 0.88 + i * 0.035, 0.2, 0.03, "#ffffff")    # plate stack
cyl(0.5, 1.0, 0, 0.3, 0.7, "#5b6b57")                        # trash
cyl(0.5, 1.0, 0.7, 0.33, 0.06, "#42503f")
for y in (2.5, 3.5, 4.5, 5.5):                               # the pass
    counter(4, y, top="#f6efe2", body="#e56b5d")
cyl(4, 3.5, 0.88, 0.17, 0.03, "#ffffff"); ball(4, 3.5, 0.94, 0.09, "#e8873a")
cyl(4, 4.5, 0.88, 0.07, 0.12, "#ffd34e", emit=1.0)           # order bell

person(2.0, 5.4, "#ffffff", skin=1, hat="chef")
person(3.0, 2.2, "#4a6fa5", skin=3, plate=True)

# ---------- dining ----------
table(6.4, 5.0, ("joy", "joy"), ("#b85c9e", "#3f7f86"))
table(8.6, 2.6, ("meh", None), ("#e9a23b", "#4a6fa5"))
table(6.2, 2.0, ("mad", "joy"), ("#6c5ce7", "#d9534f"))
cyl(9.4, 6.4, 0, 0.26, 0.4, "#c96f4a")                       # plant
ball(9.4, 6.4, 0.75, 0.42, "#4f9d69"); ball(9.55, 6.3, 1.1, 0.28, "#5fb37a")

# blueprint: a delivered crate + its ghost footprint
box(9.0, 4.8, 0.02, 1.9, 1.0, 0.02, "#3d8bff", bevel=0, emit=1.2)
box(9.0, 4.8, 0.04, 1.8, 0.9, 0.9, "#3d8bff", alpha=0.28)
box(8.9, 0.7, 0, 0.8, 0.8, 0.7, "#c98a4b")
box(8.9, 0.7, 0.3, 0.84, 0.84, 0.1, "#3d8bff", bevel=0.01)

# ---------- entrance & queue ----------
box(5.5, 0.15, 0.02, 1.2, 0.5, 0.02, "#d9534f", bevel=0)     # door mat
for x in (4.75, 6.25):
    box(x, 0.0, 0, 0.14, 0.14, 2.0, "#7a5235")
box(5.5, 0.0, 2.0, 1.9, 0.2, 0.34, "#e56b5d")                # sign board
person(5.5, -0.9, "#3f7f86", skin=2, mood="joy")
person(6.4, -1.2, "#e9a23b", skin=0, mood="meh")
person(7.3, -1.0, "#b85c9e", skin=1, mood="meh")
person(8.2, -1.3, "#6c5ce7", skin=3, mood="mad")
box(3.2, -1.2, 0, 0.5, 0.1, 0.9, "#33373b")                  # A-frame sign
box(3.2, -1.26, 0.2, 0.4, 0.02, 0.6, "#f6efe2", bevel=0)

# ---------- light & camera ----------
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(8), math.radians(-25)))
bpy.context.object.data.energy = 2.6
bpy.context.object.data.angle = math.radians(8)
w = bpy.data.worlds.new("w"); S.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.93, 0.85, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.45

bpy.ops.object.empty_add(location=(4.9, 2.7, 0.6)); tgt = bpy.context.object
bpy.ops.object.camera_add(location=(4.9 + 20, 2.7 - 20, 0.6 + 17))
cam = bpy.context.object
cam.data.type = "ORTHO"; cam.data.ortho_scale = 16.8
c = cam.constraints.new("TRACK_TO"); c.target = tgt
S.camera = cam

S.render.engine = "CYCLES"
S.cycles.samples = 64
S.cycles.use_denoising = True
S.render.resolution_x, S.render.resolution_y = 1600, 1000
S.view_settings.view_transform = "Standard"
S.render.filepath = out
bpy.ops.render.render(write_still=True)
