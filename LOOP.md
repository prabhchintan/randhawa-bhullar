# The Sunday loop

Every Sunday morning this repository is worked on by an unattended Claude
session on a GitHub-hosted Mac. It reads how the apps were actually used
during the week, decides what to improve, builds it, ships it through App
Store Connect, and writes a report. The maintainer's part is to carry the
apps on his phone, answer the Saturday email when he has something to say,
and read the Sunday one. This file is the covenant that session runs under.

## What it reads

Nothing in the apps phones home; the roadmap says analytics will not happen
and this loop does not change that. Three feeds, none of them from the apps
themselves:

1. **The maintainer's own map**, `scripts/mymap.py`. His moments and memories,
   read from his own private CloudKit database with a cktool user token that
   belongs to his iCloud account. Summarised as counts, gaps and shapes; the
   raw points stay on the runner and die with it, and no report ever quotes a
   coordinate or a place name.
2. **App Store Connect analytics**, `scripts/asc.py analytics`: installs,
   sessions, retention and crashes from the users who opted into sharing
   with developers. Apple gathers it; the apps do not.
3. **The maintainer's words.** Every Saturday a check-in issue with three
   questions is opened in the private repository and mailed to him; he
   replies to the email, the reply becomes a comment, and a workflow files
   the comment under `inbox/`. Any reply to any of the loop's emails lands
   there, any day of the week. The Sunday session reads everything newer
   than its last report. Plus the review state of the last submission and
   that last report.

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

Nothing runs on the maintainer's Mac. Two repositories, three workflows, one
session:

- **This repository, public.** `.github/workflows/sunday.yml` runs Sundays at
  15:00 UTC on a GitHub-hosted macOS runner: it checks out both repositories,
  selects the newest Xcode, installs the App Store Connect key and the cktool
  token from repository secrets, and runs `claude -p` with `loop/SUNDAY.md` as
  the prompt and permission checks off. The session builds, decides, ships
  through RELEASING.md and `scripts/asc.py`, and writes the report. Its
  transcript goes to the private repository, never to the public job log.
  Change the cron there to change the cadence; `workflow_dispatch` runs it on
  demand, with a `check` mode that only proves the runner and a `note` field
  for a one-line instruction.
- **prabhchintan/randhawa-loop, private.** `inbox/`, `reports/`, `logs/`,
  `analytics/`, and the conversation as issues. Three small workflows:
  `checkin.yml` opens the Saturday check-in (Saturdays 15:00 UTC),
  `report.yml` turns a pushed report into an issue addressed to the
  maintainer, `inbox.yml` files every comment he writes. GitHub's own
  notification email is the channel in both directions: the issue body is the
  message, and a reply to the email is a comment.
- **Secrets**, all in the public repository's Actions secrets and nowhere in
  git: `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, the maintainer's
  subscription), `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
  `ASC_CONTACT_JSON`, `CKTOOL_USER_TOKEN`, and `LOOP_DEPLOY_KEY`, a write
  deploy key for the private repository.
- Both apps must build for the simulator before anything is archived. If a
  build fails and the fix is not obvious, the session reverts its own
  changes, reports, and ships nothing. A failed job also emails the
  maintainer through GitHub Actions itself.
- To pause the loop, disable the workflow in the Actions tab; to run it
  early, dispatch it. `scripts/mymap.py` and `scripts/asc.py` also run from
  any Mac with the same keys installed, which is how the first release under
  this loop was made by hand on 2026-08-16.

## Why this shape

The apps are quiet on purpose. The loop keeps them quiet: it studies one
person who agreed to be studied and the numbers Apple already gathers, and
it changes small things often instead of large things rarely. The maintainer
sees each change the way everyone else does, as an update in the App Store,
and reads one report a week. That is the whole feedback system, and it is
enough.
