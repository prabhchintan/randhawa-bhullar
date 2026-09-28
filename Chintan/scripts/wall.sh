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
# The build he opens is the newest one (Prab, 2026-09-27 13:14: the Debug
# build in DerivedData was ahead of the copy in Applications): every green
# build replaces /Applications/Chintan.app, so Spotlight and the Dock open
# the latest wall.
if [ -d /Applications ] && [ -w /Applications ]; then
  rm -rf /Applications/Chintan.app.new && cp -R "$APP" /Applications/Chintan.app.new \
    && rm -rf /Applications/Chintan.app && mv /Applications/Chintan.app.new /Applications/Chintan.app \
    && echo "INSTALLED: /Applications/Chintan.app"
  # The dev copy shows as "chintan dev" in Spotlight and the Dock (Prab, 13:26:
  # Applications is production, the other is the house's), display name only,
  # so the process and bundle names the eyes look for stay the same.
  plutil -replace CFBundleDisplayName -string "chintan dev" "$APP/Contents/Info.plist" \
    && codesign -f -s - --deep --preserve-metadata=entitlements "$APP" >"$OUT/resign.log" 2>&1 \
    || { echo "DEV COPY NOT RESIGNED:"; tail -3 "$OUT/resign.log"; }
  codesign --verify --deep --strict "$APP" >>"$OUT/resign.log" 2>&1 \
    || { echo "DEV COPY SIGNATURE BROKEN:"; tail -3 "$OUT/resign.log"; }
  # The eyes open the copy he opens (2026-09-27 18:12: the re-signed dev copy
  # failed at spawn, "Launchd job spawn failed", 162, three times running).
  [ -d /Applications/Chintan.app ] && APP=/Applications/Chintan.app
fi
[ "$ONLY_BUILD" = yes ] && exit 0

# The wall opens full screen over whatever is on yantar and the picture is of
# the whole screen: never while someone is at the desk. Touched in the last
# ten minutes, it builds only and says so.
IDLE=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
if [ "${IDLE:-0}" -lt "${WALL_IDLE:-600}" ]; then
  echo "NOT SEEN: yantar was touched ${IDLE:-0} s ago; the wall is not opened over someone at the desk"
  exit 0
fi

# Whether chintan's window is on the screen, full screen and in front:
# prints "full", "window" (there, not yet full screen or not in front) or "none".
# The runner's session sees no windows: System Events said "none" and the
# window server's list came back empty over a full screen wall (2026-09-27).
# So the wall says it itself (`--say-window`): Caches/wall-state in its
# sandbox, rewritten twice a second while it runs; older than 3 s is none.
STATE_GLOB="$HOME/Library/Containers/*Chintan*/Data/Library/Caches/wall-state"
# The runner is not let into the wall's container (2026-09-27, sprint 45:
# every photograph said NO WINDOW over the wall), so the wall also says each
# change on its standard output, which `open --stdout` writes to STATE_OUT;
# its last line counts while the app runs.
STATE_OUT=""
state() {
  local f
  if [ -n "$STATE_OUT" ] && [ -s "$STATE_OUT" ] && [ -n "$(pgrep -x Chintan)" ]; then
    f=$(grep '^wall-state ' "$STATE_OUT" | tail -1 | cut -d' ' -f2)
    [ -n "$f" ] && { echo "$f"; return; }
  fi
  for f in $STATE_GLOB; do
    [ -f "$f" ] || continue
    [ $(( $(date +%s) - $(stat -f %m "$f") )) -le 3 ] || continue
    [ -n "$(pgrep -x Chintan)" ] || continue
    cat "$f"; return
  done
  echo none
}

# One photograph, called confirmed only when the window stood full screen
# in front as it was taken; otherwise the eyes say what was there instead.
photo() {
  local name=$1 s
  s=$(state)
  screencapture -x "$OUT/$name.png" || return
  case "$s" in
    full) echo "$OUT/$name.png CONFIRMED" ;;
    window) echo "$OUT/$name.png NOT CONFIRMED: the window is there but not full screen in front" ;;
    *) echo "$OUT/$name.png NOT CONFIRMED: NO WINDOW, the photograph is not of the wall" ;;
  esac
}

# One look: open, wait for the full screen turn and time it, let the painting
# settle, photograph; `--at S NAME` more photographs S seconds after the open.
shoot() {
  local name=$1; shift
  local later=()
  while [ "${1:-}" = "--at" ]; do later+=("$2" "$3"); shift 3; done
  pkill -x Chintan 2>/dev/null; sleep 1
  # Through LaunchServices, never the binary itself: run from the runner's
  # launchd context the binary came up with no window on the screen (the
  # 12:15 and 12:29 photos on 2026-09-27 showed HEY and Telegram, not the
  # wall); `open` hands it to the user's GUI session, where the window is.
  local t0; t0=$(date +%s)
  rm -f $STATE_GLOB
  STATE_OUT="$OUT/$name.state"; : > "$STATE_OUT"
  open -n --stdout "$STATE_OUT" "$APP" --args --house "${CHINTAN_HOUSE:-}" --tab jharokha --say-window "$@" >"$OUT/$name.log" 2>&1
  local s=none waited=0
  while [ "$waited" -lt "${WALL_LIMIT:-60}" ]; do
    s=$(state)
    [ "$s" = full ] && break
    sleep 1; waited=$(( $(date +%s) - t0 ))
  done
  if [ "$s" = full ]; then
    echo "$name: full screen $(( $(date +%s) - t0 )) s after open"
  else
    echo "$name: not full screen after ${WALL_LIMIT:-60} s (last seen: $s)"
  fi
  if [ -z "$(pgrep -x Chintan)" ]; then
    echo "$name: the app left early; its last words:"; tail -15 "$OUT/$name.log"
  fi
  # The picture comes down and fades in after the turn.
  sleep "${WALL_SETTLE:-6}"
  photo "$name"
  local i=0
  while [ "$i" -lt "${#later[@]}" ]; do
    local at=${later[$i]} shot=${later[$((i + 1))]}
    local now; now=$(date +%s)
    [ $(( t0 + at - now )) -gt 0 ] && sleep $(( t0 + at - now ))
    photo "$shot"
    i=$((i + 2))
  done
  pkill -x Chintan 2>/dev/null || true
}
shoot wall
shoot wall-alone --open alone
# The wall turning on its own: a turn 30 s after launch for the eyes,
# photographed before, twice inside the crossfade, and after.
shoot wall-turn-before --at 32 wall-turn-mid --at 33 wall-turn-mid2 --at 38 wall-turn-after \
  --open alone --turn 30
