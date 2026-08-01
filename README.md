# Les Chroniques de Skypiea — CHK Hero

Jeu d’aventure et d’action 3D en monde ouvert, sous Godot 4.7.1, intégralement en français et conçu pour Android. Cette version 0.5.0 prolonge le projet existant : elle conserve son contrôleur, son combat, sa carte, ses ennemis, ses musiques et sa chaîne de génération Blender, puis leur ajoute un monde beaucoup plus vaste et vivant.

## CHK Hero

- Cheikh devient le chevalier jouable `CHKHeroRoyalKnight` : peau caramel, crâne rasé, cape bleue, tunique blanche et bleue, tabard vert, armure dorée et épée.
- Le modèle GLB possède de vrais pivots `Arm_L`, `Arm_R`, `Leg_L`, `Leg_R`, `Head`, `Cape` et `Weapon`.
- Marche, course, saut, attaque, esquive, impact et mort sont animés en temps réel.
- Le portrait personnalisé est affiché dans l’accueil et le HUD avec le statut **CHK HERO**.

## Monde ouvert déterministe

Les dix régions ont chacune une surface de 152 × 136 unités, soit **10,70 fois** la surface historique de 46 × 42. Leur relief, leurs routes, leurs ponts, leurs bâtiments, leurs ressources et leurs points d’intérêt sont définis explicitement dans le code ; aucun remplissage aléatoire n’est effectué au lancement.

1. Village côtier : village, marché, phare, plage, quais, pontons et bateaux.
2. Grande forêt : forêt dense, clairières, cours d’eau, cascade et ruines.
3. Montagnes rocheuses : pics, falaises, chemin vertical, mine et cascade.
4. Plaines agricoles : huit champs distincts, fermes, route et canal.
5. Région volcanique : cône, cratère, lave, obsidienne et sanctuaire.
6. Marais brumeux : bassins, arbres sombres, lueurs et ressources médicinales.
7. Désert de cendres : canyon, rochers, colosse et caravane ensevelie.
8. Grand port commercial : entrepôts, quais, marché, navires et capitainerie.
9. Ruines antiques : pyramides, colonnes, temple, mécanismes et trésors.
10. Montagnes enneigées : sommets, glace, cristaux, balises et cloche du sommet.

Le streaming conserve la région courante et ses voisines, puis réduit davantage la charge avec le profil graphique faible.

## Systèmes jouables

- 200 profils de PNJ, soit 20 par région, avec nom, métier, personnalité, maison, travail, lieu de repos et routine horaire.
- 20 PNJ actifs dans la région visitée ; les autres restent représentés par leurs profils légers.
- Dialogues contextuels en français selon la région, l’heure, la météo, les objets, les quêtes et la réputation.
- Achat de rations, vente de trésors, fuite face au danger et retour à la routine.
- Faune terrestre, aérienne et marine : fuite, prédateurs, cycles nocturnes, collisions et habitats régionaux.
- Cycle jour/nuit, lever et coucher du soleil, météo régionale, brouillard, pluie, neige, blizzard et cendres.
- Lanternes automatiques la nuit dans les villages, les routes et les ports.
- Océan animé par shader, nage, plongée, brouillard sous-marin et cinq niveaux de profondeur jusqu’aux abysses.
- Fonds marins, récifs, ruines, passage abyssal et cinq coffres sous-marins persistants.
- Deux bateaux pilotables avec collisions et sillage, plus quatre navires marchands sur des routes fixes.
- Dix quêtes régionales, trente ressources terrestres, inventaire, récompenses, pièces et réputation.
- Carte complète, mini-carte en direct et étoiles de lieux visibles uniquement après leur découverte.
- Tutoriel français en treize étapes, inventaire, journal, écran d’accueil et menu pause.
- Sauvegarde automatique toutes les 45 secondes, sauvegarde manuelle, écriture temporaire et copie de secours anti-corruption.
- Bouton de déblocage de CHK Hero en cas de collision ou de chute anormale.
- Profils graphiques faible, moyen et élevé avec cibles de 30 ou 60 images par seconde.

## Commandes

Sur Android, le joystick fixe déplace CHK Hero et le glissement à droite contrôle la caméra. Les boutons permettent de sauter, attaquer, esquiver, agir et plonger. `ACTION` parle aux PNJ, ramasse les objets, ouvre les coffres et permet de monter ou descendre d’un bateau.

Au clavier : `ZQSD`/`WASD`, flèches, espace, `F`, Maj, Ctrl et `E`.

## Génération des assets

Le workflow Android utilise Blender pour produire douze modèles GLB optimisés : CHK Hero, sept familles d’ennemis, arbre, maison, ruine et bateau.

```bash
blender --background --python tools/blender/generate_game_assets_v2.py -- --output generated_models
```

Les quinze ambiances OGG sont déjà intégrées. Elles peuvent être régénérées de manière reproductible :

```bash
tools/audio/generate_ambiences.sh assets/audio/generated
```

## Validation

La CI vérifie réellement :

- l’import et l’exécution sans erreur de script ;
- les dix régions et leur rapport de surface de 10,70 ;
- les 200 profils de PNJ et les 20 habitants actifs ;
- la faune, les ambiances, les quêtes, les objets et les bateaux ;
- l’embarquement, le débarquement, la nage et la plongée ;
- les trois profils graphiques et la pause réelle ;
- le changement rapide de région ;
- la sauvegarde et la restauration depuis une copie corrompue ;
- une vraie pression tactile, le déplacement continu et l’animation des membres ;
- une capture de l’interface chargée ;
- la présence des scripts, sons, textures et GLB dans l’APK.

Test principal local :

```bash
godot --headless --path . --editor --import
godot --headless --path . -- --ci-open-world-check
```

Le workflow publie `ZeldaLike-CHK-Hero-OpenWorld-V5-debug.apk` avec sa somme SHA-256 dans les artifacts GitHub Actions.
