#!/bin/bash
# The house's eyes on chintan, the private app, run on the Mac that builds it:
# build for the simulator (incremental, one derived-data folder kept between
# looks), launch every tab against the real house, photograph it in light
# and dark. Prints the picture paths; exits 1 with the errors when the build
# fails. Needs CHINTAN_HOUSE in the environment (the house address).
#
#   bash Chintan/scripts/see.sh OUTDIR [tab ...]     tabs: jharokha board study
#                                                    (board@N: the Nth thing opened;
#                                                    board@held: the heading held;
#                                                    board@onword: held, the thumb
#                                                    on its word; board@word: open;
#                                                    jharokha@tN: Home's Nth thing held;
#                                                    jharokha@cut: the phone's own cut;
#                                                    jharokha@empty: a day with nothing;
#                                                    jharokha@day: an invented day of
#                                                    three things (tN holds one of
#                                                    them when the real day is empty);
#                                                    jharokha@label: the label held;
#                                                    jharokha@onword: held, the thumb
#                                                    on its word for the house;
#                                                    jharokha@word: that word open;
#                                                    jharokha@newcomers: the book read
#                                                    as if last opened a month ago;
#                                                    jharokha@book: so, the book open;
#                                                    jharokha@person: the book open on
#                                                    whoever read the most pages;
#                                                    jharokha@alone: the painting alone;
#                                                    jharokha@alone-back: so, then
#                                                    the wall back after 2 s;
#                                                    jharokha@alone-yesterday: alone,
#                                                    then a swipe back to a staged
#                                                    yesterday; ...-back: then the
#                                                    wall back over it;
#                                                    jharokha@alone-kept: alone,
#                                                    held, the house's yes staged;
#                                                    jharokha@alone-keep: so, the
#                                                    house asked for real;
#                                                    study@held: darban's name held;
#                                                    study@onword: held, the thumb
#                                                    on its word for the house;
#                                                    study@word: that word open;
#                                                    settings: the Settings sheet;
#                                                    settings@on: every sense on;
#                                                    settings@senses: so, opened
#                                                    on The senses;
#                                                    settings@quiet: there, off;
#                                                    settings@move: every sense on,
#                                                    opened at the foot, How you move;
#                                                    settings@still: there, off;
#                                                    settings@apps: every sense on,
#                                                    opened on Which app you open;
#                                                    settings@foot: opened at the
#                                                    foot, on the build's colophon;
#                                                    study@waiting: a word left
#                                                    waiting, taken up again;
#                                                    study@hawa: hawa's room
#                                                    empty, a word answered
#                                                    by a stand-in, put away
#                                                    and back three times, the
#                                                    words heard counted, then
#                                                    chintan's room;
#                                                    study@in-hawa: hawa's room
#                                                    as it stands, nothing said)
#                                                    A tab ending -away (jharokha@feed-away,
#                                                    jharokha@feed-like-away,
#                                                    jharokha@feed-stale-away): the
#                                                    house address refuses, so the
#                                                    feed takes the road; needs --signed.
#   bash Chintan/scripts/see.sh --signed OUTDIR ...  signed to run locally, so the app
#                                                    has a Keychain in the simulator
#   bash Chintan/scripts/see.sh --walk [OUTDIR]      the walk instead (walk.sh)
#   bash Chintan/scripts/see.sh --hitches [--sample] OUTDIR [RUNS]
#                                                    the hitch numbers alone, RUNS
#                                                    times (walk.sh --hitches)
#   bash Chintan/scripts/see.sh --wall [--build] OUTDIR
#                                                    the Mac wall instead (wall.sh)
#   bash Chintan/scripts/see.sh --widget OUTDIR      the widget in the home screen's
#                                                    gallery and placed (widget.sh)
#   bash Chintan/scripts/see.sh --large OUTDIR ...   at the largest accessibility
#                                                    text size, then back to normal
#   bash Chintan/scripts/see.sh --resume OUTDIR [RUNS]
#                                                    the return to the front, sampled
#                                                    (OUTDIR/resumeN.txt, resume.txt)
#   bash Chintan/scripts/see.sh --evidence OUTDIR [tab ...]
#                                                    the stills, then the evidence the
#                                                    review reads beside them: the look
#                                                    door's answer, the walk (OUTDIR/walk:
#                                                    contact sheets, hitch lines, audit
#                                                    list), the wall's own drawings
#                                                    (OUTDIR/wall) when the wall changed
#                                                    since origin/main (SEE_WALL=1 forces
#                                                    it), and EVIDENCE.txt naming each
set -euo pipefail
if [ "${1:-}" = "--evidence" ]; then
  shift
  OUT=${1:?usage: see.sh --evidence OUTDIR [tab ...]}
  HERE=$(cd "$(dirname "$0")" && pwd)
  ROOT=$(cd "$HERE/../.." && pwd)
  bash "$HERE/see.sh" "$@" || exit 1
  EV="$OUT/EVIDENCE.txt"
  {
    echo "The look folder, $(date '+%Y-%m-%d %H:%M'), at $(git -C "$ROOT" rev-parse --short HEAD)"
    echo "Stills: $(ls "$OUT"/*.png 2>/dev/null | grep -c . || true)"
  } > "$EV"
  # The look door: what the house says to GET /v1/look, so the review knows
  # whether the stills are the house's look or the shipped one.
  python3 - "$OUT/look-door.json" >> "$EV" <<'PY'
import os, sys, urllib.request, urllib.error
house = os.environ.get("CHINTAN_HOUSE", "")
url = (house if "://" in house else "http://" + house).rstrip("/") + "/v1/look"
try:
    with urllib.request.urlopen(url, timeout=10) as r:
        body = r.read()
    open(sys.argv[1], "wb").write(body)
    print(f"Look door: {r.status}, {len(body)} bytes kept in look-door.json; the stills are the house's look")
except urllib.error.HTTPError as e:
    print(f"Look door: {e.code}; the stills are the shipped look")
except Exception as e:
    print(f"Look door: no answer ({type(e).__name__}); the stills are the kept or shipped look")
PY
  # The walk: film, contact sheets, hitch lines and audit list in one run.
  WALK_STATUS=0
  bash "$HERE/walk.sh" "$OUT/walk" > "$OUT/walk.txt" 2>&1 || WALK_STATUS=$?
  {
    if [ "$WALK_STATUS" -ne 0 ]; then echo "Walk: FAILED ($WALK_STATUS), its words in walk.txt"; else echo "Walk: done"; fi
    echo "Contact sheets: $(ls "$OUT"/walk/sheets/*.png 2>/dev/null | grep -c . || true) (walk/sheets)"
    echo "Hitch lines (walk/hitches.txt, ms/s, under 5 good, over 10 a jank):"
    sed 's/^/  /' "$OUT/walk/hitches.txt" 2>/dev/null || echo "  none"
    if [ -f "$OUT/walk/audit.tsv" ]; then
      echo "Audit: $(grep -c . "$OUT/walk/audit.tsv" || true) findings (walk/audit.tsv), $(grep -c . "$OUT/walk/audit-waived.tsv" 2>/dev/null || echo 0) waived"
      sort "$OUT/walk/audit.tsv" | sed 's/^/  /'
    else
      echo "Audit: did not run (walk/audit-light.log)"
    fi
  } >> "$EV"
  # The wall: drawn again only when a file it is built from changed since
  # the last push (a Swift file with Mac code in it, or the wall's eyes).
  CHANGED=$( { git -C "$ROOT" diff --name-only origin/main...HEAD 2>/dev/null; git -C "$ROOT" diff --name-only HEAD; } | sort -u)
  WALLED=""
  for f in $CHANGED; do
    case "$f" in
      Chintan/scripts/wall.sh) WALLED="$WALLED $f" ;;
      Chintan/Chintan/*.swift) [ -f "$ROOT/$f" ] && grep -q macCatalyst "$ROOT/$f" && WALLED="$WALLED $f" ;;
    esac
  done
  if [ -n "$WALLED" ] || [ "${SEE_WALL:-}" = 1 ]; then
    bash "$HERE/wall.sh" "$OUT/wall" > "$OUT/wall.txt" 2>&1 || true
    {
      echo "Wall: changed (${WALLED# }${SEE_WALL:+, forced}); its words in wall.txt"
      grep -E "SELF|CONFIRMED|NOT DRAWN|BUILD FAILED" "$OUT/wall.txt" | sed "s#$OUT/##; s/^/  /" || echo "  no drawing said"
    } >> "$EV"
  else
    echo "Wall: unchanged since origin/main, not drawn" >> "$EV"
  fi
  cat "$EV"
  exit 0
fi
if [ "${1:-}" = "--walk" ]; then
  shift
  exec bash "$(dirname "$0")/walk.sh" "$@"
fi
if [ "${1:-}" = "--hitches" ]; then
  shift
  exec bash "$(dirname "$0")/walk.sh" --hitches "$@"
fi
if [ "${1:-}" = "--wall" ]; then
  shift
  exec bash "$(dirname "$0")/wall.sh" "$@"
fi
if [ "${1:-}" = "--widget" ]; then
  shift
  exec bash "$(dirname "$0")/widget.sh" "$@"
fi
if [ "${1:-}" = "--signed" ]; then
  SEE_SIGN=1
  shift
fi
RESUME=""
if [ "${1:-}" = "--resume" ]; then
  RESUME=1
  shift
fi
TEXT=large
if [ "${1:-}" = "--large" ]; then
  TEXT=accessibility-extra-extra-extra-large
  shift
fi
OUT=${1:?usage: see.sh OUTDIR [tab ...]}; shift
TABS=${*:-jharokha board study}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DD=${SEE_DERIVED:-$HOME/Library/Developer/Xcode/DerivedData/chintan-see}
DEVICE=${SEE_DEVICE:-iPhone 16 Pro}
mkdir -p "$OUT"
LOG="$OUT/build.log"
# --signed (or SEE_SIGN=1): signed to run locally, so the app has a Keychain
# of its own in the simulator (the feed's road lives there); unsigned, every
# write fails.
SIGN=(CODE_SIGNING_ALLOWED=NO)
[ "${SEE_SIGN:-}" = 1 ] && SIGN=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
if ! xcodebuild -project "$ROOT/Chintan/Chintan.xcodeproj" -scheme Chintan -configuration Debug \
     -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
     -derivedDataPath "$DD" "${SIGN[@]}" CHINTAN_HOUSE="${CHINTAN_HOUSE:-}" build > "$LOG" 2>&1; then
  grep -E -B2 -A6 "error:" "$LOG" | tail -80
  echo "BUILD FAILED"
  exit 1
fi
grep -E "warning:" "$LOG" | grep -F "/Chintan/" | sort -u | head -10 || true
UDID=$(xcrun simctl list devices available -j | DEVICE="$DEVICE" python3 -c '
import json, os, sys
for devs in json.load(sys.stdin)["devices"].values():
    for d in devs:
        if d["name"] == os.environ["DEVICE"]:
            print(d["udid"]); raise SystemExit
sys.exit("no simulator called " + os.environ["DEVICE"])')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# The Debug app by name: the hitch walk's --release leaves a Release one beside it.
APP="$DD/Build/Products/Debug-iphonesimulator/Chintan.app"
xcrun simctl install "$UDID" "$APP"
xcrun simctl ui "$UDID" content_size "$TEXT"
# --resume: the return to the front, the moment the phone's MetricKit times.
# Each run launches Home with the feed open and every card's picture drawn,
# as after a long scroll (SEE_RESUME_OPEN names another --open word), lets
# the shelf and the cards come down, puts the app behind
# Settings, then brings it back while sampling it: OUT/resumeN.txt holds the
# stacks, and one line says the frames late after the return and the app's
# memory before and after.
if [ -n "$RESUME" ]; then
  RUNS=${1:-1}
  DATA=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data)
  for n in $(seq 1 "$RUNS"); do
    xcrun simctl launch --terminate-running-process "$UDID" Prabhchintan.Chintan \
      --house "${CHINTAN_HOUSE:-}" --tab jharokha --open "${SEE_RESUME_OPEN:-feed-all}" --hitches > /dev/null
    sleep 25
    PID=$(pgrep -f "Chintan.app/Chintan" | head -1)
    xcrun simctl launch "$UDID" com.apple.Preferences > /dev/null
    sleep 8
    # The footprint iOS judges an app by (decoded pictures included), as
    # the phone's MetricKit counts peak memory; resident size misses them.
    footprint "$PID" > "$OUT/footprint$n.txt" 2>&1 || true
    BEFORE=$(ps -o rss= -p "$PID" | awk '{printf "%.0f", $1/1024}')
    FOOT=$(grep -m1 -iE "footprint:" "$OUT/footprint$n.txt" | sed 's/^ *//' || true)
    echo "resume $n: behind, $FOOT" | tee -a "$OUT/resume.txt"
    /usr/bin/sample "$PID" 4 1 -file "$OUT/resume$n.txt" > /dev/null 2>&1 &
    SP=$!
    sleep 0.3
    T0=$(python3 -c 'import time; print(time.time())')
    xcrun simctl launch "$UDID" Prabhchintan.Chintan > /dev/null
    wait "$SP" || true
    sleep 2
    AFTER=$(ps -o rss= -p "$PID" | awk '{printf "%.0f", $1/1024}')
    footprint "$PID" > "$OUT/footprint$n-back.txt" 2>&1 || true
    echo "resume $n: back, $(grep -m1 -iE "footprint:" "$OUT/footprint$n-back.txt" | sed 's/^ *//' || true), $(grep -m1 phys_footprint_peak "$OUT/footprint$n-back.txt" | sed 's/^ *//' || true)" | tee -a "$OUT/resume.txt"
    awk -v t="$T0" -v n="$n" -v b="$BEFORE" -v a="$AFTER" '
      $1 >= t && $1 <= t + 6 { late += $2; if ($2 > worst) worst = $2; k++ }
      END { printf "resume %d: %d frames late, %.0f ms in all, worst %.0f ms; memory %s MB behind, %s MB back\n", n, k, late, worst, b, a }' \
      "$DATA/Library/Caches/hitches.tsv" | tee -a "$OUT/resume.txt"
  done
  xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
  exit 0
fi
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  # The switch settles before the first tab of a mode is launched; the
  # simulator says back which mode it holds, and a look in the wrong one stops.
  sleep 2
  HELD=$(xcrun simctl ui "$UDID" appearance)
  [ "$HELD" = "$mode" ] || { echo "the simulator held $HELD, not $mode"; exit 1; }
  for tab in $TABS; do
    xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
    # A tab written board@N is the board with its Nth thing opened on launch.
    EXTRA=()
    # settings is the study with its Settings sheet open.
    NAME=${tab%@*}
    case "$tab" in *@*) EXTRA=(--open "${tab#*@}") ;; esac
    [ "$NAME" = settings ] && NAME=study && EXTRA=(--settings)
    # settings@senses: as settings@on, the sheet opened on The senses;
    # settings@quiet: opened there with nothing on.
    case "$tab" in settings@senses|settings@quiet) EXTRA=(--settings --open senses) ;; esac
    # settings@move: as settings@on, opened at the foot; settings@still: there, off.
    case "$tab" in settings@move|settings@still) EXTRA=(--settings --open motion) ;; esac
    # settings@apps: as settings@on, opened on Which app you open.
    case "$tab" in settings@apps) EXTRA=(--settings --open apps) ;; esac
    # settings@foot: opened at the very foot, on the build's colophon.
    case "$tab" in settings@foot) EXTRA=(--settings --open foot) ;; esac
    # study@in-hawa: hawa's room as the phone holds it, nothing said.
    case "$tab" in study@in-hawa) EXTRA=(--open hawa) ;; esac
    # A tab ending @look (board@look): drawn in the look at CHINTAN_LOOK
    # (/tmp/see/look.json unless named), a file shaped as /v1/look, so a
    # look the house has not served is seen.
    case "$tab" in *@look) EXTRA=(--look "${CHINTAN_LOOK:-/tmp/see/look.json}") ;; esac
    # A tab ending -away (jharokha@feed-away, jharokha@feed-like-away): the
    # same look with a house address that refuses, so the feed takes the road.
    HOUSE_ARG=${CHINTAN_HOUSE:-}
    case "$tab" in *-away) HOUSE_ARG=127.0.0.1:9; T=${tab%-away}; EXTRA=(--open "${T#*@}") ;; esac
    # settings@on: location granted always, telling, a place heard, and the
    # phone's word, Health and motion heard. The app
    # the eyes launch never monitors and never posts, so the house hears nothing.
    if [ "$tab" = settings@on ] || [ "$tab" = settings@senses ] || [ "$tab" = settings@move ] || [ "$tab" = settings@apps ]; then
      xcrun simctl privacy "$UDID" grant location-always Prabhchintan.Chintan
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan where.telling -bool YES
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan where.place home
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan where.heard -date "$(date -u '+%Y-%m-%d %H:%M:%S +0000')"
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan phone.heard -date "$(date -u '+%Y-%m-%d %H:%M:%S +0000')"
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan health.telling -bool YES
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan health.heard -date "$(date -u '+%Y-%m-%d %H:%M:%S +0000')"
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan motion.telling -bool YES
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan motion.heard -date "$(date -u '+%Y-%m-%d %H:%M:%S +0000')"
    fi
    # study@waiting: darban's room with a word left waiting when the app was
    # closed, its id one the house never gave; photographed as the study
    # opens and again once the house has said. The room is put back after.
    if [ "$tab" = study@waiting ]; then
      EXTRA=(--open darban)
      DATA=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data)
      STAGE_DIR="$DATA/Library/Application Support" python3 - <<'PY'
import json, os, shutil, time, uuid
d = os.environ["STAGE_DIR"]
os.makedirs(d, exist_ok=True)
for f in ("conversation-darban.json", "waiting.json"):
    p = os.path.join(d, f)
    if os.path.exists(p): shutil.copy(p, p + ".kept")
now = time.time() - 978307200
word = str(uuid.uuid4()).upper()
room = [
    {"id": str(uuid.uuid4()).upper(), "text": "Is the round done?", "fromHouse": False, "date": now - 7300},
    {"id": str(uuid.uuid4()).upper(), "text": "Done at nine, nothing raised.", "fromHouse": True, "date": now - 7280},
    {"id": word, "text": "Anything from the library?", "fromHouse": False, "date": now - 200},
]
json.dump(room, open(os.path.join(d, "conversation-darban.json"), "w"))
json.dump({"darban": {"id": "eyes-" + str(uuid.uuid4()), "word": word, "since": now - 200}},
          open(os.path.join(d, "waiting.json"), "w"))
PY
    fi
    # jharokha@alone-yesterday: a yesterday staged from the shelf's last
    # picture under an id of its own, taken away after the look.
    case "$tab" in jharokha@alone-yesterday*)
      DATA=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data)
      STAGE_DIR="$DATA/Library/Caches/paintings" python3 - <<'PY'
import json, os, shutil
d = os.environ["STAGE_DIR"]
last = json.load(open(os.path.join(d, "shelf.json")))[-1]
key = lambda p: (p.get("id") or "today") + ("-" + p["fit"] if p.get("fit") else "")
kept = dict(last, id="eyes-yesterday")
shutil.copy(os.path.join(d, key(last) + ".jpg"), os.path.join(d, key(kept) + ".jpg"))
json.dump(kept, open(os.path.join(d, "yesterday.json"), "w"))
PY
      ;;
    esac
    xcrun simctl launch "$UDID" Prabhchintan.Chintan --house "$HOUSE_ARG" --tab "$NAME" "${EXTRA[@]+"${EXTRA[@]}"}" >/dev/null
    if [ "$tab" = study@waiting ]; then
      sleep 1.5
      xcrun simctl io "$UDID" screenshot "$OUT/$tab-opening-$mode.png" >/dev/null
    fi
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$tab-$mode.png" >/dev/null
    # After an -away look: how many marks the phone still holds unsent.
    case "$tab" in *-away)
      sleep 3
      FEED="$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data)/Library/Application Support/feed.json"
      python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("pending", [])))' "$FEED" > "$OUT/$tab-$mode.pending" 2>/dev/null || true
      ;;
    esac
    case "$tab" in jharokha@alone-yesterday*)
      xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
      rm -f "$DATA/Library/Caches/paintings/yesterday.json" "$DATA/Library/Caches/paintings/eyes-yesterday"*.jpg
      xcrun simctl spawn "$UDID" defaults delete Prabhchintan.Chintan gallery.chosen 2>/dev/null || true
      ;;
    esac
    if [ "$tab" = study@waiting ]; then
      xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
      # What the app still waits on after the look: {} once the house has said.
      cp "$DATA/Library/Application Support/waiting.json" "$OUT/$tab-$mode.json" 2>/dev/null || true
      for f in conversation-darban.json waiting.json; do
        P="$DATA/Library/Application Support/$f"
        if [ -f "$P.kept" ]; then mv "$P.kept" "$P"; else rm -f "$P"; fi
      done
    fi
    # study@hawa, after the empty room: a word said to hawa on launch and
    # its answer; the app put away behind the phone's Settings and brought
    # back three times; what Application Support holds; and chintan's room,
    # its history still there. The word goes to a stand-in on this Mac
    # (standin.py), never the real hawa, and NAME.count says how many words
    # reached it: 1 is right.
    if [ "$tab" = study@hawa ]; then
      xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
      HEARD="$OUT/$tab-$mode.heard"
      : > "$HEARD"
      python3 -I "$ROOT/Chintan/scripts/standin.py" 8799 "$HEARD" &
      STANDIN=$!
      sleep 1
      xcrun simctl launch "$UDID" Prabhchintan.Chintan --house 127.0.0.1:8799 --tab study --open hawa \
        --say "Why does toast always land butter side down?" >/dev/null
      sleep "${SEE_HAWA_WAIT:-12}"
      xcrun simctl io "$UDID" screenshot "$OUT/$tab-said-$mode.png" >/dev/null
      for _ in 1 2 3; do
        xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null
        sleep 3
        xcrun simctl launch "$UDID" Prabhchintan.Chintan >/dev/null
        sleep 3
      done
      xcrun simctl io "$UDID" screenshot "$OUT/$tab-back-$mode.png" >/dev/null
      kill "$STANDIN" 2>/dev/null || true
      grep -c ' POST /v1/say ' "$HEARD" > "$OUT/$tab-$mode.count" || true
      DATA=$(xcrun simctl get_app_container "$UDID" Prabhchintan.Chintan data)
      { ls "$DATA/Library/Application Support"; cat "$DATA/Library/Application Support/waiting.json" 2>/dev/null || true; } >"$OUT/$tab-$mode.txt"
      xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
      xcrun simctl launch "$UDID" Prabhchintan.Chintan --house "${CHINTAN_HOUSE:-}" --tab study --open chintan >/dev/null
      sleep 6
      xcrun simctl io "$UDID" screenshot "$OUT/$tab-chintan-$mode.png" >/dev/null
      xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
      xcrun simctl spawn "$UDID" defaults write Prabhchintan.Chintan studyVoice chintan
    fi
    if [ "$tab" = settings@on ] || [ "$tab" = settings@senses ] || [ "$tab" = settings@move ] || [ "$tab" = settings@apps ]; then
      xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
      xcrun simctl privacy "$UDID" reset location-always Prabhchintan.Chintan 2>/dev/null || true
      for key in telling place heard; do
        xcrun simctl spawn "$UDID" defaults delete Prabhchintan.Chintan "where.$key" 2>/dev/null || true
      done
      xcrun simctl spawn "$UDID" defaults delete Prabhchintan.Chintan phone.heard 2>/dev/null || true
      for key in telling heard; do
        xcrun simctl spawn "$UDID" defaults delete Prabhchintan.Chintan "health.$key" 2>/dev/null || true
        xcrun simctl spawn "$UDID" defaults delete Prabhchintan.Chintan "motion.$key" 2>/dev/null || true
      done
    fi
  done
done
xcrun simctl terminate "$UDID" Prabhchintan.Chintan 2>/dev/null || true
xcrun simctl ui "$UDID" content_size large
# A tab whose light and dark are one picture, byte for byte, is said so
# (Home is drawn dark in both, its own choice), never passed off as two.
for light in "$OUT"/*-light.png; do
  [ -f "$light" ] || continue
  dark=${light%-light.png}-dark.png
  if [ -f "$dark" ] && cmp -s "$light" "$dark"; then
    echo "ONE PICTURE: $(basename "${light%-light.png}") is drawn the same in light and dark"
  fi
done
echo "BUILD OK, pictures:"
ls "$OUT"/*.png
