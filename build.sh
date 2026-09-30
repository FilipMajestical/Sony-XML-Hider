#!/bin/bash
set -euo pipefail

APP_NAME="Sony XML Hider"
VERSION="1.0.1"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
MACOS="$APP/Contents/MacOS"

rm -rf "$BUILD"
mkdir -p "$MACOS"

xcrun swiftc \
  "$ROOT/Sources/main.swift" \
  -O \
  -framework AppKit \
  -o "$MACOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.majestical.sonyxmlhider</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signing: this does NOT make the app trusted/notarized, but keeps the bundle internally signed.
codesign --force --deep --sign - "$APP"

cd "$BUILD"
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "Sony_XML_Hider_macOS_v$VERSION.zip"

echo "Built: $BUILD/Sony_XML_Hider_macOS_v$VERSION.zip"
