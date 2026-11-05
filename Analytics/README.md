# Compteurs d’usage Nino — préparation locale

Ce dossier est un **serveur de référence local**, pas un service déployé. L’application Nino livrée n’a aucun endpoint de mesure : même après un « oui », elle ne peut rien transmettre. Aucun compte Google, identifiant de Mac, contenu ou historique utilisateur n’alimente cette base.

## Ce qui fonctionne

- Choix explicite `undecided`, `declined` ou `accepted`, enregistré avec la version de la notice et le jour UTC. Aucune collecte avant accord ; refus sans perte de fonctionnalités.
- Compteurs journaliers d’événements prédéfinis : version majeure, événement, nombre. Les événements incluent des échecs techniques, jamais leur message ni un code libre.
- File locale atomique et bornée : 256 compteurs en attente, lots de 128 maximum, 1 000 occurrences maximum par compteur, fichier de 64 Kio maximum.
- Envoi uniquement à la demande avec une configuration éditeur HTTPS explicite. Aucun envoi automatique, aucune collecte rétroactive avant consentement.
- Retrait : collecte arrêtée, envoi en cours annulé, file locale effacée. Un lot déjà envoyé peut avoir été reçu. Les agrégats sans identité ne permettent pas de rechercher puis retirer la contribution d’une personne.
- Reprise idempotente : UUID aléatoire **par lot**, conservé lors d’un retry ; aucune identité stable. Le serveur refuse la réutilisation d’un UUID avec un autre contenu.
- SQLite : agrégats + empreintes des lots pour déduplication. Ni IP, ni headers, ni payload complet ne sont journalisés ou conservés. Pas de tableau de bord public.

La mesure compte des **utilisations**, pas des utilisateurs uniques. Un consentement déclaré dans un lot n’est pas une preuve d’identité du déclarant. Ce prototype ne prétend pas être certifié conforme au RGPD.

## Essayer avec des données synthétiques

Python **3.12 ou supérieur**, bibliothèque standard uniquement. Aucune dépendance globale à installer.

```sh
cd Analytics
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v
python3 server.py serve --db ./local-data/usage.sqlite3
# Dans un autre terminal :
python3 server.py summary --db ./local-data/usage.sqlite3
```

Le serveur écoute exclusivement `127.0.0.1:8769`. Les tests ouvrent un port loopback éphémère, envoient uniquement une fixture inventée et arrêtent le serveur. Le test Swift utilise un transport simulé : il n’envoie rien sur Internet. L’app refuse intentionnellement une URL HTTP loopback ; aucun mode de contournement TLS n’a été ajouté.

La base est créée au premier `serve` ou `summary`. Le résumé affiche uniquement les agrégats. Les données réelles, bases SQLite et éventuels fichiers de configuration privés doivent rester **hors du dépôt et de l’archive GitHub**. `publisher-endpoint.example.json` est un exemple inactif ; le code n’en lit pas automatiquement la valeur.

## Contrat et protections

`POST /v1/usage`, JSON strict décrit dans `schema.json`. Champs inconnus, doublons de clés, événements inconnus, doublons de compteurs, dates futures, compteurs précédant le consentement et lots trop anciens sont refusés. Taille maximale : 65 536 octets. Réponse stricte : `schema_version`, `batch_id`, `accepted_count`, `duplicate`. Un succès signifie seulement que ce lot a été agrégé.

Le client bloque redirections, cookies et authentification HTTP, limite les délais et la réponse à 4 Kio. Il ne joint ni token Google ni identifiant de session. Le serveur local limite globalement les requêtes à 60/minute **sans conserver d’adresse IP** et impose un timeout de 5 secondes, y compris sur les headers. Ces limites ne constituent pas une protection suffisante pour un service public.

## Durées de conservation réelles

- Client : purge des compteurs vieux de plus de 30 jours **au lancement ou à une action de mesure/envoi**. Une application fermée ne nettoie pas son disque en arrière-plan.
- Serveur : agrégats et déduplication conservés au maximum 90 jours, purgés au démarrage et une fois par jour tant que le processus fonctionne ; les commandes de résumé/réception déclenchent également le nettoyage. Serveur arrêté : purge au redémarrage.
- Le choix local de confidentialité est conservé pour respecter le refus lors des prochains lancements. Une version de notice différente remet le choix à indécis et purge l’ancienne file.

## Avant une éventuelle publication d’un vrai service

Cette étape **n’est pas faite ici**. Il faut définir un éditeur, un contact, une notice accessible, le destinataire et la finalité ; afficher ces informations avant l’accord. Un changement de finalité ou de destinataire doit faire revalider le consentement via une nouvelle version de notice. Les conditions d’utilisation et les permissions du microphone restent distinctes de ce choix.

Prévoir un reverse proxy TLS, des limites de charge, des contrôles d’accès pour l’administration, une politique de logs et de sauvegardes cohérente avec les durées annoncées, puis une revue juridique et sécurité adaptée. Configurer l’endpoint éditeur dans l’application seulement après cette étape. Ne jamais publier une base, des tokens, une adresse privée de collecte ou une configuration réelle dans le paquet open source.
