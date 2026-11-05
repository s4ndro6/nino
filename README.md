<div align="center">

# nino

### Un petit compagnon. De la place pour tes idées.

Un post-it à garder sous les yeux. Le fil de ton projet. Une pause pour te concentrer.<br>
Nino s’installe dans l’encoche de ton Mac et accompagne ta journée, à ton rythme.

[![Télécharger Nino pour Mac](docs/assets/download.svg)](https://github.com/s4ndro6/nino/releases/download/v0.20.1/Nino-0.20.1-macOS-arm64.dmg)

**Apple Silicon · macOS 15 ou plus · gratuit · MIT**<br>
Version 0.20.1 — alpha publique, non notariée par Apple.

[Le site Nino](https://nino-companion.vercel.app) · [Installation](#en-trois-gestes) · [Ce que tu peux faire](#ton-petit-coin-de-bureau) · [Contribuer](CONTRIBUTING.md) · [Signaler un problème](https://github.com/s4ndro6/nino/issues)

![Nino marche, observe, grimpe, réfléchit et fait coucou. Aperçu des gestes du composant de l’application.](docs/assets/promenade.gif)

</div>

## En trois gestes

1. **[Télécharge le DMG](https://github.com/s4ndro6/nino/releases/download/v0.20.1/Nino-0.20.1-macOS-arm64.dmg)** et ouvre-le.
2. **Glisse Nino dans Applications**, puis éjecte le disque Nino.
3. **Ouvre Nino depuis Applications.** Choisis ton profil, ou commence directement avec une note.

Aucun Terminal, abonnement ou compte obligatoire pour commencer. Mac Intel, Windows et Linux ne sont pas pris en charge par ce téléchargement.

> **Premier lancement :** cette alpha n’est pas encore signée avec un certificat Developer ID ni notariée. macOS peut la bloquer. Après avoir essayé de l’ouvrir, consulte **Réglages Système → Confidentialité et sécurité** pour décider d’autoriser cette application. [Procédure officielle Apple](https://support.apple.com/fr-fr/102445). Aucune commande pour désactiver Gatekeeper n’est nécessaire ou fournie. Si macOS signale un logiciel malveillant ou ne propose pas d’exception, ne force pas l’ouverture et ouvre une issue.

Les sommes SHA-256 sont jointes à la [release](https://github.com/s4ndro6/nino/releases/tag/v0.20.1). Déplace l’app avant de configurer le MCP : son chemin doit rester stable.

**Nouveau en 0.20 :** alertes de mise à jour facultatives, signaux des agents dans l’encoche et [contrôle des fichiers à livrer](docs/DELIVERY.md). [Fonctionnement des mises à jour](docs/UPDATES.md).

Déjà sur 0.18 ? Installe 0.20 une première fois depuis ce bouton pour recevoir ensuite les alertes.

## Ton petit coin de bureau

**Des notes qui ressemblent à des notes.** Papier jaune, abricot, menthe, bleu, lavande ou rose. Un peu de grain, une ombre, un coin plié. Écris, coche, replie, associe une note à un projet et retrouve-la après redémarrage.

**Un travail, un endroit où reprendre.** Garde un brief, la prochaine action, les étapes et les liens utiles dans une fiche. Associe ton dépôt local et un chat Codex enregistré. Ajoute des retours avec version, timecode et état ; exporte-les en Markdown ou CSV.

**L’encoche à portée de main.** Un minuteur, tes raccourcis et un compagnon animé. `⌃⌥N` affiche ou masque l’encoche. Les écrans sans encoche disposent aussi du panneau en haut de l’écran.

**Un peu de vie.** Pendant l’accueil, Nino se promène, balance les bras, grimpe et s’arrête pour regarder. C’est une animation décorative, pas un agent qui lit tes applications. Tu peux l’arrêter ; le mode Discret et le réglage macOS Réduire les animations sont respectés. La neige reste désactivée par défaut.

## Pour ton quotidien

| Tu fais… | Nino peut t’aider à… |
| --- | --- |
| Du développement ou du vibe coding | Retrouver le brief, le dépôt et la prochaine étape ; consulter les quotas disponibles ; recevoir les signaux d’un agent connecté au MCP. |
| Du montage ou de la création de contenu | Garder des retours avec version et timecode, une checklist d’export, un script de prompteur et des notes de production. |
| Du design ou de la communication | Rassembler les références, les liens de validation et les corrections dans une fiche. |
| Un peu de tout | Poser une idée, organiser quelques tâches et lancer une session de concentration. |

Les modèles s’adaptent à ton profil. **Nino ne pilote pas directement Photoshop, Illustrator, Premiere ou DaVinci.**

## Ce qui est prêt, ce qui demande une connexion

| Fonction | Dans cette version |
| --- | --- |
| Post-it, fiches, checklist, minuteur, prompteur manuel | Disponibles sans compte. |
| Statut d’un dépôt Git local | Lecture explicite ; aucun commit, push ou fetch. |
| GitHub Actions d’un dépôt public | Cinq exécutions à la demande. Un workflow vert n’est pas une preuve de bon déploiement. |
| Nino MCP | Serveur natif inclus ; partage d’une fiche uniquement après accord. [Guide MCP](docs/MCP.md). |
| Quotas et chats Codex | Nécessitent l’outil officiel Codex connecté sur le Mac. Les chats affichés sont des échanges enregistrés, pas une surveillance universelle en direct. |
| Quota Claude / Claude Code | Nécessite Claude Code connecté et le helper CodexBar facultatif. [Installation des options](docs/INSTALLATION.md). |
| Capture micro et son du Mac | Autorisations macOS distinctes ; enregistrement lancé explicitement. Aucun consentement micro ne valide les autres accès. |
| Transcription finale d’un média ou d’un enregistrement | FFmpeg, whisper.cpp et modèle GGML à installer séparément. [Préparer la transcription](docs/INSTALLATION.md#transcription-locale). |
| Assistant et réponses en direct | Apple Intelligence disponible et activée, macOS 26 ou plus ; reconnaissance vocale autorisée pour le direct. Les réponses restent à vérifier. |
| Google / Gmail | **Non activés dans le téléchargement public.** Le code du connecteur est fourni ; sa configuration éditeur et sa validation publique restent à finaliser. Aucun compte Google n’est requis pour essayer Nino. |
| Touch Bar | Extension MTMR facultative, configuration manuelle. [Guide Touch Bar](TouchBar/README.md). |

Nino est une **alpha**. L’installation neuve sur tous les Mac, la fiabilité de tous les appels et la justesse de l’IA ne sont pas garanties. [Correction d’installation 0.20.1](VALIDATION-0.20.1.md) · [Vérifications 0.20](VALIDATION-0.20.md) · [Limites de la première distribution](VALIDATION-0.18.md).

## Tes données restent les tiennes

- Les notes, fiches et enregistrements sont stockés dans `~/Library/Application Support/Nino`, séparément de l’application. Une mise à jour de l’app ne remplace pas ta bibliothèque.
- Aucun enregistrement ne démarre à l’installation. Le son du Mac peut inclure d’autres applications : préviens les participants selon le contexte.
- Aucun compte Nino central, aucun audio envoyé par Nino pour les quotas, aucun contenu de note utilisé comme statistique.
- Les compteurs d’usage sont **facultatifs et désactivés tant que tu n’acceptes pas**. Aucun serveur de collecte n’est configuré dans cette release. Le prototype SQLite reste [local](Analytics/README.md).
- Le MCP ne partage que la fiche sélectionnée et autorisée. L’outil IA auquel tu le connectes peut transmettre ce contexte à son propre fournisseur.
- Les services explicitement utilisés, comme GitHub ou les CLI de quotas, effectuent leurs requêtes réseau. « Local » ne signifie pas que chaque connecteur fonctionne hors ligne.

[Politique de sécurité](SECURITY.md) · [Connexions Google](GOOGLE-ET-MAIL.md)

## Construire et contribuer

Mac Apple Silicon, outils Apple avec SDK macOS 26 ou plus récent. Python 3.12+ pour les tests ; aucune dépendance Python à installer.

```sh
git clone https://github.com/s4ndro6/nino.git
cd nino
bash test.sh
NINO_PUBLIC_BUILD=1 zsh Source/build.sh
```

Le build produit `Nino.app` et télécharge AppAuth 2.1.0, épinglé dans le manifeste. Les fichiers temporaires de compilation restent dans `Build/`. Le flag public empêche d’intégrer une configuration OAuth privée. Les tests utilisent des fixtures ; ils n’enregistrent pas ton micro.

Une correction, un retour d’usage ou une petite amélioration sont les bienvenus. Une issue précise avec version de macOS et étapes de reproduction aide davantage qu’un enregistrement privé. [Contribuer](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [Guide détaillé](docs/GUIDE.md)

---

Projet personnel de [Sandro](https://github.com/s4ndro6). Code original sous [licence MIT](LICENSE). Bibliothèques et attributions : [THIRD_PARTY.md](THIRD_PARTY.md).
