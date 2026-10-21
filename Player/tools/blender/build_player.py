"""Builds the player as a toon-shaded 3D model and renders pixel-art frames.

Run with Blender (no window needed):
  blender --background --factory-startup --python Player/tools/blender/build_player.py -- <out_dir> [blend_path]

Writes <out_dir>/<view>_<pose>.png (32 x 52 px each, transparent background)
and optionally saves the scene as a .blend you can open and tweak.
Views: down (facing camera), up (back), side (facing right).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "player_render")
BLEND = ARGS[1] if len(ARGS) > 1 else None
os.makedirs(OUT, exist_ok=True)

W, H = 32, 52
WALK_FRAMES = 8
SCALE = int(os.environ.get("PIXEL_SCALE", "1"))  # >1 renders big previews
random.seed(7)

# [highlight, base, shadow] toon ramps
SKIN = ["f7ddc6", "c1789a", "6b2151"]
HAIR = ["f3f2b1", "c19458", "6a3913"]
SHORTS = ["108351", "155236", "0e2e21"]
METAL = ["9ea9ba", "9ea9ba", "576271"]
EYE = ["5bd7ef", "5bd7ef", "5bd7ef"]


def hex_rgba(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # colours are given in sRGB; the ramp works in linear
    lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (*lin, 1.0)


def toon_material(name, ramp):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    cr = nt.nodes.new("ShaderNodeValToRGB")
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    cr.color_ramp.interpolation = "CONSTANT"
    els = cr.color_ramp.elements
    els[0].position, els[0].color = 0.0, hex_rgba(ramp[2])
    els[1].position, els[1].color = 0.18, hex_rgba(ramp[1])
    hi = els.new(0.55)
    hi.color = hex_rgba(ramp[0])
    nt.links.new(diffuse.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs["Color"], cr.inputs["Fac"])
    nt.links.new(cr.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return mat


MAT = {
    "skin": toon_material("Skin", SKIN),
    "hair": toon_material("Hair", HAIR),
    "shorts": toon_material("Shorts", SHORTS),
    "metal": toon_material("Metal", METAL),
    "eye": toon_material("Eye", EYE),
}


# --- scene -------------------------------------------------------------------

scene = bpy.context.scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x = W * SCALE
scene.render.resolution_y = H * SCALE
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.filter_size = 0.0
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 1
except AttributeError:
    pass


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    e.empty_display_size = 0.05
    if parent:
        e.parent = parent
        e.location = Vector(loc) - parent.matrix_world.translation
    else:
        e.location = loc
    bpy.context.view_layer.update()
    return e


def blob(name, parent, loc, scale, mat, rot=(0, 0, 0), kind="sphere"):
    """A shape parented to a joint. loc is in world space at rest."""
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1, depth=2, location=loc)
    else:
        bpy.ops.mesh.primitive_cube_add(location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.rotation_euler = rot
    ob.data.materials.append(MAT[mat])
    bpy.ops.object.shade_smooth()
    mw = ob.matrix_world.copy()
    ob.parent = parent
    ob.matrix_world = mw
    return ob


def limb(name, parent, a, b, r0, r1, mat):
    """Ellipsoid from point a to point b (world, rest pose)."""
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2
    length = (b - a).length
    ob = blob(name, parent, mid, (r0, r1, length / 2 + 0.02), mat)
    direction = (b - a).normalized()
    ob.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    mw = ob.matrix_world.copy()
    ob.matrix_world = mw
    return ob


# The character faces -Y. Joints are empties; rotating them poses the body.
root = empty("Root", (0, 0, 0))
hips = empty("Hips", (0, 0, 0.98), root)
chest = empty("Chest", (0, 0, 1.12), hips)
neck = empty("Neck", (0, 0, 1.50), chest)

blob("Pelvis", hips, (0, 0, 0.98), (0.21, 0.15, 0.13), "shorts")
blob("Abs", chest, (0, -0.02, 1.14), (0.19, 0.14, 0.15), "skin")
blob("Ribs", chest, (0, 0, 1.30), (0.25, 0.16, 0.16), "skin")
blob("PecL", chest, (0.10, -0.09, 1.34), (0.13, 0.09, 0.09), "skin")
blob("PecR", chest, (-0.10, -0.09, 1.34), (0.13, 0.09, 0.09), "skin")
blob("Lats", chest, (0, 0.03, 1.30), (0.30, 0.14, 0.14), "skin")
blob("Traps", chest, (0, 0.03, 1.46), (0.22, 0.11, 0.08), "skin")
blob("NeckMesh", neck, (0, 0, 1.56), (0.085, 0.085, 0.09), "skin")

head = empty("Head", (0, 0, 1.62), neck)
blob("Skull", head, (0, 0, 1.77), (0.16, 0.17, 0.18), "skin")
blob("Jaw", head, (0, -0.05, 1.67), (0.12, 0.11, 0.08), "skin")
blob("EyeL", head, (0.065, -0.155, 1.77), (0.035, 0.015, 0.02), "eye")
blob("EyeR", head, (-0.065, -0.155, 1.77), (0.035, 0.015, 0.02), "eye")

# messy mane: a cap plus spikes thrown outwards, a few falling over one eye
blob("HairCap", head, (0, 0.05, 1.87), (0.185, 0.18, 0.12), "hair")
for i in range(40):
    yaw = random.uniform(0, 2 * math.pi)
    pitch = random.uniform(-0.8, 1.2)
    d = Vector((math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch)))
    if d.y < 0.1 and d.z < 0.75 and abs(d.x) < 0.7:  # keep the face clear
        d.y = abs(d.y) * 0.6 + 0.2
        d.normalize()
    length = random.uniform(0.16, 0.30)
    base = Vector((0, 0.03, 1.80)) + d * 0.13
    tip = base + d * length
    ob = blob(f"Spike{i}", head, (base + tip) / 2, (0.065, 0.065, length / 2), "hair", kind="cone")
    ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
for i, x in enumerate((0.05, 0.0, -0.06)):
    a = Vector((x, -0.15, 1.93))
    b = Vector((x + 0.03, -0.19, 1.76))
    ob = blob(f"Fringe{i}", head, (a + b) / 2, (0.045, 0.045, (b - a).length / 2), "hair", kind="cone")
    ob.rotation_euler = (a - b).normalized().to_track_quat("Z", "Y").to_euler()

head.scale = (1.18, 1.18, 1.18)  # bigger head, like an RPG walk sprite

JOINTS = {}
for side, s in (("L", 1), ("R", -1)):
    sh = empty(f"Shoulder{side}", (0.30 * s, 0, 1.42), chest)
    blob(f"Delt{side}", sh, (0.31 * s, 0, 1.43), (0.11, 0.11, 0.11), "skin")
    limb(f"Bicep{side}", sh, (0.32 * s, 0, 1.40), (0.34 * s, 0, 1.16), 0.095, 0.095, "skin")
    el = empty(f"Elbow{side}", (0.34 * s, 0, 1.15), sh)
    limb(f"Forearm{side}", el, (0.34 * s, 0, 1.15), (0.35 * s, 0, 0.93), 0.08, 0.075, "skin")
    wr = empty(f"Wrist{side}", (0.35 * s, 0, 0.92), el)
    blob(f"Fist{side}", wr, (0.35 * s, -0.01, 0.87), (0.08, 0.085, 0.08), "skin")
    if side == "L":
        blob("Knuckles", wr, (0.35 * s, -0.09, 0.87), (0.07, 0.03, 0.05), "metal", kind="cube")

    hp = empty(f"Hip{side}", (0.12 * s, 0, 0.92), hips)
    blob(f"ShortsLeg{side}", hp, (0.12 * s, 0, 0.84), (0.13, 0.13, 0.12), "shorts")
    limb(f"Thigh{side}", hp, (0.12 * s, 0, 0.88), (0.13 * s, 0, 0.52), 0.11, 0.11, "skin")
    kn = empty(f"Knee{side}", (0.13 * s, 0, 0.50), hp)
    limb(f"Shin{side}", kn, (0.13 * s, 0, 0.50), (0.13 * s, 0, 0.10), 0.085, 0.08, "skin")
    an = empty(f"Ankle{side}", (0.13 * s, 0, 0.08), kn)
    blob(f"Foot{side}", an, (0.13 * s, -0.05, 0.04), (0.07, 0.13, 0.05), "skin")
    JOINTS[side] = dict(sh=sh, el=el, hp=hp, kn=kn)


# --- poses -------------------------------------------------------------------

def reset():
    for ob in scene.objects:
        if ob.type == "EMPTY":
            ob.rotation_euler = (0, 0, 0)
    hips.location.z = 0.98


def pose(guard=1.0, step=0.0, stance=0.0, phase=None):
    """guard: 1 fists up, 0 hands down. step: -1..1 which leg is forward.
    stance: fighting stance (legs apart, knees bent).
    phase: walk cycle angle; sets step and lifts the leg that swings forward."""
    reset()
    if phase is not None:
        step = math.sin(phase)
    L, R = JOINTS["L"], JOINTS["R"]
    # arms: guard lifts the forearms in front of the face; hands down hang loose
    for side, j, s in (("L", L, 1), ("R", R, -1)):
        lead = 1.0 if side == "L" else 0.7
        j["sh"].rotation_euler = (-0.7 * guard * lead + 0.5 * step * s * (1 - guard),
                                  0, 0.15 * s * (1 - guard) - 0.25 * s * guard)
        j["el"].rotation_euler = (-2.5 * guard * lead - 0.35 * (1 - guard), 0, 0)
    # legs
    for side, j, s in (("L", L, 1), ("R", R, -1)):
        swing = -0.38 * step * s
        j["hp"].rotation_euler = (swing - 0.15 * stance * s, 0, 0)
        j["hp"].rotation_euler.y = -0.18 * stance * s
        if phase is not None:
            bend = 0.12 + 0.55 * max(0.0, math.cos(phase) * s)
        else:
            bend = 0.35 * stance + (0.5 if swing > 0.1 else 0.1 * abs(step))
        j["kn"].rotation_euler = (bend, 0, 0)
        j["hp"].rotation_euler.x -= bend * 0.5
    hips.location.z = 0.98 - 0.05 * stance - 0.03 * abs(step)
    neck.rotation_euler = (0, 0, -0.03 * step)  # keep the head (and mane) steady
    chest.rotation_euler = (0.08 * guard, 0, 0.03 * step)


# --- camera and light ----------------------------------------------------------

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.5
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
elev = math.radians(28)
dist = 8
cam.location = (0, -dist * math.cos(elev), 1.06 + dist * math.sin(elev))
cam.rotation_euler = (math.pi / 2 - elev, 0, 0)
cam_data.shift_y = -0.02

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 4
sun_data.angle = 0.0
sun_data.use_shadow = False  # cast shadows add noise that flickers between frames
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(-30), math.radians(-35))

VIEWS = {"down": 0.0, "up": math.pi, "side": math.pi / 2}

POSES = {
    "guard": dict(guard=1.0, stance=1.0),
    "guard_mid": dict(guard=0.5, stance=0.6),
    "guard_down": dict(guard=0.0, stance=0.2),
    # 8-frame walk cycle
    **{f"walk{i}": dict(guard=0.0, phase=2 * math.pi * i / WALK_FRAMES) for i in range(WALK_FRAMES)},
}

for view, yaw in VIEWS.items():
    root.rotation_euler = (0, 0, yaw)
    for name, p in POSES.items():
        pose(**p)
        root.rotation_euler = (0, 0, yaw)
        bpy.context.view_layer.update()
        scene.render.filepath = os.path.join(OUT, f"{view}_{name}.png")
        bpy.ops.render.render(write_still=True)

pose(**POSES["guard"])
root.rotation_euler = (0, 0, 0)
if BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
print("RENDER_DONE", OUT)
