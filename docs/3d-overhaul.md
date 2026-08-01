# Pipeline 3D Blender → Godot → Android

## Objectif

Remplacer les personnages plats créés à partir des planches PNG par de vrais volumes 3D mobiles, tout en conservant un rendu fluide sur téléphone.

## Références utilisées

- `pack player 1 2eme pack.png` : silhouette, visage, armure bleue et or, torse blanc, tabard vert et cape ;
- `pack ennemis.png` à `pack ennemis 7.png` : formes, palettes, armes et familles de créatures ;
- les images de carte et de décor restent utilisées dans l’interface et comme références visuelles.

## Modèles générés

| Fichier | Référence visuelle |
|---|---|
| `hero_knight.glb` | héros chevalier |
| `enemy_01_armored_boar.glb` | sanglier cuirassé |
| `enemy_02_crystal_golem.glb` | golem de pierre et cristal |
| `enemy_03_lava_hound.glb` | molosse volcanique |
| `enemy_04_anubis_knight.glb` | guerrier Anubis |
| `enemy_05_goblin_raider.glb` | gobelin à deux lames |
| `enemy_06_ice_ogre.glb` | ogre de glace |
| `enemy_07_orc_warlord.glb` | chef orc à la hache |
| `world_tree.glb` | arbre |
| `village_house.glb` | maison |
| `ruin_gate.glb` | portail en ruine |
| `boat.glb` | bateau |

## Animation

Chaque personnage expose des pivots `Torso`, `Head`, `Arm_L`, `Arm_R`, `Leg_L`, `Leg_R`, `Weapon` et éventuellement `Cape`. `scripts/procedural_animator.gd` applique des animations temps réel sans lourde armature : repos, locomotion, saut, attaque, esquive, coup reçu et mort.

## Limites assumées

Le pipeline reconstruit automatiquement des modèles stylisés à partir de planches 2D. Il est nettement plus fidèle que des sprites verticaux, mais ce n’est pas un scan photoréaliste ni une sculpture humaine 1:1. Les modèles privilégient la lisibilité et les performances Android.
