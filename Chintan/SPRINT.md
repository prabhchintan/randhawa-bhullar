# chintan, the private app: the sprints

The maintainer's word, 2026-09-22, 17:59, on the study line: the first build
is "very raw and unusable as a human", so run "hyper agile sprints assessing
the app from all angles, product, design and code", and "make it the HQ as
an iOS app where I can visually see the system we have built come to life".
Pace it by the usage meters, leaving room for his own conversations, the
rounds and darban. This file is the sprint's memory: the vision, the rules,
the backlog, the ledger. One read before every sprint, one ledger line after.

## The vision

The house in his pocket. Not a chat wrapper and not a dashboard: a warm,
quiet place that shows the household alive (what the day holds, what the
house is doing, what needs him) and lets him talk to chintan when he wants
to. The values are GHAR.md's: warm not corporate, minimal and native, one
person, gentle pace. A screen should read at a glance, the way a good note
on the kitchen table does; nothing on it explains its own shape; nothing on
it is a chore for him.

The shape to grow into (four tabs, in this order):

1. **Home** (the jharokha, reborn native). One screen: the date and the day
   in a sentence, today's to-dos with their consequence, the next thing on
   the calendar, and the house's pulse as quiet tiles (rounds, hands,
   meters, the doctor's word). Data from `/v1/cockpit` (the house has
   `ghar cockpit --json`; add a `/v1/cockpit.json` door when the tiles
   need structure).
2. **The board.** To-dos grouped Today, This week, Later, each with its
   date and lead; done from the phone (`POST /v1/done {"text": ...}` on
   the house door, which runs `ghar done`); the why on tap.
3. **The study.** The conversation with chintan: readable bubbles, time
   stamps, a thinking state that feels alive, history kept, failures said
   plainly, retry, the composer never lost under the keyboard.
4. **The house.** The household itself: darban, yaar, the hands, the
   timers, each with its last run and state; the usage meters as bars; the
   doctor's list. The system seen, which is the point of the app.

Design language: system fonts (a serif for titles, `.design(.serif)`, the
body in the text style), a warm neutral palette that reads in light and
dark, one accent (a deep saffron), generous spacing, real SF Symbols, no
decoration for its own sake. Every string in the house's voice: plain,
warm, lower-case chintan, never an em dash or an en dash. Dark mode is a
first-class citizen, not a theme.

## The rules of a sprint

- One improvement per run, finished: designed, built, seen in the
  simulator screenshots, and written into the ledger. Small and whole beats
  large and half.
- Product before polish: the order of the backlog is the order of value to
  a person holding the phone. Skip ahead only for a bug he would hit.
- The eyes are real: after every push, run the screens job on yantar and
  read the pictures before calling anything done. A change that cannot be
  seen is verified by the simulator build succeeding.
- The house door (`ghar/app.py` in the chintan repo) may grow a door when
  the app needs one; keep the gate, keep it read-only unless the item says
  otherwise, restart the service, and note the door here.
- TestFlight: the nightly job ships at 03:00 Mountain. A sprint fires a
  TestFlight build itself only when the change is something he would notice
  on the phone and no build has gone up in the last four hours.
- Never touch Randhawa or Bhullar. No third-party code, no analytics, no
  crash reporting, no phone-home. Only the one host. The brief in BRIEF.md
  binds this file.
- Commits say what changed for the person, not the code; one commit per
  sprint; the ledger line names the commit.

## How a sprint runs (since 2026-09-22 evening)

On yantar, the Mac that builds it, in one job (`.github/workflows/sprint.yml`,
the brief `Chintan/SPRINT-BRIEF.md`): the hand builds and photographs the app
on the machine as many times as its cycle allowance says (`scripts/see.sh`),
commits, the job pushes, keeps the last look, and ships to TestFlight when
the sprint says a person would notice (`scripts/ship.sh`). The house
(`ghar sprint` on chintan) holds the gears, the gate on the usage meters,
and the fresh-eyes review: every third sprint a reviewer that did not make
the change compares the last two looks against this vision and world-class
design principles and says improving, flat, worsening or enough; worsening
stops the sprints until the maintainer's word, enough rests them until a
named time, flat slows them. The nightly TestFlight build stays as the
catch-all.

## The backlog (top is next)

1. Home: replace the monospaced cockpit text with native tiles from the
   cockpit's structure; today's to-dos on top with their consequence.
2. The board: Today, This week, Later; done from the phone; the why on tap.
3. The study: bubbles, time stamps, thinking state, history, retry, the
   keyboard.
4. The house: agents, timers, meters, the doctor.
5. Settings: the health check as a green dot on the Home tab, settings one
   tap away, a version line.
6. Later, on the maintainer's word: a widget (App Group and an extension
   target), notifications (an APNs key, his hands), Siri.

## The ledger (newest first)

- 2026-09-22 · sprint 2 (040297d): the icon. The old blue dot on black is
  gone; the app is now a paper jharokha on the deep saffron: an arched
  frame, the room in shade behind it, one mullion, a sill. A first draft
  in solid paper read as a gravestone, so the window became a frame. Seen
  on the simulator's home screen beside Randhawa, where it reads at a
  glance; the design foundation is done. No door needed.

- 2026-09-22 · sprint 1 (88828e6, b556d6e): the app has the house's colours.
  Warm paper under every screen with its own dark, lighter cards, serif
  titles, a deep saffron on the tabs, the gear and the send arrow; the tabs
  are Home, Board, Study with Home first and the app opens there; the
  composer is a soft pill with a round arrow; the launch screen is paper
  (seen only as a green build, the eyes do not catch launch). The global
  accent alone left things system blue, so the tint is set by name. Seen in
  both modes on yantar. The empty Home still has a gap above its card; item
  2 replaces that screen.

- 2026-09-22 · sprint 0 (chintan, by hand): the board tab, launch arguments
  for the simulator's eyes, screens.yml and chintan.yml on yantar. The app
  as of tonight: three tabs of raw text, a gear, and a heartbeat.
