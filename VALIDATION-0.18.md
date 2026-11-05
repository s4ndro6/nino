# Validation de la première distribution — 0.18.0

5 novembre 2026. Alpha publique Apple Silicon, macOS 15+. L’assistant Apple Intelligence demande macOS 26+ et sa disponibilité locale.

## Contrôlé avant publication

- Build release avec SDK Apple, signature ad hoc vérifiée ; arm64, minimum macOS 15, FoundationModels lié faiblement. Les dépendances dynamiques sont fournies par macOS.
- Paquet reconstruit sans configuration OAuth éditeur, modèle, helper optionnel, compte ou document personnel. Licences Nino/AppAuth incluses. Le build remplace le bundle entier pour éviter de conserver une ancienne ressource privée.
- Bibliothèque installée séparément dans Application Support/Nino. Création de la racine avant les stores, conservation des fichiers existants, mode portable/découverte explicite.
- Tests automatisés : 14 suites Swift, 19 tests MCP et 6 tests Python du collecteur. Tests de chemins Applications/DMG/translocation, première création, racine portable absente et ancêtres symlinks inclus.
- Lancement de la nouvelle app sur le Mac de développement : création, édition et sauvegarde d’un post-it observées. État Google « Pas encore activé » vérifié. Pas de nouveau test audio ni de connexion de compte. Les préférences d’un ancien Nino existaient sur ce Mac : ce n’est pas une recette sur Mac vierge.
- README, dépendances facultatives et installation sans Terminal pour les fonctions de base documentés.
- Revues ciblées sécurité et adversarial : aucun blocage de confidentialité confirmé dans le paquet. Les deux remarques sur la copie des licences et le remplacement complet du bundle ont été corrigées ; les ressources de dépendances périmées sont exclues.
- La promenade de la version précédente est confirmée visuellement par l’utilisateur : pas et gestes visibles. Sa perception sur tous les écrans n’est pas garantie.

## Limites de cette alpha

Pas de signature Developer ID ou de notarisation ; une exception manuelle macOS peut être nécessaire. Aucun contournement global de Gatekeeper. Pas de binaire Intel. Pas de recette sur tous les Mac/Spaces/écrans ni de mesure d’autonomie prolongée.

FFmpeg, whisper.cpp, modèle GGML et helper Claude optionnel ne sont pas livrés dans le DMG. Google/Gmail sont inactifs dans cette distribution ; la configuration privée qui avait été testée localement n’est pas distribuée.

La capture réelle de tous les outils de réunion et l’exactitude des réponses IA restent à valider selon le contexte. Les contrôles locaux ne prouvent pas que toutes les fonctions fonctionnent sur chaque Mac.

Le collecteur de statistiques reste local et sans endpoint configuré dans l’app. Ni données réelles, ni base SQLite ne figurent dans la release.

## Preuves publiques

Le workflow GitHub « Local core and MCP » teste puis compile les sources. Son résultat réel est visible dans l’onglet Actions du dépôt ; ne pas déduire une réussite de la seule présence du fichier YAML. Les sommes SHA-256 de la release permettent de contrôler le téléchargement.

Les vérifications antérieures détaillées restent dans VALIDATION-0.17.1.md. Le README actuel fait référence pour le stockage et la distribution.
