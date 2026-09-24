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
#   bash Chintan/scripts/walk.sh --hitches [OUTDIR] [RUNS]
#       the hitch numbers alone, RUNS times (default 3), each run and the
#       median of each gesture; the Mac's frames are noisy, so a sprint that
#       touches motion reads the median before against after.
set -euo pipefail
ONLY_AUDIT=""
ONLY_HITCHES=""
if [ "${1:-}" = "--audit" ]; then ONLY_AUDIT=1; shift; fi
if [ "${1:-}" = "--hitches" ]; then ONLY_HITCHES=1; shift; fi
OUT=${1:-/tmp/see/walk}
RUNS=${2:-3}
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

# The hitches. Instruments has no hitches on the simulator ("not supported
# on this platform"), so the app times its own frames (--hitches) and the
# ChintanHitches walk logs a window per gesture; the late frames in a
# window, summed, over its length are the hitch time ratio in ms per s
# (Apple: under 5 good, over 10 a visible jank). These frames are the
# Mac's, so read the numbers before against after, not as the phone.
hitches() {
  TEST_RUNNER_WALK_OUT="$1" TEST_RUNNER_CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" \
    xcodebuild "${XCB[@]}" -only-testing:ChintanWalk/ChintanHitches test-without-building > "$1/hitches.log" 2>&1 || true
  DATA=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data 2>/dev/null || true)
  cp "$DATA/Library/Caches/hitches.tsv" "$1/frames.tsv" 2>/dev/null || true
  # Then the walk with no hand: the app launched plainly, turning its own
  # pages, so nothing reads its accessibility tree; its own cost alone.
  rm -f "$DATA/Library/Caches/self-done"
  xcrun simctl launch --terminate-running-process "$UDID" Prabhchintan.Chintan \
    --house "${CHINTAN_HOUSE:-}" --tab jharokha --hitches --self-walk > /dev/null 2>&1 || true
  for _ in $(seq 60); do
    [ -f "$DATA/Library/Caches/self-done" ] && break
    sleep 1
  done
  xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
  cp "$DATA/Library/Caches/self-steps.tsv" "$1/self-steps.tsv" 2>/dev/null || true
  cp "$DATA/Library/Caches/hitches.tsv" "$1/self-frames.tsv" 2>/dev/null || true
  python3 - "$1/hitches-steps.tsv" "$1/frames.tsv" "$1/self-steps.tsv" "$1/self-frames.tsv" > "$1/hitches.txt" <<'PY'
import sys
windows = []
for steps, frames in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    try:
        ws = [l.rstrip("\n").split("\t") for l in open(steps) if l.strip()]
        late = [tuple(map(float, l.split("\t"))) for l in open(frames) if l.strip()]
    except OSError:
        continue
    windows += [(w, late) for w in ws]
if not windows:
    print("no hitch numbers (see hitches.log)")
for (start, end, name), late in windows:
    start, end = float(start), float(end)
    ms = [m for t, m in late if start <= t <= end]
    print(f"{name}: {sum(ms) / (end - start):.1f} ms/s over {end - start:.1f} s,"
          f" {len(ms)} hitches, worst {max(ms, default=0):.0f} ms")
PY
}

if [ -n "$ONLY_HITCHES" ]; then
  xcrun simctl ui "$UDID" appearance light
  for n in $(seq "$RUNS"); do
    mkdir -p "$OUT/run$n"
    hitches "$OUT/run$n"
    echo "Run $n:"
    cat "$OUT/run$n/hitches.txt"
  done
  echo "The median of $RUNS runs (ms/s), then each run:"
  cat "$OUT"/run*/hitches.txt | python3 -c '
import re, statistics, sys
runs = {}
for line in sys.stdin:
    m = re.match(r"(.+?): ([0-9.]+) ms/s", line)
    if m:
        runs.setdefault(m.group(1), []).append(float(m.group(2)))
for name, xs in runs.items():
    print(name + ": " + format(statistics.median(xs), ".1f") + "  (" + " ".join(format(x, ".1f") for x in xs) + ")")
'
  exit 0
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

# The hitches, off the film.
hitches "$OUT"
fi
STATUS=${STATUS:-0}

# The audit: Apple's accessibility audit on every screen, light then dark.
# Each line a real defect a person would feel; zero is the bar.
rm -f "$OUT/audit.tsv" "$OUT/audit-waived.tsv"
for LOOK in light dark; do
  xcrun simctl ui "$UDID" appearance "$LOOK"
  TEST_RUNNER_WALK_OUT="$OUT" TEST_RUNNER_AUDIT_LOOK="$LOOK" TEST_RUNNER_CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" \
    xcodebuild "${XCB[@]}" -only-testing:ChintanWalk/ChintanAudit test-without-building > "$OUT/audit-$LOOK.log" 2>&1 || true
done
xcrun simctl ui "$UDID" appearance light

if [ -f "$OUT/audit.tsv" ]; then
  echo "The audit: $(grep -c . "$OUT/audit.tsv" || true) findings (screen, look, kind, element, word)"
  sort "$OUT/audit.tsv"
  # Waived by name in ChintanAudit, each with its reason, kept beside the list.
  echo "Waived: $(cat "$OUT/audit-waived.tsv" 2>/dev/null | grep -c . || true) (audit-waived.tsv)"
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
