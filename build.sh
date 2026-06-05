#!/bin/bash
set -e

VERSION=${1:-$(defaults read "$(pwd)/TokenTracker/TokenTracker/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")}
SCHEME="TokenTracker"
PROJECT="TokenTracker/TokenTracker.xcodeproj"
BUILD_DIR="$(pwd)/build"
APP_PATH="$BUILD_DIR/$SCHEME.app"
DMG_PATH="$(pwd)/release/TT${VERSION//./}.dmg"
SIGN_UPDATE="$HOME/Library/Developer/Xcode/DerivedData/TokenTracker-ehgmynhzehxjyabtbfjkmwabwmfq/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

echo "==> Building TokenTracker v$VERSION"
mkdir -p "$BUILD_DIR" "$(pwd)/release"

# Build
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  clean build 2>&1 | tail -20

echo "==> Re-signing (inside-out) to unify Team IDs"
# Sparkle nested components must be signed before the framework itself
for XPC in "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/"*.xpc; do
  codesign --force --sign - "$XPC"
done
codesign --force --sign - "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --sign - "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --sign - "$APP_PATH/Contents/Frameworks/Sparkle.framework"
for APPEX in "$APP_PATH/Contents/PlugIns/"*.appex; do
  codesign --force --sign - "$APPEX"
done
codesign --force --sign - "$APP_PATH"

echo "==> Verifying"
codesign -dv "$APP_PATH/Contents/Frameworks/Sparkle.framework" 2>&1 | grep "TeamIdentifier"
codesign -dv "$APP_PATH" 2>&1 | grep "TeamIdentifier"

echo "==> Creating DMG"
mkdir -p /tmp/tt_dmg
cp -R "$APP_PATH" /tmp/tt_dmg/
ln -sf /Applications /tmp/tt_dmg/Applications
hdiutil create -volname "TokenTracker" -srcfolder /tmp/tt_dmg -ov -format UDZO "$DMG_PATH"
rm -rf /tmp/tt_dmg

echo "==> Signing appcast entry"
SIGNATURE=$("$SIGN_UPDATE" "$DMG_PATH" 2>/dev/null || echo "SIGN_UPDATE_NOT_FOUND")
SIZE=$(stat -f%z "$DMG_PATH")
echo ""
echo "appcast entry:"
echo "  sparkle:edSignature=\"$SIGNATURE\""
echo "  length=\"$SIZE\""
echo ""
echo "==> Done: $DMG_PATH"
