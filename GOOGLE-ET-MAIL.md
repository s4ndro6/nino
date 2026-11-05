# Google et Gmail — 0.12

Nino utilise AppAuth 2.1.0 avec un client OAuth **application de bureau**, un retour HTTP local sur une adresse de boucle locale et un port aléatoire, PKCE S256, state et nonce. Le navigateur système affiche les pages Google. Aucun serveur de comptes Nino n’est créé.

## Configuration éditeur

L’éditeur configure une fois son projet Google Cloud, le consentement et le client de bureau. L’utilisateur final clique sur Continuer avec Google ; il n’a pas à ouvrir Google Cloud.

Placer la configuration éditeur hors des sources publiques dans `Configuration/GoogleDesktopOAuth.plist` (dictionnaire `client_id`, et `client_secret` si fourni pour ce client de bureau). `Source/build.sh` copie seulement ces champs dans les ressources de l’application. Le chemin peut être fourni par `NINO_GOOGLE_CONFIG`. Ne jamais ajouter de jeton utilisateur à ce fichier. La configuration du client de bureau ne doit pas être utilisée comme secret d’un backend.

Aucun certificat Apple n’est nécessaire au transport OAuth local de cette version. Une distribution grand public nécessite néanmoins signature Developer ID et notarisation, ainsi que les vérifications Google applicables. Le projet local reste en mode test ; le fonctionnement avec le compte propriétaire ne prouve pas l’accès pour tous les utilisateurs.

## Comportement

- La connexion initiale demande uniquement `openid email profile`.
- Session OAuth conservée dans le Trousseau, isolée par bundle et client. Initialisation sans lecture du Trousseau ; reprise explicite par **Reprendre ma connexion**.
- Délai de connexion limité à 180 secondes et annulation possible. Les réponses tardives d’une ancienne tentative sont ignorées.
- Déconnexion locale et révocation Google sont deux actions différentes. Une révocation déjà envoyée ne peut pas être annulée.
- Gmail a son propre consentement et doit utiliser le même compte. Activer Gmail API côté éditeur, configurer les testeurs/scopes et suivre les exigences Google avant distribution.
- Le scope Gmail en lecture donne accès à la boîte ; le code Nino charge uniquement cinq aperçus de la boîte de réception, sur demande. Aucun envoi, suppression, pièce jointe ni lecture automatique par l’assistant.
- Les droits actualisés sont contrôlés après renouvellement du jeton, y compris si Google omet `scope` dans sa réponse ou réduit les droits.
- Endpoints HTTPS fixes pour les API ; pas de redirection avec jeton vers un autre hôte. Erreurs sans jetons ni réponse serveur brute.

## Vérification

La connexion réelle au compte personnel a réussi dans Nino Découverte 0.12 : identité visible, Gmail toujours déconnecté. La reprise explicite depuis le Trousseau a aussi réussi après mise à jour et redémarrage. Gmail reste à valider en conditions réelles.

`bash test.sh` exécute les contrôles hors ligne de configuration, identité vérifiée, erreur nettoyée et absence de faux compte. La même fixture `Tests/GoogleConnectorTests.swift`, compilée avec AppAuth, contrôle aussi PKCE/state/nonce et la conservation/réduction des scopes après renouvellement. Ces tests liés au SDK ont réussi pendant le développement ; ils ne sont pas intégrés à la suite hors ligne par défaut.

Documentation officielle : https://developers.google.com/identity/protocols/oauth2/native-app et https://developers.google.com/workspace/gmail/api/auth/scopes.
