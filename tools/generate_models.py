from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import trimesh
from trimesh.transformations import translation_matrix, rotation_matrix, concatenate_matrices
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT
OUT = ROOT / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)

img = Image.open(SRC / 'pack player 1 2eme pack.png').convert('RGBA')
face = img.crop((195, 45, 345, 220)).resize((256, 256), Image.Resampling.LANCZOS)
mask = Image.new('L', face.size, 0)
d = ImageDraw.Draw(mask)
d.ellipse((28, 8, 228, 248), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(10))
mask2 = Image.new('L', face.size, 0)
d2 = ImageDraw.Draw(mask2)
d2.ellipse((40, 0, 216, 230), fill=255)
mask2 = mask2.filter(ImageFilter.GaussianBlur(7))
mask = Image.fromarray(np.maximum(np.array(mask), np.array(mask2)).astype(np.uint8))
face.putalpha(mask)
face = ImageEnhance.Sharpness(face).enhance(1.2)
face.save(OUT / 'cheikh_face.png')

def mat(name, color, metallic=0.0, rough=0.7, texture=None, alpha=None, double=False):
    kwargs = dict(name=name, baseColorFactor=np.array(color, dtype=np.float64), metallicFactor=metallic,
                  roughnessFactor=rough, doubleSided=double)
    if texture is not None:
        kwargs['baseColorTexture'] = texture
    if alpha:
        kwargs['alphaMode'] = alpha
    return PBRMaterial(**kwargs)

def color(hexv, a=255):
    hexv = hexv.lstrip('#')
    return [int(hexv[i:i+2], 16)/255 for i in (0,2,4)] + [a/255]

def T(x=0,y=0,z=0): return translation_matrix([x,y,z])
def R(axis, deg): return rotation_matrix(np.deg2rad(deg), axis)
def S(x=1,y=1,z=1):
    m=np.eye(4); m[0,0]=x; m[1,1]=y; m[2,2]=z; return m

def add(scene, mesh, node, transform=None, material=None):
    mesh = mesh.copy()
    if material is not None:
        if hasattr(mesh.visual, 'material'):
            mesh.visual.material = material
        else:
            mesh.visual = trimesh.visual.TextureVisuals(material=material)
    scene.add_geometry(mesh, node_name=node, geom_name=node+'_geom', transform=np.eye(4) if transform is None else transform)

skin = mat('Skin', color('#6f4532'), 0.0, 0.72)
blue = mat('RoyalBlue', color('#1556a8'), 0.25, 0.34)
blue2 = mat('DeepBlue', color('#082a59'), 0.12, 0.48)
gold = mat('GoldTrim', color('#c99531'), 0.75, 0.25)
white = mat('ClothWhite', color('#d8d6cc'), 0.02, 0.72)
green = mat('TunicGreen', color('#245846'), 0.03, 0.76)
brown = mat('Leather', color('#4a2d1e'), 0.05, 0.82)
black = mat('Hair', color('#15110f'), 0.0, 0.92)
steel = mat('Steel', color('#b9c2c8'), 0.88, 0.18)
face_mat = mat('CheikhFace', [1,1,1,1], 0.0, 0.88, texture=face, alpha='BLEND', double=True)

def capsule(radius, height, count=(20,20)):
    return trimesh.creation.capsule(height=height, radius=radius, count=count)
def sphere(rx, ry=None, rz=None, subdivisions=3):
    mesh = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    if ry is None: ry = rx
    if rz is None: rz = rx
    mesh.apply_scale([rx, ry, rz])
    return mesh
def cyl(radius, height, sections=24):
    return trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
def box(ext): return trimesh.creation.box(extents=ext)
def cone(r1, h, sections=24): return trimesh.creation.cone(radius=r1, height=h, sections=sections)

def plane_xy(w,h):
    vertices=np.array([[-w/2,-h/2,0],[w/2,-h/2,0],[w/2,h/2,0],[-w/2,h/2,0]], dtype=float)
    faces=np.array([[0,1,2],[0,2,3]])
    uv=np.array([[0,1],[1,1],[1,0],[0,0]], dtype=float)
    mesh=trimesh.Trimesh(vertices=vertices, faces=faces, process=False)
    mesh.visual=TextureVisuals(uv=uv, image=face, material=face_mat)
    return mesh

scene=trimesh.Scene(base_frame='HeroRoot')
add(scene, sphere(0.34,0.48,0.22,4), 'Torso', T(0,1.18,0), blue)
add(scene, sphere(0.29,0.30,0.20,3), 'Hips', T(0,0.79,0), brown)
add(scene, box([0.38,0.58,0.08]), 'ChestCloth', T(0,1.20,-0.225), white)
add(scene, box([0.07,0.78,0.045]), 'ChestBlueStripe', T(0.04,1.20,-0.276), blue)
for side,x in [('L',-0.43),('R',0.43)]:
    add(scene, sphere(0.22,0.16,0.20,3), f'Shoulder_{side}', T(x,1.45,0), blue)
    add(scene, box([0.28,0.06,0.24]), f'ShoulderGold_{side}', T(x,1.48,-0.03), gold)
add(scene, sphere(0.19,0.235,0.175,4), 'Head', T(0,1.88,0), skin)
add(scene, sphere(0.195,0.08,0.176,3), 'HairCap', T(0,2.08,0.015), black)
add(scene, sphere(0.025,0.045,0.025,2), 'Ear_L', T(-0.205,1.90,0), skin)
add(scene, sphere(0.025,0.045,0.025,2), 'Ear_R', T(0.205,1.90,0), skin)
add(scene, cone(0.035,0.105,16), 'Nose', concatenate_matrices(T(0,1.90,-0.19),R([1,0,0],90)), skin)
add(scene, plane_xy(0.34,0.42), 'FaceDecal', T(0,1.91,-0.181), face_mat)
add(scene, box([0.76,1.34,0.055]), 'Cape', concatenate_matrices(T(0,1.15,0.255),R([1,0,0],-7)), blue)
add(scene, box([0.18,1.16,0.035]), 'CapeFold', concatenate_matrices(T(-0.32,1.12,0.285),R([0,0,1],10)), blue2)
add(scene, box([0.34,0.72,0.055]), 'TunicFront', T(0,0.54,-0.20), green)
add(scene, box([0.05,0.68,0.06]), 'TunicTrim', T(0,0.54,-0.235), gold)
add(scene, cyl(0.33,0.11,32), 'Belt', concatenate_matrices(T(0,0.86,0),R([1,0,0],90)), brown)
add(scene, box([0.14,0.12,0.07]), 'Buckle', T(0,0.86,-0.25), gold)
for side,x in [('L',-0.45),('R',0.45)]:
    arm=capsule(0.11,0.56,(16,16)); arm.apply_translation([0,-0.28,0])
    add(scene, arm, f'Arm_{side}', T(x,1.45,0), blue)
    fore=capsule(0.095,0.45,(16,16)); fore.apply_translation([0,-0.225,0])
    add(scene, fore, f'Forearm_{side}', T(x,0.92,0), brown)
    add(scene, sphere(0.10,0.13,0.10,3), f'Hand_{side}', T(x,0.64,0), skin)
    add(scene, cyl(0.13,0.22,20), f'Bracer_{side}', T(x,0.84,0), gold)
for side,x in [('L',-0.18),('R',0.18)]:
    thigh=capsule(0.14,0.64,(18,18)); thigh.apply_translation([0,-0.32,0])
    add(scene, thigh, f'Leg_{side}', T(x,0.78,0), brown)
    shin=capsule(0.125,0.58,(18,18)); shin.apply_translation([0,-0.29,0])
    add(scene, shin, f'Shin_{side}', T(x,0.18,0), brown)
    add(scene, box([0.27,0.20,0.46]), f'Boot_{side}', T(x,-0.17,-0.09), brown)
    add(scene, sphere(0.15,0.12,0.13,3), f'KneeArmor_{side}', T(x,0.35,-0.10), blue)
add(scene, box([0.055,1.05,0.035]), 'SwordBlade', concatenate_matrices(T(0.63,0.55,-0.08),R([0,0,1],-8)), steel)
add(scene, box([0.30,0.06,0.07]), 'SwordGuard', concatenate_matrices(T(0.58,1.04,-0.08),R([0,0,1],-8)), gold)
add(scene, cyl(0.035,0.28,16), 'SwordGrip', concatenate_matrices(T(0.55,1.18,-0.08),R([0,0,1],-8)), brown)
add(scene, box([0.36,0.045,0.05]), 'ChestGold', T(0,1.49,-0.20), gold)
hero_path=OUT/'hero_cheikh.glb'
hero_path.write_bytes(scene.export(file_type='glb'))

white_horse = mat('HorseWhite', color('#e6e1d5'), 0.0, 0.72)
grey = mat('HorseShadow', color('#a7a49d'), 0.0, 0.82)
scene2=trimesh.Scene(base_frame='HorseRoot')
add(scene2, capsule(0.48,1.52,(24,24)), 'HorseBody', concatenate_matrices(T(0,1.18,0),R([1,0,0],90),S(1.0,1.0,1.0)), white_horse)
add(scene2, capsule(0.26,0.88,(20,20)), 'HorseNeck', concatenate_matrices(T(0,1.56,-0.65),R([1,0,0],-25)), white_horse)
add(scene2, sphere(0.30,0.34,0.42,4), 'HorseHead', T(0,1.96,-1.05), white_horse)
add(scene2, capsule(0.16,0.48,(16,16)), 'HorseMuzzle', concatenate_matrices(T(0,1.83,-1.42),R([1,0,0],90)), grey)
for side,x in [('L',-0.18),('R',0.18)]:
    add(scene2, cone(0.08,0.34,14), f'Ear_{side}', T(x,2.26,-1.04), white_horse)
add(scene2, box([0.12,0.90,0.08]), 'Mane', concatenate_matrices(T(0,1.79,-0.62),R([1,0,0],-25)), grey)
add(scene2, capsule(0.13,0.92,(16,16)), 'Tail', concatenate_matrices(T(0,1.32,0.97),R([1,0,0],35)), grey)
add(scene2, box([0.72,0.24,0.84]), 'Saddle', T(0,1.64,0.05), brown)
add(scene2, box([0.82,0.42,0.10]), 'HorseArmorFront', T(0,1.40,-0.74), blue)
add(scene2, box([0.86,0.38,0.10]), 'HorseArmorSide', T(0,1.34,0.52), blue)
add(scene2, box([0.84,0.05,0.12]), 'HorseGoldTrim', T(0,1.58,-0.73), gold)
for name,x,z in [('FL',-0.30,-0.55),('FR',0.30,-0.55),('BL',-0.30,0.55),('BR',0.30,0.55)]:
    upper=capsule(0.11,0.72,(16,16)); upper.apply_translation([0,-0.36,0])
    add(scene2, upper, f'HorseLeg_{name}', T(x,1.08,z), white_horse)
    lower=capsule(0.085,0.58,(14,14)); lower.apply_translation([0,-0.29,0])
    add(scene2, lower, f'HorseShin_{name}', T(x,0.42,z), grey)
    add(scene2, box([0.22,0.16,0.34]), f'Hoof_{name}', T(x,0.05,z-0.06), brown)
horse_path=OUT/'horse_white.glb'
horse_path.write_bytes(scene2.export(file_type='glb'))

for path in (hero_path, horse_path):
    scene_check=trimesh.load(path, force='scene')
    print(path.name, path.stat().st_size, len(scene_check.geometry))
