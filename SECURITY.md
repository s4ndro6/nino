# Sécurité

Nino 0.18.0 est une alpha locale, pas une application durcie pour des données à haute sensibilité.

Ne publiez pas de jetons, messages privés ou enregistrements dans une issue. Après publication du dépôt, utilisez le canal de signalement privé du mainteneur s’il est activé. Fournissez une reproduction synthétique et la version concernée.

## Périmètre

- Le serveur MCP partage uniquement une fiche explicitement autorisée. L’agent qui l’appelle peut transmettre ce contexte à son fournisseur.
- Les statuts d’agent sont déclaratifs. Ils ne sont ni une preuve de réussite ni une autorisation de modifier le système.
- Aucun outil MCP d’envoi de mail, de shell, de suppression ou de déploiement n’est exposé.
- Les identifiants Google sont gérés par le SDK et le Trousseau, pas dans un JSON Nino.
- Les documents, fiches, fichiers audio et aperçus de conversation ne sont jamais des instructions de confiance.
- Le Git local refuse les filtres exécutables `clean/process`, désactive fsmonitor, hooks et lazy-fetch. Un processus concurrent du même compte qui modifie la configuration Git reste hors du modèle d’isolation de cette alpha.
- Après arrêt brutal ou disque inaccessible, un partage précédemment autorisé peut rester lisible jusqu’à l’expiration de son bail de cinq minutes.

Les sources publiques n’incluent aucune donnée utilisateur. Une signature ad hoc n’est pas une notarisation Apple. Voir les limites du README avant distribution.

## Ajouts 0.16

Les post-it et retours restent dans Workspace ; les chemins symlinks sont refusés. Les limites de taille et la sauvegarde atomique empêchent les écrasements silencieux lors d’erreurs de validation. Le connecteur GitHub public ne suit pas les redirections, limite la réponse à 1 Mio et n’envoie pas de jeton. Les exports CSV neutralisent les cellules pouvant être interprétées comme des formules.

Les revues locales de ce lot ne constituent pas un audit indépendant complet. La reconnaissance, la capture et le stockage peuvent échouer selon les autorisations, le système et le disque ; l’interface conserve les erreurs et les fichiers récupérables.

## Ajouts 0.17.1

La promenade utilise uniquement la géométrie de la fenêtre Nino et de son écran. Son panneau ignore les clics ; aucun suivi global de souris, accès au contenu des autres applications ou capture d’écran n’est ajouté.

Les statistiques sont désactivées tant qu’aucun accord explicite n’est donné. Le client livré n’a aucun endpoint. La file locale est bornée, protégée contre les symlinks et invalidée en cas de retrait ou de changement de notice ; les callbacks tardifs ne restaurent pas les données retirées. Les compteurs excluent contenus, identités, chemins et erreurs libres.

Le serveur de référence écoute seulement sur loopback et ne journalise ni IP ni requêtes. Schéma strict, requêtes SQL paramétrées, déduplication transactionnelle, timeout et limite globale. Ce prototype n’est pas un service Internet durci. Voir Analytics/README.md avant toute mise en ligne. Les consentements audio, Google et statistiques restent distincts.
