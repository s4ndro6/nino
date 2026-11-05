#!/bin/bash
set -euo pipefail
SPARKLE="${1:?Usage: generate-update-feed.sh SPARKLE_DIRECTORY DMG_DIRECTORY VERSION}"
ARCHIVES="${2:?DMG directory required}"
VERSION="${3:?Version required}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version invalide'; exit 1; }
[[ -x "$SPARKLE/bin/generate_appcast" && -f "$ARCHIVES/Nino-$VERSION-macOS-arm64.dmg" ]] || { echo 'Distribution Sparkle ou DMG manquant'; exit 1; }
# This command uses the previously authorized publisher key in Keychain. It never creates or exports keys.
"$SPARKLE/bin/generate_appcast" --account nino-s4ndro6-updates --maximum-deltas 0 \
  --download-url-prefix "https://github.com/s4ndro6/nino/releases/download/v$VERSION/" \
  --link 'https://nino-companion.vercel.app' "$ARCHIVES"
printf 'Appcast généré : %s/appcast.xml\n' "$ARCHIVES"
