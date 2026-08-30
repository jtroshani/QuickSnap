#!/bin/bash
# Builds QuickSnap.app from source. Requires the Xcode Command Line Tools
# (run `xcode-select --install` once if you don't have them).
set -euo pipefail

APP_NAME="QuickSnap"
BUNDLE_ID="com.github.quicksnap"
VERSION="1.0.0"
RELEASE_BIN=".build/release/$APP_NAME"
APP_BUNDLE="$APP_NAME.app"

# Pass `--identity "Some Cert Name"` to sign with a real (or self-signed) identity
# instead of an ad-hoc signature. A stable identity is what lets macOS *remember*
# the Screen Recording permission across rebuilds -- see install.sh.
SIGN_IDENTITY="-"
if [[ "${1:-}" == "--identity" && -n "${2:-}" ]]; then
    SIGN_IDENTITY="$2"
fi

echo "==> Compiling (release)"
swift build -c release

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

# iCloud-synced folders (~/Desktop, ~/Documents) sprinkle com.apple.FinderInfo /
# com.apple.provenance xattrs onto the bundle, which make codesign refuse it.
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "==> Ad-hoc signing"
    echo "    (note: the screen-recording permission won't stick across rebuilds -"
    echo "     run ./install.sh for a stable install)"
    codesign --force --sign - "$APP_BUNDLE"
else
    echo "==> Signing with identity: $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
fi

echo ""
echo "Done  ->  $(pwd)/$APP_BUNDLE"
echo "Try it:  open \"$APP_BUNDLE\""
