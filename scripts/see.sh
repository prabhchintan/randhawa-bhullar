#!/bin/bash
# The loop's eyes on the pair: build Randhawa and Bhullar with their walks
# (Walk/, one UI test target per project), put both on one fresh simulator,
# and walk each app through its screens three times: light, dark, and light
# at the largest accessibility text. Every screen is photographed, and in
# light and dark Apple's accessibility audit runs on it. The apps get no
# launch arguments; the walk drives the real UI.
#
#   bash scripts/see.sh [OUTDIR]        default /tmp/see/pair
#
# Leaves OUTDIR/<screen>-<look>.png, audit.tsv (screen, look, kind, element,
# issue) and notes.txt (where a walk could not go). Prints the audit by
# screen and the pictures; exits 1 when a build or a walk fails.
set -euo pipefail
OUT=${1:-/tmp/see/pair}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DD=${SEE_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/pair-see}
DEVICE=${SEE_DEVICE:-iPhone 16 Pro}
rm -rf "$OUT"
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available -j | DEVICE="$DEVICE" python3 -c '
import json, os, sys
for devs in json.load(sys.stdin)["devices"].values():
    for d in devs:
        if d["name"] == os.environ["DEVICE"]:
            print(d["udid"]); raise SystemExit
sys.exit("no simulator called " + os.environ["DEVICE"])')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

walk() { # project scheme
  echo "-project $ROOT/$1 -scheme $2 -configuration Debug -destination id=$UDID -derivedDataPath $DD"
}
for pair in "Randhawa.xcodeproj RandhawaWalk" "Bhullar/Bhullar.xcodeproj BhullarWalk"; do
  set -- $pair
  if ! xcodebuild $(walk "$1" "$2") build-for-testing > "$OUT/build-$2.log" 2>&1; then
    grep -E "error:" "$OUT/build-$2.log" | sort -u | head -20
    echo "BUILD FAILED ($2)"
    exit 1
  fi
done

# A fresh start: no map, no memories, location not yet asked, standing
# somewhere public (Apple Park) so the first dot has a place to land.
for app in Prabhchintan.Randhawa Prabhchintan.Bhullar; do
  xcrun simctl uninstall "$UDID" "$app" 2>/dev/null || true
done
xcrun simctl location "$UDID" set 37.3349,-122.0090

STATUS=0
for look in light dark large; do
  case "$look" in
    large) xcrun simctl ui "$UDID" appearance light
           xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
           AUDIT=0 ;;
    *)     xcrun simctl ui "$UDID" appearance "$look"
           xcrun simctl ui "$UDID" content_size large
           AUDIT=1 ;;
  esac
  for pair in "Randhawa.xcodeproj RandhawaWalk" "Bhullar/Bhullar.xcodeproj BhullarWalk"; do
    set -- $pair
    TEST_RUNNER_WALK_OUT="$OUT" TEST_RUNNER_WALK_LOOK="$look" TEST_RUNNER_WALK_AUDIT="$AUDIT" \
      xcodebuild $(walk "$1" "$2") -only-testing:"$2" test-without-building \
      > "$OUT/walk-$2-$look.log" 2>&1 || { STATUS=1; echo "WALK FAILED: $2 $look (walk-$2-$look.log)"; }
  done
done
xcrun simctl ui "$UDID" appearance light
xcrun simctl ui "$UDID" content_size large

if [ -f "$OUT/audit.tsv" ]; then
  echo "The audit: $(grep -c . "$OUT/audit.tsv" || true) findings (screen, look, kind, element, issue)"
  sort "$OUT/audit.tsv"
else
  echo "The audit: nothing found"
fi
if [ -f "$OUT/notes.txt" ]; then
  echo "The walks' notes:"
  cat "$OUT/notes.txt"
fi
echo "Pictures:"
ls "$OUT"/*.png 2>/dev/null || true
exit "$STATUS"
