#!/bin/bash
# yantar as the builder for chintan, the private app.
#
# Registers this Mac as a self-hosted GitHub Actions runner for
# prabhchintan/randhawa-bhullar (label: yantar), installed as a launchd
# service so it survives a restart, and sets the repository variable that
# turns the nightly job in .github/workflows/chintan.yml on. Free, faster
# than the GitHub Macs, and it keeps the loop's hosted minutes for the
# public apps. Run once, at the keyboard, in Terminal:
#
#     bash scripts/yantar-runner.sh
#
# Needs: Xcode itself (not only the command line tools), and gh logged in
# as the maintainer (it is; the maproom uses it). The password is asked once,
# for the launchd service and for the nightly wake before the 03:00 run.
# Undo: cd ~/actions-runner && ./svc.sh stop && ./svc.sh uninstall &&
# ./config.sh remove --token "$(gh api -X POST repos/prabhchintan/randhawa-bhullar/actions/runners/remove-token --jq .token)"
set -euo pipefail

REPO=prabhchintan/randhawa-bhullar
DIR="$HOME/actions-runner"
NAME=yantar

say() { printf '\n== %s\n' "$*"; }

say "Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is not answering. Install Xcode from the App Store, open it once, then:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -license accept" >&2
  exit 1
fi
xcodebuild -version | head -1

say "gh"
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in; run: gh auth login" >&2; exit 1; }

say "The runner"
case "$(uname -m)" in
  arm64) ARCH=osx-arm64 ;;
  *) ARCH=osx-x64 ;;
esac
VER=$(gh api repos/actions/runner/releases/latest --jq .tag_name | sed 's/^v//')
mkdir -p "$DIR" && cd "$DIR"
if [ ! -x ./config.sh ]; then
  curl -fsSL -o runner.tar.gz "https://github.com/actions/runner/releases/download/v$VER/actions-runner-$ARCH-$VER.tar.gz"
  tar xzf runner.tar.gz && rm runner.tar.gz
fi
echo "runner $VER ($ARCH) in $DIR"

if [ -f .runner ]; then
  echo "already registered as $(python3 -c 'import json;print(json.load(open(".runner"))["agentName"])' 2>/dev/null || echo "$NAME")"
else
  TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)
  ./config.sh --url "https://github.com/$REPO" --token "$TOKEN" \
    --name "$NAME" --labels "$NAME" --work _work --unattended --replace
fi

say "The service (launchd, asks for the password)"
if ./svc.sh status 2>/dev/null | grep -q "^Started"; then
  echo "already running"
else
  ./svc.sh install 2>/dev/null || true
  ./svc.sh start
fi
./svc.sh status 2>/dev/null | grep -A1 "Started" || true

say "The nightly wake (02:55, before the 03:00 build)"
sudo pmset repeat wakeorpoweron MTWRFSU 02:55:00
pmset -g sched | head -3

say "The switch"
gh variable set CHINTAN_RUNNER --body yantar --repo "$REPO"
echo "CHINTAN_RUNNER=yantar: the nightly job now runs here"

say "A first run, to prove it"
gh workflow run chintan.yml -f runner=yantar --repo "$REPO"
echo "watch it: gh run watch --repo $REPO"
echo "done. The house sees the runner as online at github.com/$REPO/settings/actions/runners"
