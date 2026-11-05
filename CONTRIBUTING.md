# Contribuer

Nino est une alpha native SwiftUI/AppKit. La version 0.18 prépare sa première distribution publique ; les intégrations facultatives restent documentées séparément.

- Lire le README et les limites avant d’ajouter une intégration.
- Conserver les captures, documents, quotas et tâches indépendants des connecteurs.
- Aucun accès réseau, micro, serveur MCP tiers ou génération automatique à l’ouverture d’un écran.
- Processus hors fil principal, timeout, sorties bornées, arguments séparés, aucun shell recevant du texte utilisateur.
- Toujours préserver les fichiers existants ; sauvegarde avant migration. Ne pas inclure de données personnelles dans les fixtures.
- Tests : `bash test.sh`. Build complète : `zsh Source/build.sh` avec SDK macOS 26+.
- Tester visuellement à 680×540 et 1120×740, clavier et Réduire les animations. Vérifier les états vides, erreurs et déconnexion du disque.
- PR : problème, comportement final, tests et limites. Commits conventionnels (`feat:`, `fix:`, `docs:`…).

## Organisation

`Workspace.swift` possède la persistance et le partage. `WorkspaceView.swift` présente le travail ; `ConnectionsView.swift` prépare les accès. `RepositoryConnector.swift` lit Git. `MCP/Server.swift` est un exécutable indépendant à privilèges limités. Les modules audio existants restent séparés.

Les variantes de protocole doivent avoir des tests d’interopérabilité avant d’être déclarées compatibles. Un changement de schéma doit migrer les données et conserver un moyen de récupération.
