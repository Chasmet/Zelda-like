# Les Chroniques de Skypiea — Zelda-like RPG 3D

Base jouable d’un RPG d’action 3D sous Godot 4.7, pensée pour Android et créée autour des assets présents dans ce dépôt.

## Gameplay inclus

- déplacement libre en troisième personne et caméra 360° ;
- commandes tactiles Android et commandes clavier/souris ;
- attaque à l’épée, esquive, saut, dégâts, recul et réapparition ;
- huit ennemis avec variantes, poursuite, attaque et barre de vie ;
- quête complète : vaincre cinq créatures, récupérer la relique puis ouvrir le portail ;
- village, ancien, feu de repos, ruines, forêt, océan et objets de décor ;
- cycle jour/nuit, brouillard et pluie dynamique ;
- sauvegarde automatique de la position, de la vie et de la progression ;
- détection automatique des images, modèles 3D et sons déjà déposés dans le projet.

## Assets reconnus automatiquement

Le jeu parcourt les dossiers du dépôt au démarrage. Il reconnaît :

- images : PNG, JPG, JPEG, WEBP et SVG ;
- modèles/scènes : GLB, GLTF, FBX, OBJ, DAE, TSCN et SCN ;
- audio : OGG, WAV et MP3.

Les noms contenant `cheikh`, `yvane`, `nelvin`, `hero`, `player`, `chevalier` ou `knight` sont prioritaires pour le héros. Les noms contenant `enemy`, `ennemi`, `monster`, `monstre`, `goblin`, `tortue`, `lievre`, `wolf` ou `bandit` sont prioritaires pour les ennemis.

## Contrôles

### Android

- joystick gauche : déplacement ;
- glisser sur la partie droite : caméra ;
- boutons : attaque, esquive, saut et action.

### PC

- ZQSD/WASD ou flèches : déplacement ;
- souris : caméra ;
- clic gauche ou F : attaque ;
- Maj : esquive ;
- E : action ;
- Espace : saut ;
- Ctrl : sprint.

## Compilation Android automatique

Le workflow `.github/workflows/build-android.yml` compile l’APK avec Godot 4.7.1 et le publie dans l’onglet **Actions > Artifacts** sous le nom `ZeldaLike-Android-debug`.

Lancement manuel : ouvrir `project.godot` avec Godot 4.7.1, laisser les assets s’importer, puis lancer la scène principale.
