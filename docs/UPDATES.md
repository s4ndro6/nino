# Mises à jour de Nino

Depuis 0.20, Nino peut afficher une nouvelle version dans l’encoche. Le bouton n’interrompt pas les enregistrements : il ouvre les détails dans les réglages. L’appel et le minuteur conservent la priorité dans l’encoche.

- Active **Me prévenir quand Nino évolue** pendant l’accueil, ou **Réglages → Mises à jour → Me prévenir des nouvelles versions**.
- Nino consulte le dépôt public `s4ndro6/nino` au maximum une fois par jour automatiquement, alphas comprises. La vérification manuelle reste disponible dans le menu Nino et les réglages.
- GitHub reçoit l’adresse IP et une requête standard ; aucun compte, jeton, document, chemin local, audio ou conversation n’est transmis.
- **Télécharger** ouvre le DMG de la version précise sur GitHub. **Plus tard** masque l’alerte pendant 24 h. **Ignorer** masque cette version uniquement. Les détails restent accessibles dans les réglages.
- L’offre détectée est conservée localement et revalidée au redémarrage. Une erreur réseau ne signifie jamais que l’app est à jour.

## Installer une version

Termine tes travaux et enregistrements, quitte Nino, ouvre le DMG et remplace l’application dans Applications. Tes notes restent dans leur dossier de bibliothèque, hors du bundle. Aucune suppression des données n’est effectuée par ce mécanisme.

Cette alpha est signée ad hoc et n’est pas notariée par Apple. **Il n’y a pas de remplacement ou de redémarrage automatique**. Les versions antérieures à 0.20 doivent être mises à niveau manuellement une première fois pour bénéficier des alertes suivantes.

## Publier une nouvelle version

1. Incrémenter `CFBundleShortVersionString` et `CFBundleVersion` dans `Source/Info.plist` et écrire les notes.
2. Exécuter `bash test.sh`, puis `NINO_PUBLIC_BUILD=1 zsh Source/build.sh` (configurer `NINO_BUILD_ROOT` vers un disque de compilation).
3. Exécuter `bash scripts/package-release.sh /chemin/vers/les/livrables`.
4. Publier une release GitHub non brouillon, tag `vX.Y.Z`, contenant exactement `Nino-X.Y.Z-macOS-arm64.dmg` et `SHA256SUMS.txt`. Les préreleases publiques sont acceptées, conformément au statut alpha.
5. Mettre à jour le bouton de téléchargement et les limites présentées sur le site. Le checker lit GitHub, pas Vercel ; Vercel héberge uniquement la page de présentation.

Le parseur refuse les versions malformées, les rétrogradations, les brouillons, les autres dépôts, les liens HTTP, les redirections de l’API et les assets inattendus. Il limite la réponse à 1 Mio et le DMG annoncé à 200 Mo. Les notes sont affichées en texte, sans HTML exécutable.
