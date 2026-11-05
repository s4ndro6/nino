# Validation locale Nino 0.11 — 5 novembre 2026

## Exécuté

- Compilation native SwiftPM et helper MCP Foundation ; signature ad hoc du bundle et du helper vérifiées.
- Suite Workspace : création/sauvegarde/relecture, tâches, changement de fiche, limites de taille, chargement corrompu, URLs, données autorisées et révocation.
- Suite Git : état propre/modifié/sans commit, noms avec espaces, renommages, dossier invalide, annulation, délai, borne de sortie, refus de fsmonitor et des filtres clean/process (y compris configuration incluse).
- **19 tests MCP d’intégration réussis** : cycle protocolaire, outils/ressource, entrées invalides, absence de réponse aux notifications, limites, symlinks/hardlinks/FIFO, révocation, ancien projet/session, expiration et dates futures.
- Revue indépendante : ancien jeton de session refusé, JSON profondément imbriqué sans crash, filtre Git malveillant bloqué sans exécution de sa commande.
- UI installée : création d’une fiche synthétique, trois étapes, case cochée, persistance sur X9 ; conversation Codex associée à cette fiche.
- Assistant Apple Intelligence : contexte transféré depuis la fiche et réponse générée localement.
- Git via UI : dossier synthétique sélectionné, branche `demo`, un fichier modifié, heure du relevé affichée. Dépôt détaché à la fin du test.
- **MCP installé → application** : lecture de la seule fiche synthétique, signal `working` puis `completed`, états visibles dans Nino avec source et heure. Partage ensuite désactivé ; outils et ressource effectivement refusés.
- Fermeture et redémarrage : fiche, étape cochée et conversation associée retrouvées ; partage toujours désactivé. Sélecteur de dépôt annulé : retour direct à la fiche vérifié.
- Rendu vérifié à 1120×740 et 680×540 : adaptation de la navigation et empilement du contexte, contenu défilable.

## Limites

- Pas de connexion Google/Gmail réelle : configuration OAuth et signature Apple éditeur absentes.
- Pas de compte Nino centralisé, serveur MCP tiers exécuté, calendrier ou statut de déploiement distant.
- L’interopérabilité MCP a été exercée avec un client JSON-RPC local de test, pas par installation dans la configuration personnelle de Claude/Codex.
- Pas de nouveau test micro/appel/casque, ni de vérification physique de la Touch Bar ou d’un second écran dans cette passe.
- CI écrite mais non exécutée sur GitHub. Aucun commit ni push.
- Signature locale ad hoc, pas de notarisation ni d’installeur grand public.
- Des avertissements préexistants Swift sur l’observateur de fermeture MTMR subsistent ; compilation réussie.

Les signaux MCP sont déclarés par l’agent, pas une preuve de réussite de ses actions. Après crash ou disque inaccessible, un partage actif peut rester accessible jusqu’à cinq minutes. Les sources publiques excluent les données de test de l’application et toutes les données personnelles.
