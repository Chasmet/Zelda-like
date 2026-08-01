"""Second-generation Blender build for the Zelda-like project.

The original open-source Blender pipeline is reused for enemies and world props.
Only the playable hero builder is replaced by a more detailed Cheikh-inspired
model: shaved head, oval face, caramel skin, short beard, brown eyes, eyebrow
scar, blue/gold knight armour, green tabard and blue cape.
"""

from __future__ import annotations

import importlib.util
import math
from pathlib import Path

SCRIPT_PATH = Path(__file__).with_name("generate_game_assets.py")
spec = importlib.util.spec_from_file_location("base_asset_generator", SCRIPT_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load {SCRIPT_PATH}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def build_hero_v2():
    base.reset_scene()
    root = base.empty("HeroKnight", (0.0, 0.0, 0.0))

    skin = base.material("CheikhSkin", (0.46, 0.275, 0.16, 1.0), roughness=0.67)
    skin_shadow = base.material("CheikhSkinShadow", (0.30, 0.16, 0.085, 1.0), roughness=0.74)
    beard = base.material("CheikhBeard", (0.030, 0.022, 0.018, 1.0), roughness=0.94)
    brows = base.material("CheikhBrows", (0.022, 0.016, 0.013, 1.0), roughness=0.92)
    lips = base.material("CheikhLips", (0.30, 0.105, 0.075, 1.0), roughness=0.72)
    iris = base.material("CheikhLightBrownEyes", (0.28, 0.12, 0.035, 1.0), roughness=0.24)
    scar = base.material("CheikhScar", (0.60, 0.34, 0.20, 1.0), roughness=0.70)

    royal_blue = base.material("RoyalBlueArmour", (0.018, 0.10, 0.31, 1.0), metallic=0.30, roughness=0.42)
    blue_cloth = base.material("DeepBlueCloth", (0.022, 0.15, 0.40, 1.0), roughness=0.76)
    white_cloth = base.material("IvoryCloth", (0.78, 0.76, 0.68, 1.0), roughness=0.82)
    green = base.material("EmeraldTabard", (0.035, 0.22, 0.13, 1.0), roughness=0.84)
    leather = base.material("DarkLeather", (0.115, 0.045, 0.020, 1.0), roughness=0.86)
    steel = base.material("PolishedSteel", (0.48, 0.56, 0.64, 1.0), metallic=0.78, roughness=0.24)
    dark_steel = base.material("DarkSteel", (0.12, 0.15, 0.19, 1.0), metallic=0.72, roughness=0.32)
    gold = base.material("RoyalGold", (0.78, 0.48, 0.075, 1.0), metallic=0.66, roughness=0.26)

    hips = base.empty("Hips", (0.0, 0.0, 0.86), root)
    base.cube("PelvisArmour", (0.0, 0.0, 0.89), (0.56, 0.35, 0.28), leather, hips, bevel=0.075)
    base.cube("Belt", (0.0, -0.01, 1.02), (0.70, 0.40, 0.13), leather, hips, bevel=0.030)
    base.cube("BeltBuckle", (0.0, -0.228, 1.02), (0.17, 0.055, 0.16), gold, hips, bevel=0.022)

    torso = base.empty("Torso", (0.0, 0.0, 1.31), root)
    base.sphere("ChestCore", (0.0, 0.015, 1.39), (0.40, 0.245, 0.48), white_cloth, torso, 24, 14)
    base.cube("Breastplate", (0.0, -0.205, 1.43), (0.70, 0.09, 0.61), royal_blue, torso, bevel=0.075)
    base.cube("ChestIvory", (0.0, -0.260, 1.40), (0.28, 0.035, 0.50), white_cloth, torso, bevel=0.028)
    base.cube("ChestGoldVertical", (0.0, -0.286, 1.43), (0.055, 0.025, 0.53), gold, torso, bevel=0.012)
    base.cube("ChestGoldHorizontal", (0.0, -0.287, 1.60), (0.56, 0.025, 0.055), gold, torso, bevel=0.012)
    base.cube("Collar", (0.0, -0.07, 1.74), (0.52, 0.34, 0.17), dark_steel, torso, bevel=0.055)
    base.cube("Harness", (0.0, -0.292, 1.42), (0.105, 0.040, 0.80), leather, torso, rotation=(0.0, 0.0, -0.56), bevel=0.015)

    for x, side_name in ((-0.19, "L"), (0.19, "R")):
        tabard = base.empty(f"Tabard_{side_name}", (x, 0.0, 0.80), hips)
        base.cube(f"TabardCloth_{side_name}", (x, -0.015, 0.66), (0.30, 0.27, 0.73), green, tabard, rotation=(0.0, 0.0, 0.06 if x > 0 else -0.06), bevel=0.032)
        base.cube(f"TabardGold_{side_name}", (x, -0.170, 0.66), (0.035, 0.020, 0.63), gold, tabard, bevel=0.007)

    head = base.empty("Head", (0.0, 0.0, 1.98), root)
    base.sphere("Skull", (0.0, 0.015, 1.99), (0.292, 0.255, 0.345), skin, head, 28, 18)
    base.sphere("Jaw", (0.0, -0.030, 1.82), (0.245, 0.235, 0.205), skin, head, 24, 14)
    base.sphere("Cheek_L", (-0.175, -0.205, 1.91), (0.105, 0.055, 0.105), skin, head, 18, 10)
    base.sphere("Cheek_R", (0.175, -0.205, 1.91), (0.105, 0.055, 0.105), skin, head, 18, 10)
    base.sphere("Ear_L", (-0.292, 0.0, 1.98), (0.055, 0.035, 0.090), skin_shadow, head, 16, 9)
    base.sphere("Ear_R", (0.292, 0.0, 1.98), (0.055, 0.035, 0.090), skin_shadow, head, 16, 9)
    base.cone("Nose", (0.0, -0.315, 1.95), 0.075, 0.035, 0.22, skin_shadow, head, 16, (math.radians(90), 0.0, 0.0))
    base.eye("Eye_L", -0.105, -0.258, 2.045, head, iris, 1.05)
    base.eye("Eye_R", 0.105, -0.258, 2.045, head, iris, 1.05)
    base.cube("Eyebrow_L", (-0.105, -0.295, 2.115), (0.155, 0.022, 0.030), brows, head, rotation=(0.05, 0.0, -0.06), bevel=0.010)
    base.cube("Eyebrow_R", (0.105, -0.295, 2.115), (0.155, 0.022, 0.030), brows, head, rotation=(0.05, 0.0, 0.06), bevel=0.010)
    base.cube("LeftEyebrowScar", (-0.145, -0.317, 2.115), (0.026, 0.010, 0.105), scar, head, rotation=(0.0, 0.0, -0.38), bevel=0.004)
    base.cube("Mouth", (0.0, -0.295, 1.825), (0.165, 0.018, 0.028), lips, head, bevel=0.009)
    base.sphere("ScalpShadow", (0.0, 0.020, 2.190), (0.268, 0.232, 0.105), skin_shadow, head, 24, 14)
    base.sphere("BeardChin", (0.0, -0.232, 1.765), (0.205, 0.045, 0.120), beard, head, 22, 12)
    base.cube("BeardJaw_L", (-0.165, -0.225, 1.820), (0.105, 0.035, 0.190), beard, head, rotation=(0.0, 0.0, -0.20), bevel=0.040)
    base.cube("BeardJaw_R", (0.165, -0.225, 1.820), (0.105, 0.035, 0.190), beard, head, rotation=(0.0, 0.0, 0.20), bevel=0.040)
    base.cube("Mustache", (0.0, -0.308, 1.865), (0.195, 0.020, 0.034), beard, head, bevel=0.012)

    parts = {}
    for side_name, sign in (("L", -1.0), ("R", 1.0)):
        arm = base.empty(f"Arm_{side_name}", (sign * 0.45, 0.0, 1.57), root)
        base.sphere(f"Shoulder_{side_name}", (sign * 0.45, 0.0, 1.57), (0.205, 0.195, 0.185), royal_blue, arm, 18, 11)
        base.cylinder(f"UpperArm_{side_name}", (sign * 0.45, 0.0, 1.30), 0.125, 0.48, blue_cloth, arm, 16)
        base.cylinder(f"Forearm_{side_name}", (sign * 0.45, 0.0, 1.02), 0.105, 0.40, dark_steel, arm, 16)
        base.sphere(f"Hand_{side_name}", (sign * 0.45, -0.01, 0.80), (0.105, 0.085, 0.12), skin, arm, 16, 9)
        base.cube(f"ShoulderGold_{side_name}", (sign * 0.45, -0.155, 1.57), (0.29, 0.055, 0.105), gold, arm, bevel=0.025)
        leg = base.empty(f"Leg_{side_name}", (sign * 0.19, 0.0, 0.88), root)
        base.cylinder(f"Thigh_{side_name}", (sign * 0.19, 0.0, 0.64), 0.145, 0.47, white_cloth, leg, 16)
        base.cube(f"Knee_{side_name}", (sign * 0.19, -0.125, 0.43), (0.27, 0.115, 0.24), royal_blue, leg, bevel=0.055)
        base.cylinder(f"Shin_{side_name}", (sign * 0.19, 0.0, 0.25), 0.125, 0.38, dark_steel, leg, 16)
        base.cube(f"Boot_{side_name}", (sign * 0.19, -0.070, 0.075), (0.28, 0.44, 0.18), leather, leg, bevel=0.060)
        parts[f"arm_{side_name.lower()}"] = arm
        parts[f"leg_{side_name.lower()}"] = leg

    base.sword(parts["arm_r"], 0.45, 1.0, steel, leather, gold)
    cape = base.empty("Cape", (0.0, 0.25, 1.60), root)
    base.cube("CapeUpper", (0.0, 0.31, 1.35), (0.76, 0.065, 0.62), blue_cloth, cape, rotation=(0.08, 0.0, 0.0), bevel=0.040)
    base.cube("CapeLower", (0.0, 0.34, 0.87), (0.68, 0.055, 0.65), blue_cloth, cape, rotation=(0.16, 0.0, 0.0), bevel=0.040)
    base.cube("CapeGoldTrim", (0.0, 0.315, 0.56), (0.66, 0.025, 0.045), gold, cape, bevel=0.010)
    return root


def main() -> None:
    args = base.parse_args()
    base.OUTPUT_DIR = Path(args.output)
    base.build_hero = build_hero_v2
    base.generate_all()


if __name__ == "__main__":
    main()
