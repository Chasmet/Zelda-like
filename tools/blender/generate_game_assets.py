"""Generate Android-friendly GLB models from the repository's character sheets.

Usage:
    blender --background --python tools/blender/generate_game_assets.py -- --output generated_models

Blender is used only during the build. Godot imports the generated GLB files and
animates their named pivots at runtime, keeping the APK light enough for Android.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path
from typing import Callable

import bpy

OUTPUT_DIR = Path("generated_models")


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="generated_models")
    return parser.parse_args(argv)


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for blocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(blocks):
            if block.users == 0:
                blocks.remove(block)


def material(
    name: str,
    rgba: tuple[float, float, float, float],
    metallic: float = 0.0,
    roughness: float = 0.58,
    emission: tuple[float, float, float, float] | None = None,
) -> bpy.types.Material:
    found = bpy.data.materials.get(name)
    if found is not None:
        return found
    mat = bpy.data.materials.new(name=name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if rgba[3] < 0.999:
            bsdf.inputs["Alpha"].default_value = rgba[3]
            try:
                mat.blend_method = "BLEND"
            except (AttributeError, TypeError):
                pass
        if emission is not None:
            emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
            strength_input = bsdf.inputs.get("Emission Strength")
            if emission_input is not None:
                emission_input.default_value = emission
            if strength_input is not None:
                strength_input.default_value = 2.5
    return mat


def parent_keep_transform(child: bpy.types.Object, parent: bpy.types.Object) -> None:
    world = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = world


def empty(name: str, location: tuple[float, float, float], parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.location = location
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        parent_keep_transform(obj, parent)
    return obj


def apply_bevel(obj: bpy.types.Object, width: float = 0.035, segments: int = 2) -> None:
    if obj.type != "MESH":
        return
    modifier = obj.modifiers.new(name="SoftBevel", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    except RuntimeError:
        pass


def smooth(obj: bpy.types.Object) -> None:
    if obj.type == "MESH" and obj.data is not None:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True


def cube(name, location, dimensions, mat, parent=None, rotation=(0.0, 0.0, 0.0), bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        apply_bevel(obj, bevel)
    if parent is not None:
        parent_keep_transform(obj, parent)
    return obj


def sphere(name, location, scale, mat, parent=None, segments=18, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    if parent is not None:
        parent_keep_transform(obj, parent)
    return obj


def cylinder(name, location, radius, depth, mat, parent=None, vertices=14, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    apply_bevel(obj, min(radius * 0.16, 0.04), 2)
    smooth(obj)
    if parent is not None:
        parent_keep_transform(obj, parent)
    return obj


def cone(name, location, radius1, radius2, depth, mat, parent=None, vertices=14, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    apply_bevel(obj, min(max(radius1, radius2) * 0.10, 0.035), 2)
    smooth(obj)
    if parent is not None:
        parent_keep_transform(obj, parent)
    return obj


def eye(name: str, x: float, y: float, z: float, parent: bpy.types.Object, iris: bpy.types.Material, size: float = 1.0) -> None:
    white = material("EyeWhite", (0.96, 0.95, 0.90, 1.0), roughness=0.3)
    sphere(f"{name}_White", (x, y, z), (0.070 * size, 0.032 * size, 0.050 * size), white, parent, 12, 7)
    sphere(f"{name}_Iris", (x, y - 0.030 * size, z), (0.030 * size, 0.014 * size, 0.030 * size), iris, parent, 10, 6)


def limb_pair(root, arm_material, leg_material, scale=1.0, arm_x=0.40, leg_x=0.18):
    parts = {}
    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        arm = empty(f"Arm_{suffix}", (sign * arm_x * scale, 0.0, 1.52 * scale), root)
        cylinder(f"Arm_{suffix}_Mesh", (sign * arm_x * scale, 0.0, 1.20 * scale), 0.115 * scale, 0.62 * scale, arm_material, arm)
        leg = empty(f"Leg_{suffix}", (sign * leg_x * scale, 0.0, 0.88 * scale), root)
        cylinder(f"Leg_{suffix}_Mesh", (sign * leg_x * scale, 0.0, 0.43 * scale), 0.14 * scale, 0.86 * scale, leg_material, leg)
        parts[f"arm_{suffix.lower()}"] = arm
        parts[f"leg_{suffix.lower()}"] = leg
    return parts


def sword(parent, x, scale, steel, grip, gold, name="Weapon"):
    weapon = empty(name, (x, -0.02, 1.04 * scale), parent)
    cylinder("SwordGrip", (x, -0.02, 0.96 * scale), 0.035 * scale, 0.30 * scale, grip, weapon, 10)
    cube("SwordGuard", (x, -0.02, 1.10 * scale), (0.34 * scale, 0.08 * scale, 0.07 * scale), gold, weapon, bevel=0.018)
    cube("SwordBlade", (x, -0.02, 1.60 * scale), (0.10 * scale, 0.045 * scale, 0.98 * scale), steel, weapon, bevel=0.012)
    cone("SwordTip", (x, -0.02, 2.13 * scale), 0.07 * scale, 0.0, 0.18 * scale, steel, weapon, 4, (0.0, 0.0, math.radians(45)))
    return weapon


def axe(parent, x, scale, wood, metal):
    weapon = empty("Weapon", (x, -0.02, 1.04 * scale), parent)
    cylinder("AxeHandle", (x, -0.02, 1.40 * scale), 0.045 * scale, 1.20 * scale, wood, weapon, 10)
    cube("AxeHead", (x - 0.15 * scale, -0.02, 1.96 * scale), (0.46 * scale, 0.10 * scale, 0.30 * scale), metal, weapon, rotation=(0.0, 0.0, -0.25), bevel=0.035)
    return weapon


def build_hero() -> bpy.types.Object:
    reset_scene()
    root = empty("HeroKnight", (0.0, 0.0, 0.0))
    skin = material("HeroSkin", (0.43, 0.235, 0.125, 1.0), roughness=0.65)
    hair = material("HeroHair", (0.025, 0.018, 0.014, 1.0), roughness=0.88)
    blue = material("HeroRoyalBlue", (0.025, 0.17, 0.43, 1.0), roughness=0.62)
    white = material("HeroWhiteCloth", (0.72, 0.72, 0.67, 1.0), roughness=0.78)
    green = material("HeroGreenTabard", (0.08, 0.25, 0.18, 1.0), roughness=0.82)
    leather = material("HeroLeather", (0.18, 0.075, 0.025, 1.0), roughness=0.82)
    steel = material("HeroSteel", (0.42, 0.48, 0.53, 1.0), metallic=0.72, roughness=0.28)
    gold = material("HeroGold", (0.72, 0.43, 0.07, 1.0), metallic=0.55, roughness=0.30)
    iris = material("HeroBrownEyes", (0.18, 0.075, 0.025, 1.0), roughness=0.25)
    hips = empty("Hips", (0.0, 0.0, 0.90), root)
    cube("Hips_Mesh", (0.0, 0.0, 0.92), (0.58, 0.36, 0.30), leather, hips, bevel=0.065)
    torso = empty("Torso", (0.0, 0.0, 1.31), root)
    cube("Torso_Mesh", (0.0, 0.0, 1.38), (0.74, 0.43, 0.72), white, torso, bevel=0.085)
    cube("ChestBlue_L", (-0.20, -0.235, 1.42), (0.25, 0.055, 0.52), blue, torso, bevel=0.02)
    cube("ChestBlue_R", (0.20, -0.235, 1.42), (0.25, 0.055, 0.52), blue, torso, bevel=0.02)
    cube("Harness", (0.0, -0.275, 1.48), (0.12, 0.045, 0.86), leather, torso, rotation=(0.0, 0.0, -0.58), bevel=0.018)
    cube("Belt", (0.0, -0.01, 1.04), (0.69, 0.40, 0.14), leather, torso, bevel=0.025)
    cube("BeltBuckle", (0.0, -0.225, 1.04), (0.17, 0.06, 0.16), gold, torso, bevel=0.025)
    for x in (-0.20, 0.20):
        cube(f"Tabard_{x}", (x, -0.02, 0.69), (0.31, 0.30, 0.72), green, hips, rotation=(0.0, 0.0, 0.08 * (1 if x > 0 else -1)), bevel=0.035)
        cube(f"TabardGold_{x}", (x, -0.19, 0.69), (0.035, 0.025, 0.64), gold, hips, bevel=0.008)
    head = empty("Head", (0.0, 0.0, 1.96), root)
    sphere("Head_Mesh", (0.0, 0.0, 1.96), (0.295, 0.265, 0.34), skin, head, 20, 12)
    sphere("ShortHair", (0.0, 0.025, 2.18), (0.275, 0.245, 0.13), hair, head, 18, 10)
    cube("Hairline", (0.0, -0.245, 2.115), (0.47, 0.04, 0.10), hair, head, bevel=0.035)
    cube("Mustache", (0.0, -0.279, 1.88), (0.20, 0.025, 0.035), hair, head, bevel=0.012)
    cone("Goatee", (0.0, -0.276, 1.78), 0.075, 0.02, 0.18, hair, head, 12)
    eye("Eye_L", -0.105, -0.255, 2.01, head, iris)
    eye("Eye_R", 0.105, -0.255, 2.01, head, iris)
    parts = limb_pair(root, blue, leather, 1.0, 0.45, 0.19)
    for side, sign in (("L", -1), ("R", 1)):
        sphere(f"Shoulder_{side}", (sign * 0.45, 0.0, 1.58), (0.19, 0.19, 0.17), blue, parts[f"arm_{side.lower()}"], 14, 8)
        cube(f"ShoulderGold_{side}", (sign * 0.45, -0.14, 1.58), (0.27, 0.055, 0.12), gold, parts[f"arm_{side.lower()}"], bevel=0.022)
        cube(f"Knee_{side}", (sign * 0.19, -0.13, 0.50), (0.28, 0.12, 0.25), blue, parts[f"leg_{side.lower()}"], bevel=0.055)
        cube(f"Boot_{side}", (sign * 0.19, -0.07, 0.09), (0.28, 0.43, 0.19), leather, parts[f"leg_{side.lower()}"], bevel=0.055)
    sword(parts["arm_r"], 0.45, 1.0, steel, leather, gold)
    cape = empty("Cape", (0.0, 0.24, 1.58), root)
    cube("Cape_Mesh", (0.0, 0.31, 1.12), (0.72, 0.065, 1.20), blue, cape, rotation=(0.10, 0.0, 0.0), bevel=0.035)
    cube("CapeGoldTrim", (0.0, 0.275, 0.54), (0.70, 0.025, 0.045), gold, cape, bevel=0.012)
    return root


def build_armored_boar() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyArmoredBoar", (0.0, 0.0, 0.0))
    fur = material("BoarFur", (0.16, 0.075, 0.035, 1.0), roughness=0.93)
    skin = material("BoarSkin", (0.30, 0.17, 0.10, 1.0), roughness=0.88)
    armor = material("BoarArmor", (0.28, 0.27, 0.25, 1.0), metallic=0.62, roughness=0.42)
    bone = material("BoarTusks", (0.72, 0.65, 0.48, 1.0), roughness=0.72)
    eye_mat = material("BoarEyes", (0.95, 0.25, 0.02, 1.0), emission=(1.0, 0.12, 0.01, 1.0))
    torso = empty("Torso", (0.0, 0.0, 1.22), root)
    sphere("Torso_Mesh", (0.0, 0.05, 1.25), (0.58, 0.39, 0.64), armor, torso, 18, 10)
    head = empty("Head", (0.0, -0.15, 1.88), root)
    sphere("Head_Mesh", (0.0, -0.15, 1.86), (0.36, 0.33, 0.34), fur, head, 18, 10)
    sphere("Snout", (0.0, -0.45, 1.78), (0.25, 0.23, 0.17), skin, head, 14, 8)
    for sign in (-1, 1):
        cone(f"Tusk_{sign}", (sign * 0.18, -0.62, 1.73), 0.06, 0.0, 0.28, bone, head, 10, (math.radians(62), 0.0, sign * 0.20))
        cone(f"Ear_{sign}", (sign * 0.25, -0.10, 2.14), 0.12, 0.0, 0.28, fur, head, 8, (0.0, sign * 0.35, 0.0))
        eye(f"Eye_{sign}", sign * 0.12, -0.42, 1.94, head, eye_mat, 0.82)
    parts = limb_pair(root, armor, fur, 1.10, 0.48, 0.20)
    axe(parts["arm_r"], 0.48 * 1.10, 1.05, fur, armor)
    return root


def build_crystal_golem() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyCrystalGolem", (0.0, 0.0, 0.0))
    rock = material("GolemRock", (0.22, 0.25, 0.29, 1.0), roughness=0.96)
    rock2 = material("GolemRockDark", (0.10, 0.13, 0.17, 1.0), roughness=0.97)
    crystal = material("GolemCrystal", (0.02, 0.58, 0.84, 1.0), metallic=0.15, roughness=0.18, emission=(0.01, 0.42, 1.0, 1.0))
    torso = empty("Torso", (0.0, 0.0, 1.33), root)
    cube("Torso_Mesh", (0.0, 0.0, 1.35), (0.95, 0.58, 0.92), rock, torso, bevel=0.14)
    head = empty("Head", (0.0, -0.02, 2.03), root)
    cube("Head_Mesh", (0.0, -0.02, 2.03), (0.52, 0.45, 0.48), rock2, head, bevel=0.11)
    for sign in (-1, 1):
        sphere(f"Eye_{sign}", (sign * 0.12, -0.25, 2.07), (0.06, 0.025, 0.06), crystal, head, 10, 6)
    limb_pair(root, rock, rock2, 1.18, 0.52, 0.23)
    for index, (x, y, z, rotation) in enumerate(((-0.34, 0.27, 2.06, -0.25), (0.0, 0.31, 2.30, 0.0), (0.34, 0.27, 2.06, 0.25), (-0.47, 0.10, 1.63, -0.4), (0.47, 0.10, 1.63, 0.4))):
        cone(f"Crystal_{index}", (x, y, z), 0.12, 0.0, 0.55, crystal, torso, 8, (rotation, 0.0, 0.0))
    return root


def build_lava_hound() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyLavaHound", (0.0, 0.0, 0.0))
    stone = material("LavaStone", (0.08, 0.055, 0.045, 1.0), roughness=0.95)
    lava = material("LavaGlow", (0.95, 0.12, 0.01, 1.0), roughness=0.24, emission=(1.0, 0.05, 0.0, 1.0))
    eye_mat = material("LavaEyes", (1.0, 0.55, 0.02, 1.0), emission=(1.0, 0.25, 0.0, 1.0))
    torso = empty("Torso", (0.0, 0.0, 0.82), root)
    sphere("Torso_Mesh", (0.0, 0.07, 0.84), (0.43, 0.65, 0.37), stone, torso, 16, 9)
    cube("LavaCore", (0.0, -0.36, 0.84), (0.35, 0.08, 0.28), lava, torso, bevel=0.07)
    head = empty("Head", (0.0, -0.60, 1.02), root)
    sphere("Head_Mesh", (0.0, -0.60, 1.02), (0.34, 0.36, 0.30), stone, head, 16, 9)
    cone("Muzzle", (0.0, -0.92, 0.95), 0.20, 0.08, 0.43, stone, head, 12, (math.radians(90), 0.0, 0.0))
    for sign in (-1, 1):
        cone(f"Ear_{sign}", (sign * 0.18, -0.54, 1.34), 0.13, 0.0, 0.32, stone, head, 8)
        sphere(f"Eye_{sign}", (sign * 0.11, -0.88, 1.08), (0.05, 0.025, 0.05), eye_mat, head, 10, 6)
    positions = {"Arm_L": (-0.29, -0.28), "Arm_R": (0.29, -0.28), "Leg_L": (-0.29, 0.32), "Leg_R": (0.29, 0.32)}
    for name, (x, y) in positions.items():
        pivot = empty(name, (x, y, 0.66), root)
        cylinder(f"{name}_Mesh", (x, y, 0.32), 0.115, 0.64, stone, pivot, 12)
        cube(f"{name}_Crack", (x, y - 0.11, 0.40), (0.06, 0.035, 0.30), lava, pivot, bevel=0.01)
    for index, x in enumerate((-0.27, 0.0, 0.27)):
        cone(f"BackSpike_{index}", (x, 0.25, 1.22 + (0.12 if x == 0 else 0.0)), 0.10, 0.0, 0.45, lava, torso, 8)
    return root


def build_anubis_knight() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyAnubisKnight", (0.0, 0.0, 0.0))
    fur = material("AnubisFur", (0.025, 0.030, 0.038, 1.0), roughness=0.88)
    blue = material("AnubisBlue", (0.02, 0.12, 0.24, 1.0), roughness=0.72)
    gold = material("AnubisGold", (0.63, 0.38, 0.06, 1.0), metallic=0.60, roughness=0.30)
    eye_mat = material("AnubisEyes", (0.05, 0.75, 1.0, 1.0), emission=(0.0, 0.45, 1.0, 1.0))
    torso = empty("Torso", (0.0, 0.0, 1.26), root)
    cube("Torso_Mesh", (0.0, 0.0, 1.33), (0.76, 0.43, 0.79), blue, torso, bevel=0.085)
    cube("ChestGold", (0.0, -0.24, 1.44), (0.52, 0.055, 0.38), gold, torso, bevel=0.035)
    head = empty("Head", (0.0, -0.02, 1.98), root)
    sphere("Head_Mesh", (0.0, -0.02, 1.98), (0.28, 0.29, 0.33), fur, head, 16, 9)
    cone("JackalMuzzle", (0.0, -0.35, 1.91), 0.18, 0.06, 0.45, fur, head, 12, (math.radians(90), 0.0, 0.0))
    for sign in (-1, 1):
        cone(f"Ear_{sign}", (sign * 0.17, -0.01, 2.37), 0.12, 0.0, 0.47, fur, head, 8)
        sphere(f"Eye_{sign}", (sign * 0.10, -0.29, 2.04), (0.05, 0.025, 0.05), eye_mat, head, 10, 6)
    parts = limb_pair(root, gold, blue, 1.04, 0.43, 0.18)
    sword(parts["arm_r"], 0.43 * 1.04, 1.02, gold, fur, gold)
    cape = empty("Cape", (0.0, 0.23, 1.52), root)
    cube("Cape_Mesh", (0.0, 0.29, 1.10), (0.68, 0.06, 1.00), blue, cape, rotation=(0.10, 0.0, 0.0), bevel=0.025)
    return root


def build_goblin_raider() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyGoblinRaider", (0.0, 0.0, 0.0))
    skin = material("GoblinSkin", (0.22, 0.48, 0.11, 1.0), roughness=0.86)
    cloth = material("GoblinCloth", (0.18, 0.055, 0.035, 1.0), roughness=0.88)
    steel = material("GoblinSteel", (0.34, 0.37, 0.38, 1.0), metallic=0.60, roughness=0.38)
    leather = material("GoblinLeather", (0.16, 0.07, 0.025, 1.0), roughness=0.86)
    eye_mat = material("GoblinEyes", (0.95, 0.62, 0.03, 1.0), emission=(0.8, 0.18, 0.0, 1.0))
    scale = 0.90
    torso = empty("Torso", (0.0, 0.0, 1.20 * scale), root)
    sphere("Torso_Mesh", (0.0, 0.0, 1.22 * scale), (0.42 * scale, 0.30 * scale, 0.48 * scale), cloth, torso, 16, 9)
    head = empty("Head", (0.0, -0.02, 1.76 * scale), root)
    sphere("Head_Mesh", (0.0, -0.02, 1.76 * scale), (0.31 * scale, 0.27 * scale, 0.30 * scale), skin, head, 16, 9)
    for sign in (-1, 1):
        cone(f"Ear_{sign}", (sign * 0.31 * scale, -0.02, 1.82 * scale), 0.10 * scale, 0.0, 0.36 * scale, skin, head, 8, (0.0, sign * math.radians(78), 0.0))
        eye(f"Eye_{sign}", sign * 0.105 * scale, -0.25 * scale, 1.80 * scale, head, eye_mat, 0.78)
    parts = limb_pair(root, skin, leather, scale, 0.43, 0.18)
    sword(parts["arm_r"], 0.43 * scale, scale, steel, leather, steel)
    sword(parts["arm_l"], -0.43 * scale, scale * 0.90, steel, leather, steel, "Weapon_L")
    return root


def build_ice_ogre() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyIceOgre", (0.0, 0.0, 0.0))
    skin = material("IceOgreSkin", (0.25, 0.48, 0.62, 1.0), roughness=0.82)
    ice = material("IceOgreCrystal", (0.20, 0.72, 0.95, 1.0), metallic=0.10, roughness=0.18, emission=(0.05, 0.35, 0.85, 1.0))
    fur = material("IceOgreFur", (0.75, 0.82, 0.84, 1.0), roughness=0.96)
    leather = material("IceOgreLeather", (0.16, 0.10, 0.06, 1.0), roughness=0.90)
    eye_mat = material("IceOgreEyes", (0.65, 0.95, 1.0, 1.0), emission=(0.2, 0.6, 1.0, 1.0))
    scale = 1.24
    torso = empty("Torso", (0.0, 0.0, 1.22 * scale), root)
    sphere("Torso_Mesh", (0.0, 0.0, 1.22 * scale), (0.48 * scale, 0.36 * scale, 0.55 * scale), skin, torso, 18, 10)
    cube("FurCollar", (0.0, 0.0, 1.63 * scale), (0.82 * scale, 0.50 * scale, 0.20 * scale), fur, torso, bevel=0.09)
    head = empty("Head", (0.0, -0.01, 1.78 * scale), root)
    sphere("Head_Mesh", (0.0, -0.01, 1.78 * scale), (0.31 * scale, 0.28 * scale, 0.31 * scale), skin, head, 16, 9)
    for sign in (-1, 1):
        cone(f"Horn_{sign}", (sign * 0.23 * scale, 0.0, 2.04 * scale), 0.09 * scale, 0.0, 0.34 * scale, ice, head, 9, (0.0, sign * 0.25, 0.0))
        eye(f"Eye_{sign}", sign * 0.105 * scale, -0.26 * scale, 1.82 * scale, head, eye_mat, 0.80)
    parts = limb_pair(root, skin, leather, scale, 0.44, 0.18)
    weapon = empty("Weapon", (0.44 * scale, -0.02, 1.04 * scale), parts["arm_r"])
    cylinder("IceClubHandle", (0.44 * scale, -0.02, 1.38 * scale), 0.055 * scale, 1.15 * scale, leather, weapon, 10)
    sphere("IceClubHead", (0.44 * scale, -0.02, 2.00 * scale), (0.25 * scale, 0.22 * scale, 0.31 * scale), ice, weapon, 12, 7)
    return root


def build_orc_warlord() -> bpy.types.Object:
    reset_scene()
    root = empty("EnemyOrcWarlord", (0.0, 0.0, 0.0))
    skin = material("OrcSkin", (0.31, 0.46, 0.15, 1.0), roughness=0.86)
    leather = material("OrcLeather", (0.17, 0.075, 0.025, 1.0), roughness=0.88)
    iron = material("OrcIron", (0.25, 0.24, 0.22, 1.0), metallic=0.57, roughness=0.47)
    bone = material("OrcBone", (0.66, 0.58, 0.43, 1.0), roughness=0.78)
    eye_mat = material("OrcEyes", (0.95, 0.32, 0.02, 1.0), emission=(0.8, 0.12, 0.0, 1.0))
    scale = 1.20
    torso = empty("Torso", (0.0, 0.0, 1.23 * scale), root)
    sphere("Torso_Mesh", (0.0, 0.0, 1.24 * scale), (0.50 * scale, 0.36 * scale, 0.57 * scale), skin, torso, 18, 10)
    cube("BoneHarness", (0.0, -0.31 * scale, 1.35 * scale), (0.70 * scale, 0.07, 0.25 * scale), bone, torso, rotation=(0.0, 0.0, -0.25), bevel=0.045)
    head = empty("Head", (0.0, -0.02, 1.82 * scale), root)
    sphere("Head_Mesh", (0.0, -0.02, 1.82 * scale), (0.32 * scale, 0.29 * scale, 0.32 * scale), skin, head, 16, 9)
    sphere("Jaw", (0.0, -0.25 * scale, 1.70 * scale), (0.25 * scale, 0.11 * scale, 0.15 * scale), skin, head, 12, 7)
    for sign in (-1, 1):
        cone(f"Tusk_{sign}", (sign * 0.13 * scale, -0.36 * scale, 1.68 * scale), 0.045 * scale, 0.0, 0.20 * scale, bone, head, 9, (math.radians(55), 0.0, sign * 0.10))
        eye(f"Eye_{sign}", sign * 0.11 * scale, -0.28 * scale, 1.88 * scale, head, eye_mat, 0.78)
    parts = limb_pair(root, iron, leather, scale, 0.46, 0.19)
    axe(parts["arm_r"], 0.46 * scale, scale, leather, iron)
    return root


def build_tree() -> bpy.types.Object:
    reset_scene()
    root = empty("WorldTree", (0.0, 0.0, 0.0))
    bark = material("TreeBark", (0.20, 0.075, 0.025, 1.0), roughness=0.95)
    leaf = material("TreeLeaf", (0.035, 0.28, 0.075, 1.0), roughness=0.92)
    leaf2 = material("TreeLeafLight", (0.08, 0.42, 0.11, 1.0), roughness=0.90)
    cylinder("Trunk", (0.0, 0.0, 1.45), 0.30, 2.90, bark, root, 12)
    crowns = ((-0.55, 0.0, 2.95, 1.0), (0.45, 0.05, 3.18, 0.92), (0.0, 0.25, 3.60, 0.88), (0.0, -0.35, 3.25, 0.86))
    for idx, (x, y, z, size) in enumerate(crowns):
        sphere(f"Crown_{idx}", (x, y, z), (1.12 * size, 1.00 * size, 0.88 * size), leaf2 if idx % 2 else leaf, root, 14, 8)
    return root


def build_house() -> bpy.types.Object:
    reset_scene()
    root = empty("VillageHouse", (0.0, 0.0, 0.0))
    plaster = material("HousePlaster", (0.66, 0.52, 0.32, 1.0), roughness=0.93)
    timber = material("HouseTimber", (0.15, 0.055, 0.02, 1.0), roughness=0.90)
    roof = material("HouseRoof", (0.31, 0.055, 0.035, 1.0), roughness=0.90)
    glass = material("HouseGlass", (0.12, 0.44, 0.62, 1.0), roughness=0.18)
    cube("HouseWalls", (0.0, 0.0, 1.45), (4.6, 3.6, 2.9), plaster, root, bevel=0.08)
    cube("Door", (0.0, -1.83, 1.02), (0.92, 0.10, 2.04), timber, root, bevel=0.04)
    for x in (-1.35, 1.35):
        cube(f"Window_{x}", (x, -1.84, 1.62), (0.72, 0.08, 0.72), glass, root, bevel=0.04)
    cube("RoofLeft", (-1.25, 0.0, 3.42), (3.1, 4.2, 0.22), roof, root, (0.0, math.radians(-32), 0.0), 0.03)
    cube("RoofRight", (1.25, 0.0, 3.42), (3.1, 4.2, 0.22), roof, root, (0.0, math.radians(32), 0.0), 0.03)
    return root


def build_ruin_gate() -> bpy.types.Object:
    reset_scene()
    root = empty("RuinGate", (0.0, 0.0, 0.0))
    stone = material("RuinStone", (0.29, 0.31, 0.34, 1.0), roughness=0.96)
    moss = material("RuinMoss", (0.10, 0.24, 0.08, 1.0), roughness=0.98)
    for x in (-2.1, 2.1):
        cube(f"Pillar_{x}", (x, 0.0, 2.3), (1.25, 1.35, 4.6), stone, root, bevel=0.12)
        cube(f"Moss_{x}", (x, -0.70, 3.35), (0.75, 0.06, 0.60), moss, root, bevel=0.03)
    cube("Lintel", (0.0, 0.0, 4.45), (5.4, 1.45, 1.15), stone, root, bevel=0.12)
    return root


def build_boat() -> bpy.types.Object:
    reset_scene()
    root = empty("Boat", (0.0, 0.0, 0.0))
    wood = material("BoatWood", (0.24, 0.075, 0.018, 1.0), roughness=0.84)
    trim = material("BoatTrim", (0.48, 0.20, 0.055, 1.0), roughness=0.78)
    sail = material("BoatSail", (0.78, 0.72, 0.56, 1.0), roughness=0.92)
    cube("Hull", (0.0, 0.0, 0.55), (2.5, 5.8, 0.85), wood, root, bevel=0.28)
    cube("Deck", (0.0, 0.0, 1.02), (2.25, 5.25, 0.18), trim, root, bevel=0.08)
    cone("Bow", (0.0, -3.15, 0.64), 1.25, 0.05, 1.75, wood, root, 4, (math.radians(90), 0.0, math.radians(45)))
    cylinder("Mast", (0.0, 0.0, 3.15), 0.10, 4.2, trim, root, 12)
    cube("Sail", (0.0, -0.05, 3.45), (0.08, 2.9, 2.70), sail, root, bevel=0.02)
    cube("Rudder", (0.0, 3.05, 0.58), (0.18, 0.58, 1.05), trim, root, bevel=0.05)
    return root


def selected_hierarchy(root: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    def recurse(obj: bpy.types.Object) -> None:
        obj.select_set(True)
        for child in obj.children:
            recurse(child)
    recurse(root)
    bpy.context.view_layer.objects.active = root


def export_glb(root: bpy.types.Object, filename: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    selected_hierarchy(root)
    path = (OUTPUT_DIR / filename).resolve()
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
    )
    print(f"Generated {path}")


def generate_all() -> None:
    assets: list[tuple[str, Callable[[], bpy.types.Object]]] = [
        ("hero_knight.glb", build_hero),
        ("enemy_01_armored_boar.glb", build_armored_boar),
        ("enemy_02_crystal_golem.glb", build_crystal_golem),
        ("enemy_03_lava_hound.glb", build_lava_hound),
        ("enemy_04_anubis_knight.glb", build_anubis_knight),
        ("enemy_05_goblin_raider.glb", build_goblin_raider),
        ("enemy_06_ice_ogre.glb", build_ice_ogre),
        ("enemy_07_orc_warlord.glb", build_orc_warlord),
        ("world_tree.glb", build_tree),
        ("village_house.glb", build_house),
        ("ruin_gate.glb", build_ruin_gate),
        ("boat.glb", build_boat),
    ]
    for filename, builder in assets:
        export_glb(builder(), filename)


if __name__ == "__main__":
    args = parse_args()
    OUTPUT_DIR = Path(args.output)
    generate_all()
