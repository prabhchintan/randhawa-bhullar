#!/bin/bash
# The maproom's clock. launchd runs this twice a day on the maintainer's
# Mac: pull this repository, rebuild Maproom if its source changed, read the
# map from CloudKit with the Mac's own iCloud session, summarize it with
# scripts/mymap.py, and push the summary and any @loop notes to the private
# repo. The loop's runner only reads what was pushed here. Raw map data
# stays in ~/Library/Application Support/randhawa-loop/; only counts and
# notes leave this Mac. Install once with: scripts/maproom.sh --install
#
# It speaks only when the silence is getting long: a failure raises a
# notification once the last good feed is two days old, at most once a day.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$HOME/Library/Application Support/randhawa-loop"
APP="$STATE/build/sym/Release/Maproom.app/Contents/MacOS/Maproom"
CLONE="$STATE/repo"
OK_STAMP="$STATE/.maproom-ok"
NAG_STAMP="$STATE/.maproom-nagged"
LABEL="com.prabhchintan.maproom"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

age() { [ -f "$1" ] && echo $(( $(date +%s) - $(stat -f %m "$1") )) || echo 999999999; }

fail() {
  echo "maproom: $1" >&2
  if [ "$(age "$OK_STAMP")" -gt 172800 ] && [ "$(age "$NAG_STAMP")" -gt 72000 ]; then
    /usr/bin/osascript -e "display notification \"$1\" with title \"Maproom\"" || true
    touch "$NAG_STAMP"
  fi
  exit 1
}

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Library/LaunchAgents" "$STATE"
  cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$ROOT/scripts/maproom.sh</string>
	</array>
	<key>StartCalendarInterval</key>
	<array>
		<dict>
			<key>Hour</key>
			<integer>8</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>20</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
	</array>
	<key>StandardOutPath</key>
	<string>$STATE/maproom.log</string>
	<key>StandardErrorPath</key>
	<string>$STATE/maproom.log</string>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "installed: the maproom runs at 08:00 and 20:00 (or on waking past them)."
  echo "Remove with: launchctl bootout gui/$(id -u) $PLIST && rm $PLIST"
  exit 0
fi

echo "== maproom $(date -u +"%FT%TZ")"

# The repository first, so the loop's own improvements to the summary and to
# Maproom reach this Mac without anyone touching it. Offline is fine; run
# what is already here.
git -C "$ROOT" pull --quiet 2>/dev/null || echo "maproom: no pull today, running as is"

# Rebuild when the source moved or the app is missing. Cloud signing renews
# the provisioning profile as a side effect, so the yearly expiry heals here
# too. Built outside the repo tree: iCloud Drive syncs the Desktop and its
# xattrs break codesign.
NEWEST=$(find "$ROOT/Maproom" -type f \( -name "*.swift" -o -name "*.entitlements" -o -name "project.pbxproj" \) -exec stat -f %m {} + | sort -n | tail -1)
if [ ! -x "$APP" ] || [ "$NEWEST" -gt "$(stat -f %m "$APP")" ]; then
  xcodebuild -project "$ROOT/Maproom/Maproom.xcodeproj" -target Maproom -configuration Release \
    -allowProvisioningUpdates "SYMROOT=$STATE/build/sym" "OBJROOT=$STATE/build/obj" build > /dev/null 2>&1 \
    || fail "Maproom would not build; run scripts/maproom.sh in a terminal to see why."
fi

"$APP" || fail "Maproom could not read the map. Is this Mac signed into iCloud?"

if [ ! -d "$CLONE/.git" ]; then
  gh repo clone prabhchintan/randhawa-loop "$CLONE" -- --quiet || fail "Could not clone the private repo."
fi
git -C "$CLONE" pull --quiet --rebase || fail "Could not pull the private repo."
mkdir -p "$CLONE/logs" "$CLONE/inbox"
python3 "$ROOT/scripts/mymap.py" --inbox "$CLONE/inbox" > "$CLONE/logs/$(date -u +%F)-map.txt" \
  || fail "mymap.py failed; run scripts/maproom.sh in a terminal to see why."

cd "$CLONE"
git add logs inbox
if ! git diff --cached --quiet; then
  git -c user.name="The maproom" -c user.email="loop@pulse.prabhchintan.com" commit -q -m "Map feed $(date -u +%F)"
  git push -q 2>/dev/null || { git pull -q --rebase && git push -q; } || fail "Could not push the feed."
fi
touch "$OK_STAMP"
head -1 "$CLONE/logs/$(date -u +%F)-map.txt"
