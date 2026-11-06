# Validation 0.22.0 — 6 novembre 2026

## Vérifié
- Suite `bash test.sh` complète : succès, dont modèles corrompus/tronqués/liens, annulation, conversion AAC vers WAV 16 kHz mono, conservation de l’original, rejet des playlists externes et rechargement du lecteur après finalisation.
- Compilation publique arm64/macOS 15+, signature ad hoc vérifiée. Whisper v1.9.5 compilé statiquement, dépendances système uniquement, sans Homebrew utilisateur.
- Téléchargement réel du modèle tiny depuis la révision épinglée officielle : taille et SHA256 vérifiés. Annulation puis reprise avec conservation du modèle incomplet dans un fichier de récupération.
- Application de test isolée avec une bibliothèque neuve : choix « Plus tard », lecture/pause d’un fichier de parole public sans modèle, téléchargement du modèle léger, puis transcription réelle visible et export disponible.
- Fixture publique JFK de whisper.cpp ; aucun microphone ou son d’appel privé capturé pendant ces tests.
- Audit sécurité : extraction neuve de l’archive source vérifiée, redirections HTTPS uniquement, modèle installé après contrôle intégral, aucune clé privée de publication dans les sources.
- Audit interface : carte de préparation accessible dans l’accueil, les connexions et les réglages ; lecteur explicite, contrôle du téléchargement, absence de téléchargement imposé.

## Limites
- Pas de test physique sur le Mac de la seconde utilisatrice ; il faudra confirmer son parcours après mise à jour.
- Le modèle Whisper sert à la transcription des fichiers. Le direct reste assuré par Speech local Apple : disponibilité des ressources et autorisations à vérifier sur chaque Mac.
- L’app n’est pas notariée Apple ; la procédure par application « Ouvrir quand même » peut rester nécessaire.
- Aucune synthèse vocale ajoutée.
