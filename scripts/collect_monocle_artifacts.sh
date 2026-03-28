#!/bin/zsh
set -euo pipefail

APP="/Applications/Monocle.app"
OUT_DIR="${1:-./artifacts/monocle-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT_DIR"

echo "Collecting Monocle artifacts into $OUT_DIR"

plutil -p "$APP/Contents/Info.plist" > "$OUT_DIR/info-plist.txt"
codesign -d --entitlements :- "$APP" > "$OUT_DIR/entitlements.plist" 2>&1 || true
otool -L "$APP/Contents/MacOS/Monocle" > "$OUT_DIR/linked-frameworks.txt"
otool -ov "$APP/Contents/MacOS/Monocle" > "$OUT_DIR/objc-metadata.txt"
strings -a "$APP/Contents/MacOS/Monocle" > "$OUT_DIR/strings.txt"
strings -a "$APP/Contents/Resources/default.metallib" > "$OUT_DIR/metallib-strings.txt"

if [ -d "$HOME/Library/Containers/dk.heyiam.monocle/Data/Library/Preferences" ]; then
  cp -R "$HOME/Library/Containers/dk.heyiam.monocle/Data/Library/Preferences" "$OUT_DIR/preferences"
fi

echo "Done."
