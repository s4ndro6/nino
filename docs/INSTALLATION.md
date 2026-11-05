# Installer Nino

## L’application

Télécharger le DMG depuis les releases du dépôt personnel `s4ndro6/nino`, glisser **Nino.app → Applications**, éjecter le DMG, puis ouvrir Nino depuis Applications. Le déplacement doit précéder les connexions MCP, qui utilisent le chemin absolu du helper inclus.

Le téléchargement vise les Mac Apple Silicon (M1 ou plus récent), macOS 15+. L’assistant Apple Intelligence demande macOS 26+ et un modèle Apple disponible sur ce Mac. Aucun binaire Intel n’est livré.

L’alpha est signée ad hoc, pas avec un certificat Developer ID, et n’est pas notariée. Consulter la [procédure Apple](https://support.apple.com/fr-fr/102445) si macOS bloque le premier lancement. Ne pas désactiver Gatekeeper et ne pas ignorer une alerte de logiciel malveillant. Sans exception proposée par macOS, utiliser les sources ou signaler le problème.

## Première utilisation

Choisir un profil dans l’accueil ; les connexions sont facultatives. Créer un post-it, écrire une idée et cocher une tâche. `⌃⌥N` affiche l’encoche. Réglages → Personnaliser mon Nino rouvre l’accueil.

## Transcription locale

Cette option est séparée de l’installation de l’application. Les moteurs et les modèles ne sont pas intégrés au DMG.

1. Installer FFmpeg et whisper.cpp via Homebrew si souhaité : `brew install ffmpeg whisper-cpp`.
2. Vérifier que `/opt/homebrew/bin/ffmpeg` et `/opt/homebrew/bin/whisper-cli` existent. Cette alpha utilise ces chemins Apple Silicon.
3. Télécharger un modèle GGML depuis la [documentation officielle whisper.cpp](https://github.com/ggml-org/whisper.cpp/tree/master/models). Le modèle `ggml-small.bin` multilingue est le choix initial ; sa taille est d’environ 466 Mo.
4. Dans Nino → Connexions → Transcription locale → **Choisir un modèle…**, sélectionner le fichier `.bin`.
5. Préparer les accès audio uniquement pour les fonctions souhaitées. macOS demande des accords distincts pour le micro, la reconnaissance et l’écran/audio système.

Importer un petit fichier d’essai avant un premier appel important. Le téléprompteur manuel ne dépend pas de Whisper. La transcription en direct utilise la reconnaissance locale Apple ; la transcription finale utilise Whisper.

## Quotas Codex et Claude

Les outils officiels doivent être installés et connectés au compte de l’utilisateur. Nino peut ouvrir leur parcours de connexion ; il ne reçoit pas leur mot de passe.

Claude nécessite aussi le helper optionnel CodexBar. Depuis un checkout du dépôt :

```sh
zsh install-helper.sh
```

Le script télécharge une version précise de CodexBarCLI depuis son dépôt, contrôle son SHA-256 puis l’installe dans `~/Library/Application Support/Nino/Helpers`. Aucune installation globale. Les modèles et ce helper ne sont pas ajoutés au DMG. Pour une version portable explicitement configurée, `NINO_DATA_DIR` permet d’indiquer son dossier de données au script.

## Mises à jour et sauvegarde

Quitter Nino, remplacer seulement l’application dans Applications, puis relancer. Sauvegarder `~/Library/Application Support/Nino` pour conserver notes, fiches, documents et modèles. Les jetons d’une éventuelle configuration Google restent dans le Trousseau macOS.

Les anciennes builds de découverte/portables conservent leur bibliothèque à côté de l’app grâce au marqueur explicite du bundle. Pas de migration automatique ou suppression de leur bibliothèque. Ne pas déplacer uniquement une ancienne app portable en supposant que ses données la suivront.

## Désinstallation

Quitter Nino et mettre l’application à la Corbeille. La bibliothèque est conservée séparément. La supprimer est une action distincte à décider après sauvegarde. Si l’extension Touch Bar facultative a été installée, suivre son guide pour restaurer la configuration MTMR.
