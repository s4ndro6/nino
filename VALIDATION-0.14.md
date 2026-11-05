# Validation 0.14 — 5 novembre 2026

## Vérifié

- Compilation SwiftPM finale et signature ad hoc réussies.
- Suite publique réussie : Workspace, Git, 19 tests MCP, profils, configuration Google hors ligne et questions de cours.
- Question synthétique complète sur l’après-achat : analyse locale et réponse contextualisée en 5,318 s hors stabilisation (1,4–2 s). Contexte, reformulation et réponse cohérents dans ce cas.
- Fragments synthétiques « est-ce que si… SAV là » et « .com… pas » : rejetés avant le modèle par filtre syntaxique ; ancienne paire question/réponse préservée. Variantes génériques testées (fin de phrase suspendue, condition complète, ponctuation artificielle).
- La génération automatique publie ensemble question reformulée, réponse et heure. La génération manuelle reste progressive, non filtrée.
- Revues sécurité/contradictoire : ancien résultat invalidé par candidat plus récent, arrêt/mode/manuelle invalident les tâches ; correction de la réanalyse en boucle d’un candidat actif pendant une génération lente.
- Lecteur 0.13 vu dans l’encoche en conditions réelles. Version 0.14 installée avec fond noir à 72 % d’opacité et respect de Réduire la transparence ; nouveau rendu transparent non vérifié par capture compositée de l’écran.
- Documents des deux premières parties du cours conservés (première : 9 min 32, seconde : environ 15 min 25). Leur transcription finale a été annulée pour permettre les mises à jour et reste À reprendre.
- Capture réelle redémarrée en 0.14 après actualisation des permissions écran et reconnaissance vocale. Compteur d’enregistrement observé. Aucun nouveau texte pendant le dernier contrôle ; l’utilisateur a confirmé que le cours était silencieux/en pause.

## Limites connues

- Le modèle seul a accepté les trois questions testées, y compris les fragments, et leur a inventé un sens. Le schéma structuré ne garantit donc ni complétude ni vérité. Le filtre déterministe améliore les cas couverts mais peut manquer de vraies questions ; les réponses restent à vérifier.
- Le filtre n’identifie pas les locuteurs et ne garantit pas la distinction entre question adressée à l’utilisateur et question rhétorique du professeur.
- Pas de validation générale de justesse ni de latence garantie. Une question détectée pendant la nouvelle capture reste à tester après la pause du cours.
- Les signatures ad hoc rendent les mises à jour pendant un appel perturbantes : permissions écran à réinscrire, reconnaissance vocale à actualiser. La tentative de 14:01 est restée bloquée en préparation ; l’utilisateur a fermé Nino et la capture suivante a démarré. Les interruptions n’ont pas été enregistrées. L’attente d’autorisation vocale sans délai maximum est un défaut de robustesse restant à corriger avant distribution.
- Pas de binaire notarié, pas de publication GitHub, pas de certification des intégrations tierces.

Les sources excluent les comptes, la configuration OAuth privée, modèles et enregistrements. Les autres limites de 0.12 restent applicables.
