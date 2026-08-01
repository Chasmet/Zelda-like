"""Generate the Android game assets and a fully articulated Cheikh hero.

Enemies and scenery still come from the original open-source generator.  The
playable hero is rebuilt from the supplied royal-knight reference: dark skin,
shaved head, blue cloak, white-and-blue tunic, gold armour and green tabard.
Every limb uses a real local pivot so Godot can animate walking, running,
attacking, jumping and dodging instead of sliding a rigid model.
"""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy
from mathutils import Matrix

SCRIPT_PATH = Path(__file__).with_name("generate_game_assets.py")
spec = importlib.util.spec_from_file_location("base_asset_generator", SCRIPT_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load {SCRIPT_PATH}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def local_empty(name, location, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = location
    return obj


def local_parent(obj, parent, location=(0.0, 0.0, 0.0), rotation=(0.0, 0.0, 0.0)):
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = location
    obj.rotation_euler = rotation
    return obj


def local_cube(name, location, dimensions, material, parent, rotation=(0.0, 0.0, 0.0), bevel=0.035):
    obj = base.cube(name, (0.0, 0.0, 0.0), dimensions, material, None, bevel=bevel)
    return local_parent(obj, parent, location, rotation)


def local_sphere(name, location, scale, material, parent, segments=20, rings=12):
    obj = base.sphere(name, (0.0, 0.0, 0.0), scale, material, None, segments, rings)
    return local_parent(obj, parent, location)


def local_cylinder(name, location, radius, depth, material, parent, vertices=16, rotation=(0.0, 0.0, 0.0)):
    obj = base.cylinder(name, (0.0, 0.0, 0.0), radius, depth, material, None, vertices, rotation)
    return local_parent(obj, parent, location, rotation)


def local_cone(name, location, radius1, radius2, depth, material, parent, vertices=16, rotation=(0.0, 0.0, 0.0)):
    obj = base.cone(name, (0.0, 0.0, 0.0), radius1, radius2, depth, material, None, vertices, rotation)
    return local_parent(obj, parent, location, rotation)


def local_eye(name, x, y, z, parent, iris, size=1.0):
    white = base.material("CheikhEyeWhite", (0.96, 0.95, 0.91, 1.0), roughness=0.30)
    local_sphere(f"{name}_White", (x, y, z), (0.068 * size, 0.032 * size, 0.050 * size), white, parent, 14, 8)
    local_sphere(f"{name}_Iris", (x, y - 0.031 * size, z), (0.029 * size, 0.014 * size, 0.029 * size), iris, parent, 12, 7)


def build_sword(parent, steel, leather, gold):
    weapon = local_empty("Weapon", (0.0, -0.02, -0.66), parent)
    local_cylinder("SwordGrip", (0.0, 0.0, 0.02), 0.040, 0.31, leather, weapon, 12)
    local_cube("SwordGuard", (0.0, 0.0, 0.19), (0.34, 0.09, 0.08), gold, weapon, bevel=0.018)
    local_cube("SwordBlade", (0.0, 0.0, 0.72), (0.105, 0.050, 0.98), steel, weapon, bevel=0.012)
    local_cone("SwordTip", (0.0, 0.0, 1.28), 0.075, 0.0, 0.19, steel, weapon, 4, (0.0, 0.0, math.radians(45.0)))
    weapon.rotation_euler = (math.radians(-8.0), 0.0, math.radians(-10.0))
    return weapon


def build_hero_v3():
    base.reset_scene()
    root = local_empty("CHKHeroRoyalKnight", (0.0, 0.0, 0.0))

    skin = base.material("CHKCaramelSkin", (0.34, 0.185, 0.105, 1.0), roughness=0.64)
    skin_light = base.material("CHKSkinHighlight", (0.44, 0.255, 0.155, 1.0), roughness=0.61)
    skin_shadow = base.material("CHKSkinShadow", (0.19, 0.088, 0.045, 1.0), roughness=0.72)
    brows = base.material("CheikhBrows", (0.020, 0.014, 0.011, 1.0), roughness=0.92)
    lips = base.material("CheikhLips", (0.22, 0.070, 0.055, 1.0), roughness=0.72)
    iris = base.material("CheikhBrownEyes", (0.20, 0.075, 0.022, 1.0), roughness=0.22)

    royal_blue = base.material("ReferenceRoyalBlue", (0.025, 0.115, 0.34, 1.0), metallic=0.24, roughness=0.43)
    cloak_blue = base.material("ReferenceBlueCloak", (0.025, 0.16, 0.43, 1.0), roughness=0.72)
    ivory = base.material("ReferenceIvoryCloth", (0.82, 0.80, 0.72, 1.0), roughness=0.78)
    emerald = base.material("ReferenceEmeraldTabard", (0.035, 0.23, 0.16, 1.0), roughness=0.82)
    leather = base.material("ReferenceDarkLeather", (0.095, 0.038, 0.018, 1.0), roughness=0.84)
    steel = base.material("ReferenceSteel", (0.40, 0.49, 0.58, 1.0), metallic=0.80, roughness=0.23)
    dark_steel = base.material("ReferenceDarkSteel", (0.075, 0.10, 0.15, 1.0), metallic=0.72, roughness=0.30)
    gold = base.material("ReferenceAntiqueGold", (0.72, 0.43, 0.075, 1.0), metallic=0.68, roughness=0.28)

    hips = local_empty("Hips", (0.0, 0.0, 0.94), root)
    local_cube("PelvisArmour", (0.0, 0.0, 0.0), (0.62, 0.39, 0.28), leather, hips, bevel=0.070)
    local_cube("RoyalBelt", (0.0, -0.015, 0.16), (0.76, 0.43, 0.13), leather, hips, bevel=0.030)
    local_cube("DiamondBuckle", (0.0, -0.235, 0.16), (0.19, 0.055, 0.19), gold, hips, rotation=(0.0, 0.0, math.radians(45.0)), bevel=0.020)
    local_cube("BuckleGem", (0.0, -0.270, 0.16), (0.105, 0.025, 0.105), royal_blue, hips, rotation=(0.0, 0.0, math.radians(45.0)), bevel=0.012)

    for side_name, x in (("L", -0.19), ("R", 0.19)):
        tabard = local_empty(f"Tabard_{side_name}", (x, -0.015, -0.05), hips)
        local_cube(f"TabardCloth_{side_name}", (0.0, 0.0, -0.38), (0.31, 0.30, 0.78), emerald, tabard, rotation=(0.0, 0.0, -0.035 if x < 0 else 0.035), bevel=0.030)
        local_cube(f"TabardGoldOuter_{side_name}", ((-0.132 if x < 0 else 0.132), -0.166, -0.38), (0.035, 0.020, 0.68), gold, tabard, bevel=0.006)
        local_cube(f"TabardGoldBottom_{side_name}", (0.0, -0.166, -0.745), (0.27, 0.020, 0.040), gold, tabard, bevel=0.006)

    torso = local_empty("Torso", (0.0, 0.0, 1.47), root)
    local_sphere("ChestCore", (0.0, 0.01, 0.0), (0.43, 0.255, 0.50), ivory, torso, 28, 16)
    local_cube("BlueChestLeft", (-0.205, -0.235, 0.01), (0.24, 0.070, 0.63), royal_blue, torso, bevel=0.040)
    local_cube("IvoryChestCentre", (0.0, -0.255, 0.01), (0.24, 0.045, 0.62), ivory, torso, bevel=0.026)
    local_cube("BlueChestRight", (0.205, -0.235, 0.01), (0.24, 0.070, 0.63), royal_blue, torso, bevel=0.040)
    local_cube("ChestGoldLeft", (-0.330, -0.280, 0.01), (0.045, 0.023, 0.58), gold, torso, bevel=0.010)
    local_cube("ChestGoldRight", (0.330, -0.280, 0.01), (0.045, 0.023, 0.58), gold, torso, bevel=0.010)
    local_cube("ChestGoldCentre", (0.0, -0.285, 0.01), (0.050, 0.023, 0.57), gold, torso, bevel=0.010)
    local_cube("ChestHarness", (0.02, -0.305, 0.03), (0.12, 0.040, 0.91), leather, torso, rotation=(0.0, 0.0, math.radians(-34.0)), bevel=0.014)
    local_cube("GoldHarnessTrim", (0.02, -0.331, 0.03), (0.035, 0.015, 0.88), gold, torso, rotation=(0.0, 0.0, math.radians(-34.0)), bevel=0.006)
    local_cube("RoyalCollar", (0.0, -0.04, 0.40), (0.56, 0.35, 0.17), dark_steel, torso, bevel=0.055)
    local_cylinder("GoldNecklace", (0.0, -0.225, 0.405), 0.025, 0.46, gold, torso, 20, (0.0, math.radians(90.0), 0.0))

    head = local_empty("Head", (0.0, 0.0, 2.12), root)
    local_sphere("Skull", (0.0, 0.020, 0.02), (0.300, 0.255, 0.350), skin, head, 32, 20)
    local_sphere("Jaw", (0.0, -0.025, -0.165), (0.250, 0.235, 0.205), skin, head, 28, 16)
    local_sphere("Cheek_L", (-0.178, -0.210, -0.045), (0.108, 0.055, 0.108), skin_light, head, 20, 12)
    local_sphere("Cheek_R", (0.178, -0.210, -0.045), (0.108, 0.055, 0.108), skin_light, head, 20, 12)
    local_sphere("Ear_L", (-0.300, 0.0, 0.015), (0.055, 0.035, 0.092), skin_shadow, head, 18, 10)
    local_sphere("Ear_R", (0.300, 0.0, 0.015), (0.055, 0.035, 0.092), skin_shadow, head, 18, 10)
    local_cone("Nose", (0.0, -0.318, -0.010), 0.076, 0.035, 0.22, skin_shadow, head, 18, (math.radians(90.0), 0.0, 0.0))
    local_eye("Eye_L", -0.108, -0.264, 0.085, head, iris, 1.06)
    local_eye("Eye_R", 0.108, -0.264, 0.085, head, iris, 1.06)
    local_cube("Eyebrow_L", (-0.108, -0.298, 0.158), (0.155, 0.021, 0.030), brows, head, rotation=(0.05, 0.0, -0.055), bevel=0.009)
    local_cube("Eyebrow_R", (0.108, -0.298, 0.158), (0.155, 0.021, 0.030), brows, head, rotation=(0.05, 0.0, 0.055), bevel=0.009)
    local_cube("Mouth", (0.0, -0.302, -0.118), (0.170, 0.018, 0.028), lips, head, bevel=0.009)
    local_sphere("ShavedScalp", (0.0, 0.025, 0.225), (0.278, 0.235, 0.105), skin_shadow, head, 28, 16)

    parts = {}
    for side_name, sign in (("L", -1.0), ("R", 1.0)):
        arm = local_empty(f"Arm_{side_name}", (sign * 0.50, 0.0, 1.72), root)
        local_sphere(f"ShoulderCore_{side_name}", (0.0, 0.0, 0.0), (0.205, 0.195, 0.190), royal_blue, arm, 22, 13)
        local_cube(f"ShoulderPlate_{side_name}", (sign * 0.035, -0.06, 0.01), (0.34, 0.30, 0.20), royal_blue, arm, rotation=(0.0, 0.0, sign * math.radians(7.0)), bevel=0.060)
        local_cube(f"ShoulderGoldTop_{side_name}", (sign * 0.035, -0.225, 0.04), (0.30, 0.045, 0.060), gold, arm, rotation=(0.0, 0.0, sign * math.radians(7.0)), bevel=0.018)
        local_cylinder(f"UpperArm_{side_name}", (0.0, 0.0, -0.28), 0.132, 0.48, cloak_blue, arm, 18)
        local_cube(f"ForearmGuard_{side_name}", (0.0, -0.02, -0.58), (0.235, 0.22, 0.40), dark_steel, arm, bevel=0.055)
        local_cube(f"ForearmGold_{side_name}", (0.0, -0.138, -0.58), (0.205, 0.025, 0.045), gold, arm, bevel=0.010)
        local_sphere(f"Hand_{side_name}", (0.0, -0.02, -0.83), (0.110, 0.088, 0.125), skin, arm, 18, 10)

        leg = local_empty(f"Leg_{side_name}", (sign * 0.205, 0.0, 0.94), root)
        local_cylinder(f"Thigh_{side_name}", (0.0, 0.0, -0.27), 0.150, 0.50, ivory, leg, 18)
        local_cube(f"KneePlate_{side_name}", (0.0, -0.13, -0.52), (0.29, 0.13, 0.25), royal_blue, leg, bevel=0.060)
        local_cube(f"KneeGold_{side_name}", (0.0, -0.205, -0.52), (0.24, 0.025, 0.045), gold, leg, bevel=0.010)
        local_cylinder(f"Shin_{side_name}", (0.0, 0.0, -0.72), 0.132, 0.39, dark_steel, leg, 18)
        local_cube(f"ShinBlue_{side_name}", (0.0, -0.12, -0.72), (0.22, 0.055, 0.36), royal_blue, leg, bevel=0.045)
        local_cube(f"Boot_{side_name}", (0.0, -0.085, -0.93), (0.30, 0.47, 0.19), leather, leg, bevel=0.065)
        local_cube(f"BootGold_{side_name}", (0.0, -0.325, -0.91), (0.25, 0.030, 0.050), gold, leg, bevel=0.010)
        parts[f"arm_{side_name.lower()}"] = arm
        parts[f"leg_{side_name.lower()}"] = leg

    build_sword(parts["arm_r"], steel, leather, gold)

    cape = local_empty("Cape", (0.0, 0.25, 1.78), root)
    local_cube("CapeShoulders", (0.0, 0.02, 0.0), (1.02, 0.085, 0.22), cloak_blue, cape, bevel=0.055)
    local_cube("CapeUpper", (0.0, 0.055, -0.36), (0.88, 0.070, 0.70), cloak_blue, cape, rotation=(math.radians(8.0), 0.0, 0.0), bevel=0.050)
    local_cube("CapeLower", (0.0, 0.10, -0.91), (0.75, 0.060, 0.70), cloak_blue, cape, rotation=(math.radians(14.0), 0.0, 0.0), bevel=0.048)
    local_cube("CapeGoldLeft", (-0.355, 0.035, -0.59), (0.035, 0.025, 1.05), gold, cape, rotation=(math.radians(10.0), 0.0, 0.0), bevel=0.006)
    local_cube("CapeGoldRight", (0.355, 0.035, -0.59), (0.035, 0.025, 1.05), gold, cape, rotation=(math.radians(10.0), 0.0, 0.0), bevel=0.006)
    local_cube("CapeGoldBottom", (0.0, 0.095, -1.25), (0.70, 0.025, 0.045), gold, cape, rotation=(math.radians(14.0), 0.0, 0.0), bevel=0.008)

    return root


def main() -> None:
    args = base.parse_args()
    base.OUTPUT_DIR = Path(args.output)
    base.build_hero = build_hero_v3
    base.generate_all()


if __name__ == "__main__":
    main()
