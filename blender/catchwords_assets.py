"""
CatchWords の 3D 素材を Blender で作る（手作業なし・毎回同じ物ができる）。

作る物（ios/CatchWords/Resources/3D/ に .usdz で書き出す）:
  DexBook.usdz      図鑑の本（表紙・背・紙の束）。表紙の色はアプリ側で棚ごとに塗る。
                    名前付きの部品: BookCover / BookSpine / BookPages / BookLabel
  （瓶・星・アルバムは画面で使わなくなったので作らない。2026-10-01 整理）

使い方（Blender 4.5 LTS。Mac は不要）:
  pip install "bpy==4.5.*"            # Python 3.11
  python blender/catchwords_assets.py              # .usdz を書き出す
  python blender/catchwords_assets.py --previews   # 確認用の PNG も描く（blender/previews/）

GitHub の Actions「3D assets（3D 素材を作り直す）」でも同じことができる。

決めごと:
- 単位はメートル。iPhone の RealityKit は Y が上なので、Y 上で書き出す。
- 色や質感は UsdPreviewSurface（iOS がそのまま読める形）で持たせる。
  ガラスの透け具合・表紙の色・写真はアプリ側で上書きする（部品名で探す）。
"""

import math
import os
import sys

import bpy  # noqa: E402  (bpy を先に読み込むと bmesh / mathutils が使えるようになる)
import bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "ios", "CatchWords", "Resources", "3D")
PREVIEW_DIR = os.path.join(ROOT, "blender", "previews")


# ---------------------------------------------------------------- helpers


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def material(name, color, metallic=0.0, roughness=0.5, alpha=1.0, emission=None, coat=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if coat:
        bsdf.inputs["Coat Weight"].default_value = coat
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if alpha < 1.0:
        mat.surface_render_method = "BLENDED"
        # 確認用の絵（Cycles）ではガラスらしく透過させる。iOS には opacity だけが届く。
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        bsdf.inputs["IOR"].default_value = 1.45
    return mat


def srgb(hex_value):
    """#RRGGBB → linear RGB (Blender の色は linear)."""
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin((hex_value >> 16) & 255), lin((hex_value >> 8) & 255), lin(hex_value & 255))


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def shade_smooth(obj, angle=40):
    for p in obj.data.polygons:
        p.use_smooth = True
    if hasattr(obj.data, "set_sharp_from_angle"):
        obj.data.set_sharp_from_angle(angle=math.radians(angle))


def bevel(obj, width, segments=3):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    apply_modifiers(obj)


def lathe(name, profile, segments=64, caps=True):
    """profile: [(radius, z), ...] を Z 軸まわりに回した面（瓶・コルク用）。"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((a[i], a[j], b[j], b[i]))
    # 端を閉じる（半径 0 でなければ面を張る）
    if caps and profile[0][0] > 0:
        bm.faces.new(list(reversed(rings[0])))
    if caps and profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def box(name, size, location=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return obj


def plane(name, size, location, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    obj.scale = (size[0], size[1], 1)
    bpy.ops.object.transform_apply(scale=True)
    return obj


def export_usdz(filename):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.wm.usd_export(
        filepath=path,
        export_materials=True,
        generate_preview_surface=True,
        export_uvmaps=True,
        export_normals=True,
        export_animation=False,
        export_lights=False,
        export_cameras=False,
        evaluation_mode="RENDER",
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        triangulate_meshes=True,
        root_prim_path="/root",
        meters_per_unit=1.0,
        convert_scene_units="METERS",
    )
    print("wrote", os.path.relpath(path, ROOT), f"{os.path.getsize(path) / 1024:.0f} KB")
    return path


# ---------------------------------------------------------------- models


def build_book():
    """図鑑の本: 布張りの表紙（厚紙）、丸い背、少し小さい紙の束。縦 0.2m。"""
    cloth = material("CoverCloth", srgb(0x2F7FE0), roughness=0.75)
    page = material("PageEdge", srgb(0xFBF6EC), roughness=0.95)
    label = material("CoverLabel", srgb(0xFFFFFF), roughness=0.8)
    foil = material("SpineFoil", srgb(0xE9C46A), metallic=1.0, roughness=0.3)

    w, h, t, board = 0.145, 0.200, 0.034, 0.0035
    front = box("BookCover", (w, board, h), (w / 2, -t / 2 + board / 2, h / 2))
    back = box("BookCoverBack", (w, board, h), (w / 2, t / 2 - board / 2, h / 2))
    for b in (front, back):
        bevel(b, 0.0012, 2)
        assign(b, cloth)
    # 背: 半円柱
    spine = lathe("BookSpine", [(t / 2, 0.0), (t / 2, h)], segments=32, caps=False)
    bm = bmesh.new()
    bm.from_mesh(spine.data)
    remove = [f for f in bm.faces if f.calc_center_median().x > 0.0005]
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    bm.to_mesh(spine.data)
    bm.free()
    sol = spine.modifiers.new("Thickness", "SOLIDIFY")
    sol.thickness = board
    apply_modifiers(spine)
    shade_smooth(spine, 60)
    assign(spine, cloth)

    pages = box("BookPages", (w - 0.006, t - board * 2 - 0.001, h - 0.008), ((w - 0.006) / 2 + 0.002, 0, h / 2))
    bevel(pages, 0.0015, 2)
    assign(pages, page)

    # 表紙の札（アプリが棚の名前・写真を貼る）
    lab = plane("BookLabel", (0.095, 0.070), (w * 0.55, -t / 2 - 0.0002, h * 0.62),
                rotation=(math.radians(90), 0, 0))
    assign(lab, label)
    # 背の金の帯 2 本
    for i, z in enumerate((0.030, h - 0.030)):
        bpy.ops.mesh.primitive_cylinder_add(radius=t / 2 + 0.0006, depth=0.004, vertices=32, location=(0, 0, z))
        band = bpy.context.active_object
        band.name = f"SpineBand{i}"
        assign(band, foil)
    return None


def render_preview(name, camera_distance, target_z, angle=(62, 0, 28)):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*srgb(0x0B2548), 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world

    target = Vector((0.06 if name == "DexBook" else 0, 0, target_z))
    rx, _, rz = (math.radians(a) for a in angle)
    offset = Vector((math.sin(rz) * math.sin(rx), -math.cos(rz) * math.sin(rx), math.cos(rx))) * camera_distance
    bpy.ops.object.camera_add(location=target + offset)
    cam = bpy.context.active_object
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.camera = cam

    bpy.ops.object.light_add(type="AREA", location=target + Vector((0.4, -0.5, 0.7)))
    key = bpy.context.active_object
    key.data.energy = 14
    key.data.size = 0.6
    key.rotation_euler = (target - key.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=target + Vector((-0.5, 0.3, 0.4)))
    fill = bpy.context.active_object
    fill.data.energy = 5
    fill.data.size = 1.0
    fill.rotation_euler = (target - fill.location).to_track_quat("-Z", "Y").to_euler()

    os.makedirs(PREVIEW_DIR, exist_ok=True)
    scene.render.filepath = os.path.join(PREVIEW_DIR, f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", os.path.relpath(scene.render.filepath, ROOT))


# ---------------------------------------------------------------- main

MODELS = [
    ("DexBook", build_book, 0.62, 0.10),
]


def main():
    previews = "--previews" in sys.argv
    for name, build, dist, target_z in MODELS:
        reset_scene()
        build()
        export_usdz(f"{name}.usdz")
        if previews:
            render_preview(name, dist, target_z)


if __name__ == "__main__":
    main()
