# Correctif d'installation Android v2

Les anciens APK GitHub Actions utilisaient le même identifiant Android `com.chasmet.zeldalike` et le même code de version, tout en pouvant être signés avec une clé de débogage différente selon le runner. Android refuse alors l'installation par-dessus une version déjà présente.

Ce correctif utilise un nouvel identifiant de paquet et un code de version supérieur afin de permettre une installation propre et indépendante.
