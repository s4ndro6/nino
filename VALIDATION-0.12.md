# Validation Nino 0.12 — 5 novembre 2026

## Exécuté

- Compilation SwiftPM complète de la version finale et helper MCP ; signature ad hoc vérifiée.
- Suite publique `test.sh` réussie : Workspace, Git, 19 tests MCP, profils métier et contrôles Google hors ligne.
- Tests Google liés à AppAuth réussis : PKCE S256, state/nonce distincts, scopes initiaux minimaux, conservation des droits si le renouvellement omet scope, réduction effective des droits.
- Revue sécurité et revue contradictoire : correction de la course d’annulation entre deux connexions, révocation non annulable et droits Gmail après renouvellement.
- Connexion Google réelle depuis Nino Découverte : compte personnel visible, Gmail non connecté. Mise à jour, redémarrage puis Reprendre ma connexion : identité retrouvée depuis le Trousseau.
- Mode Cours testé dans l’application avec une question saisie sur segmentation/persona : réponse locale affichée, boutons copier/prompteur présents. Aucun enregistrement déclenché. La réponse comporte une réserve générique de contexte ; sa qualité pédagogique reste perfectible.
- Apple Intelligence disponible ; génération locale réussie. Whisper testé sur un court audio synthétique avec le modèle small, sans enregistrement personnel.
- Modèle Whisper installé aussi dans l’environnement Découverte.

## Limites explicites

- Aucun appel Teams réel enregistré pendant cette passe ; pas de validation complète micro/casque/transcription directe.
- Gmail non autorisé et non testé. Configuration Cloud en test, sans facturation ; pas de validation Google pour distribution générale.
- Promenade d’accueil compilée et contrôlée en source, pas de recette visuelle exhaustive multi-écran de cette nouvelle animation. Le responsive de la version précédente ne constitue pas une validation de tous les nouveaux écrans.
- Espaces métier : fiches séparées, comptes et documents communs. Aucun plugin de contrôle DaVinci/Premiere/Photoshop/Illustrator.
- Aucun backend de comptes Nino ni synchronisation cloud ; serveur MCP local, pas de client MCP universel.
- Signature ad hoc, pas de notarisation. CI distante non exécutée, aucun commit ni push.
- Avertissements de compilation existants autour de MTMR et API AppAuth dépréciée pour le flux navigateur/loopback choisi.

Les fichiers de configuration OAuth de l’éditeur, modèles, données, enregistrements, caches et sessions ne sont pas inclus dans l’archive source.
