#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LazyDisk"
BUILD_DIR="$ROOT/.build/release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
ENTITLEMENTS="$ROOT/Scripts/LazyDisk.entitlements"
ICONSET="$ROOT/assets/AppIcon.iconset"
ICON_ICNS="$ROOT/assets/AppIcon.icns"
ZIP_PATH="$DIST_DIR/${APP_NAME}.zip"

echo "Building $APP_NAME..."
cd "$ROOT"
swift build -c release

if [[ -f "$ICON_ICNS" ]]; then
  echo "Using app icon: $ICON_ICNS"
elif [[ -d "$ICONSET" ]]; then
  echo "Building icon from iconset..."
  iconutil -c icns "$ICONSET" -o "$ICON_ICNS"
fi

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

INFO_TEMPLATE="$ROOT/Scripts/Info.plist.template"
if [[ -f "$INFO_TEMPLATE" ]]; then
  cp "$INFO_TEMPLATE" "$APP_DIR/Contents/Info.plist"
else
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LazyDisk</string>
    <key>CFBundleIdentifier</key>
    <string>com.lazydisk.app</string>
    <key>CFBundleName</key>
    <string>LazyDisk</string>
    <key>CFBundleDisplayName</key>
    <string>LazyDisk</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
fi

if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

if [[ -f "$ICON_ICNS" ]]; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_DIR/Contents/Info.plist"
fi

chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing with identity: $SIGN_IDENTITY"
  codesign --force --deep --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
else
  echo "Skipping Developer ID signing (set CODE_SIGN_IDENTITY to sign for distribution)"
  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR" 2>/dev/null || true
  fi
fi

notarize_app() {
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "Error: notarization requires CODE_SIGN_IDENTITY (Developer ID Application)."
    exit 1
  fi

  echo "Preparing notarization zip..."
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

  echo "Submitting to Apple notary service..."
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP_PATH" \
      --keychain-profile "$NOTARYTOOL_PROFILE" \
      --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
    xcrun notarytool submit "$ZIP_PATH" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  else
    echo "Error: set NOTARYTOOL_PROFILE or APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID"
    exit 1
  fi

  echo "Stapling notarization ticket..."
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  rm -f "$ZIP_PATH"
  echo "Notarization complete."
}

if [[ "${NOTARIZE_APP:-}" == "1" ]]; then
  notarize_app
fi

echo "Done! App bundle created at:"
echo "  $APP_DIR"
echo ""
echo "Run with: open dist/${APP_NAME}.app"
echo ""
echo "Distribution:"
echo "  CODE_SIGN_IDENTITY=\"Developer ID Application: …\" ./Scripts/build-app.sh"
echo ""
echo "Notarization (after signing):"
echo "  NOTARIZE_APP=1 NOTARYTOOL_PROFILE=\"your-profile\" CODE_SIGN_IDENTITY=\"Developer ID Application: …\" ./Scripts/build-app.sh"
echo "  # or: NOTARIZE_APP=1 APPLE_ID=… APPLE_APP_SPECIFIC_PASSWORD=… APPLE_TEAM_ID=… CODE_SIGN_IDENTITY=… ./Scripts/build-app.sh"
