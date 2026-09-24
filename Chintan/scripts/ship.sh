#!/bin/bash
# Archive chintan and upload it to TestFlight (internal testing, never a
# submission) on yantar, signing in a keychain of the house's own: the Mac's
# login keychain will not lend its keys to a background process, and Xcode's
# cloud signing wants to find, on the next run, the certificate it made on
# the last one, so the keychain persists (chintan-build.keychain-db) and is
# only put first in the search list for the length of the run. Needs
# ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 in the environment. Restores the
# login keychain and removes the key material on exit, success or not.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
LOGIN="$HOME/Library/Keychains/login.keychain-db"
KC="$HOME/Library/Keychains/chintan-build.keychain-db"
KCPW="chintan-build"     # not a secret: the keychain holds one development certificate
cleanup() {
  security default-keychain -d user -s "$LOGIN" 2>/dev/null || true
  security list-keychains -d user -s "$LOGIN" 2>/dev/null || true
  security lock-keychain "$KC" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT
if [ ! -f "$KC" ]; then
  security create-keychain -p "$KCPW" "$KC"
  security set-keychain-settings "$KC"          # no auto-lock
  echo "made the build keychain"
fi
security unlock-keychain -p "$KCPW" "$KC"
security list-keychains -d user -s "$KC"
security default-keychain -d user -s "$KC"
printf '%s\n' "$ASC_KEY_P8" > "$TMP/AuthKey.p8"; chmod 600 "$TMP/AuthKey.p8"
printf '{"key_id": "%s", "issuer_id": "%s", "key_path": "%s/AuthKey.p8", "team_id": "7FWNAT83XU"}\n' \
  "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$TMP" > "$TMP/config.json"
KEY=(-allowProvisioningUpdates -authenticationKeyPath "$TMP/AuthKey.p8" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
BUILD=$(date -u +%Y%m%d%H%M)
echo "chintan 1.0 ($BUILD)"
# The icon is cut by the house for this build (Prab, 2026-09-24 05:04: a
# different work of art through his arch on every build, never constant):
# GET /v1/icon.png?seed=BUILD. The checked-in icon stands when the house is
# out of reach, so a build never waits on it.
ICON="$ROOT/Chintan/Chintan/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
if [ -n "${CHINTAN_HOUSE:-}" ]; then
  HOUSE="${CHINTAN_HOUSE%/}"; case "$HOUSE" in http*) ;; *) HOUSE="http://$HOUSE" ;; esac
  if curl -fsS --max-time 200 -D "$TMP/icon.h" -o "$TMP/icon.png" "$HOUSE/v1/icon.png?seed=$BUILD" \
     && [ "$(file -b --mime-type "$TMP/icon.png")" = "image/png" ]; then
    cp "$TMP/icon.png" "$ICON"
    echo "icon for this build: $(sed -n 's/^X-Work: //Ip' "$TMP/icon.h" | tr -d '\r')"
  else
    echo "the house gave no icon; the checked-in one stands"
  fi
fi
archive() {
  xcodebuild -project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -destination 'generic/platform=iOS' \
    -archivePath "$TMP/Chintan.xcarchive" CURRENT_PROJECT_VERSION="$BUILD" "${KEY[@]}" archive > "$TMP/archive.log" 2>&1
}
if ! archive; then
  if grep -q "Revoke certificate" "$TMP/archive.log"; then
    # A certificate made by an earlier run whose keychain is gone. Revoke the
    # day's Apple Development certificates and let Xcode make a fresh one here.
    echo "a stale development certificate blocks signing; revoking today's and trying once more"
    python3 -c "import jwt" 2>/dev/null || pip3 install --quiet --user "PyJWT[crypto]"
    ASC_CONFIG="$TMP/config.json" python3 "$ROOT/scripts/asc.py" certificates --revoke-newer-than 24 || true
    rm -rf "$TMP/Chintan.xcarchive"
    archive || { grep -E -i -B3 -A8 "error|failed" "$TMP/archive.log" | tail -60; echo "ARCHIVE FAILED"; exit 1; }
  else
    grep -E -i -B3 -A8 "error|failed" "$TMP/archive.log" | tail -60; echo "ARCHIVE FAILED"; exit 1
  fi
fi
echo "** ARCHIVE SUCCEEDED **"
cat > "$TMP/exportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>7FWNAT83XU</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
if xcodebuild -exportArchive -archivePath "$TMP/Chintan.xcarchive" -exportOptionsPlist "$TMP/exportOptions.plist" \
     -exportPath "$TMP/export" "${KEY[@]}" > "$TMP/export.log" 2>&1; then
  grep -E "Upload succeeded|EXPORT SUCCEEDED" "$TMP/export.log" | head -2
  echo "uploaded chintan 1.0 ($BUILD); Apple processes it in five to thirty minutes, TestFlight installs it on the phone"
else
  grep -E -i -B3 -A8 "error|failed" "$TMP/export.log" | tail -40; echo "EXPORT FAILED"; exit 1
fi
