#!/bin/bash
# The house's eyes on the Mac wall (chunk O): build chintan's Mac Catalyst
# destination on yantar, ad hoc signed, open it full screen against the real
# house, and photograph the screen at rest and with the painting alone.
# Prints the picture paths; exits 1 with the errors when the build fails.
# Needs CHINTAN_HOUSE in the environment (the house address).
#
#   bash Chintan/scripts/wall.sh OUTDIR            build, open, photograph
#   bash Chintan/scripts/wall.sh --build OUTDIR    build only
#   bash Chintan/scripts/wall.sh --sign                the signature of every copy
#                                                     and the last crash reports
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DD=${WALL_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/chintan-mac}

# What the Mac thinks of a copy: its signature, whether it verifies, what
# Gatekeeper says, its entitlements. A launch the system refuses leaves no
# Swift frame, only these (2026-09-27 18:11 to 18:13: Launch Constraint
# Violation, SIGKILL at dyld_start, three times).
sign() {
  local app=$1
  [ -d "$app" ] || { echo "SIGN $app: not there"; return; }
  echo "SIGN $app"
  codesign -dv --verbose=4 "$app" 2>&1 | grep -E "^(Identifier|Format|CodeDirectory|Signature|TeamIdentifier|Runtime|Authority|CDHash)=" | sed 's/^/  /'
  codesign --verify --deep --strict "$app" >/dev/null 2>&1 && echo "  verifies" || echo "  DOES NOT VERIFY: $(codesign --verify --deep --strict "$app" 2>&1 | tail -1)"
  echo "  gatekeeper: $(spctl -a -vv "$app" 2>&1 | head -1)"
  echo "  entitlements: $(codesign -d --entitlements - --xml "$app" 2>/dev/null | plutil -convert json -o - - 2>/dev/null)"
  echo "  display name: $(plutil -extract CFBundleDisplayName raw "$app/Contents/Info.plist" 2>/dev/null)"
}
crashes() {
  local f
  for f in $(ls -t "$HOME"/Library/Logs/DiagnosticReports/Chintan*.ips 2>/dev/null | head -${1:-4}); do
    echo "CRASH $(basename "$f"): $(grep -m1 '"procPath"' "$f" | sed 's/.*: "//; s/",*$//; s#\\/#/#g') $(grep -m1 '"indicator"' "$f" | sed 's/.*"indicator":"\([^"]*\)".*/\1/')"
  done
}
if [ "${1:-}" = "--sign" ]; then
  sign /Applications/Chintan.app
  sign "$DD/Build/Products/Debug-maccatalyst/Chintan.app"
  crashes 6
  # Which copy the Dock and LaunchServices hand him when he clicks chintan.
  echo "DOCK: $(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -i '_CFURLString" = ".*chintan' | sed 's/.*= //' | tr '\n' ' ')"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump 2>/dev/null \
    | grep -E '^path:.*Chintan\.app' | sort -u | sed 's/^/REGISTERED /'
  # What the system said at the last launches, refused or not.
  log show --last "${WALL_LOG:-3h}" --style compact \
    --predicate 'eventMessage CONTAINS[c] "Prabhchintan.Chintan" OR process == "Chintan"' 2>/dev/null \
    | grep -iE "constraint|spawn fail|killed|signature|amfi|terminat|exited|crash|fatal" | tail -${WALL_LOG_LINES:-40}
  exit 0
fi

ONLY_BUILD=no
if [ "${1:-}" = "--build" ]; then ONLY_BUILD=yes; shift; fi
OUT=${1:?usage: wall.sh [--build] OUTDIR}
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
# The crash of 2026-09-27 18:11 (Prab, 18:18: "On the Mac it's crashing"):
# the eyes renamed the dev copy and re-signed it in place after Xcode had
# registered it with LaunchServices, so its code hash no longer matched the
# registration and the system killed it at spawn (Launch Constraint
# Violation, POSIX 162), the dev copy answering to the same bundle id as the
# copy he opens. So a copy is never re-signed or edited after the build, and
# every copy is registered again after it changes.
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREG" -f "$APP" 2>/dev/null
sign "$APP"
[ "$ONLY_BUILD" = yes ] && { echo "NOT INSTALLED: built only"; exit 0; }

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
# in front as it was taken; otherwise the eyes say what was there instead,
# and the build is not installed.
UNSEEN=0
# The wall's own drawing of its window (SIGUSR1, sprint 58): taken beside
# every photograph, so a look still has a picture of the wall when the
# display cannot be photographed. Said as SELF, never as CONFIRMED; it does
# not count toward installing the copy.
selfphoto() {
  local name=$1 before n waited=0
  [ -n "$STATE_OUT" ] && [ -n "$(pgrep -x Chintan)" ] || return
  before=$(grep -c '^wall-photo ' "$STATE_OUT")
  pkill -USR1 -x Chintan 2>/dev/null || return
  while [ "$waited" -lt 10 ]; do
    sleep 1; waited=$((waited + 1))
    n=$(grep -c '^wall-photo ' "$STATE_OUT")
    [ "$n" -gt "$before" ] && break
  done
  if [ "${n:-0}" -le "$before" ]; then echo "$OUT/$name-self.jpg NOT DRAWN: the wall did not answer"; return; fi
  if grep '^wall-photo ' "$STATE_OUT" | tail -1 | cut -d' ' -f2 | base64 -D > "$OUT/$name-self.jpg" 2>/dev/null \
     && [ -s "$OUT/$name-self.jpg" ] && [ "$(head -c 2 "$OUT/$name-self.jpg" | xxd -p)" = ffd8 ]; then
    echo "$OUT/$name-self.jpg SELF: the wall's own drawing"
  else
    rm -f "$OUT/$name-self.jpg"; echo "$OUT/$name-self.jpg NOT DRAWN: the wall said none"
  fi
}
photo() {
  local name=$1 s
  selfphoto "$name"
  s=$(state)
  screencapture -x "$OUT/$name.png" || { UNSEEN=$((UNSEEN + 1)); return; }
  case "$s" in
    full) echo "$OUT/$name.png CONFIRMED" ;;
    window) echo "$OUT/$name.png NOT CONFIRMED: the window is there but not full screen in front"; UNSEEN=$((UNSEEN + 1)) ;;
    *) echo "$OUT/$name.png NOT CONFIRMED: NO WINDOW, the photograph is not of the wall"; UNSEEN=$((UNSEEN + 1)) ;;
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
  # 12:15 and 12:29 photos on 2026-09-27 showed other windows, not the
  # wall); `open` hands it to the user's GUI session, where the window is.
  local t0; t0=$(date +%s)
  rm -f $STATE_GLOB
  STATE_OUT="$OUT/$name.state"; : > "$STATE_OUT"
  open -n --stdout "$STATE_OUT" "$APP" --args --house "${CHINTAN_HOUSE:-}" --tab jharokha --say-window "$@" >"$OUT/$name.log" 2>&1
  local s=none waited=0
  while [ "$waited" -lt "${WALL_LIMIT:-60}" ]; do
    s=$(state)
    [ "$s" = full ] && break
    [ "$waited" -gt 5 ] && [ -z "$(pgrep -x Chintan)" ] && break
    sleep 1; waited=$(( $(date +%s) - t0 ))
  done
  if [ "$s" = full ]; then
    echo "$name: full screen $(( $(date +%s) - t0 )) s after open"
  else
    echo "$name: not full screen after $waited s (last seen: $s)"
  fi
  if [ -z "$(pgrep -x Chintan)" ]; then
    echo "$name: THE APP LEFT EARLY; its last words:"; tail -15 "$OUT/$name.log"
    crashes 1
    UNSEEN=$((UNSEEN + 1))
    return
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
  grep -E '^wall-(step|poll) ' "$STATE_OUT" | sed "s/^/$name: /"
  if [ -z "$(pgrep -x Chintan)" ]; then
    echo "$name: THE APP LEFT during the look"; crashes 1; UNSEEN=$((UNSEEN + 1))
  fi
  pkill -x Chintan 2>/dev/null || true
}

# The wall itself, whatever the house says.
shoot wall --step wall
# The click round (Prab, 18:18): from the wall, a click every 10 s, each
# step photographed 6 s after its click: bare, basic, detailed, the wall.
shoot click-wall --at 17 click-bare --at 27 click-basic --at 37 click-detailed --at 47 click-back \
  --step wall --clicks 10
# The open as he will see it: the step the house's word names, then one turn
# of the house's loop 30 s in, photographed after its crossfade; the board
# read every 10 s through it, each read said (same, changed or unheard).
shoot open --at 38 open-turned --turn 30 --poll 10
# The board's column with an invented week, so its shape is seen on any day.
shoot column --step wall --open day

# The copy he opens is replaced only after a look with every photograph
# confirmed and the app standing throughout; then the new copy in
# Applications is opened and must be seen standing too, or the old comes back.
if [ "$UNSEEN" -gt 0 ]; then
  echo "NOT INSTALLED: $UNSEEN photographs not confirmed; /Applications/Chintan.app left as it was"
  exit 0
fi
if [ -d /Applications ] && [ -w /Applications ]; then
  rm -rf /Applications/Chintan.app.new /Applications/Chintan.app.old
  cp -R "$APP" /Applications/Chintan.app.new || { echo "NOT INSTALLED: the copy failed"; exit 0; }
  [ -d /Applications/Chintan.app ] && mv /Applications/Chintan.app /Applications/Chintan.app.old
  mv /Applications/Chintan.app.new /Applications/Chintan.app
  "$LSREG" -f /Applications/Chintan.app 2>/dev/null
  # The dev copy leaves LaunchServices, so a click on chintan finds only his.
  DEV=$APP; APP=/Applications/Chintan.app
  "$LSREG" -u "$DEV" 2>/dev/null
  sign "$APP"
  shoot installed --step wall
  if [ "$UNSEEN" -gt 0 ]; then
    rm -rf /Applications/Chintan.app
    if [ -d /Applications/Chintan.app.old ]; then
      mv /Applications/Chintan.app.old /Applications/Chintan.app
      "$LSREG" -f /Applications/Chintan.app 2>/dev/null
    fi
    echo "NOT INSTALLED: the copy in Applications was not seen standing; the old one is back"
  else
    rm -rf /Applications/Chintan.app.old
    echo "INSTALLED: /Applications/Chintan.app, seen standing"
  fi
fi
