#!/bin/zsh
set -euo pipefail
ROOT="${NINO_DATA_DIR:-$HOME/Library/Application Support/Nino}"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/nino-helper.XXXXXX")"
URL='https://github.com/steipete/CodexBar/releases/download/v0.83.0/CodexBarCLI-v0.83.0-macos-arm64.tar.gz'
/usr/bin/curl --fail --location --proto '=https' --tlsv1.2 "$URL" -o "$STAGE/helper.tar.gz"
ACTUAL="$(/usr/bin/shasum -a 256 "$STAGE/helper.tar.gz" | /usr/bin/awk '{print $1}')"
[[ "$ACTUAL" == '3fb6af9582a0b232dc1708e1d8f13985441dbe2e74903791c902d1fa8bb7c4a9' ]] || { print 'Intégrité du téléchargement invalide'; exit 1; }
/usr/bin/tar -xzf "$STAGE/helper.tar.gz" -C "$STAGE"
mkdir -p "$ROOT/Helpers"
for NAME in CodexBarCLI CodexBar_CodexBarCore.bundle THIRD_PARTY_NOTICES; do
 /usr/bin/ditto --norsrc --noextattr "$STAGE/$NAME" "$ROOT/Helpers/$NAME"
done
print 'Connecteur Claude installé dans Helpers. Aucune installation globale.'
