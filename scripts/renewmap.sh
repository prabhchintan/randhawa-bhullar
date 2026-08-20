#!/bin/bash
# The map feed's token ritual. scripts/mymap.py reads the maintainer's
# private CloudKit database with a cktool user token, and Apple keeps that
# token short-lived by design (its docs say hours; this project has measured
# about three days). Only an interactive Apple ID sign-in can mint one, so
# renewal cannot be automated away; this script makes it one paste. It opens
# the console, saves what you paste, updates the loop's repository secret,
# and proves the token live with the same query the runner makes.
#
#   renewmap.sh            the ritual itself
#   renewmap.sh --check    quiet probe for launchd; on Tuesday and Saturday
#                          evenings a dead or aging token raises a
#                          notification, because Wednesday and Sunday runs
#                          need a fresh one
#   renewmap.sh --install  install the daily 19:00 probe as a LaunchAgent
set -euo pipefail

TEAM="7FWNAT83XU"
CONTAINER="iCloud.Prabhchintan.Randhawa"
REPO="prabhchintan/randhawa-bhullar"
TOKEN_FILE="$HOME/.config/cktool"
LABEL="com.prabhchintan.maptoken"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

probe() {
  xcrun cktool query-records --team-id "$TEAM" --container-id "$CONTAINER" \
    --environment production --database-type private --zone-name SpaceTime \
    --record-type Moment --limit 1 2>&1
}

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"Randhawa map token\""
}

case "${1:-}" in
  --check)
    # Speak only on the eve of a loop day, and only when the token will not
    # carry it: dead now, missing, or minted more than two days ago. A
    # network hiccup is not worth a word.
    day=$(date +%u)   # Monday 1 .. Sunday 7
    [ "$day" = 2 ] || [ "$day" = 6 ] || exit 0
    if [ ! -f "$TOKEN_FILE" ]; then
      notify "No map token is saved. Run Randhawa/scripts/renewmap.sh before the loop runs tomorrow."
      exit 0
    fi
    out=$(probe) || true
    age=$(( $(date +%s) - $(stat -f %m "$TOKEN_FILE") ))
    if echo "$out" | grep -q "expired or is invalid"; then
      notify "The map token has expired. Run Randhawa/scripts/renewmap.sh before the loop runs tomorrow."
    elif [ "$age" -gt 172800 ]; then
      notify "The map token is over two days old and may not survive tomorrow. Run Randhawa/scripts/renewmap.sh."
    fi
    exit 0
    ;;
  --install)
    SCRIPT="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    mkdir -p "$HOME/Library/LaunchAgents"
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
		<string>$SCRIPT</string>
		<string>--check</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>19</integer>
		<key>Minute</key>
		<integer>0</integer>
	</dict>
</dict>
</plist>
PLIST
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    echo "installed: a quiet probe at 19:00 daily. It speaks only on Tuesday and"
    echo "Saturday evenings, and only when the next run would find a dead token."
    echo "Remove with: launchctl bootout gui/$(id -u) $PLIST && rm $PLIST"
    exit 0
    ;;
  "") ;;
  *)
    echo "usage: renewmap.sh [--check | --install]" >&2
    exit 2
    ;;
esac

echo "Opening the CloudKit Console. Sign in, then: account initials (top"
echo "right), Settings, Tokens, generate a user token, copy it, paste it here."
open "https://icloud.developer.apple.com/dashboard/"
xcrun cktool save-token --type user --method file --force
gh secret set CKTOOL_USER_TOKEN --repo "$REPO" < "$TOKEN_FILE"
if probe > /dev/null 2>&1; then
  echo "Token saved, secret updated, live query verified. Expect roughly three"
  echo "days; the evening probe will say when the next run needs a fresh one."
else
  echo "Token saved and secret updated, but the live query still fails:"
  probe || true
  exit 1
fi
