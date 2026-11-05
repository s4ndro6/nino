# Dépendances

- CodexBarCLI 0.83.0 : https://github.com/steipete/CodexBar — projet MIT ; binaire optionnel téléchargé séparément. Ses notices de dépendances sont conservées dans `Helpers/THIRD_PARTY_NOTICES` par l’installateur. SHA-256 archive arm64 : `3fb6af9582a0b232dc1708e1d8f13985441dbe2e74903791c902d1fa8bb7c4a9`.
- Codex CLI : https://github.com/openai/codex — installé séparément par l’utilisateur.
- Claude Code : logiciel Anthropic installé séparément ; ses conditions et celles de l’abonnement s’appliquent.
- Whisper.cpp : https://github.com/ggml-org/whisper.cpp — MIT, non inclus.
- FFmpeg : https://ffmpeg.org — licence dépendante de la compilation (LGPL/GPL), non inclus.
- Frameworks Apple : fournis par macOS et le SDK Apple, non redistribués.

Aucun média Koi, identifiant de compte, donnée personnelle ou modèle de transcription n’est inclus dans les sources.


## Connexion Google (0.12)

AppAuth-iOS 2.1.0 (OpenID Foundation), Apache-2.0 : https://github.com/openid/AppAuth-iOS/tree/2.1.0. Le verrou SwiftPM est dans `Source/Package.resolved`. Licence dans `ThirdPartyLicenses/AppAuth-iOS-LICENSE`. Les autres notices Google conservées dans ce dossier concernent les anciennes versions et ne représentent pas les dépendances actuelles.
