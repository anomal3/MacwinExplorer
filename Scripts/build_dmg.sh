#!/bin/bash
# Builds MacwinExplorer (Release) and packages it into a drag-to-Applications
# installer DMG, the way most non-App-Store Mac apps are distributed.
set -euo pipefail

APP_NAME="MacwinExplorer"
SCHEME="MacwinExplorer"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
STAGING_DIR="$BUILD_DIR/dmg-staging"
BACKGROUND_PNG="$BUILD_DIR/dmg-background.png"
DMG_TMP="$BUILD_DIR/${APP_NAME}-tmp.dmg"
DMG_FINAL="$BUILD_DIR/${APP_NAME}-Installer.dmg"
VOLUME_NAME="$APP_NAME"

echo "==> Generating Xcode project…"
(cd "$ROOT_DIR" && xcodegen generate)

echo "==> Building $APP_NAME ($CONFIGURATION)…"
xcodebuild -project "$ROOT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -destination 'platform=macOS' \
    build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "error: build succeeded but $APP_PATH was not found" >&2
    exit 1
fi

echo "==> Preparing staging folder…"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Generating background artwork…"
swift "$ROOT_DIR/Scripts/generate_dmg_background.swift" "$BACKGROUND_PNG" "$APP_NAME"
mkdir -p "$STAGING_DIR/.background"
cp "$BACKGROUND_PNG" "$STAGING_DIR/.background/background.png"

echo "==> Creating disk image…"
rm -f "$DMG_TMP" "$DMG_FINAL"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -fs HFS+ -format UDRW "$DMG_TMP" >/dev/null

MOUNT_DIR="/Volumes/$VOLUME_NAME"
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -quiet || true
fi

echo "==> Mounting for styling…"
hdiutil attach "$DMG_TMP" -readwrite -noverify -noautoopen >/dev/null
sleep 1

echo "==> Styling Finder window…"
osascript <<APPLESCRIPT
with timeout of 120 seconds
    tell application "Finder"
        tell disk "$VOLUME_NAME"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 120, 860, 520}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 96
            set background picture of theViewOptions to file ".background:background.png"
            set position of item "$APP_NAME.app" of container window to {150, 220}
            set position of item "Applications" of container window to {505, 220}
            update without registering applications
        end tell
    end tell
end timeout
APPLESCRIPT

echo "==> Finalizing…"
chmod -Rf go-w "$MOUNT_DIR" || true
sync
hdiutil detach "$MOUNT_DIR" -quiet

hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" >/dev/null
rm -f "$DMG_TMP"

echo "==> Done: $DMG_FINAL"
