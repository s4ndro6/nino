# Installation intégrée (0.21)

La 0.20.1 publique ouvre le téléchargement du DMG. Elle ne sait pas encore se remplacer. Réinstaller cette même version ne change pas ce comportement.

La prochaine version intègre Sparkle 2.10.1 pour télécharger, vérifier la signature EdDSA, remplacer l’application et proposer son redémarrage. La vérification quotidienne GitHub reste facultative. Sparkle ne lance ni téléchargement ni installation en arrière-plan. Aucun profil système n’est envoyé.

## État de préparation

- Code intégré ; clé de publication dédiée créée dans le Trousseau du mainteneur après autorisation. Seule sa clé publique est dans le dépôt.
- Sans clé publique valide, le bouton d’installation intégrée est absent et la raison est affichée.
- Le conditionnement public refuse de produire un DMG sans configuration de signature.
- La signature EdDSA est distincte de la notarisation Apple. Nino reste gratuit et non notarié ; une autorisation macOS peut encore être nécessaire.
- Le parcours réel téléchargement → vérification → remplacement → relance doit être validé avant publication.

## Publication par le mainteneur

Après autorisation explicite de créer la clé privée dans son Trousseau :

1. Utiliser `generate_keys --account nino-s4ndro6-updates` de la distribution officielle Sparkle 2.10.1. Ne jamais exporter la clé privée dans le dépôt ou les logs.
2. Copier uniquement la clé publique affichée dans `SUPublicEDKey` de `Source/Info.plist`. La clé publique n’est pas un secret et doit accompagner les builds GitHub. L’override local `Configuration/UpdatePublicKey.txt` est réservé aux essais du mainteneur.
3. Incrémenter `CFBundleVersion` à chaque livraison et `CFBundleShortVersionString` pour le nom public ; compiler avec `NINO_PUBLIC_BUILD=1` puis utiliser `scripts/package-release.sh`.
4. Exécuter `scripts/generate-update-feed.sh CHEMIN_SPARKLE DOSSIER_DMG VERSION`. Le script signe l’archive via le Trousseau et génère l’appcast, sans exporter la clé.
5. Publier le DMG et son SHA256 sur la release personnelle `s4ndro6/nino`, puis l’appcast généré sur `https://nino-companion.vercel.app/appcast.xml`. Ne jamais changer un DMG après signature.
6. Tester depuis une version antérieure réellement installée, avec un post-it et un document témoins. Vérifier annulation, serveur inaccessible, signature invalide et refus du redémarrage pendant un travail. Le build seul n’est pas une preuve d’installation.

Les anciennes versions demandent une dernière installation manuelle pour recevoir ce moteur. Les versions ultérieures l’utilisent depuis Nino.

## Protection du travail et éditions personnelles

Le démarrage de l’installation et la relance vérifient capture, démarrage/arrêt audio, import, transcription, génération, livraison, connexion Google et sauvegardes. La fermeture Cocoa conserve le flush des post-it et la révocation MCP avec délai maximal. Aucun `kill`, désactivation de Gatekeeper ou suppression de quarantaine.

L’appcast public est réservé à `app.sandro.nino`, sans marqueur Découverte/Portable et sans configuration Google embarquée. Découverte utilise un autre domaine de préférences, une bibliothèque X9 et une session Trousseau distincts : elle ne doit jamais être remplacée automatiquement par le DMG public. Une migration explicite doit préserver sa bibliothèque et prévoir une reconnexion Google.

Référence : <https://sparkle-project.org/documentation/>
