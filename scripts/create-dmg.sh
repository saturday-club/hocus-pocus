#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Hocus Pocus"
DMG_NAME="HocusPocus-0.1.0"
APP_PATH="build/AutoFocus.app"
DMG_DIR="build/dmg"
DMG_PATH="build/${DMG_NAME}.dmg"

# Ensure the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "App not found at $APP_PATH. Run ./scripts/bundle.sh first."
    exit 1
fi

echo "Creating DMG..."

# Clean previous
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"

# Copy app to staging
cp -R "$APP_PATH" "$DMG_DIR/"

# Create symlink to /Applications for drag-to-install
ln -s /Applications "$DMG_DIR/Applications"

# Create the DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean staging
rm -rf "$DMG_DIR"

echo ""
echo "DMG created: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
