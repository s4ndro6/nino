# Validation 0.13 — 5 novembre 2026

- Compilation SwiftPM finale et signature ad hoc vérifiées.
- Tests de détection des questions : extraction, phrases déclaratives ignorées, snapshots identiques, extensions, remplacement d’une question, remise à zéro et expiration : PASS.
- Test réel Apple Intelligence sans micro sur question synthétique : détection automatique, premier fragment 4,445 s, réponse complète 4,817 s. Test hors sandbox nécessaire au service Apple local ; erreur 1008 dans le sandbox.
- Revue sécurité et contradictoire : aucun P1/P2 signalé. Gardes d’annulation ajoutées avant génération et après échec de préparation vocale ; avertissement partage d’écran visible dans le lecteur.
- UI réelle : première partie du cours conservée (9 min 32), transcription finale laissée À reprendre pour permettre la bascule ; mise à jour Découverte, autorisation macOS réinscrite via Réglages Système et capture/transcription réelle reprises dans un nouveau document.
- Une réponse automatique a été générée à partir du cours. La transcription a déformé un terme en « .com » et la réponse l’a interprété comme un site web : limite de compréhension réelle, non corrigée par le seul streaming. Aucun texte n’est envoyé ou prononcé dans Teams.
- L’affichage du nouveau lecteur dans l’encoche reste à confirmer visuellement sur l’écran sélectionné. Pas de validation physique de plusieurs écrans ou du mode lecture automatique sur réponse longue.

Les mises à jour ad hoc peuvent invalider les autorisations de capture macOS : un interrupteur déjà actif ne suffit pas toujours, la réinscription de l’application peut être nécessaire. Une distribution signée stable reste à préparer.

Sources et archives excluent les enregistrements, les données de comptes, la configuration OAuth privée et les caches. Aucun push.
