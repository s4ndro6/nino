#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Nino.app"
DEST="${1:?Usage: bash scripts/package-release.sh OUTPUT_DIRECTORY}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version invalide'; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")" == 'app.sandro.nino' ]] || { echo 'Identité incorrecte'; exit 1; }
[[ ! -e "$APP/Contents/Resources/GoogleDesktopOAuth.plist" ]] || { echo 'Configuration privée : reconstruire avec NINO_PUBLIC_BUILD=1'; exit 1; }
codesign --verify --deep --strict "$APP"
mkdir -p "$DEST"
IMAGE="$DEST/Nino-$VERSION-macOS-arm64.dmg"
[[ ! -e "$IMAGE" ]] || { echo "Le fichier existe déjà : $IMAGE"; exit 1; }
STAGE=$(mktemp -d "${TMPDIR%/}/nino-release.XXXXXX")
export COPYFILE_DISABLE=1
ditto --norsrc --noextattr --noacl "$APP" "$STAGE/Nino.app"
ln -s /Applications "$STAGE/Applications"
printf 'Nino %s — alpha publique\n\nGlisse Nino dans Applications puis ouvre-le.\nCette alpha ne dispose pas de notarisation Apple.\nSi Apple indique ne pas pouvoir verifier Nino, consulte le guide officiel : https://support.apple.com/fr-fr/102445\nNe desactive pas les protections macOS.\nGuide : https://github.com/s4ndro6/nino#en-trois-gestes\nMises à jour : Réglages → Mises à jour (facultatif).\n' "$VERSION" > "$STAGE/LIRE-MOI.txt"
python3 "$ROOT/scripts/normalize-release-permissions.py" "$STAGE"
codesign --verify --deep --strict "$STAGE/Nino.app"
hdiutil create -volname "Nino $VERSION" -srcfolder "$STAGE" -format UDZO -fs HFS+ "$IMAGE"
(cd "$DEST" && shasum -a 256 "Nino-$VERSION-macOS-arm64.dmg" > SHA256SUMS.txt)
printf 'DMG : %s\nDossier temporaire conservé : %s\n' "$IMAGE" "$STAGE"
