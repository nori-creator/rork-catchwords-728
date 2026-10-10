# Concept B: the sticker peels off completely, then flips face-up toward the viewer (a card-reveal turn).
# Rendered with Cycles from a top-down camera that matches the film: 1 render px = 1 screen px when the tile sits at
# B_POS (540, 1040) at scale 0.74. Output: RGBA frames (sticker + its shadow on a shadow catcher) and peel.json with the
# per-frame fold position (for the backing paper drawn in the film), the finger point and the final pose.
#   blender -b -P peel.py -- OUT_DIR SAMPLES [FRAME_STEP]
import bpy, bmesh, math, json, sys, os
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]; SAMPLES = int(argv[1]) if len(argv) > 1 else 96; STEP = int(argv[2]) if len(argv) > 2 else 1
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
os.makedirs(OUT, exist_ok=True)

TW, TH = 747, 1332                        # tile size (px)
S_SCREEN = 0.62                           # tile scale on screen at rest (B_S in film.html)
REST = (600.0, 1250.0)                    # tile centre on screen at rest (B_POS in film.html)
RW, RH = 1080, 2340                       # render = the whole screen, 1 render px = 1 screen px
SCREEN_OFF = (0, 0)
U = 0.01                                  # world units per tile px
HC = 40.0                                 # camera height (world units)
FIELD_W = RW / S_SCREEN * U               # world width seen at z = 0
FOCAL = 36.0 * HC / FIELD_W

# peel axis (same as film.html peelGeom): from the bottom-right corner towards the top-left
P0 = np.array([TW * .86, TH * .93]); P1 = np.array([TW * .18, TH * .30])
D = (P1 - P0) / np.linalg.norm(P1 - P0); N = np.array([-D[1], D[0]])
U_MIN, U_MAX, V_MIN, V_MAX = 59.0, 1148.0, -372.0, 479.0

FPS = 60
NA = 66                                   # peel frames (1.1 s)
NB = 27                                   # flip frames (0.45 s)

def smooth(x): return x * x * (3 - 2 * x)
def ease_in_out_sine(x): return -(math.cos(math.pi * x) - 1) / 2
def ease_out_cubic(x): return 1 - (1 - x) ** 3
def ease_in_out_cubic(x): return 4 * x ** 3 if x < .5 else 1 - (-2 * x + 2) ** 3 / 2

def peel_params(k):
    """k in [0,1] over the peel. Returns fold position f (tile px along D), bend radius R, flap angle alpha."""
    # the first lift is slow (adhesion), then a steady pull with two tiny stick-slip hesitations, then it lets go
    e = ease_in_out_sine(k)
    e += 0.012 * math.sin(k * math.pi * 6) * math.sin(k * math.pi)
    f = U_MIN - 4 + (U_MAX + 4 - (U_MIN - 4)) * min(1, max(0, e))
    R = 22 + 16 * smooth(k)
    lift = ease_out_cubic(min(1, k / 0.30))                  # the corner comes up and folds back
    alpha = math.radians(20 + 130 * lift - 34 * smooth(max(0, (k - 0.4) / 0.6)))     # ... then the hand raises it
    return f, R, alpha

def curl(u, f, R, alpha):
    """Flat coordinate u -> (u', z) for the peel (vectorised)."""
    s = f - u
    up = u.copy(); z = np.zeros_like(u)
    on_cyl = (s > 0) & (s < R * alpha)
    th = s[on_cyl] / R
    up[on_cyl] = f - R * np.sin(th); z[on_cyl] = R * (1 - np.cos(th))
    st = s >= R * alpha
    r = s[st] - R * alpha
    u0 = f - R * math.sin(alpha); z0 = R * (1 - math.cos(alpha))
    # tangent angle a(r) = alpha + KAPPA * r ; direction (-cos a, sin a)
    a = alpha + KAPPA * r
    up[st] = u0 - (np.sin(a) - math.sin(alpha)) / KAPPA
    z[st] = z0 + (math.cos(alpha) - np.cos(a)) / KAPPA
    return up, z

KAPPA = -1 / 1100.0
KEY_W = float(os.environ.get('KEY_W', '3600'))
AMB = float(os.environ.get('AMB', '0.30'))

# ---------------------------------------------------------------- scene
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = SAMPLES
sc.cycles.use_adaptive_sampling = True
sc.cycles.adaptive_threshold = 0.004
sc.cycles.use_denoising = False
sc.cycles.max_bounces = 4; sc.cycles.transparent_max_bounces = 8
sc.render.resolution_x = RW; sc.render.resolution_y = RH; sc.render.resolution_percentage = 100
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'; sc.view_settings.look = 'None'
sc.render.threads_mode = 'AUTO'

# sheet mesh: a grid in the (u, v) peel frame so the curl has resolution where it bends
nu, nv = int((U_MAX - U_MIN) / 3.0) + 1, int((V_MAX - V_MIN) / 12) + 1
us = np.linspace(U_MIN, U_MAX, nu); vs = np.linspace(V_MIN, V_MAX, nv)
UU, VV = np.meshgrid(us, vs, indexing='ij')
UF, VF = UU.ravel(), VV.ravel()
flat_px = P0[None, :] + UF[:, None] * D[None, :] + VF[:, None] * N[None, :]
me = bpy.data.meshes.new('Sticker')
verts = [(0, 0, 0)] * (nu * nv)
faces = []
for i in range(nu - 1):
    for j in range(nv - 1):
        a = i * nv + j; faces.append((a, a + 1, a + nv + 1, a + nv))
me.from_pydata(verts, [], faces)
uvl = me.uv_layers.new(name='UV')
loop_v = np.zeros(len(me.loops), dtype=np.int64); me.loops.foreach_get('vertex_index', loop_v)
uv = np.stack([flat_px[:, 0] / TW, 1 - flat_px[:, 1] / TH], 1)[loop_v]
uvl.data.foreach_set('uv', uv.ravel())
for p in me.polygons: p.use_smooth = True
sheet = bpy.data.objects.new('Sticker', me); sc.collection.objects.link(sheet)

# materials: glossy laminated front (the sticker art), matte paper back
mat = bpy.data.materials.new('Sticker'); mat.use_nodes = True; mat.blend_method = 'CLIP'
nt = mat.node_tree; nt.nodes.clear()
out = nt.nodes.new('ShaderNodeOutputMaterial')
tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(os.path.join(ASSETS, 'sticker_front.png'))
tex.extension = 'CLIP'; tex.interpolation = 'Cubic'; tex.image.alpha_mode = 'STRAIGHT'
front = nt.nodes.new('ShaderNodeBsdfPrincipled')
front.inputs['Roughness'].default_value = 0.42
front.inputs['Specular IOR Level'].default_value = 0.35
front.inputs['Coat Weight'].default_value = 0.55
front.inputs['Coat Roughness'].default_value = 0.06
nt.links.new(tex.outputs['Color'], front.inputs['Base Color'])
back = nt.nodes.new('ShaderNodeBsdfPrincipled')
back.inputs['Base Color'].default_value = (0.93, 0.92, 0.89, 1)
back.inputs['Roughness'].default_value = 0.85
back.inputs['Specular IOR Level'].default_value = 0.2
noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 420; noise.inputs['Detail'].default_value = 2
bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.08
nt.links.new(noise.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], back.inputs['Normal'])
geo = nt.nodes.new('ShaderNodeNewGeometry')
mix = nt.nodes.new('ShaderNodeMixShader')
nt.links.new(geo.outputs['Backfacing'], mix.inputs['Fac'])
nt.links.new(front.outputs['BSDF'], mix.inputs[1]); nt.links.new(back.outputs['BSDF'], mix.inputs[2])
transp = nt.nodes.new('ShaderNodeBsdfTransparent')
amix = nt.nodes.new('ShaderNodeMixShader')
nt.links.new(tex.outputs['Alpha'], amix.inputs['Fac'])
nt.links.new(transp.outputs['BSDF'], amix.inputs[1]); nt.links.new(mix.outputs['Shader'], amix.inputs[2])
nt.links.new(amix.outputs['Shader'], out.inputs['Surface'])
sheet.data.materials.append(mat)

# shadow catcher on the photo plane
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.002))
catcher = bpy.context.active_object; catcher.is_shadow_catcher = True

# light: a soft sun from the top (calibrated so a flat face-up sticker renders at its own colours) + a softbox
# above-left that only shows up in reflections (the glint that sweeps over the laminate as it turns)
sun_d = bpy.data.lights.new('Key', 'AREA'); sun = bpy.data.objects.new('Key', sun_d); sc.collection.objects.link(sun)
sun_d.shape = 'DISK'; sun_d.size = 14
sun.location = (-4, 9, 22)
sun.rotation_euler = (Vector((4, -9, -22)).to_track_quat('-Z', 'Y')).to_euler()
sun_d.energy = KEY_W; sun_d.color = (1.0, 0.965, 0.92)
world = bpy.data.worlds.new('W'); sc.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (1, 1, 1, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = AMB
box = bpy.data.objects.new('Softbox', bpy.data.meshes.new('Softbox')); sc.collection.objects.link(box)
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=7); bm.to_mesh(box.data); bm.free()
box.location = (-9, 7, 16); box.rotation_euler = (math.radians(-30), math.radians(-38), 0)
em = bpy.data.materials.new('Box'); em.use_nodes = True; en = em.node_tree
en.nodes.clear(); eo = en.nodes.new('ShaderNodeOutputMaterial'); ee = en.nodes.new('ShaderNodeEmission')
ee.inputs['Strength'].default_value = 3.2; en.links.new(ee.outputs['Emission'], eo.inputs['Surface']); box.data.materials.append(em)
box.visible_camera = False; box.visible_shadow = False; box.visible_diffuse = False

cam_d = bpy.data.cameras.new('Cam'); cam_d.lens = FOCAL; cam_d.sensor_fit = 'HORIZONTAL'; cam_d.sensor_width = 36
cam_d.clip_start = 1; cam_d.clip_end = 200
cam = bpy.data.objects.new('Cam', cam_d); sc.collection.objects.link(cam); sc.camera = cam
CAM_X = (RW / 2 - REST[0]) / S_SCREEN * U; CAM_Y = -(RH / 2 - REST[1]) / S_SCREEN * U
cam.location = (CAM_X, CAM_Y, HC); cam.rotation_euler = (0, 0, 0)

def to_world(px, py, z):
    return np.stack([(px - TW / 2) * U, -(py - TH / 2) * U, z * U], 1)

def proj(p):
    co = world_to_camera_view(sc, cam, Vector(p))
    return [co.x * RW + SCREEN_OFF[0], (1 - co.y) * RH + SCREEN_OFF[1]]

# ---------------------------------------------------------------- shapes
def phase_a(k):
    f, R, alpha = peel_params(k)
    up, z = curl(UF, f, R, alpha)
    px = P0[None, :] + up[:, None] * D[None, :] + VF[:, None] * N[None, :]
    return to_world(px[:, 0], px[:, 1], z), (f, R, alpha)

flat_local = to_world(flat_px[:, 0], flat_px[:, 1], np.zeros(len(UF)))       # rest pose (world)
centroid_flat = flat_local.mean(0)
L0 = flat_local - centroid_flat

def kabsch(A, B):
    """Rotation Rm and translation t minimising |Rm A + t - B| (rows are points)."""
    ca, cb = A.mean(0), B.mean(0)
    H = (A - ca).T @ (B - cb)
    Uu, S, Vt = np.linalg.svd(H)
    dd = np.sign(np.linalg.det(Vt.T @ Uu.T))
    Dm = np.diag([1, 1, dd])
    Rm = Vt.T @ Dm @ Uu.T
    return Rm, cb - Rm @ ca

PJ, _ = phase_a(1.0)
RJ, tJ = kabsch(L0, PJ)
BJ = (np.linalg.inv(RJ) @ (PJ - tJ).T).T - L0                                 # the curl left in the free sticker
# final pose: face-up, flat, lifted toward the viewer (apparent scale 1.1), a touch rotated, centred at screen (540, 860)
Z_F = HC * (1 - 1 / 1.1)
target_screen = np.array([540.0, 900.0])
# invert the projection for the centre at height Z_F: screen -> world at that height
cx = CAM_X + (target_screen[0] - RW / 2) / RW * FIELD_W * (HC - Z_F) / HC
cy = CAM_Y - (target_screen[1] - RH / 2) / RW * FIELD_W * (HC - Z_F) / HC
ROT_F = math.radians(-4)
RF = np.array(Matrix.Rotation(ROT_F, 3, 'Z'))
tF = np.array([cx, cy, Z_F])
qJ = Matrix(RJ.tolist()).to_quaternion(); qF = Matrix(RF.tolist()).to_quaternion()
if qJ.dot(qF) < 0: qF = -qF

def phase_b(k):
    e = ease_in_out_cubic(k)
    q = qJ.slerp(qF, e); Rm = np.array(q.to_matrix())
    # path: rise a little above the line between the poses (it is lifted while turning)
    mid = (tJ + tF) / 2 + np.array([0, 0, 1.2])
    t = (1 - e) ** 2 * tJ + 2 * (1 - e) * e * mid + e ** 2 * tF
    bend = BJ * (1 - smooth(min(1, k * 1.3)))
    # a slight bow along the long side mid-turn: the sticker flexes as it flips
    bow = np.zeros_like(L0); L = np.linalg.norm(L0[:, :2], axis=1)
    bow[:, 2] = 0.35 * math.sin(math.pi * k) * (1 - (L / L.max()) ** 2)
    P = (Rm @ (L0 + bend + bow).T).T + t
    return P

# ---------------------------------------------------------------- render
meta = {'rest': REST, 'restScale': S_SCREEN, 'fps': FPS, 'na': NA, 'nb': NB, 'render': [RW, RH], 'screenOffset': SCREEN_OFF, 'tile': [TW, TH],
        'd': D.tolist(), 'p0': P0.tolist(), 'frames': []}
tip_idx = int(np.argmin(np.abs(UF - 72) + np.abs(VF + 115) * 0.6))         # the corner that lifts first (u 66, v -115)
frames = [('a', i / (NA - 1)) for i in range(NA)] + [('b', (i + 1) / NB) for i in range(NB)]
for n, (ph, k) in enumerate(frames):
    if n % STEP: continue
    if ph == 'a': P, (f, R, alpha) = phase_a(k)
    else: P = phase_b(k); f, R, alpha = U_MAX + 4, 0, 0
    me.vertices.foreach_set('co', P.astype(np.float32).ravel()); me.update()
    pts = np.array([proj(p) for p in P[::37]])
    x0, y0 = pts.min(0) - 150; x1, y1 = pts.max(0) + 150
    sc.render.use_border = True; sc.render.use_crop_to_border = False
    sc.render.border_min_x = max(0, x0 / RW); sc.render.border_max_x = min(1, x1 / RW)
    sc.render.border_min_y = max(0, 1 - y1 / RH); sc.render.border_max_y = min(1, 1 - y0 / RH)
    sc.render.filepath = os.path.join(OUT, f'peel_{n:03d}.png')
    bpy.ops.render.render(write_still=True)
    meta['frames'].append({'i': n, 'phase': ph, 'k': round(k, 4), 'fold': round(float(f), 2), 'finger': [round(c, 1) for c in proj(P[tip_idx])]})
    print('frame', n, ph, round(k, 3), flush=True)
# final pose for the film to take over (screen px): centre, apparent scale of the tile, rotation
meta['final'] = {'center': [round(c, 1) for c in proj(tF)], 'scale': round(S_SCREEN * HC / (HC - Z_F), 4), 'rot': ROT_F}
json.dump(meta, open(os.path.join(OUT, 'peel.json'), 'w'), indent=1)
print('DONE', meta['final'])
