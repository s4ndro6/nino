# Touch Bar MTMR — 0.7

Un seul personnage animé à24images/s, sans libellé tronqué, remplace les six cases0.6. PNG48×48pixels pour24points logiques : même dessin SwiftUI que l’encoche, visage stable et cadrage resserré. Huit états : repos, appel, écoute, transcription, réflexion, concentration, terminé, erreur.

Ajouter les objets nino-widgets.json au preset MTMR après sauvegarde, sans écraser ses autres boutons. Créer le fichier vide ~/Library/Application Support/MTMR/nino.enabled puis relancer Nino. Toucher le personnage ouvre l’encoche ; Audio ouvre ses commandes ; Texte ouvre la dernière transcription. Aucun contenu de chat ou audio n’est exporté.

Présence Discret : repos immobile et gestes ralentis. Réduire les animations macOS : image fixe. Après modification du preset, relancer MTMR si son surveillant de fichier ne prend pas le changement en compte. Une suppression du marqueur nino.enabled coupe les prochaines écritures de Nino ; le widget repasse au repos lorsque le statut devient périmé.

Génération depuis le dossier du projet :

```sh
xcrun swiftc -swift-version 5 Source/Profile.swift Source/Companion.swift TouchBar/DrawFrames.swift -o /tmp/nino-frames -framework SwiftUI -framework AppKit
/tmp/nino-frames /tmp/nino-retina-frames
```

Le JSON embarque déjà les1024images. tile.applescript est le script utilisé, sans substitution nécessaire.

Validation sur le Mac de développement le5novembre2026 : fluidité confirmée par l’utilisateur, PNG48×48 vérifiés, mesure locale~22% d’un cœur sur10secondes, contre~50% avec six cases. Cela reste plus coûteux qu’un moteur natif et les résultats varient selon le Mac. Les animations représentent l’état local de Nino, pas l’exécution en direct d’un chat Codex.
