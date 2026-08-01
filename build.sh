#!/bin/bash
# Build Sleepless.app — self-contained.
# Compiles the binary, assembles a complete bundle (Info.plist + icon),
# then ad-hoc signs it so it runs on ANY Mac without the Gatekeeper
# "damaged / can't be opened" block. Needs only the Xcode Command Line
# Tools (swiftc, iconutil, codesign) — full Xcode is NOT required.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

APP="Sleepless.app"
BUNDLE_ID="com.jasloop.sleepless"
VERSION="1.0"
MIN_MACOS="13.0"

echo "Compiling Sleepless..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Compile straight into the bundle so no stray binary is left in the repo.
swiftc -O -o "$APP/Contents/MacOS/Sleepless" Sleepless.swift -framework AppKit -framework IOKit

# --- App icon: compile Icons/*.png into AppIcon.icns (skipped if Icons/ absent) ---
ICON_KEY=""
if [ -d Icons ]; then
  echo "Building app icon..."
  ISET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ISET"
  cp Icons/icon_16x16.png     "$ISET/icon_16x16.png"
  cp Icons/icon_32x32.png     "$ISET/icon_16x16@2x.png"
  cp Icons/icon_32x32.png     "$ISET/icon_32x32.png"
  cp Icons/icon_64x64.png     "$ISET/icon_32x32@2x.png"
  cp Icons/icon_128x128.png   "$ISET/icon_128x128.png"
  cp Icons/icon_256x256.png   "$ISET/icon_128x128@2x.png"
  cp Icons/icon_256x256.png   "$ISET/icon_256x256.png"
  cp Icons/icon_512x512.png   "$ISET/icon_256x256@2x.png"
  cp Icons/icon_512x512.png   "$ISET/icon_512x512.png"
  cp Icons/icon_1024x1024.png "$ISET/icon_512x512@2x.png"
  iconutil -c icns "$ISET" -o "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
"
fi

echo "Writing Info.plist..."
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Sleepless</string>
    <key>CFBundleDisplayName</key>
    <string>Sleepless</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>Sleepless</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
${ICON_KEY}</dict>
</plist>
PLIST

# --- Clean xattrs + ad-hoc sign (creates the _CodeSignature seal Gatekeeper needs) ---
echo "Signing (ad-hoc)..."
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP" && echo "  signature valid"

echo ""
echo "Built $APP  (ad-hoc signed$( [ -n "$ICON_KEY" ] && echo ", with icon" ))"
echo ""
echo "To install:  cp -r $APP /Applications/"
echo "Login item:  System Settings > General > Login Items > add Sleepless"
