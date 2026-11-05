# Validation 0.20.0 — 5 novembre 2026

## Périmètre

Alertes de versions publiques sur consentement, choix télécharger/reporter/ignorer, signaux MCP reçus visibles dans l’encoche. La distribution comprend également la fonction Livraison préparée en 0.19, dont les limites sont décrites dans `VALIDATION-0.19.md` et `docs/DELIVERY.md`.

## Vérifications effectuées

- Suite complète `bash test.sh` réussie : mises à jour, livraison, espace de travail, MCP, profils, connexion Google, questions d’appel, permissions, notes, signaux agents, capture synthétique, statistiques locales, promenade et stockage.
- Suite de mises à jour finale : **41 assertions**, sans réseau réel. Versions invalides, brouillons, rétrogradations, URL étrangère, taille, réponse invalide, consentement, erreurs, temporisation, version ignorée, prochaine version, cache au redémarrage et annulation d’une requête en cours.
- Compilation publique arm64 réussie avec `NINO_PUBLIC_BUILD=1`, version 0.20.0 / build 21. Des avertissements préexistants de compilation restent présents.
- Signature ad hoc vérifiée ; aucune configuration OAuth Google privée dans les ressources publiques. DMG monté en lecture seule, version et binaire comparés au bundle construit, signature du bundle monté vérifiée ; image démontée après contrôle.
- Interface SwiftUI réelle des mises à jour exercée dans un programme de recette isolé avec une version **fictive 0.21.0** : vérification, notes, boutons lisibles, report et refus. Aucun faux téléchargement n’a été déclenché.
- Revues de sécurité et contradictoire : correction de la disparition d’alerte au redémarrage, validation du cache, exclusion des sauvegardes locales du dépôt.

## Limites

- Ce test d’interface n’est pas une installation automatique de bout en bout. Le logiciel propose un DMG ; l’utilisateur choisit quand quitter et remplacer l’app.
- Aucune mise à jour imposée à l’instance personnelle en cours, aucune capture réelle démarrée ou interrompue.
- Pas de signature Developer ID ni de notarisation Apple ; distribution alpha pour Apple Silicon. Les anciens clients doivent installer cette version manuellement une première fois.
- Les signaux d’agents reflètent les événements reçus via MCP, pas une surveillance universelle de tous les chats ou outils.
- Les animations et ressources de Coucou n’ont pas été copiées ; voir `THIRD_PARTY.md`.
