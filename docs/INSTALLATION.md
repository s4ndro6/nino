# Installer Nino

## L’application

Télécharger le DMG depuis les releases du dépôt personnel `s4ndro6/nino`, glisser **Nino.app → Applications**, éjecter le DMG, puis ouvrir Nino depuis Applications. Le déplacement doit précéder les connexions MCP, qui utilisent le chemin absolu du helper inclus.

Le téléchargement vise les Mac Apple Silicon (M1 ou plus récent), macOS 15+. L’assistant Apple Intelligence demande macOS 26+ et un modèle Apple disponible sur ce Mac. Aucun binaire Intel n’est livré.

L’alpha est signée ad hoc, pas avec un certificat Developer ID, et n’est pas notariée. Consulter la [procédure Apple](https://support.apple.com/fr-fr/102445) si macOS bloque le premier lancement. Ne pas désactiver Gatekeeper et ne pas ignorer une alerte de logiciel malveillant. Sans exception proposée par macOS, utiliser les sources ou signaler le problème.

## Problèmes rencontrés sur un autre Mac

- **« Vous n’avez pas l’autorisation » / LIRE-MOI illisible dans les versions 0.18–0.20.0** : un défaut de fabrication conservait des droits réservés au compte de compilation. Télécharge la **0.20.1 ou plus récente**, éjecte l’ancien DMG et utilise le nouveau. Remplace uniquement l’application ; ne supprime pas la bibliothèque de données.
- **« Apple n’a pas pu confirmer… »** : cette version n’a pas de certificat Developer ID ni de ticket de notarisation Apple. Réinstaller ne supprime pas cet avertissement. Consulte la procédure Apple ci-dessus pour décider sur ce Mac ; aucune désactivation globale de Gatekeeper n’est nécessaire.
- **Mac Intel** : ce téléchargement ne convient pas. Vérifie le type de puce dans À propos de ce Mac.

Une distribution reconnue par Gatekeeper nécessite un certificat Developer ID Application, une signature avec Hardened Runtime et une notarisation Apple acceptée. Voir [la documentation éditeur Apple](https://developer.apple.com/developer-id/). Cette étape n’est pas encore réalisée pour Nino.

## Autoriser le premier lancement gratuitement

Suis le [guide pas à pas](PREMIER-LANCEMENT.txt) : après la première tentative d’ouverture, **Réglages Système → Confidentialité et sécurité → Sécurité → Ouvrir quand même**, si proposé pour Nino et si tu décides de lui faire confiance. Confirme ensuite **Ouvrir**. Aucun paiement ni abonnement n’est demandé pour utiliser l’app.

## Première utilisation

Choisir un profil dans l’accueil ; les connexions sont facultatives. Créer un post-it, écrire une idée et cocher une tâche. `⌃⌥N` affiche l’encoche. Réglages → Personnaliser mon Nino rouvre l’accueil. **Affichage → Neige sur le bureau** active ou désactive la neige, quel que soit le mode de l’encoche.

## Transcription locale

Depuis **0.22.0**, le moteur Whisper est intégré à Nino et macOS prépare l’audio. Pas de Terminal, Homebrew ou FFmpeg à installer.

1. Dans l’accueil, à l’étape **Tes outils**, ou dans **Connexions et préparation**, choisis **Télécharger le modèle** ou **Plus tard**.
2. **Équilibré (148 Mo)** est le point de départ recommandé ; **Léger (78 Mo)** privilégie la vitesse. Les deux sont multilingues, dont le français. Nino télécharge depuis Hugging Face et vérifie le SHA-256 avant activation. Aucun téléchargement de modèle sans clic explicite.
3. Le téléchargement affiche sa progression et peut être annulé. Un échec permet de réessayer. Un modèle existant corrompu est conservé sous un nom `.recovery-…` avant installation d’une copie valide. Les modèles restent dans la bibliothèque lors des mises à jour.
4. Le choix **Plus tard** laisse les notes vocales enregistrables et écoutables. **Dicter** et **Transcrire** proposent la préparation si nécessaire. Les modèles déjà importés restent utilisables.
5. Pour un essai : **Note vocale → autoriser le micro → enregistrer quelques secondes → Arrêter et enregistrer** (ou **Arrêter et transcrire** si prêt). Dans le document, **Écouter** relit l’original, même sans transcription. La barre de lecture permet de se déplacer.

Les fichiers WAV, M4A, MP3, AAC, AIFF, CAF, FLAC et les pistes audio de MP4/MOV utilisent les décodeurs macOS ; pour un codec non reconnu, exporter une piste WAV ou M4A depuis le logiciel de montage. La vidéo seule sans piste audio ne peut pas être transcrite.

Préparer les accès seulement pour les fonctions souhaitées. macOS demande des accords distincts pour le micro, la reconnaissance et l’écran/audio système. Aucun enregistrement n’est lancé pendant le téléchargement du modèle. La transcription finale fonctionne hors ligne après le téléchargement ; l’aide aux appels utilise séparément la reconnaissance locale Apple et Apple Intelligence si disponibles.

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
