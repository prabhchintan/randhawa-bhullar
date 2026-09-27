#!/bin/bash
# The house's eyes on the Mac wall (chunk O): build chintan's Mac Catalyst
# destination on yantar, ad hoc signed, open it full screen against the real
# house, and photograph the screen at rest and with the painting alone.
# Prints the picture paths; exits 1 with the errors when the build fails.
# Needs CHINTAN_HOUSE in the environment (the house address).
#
#   bash Chintan/scripts/wall.sh OUTDIR            build, open, photograph
#   bash Chintan/scripts/wall.sh --build OUTDIR    build only
set -uo pipefail
ONLY_BUILD=no
if [ "${1:-}" = "--build" ]; then ONLY_BUILD=yes; shift; fi
OUT=${1:?usage: wall.sh [--build] OUTDIR}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DD=${WALL_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/chintan-mac}
mkdir -p "$OUT"
LOG="$OUT/build.log"
if ! xcodebuild -project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -configuration Debug \
     -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath "$DD" \
     CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
     build > "$LOG" 2>&1; then
  grep -E -B2 -A6 "error:" "$LOG" | tail -80
  echo "BUILD FAILED"
  exit 1
fi
grep -E "warning:" "$LOG" | grep -F "/Chintan/Chintan/" | sort -u | head -10 || true
APP="$DD/Build/Products/Debug-maccatalyst/Chintan.app"
echo "BUILD OK: $APP"
[ "$ONLY_BUILD" = yes ] && exit 0

# The wall opens full screen over whatever is on yantar and the picture is of
# the whole screen: never while someone is at the desk. Touched in the last
# ten minutes, it builds only and says so.
IDLE=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
if [ "${IDLE:-0}" -lt "${WALL_IDLE:-600}" ]; then
  echo "NOT SEEN: yantar was touched ${IDLE:-0} s ago; the wall is not opened over someone at the desk"
  exit 0
fi

# One look: the wall at rest, then the painting alone (as a tap would).
shoot() {
  local name=$1; shift
  pkill -x Chintan 2>/dev/null; sleep 1
  # Through LaunchServices, never the binary itself: run from the runner's
  # launchd context the binary came up with no window on the screen (the
  # 12:15 and 12:29 photos on 2026-09-27 showed HEY and Telegram, not the
  # wall); `open` hands it to the user's GUI session, where the window is.
  open -n "$APP" --args --house "${CHINTAN_HOUSE:-}" --tab jharokha "$@" >"$OUT/$name.log" 2>&1
  sleep "${WALL_WAIT:-12}"
  local pid; pid=$(pgrep -x Chintan | head -1)
  if [ -z "$pid" ]; then
    echo "$name: the app left early; its last words:"; tail -15 "$OUT/$name.log"
  fi
  # The picture must hold the app's own window, or the eyes say so.
  if ! osascript -e 'tell application "System Events" to get name of window 1 of process "Chintan"' >/dev/null 2>&1; then
    echo "$name: NO WINDOW on the screen; the photograph would not be of the wall"
  fi
  screencapture -x "$OUT/$name.png" && echo "$OUT/$name.png"
  pkill -x Chintan 2>/dev/null || true
}
shoot wall
shoot wall-alone --open alone
