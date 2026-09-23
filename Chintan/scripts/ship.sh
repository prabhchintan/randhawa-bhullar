#!/bin/bash
# Archive chintan and upload it to TestFlight (internal testing, never a
# submission), signing in a keychain of this run's own: the Mac's login
# keychain will not lend its keys to a background process. Needs ASC_KEY_ID,
# ASC_ISSUER_ID and ASC_KEY_P8 in the environment. Restores the login
# keychain and removes every trace on exit, success or not.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
LOGIN="$HOME/Library/Keychains/login.keychain-db"
KC="$TMP/build.keychain-db"
cleanup() {
  security default-keychain -d user -s "$LOGIN" 2>/dev/null || true
  security list-keychains -d user -s "$LOGIN" 2>/dev/null || true
  security delete-keychain "$KC" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT
security create-keychain -p "" "$KC"
security set-keychain-settings -lut 7200 "$KC"
security unlock-keychain -p "" "$KC"
security list-keychains -d user -s "$KC"
security default-keychain -d user -s "$KC"
printf '%s\n' "$ASC_KEY_P8" > "$TMP/AuthKey.p8"; chmod 600 "$TMP/AuthKey.p8"
KEY=(-allowProvisioningUpdates -authenticationKeyPath "$TMP/AuthKey.p8" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
BUILD=$(date -u +%Y%m%d%H%M)
echo "chintan 1.0 ($BUILD)"
if ! xcodebuild -project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -destination 'generic/platform=iOS' \
     -archivePath "$TMP/Chintan.xcarchive" CURRENT_PROJECT_VERSION="$BUILD" "${KEY[@]}" archive > "$TMP/archive.log" 2>&1; then
  grep -E -i -B3 -A8 "error|failed" "$TMP/archive.log" | tail -60; echo "ARCHIVE FAILED"; exit 1
fi
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
xcodebuild -exportArchive -archivePath "$TMP/Chintan.xcarchive" -exportOptionsPlist "$TMP/exportOptions.plist" \
  -exportPath "$TMP/export" "${KEY[@]}" 2>&1 | grep -E "error:|Upload succeeded|EXPORT (SUCCEEDED|FAILED)"
echo "uploaded chintan 1.0 ($BUILD); Apple processes it in five to thirty minutes, TestFlight installs it on the phone"
