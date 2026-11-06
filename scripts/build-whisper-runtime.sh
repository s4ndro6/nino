#!/bin/bash
set -euo pipefail
# Build-time tools only. End users need neither Homebrew, CMake nor Python.
RUNTIME_ROOT="${1:?Usage: build-whisper-runtime.sh build-directory}"
mkdir -p "$RUNTIME_ROOT"
VERSION=1.9.5
ARCHIVE="$RUNTIME_ROOT/whisper-v$VERSION.tar.gz"

CMAKE="${NINO_CMAKE:-cmake}"
EXPECTED=ff1a9053feb509ff9d7729703355541ae9690073a6b1c40eb692c962e0dc1720
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --proto '=https' --proto-redir '=https' --retry 2 \
    "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$VERSION.tar.gz" -o "$ARCHIVE.partial"
  mv "$ARCHIVE.partial" "$ARCHIVE"
fi
[[ "$(shasum -a 256 "$ARCHIVE" | cut -d ' ' -f 1)" == "$EXPECTED" ]] || { echo 'Whisper source checksum mismatch' >&2; exit 1; }
# Never trust an old extracted source/build cache: compile only this verified archive.
FRESH=$(mktemp -d "$RUNTIME_ROOT/verified.XXXXXX")
COPYFILE_DISABLE=1 tar -xzf "$ARCHIVE" -C "$FRESH"
SOURCE="$FRESH/whisper.cpp-$VERSION"
COMPILE="$FRESH/build"
"$CMAKE" -S "$SOURCE" -B "$COMPILE" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DBUILD_SHARED_LIBS=OFF -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF \
  -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_CCACHE=OFF \
  -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF
"$CMAKE" --build "$COMPILE" --target whisper-cli -j 4
BIN="$COMPILE/bin/whisper-cli"
# Fail closed if a maintainer accidentally ships a developer-machine dependency.
otool -L "$BIN" | tail -n +2 | awk '{print $1}' | while read -r library; do
  case "$library" in /System/Library/*|/usr/lib/*) ;; *) echo "Nonportable runtime dependency: $library" >&2; exit 1;; esac
done

mkdir -p "$RUNTIME_ROOT/static-build/bin"
cp "$BIN" "$RUNTIME_ROOT/static-build/bin/whisper-cli"
cp "$SOURCE/LICENSE" "$RUNTIME_ROOT/WHISPER-LICENSE"
