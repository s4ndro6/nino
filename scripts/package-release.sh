#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Nino.app"
DEST="${1:?Usage: bash scripts/package-release.sh OUTPUT_DIRECTORY}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Version invalide'; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")" == 'app.sandro.nino' ]] || { echo 'Identité incorrecte'; exit 1; }
[[ ! -e "$APP/Contents/Resources/GoogleDesktopOAuth.plist" ]] || { echo 'Configuration privée : reconstruire avec NINO_PUBLIC_BUILD=1'; exit 1; }
python3 "$ROOT/scripts/verify-update-config.py" "$APP/Contents/Info.plist"
codesign --verify --deep --strict "$APP"
mkdir -p "$DEST"
IMAGE="$DEST/Nino-$VERSION-macOS-arm64.dmg"
[[ ! -e "$IMAGE" ]] || { echo "Le fichier existe déjà : $IMAGE"; exit 1; }
STAGE=$(mktemp -d "${TMPDIR%/}/nino-release.XXXXXX")
export COPYFILE_DISABLE=1
ditto --norsrc --noextattr --noacl "$APP" "$STAGE/Nino.app"
ln -s /Applications "$STAGE/Applications"
printf 'Nino %s — alpha publique\n\n' "$VERSION" > "$STAGE/LIRE-MOI.txt"
cat "$ROOT/docs/PREMIER-LANCEMENT.txt" >> "$STAGE/LIRE-MOI.txt"
python3 "$ROOT/scripts/normalize-release-permissions.py" "$STAGE"
codesign --verify --deep --strict "$STAGE/Nino.app"
hdiutil create -volname "Nino $VERSION" -srcfolder "$STAGE" -format UDZO -fs HFS+ "$IMAGE"
(cd "$DEST" && shasum -a 256 "Nino-$VERSION-macOS-arm64.dmg" > SHA256SUMS.txt)
printf 'DMG : %s\nDossier temporaire conservé : %s\n' "$IMAGE" "$STAGE"
