#!/bin/bash
# The house's eyes on chintan, the private app, run on the Mac that builds it:
# build for the simulator (incremental, one derived-data folder kept between
# looks), launch every tab against the real house, photograph it in light
# and dark. Prints the picture paths; exits 1 with the errors when the build
# fails. Needs CHINTAN_HOUSE in the environment (the house address).
#
#   bash Chintan/scripts/see.sh OUTDIR [tab ...]     tabs: jharokha board study
#                                                    (board@N: the Nth thing opened)
set -euo pipefail
OUT=${1:?usage: see.sh OUTDIR [tab ...]}; shift
TABS=${*:-jharokha board study}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DD=${SEE_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/chintan-see}
DEVICE=${SEE_DEVICE:-iPhone 16 Pro}
mkdir -p "$OUT"
LOG="$OUT/build.log"
if ! xcodebuild -project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -configuration Debug \
     -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
     -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build > "$LOG" 2>&1; then
  grep -E -B2 -A6 "error:" "$LOG" | tail -80
  echo "BUILD FAILED"
  exit 1
fi
grep -E "warning:" "$LOG" | grep -F "/Chintan/" | sort -u | head -10 || true
UDID=$(xcrun simctl list devices available -j | DEVICE="$DEVICE" python3 -c '
import json, os, sys
for devs in json.load(sys.stdin)["devices"].values():
    for d in devs:
        if d["name"] == os.environ["DEVICE"]:
            print(d["udid"]); raise SystemExit
sys.exit("no simulator called " + os.environ["DEVICE"])')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
APP=$(find "$DD/Build/Products" -name Chintan.app -path '*iphonesimulator*' | head -1)
xcrun simctl install "$UDID" "$APP"
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for tab in $TABS; do
    xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
    # A tab written board@N is the board with its Nth thing opened on launch.
    EXTRA=()
    case "$tab" in *@*) EXTRA=(--open "${tab#*@}") ;; esac
    xcrun simctl launch "$UDID" Prabhchintan.Chintan --house "${CHINTAN_HOUSE:-}" --tab "${tab%@*}" "${EXTRA[@]+"${EXTRA[@]}"}" >/dev/null
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$tab-$mode.png" >/dev/null
  done
done
xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
echo "BUILD OK, pictures:"
ls "$OUT"/*.png
