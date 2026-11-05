# Guide détaillé — historique 0.17.1

Ce document décrit les fonctions de l’alpha précédente. Pour le téléchargement et le stockage de la version publique, le [README actuel](../README.md) et le [guide d’installation](INSTALLATION.md) font référence.

# Nino

Un compagnon macOS dans l’encoche pour garder le fil de son travail.

**0.17.1 · alpha développeur · Apple Silicon.** Source sous licence MIT. Pas encore de binaire notarié. Connexion Google vérifiée sur la configuration locale de l’éditeur ; les sources seules ne contiennent pas sa configuration OAuth.

## Nouveautés 0.17.1

- **Papier coloré** : six couleurs, grain discret, bande adhésive, ombre et coin plié. Texte foncé et checklist ; mêmes données de notes conservées.
- **Accueil en cinq étapes** : présentation avec aperçu Mac, profil, outils facultatifs, choix de confidentialité, première action. Les boutons de navigation restent hors de la zone défilante.
- **Promenade articulée** pendant l’accueil : Nino de trois quarts marche, balance les bras, grimpe, observe, réfléchit et fait signe. Deux parcours alternent autour de la fenêtre et au bas du bureau. Il mime la curiosité : aucune application n’est ouverte ou analysée. La promenade est facultative et s’arrête hors premier plan, en mode discret ou avec Réduire les animations.
- **Statistiques facultatives** : choix explicite, refus sans perte de fonctions, retrait dans Réglages. Compteurs journaliers bornés, aucun contenu personnel. Aucun serveur configuré dans l’application, aucun envoi automatique.
- **Collecteur SQLite local** : code et tests dans [Analytics](../Analytics/README.md), uniquement pour préparer une future infrastructure. Aucun service public ni base de comptes utilisateurs n’est créé.

## Une fiche, un travail

Crée une fiche avec son brief, sa prochaine action, ses étapes et ses liens (ticket, Figma, recette…). Associe un dépôt local et une conversation Codex. Retrouve cette fiche depuis l’encoche ; prépare ton focus ou envoie explicitement son contexte à l’assistant local.

- **Mon Nino** : fiches persistantes, tâches cochables, liens, dépôt et chat associé.
- **Dépôt local** : branche, nombre de fichiers modifiés et identifiant du dernier commit, sur demande. Aucun commit, push ou fetch.
- **Codex / Claude Code** : quotas de l’abonnement via les outils officiels connectés sur ce Mac. Chats Codex enregistrés, consultables en lecture seule. Les dates de relevé restent visibles.
- **Nino MCP** : un vrai serveur stdio natif, qui donne le contexte choisi à un outil IA et reçoit ses signaux d’avancement. Partage désactivé par défaut.
- **Assistant local** : aide à clarifier un brief et préparer la suite avec Apple Intelligence. Ses propositions restent des brouillons ; il n’exécute pas des commandes ou des envois.
- **Audio** : import, transcription locale Whisper, documents éditables et exports ; capture micro/système selon permissions et moteur installé. Ne pas confondre les essais locaux d’import avec une validation de tous les appels Slack/Meet.
- **Encoche et Touch Bar** : raccourcis, minuteur et compagnon animé ; Touch Bar via l’extension MTMR facultative.

## Les outils du quotidien (0.16)

- **Post-it** dans la barre latérale, dans une fiche ou depuis l’encoche : note flottante, couleur, projet, cases à cocher, épinglage et pliage. Recherche, corbeille restaurable, export Markdown. Les notes sont locales, visibles lors d’un partage d’écran et sauvegardées automatiquement. Aucun accès au presse-papiers en arrière-plan.
- **À ton attention**, dans Aujourd’hui : signaux MCP réellement observés pendant cette session de Nino (travail, attente, terminé, erreur), avec acquittement. Le signal courant de chaque agent/session remplace le précédent ; les autres sessions observées restent jusqu’à la fermeture. Ce n’est pas un journal exhaustif ni un observateur universel de tous les chats.
- **Preuves & retours**, dans une fiche : version, timecode en secondes, auteur, source, état et export CSV/Markdown. Utile pour une correction vidéo, un contenu à valider ou une recette. Aucun marqueur injecté dans DaVinci/Premiere.
- **GitHub Actions public**, dans cette même fiche : URL du dépôt puis lecture explicite. Cinq exécutions, SHA, date, lien source, statut exact. Un résultat vert de CI ne prouve pas qu’un déploiement est bon. Aucun compte GitHub, cookie ou token n’est utilisé ; les dépôts privés ne sont pas pris en charge.

## Préparer les accès audio

Ouvre **Connexions → Préparer la voix**. Un seul parcours Nino regroupe les étapes, sans démarrer d’enregistrement. Chaque accès macOS conserve son consentement propre : microphone, reconnaissance vocale, écran/sons du système. Accepter le micro ne permet pas d’accepter les autres automatiquement.

Les accès déjà accordés sont relus dans macOS ; un refus propose les réglages. Les attentes micro/reconnaissance expirent après 30 secondes et peuvent être annulées. Le démarrage est annulable depuis l’encoche ou la barre latérale. L’annulation ne retire pas les autorisations déjà données. Les attentes natives ScreenCaptureKit peuvent encore dépendre du retour de macOS ; l’état reste « démarrage » jusqu’à nettoyage.

Pour une distribution signée, configure `NINO_SIGNING_IDENTITY` avec une identité Developer ID existante et garde le même bundle ID. Sans elle, la compilation reste signée ad hoc et macOS peut redemander les accès après une mise à jour. La notarisation reste une étape de publication distincte.

## Pendant un cours ou un appel

Dans **Appel en direct**, indique le sujet et ton rôle, puis lance l’écoute. **Lire dans l’encoche** ouvre le lecteur :

- **Corriger la question** permet de rectifier ce que Nino a compris, puis de demander une nouvelle réponse.
- **Plus simple** reformule la réponse affichée en conservant le contexte qui l’a produite, même si la conversation a changé de sujet.
- Une nouvelle proposition remplace la précédente seulement quand elle est complète et respecte les limites de longueur. En cas d’échec, l’ancienne réponse et son heure restent visibles.

Les explications utilisent Apple Intelligence localement et restent à vérifier. Nino ne parle pas à ta place. L’enregistrement micro et système requiert les autorisations macOS ; le texte en direct vient du son du Mac.

## Des espaces selon ton métier

Développement, vibe coding, vidéo, design, création de contenu, communication : chaque profil propose des fiches et modèles adaptés. Les fiches sont séparées par profil ; les comptes et documents restent communs. Les fiches antérieures sont conservées dans Général. Les modèles vidéo/image préparent des fichiers, briefs et listes de contrôle : aucun pilotage direct de DaVinci, Premiere ou Adobe n’est promis.

L’accueil propose un compagnon qui se promène autour de sa fenêtre, désactivable et respectueux de Réduire les animations. La neige reste désactivée par défaut.

## Démarrer depuis les sources

Prérequis : Mac Apple Silicon, Xcode ou Command Line Tools avec SDK macOS 26+ et Swift 6.x, Python 3.12+ pour les tests. Déploiement minimal macOS 15 ; l’assistant exige macOS 26+ et Apple Intelligence disponible. Compatibilité avec les versions antérieures à macOS 26 non validée sur matériel réel.

1. Place le dossier du projet dans un emplacement où ton compte peut écrire, sur ton Mac ou un disque externe. Les compilations et caches restent dans `Build/` à côté des sources.
2. Lance `zsh Source/build.sh`. Les versions des dépendances Google sont verrouillées dans `Source/Package.resolved`.
3. Ouvre `Nino.app`, produite à la racine. La signature ad hoc sert au développement local ; macOS peut demander des autorisations. Ce n’est pas un installateur grand public.
4. Choisis **Explorer directement**, puis **Créer mon premier travail**. Aucun compte n’est nécessaire.
5. Pour les quotas, installe et connecte les CLI officiels Codex et Claude Code. Le helper Claude s’installe localement par `zsh install-helper.sh`, avec vérification SHA-256.
6. Pour la transcription, configure un modèle Whisper et les helpers audio. Ils ne sont pas inclus dans les sources. Consulte les réglages de Nino pour les éléments manquants.

Si la bibliothèque attend l’accès au disque, utilise **Choisir le dossier…** et sélectionne le dossier `Documents` de cette installation.

## Brancher un agent à Nino

Dans **Connexions → Nino devient ton connecteur MCP** :

1. Crée et sélectionne une fiche.
2. Copie/exporte la configuration MCP dans ton outil IA (Codex, Claude ou autre client compatible stdio).
3. Vérifie l’aperçu du contexte puis active **Partager cette fiche…**.
4. Demande à l’agent : « Lis mon travail Nino, puis signale quand tu commences, quand tu attends mon intervention et quand tu termines. »

Outils : `nino_get_context`, `nino_report_progress`. Ressource : `nino://current-work`. Le client doit utiliser les identifiants de projet/session renvoyés par la lecture. Voir [le protocole et les exemples](../docs/MCP.md).

Les statuts sont **déclarés par l’agent**. Nino ne déduit pas qu’un chat Codex est terminé à partir de sa dernière modification. Sans configuration MCP côté client et sans appel d’outil, aucun signal n’apparaît. Un signal « terminé » ne prouve pas qu’un déploiement ou un test est réussi.

Nino est actuellement un **serveur MCP**, pas un client universel qui lance les serveurs tiers. Aucun serveur, commande ou agent tiers n’est démarré automatiquement.

## En cours ou en visio

Démarre volontairement un appel : le téléprompteur s’ouvre dans l’encoche. Chaque nouvelle question détectée peut le rouvrir ; désactive cette option ou masque la réponse à tout moment. Les réponses automatiques passent d’abord par un filtre conservateur et une analyse locale avec le contexte du cours ; une phrase incomplète peut être ignorée. Une question saisie manuellement affiche sa réponse complète lorsqu’elle est prête ; la précédente reste visible pendant le calcul. Le fond du lecteur est semi-transparent, sauf si Réduire la transparence est activé dans macOS. La détection est heuristique et la compréhension dépend de la transcription. **Lire dans l’encoche** permet aussi de le rouvrir manuellement. Le mode **Cours** aide à expliquer les notions ; **Faire le point** utilise la portion récente de la transcription. Le direct dépend des permissions macOS et de la reconnaissance vocale ; la transcription finale dépend du moteur Whisper. Aucune détection ou capture Teams automatique, aucun message envoyé à la réunion. La capture système peut inclure les autres applications.

## Google et Gmail

La connexion native utilise AppAuth 2.1.0 et un client OAuth de bureau. Le parcours réel a été vérifié avec un compte personnel. Les sources publiques ne contiennent aucun identifiant OAuth éditeur ni session utilisateur.

L’éditeur doit configurer une fois Google Cloud, le consentement, un client OAuth de bureau. Les utilisateurs finaux n’auront pas à créer de projet Cloud. Gmail demande ensuite un consentement distinct ; le code ne lit que cinq aperçus à la demande et n’envoie rien. Voir [GOOGLE-ET-MAIL.md](../GOOGLE-ET-MAIL.md).

La connexion Google n’est pas un service de comptes Nino synchronisés. Il n’y a aucun backend de comptes dans cette version. Le relevé GitHub Actions public est disponible sur demande, sans token. Les dépôts privés, GitLab distant, le calendrier et la validation des déploiements restent à implémenter ; associer leur URL à une fiche ne les connecte pas.

## Données et permissions

- `Workspace/workspace.json` contient tes fiches. `Documents/` contient tes documents/audio. Ces répertoires ne doivent jamais être commités.
- Le MCP ne partage que le brief, la prochaine action, les tâches et les liens de la fiche sélectionnée. Pas de fichiers du dépôt, messages de chat, enregistrements, mails ni identifiants.
- Le client IA peut transmettre le contexte partagé à son fournisseur. L’aperçu et le consentement précèdent le partage.
- Le partage s’arrête au changement de fiche, au redémarrage et à la fermeture normale. En cas de crash ou d’erreur disque, le bail expire au plus tard après cinq minutes.
- Les quotas utilisent les comptes des CLI. Nino ne reçoit pas leur mot de passe. La session Google est conservée dans le Trousseau macOS.
- Aucun enregistrement ne démarre automatiquement. Une capture système peut inclure le son d’autres applications. Préviens les participants selon le contexte de ton appel.
- Le connecteur Git peut inspecter/hacher les fichiers pour calculer le statut, mais ne remonte que les métadonnées. Les dépôts avec filtres `clean/process` sont refusés pour éviter d’exécuter des commandes configurées dans le dépôt.

## Tests et contribution

`bash test.sh` vérifie persistance, limites, révocation, connecteur Git et serveur MCP avec des fixtures synthétiques. Aucun compte Google, audio personnel ou accès réseau n’est nécessaire pour cette suite. La CI prévue exécute cette suite et compile l’application native ; elle n’a pas encore tourné sur GitHub.

Voir [CONTRIBUTING.md](../CONTRIBUTING.md), [SECURITY.md](../SECURITY.md) et [la validation locale](../VALIDATION-0.17.1.md). Les contrôles de source et la compilation ne remplacent pas la validation visuelle et matérielle.

## Distribution

La source peut être publiée comme alpha développeur après revue du contenu. Pour une installation grand public : signature Developer ID, notarisation, configuration OAuth éditeur et recette multi-Mac restent nécessaires. Aucun secret, modèle Whisper, helper audio binaire, compte ou donnée de travail n’est inclus.

Code original Nino : [MIT](../LICENSE). Dépendances et attribution : [THIRD_PARTY.md](../THIRD_PARTY.md).
