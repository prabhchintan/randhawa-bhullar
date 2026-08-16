# The Sunday loop

Every Sunday morning this repository is worked on by an unattended Claude
session on the maintainer's Mac. It reads how the apps were actually used
during the week, decides what to improve, builds it, ships it through App
Store Connect, and writes a report. The maintainer's part is to carry the
apps on his phone, file thoughts as GitHub issues labeled `sunday`, and read
the report. This file is the covenant that session runs under.

## What it reads

Nothing in the apps phones home; the roadmap says analytics will not happen
and this loop does not change that. Three feeds, none of them from the apps
themselves:

1. **The maintainer's own map**, `scripts/mymap.py`. His moments and memories,
   read from his own private CloudKit database with a cktool user token that
   belongs to his iCloud account. Written to
   `~/Library/Application Support/randhawa-loop/map/`, never into this
   repository, and never quoted in a report as coordinates or place names.
   Counts, gaps and shapes only.
2. **App Store Connect analytics**, `scripts/asc.py analytics`: installs,
   sessions, retention and crashes from the users who opted into sharing
   with developers. Apple gathers it; the apps do not.
3. **The inbox**: open GitHub issues labeled `sunday`, plus review state from
   `scripts/asc.py status`, plus last week's report.

## What it may do alone

- Tune the ink: alphas, widths, radii, the day boundary, the thread gap, the
  clustering radius. The first weeks are for this; the maintainer's map is
  the test card.
- Fix bugs, in either app or in MemoryKit, within the compatibility rules in
  MemoryKit/README.md.
- Copy inside the apps and on the store pages, provided every privacy claim
  stays literally true and no dash of either long kind appears anywhere.
- Roadmap items marked Next, if small enough to finish and verify in one
  session.
- Bump versions, regenerate screenshots, archive, upload, submit for review
  with automatic release, tag, push, and write the report.
- Skip the release. A week with nothing user-visible ships nothing; the
  report says so.

## What waits for the maintainer

- Anything that changes a public promise: permission strings, what location
  is used for, the privacy page, the App Privacy label, the "Will not happen"
  list, the five trail constraints.
- Anything that changes the stored formats or the CloudKit schema.
- Removing a feature (the memory tripwire below is the one pre-approved
  removal, and it still gets a written case first).
- Price, name, category, availability.
- Spending money, or touching the website beyond the two app pages.

When the right move is out of scope, the session writes the case in the
report and stops short of doing it.

## Standing questions

Things the loop is meant to answer over weeks, with the maintainer as the
test case:

- **Does the trail draw the map?** Dots per day, longest gaps, share of dots
  from the trail versus opens. If a normal day yields fewer than ten dots or
  gaps regularly exceed six waking hours, the cadence or the wake sources
  need thought.
- **Do the threads read as movement?** Do straight lines between
  significant-change fixes look like a life or like a spider web? Tune the
  gap and the alpha before adding cleverness.
- **Do memories get made?** The tripwire: if the maintainer's store still
  holds zero memories four weeks after 3.2 (that is, on 2026-09-13), write
  the case for removing the plus from Randhawa's map and making memories a
  Bhullar-only thing, and stop there. Removal is his call.
- **Is Bhullar opened at all?** If sessions stay near zero, the report says
  so plainly, every week, until he decides.

## Mechanics

- `scripts/sunday.sh` is what launchd runs, Sundays 09:00 local, from
  `~/Library/LaunchAgents/com.prabhchintan.randhawa.sunday.plist`. A missed
  Sunday runs when the Mac next wakes. It pulls both repositories, runs
  `claude -p` with `loop/SUNDAY.md` as the prompt, and logs to
  `~/Library/Logs/randhawa-sunday/`.
- Reports go to `loop/reports/YYYY-MM-DD.md` in this repository and are also
  posted as a GitHub issue labeled `sunday-report`, which is what reaches the
  maintainer's inbox.
- The release path is RELEASING.md; the App Store Connect half is
  `scripts/asc.py`, driven by an API key in `~/.config/appstoreconnect/`.
- Both apps must build for the simulator before anything is archived. If a
  build fails and the fix is not obvious, the session reverts its own
  changes, reports, and ships nothing.

## Why this shape

The apps are quiet on purpose. The loop keeps them quiet: it studies one
person who agreed to be studied and the numbers Apple already gathers, and
it changes small things often instead of large things rarely. The maintainer
sees each change the way everyone else does, as an update in the App Store,
and reads one report a week. That is the whole feedback system, and it is
enough.
