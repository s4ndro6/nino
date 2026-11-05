# Nino 0.21 — mises à jour intégrées

## Préparation vérifiée le 6 novembre 2026

- SwiftPM : Sparkle 2.10.1 épinglé, framework et helpers embarqués ; build public arm64 réussi et signature ad-hoc vérifiée `codesign --verify --deep --strict`.
- 36 assertions de configuration/gardes, 10 assertions de fermeture asynchrone et 41 assertions de recherche GitHub passent. La suite existante `test.sh` passe ; tests stockage, preuves et statistiques réexécutés après les correctifs de disque absent, tous réussis.
- Refus de fermeture pendant capture/import/transcription/IA/livraison/connexion/sauvegarde. Revalidation après sauvegarde, refus sur erreur/timeout, callbacks doubles/tardifs ignorés.
- Les réponses du prompteur après un appel et la copie de modèles participent aux gardes.
- Clé EdDSA dédiée créée dans le Trousseau après accord explicite ; seule la clé publique est versionnée. Sans clé, installation intégrée désactivée et conditionnement public refusé.
- Éditions Découverte/Portable et configurations OAuth embarquées exclues du flux public.
- Configuration OAuth personnelle facultative hors bundle et racine X9 persistante pour migration explicite. Aucun jeton de session migré ; reconnexion Google nécessaire au changement d’identité.
- Régressions de stockage testées : racine absente non recréée, dossier modèle existant utilisable, sauvegardes répétées possibles.
- Aperçu SwiftUI isolé : boutons accessibles et action « Installer et relancer » raccordée. Simulation d’interface seulement, pas une preuve de remplacement.

## Vérifications de distribution à compléter

Le remplacement réel et la relance seront consignés ici après test de l’archive finale. Les autres Mac, les autorisations système et une future signature Developer ID ne sont pas validés par cette compilation. Nino demeure une alpha gratuite non notariée.
