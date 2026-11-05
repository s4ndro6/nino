# Nino MCP 0.11

Serveur natif Foundation, sans Python/Node à installer pour l’utilisateur. L’exécutable `Contents/MacOS/nino-mcp` est compilé par `Source/build.sh` et signé dans le bundle.

## Configuration

La page Connexions génère les chemins exacts de l’installation. Exemple illustratif :

```json
{
  "mcpServers": {
    "nino": {
      "command": "/chemin/Nino.app/Contents/MacOS/nino-mcp",
      "args": ["--workspace", "/chemin/Workspace"]
    }
  }
}
```

Ne colle pas cet exemple sans remplacer les chemins. Préfère l’export de Nino. La commande doit pointer sur un exécutable local approuvé. Aucun port réseau n’est ouvert et aucun shell n’est lancé par le serveur.

## Contrat

Transport stdio JSON-RPC, messages JSON séparés par un saut de ligne. Versions initialisation supportées : `2025-11-25` et `2025-06-18`. Le client envoie `initialize`, puis `notifications/initialized`. Pas de prise en charge déclarée des nouvelles versions du protocole sans cette négociation.

- `nino_get_context {}` : retourne la fiche autorisée et les identifiants de projet/session.
- `nino_report_progress {projectID, sessionID, state, message, agent?}` : état parmi `working`, `waiting`, `completed`, `failed`. Message ≤ 500 caractères, nom d’agent ≤ 60. Le serveur ajoute l’heure et l’identifiant de l’événement.
- `resources/read {uri:"nino://current-work"}` : même contexte autorisé.

Les noms d’agent sont déclaratifs, pas une identité authentifiée. Aucun événement ne valide une étape ou une livraison à la place de l’utilisateur. Une activité `working` sans nouveau signal depuis cinq minutes devient « Signal ancien ».

## Accès

Chaque lecture/écriture vérifie le fichier `context.json`, son opt-in, son bail (300 s) et la session sélectionnée. Nino le renouvelle toutes les 60 s pendant le partage actif. Le serveur refuse les symlinks, hardlinks, fichiers non réguliers, gros messages, sessions périmées, champs supplémentaires et chemins arbitraires. Seul `activity.json` peut être écrit. Les permissions POSIX ne constituent pas une isolation garantie sur un disque ExFAT ; ce mécanisme ne protège pas d’un autre processus malveillant du même compte utilisateur.

Une invocation du client peut transmettre le contexte à son fournisseur IA. Nino n’envoie lui-même aucune requête réseau MCP. Le partage ne couvre jamais des contenus de mail, audio, comptes ou dépôt. L’utilisateur doit éviter d’inscrire un secret dans le brief ou les liens.

## Vérification

`bash test.sh` compile et interroge le serveur sur des données synthétiques. Pour vérifier un client réel : importer la configuration, autoriser une fiche de test, lire le contexte, signaler `working` puis `completed`, vérifier Nino, arrêter le partage, vérifier que la lecture est refusée. Ne jamais utiliser de clés réelles dans un test.

Spécification : https://modelcontextprotocol.io/specification/2025-11-25
