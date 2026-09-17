#!/bin/bash
set -e

APP_NAME="Glide"
PROJECT_NAME="Glide.xcodeproj"
SCHEME="Glide"
BUILD_DIR="build"

echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Building $APP_NAME..."
xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME" -configuration Release -derivedDataPath "$BUILD_DIR/DerivedData" build > /dev/null

APP_BUNDLE=$(find "$BUILD_DIR/DerivedData/Build/Products/Release" -name "$APP_NAME.app" -type d)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Failed to find built .app!"
    exit 1
fi

echo "📦 Found app at $APP_BUNDLE"

# IMPORTANT: Fix the daemon's code signature identifier AND sign with a valid Apple Developer identity.
# SMAppService requires the app and the daemon to have the exact same Developer Team ID.
# Ad-hoc signing (-) lacks a Team ID and macOS will silently refuse to start the daemon.
SIGN_IDENTITY="EA7232703AB7C8D9D5AB19476F4C96C3A56212BD"

DAEMON_PATH="$APP_BUNDLE/Contents/MacOS/glide-daemon"
if [ -f "$DAEMON_PATH" ]; then
    echo "🔑 Re-signing daemon with correct identifier and Team ID..."
    codesign --force --sign "$SIGN_IDENTITY" --identifier "com.abhinav.glide-daemon" --options runtime "$DAEMON_PATH"
fi

echo "🔑 Re-signing main app bundle with Team ID..."
codesign --force --sign "$SIGN_IDENTITY" --options runtime --deep "$APP_BUNDLE"

# Ensure AppIcon is injected
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

DMG_NAME="${APP_NAME}.dmg"
echo "📀 Creating DMG..."

# Try to use create-dmg if installed, otherwise hdiutil
if command -v create-dmg &> /dev/null; then
    rm -f "$BUILD_DIR/$DMG_NAME"
    create-dmg \
      --volname "$APP_NAME Installer" \
      --volicon "AppIcon.icns" \
      --background "dmg_background.tiff" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "$APP_NAME.app" 150 190 \
      --hide-extension "$APP_NAME.app" \
      --app-drop-link 450 190 \
      "$BUILD_DIR/$DMG_NAME" \
      "$APP_BUNDLE"
else
    echo "⚠️  create-dmg not found, using hdiutil..."
    hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$BUILD_DIR/$DMG_NAME"
fi

echo "✅ Done! DMG created at $BUILD_DIR/$DMG_NAME"
