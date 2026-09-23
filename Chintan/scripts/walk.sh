#!/bin/bash
# The house's eyes for motion: the walk (the XCUITest ChintanWalk) takes the
# app through its gestures on the simulator while simctl films the screen.
# Leaves, under OUTDIR: shots/ (every state the walk passed through),
# walk.mov (the film), sheets/ (one contact sheet per gesture, a frame every
# 250 ms across it) and steps.tsv (each gesture and note with the clock).
# Prints the pictures and the walk's notes; exits 1 when the build or the
# walk fails. Needs CHINTAN_HOUSE in the environment (the house address).
#
#   bash Chintan/scripts/walk.sh [OUTDIR]           default /tmp/see/walk
#   bash Chintan/scripts/walk.sh --audit [OUTDIR]   the audit alone, no film
set -euo pipefail
ONLY_AUDIT=""
if [ "${1:-}" = "--audit" ]; then ONLY_AUDIT=1; shift; fi
OUT=${1:-/tmp/see/walk}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DD=${SEE_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/chintan-see}
DEVICE=${SEE_DEVICE:-iPhone 16 Pro}
rm -rf "$OUT"
mkdir -p "$OUT/shots"
UDID=$(xcrun simctl list devices available -j | DEVICE="$DEVICE" python3 -c '
import json, os, sys
for devs in json.load(sys.stdin)["devices"].values():
    for d in devs:
        if d["name"] == os.environ["DEVICE"]:
            print(d["udid"]); raise SystemExit
sys.exit("no simulator called " + os.environ["DEVICE"])')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

# Build first, so the film holds the walk and not the compiler.
XCB=(-project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -configuration Debug
     -destination "id=$UDID" -derivedDataPath "$DD")
if ! xcodebuild "${XCB[@]}" -only-testing:ChintanWalk build-for-testing > "$OUT/build.log" 2>&1; then
  grep -E -B2 -A6 "error:" "$OUT/build.log" | tail -80
  echo "BUILD FAILED"
  exit 1
fi

if [ -z "$ONLY_AUDIT" ]; then
xcrun simctl ui "$UDID" appearance light
xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT/walk.mov" 2> "$OUT/record.log" &
REC=$!
for _ in $(seq 100); do
  grep -q "Recording started" "$OUT/record.log" 2>/dev/null && break
  sleep 0.1
done
START=$(python3 -c 'import time; print(f"{time.time():.3f}")')

# The walk writes "dark" and "light" when it wants the phone turned; the
# simulator's appearance is the host's to change, so a watcher does it.
(
  turned=""
  while sleep 0.2; do
    [ -f "$OUT/shots/steps.tsv" ] || continue
    if [ -z "$turned" ] && grep -q $'\tmark\tdark$' "$OUT/shots/steps.tsv"; then
      xcrun simctl ui "$UDID" appearance dark; turned=dark
    fi
    if [ "$turned" = dark ] && grep -q $'\tmark\tlight$' "$OUT/shots/steps.tsv"; then
      xcrun simctl ui "$UDID" appearance light; break
    fi
  done
) &
WATCH=$!

STATUS=0
TEST_RUNNER_WALK_OUT="$OUT/shots" TEST_RUNNER_CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" \
  xcodebuild "${XCB[@]}" -only-testing:ChintanWalk/ChintanWalk test-without-building > "$OUT/test.log" 2>&1 || STATUS=$?

kill -INT "$REC" 2>/dev/null || true
wait "$REC" 2>/dev/null || true
kill "$WATCH" 2>/dev/null || true
xcrun simctl ui "$UDID" appearance light
mv "$OUT/shots/steps.tsv" "$OUT/steps.tsv" 2>/dev/null || true

if [ -s "$OUT/steps.tsv" ] && [ -s "$OUT/walk.mov" ]; then
  swift "$ROOT/Chintan/scripts/frames.swift" "$OUT/walk.mov" "$OUT/steps.tsv" "$START" "$OUT/sheets" > /dev/null
fi
if [ "$STATUS" -ne 0 ]; then
  grep -E "error:|failed|Failing" "$OUT/test.log" | head -20
  echo "WALK FAILED (the pictures it took are below)"
fi

# The hitches, off the film. Instruments has no hitches on the simulator
# ("not supported on this platform"), so the app times its own frames
# (--hitches) and the ChintanHitches walk logs a window per gesture; the
# late frames in a window, summed, over its length are the hitch time ratio
# in ms per s (Apple: under 5 good, over 10 a visible jank). These frames
# are the Mac's, so read the numbers before against after, not as the phone.
TEST_RUNNER_WALK_OUT="$OUT" TEST_RUNNER_CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" \
  xcodebuild "${XCB[@]}" -only-testing:ChintanWalk/ChintanHitches test-without-building > "$OUT/hitches.log" 2>&1 || true
DATA=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data 2>/dev/null || true)
cp "$DATA/Library/Caches/hitches.tsv" "$OUT/frames.tsv" 2>/dev/null || true
python3 - "$OUT/hitches-steps.tsv" "$OUT/frames.tsv" > "$OUT/hitches.txt" <<'PY'
import sys
try:
    windows = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip()]
    late = [tuple(map(float, l.split("\t"))) for l in open(sys.argv[2]) if l.strip()]
except OSError:
    windows = []
if not windows:
    print("no hitch numbers (see hitches.log)")
for start, end, name in windows:
    start, end = float(start), float(end)
    ms = [m for t, m in late if start <= t <= end]
    print(f"{name}: {sum(ms) / (end - start):.1f} ms/s over {end - start:.1f} s,"
          f" {len(ms)} hitches, worst {max(ms, default=0):.0f} ms")
PY
fi
STATUS=${STATUS:-0}

# The audit: Apple's accessibility audit on every screen, light then dark.
# Each line a real defect a person would feel; zero is the bar.
rm -f "$OUT/audit.tsv"
for LOOK in light dark; do
  xcrun simctl ui "$UDID" appearance "$LOOK"
  TEST_RUNNER_WALK_OUT="$OUT" TEST_RUNNER_AUDIT_LOOK="$LOOK" TEST_RUNNER_CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" \
    xcodebuild "${XCB[@]}" -only-testing:ChintanWalk/ChintanAudit test-without-building > "$OUT/audit-$LOOK.log" 2>&1 || true
done
xcrun simctl ui "$UDID" appearance light

if [ -f "$OUT/audit.tsv" ]; then
  echo "The audit: $(grep -c . "$OUT/audit.tsv" || true) findings (screen, look, kind, element, word)"
  sort "$OUT/audit.tsv"
else
  echo "The audit: did not run (see audit-light.log)"
fi
[ -n "$ONLY_AUDIT" ] && exit 0
echo "The hitches:"
cat "$OUT/hitches.txt"
echo "The walk's notes:"
grep $'\tnote\t' "$OUT/steps.tsv" 2>/dev/null | cut -f3 || true
echo "Film: $OUT/walk.mov"
echo "Pictures:"
ls "$OUT"/shots/*.png "$OUT"/sheets/*.png 2>/dev/null || true
exit "$STATUS"
