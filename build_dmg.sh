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

SIGN_IDENTITY="EA7232703AB7C8D9D5AB19476F4C96C3A56212BD"

# Ensure AppIcon is injected before signing
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# IMPORTANT: Code signing must go inside-out properly.
# 1. Sign everything with --deep first so Sparkle and other frameworks get signed.
echo "🔑 Deep signing app bundle to sign frameworks (Sparkle, etc)..."
codesign --force --sign "$SIGN_IDENTITY" --options runtime --deep "$APP_BUNDLE"

# 2. --deep clobbers the daemon's required identifier. We MUST re-sign the daemon
#    with its correct Mach service identifier.
DAEMON_PATH="$APP_BUNDLE/Contents/MacOS/glide-daemon"
if [ -f "$DAEMON_PATH" ]; then
    echo "🔑 Re-signing daemon with correct identifier and Team ID..."
    codesign --force --sign "$SIGN_IDENTITY" --identifier "com.abhinav.glide-daemon" --options runtime "$DAEMON_PATH"
fi

# 3. Because we modified the daemon's signature, the outer app's seal is broken.
#    Re-sign the outer app bundle ONLY (without --deep) to create a valid seal.
echo "🔑 Re-sealing main app bundle..."
codesign --force --sign "$SIGN_IDENTITY" --options runtime "$APP_BUNDLE"

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

# Automatically generate appcast.xml with the correct GitHub Releases URL for this version
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist")

echo "📡 Generating appcast for version $APP_VERSION..."
./build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --download-url-prefix "https://github.com/abhiswrld/glide-macos/releases/download/v$APP_VERSION/" \
    "$BUILD_DIR"

if [ -f "$BUILD_DIR/appcast.xml" ]; then
    cp "$BUILD_DIR/appcast.xml" .
    echo "✅ Updated appcast.xml generated and copied to root!"
fi
