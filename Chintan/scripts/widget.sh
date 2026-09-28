#!/bin/bash
# The house's eyes on the widget (chunk Q): build for testing, then the test
# ChintanWidgetEyes drives the simulator's home screen into the widget
# gallery, photographs chintan's widget at each size as the gallery shows it,
# adds the large one and photographs it standing, then takes it off again.
# Prints the picture paths and what the widget kept of each frame. Needs
# CHINTAN_HOUSE in the environment (the house address).
#
#   bash Chintan/scripts/widget.sh OUTDIR          WIDGET_LOOK=light for light
set -euo pipefail
OUT=${1:?usage: widget.sh OUTDIR}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DD=${SEE_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/chintan-see}
DEVICE=${SEE_DEVICE:-iPhone 16 Pro}
rm -rf "$OUT"
mkdir -p "$OUT"
UDID=$(xcrun simctl list devices available -j | DEVICE="$DEVICE" python3 -c '
import json, os, sys
devs = [d for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["name"] == os.environ["DEVICE"]]
devs.sort(key=lambda d: d["state"] != "Booted")
if not devs: sys.exit("no simulator called " + os.environ["DEVICE"])
print(devs[0]["udid"])')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance "${WIDGET_LOOK:-dark}"
XCB=(-project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -configuration Debug
     -destination "id=$UDID" -derivedDataPath "$DD")
if ! xcodebuild "${XCB[@]}" -only-testing:ChintanWalk build-for-testing > "$OUT/build.log" 2>&1; then
  grep -E -B2 -A6 "error:" "$OUT/build.log" | tail -80
  echo "BUILD FAILED"
  exit 1
fi
TEST_RUNNER_WALK_OUT="$OUT" TEST_RUNNER_CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" \
  xcodebuild "${XCB[@]}" -only-testing:ChintanWalk/ChintanWidgetEyes test-without-building > "$OUT/test.log" 2>&1 \
  || echo "the test said no; read $OUT/test.log"
# What the widget kept in the App Group: the record the house gave each frame.
GROUP=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan group.Prabhchintan.Chintan 2>/dev/null || true)
for f in "$GROUP"/wall/*.json; do
  [ -f "$f" ] && echo "KEPT $(basename "$f"): $(head -c 300 "$f")"
done
echo "pictures:"
ls "$OUT"/*.png 2>/dev/null || echo "none"
