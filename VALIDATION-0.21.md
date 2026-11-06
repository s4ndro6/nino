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

## Distribution vérifiée

Le 6 novembre 2026, un bootstrap local contenant Sparkle avec le compteur 22 a téléchargé le DMG public GitHub 0.21.0 (build 23), vérifié sa signature, proposé « Install and Relaunch », remplacé l’application dans `~/Applications/Nino.app` et relancé Nino. La vérification suivante a affiché « You’re up to date » ; le plist installé confirme le build 23 et la signature de code est valide. Ce premier test utilisait un bootstrap de développement, pas une ancienne 0.20 dotée magiquement du moteur.

Les quatre identifiants de documents sont inchangés ; le fichier des post-it est identique octet pour octet à la sauvegarde avant migration. La bibliothèque X9 et les modèles sont visibles dans l’interface. L’ancienne Découverte est archivée sur le X9. Les deux workflows GitHub du commit `a057051` sont réussis.

Signature du DMG final 0.21.0 vérifiée avec la clé publique via CryptoKit ; modification d’un octet en mémoire refusée. SHA256 : `d34af7093dcb4bf9f4ff174deef55ce8dbd497fed61e885fb30e0dd0ab1ba146`.

Le correctif 0.21.1 distingue « déjà à jour » d’un échec et déclare la langue française pour les dialogues Sparkle. Build natif et vérification de signature réussis.

 Les autres Mac, les autorisations système et une future signature Developer ID ne sont pas validés par cette compilation. Nino demeure une alpha gratuite non notariée.

## Mise à jour publique 0.21.0 → 0.21.1

Test réalisé depuis le Nino 0.21.0 (build 23) installé par Sparkle, sans modifier son plist : recherche du flux public, proposition 0.21.1, téléchargement GitHub, vérification, bouton « Install and Relaunch », remplacement et relance. Le plist installé indique 0.21.1 / build 24 et `codesign --verify --deep --strict` réussit. Le contrôle suivant affiche en français « Votre logiciel est à jour ! Nino 0.21.1 est la version la plus récente disponible. » ; les réglages n’affichent plus d’erreur.

Les quatre documents sont toujours présents. Les deux post-it initiaux sont conservés avec leurs valeurs initiales ; un troisième post-it a été ajouté depuis la première sauvegarde, donc le fichier complet n’est plus identique octet pour octet. Aucun contenu n’a été écrasé pour rétablir une comparaison artificielle.

SHA256 public 0.21.1 : `677dac9ccc547f45ff21d7babaf6e022d3030ae07dac505bfb2c0ebd48c806a2`, 3 983 992 octets. Les deux workflows GitHub du commit `ce948b5` sont réussis : tests, compilation et artefact CI. Flux et liens du site contrôlés en production.

Restent hors de ce test : installation neuve sur un autre Mac, nouvelle autorisation micro/écran liée au changement d’identité, reconnexion Google, interruption réseau en cours de téléchargement, signature Developer ID/notarisation. Aucun micro ou appel lancé pour ce test d’installation.
