# Validation locale — Nino 0.19.0 (build 20)

Date : 5 novembre 2026. Livraison locale uniquement ; le DMG public reste en 0.18.

## Compilation et installation

- Build release Apple Silicon réussi, avec `NINO_BUILD_DEBUG_INFO=none` dans cet environnement. Des avertissements Swift préexistants et des avertissements de copie des métadonnées ExFAT subsistent.
- Signature ad hoc vérifiée avec `codesign --verify --deep --strict`.
- Nino Découverte mis à jour sur le X9, même identifiant de bundle, configuration privée et bibliothèque conservées. Ancienne application conservée dans `Delivery-0.19/Previous`.
- Exécutable installé comparé au build final, après retrait des signatures uniquement sur des copies temporaires : identique.

## Nouveau parcours

26 assertions automatisées réussies. Couverture : dimensions réelles ImageIO, orientation, absence et fichier vide, corruption, liens symboliques, noms et limites invalides, doublons, métadonnées inconnues, audio absent, durée, modification concurrente, annulation, isolation des projets, invalidation du résultat, persistance des critères et rejet d’une configuration dépassant les limites. Une vidéo H264/AAC synthétique réelle est incluse dans cette exécution.

Deux revues indépendantes (sécurité et tests adversariaux) ont conduit à corriger :
- l’usage de valeurs de métadonnées URL mises en cache pour détecter un fichier modifié ;
- l’affectation d’un plan persisté avant sa validation.

## Vérifications dans l’application native

- Modèle vidéo choisi et restauré après redémarrage.
- Sélecteur de dossier rendu modal à la fenêtre principale quand elle est disponible ; activation de Nino avant présentation.
- Dossier synthétique `Exemple-a-corriger` : **2 écarts**, vertical.mp4 réellement 1920 × 1080 au lieu de 1080 × 1920, et sous-titres.srt absent ; 1 fichier sur 3 conforme.
- Dossier synthétique `Exemple-conforme` : **3 fichiers sur 3 conformes aux critères saisis**, dimensions horizontal/vertical, durée et piste audio réellement lues.
- Changement de dossier : ancien rapport effacé avant le nouveau contrôle.
- Fenêtres confortable et compacte inspectées visuellement : deux colonnes puis une colonne avec défilement, sans débordement horizontal observé.
- Export depuis le panneau natif : `Controle-livraison.md` créé et relu, avec le résultat attendu.

L’intégration de l’encoche est compilée et ses priorités ont été relues. Son panneau déplié n’a pas pu être isolé dans l’outil de capture native pendant cette recette : rendu visuel final de ce panneau à confirmer. Le glisser-déposer et toutes les combinaisons de matériels/écrans ne sont pas déclarés validés.

## Régressions existantes

Suites réussies : Workspace, Repository, MCP (19 tests), Profiles, Google hors SDK, questions et réponses d’appel, autorisations, Post-it, WorkEvidence, AgentAttention, UsageAnalytics, promenade, chemins de stockage.

Deux suites initialement bloquées dans le bac à sable ont ensuite réussi hors de cette restriction : récupération AAC (2 000 buffers synthétiques, fichier relisible), collecteur SQLite/HTTP localhost (6 tests). Aucun micro, appel réel ni transfert de données utilisateur n’a été démarré pendant cette recette.

## Limites du produit

Le brief n’est pas interprété par IA. Les règles restent explicites et éditables. Le contrôle ne certifie ni l’esthétique, ni l’audibilité, ni le contenu des sous-titres. Il ne pilote pas Premiere/DaVinci et ne surveille pas les exports en continu. Voir [le guide](docs/DELIVERY.md).
