#!/bin/bash
# Generates the master app icon artwork and packages it into
# MacwinExplorer/Assets.xcassets/AppIcon.appiconset for Xcode to pick up.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
MASTER_PNG="$BUILD_DIR/icon-master.png"
ICONSET_DIR="$ROOT_DIR/MacwinExplorer/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$BUILD_DIR"

echo "==> Rendering master icon artwork…"
swift "$ROOT_DIR/Scripts/generate_app_icon.swift" "$MASTER_PNG"

mkdir -p "$ICONSET_DIR"

echo "==> Resizing into AppIcon.appiconset…"
declare -a SPECS=(
    "icon_16x16.png:16"
    "icon_16x16@2x.png:32"
    "icon_32x32.png:32"
    "icon_32x32@2x.png:64"
    "icon_128x128.png:128"
    "icon_128x128@2x.png:256"
    "icon_256x256.png:256"
    "icon_256x256@2x.png:512"
    "icon_512x512.png:512"
    "icon_512x512@2x.png:1024"
)

for spec in "${SPECS[@]}"; do
    filename="${spec%%:*}"
    px="${spec##*:}"
    sips -z "$px" "$px" "$MASTER_PNG" --out "$ICONSET_DIR/$filename" >/dev/null
done

cat > "$ICONSET_DIR/Contents.json" <<'JSON'
{
  "images" : [
    { "size" : "16x16",   "idiom" : "mac", "filename" : "icon_16x16.png",      "scale" : "1x" },
    { "size" : "16x16",   "idiom" : "mac", "filename" : "icon_16x16@2x.png",   "scale" : "2x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "icon_32x32.png",      "scale" : "1x" },
    { "size" : "32x32",   "idiom" : "mac", "filename" : "icon_32x32@2x.png",   "scale" : "2x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128.png",    "scale" : "1x" },
    { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128@2x.png", "scale" : "2x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256.png",    "scale" : "1x" },
    { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256@2x.png", "scale" : "2x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512.png",    "scale" : "1x" },
    { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512@2x.png", "scale" : "2x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON

ASSETS_ROOT="$ROOT_DIR/MacwinExplorer/Assets.xcassets"
if [ ! -f "$ASSETS_ROOT/Contents.json" ]; then
    cat > "$ASSETS_ROOT/Contents.json" <<'JSON'
{
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON
fi

echo "==> Done: $ICONSET_DIR"
