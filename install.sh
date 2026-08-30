#!/bin/bash
# One-shot installer that makes the Screen Recording permission actually STICK.
#
# The permission loop you hit has two root causes, and this script fixes both:
#
#   * The app was running from ~/Desktop, which is synced by iCloud. macOS can't
#     keep a stable identity for an app in a synced folder, so the permission
#     toggle never "takes".  -> we install into /Applications.
#
#   * An ad-hoc signature changes every rebuild, so macOS treats each build as a
#     brand-new app and forgets the permission.  -> we create ONE self-signed
#     signing identity and reuse it, giving the app a stable "designated
#     requirement" that macOS can remember.
#
# Then it clears the stale permission records so you get one clean prompt.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="QuickSnap"
BUNDLE_ID="com.github.quicksnap"
IDENTITY="QuickSnap Local Signing"
P12_PW="quicksnap"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# ---------------------------------------------------------------------------
# 1. Stable self-signed signing identity (created once, then reused)
# ---------------------------------------------------------------------------
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "==> Reusing signing identity: $IDENTITY"
    HAVE_IDENTITY=1
else
    echo "==> Creating self-signed signing identity: $IDENTITY"
    TMP="$(mktemp -d)"
    cat > "$TMP/cert.cnf" <<'CNF'
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no
[ dn ]
CN = QuickSnap Local Signing
[ ext ]
basicConstraints = critical,CA:FALSE
keyUsage         = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
    HAVE_IDENTITY=0
    if openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
           -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null \
       && openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
           -out "$TMP/id.p12" -passout "pass:$P12_PW" 2>/dev/null \
       && security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12_PW" -T /usr/bin/codesign -A 2>/dev/null; then
        security set-key-partition-list -S apple-tool:,apple: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || true
        echo "    created."
        HAVE_IDENTITY=1
    else
        echo "    couldn't create one - continuing with an ad-hoc signature."
        echo "    (Moving the app to /Applications alone usually still fixes the loop;"
        echo "     you may just need to re-grant permission after a rebuild.)"
    fi
    rm -rf "$TMP"
fi

# ---------------------------------------------------------------------------
# 2. Build (ad-hoc here; we re-sign the installed copy below)
# ---------------------------------------------------------------------------
./build.sh

# ---------------------------------------------------------------------------
# 3. Install into a stable, non-synced location
# ---------------------------------------------------------------------------
osascript -e 'quit app "QuickSnap"' >/dev/null 2>&1 || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

DEST="/Applications/$APP_NAME.app"
if ! ( rm -rf "$DEST" 2>/dev/null && cp -R "$APP_NAME.app" "$DEST" 2>/dev/null ); then
    mkdir -p "$HOME/Applications"
    DEST="$HOME/Applications/$APP_NAME.app"
    rm -rf "$DEST"
    cp -R "$APP_NAME.app" "$DEST"
fi
xattr -cr "$DEST"
echo "==> Installed to $DEST"

# ---------------------------------------------------------------------------
# 4. Sign the installed copy with the stable identity
# ---------------------------------------------------------------------------
if [ "${HAVE_IDENTITY:-0}" = "1" ]; then
    echo "==> Signing installed copy with '$IDENTITY'"
    echo "    (if a dialog asks to use a key in your keychain, click 'Always Allow')"
    codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$DEST"
    codesign -d -r- "$DEST" 2>&1 | grep -i 'designated' || true
fi

# ---------------------------------------------------------------------------
# 5. Clear stale permission records for this app
# ---------------------------------------------------------------------------
echo "==> Clearing stale permission records"
tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset All "$BUNDLE_ID"           >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 6. Launch
# ---------------------------------------------------------------------------
open "$DEST"

cat <<EOF

------------------------------------------------------------------
Installed and launched:
  $DEST

One time only:
  1. Click "Open System Settings" (or "Open Settings & Quit") when prompted.
  2. Open  Screen & System Audio Recording  and switch  QuickSnap  ON.
  3. Reopen QuickSnap:  Cmd-Space , type "QuickSnap", Return.
  4. Press  Cmd-Shift-2 , drag a box  ->  the markup window appears.  Done.

The copy on your Desktop is no longer used - you can delete it.
Re-run ./install.sh any time you change the code.
------------------------------------------------------------------
EOF
