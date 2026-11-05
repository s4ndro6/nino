#!/bin/zsh
set -euo pipefail
PROJECT_ROOT="${0:A:h:h}"
SOURCE_ROOT="$PROJECT_ROOT/Source"
BUILD_ROOT="${NINO_BUILD_ROOT:-$PROJECT_ROOT/Build}"
mkdir -p "$BUILD_ROOT"
BUILD_ROOT="$(cd "$BUILD_ROOT" && pwd -P)"
STAGING_ROOT="$(mktemp -d "${TMPDIR%/}/nino-build.XXXXXX")"
APP_ROOT="$STAGING_ROOT/Nino.app"
mkdir -p "$BUILD_ROOT/SPM" "$BUILD_ROOT/Cache" "$APP_ROOT/Contents/MacOS" "$APP_ROOT/Contents/Resources"
export COPYFILE_DISABLE=1
# Keep this identity and the bundle identifier stable across updates.
SIGNING_IDENTITY="${NINO_SIGNING_IDENTITY:--}"
SIGNING_FLAGS=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    SIGNING_FLAGS+=(--options runtime --timestamp)
fi
APP_SIGNING_FLAGS=("${SIGNING_FLAGS[@]}")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    APP_SIGNING_FLAGS+=(--entitlements "$SOURCE_ROOT/Nino.entitlements")
fi
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/Cache/Clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/Cache/SwiftPM"
export SWIFT_MODULE_CACHE_PATH="$BUILD_ROOT/Cache/Swift"
# Dependencies are pinned in Package.swift; all build/cache data stays beside the project.
SPM_FLAGS=(--package-path "$SOURCE_ROOT" --scratch-path "$BUILD_ROOT/SPM" --cache-path "$BUILD_ROOT/Cache" --config-path "$BUILD_ROOT/Config" --security-path "$BUILD_ROOT/Security" --disable-sandbox -c release)
swift package --package-path "$SOURCE_ROOT" --scratch-path "$BUILD_ROOT/SPM" --cache-path "$BUILD_ROOT/Cache" --config-path "$BUILD_ROOT/Config" --security-path "$BUILD_ROOT/Security" --disable-sandbox resolve
# ExFAT AppleDouble metadata can otherwise be mistaken for C headers by Clang.
python3 - "$BUILD_ROOT/SPM/checkouts" <<'PYCODE'
from pathlib import Path
import sys
for path in Path(sys.argv[1]).rglob('._*'):
    if path.is_file(): path.unlink()
PYCODE
swift build "${SPM_FLAGS[@]}"
BINARY_ROOT="$(swift build "${SPM_FLAGS[@]}" --show-bin-path)"
cp -X "$BINARY_ROOT/Nino" "$APP_ROOT/Contents/MacOS/Nino"
/usr/bin/strip -S "$APP_ROOT/Contents/MacOS/Nino"
# Native MCP helper: Foundation only, no Python/Node runtime needed for users.
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macosx15.0 -module-cache-path "$BUILD_ROOT/Cache/Swift" "$PROJECT_ROOT/MCP/Server.swift" -o "$APP_ROOT/Contents/MacOS/nino-mcp"
codesign "${SIGNING_FLAGS[@]}" "$APP_ROOT/Contents/MacOS/nino-mcp"
cp -X "$SOURCE_ROOT/Info.plist" "$APP_ROOT/Contents/Info.plist"
cp -X "$SOURCE_ROOT/Nino.icns" "$APP_ROOT/Contents/Resources/Nino.icns"
# Ship license notices with every binary, including clean DMG installations.
mkdir -p "$APP_ROOT/Contents/Resources/Licenses"
cp -X "$PROJECT_ROOT/LICENSE" "$APP_ROOT/Contents/Resources/Licenses/Nino-MIT.txt"
ditto --norsrc --noextattr --noacl "$PROJECT_ROOT/ThirdPartyLicenses" "$APP_ROOT/Contents/Resources/Licenses/ThirdParty"
# Publisher configuration is kept outside the public source tree. No user token is bundled.
GOOGLE_CONFIG="${NINO_GOOGLE_CONFIG:-$PROJECT_ROOT/Configuration/GoogleDesktopOAuth.plist}"
if [[ "${NINO_PUBLIC_BUILD:-0}" != "1" && -f "$GOOGLE_CONFIG" ]]; then
    python3 - "$GOOGLE_CONFIG" "$APP_ROOT/Contents/Resources/GoogleDesktopOAuth.plist" <<'PY'
import plistlib, sys
from pathlib import Path
data=plistlib.loads(Path(sys.argv[1]).read_bytes())
client=data.get('client_id','')
if not isinstance(client,str) or not client.endswith('.apps.googleusercontent.com') or len(client)>256 or any(c.isspace() for c in client):
    raise SystemExit('Invalid desktop OAuth client configuration')
result={'client_id':client}
if data.get('client_secret'):
    secret=data['client_secret']
    if not isinstance(secret,str) or len(secret)>256: raise SystemExit('Invalid desktop OAuth client configuration')
    result['client_secret']=secret
Path(sys.argv[2]).write_bytes(plistlib.dumps(result))
PY
fi
# SPM accessors first resolve Bundle.main.resourceURL (Contents/Resources).
for resource in "$BINARY_ROOT"/AppAuth_*.bundle(N); do
    ditto --norsrc --noextattr --noacl "$resource" "$APP_ROOT/Contents/Resources/${resource:t}"
done
python3 - "$APP_ROOT" <<'PYCODE'
from pathlib import Path
import sys
for path in Path(sys.argv[1]).rglob('._*'):
    if path.is_file(): path.unlink()
PYCODE
# Local alpha signature. A public binary still needs Developer ID + notarization.
codesign "${APP_SIGNING_FLAGS[@]}" "$APP_ROOT"
# Replace the bundle instead of merging: a clean build must remove stale OAuth/resources.
NEXT_ROOT="$(mktemp -d "$BUILD_ROOT/package.XXXXXX")"
ditto --norsrc --noextattr --noacl "$APP_ROOT" "$NEXT_ROOT/Nino.app"
python3 - "$NEXT_ROOT/Nino.app" <<'PYCODE'
from pathlib import Path
import sys
for path in Path(sys.argv[1]).rglob('._*'):
    if path.is_file(): path.unlink()
PYCODE
codesign --verify --deep --strict "$NEXT_ROOT/Nino.app"
PREVIOUS_APP=""
if [[ -e "$PROJECT_ROOT/Nino.app" ]]; then
    mkdir -p "$BUILD_ROOT/Previous"
    PREVIOUS_APP="$BUILD_ROOT/Previous/Nino-$(uuidgen).app"
    mv "$PROJECT_ROOT/Nino.app" "$PREVIOUS_APP"
fi
if ! mv "$NEXT_ROOT/Nino.app" "$PROJECT_ROOT/Nino.app"; then
    if [[ -n "$PREVIOUS_APP" ]]; then mv "$PREVIOUS_APP" "$PROJECT_ROOT/Nino.app"; fi
    exit 1
fi
codesign --verify --deep --strict "$PROJECT_ROOT/Nino.app"
