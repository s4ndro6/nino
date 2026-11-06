# Intelligence et connexions

## Trois moteurs pour l’assistant

1. **Apple Intelligence** : choisi par défaut, local, nécessite macOS 26 et la disponibilité du modèle Apple. Aucun compte API.
2. **OpenAI** : clé personnelle OpenAI Platform, endpoint Responses. Le texte visible de l’assistant est envoyé à OpenAI au clic « Envoyer à OpenAI ». `store=false` pour les réponses ; les règles de conservation du fournisseur s’appliquent malgré cela.
3. **Claude** : clé personnelle Claude Console, endpoint Messages. Le texte visible est envoyé à Anthropic au clic « Envoyer à Claude ».

Les appels, audio, documents, mails et comptes Google ne sont jamais joints automatiquement à ces demandes. L’assistant n’exécute aucun outil ni commande. Le résumé local des documents et les suggestions automatiques d’appel continuent à utiliser Apple Intelligence. Aucun basculement automatique vers une API en cas d’échec local.

## Ajouter une clé

Connexions → Une IA pour tes brouillons → choisir OpenAI ou Claude → coller une clé dans le champ masqué → Enregistrer → Vérifier la clé et charger les modèles → choisir un modèle de génération de texte.

La liste OpenAI est filtrée sur les familles de texte courantes ; le fournisseur peut retourner seulement une page ou des modèles incompatibles avec l’endpoint. Saisir un identifiant manuellement reste possible. La vérification charge les modèles sans générer de réponse ni confirmer le crédit disponible. Seule une demande de génération confirme que le modèle et la facturation fonctionnent ensemble.

La facturation API est distincte des abonnements ChatGPT/Claude. Nino n’inclut ni compte, ni crédits. La clé est dans une entrée dédiée du Trousseau macOS classique, sans synchronisation demandée, avec son contrôle d’accès natif. Elle n’entre ni dans les préférences, ni dans la bibliothèque, ni dans les exports ou les logs. Une mise à jour ad hoc peut faire redemander l’accès par macOS.

Retirer une clé dans Nino efface seulement son entrée locale ; la révocation définitive se fait chez le fournisseur. Pendant une requête, les réglages sont bloqués. Annuler interrompt l’attente et le résultat n’est pas appliqué ; le fournisseur peut avoir déjà commencé une génération facturable. Nino ne réessaie pas automatiquement.

## Abonnements et outils officiels

Les boutons **Connecter ChatGPT via Codex** et **Connecter Claude Code** ouvrent `codex login` ou `claude auth login` dans l’outil officiel installé, puis son navigateur. Les identifiants restent gérés par ces outils ; Nino ne lit pas leurs mots de passe. Sans l’outil, le guide d’installation officiel s’ouvre.

Ces connexions servent au tableau de suivi. Elles ne connectent pas l’API du chatbot Nino et ne remplacent pas une clé. La connexion web Claude.ai n’est pas proposée comme OAuth générique pour les utilisateurs de Nino. L’assistant embarqué utilise les API documentées.

## Transformer une transcription en prochaines actions

Ouvrir un document → Résumé → Préparer un résumé avec mon IA. Nino place le texte dans l’assistant ; si un brief existe déjà, il propose de le garder ou de le remplacer. Relire le texte et le fournisseur avant envoi. Limite : 12 000 caractères, sans troncature silencieuse. Pour un long appel, préparer plusieurs passages. Le bouton Créer un post-it conserve ensuite le brouillon sur le bureau. Il reste à relire : aucune décision ni action n’est exécutée automatiquement.

## Inspiration Coucou

Le projet [Coucou](https://github.com/Louis-CFM/coucou) propose notamment dictée locale, notes de réunions, clés API, suivi d’agents et accès rapides depuis l’encoche. Nino reprend ici l’idée de relier transcription → brouillon → actions visibles. Cette implémentation est indépendante : aucun code, personnage, nom ni son de Coucou n’a été copié. Son code et ses assets ont des régimes de licence distincts.

## Sources officielles consultées

- https://developers.openai.com/codex/auth/
- https://developers.openai.com/api/reference/resources/responses/methods/create
- https://platform.claude.com/docs/en/api/messages/create
- https://platform.claude.com/docs/en/api/overview
- https://support.claude.com/en/articles/13189465-log-in-to-your-claude-account
- https://developer.apple.com/documentation/security/ksecattraccessible

Les modalités fournisseur peuvent évoluer ; vérifier ces références avant d’ajouter un nouveau mode d’authentification.
