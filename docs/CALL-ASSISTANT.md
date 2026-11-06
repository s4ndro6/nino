# Répondre avec le fil de l’appel

1. Dans **Appel**, choisis Réunion ou Cours et donne le sujet, ton rôle et les faits confirmés dans Contexte.
2. Démarre l’appel et accorde les autorisations macOS demandées. Le direct transcrit le son système, même au casque ; le micro reste enregistré sur sa piste. Nino ne démarre pas l’enregistrement à ton insu.
3. Une question stable est vérifiée, puis une réponse courte est proposée. Le lecteur dans l’encoche s’ouvre si **Réponses auto dans l’encoche** est activé. Il ne lit pas la réponse à voix haute et ne l’envoie pas aux participants.
4. **Pause des suggestions** arrête la génération, pas la capture ni la mémoire. **Masquer** ferme seulement le lecteur. **Arrêter l’écoute** sauvegarde l’enregistrement et termine l’autorisation cloud.

## Contexte et précision

La mémoire temporaire contient uniquement les paroles reconnues, jamais les réponses inventées par un modèle. Elle retient jusqu’à 100 000 caractères ou 250 passages, puis retire les plus anciens. Pour chaque question : jusqu’à 1 200 caractères de contexte utilisateur, 1 800 caractères d’extraits antérieurs sélectionnés et 3 000 caractères récents. Les extraits anciens sont sélectionnés par mots communs et ordonnés chronologiquement. Ce n’est ni une mémoire exhaustive ni une recherche sémantique parfaite. Une correction récente doit primer sur une information ancienne.

La mémoire est remise à zéro au début d’un nouvel appel. Après l’arrêt, les dernières paroles restent disponibles dans la vue tant que Nino reste ouvert ; les enregistrements sauvegardés suivent le stockage habituel de la bibliothèque. Le changement de contexte annule les générations en attente sans couper la reconnaissance vocale. La correction d’une réponse et « Plus simple » utilisent son contexte d’origine.

Apple Intelligence est le choix initial de chaque appel. Il faut macOS 26+, un Mac compatible et son modèle Apple prêt. Sa fenêtre est limitée ; Nino envoie un contexte borné dans une session neuve à chaque génération. Une indisponibilité ou une erreur est affichée ; elle ne déclenche jamais un envoi cloud. Le modèle Whisper téléchargé pour les fichiers ne remplace pas le moteur Apple de transcription en direct.

## Cloud facultatif

Configure OpenAI ou Claude et un modèle dans Connexions, puis démarre l’appel. **Utiliser le cloud pour cet appel…** demande confirmation avant de transmettre le contexte saisi, la question, les extraits anciens/récents et, pour une simplification, la réponse affichée. L’audio brut n’est pas envoyé. Clé dans le Trousseau, transport HTTPS vers les endpoints fixes du fournisseur, redirections refusées, aucun outil distant.

Cet accord est lié à cet appel précis ; il expire à l’arrêt, au prochain appel ou à une modification de fournisseur, modèle ou clé. **Revenir en local** annule les demandes en cours. Une requête déjà reçue par le fournisseur peut rester facturable et soumise à ses règles de conservation. Une annulation n’efface pas des données déjà transmises. Pour OpenAI, les requêtes utilisent `store=false`, sans garantie de conservation nulle chez le fournisseur.

Maximum 20 demandes cloud par appel, tentatives comprises, et 10 secondes entre lancements automatiques. Une nouvelle question pendant ce délai remplace la précédente et attend son tour. Une erreur de génération automatique met les suggestions en pause ; aucune répétition automatique sur erreur. Le nombre de demandes est visible. La facturation API est distincte de l’abonnement ChatGPT/Claude. Les connexions Codex/Claude Code ne financent pas ce moteur.

## Validation de cette version

Tests déterministes sans micro ni fournisseur : conservation/sélection bornée, remplacement de question, arrivée tardive, changement de contexte, pause/reprise, consentement lié à la session, révocation, plafond de demandes, délai cloud, sortie JSON invalide. Les tests simulés ne garantissent pas la qualité du modèle dans un vrai cours. Vérifier les propositions avant de les reprendre ; Nino peut mal reconnaître ou mal interpréter une question.

Références : [contexte Foundation Models](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window), [connexion ChatGPT pour apps open source](https://developers.openai.com/siwc/token-sharing-open-source/sign-in), [connexions de Nino](INTELLIGENCE.md).
