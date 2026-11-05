# Validation locale — Nino 0.16.0

Date : 5 novembre 2026. Alpha développeur Apple Silicon. Sources sous MIT ; aucune publication GitHub effectuée.

## Livré et observé

- Build release complet sur X9 avec les outils Apple : succès. Signature ad hoc, intégrité de l’app et égalité du binaire installé/stagé vérifiées. Sauvegarde de Découverte 0.15 conservée.
- Nino Découverte relancé en 0.16. Aucun nouvel enregistrement réel pendant ce lot.
- Recette UI : création et édition de post-it, checklist cochée/décochée, pliage/dépliage, masquage/réouverture. Sauvegarde puis redémarrage : titre, contenu et état conservés. Contraste corrigé après contrôle visuel.
- Fiche d’exemple créée, retour V01 à 00:01:23.500 ajouté et passé à « À valider ». Fiche et retour retrouvés après redémarrage.
- Connecteur GitHub testé avec son vrai client puis dans l’app sur le dépôt public steipete/CodexBar : cinq runs reçus, commits/dates/liens et états distincts affichés. Aucun token ni mutation distante.
- Écran de préparation commun aux réglages et à l’accueil. Les permissions non acquises sont affichées ; aucune permission n’a été forcée. La signature locale peut invalider les anciens consentements.

## Tests automatisés

Script public `bash test.sh` terminé avec code 0. Onze exécutables Swift et dix-neuf tests Python MCP passent :

1. Workspace : persistance, limites, symlinks, révocation, corruption, tâches et sélection.
2. Git local : métadonnées, bornes, refus des configurations exécutables, aucune fixture exécutée.
3. MCP : 19 scénarios, cycle de vie, consentement, taille, redaction, dates, révocation, protocoles.
4. Profils : migration, isolation, sélection et révocation.
5. Google : configuration et état hors ligne ; ce n’est pas un test OAuth réel.
6. Questions : extraction, faux positifs, snapshots, remplacement et expiration.
7. Réponses : contexte figé, simplification, correction, échec, réponse tardive annulée.
8. Permissions : succès, timeout, annulation avant/après continuation, doublons, concurrence et callback tardif. Aucun prompt OS.
9. Notes : autosave, flush, limites, récupération, corbeille, checklist, multiécran géométrique, corruption et symlinks de tous les ancêtres.
10. Retours : timecodes, URL, isolation, persistance, corruption, export et injections CSV ; parseur GitHub, bornes et péremption.
11. Attention : déduplication, transitions, acquittement, sessions et borne 50.
12. Audio : 2 048 000 frames synthétiques, piste AAC finalisée et relisible malgré l’erreur injectée. Le codec demande une exécution hors sandbox de test ; aucune capture physique.

La compilation des derniers ajustements UI est passée. Les scripts shell passent leur contrôle de syntaxe.

## Revues

Deux revues ciblées de sécurité/adversarial. Deux défauts corrigés : annulation qui ne propageait pas au démarrage de capture, et ancêtre symlink accepté dans le dépôt de notes. Aucun problème confirmé restant dans ce périmètre ; ce n’est pas un audit exhaustif indépendant.

## Limites et suite

- Impossible de réunir les consentements macOS : micro, reconnaissance et écran/audio système restent distincts. Une seule entrée Nino les guide. Timeout 30 s sur micro/Speech ; les callbacks natifs ScreenCaptureKit ne disposent pas de la même borne.
- Pas de test réel d’appel de bout en bout pour 0.16 ; pas de garantie sur la justesse des réponses IA. Les anciens enregistrements restent conservés.
- Pas de certificat Developer ID disponible ici ni de notarisation. Option NINO_SIGNING_IDENTITY préparée, branche de signature publique non testée. L’entitlement audio-input est fourni pour hardened runtime : https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input . Il ne remplace pas le consentement macOS.
- Installation neuve sur un autre Mac, toutes les configurations multiécran/Spaces, batterie et CPU prolongés : non validés. Géométrie multiécran testée en données synthétiques seulement.
- Les signaux d’agents sont ceux réellement observés via MCP, gardés en mémoire jusqu’à fermeture (50 dernières sessions/agents). Pas de suivi universel automatique des chats.
- Google de production/Gmail, calendrier, GitLab distant, dépôts GitHub privés, contrôle Adobe/DaVinci, client MCP universel et mises à jour automatiques : pas livrés dans ce lot. Les documents expliquent les limites au lieu d’afficher des connexions fictives.
- La CI inclut désormais la compilation native, mais aucun run GitHub n’a été déclenché. Aucun push autorisé/effectué.

## Pour essayer

Post-it : barre latérale ou encoche. Fiche « Découvrir Nino · exemple » : retours et CI publique. Aujourd’hui : quotas et signaux reçus. Connexions → Micro, transcription et stockage → Préparer les accès audio : parcours guidé. Aucun compte nécessaire pour les notes, fiches ou minuteur.
