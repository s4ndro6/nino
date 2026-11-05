# Validation 0.20.1 — 5 novembre 2026

Correction ciblée du paquet de distribution. Les copies précédentes pouvaient hériter de droits 700/600 (compte de fabrication uniquement), notamment après le passage par le volume X9 ExFAT. Ce contrôle manquait dans la validation précédente : une signature valide ne prouve pas la lisibilité par un autre compte.

- Normalisation du bundle final et du dossier temporaire du DMG : dossiers 755, exécutables 755, documents 644, aucun droit d’écriture public.
- Test de régression sous umask 077 : lecture/exécution pour les autres comptes et cibles de liens symboliques externes inchangées.
- Compilation publique 0.20.1 / build 22, vérification de signature après normalisation.
- Contrôle du DMG final monté en lecture seule : permissions de tous les répertoires/fichiers, LIRE-MOI lisible, exécutables accessibles, absence de configuration Google privée, signature et version du bundle.

La signature reste ad hoc ; aucun certificat Developer ID utilisable n’est disponible sur la machine de publication. **La correction de permissions ne supprime pas l’avertissement Gatekeeper et ne constitue pas une notarisation.** Aucun contournement de sécurité ajouté. L’ouverture sur le Mac de l’utilisatrice reste à confirmer ; le téléchargement vise Apple Silicon/macOS 15+ uniquement.
