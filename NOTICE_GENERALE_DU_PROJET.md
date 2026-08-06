# NOTICE GÉNÉRALE DU PROJET — ZELDA-LIKE

## 1. But du projet
Le projet est un jeu d’aventure et de combat en monde semi-ouvert développé avec Godot et destiné principalement à Android. Le joueur explore un grand supercontinent, traverse plusieurs régions, rencontre des habitants et des animaux, affronte des ennemis et progresse jusqu’à la région finale.

Cette notice est la référence générale du projet. Elle doit permettre de reprendre le travail dans une nouvelle discussion sans perdre les décisions importantes.

## 2. Structure du monde
Le monde est composé de 10 grandes régions principales et d’une 11e région finale. Les régions appartiennent au même supercontinent et doivent être reliées par des routes, des chemins, des cols, des plages et des passages naturels.

Le monde doit contenir beaucoup plus de terre que d’eau :
- océan principalement au pourtour du continent ;
- seulement deux grands cours d’eau intérieurs au maximum ;
- quelques petits ruisseaux, étangs ou marais lorsqu’ils sont utiles ;
- grandes plaines, forêts, montagnes, falaises franchissables et plages.

Chaque région doit être vaste, différente et immédiatement reconnaissable.

## 3. Régions
Les notices détaillées sont rangées dans le dossier `royaumes/` :
1. région volcanique ;
2. grande forêt ;
3. montagnes enneigées ;
4. canyon désertique ;
5. marais et sanctuaire ;
6. ruines sacrées ;
7. côte des pirates ;
8. village et campagne ;
9. capitale royale ;
10. hautes terres automnales ;
11. région finale des souvenirs oubliés.

Les images ajoutées par l’utilisateur dans chaque dossier servent de références visuelles pour reconstruire les décors dans Godot.

## 4. Gameplay principal
Le personnage doit être contrôlé à la troisième personne. La caméra doit permettre de voir le personnage, son visage en tournant autour de lui et la direction de ses déplacements.

Le joueur doit pouvoir :
- marcher ;
- courir ;
- tourner naturellement ;
- explorer librement ;
- combattre ;
- monter vers les hauteurs grâce à des chemins logiques ;
- traverser les plaines, forêts, villages, plages et montagnes ;
- interagir avec les habitants, les objets et les points d’intérêt.

Les commandes tactiles doivent être confortables sur téléphone.

## 5. Personnages et modèles
Les personnages PNG et GLB placés dans le dépôt doivent être utilisés lorsqu’ils correspondent au projet. Leur apparence originale doit être respectée : pas de recoloration, pas de remplacement par un personnage générique et pas de déformation inutile.

Les personnages importants doivent disposer d’animations adaptées : repos, marche, course, attaque, dégâts et défaite lorsque le modèle et le système le permettent.

## 6. Monde vivant
Chaque région peut contenir :
- habitants et personnages non joueurs ;
- soldats, ennemis et boss ;
- animaux terrestres et oiseaux ;
- routes, campements, villages, ruines et zones secrètes ;
- météo, vent, brume, particules et variations de lumière adaptées à la région.

Les animaux et personnages éloignés doivent être simplifiés ou désactivés pour conserver de bonnes performances.

## 7. Règles de level design
Les décors doivent être beaux mais surtout jouables.

Toujours prévoir :
- une route principale identifiable ;
- plusieurs chemins secondaires ;
- de grandes zones où le joueur peut courir et combattre ;
- des passages permettant de franchir les montagnes et falaises ;
- des points de repère visibles ;
- des collisions propres ;
- des zones sans décor trop dense pour la caméra.

Éviter les murs infranchissables sans détour, les labyrinthes illisibles et les étendues d’eau inutiles.

## 8. Direction visuelle
Le style recherché est celui d’un grand jeu d’aventure fantasy : paysages vastes, lumière cinématographique, végétation vivante, ruines, reliefs impressionnants et environnements différents selon les régions.

Les références visuelles ne doivent pas être copiées comme une simple image plate. Elles servent à comprendre :
- les couleurs ;
- les formes du terrain ;
- la densité de végétation ;
- les chemins ;
- les points d’intérêt ;
- l’ambiance générale.

## 9. Contraintes techniques
- moteur : Godot ;
- plateforme prioritaire : Android ;
- contrôles tactiles obligatoires ;
- terrain, végétation, eau, particules et personnages optimisés ;
- utilisation de niveaux de détail, activation par distance et collisions simplifiées ;
- compilation et validation par GitHub Actions lorsqu’un APK est produit.

## 10. Objectif final
Le résultat attendu est un jeu stable, fluide, entièrement jouable, visuellement soigné et facile à continuer. La progression doit mener le joueur à travers toutes les régions jusqu’à la zone finale, où il affronte la dernière épreuve et obtient l’objet rare concluant l’aventure.