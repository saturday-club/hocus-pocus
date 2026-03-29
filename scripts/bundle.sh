#!/bin/zsh
set -euo pipefail

# Build and bundle Hocus Pocus as a macOS .app
cd "$(dirname "$0")/.."

echo "Building Hocus Pocus..."
swift build -c release 2>&1

APP_DIR="build/HocusPocus.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy the binary
cp ".build/release/HocusPocus" "$APP_DIR/MacOS/HocusPocus"

# Copy app icon
if [ -f "Sources/HocusPocus/Resources/AppIcon.icns" ]; then
    cp "Sources/HocusPocus/Resources/AppIcon.icns" "$APP_DIR/Resources/"
fi

# Copy Metal shader resource bundle if it exists
BUNDLE_PATH=$(find .build/release -name "HocusPocus_HocusPocus.bundle" -type d 2>/dev/null | head -1)
if [ -n "$BUNDLE_PATH" ]; then
    cp -R "$BUNDLE_PATH" "$APP_DIR/Resources/"
fi

# Generate Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>club.saturday.hocuspocus</string>
    <key>CFBundleName</key>
    <string>HocusPocus</string>
    <key>CFBundleDisplayName</key>
    <string>Hocus Pocus</string>
    <key>CFBundleExecutable</key>
    <string>HocusPocus</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Hocus Pocus URL Scheme</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>hocus-pocus</string>
            </array>
        </dict>
    </array>
    <key>NSAccessibility</key>
    <true/>
    <key>NSPrefersDisplaySafeAreaCompatibilityMode</key>
    <false/>
</dict>
</plist>
PLIST

# Ad-hoc codesign so macOS remembers accessibility permission across rebuilds
codesign --force --sign - "build/HocusPocus.app"

echo "App bundle created and signed at build/HocusPocus.app"
echo ""
echo "To run:"
echo "  open build/HocusPocus.app"
