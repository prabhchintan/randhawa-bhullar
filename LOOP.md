# The loop

Twice a week (Wednesdays and Sundays) this repository is worked on by an
unattended coding agent on a GitHub-hosted Mac. It reads how the apps were actually used, decides what
to improve, builds it, ships it through App Store Connect when shipping is
warranted, and writes to the maintainer only when there is something to say.
The maintainer's part is to carry the apps on his phone, answer the Saturday
email when he has something to say, and glance at the rest. Sunday is the
weekly summary. This file is the covenant every session runs under, whichever
model is behind it.

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
3. **The maintainer's words**, by either of two doors, both optional, and
   the loop runs whether or not he uses them. By email: every Saturday the
   loop's post office (a Cloudflare worker, `worker/loop.js` in the
   prabhchintan.com repo) mails him one question from
   `loop@pulse.prabhchintan.com`; he replies to that, or to any of the loop's
   emails, any day, and the next session fetches the reply into the private
   repository's `inbox/` before it starts. From inside the app: a memory
   whose text begins with `@loop` is a note to the loop; `scripts/mymap.py`
   files it into the same inbox and never touches the memory. Plus the
   review state of the last submission and the last report.

## What it may do alone

- Tune the ink: alphas, widths, radii, the day boundary, the thread gap, the
  clustering radius. The first weeks are for this; the maintainer's map is
  the test card.
- Fix bugs, in either app or in MemoryKit, within the compatibility rules in
  MemoryKit/README.md.
- Copy inside the apps and on the store pages, provided every privacy claim
  stays literally true and no dash of either long kind appears anywhere.
- The loop's backlog in ROADMAP.md, in order, one piece per run, and
  roadmap items marked Next, if small enough to finish and verify in one
  session.
- Bump versions, regenerate screenshots, archive, upload, submit for review
  with automatic release, tag, push, and write the report, subject to the
  shipping gate below.
- Skip the release, and skip the report. A quiet day ships nothing and says
  nothing; the transcript is enough.

## The shipping gate

The loop runs twice a week; the App Store does not want an update every
run, and Apple allows one submission in review per app at a time. So a session ships only
when all three hold: nothing is waiting for or in review for that app; at
least three days have passed since that app's last submission (a rejection
or a crash fix is exempt); and the changes since then have user-visible
value. Everything else accumulates on main and ships when the gate opens.

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

Nothing runs on the maintainer's Mac, and nothing about him lives in public.

- **This repository, public.** `.github/workflows/loop.yml` runs Wednesdays
  and Sundays at 15:00 UTC on a GitHub-hosted macOS runner: it checks out both repositories,
  selects the newest Xcode, installs the App Store Connect key and the cktool
  token from repository secrets, fetches the maintainer's mail into the
  private repository, and runs the agent with `loop/SESSION.md` as the
  prompt and permission checks off. The transcript goes to the private
  repository, never to the public job log. When the session leaves a report
  with a Short version, the workflow mails those bullets; when the session
  dies, it mails that; otherwise it mails nothing. `workflow_dispatch` runs
  it on demand, with a `check` mode that only proves the runner and a `note`
  field for a one-line instruction. Change the cron to change the cadence.
- **The agent is a variable.** Repository variable `LOOP_AGENT` picks it:
  `claude` (Claude Code, secret `CLAUDE_CODE_OAUTH_TOKEN` from
  `claude setup-token`, which runs on the maintainer's subscription, or
  `ANTHROPIC_API_KEY`; `LOOP_MODEL` picks the model, and a smaller plan
  should set it to a smaller model) or `codex` (OpenAI Codex CLI;
  with `LOOP_MODEL_PROVIDER=xai` and secret `XAI_API_KEY` it runs Grok, with
  `OPENAI_API_KEY` it runs OpenAI; `LOOP_MODEL` names the model). Same
  prompt, same tools, same covenant. Adding an agent is one more case in the
  workflow's install and run steps. Expect weaker agents to stumble on the
  App Store half; the workflow reports a stumble as a stumble, and the next
  day's run tries again with a clean checkout.
- **prabhchintan/randhawa-loop, private.** `inbox/` (his replies), `reports/`
  (days with news), `logs/` (map feeds, transcripts), `analytics/`. Nothing
  in it is ever copied to the public repository.
- **The post office.** `worker/loop.js` on the Pulse worker: `/loop/send`
  mails him one screen of serif text from `loop@pulse.prabhchintan.com`, no
  chrome, a Details link if he wants more; inbound mail to that address (from
  his own addresses only) is kept for the next session; a cron on the worker
  sends the Saturday question. Email Routing is enabled for the
  `pulse.prabhchintan.com` subdomain only; the apex still points at iCloud.
  `scripts/loopmail.py` is the runner's side of it.
- **Secrets**, all in the public repository's Actions secrets and nowhere in
  git: an agent key, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
  `ASC_CONTACT_JSON`, `CKTOOL_USER_TOKEN`, `LOOP_DEPLOY_KEY`, `LOOP_SECRET`.
- Both apps must build for the simulator before anything is archived. If a
  build fails and the fix is not obvious, the session reverts its own
  changes, reports, and ships nothing.
- To pause the loop, disable the workflow in the Actions tab; to run it
  early, dispatch it. `scripts/mymap.py`, `scripts/asc.py` and
  `scripts/loopmail.py` also run from any Mac with the same keys installed,
  which is how the first release under this loop was made by hand on
  2026-08-16.

## When Apple rejects

It will happen sooner or later, most likely over the Always location prompt.
The plan, in order:

1. The session sees `REJECTED` from `scripts/asc.py status`. Apple's reason
   is not in the API; it arrives by email to the maintainer. If a note with
   the reason is already in the inbox (he forwarded or replied), the session
   reads it.
2. With a reason inside scope (a missing string, a screenshot, a review note
   that needs a sentence, a build problem): fix it, rebuild, resubmit the same
   version with a new build number, and say so in the report.
3. With a reason outside scope (permissions, the privacy story, what the app
   is for): do not resubmit. Write the case in the report, propose the two
   or three honest options, and stop. The maintainer decides and answers in
   the Resolution Center himself; the loop never argues with App Review on
   his behalf. The known fallback for a location dispute is already
   designed: ask While Using at the intro and offer Always afterwards from
   the trail screen, which is 3.1's flow, and turn the default back off.
4. With no reason anywhere: mail the maintainer one line asking him to
   forward Apple's email to loop@pulse.prabhchintan.com, ship nothing, and
   check again next run.
5. Never resubmit the same build unchanged, and never more than once per run.

## Failsafes

- **Pause.** Repository variable `LOOP_PAUSED=1` stops every step of every
  run until unset; disabling the workflow in the Actions tab does the same.
- **One at a time.** Concurrency group `loop`; a run never overlaps another,
  and a run has a five-hour ceiling.
- **Nothing ships unbuilt.** Both apps must build for the simulator first;
  a broken build reverts the session's changes and reports.
- **The gate.** Nothing ships with a version in review, within three days of
  the last submission (rejection and crash fixes excepted), or without
  user-visible value.
- **Every submission is a tag.** `randhawa-X.Y-bN`, `bhullar-X.Y-bN`. A bad
  release cannot be pulled back from users, but the next build can be cut
  from the last good tag in one run, and the report says which tag is good.
- **Crashes first.** If Apple's opt-in crash reports show a spike after a
  release, that outranks the backlog.
- **Promises wait.** Anything that changes a public promise never ships
  unattended; see "What waits for the maintainer".
- **Stumbles are announced.** A run that dies mails one line and leaves its
  transcript in the private repository; the next run starts clean.
- **Mail is optional.** If the post office is unreachable, the run continues
  without the inbox and says so.
- **Undo is git.** Every change is a commit on main in the open; the
  maintainer can revert any of it from any machine.

## Why this shape

The apps are quiet on purpose. The loop keeps them quiet: it studies one
person who agreed to be studied and the numbers Apple already gathers, and
it changes small things often instead of large things rarely. The maintainer
sees each change the way everyone else does, as an update in the App Store,
and gets one short email when there is news. That is the whole feedback
system, and it is enough.
