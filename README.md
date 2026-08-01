# Les Chroniques de Skypiea — Zelda-like RPG 3D

RPG d’action 3D sous Godot 4.7, conçu pour Android et construit autour des planches de personnages, ennemis, carte, textures et musiques présentes dans ce dépôt.

## Refonte 3D

Le jeu n’utilise plus les PNG comme simples panneaux face caméra lorsque les modèles générés sont disponibles. Le workflow Android lance Blender, crée des GLB optimisés puis Godot les importe dans le jeu.

Modèles produits automatiquement :

- héros chevalier bleu, blanc, vert et or d’après les vues de référence ;
- sanglier cuirassé, golem de cristal, molosse de lave, chevalier Anubis, gobelin à deux lames, ogre de glace et chef orc ;
- arbre, maison de village, porte en ruine et bateau.

Les pivots nommés des modèles sont animés en temps réel : respiration, marche, course, saut, attaque, esquive, impact et mort. Les images originales restent les solutions de secours si un GLB n’a pas encore été généré.

## Gameplay

- déplacement troisième personne et caméra 360° ;
- commandes tactiles Android et clavier/souris ;
- attaque, esquive, saut, dégâts, recul et réapparition ;
- quatorze ennemis issus de sept familles ;
- village, forêt, ruines, océan et bateau 3D ;
- musique d’exploration et musique de combat ;
- interface, carte et objectif de victoire.

## Générer les modèles avec Blender

```bash
blender --background --python tools/blender/generate_game_assets.py -- --output generated_models
```

Blender est uniquement nécessaire pour fabriquer les GLB. Il n’est pas embarqué dans l’APK.

## Compilation Android

Le workflow `.github/workflows/build-android.yml` :

1. installe Blender ;
2. génère et vérifie les douze modèles GLB ;
3. exporte le projet avec Godot 4.7.1 ;
4. vérifie qu’un véritable APK existe ;
5. publie l’APK et les modèles dans les Artifacts GitHub Actions.

L’APK attendu est `build/ZeldaLike-debug.apk`.
