# Changelog

## 0.23.0 — Une IA pour tes brouillons

- Apple Intelligence par défaut ; OpenAI Responses et Claude Messages disponibles avec une clé API personnelle dans le Trousseau.
- Vérification explicite des clés et liste des modèles ; aucun envoi automatique, aucun fallback cloud et aucun accès aux fichiers par l’IA.
- Connexions ChatGPT/Codex et Claude Code identifiées séparément du moteur de réponses.
- Préparer un résumé depuis une transcription, relire avant envoi, préserver un brief existant, convertir le résultat en post-it.
- Raccourcis de préparation pour ticket, réponse, plan de montage et résumé/actions.
- Clarifie les prérequis de transcription en direct Apple, indépendants du modèle Whisper.


## 0.22.0 — Voix prête sur un nouveau Mac

- Moteur Whisper 1.9.5 autonome inclus, conversion AVFoundation : plus de dépendance Homebrew/FFmpeg pour transcrire.
- Choix explicite du modèle local dans l’accueil et les réglages, progression, annulation, SHA-256 et récupération après téléchargement corrompu.
- Enregistrer/importer et écouter sans modèle ; préparation guidée avant dictée ou transcription.
- Lecteur audio rechargé après finalisation, durée, déplacement, fin de lecture et erreurs visibles.
- Accès au dernier audio depuis l’encoche et protection des téléchargements pendant une mise à jour.


## 0.20.1 — Installation sur un autre Mac

- Rend la neige accessible depuis Affichage → Neige sur le bureau, même dans le mode Livraison.

- Corrige les droits du paquet et du LIRE-MOI : dossiers et exécutables 755, documents 644, y compris sous umask 077.
- Le lien Applications n’est jamais suivi pendant cette correction.
- Ajoute un test de non-régression et clarifie l’alerte Apple. La version reste non notariée ; les permissions ne remplacent pas une signature Developer ID.

## 0.20.0 — 2026-11-05

- Mises à jour : consentement facultatif, contrôle quotidien GitHub, vérification manuelle, alerte dans l’encoche et notes de version.
- Choix Télécharger / Plus tard (24 h) / Ignorer cette version ; aucune installation ni interruption automatique.
- Offre persistée et revalidée au redémarrage, liens restreints au dépôt personnel, réponses bornées et tests hors réseau.
- Signaux MCP dans l’encoche : à traiter, en cours, dernier message et acquittement ; les signaux anciens ne comptent pas comme actifs.
- Version « À propos » lue depuis le bundle, script de packaging public reproductible, documentation et inspiration Coucou explicitée.
- Inclut le parcours livraison préparé en 0.19.

## 0.19.0 — incluse dans la distribution 0.20

- Parcours « Ma livraison » : critères éditables par projet, dossiers locaux, contrôles réels de présence, dimensions, durée, poids et piste audio.
- Rapport détaillé daté, accès Finder et export Markdown ; métadonnées indisponibles explicitement non vérifiées.
- Encoche contextuelle pour les métiers créatifs, sans interrompre les outils actifs.
- Annulation, invalidation des résultats périmés, protection des fichiers locaux et tests synthétiques.
- [Guide du parcours](docs/DELIVERY.md).

## 0.18.0 — 2026-11-05

- Première distribution publique personnelle sur GitHub, DMG Apple Silicon et guide de premier lancement.
- Stockage Application Support séparé du bundle, préparation automatique et compatibilité explicite avec les bibliothèques portables/découverte.
- Build public sans configuration OAuth, licences incluses, ressources AppAuth seulement, remplacement complet du bundle avec sauvegarde.
- README de présentation, aperçu animé, bouton de téléchargement, prérequis et limites explicites.
- Tests des chemins installés et de la création du dossier de données ; CI sur macOS 26 avec Python 3.12.

## 0.17.1 — 2026-11-05

- Animation de promenade articulée, profil trois quarts, pas liés à la distance, bras alternés, escalade, regard, réflexion et salut.
- Trajectoires bornées à l’écran courant, deux itinéraires alternés, accélération/décélération et tests des raccords.
- Post-it papier en six couleurs, texture statique, adhésif, coin plié, contraste et panneau manipulable.
- Accueil en cinq étapes, scène Mac/post-it, choix facultatifs et navigation persistante.
- Consentement aux compteurs d’usage, aucune collecte avant accord, retrait/purge et aucun endpoint livré.
- Collecteur local SQLite avec schéma strict, déduplication, rétention, limite globale de requêtes et fixtures synthétiques.

## 0.16.0 — 2026-11-05

- Parcours unique de préparation audio, état réel des autorisations, timeout micro/Speech, annulation du démarrage.
- Conservation des pistes audio finalisées lorsqu’une autre piste échoue.
- Post-it locaux avec panneaux flottants, projets, checklist, couleurs, corbeille et export Markdown.
- File des signaux MCP observés, avec acquittement et distinction explicite des chats non connectés.
- Retours par projet avec version/timecode/statut, exports CSV/Markdown ; relevé GitHub Actions public réel sur demande.
- Identité de signature configurable au build, sans certificat ou notarisation inclus.

## 0.15.0 — 2026-11-05

- Le clic explicite Lire dans l’encoche donne le focus au lecteur, sans prise de focus des réponses automatiques.

- Correction de la question et reformulation « Plus simple » depuis l’encoche.
- Contexte figé avec chaque réponse : une correction ne récupère pas un autre sujet apparu ensuite.
- Refus des corrections devenues obsolètes pendant la saisie ; brouillon conservé.
- Publication complète des réponses manuelles ; ancienne réponse conservée en cas d’erreur, d’annulation ou de résultat hors limites.
- Consignes plus précises sur les causes, comparaisons et nuances ; aucune garantie de justesse du modèle.

## 0.14.0 — 2026-11-05

- Fond du téléprompteur à 72 % d’opacité, respect du réglage macOS Réduire la transparence.
- Filtre des phrases incomplètes avant analyse locale ; question reformulée et réponse publiées ensemble.
- Ancienne réponse conservée avec son heure pendant l’analyse d’une nouvelle candidate.
- Protection contre réponses obsolètes et réanalyse en boucle d’un candidat actif.
- Tests synthétiques : question après-achat contextualisée, fragments SAV et .com rejetés par filtre. La justesse générale du modèle n’est pas garantie.


## 0.13.0 — 2026-11-05

- Réponses de cours en streaming, directement dans l’encoche, avec question, pagination, taille du texte et lecture automatique.
- Maintien ouvert hors survol, masquage manuel et option d’ouverture automatique.
- Détection plus stable des questions, déduplication des corrections Speech, invalidation des réponses périmées.
- Première réponse locale mesurée à 4,45 s, terminée à 4,82 s sur une question synthétique ; ce n’est pas une garantie de latence.
- Capture Teams réelle reprise après réinscription de l’autorisation macOS de la build ad hoc.


## 0.12.0 — 2026-11-05

- Connexion Google de bureau AppAuth : navigateur, PKCE, session Trousseau, reprise explicite ; Gmail distinct.
- Espaces par métier et modèles éditables ; migration des fiches anciennes vers Général.
- Compagnon mobile autour de la fenêtre d’accueil, réglage discret/joueur et respect de Réduire les animations.
- Mode Cours : explications locales et synthèse de l’extrait récent du direct.
- Tests d’isolation des profils, révocation MCP au changement d’espace et gestion des scopes Google renouvelés.
- Connexion réelle Google et reprise après redémarrage vérifiées. Gmail, appel Teams réel et nouvelle promenade multi-écran restent à valider.


## 0.11.0 — 2026-11-05

- Nouvel accueil centré sur un travail : brief, prochaine action, étapes et liens persistants.
- Association d’une conversation Codex et transfert explicite du contexte à l’assistant local.
- Connecteur de dépôt Git local, borné et en lecture seule ; refus des filtres pouvant exécuter du code.
- Serveur MCP stdio natif, contexte opt-in, signaux déclaratifs d’agent, révocation et bail de cinq minutes.
- Affichage du travail dans l’encoche ; animation adaptée aux signaux d’agent dans l’encoche et via le pont Touch Bar.
- Centre de connexions avec aperçu du partage et export de configuration MCP.
- Fenêtres compacte et confortable ; sélecteurs natifs rattachés à la fenêtre.
- Documentation de contribution/sécurité, protocole MCP et suite CI sans comptes réels.

Google/Gmail restent inactifs sans configuration OAuth et signature éditeur. Pas de backend de comptes, de client MCP généraliste, ni de connecteur de déploiement distant dans cette version.
