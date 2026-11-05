# Validation 0.15 — 5 novembre 2026

## Vérifié

- Compilation SwiftPM finale 0.15 et vérification de signature locale réussies ; sources staging/X9/public identiques.

- Suite publique : Workspace, connecteur Git, 19 tests MCP, profils, configuration Google hors ligne, questions de cours et nouvelle suite de snapshots réussis.
- Tests injectés sans micro, réseau ni modèle : contexte figé après changement de sujet ; correction de question ; refus d’un brouillon basé sur une ancienne révision ; échec manuel et échec de simplification préservent question/réponse/heure ; résultat trop long et publication tardive annulée rejetés.
- Test réel Apple Intelligence, question synthétique « Est-ce qu’un client satisfait est forcément fidèle ? » : réponse en 3,525 s, début « Non, un client satisfait n’est pas forcément fidèle. » ; réponse contextualisée évoquant le prix et la concurrence.
- Après remplacement du contexte vivant par un cours de physique, simplification en 1,015 s toujours sur la fidélité client et préservant la nuance. Ces deux temps ne constituent pas une garantie de latence.
- Revues sécurité et contradictoire : aucun P1/P2 identifié. Un défaut du bouton Lecture après échec manuel a été corrigé en arrêtant la lecture au lancement de la demande.
- La capture 0.14 active a été observée avec compteur avançant et nouvelles paroles reçues. Aucun enregistrement interrompu pendant le développement de 0.15.

## Installation et vérification dans l’application

- Nino Découverte installé en 0.15.0, ancien bundle conservé dans Build/Backups. Signature et égalité avec le bundle Découverte resigné vérifiées.
- Enregistrement de 14:06 sauvegardé : durée affichée 23 min 49. Document À reprendre, audio conservé ; transcription finale annulée pour la mise à jour.
- Autorisation écran/audio existante réinscrite pour le binaire final, interrupteur Découverte activé. Aucun nouvel accès demandé.
- Le clic explicite Lire dans l’encoche donne désormais le focus au lecteur ; les ouvertures automatiques gardent le comportement sans prise de focus.
- Question synthétique saisie dans le lecteur, réponse affichée ; Plus simple produit deux phrases ; Corriger la question préremplit la saisie et la validation remplace la paire question/réponse.
- Application laissée ouverte dans le lecteur avec la question de test. L’écoute est arrêtée et n’a pas été relancée.

## Changement de comportement

Les réponses manuelles sont désormais publiées complètes, après validation des limites, au lieu d’apparaître mot par mot. Pendant la génération, la réponse précédente reste lisible. « Plus simple » et « Corriger la question » reprennent les données associées à cette réponse ; une correction obsolète est refusée en conservant le brouillon.

## Limites

- Les tests intermédiaires ont montré une recopie des consignes puis un premier mot contradictoire. Les formulations concernées ont été retirées ; le dernier exemple passe. Un seul exemple réussi ne démontre pas une amélioration générale de justesse.
- Le modèle peut encore se tromper, ignorer des consignes stylistiques ou simplifier une erreur existante. Aucun mécanisme ne certifie la vérité de la réponse.
- Les nouveaux boutons ont été vérifiés dans le lecteur installé : saisie manuelle, Plus simple, correction préremplie puis génération de la nouvelle réponse. Capture du lecteur 650 × 422 points inspectée : contrôles visibles sans débordement. Aucun nouvel appel réel lancé après mise à jour.
- Les problèmes de renouvellement d’autorisations des builds ad hoc et l’attente de reconnaissance vocale sans délai maximum décrits dans VALIDATION-0.14.md restent ouverts.
- Aucun nouvel accès cloud, aucune publication GitHub, aucun binaire notarié.
