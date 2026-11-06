# Dépendances

- CodexBarCLI 0.83.0 : https://github.com/steipete/CodexBar — projet MIT ; binaire optionnel téléchargé séparément. Ses notices de dépendances sont conservées dans `Helpers/THIRD_PARTY_NOTICES` par l’installateur. SHA-256 archive arm64 : `3fb6af9582a0b232dc1708e1d8f13985441dbe2e74903791c902d1fa8bb7c4a9`.
- Codex CLI : https://github.com/openai/codex — installé séparément par l’utilisateur.
- Claude Code : logiciel Anthropic installé séparément ; ses conditions et celles de l’abonnement s’appliquent.
- Whisper.cpp : https://github.com/ggml-org/whisper.cpp — MIT, moteur 1.9.5 compilé statiquement et inclus dans l’app ; modèles facultatifs téléchargés séparément.
- Conversion audio : AVFoundation, fourni par macOS. FFmpeg n’est plus nécessaire pour la transcription.
- Modèles Whisper GGML : https://huggingface.co/ggerganov/whisper.cpp — MIT, révision et SHA-256 épinglés ; téléchargement explicite depuis Nino.
- Frameworks Apple : fournis par macOS et le SDK Apple, non redistribués.

Aucun média Koi, identifiant de compte, donnée personnelle ou modèle de transcription n’est inclus dans les sources.


## Connexion Google (0.12)

AppAuth-iOS 2.1.0 (OpenID Foundation), Apache-2.0 : https://github.com/openid/AppAuth-iOS/tree/2.1.0. Le verrou SwiftPM est dans `Source/Package.resolved`. Licence dans `ThirdPartyLicenses/AppAuth-iOS-LICENSE`. Les autres notices Google conservées dans ce dossier concernent les anciennes versions et ne représentent pas les dépendances actuelles.

## Inspiration fonctionnelle — Coucou (0.20)

[Coucou](https://github.com/Louis-CFM/coucou), © 2026 Louis Raillé, propose notamment les alertes de mise à jour et la visibilité des agents depuis l’encoche. Ces usages ont inspiré les modules Nino 0.20 ; leur implémentation est indépendante et réutilise les signaux MCP propres à Nino.

Le [code de Coucou est MIT](https://github.com/Louis-CFM/coucou/blob/main/LICENSE). Sa [licence d’assets distincte](https://github.com/Louis-CFM/coucou/blob/main/LICENSE-ASSETS.md) réserve le nom, Mochi, les visuels, les animations du personnage et les sons. Aucun de ces assets ni code source de Coucou n’est incorporé à Nino. Nino n’est pas affilié à Coucou.
