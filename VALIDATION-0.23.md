# Validation 0.23.0 — connexions IA

## Vérifié
- Compilation native publique arm64, signature ad hoc vérifiée.
- Suite complète `bash test.sh` réussie : audio, persistance, MCP, mises à jour, snapshots de réponses et contrats des API.
- Tests API sans compte : endpoints fixes, local sans réseau, corps Responses/Messages, absence d’outils, `store=false` OpenAI, clés invalides, limites de taille, erreurs HTTP, sorties incomplètes et refus des redirections.
- Trousseau macOS classique testé avec un service isolé et une clé factice : création, lecture, remplacement, suppression. Aucune clé réelle lue.
- Interface testée dans une application et bibliothèque isolées : accueil Montage vidéo, IA facultative, choix OpenAI/Claude/Apple, aucun modèle imposé, absence de clé signalée, clé factice enregistrée puis refusée par OpenAI et retirée de Nino.
- Brief existant conservé au choix d’un autre exemple ; remplacement explicite proposé.
- Réponse Apple Intelligence réellement générée depuis un brief fictif, puis création et sauvegarde effective du post-it correspondant.
- Capture de l’interface conservée dans les preuves locales `work/nino-023-ai-settings.png` du workspace parent (aucune clé visible).
- Revue de sécurité : aucun cloud automatique pour les appels ; sélection figée pendant génération, pas de corps d’erreur distant affiché, aucune clé dans les préférences/exports. Le Trousseau classique est documenté sans prétendre au backend Data Protection.
- Revue adversariale : corrigé l’écrasement du brief et la conservation d’un ancien résultat après préparation ; erreur de limite de post-it visible.
- Impeccable : composants natifs cohérents, champs nommés, données partagées et coûts visibles, choix local par défaut, onboarding facultatif.

## Non validé / limites explicites
- Pas de génération avec une vraie clé OpenAI/Claude : aucun crédit utilisateur consommé. Le test de clé valide + modèle + génération doit être fait avec la clé du propriétaire dans Nino.
- Le suivi via connexion Codex/Claude Code ne devient pas une API chatbot d’abonnement. Le moteur embarqué utilise une clé API ou Apple Intelligence.
- L’envoi ne contient que le texte visible de l’assistant ; aucune connexion Gmail, outils autonomes ou capture d’écran ajoutée.
- Le direct Apple Speech sur le Mac de la seconde utilisatrice n’a pas été testé ; disponibilité et autorisations restent distinctes du modèle Whisper.
- La réponse locale est un brouillon à relire ; sa qualité n’est pas garantie. Cette version reste une alpha non notariée.

## Livraison audio précédente
La 0.22 a été publiée sur le dépôt personnel et le site. Le flux signé a été comparé à la copie servie. Le parcours installé 0.21.1 → 0.22.0 a fonctionné via Sparkle (Installer → Installer et relancer) ; version constatée et bibliothèque/modèle antérieurs conservés. La CI GitHub sur 181ffde est passée.
