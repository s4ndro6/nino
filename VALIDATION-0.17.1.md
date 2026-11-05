# Validation locale — Nino 0.17.1 (18)

5 novembre 2026. Alpha développeur Apple Silicon, sources MIT. Aucun push ni publication GitHub.

## Ce qui a été livré

- Post-it papier : six couleurs, grain statique, bande adhésive, coin plié, texte sombre. Format de données antérieur conservé.
- Accueil en cinq étapes avec scène Mac, profil, connexions facultatives, choix de confidentialité et première action.
- Promenade : même palette et crête que le personnage d’origine, silhouette de trois quarts, bras et jambes articulés, marche liée à la distance, départ/arrêt progressifs, escalade, regard, réflexion et salut. Deux itinéraires alternent autour de la fenêtre d’accueil et au bas du bureau. Aucun contenu d’application lu ou analysé.
- Compteurs d’usage facultatifs, bornés et sans contenu utilisateur. Pas de collecte avant accord. Retrait et effacement disponibles dans Réglages. Aucun endpoint configuré, aucun envoi automatique.
- Collecteur de référence Python 3.12+/SQLite, écoute limitée à loopback, schéma strict et idempotence. Copie locale préparée sur le disque externe ; base créée vide, résumé `[]`, aucun serveur laissé actif. Base exclue de la source publique.

## Vérifications réalisées

- Build release final : succès en 24,57 s. Signature ad hoc vérifiée, identité de Découverte conservée, binaire installé identique au binaire stagé. Ancienne application sauvegardée avant remplacement ; données conservées.
- Suite publique `test.sh` : code de sortie 0. Treize suites Swift, dix-neuf tests Python MCP et six tests Python du collecteur local. Les tests utilisent des fixtures, des transports simulés ou des requêtes localhost synthétiques uniquement.
- Promenade : continuité aux jonctions et au bouclage, accélération et arrêt, bornes de plusieurs écrans dont coordonnées négatives, fenêtre surdimensionnée, cinq gestes et alternance d’itinéraire.
- Statistiques : aucun événement ni réseau avant accord ou après refus ; persistance, retrait avec callback tardif, invalidation de notice, lot immuable au retry, nouveaux identifiants par lot, purge persistante, limites, validation HTTPS/ACK et refus des symlinks.
- Collecteur : validation stricte, doublons, transactions concurrentes, rétention et protocole HTTP local. Timeouts headers/corps 5 s, limite globale 60 requêtes/min sans suivi d’IP.
- Notes : migration des couleurs, création comptée une fois, sauvegarde, reprise après erreur, limites et symlinks.
- Rendu du personnage : aperçu GIF de 300 images généré avec le composant SwiftUI de production, et image de marche inspectée. Il s’agit d’un aperçu des gestes, pas d’un enregistrement du bureau.
- Interface réelle : papier jaune/abricot, checklist, pliage et fermeture observés pendant le lot. Accueil parcouru jusqu’à la dernière étape, puis retour au début ; navigation sans Google ni choix de statistiques. Le bouton de promenade passe bien désactivé/réactivé. Aucun accord de statistiques donné pour l’utilisateur.
- Deux revues ciblées sécurité/adversarial du stockage et des statistiques ont été réalisées pendant le lot. Les corrections concernent notamment les symlinks, la purge persistante, le retrait/réaccord et les délais HTTP. Cela ne remplace pas un audit indépendant complet.

## Limites explicites

- Le panneau décoratif hors fenêtre n’est pas inclus dans les captures de la fenêtre principale disponibles ici. L’aperçu montre le rendu des gestes ; leur perception sur le bureau réel reste à confirmer par l’utilisateur. 60 Hz est la fréquence demandée au timer, pas une mesure de fluidité matérielle.
- L’accueil large a été contrôlé visuellement. La géométrie de promenade est testée sur des données multiécrans ; pas de recette physique exhaustive multi-Mac/Spaces. La tentative de redimensionnement UI n’a pas donné de changement observé : ne pas considérer la mise en page compacte comme visuellement validée.
- La promenade fonctionne pendant l’accueil au premier plan, en mode Joueur, avec son option active. Elle s’arrête en mode Discret ou Réduire les animations. Le personnage mime l’observation ; il ne reconnaît pas une application et n’interagit pas avec elle.
- Aucun nouveau test réel d’appel, de micro, de Google/Gmail ou de Touch Bar dans ce lot. Les suites synthétiques ne prouvent pas la justesse des réponses d’Apple Intelligence.
- Le collecteur reste local. Aucun hébergement, backend de comptes, suivi de personnes uniques ou tableau de bord public livré. La purge dépend du lancement/de l’activité du client ou du serveur, comme expliqué dans Analytics/README.md.
- Signature Developer ID, notarisation et CI GitHub non réalisées. La signature ad hoc peut entraîner de nouvelles demandes macOS après mise à jour. Les accès microphone, reconnaissance et audio système restent distincts.

## Essayer

Réglages → Personnaliser mon Nino → présence Joueur → La promenade de Nino. L’accueil est laissé ouvert pour essai. Post-it : barre latérale ou encoche. Statistiques : Réglages → Statistiques d’usage et consentement ; tout est encore facultatif et local.
