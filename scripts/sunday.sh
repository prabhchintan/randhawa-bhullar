#!/bin/zsh
# The Sunday loop entry point. launchd runs this at 09:00 every Sunday (a
# missed run fires on the next wake). It pulls, hands loop/SUNDAY.md to a
# headless Claude Code session that may act without asking, and logs
# everything to ~/Library/Logs/randhawa-sunday/.
set -u
REPO="$HOME/Desktop/prabhchintan.com/Randhawa"
SITE="$HOME/Desktop/prabhchintan.com"
LOGDIR="$HOME/Library/Logs/randhawa-sunday"
STAMP="$(date +%F)"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/$STAMP.log"
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

{
  echo "== Sunday loop $(date) =="
  cd "$SITE" && git pull --ff-only
  cd "$REPO" && git pull --ff-only
  # caffeinate keeps the Mac awake for the length of the run and no longer.
  caffeinate -i claude -p "$(cat "$REPO/loop/SUNDAY.md")" \
    --dangerously-skip-permissions \
    --output-format text
  echo "== done $(date) exit $? =="
} >> "$LOG" 2>&1
