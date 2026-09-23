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

The maintainer's word, 2026-09-22 19:23, which now governs the whole look:
"a visual, very highly aesthetic and beautiful and pretty, like European
paintings in a museum pretty, app, that I use to run my life, talk to you
or darban or yaar, look at my to dos but in the same philosophy as our
email, basically a painting ... actual paintings that fit the iPhone frame
... unless there is an action or something in which case it is tastefully
and elegantly placed." So: the app is a painting first. Home is the day's
painting, full bleed, a real public-domain work chosen for the phone's
frame (the house door serves it: `GET /v1/painting` gives title, artist,
year, credit and `image`; `GET /v1/painting.jpg` is the picture, from the
house, so the app still talks to one host), with the day's few lines and
any action placed on or beside it the way a museum places a label: small,
exact, never shouting. His word on the first painting Home (2026-09-22
19:38): "freaking beautiful and exactly what I meant", with one change: the
tab bar underneath is part of the art like the date and the label, the
painting runs under it, never an opaque strip cutting the canvas; that is
the standard every screen is held to from here. The to-dos keep the day
card's philosophy (only
dated things with a consequence, one screen, nothing habitual, done means
gone) and, once the app is good enough, replace the daily mail card
outright; mail that needs his hands and is a positive thing stays mail.
Later rungs, on his word: darban and yaar as voices in the study (each a
door on the house), and Jev-style cheap judgments behind the scenes.

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

The maintainer's word, 2026-09-22 19:44, on the whole app: every tab works
the way Home works, the painting under everything, the conversation too,
with translucent and opaque layers so the text makes sense; all three
voices in the app (chintan, darban, yaar); and the look re-cut: "colors
could be classier and more elegant, the brown seems kinda low class. I
want this to feel like a high end museum but also incorporate Sikh and
Indian art in it, though extremely classy and tasteful imagery and art.
Architecture, art, you get the idea." And: Opus is said to have amazing
aesthetic standards; show them.

## The look (re-cut 2026-09-22 evening, governs every screen)

A high-end museum, not a paper notebook. Think the wall label, the gilt
hairline, the quiet of a gallery at night. The warm brown paper is retired.

- Ground: the painting. Where there is no painting (never, ideally) the
  ground is bone in light (a cool ivory, not tan) and lamp black in dark (a
  warm near-black, gallery walls after hours). No brown, no beige cards.
- Ink: graphite in light, bone in dark. Never pure black on pure white.
- One accent, used hair-thin: old gold (a muted gilt, the frame's edge),
  for rules, the active tab, a date. Saffron survives as a single mark
  only (the day that has come, a thing that needs his hand); never a fill,
  never a tint over a screen.
- Surfaces for text: glass over the painting (ultra thin material), a soft
  gradient scrim at the foot or head of the picture, or a small opaque
  plaque in bone or lamp black with a gilt hairline for the densest text
  (the conversation). Each tab picks the lightest surface that keeps its
  text legible in both modes; the picture is always seen through or
  around it. Never a full-width opaque strip, never a card grid.
- Type: the serif for titles and the day's line; small capitals with
  tracking for labels and section names, the way a museum letters a wall;
  the body in the text style. Few sizes, large gaps.
- The tab bar is drawn on the art: translucent, the icons in bone, the
  active one in gilt, the painting running under it (his word, 19:38).
- The collection: real works from open collections (The Met, Cleveland),
  chosen for the phone's frame. European painting and the subcontinent's
  own: Pahari, Kangra, Guler, Basohli, Sikh school, Mughal, Deccan, Rajput;
  ragamala, court, landscape, nayika, architecture (Amritsar, the forts,
  the havelis, in period photographs and drawings). Tasteful and exact:
  the house never shows the Gurus under a to-do list or a chat (works
  depicting the Gurus are left out of the daily rotation, his to overrule),
  nothing lurid, nothing kitsch, no clip-art Khanda, no orange gradients.
  The label is the only decoration: title, artist, year, credit, on tap.
- Motion: none for its own sake. A painting fades in; a done thing lifts
  off its leaf; the thinking state breathes.

The older words still hold where they do not conflict: system fonts, real
SF Symbols, every string in the house's voice, dark mode first-class,
visual before verbal (his word, 09-22 19:18): a number is a ring or a bar
before it is a digit, text only where it earns its place, nothing on a
screen explains its own shape.

## The doors the house serves (chintan-app, one host)

`/v1/health`, `/v1/cockpit` (text), `/v1/board` (the to-dos as text),
`/v1/painting` and `/v1/painting.jpg` (the day's painting), `/v1/pulse`
(meters[] with key, name, fraction 0 to 1, resets, words; tended = the last
round's time), `/v1/say` and `/v1/say/ID` (the conversation; since 09-22 evening `POST
/v1/say {"text": ..., "to": "chintan"|"darban"|"yaar"}` reaches the voice
named, chintan when unnamed, and `GET /v1/voices` lists the three with a line
each and their state), `POST /v1/done {"text": ...}` when the board asks for
it. Anything shown as a number, ring or bar comes from one of these or is
not shown.

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

## The roadmap, in chunks (2026-09-22 19:44; each chunk is a few sprints)

Take them in order; a sprint takes the next slice of the open chunk. The
chunk is done when the fresh-eyes review says so against the look above.

A. The canvas (now). The palette re-cut to the look (bone, lamp black,
   graphite, gilt hairlines; the brown gone from every screen and the
   asset catalog); the tab bar drawn on the art; the painting under every
   tab with the right surface for its text; the rings under Home named
   from `/v1/pulse` or removed; the cut-off to-do line fixed. Slices: 1)
   palette and tab bar, 2) Board and Study get the painting and a surface,
   3) rings and the label. All three slices built (sprints 4 and 5); the
   chunk waits on the fresh-eyes review. Next, B.
B. The board on the canvas. Today, This week, Later on leaves over the
   picture; a thing done lifts off (`POST /v1/done`, house side to build
   when this chunk opens); the why on tap; the empty board is the painting
   alone with one line. The day card's philosophy, nothing more. Slice 1
   built (sprint 6): the shelves by date, the why on tap, Done in the app.
   Slice 2 built (sprint 7): the list ends cleanly above the tabs, and
   This week closes on Sunday. Slice 3 built (sprint 8): leaves by day.
   Left: the house side of `POST /v1/done` (in the chintan repo, not
   buildable from yantar's sprint; then see a thing lift off). The app side
   of B is whole; the next buildable slice is C.
C. The study, three voices. The conversation legible over the painting
   (ink on a plaque or glass, never a raw bubble on the picture); the
   voice chosen at the top the way a gallery names its room: chintan,
   darban, yaar; history kept per voice; a thinking state that breathes;
   time stamps; failures said plainly; retry; the composer above the
   keyboard. Uses `to` on `/v1/say` and `/v1/voices` (house side live
   09-22 evening). Slice 1 built (sprint 9): the three rooms named at the
   top, history per voice, `to` sent, the empty room in the voice's own
   line, the thinking mark breathing. Left: time stamps, retry on a failed
   word, the composer seen above the keyboard.
D. The house. The household seen: darban, yaar, the hands, the timers,
   each with its last run and state as marks not words; the meters as
   bars; the doctor's word. `/v1/cockpit.json` when the tiles need
   structure (shape: {"headline", "raised": [], "meters": {"s","w","f"},
   "tiles": [{"name","value","of","state"}]}).
E. The collection. The painting alone on tap (label away, pinch to look);
   the subcontinent's art and architecture woven into the rotation (house
   side: Cleveland as a second source and the Indian and Sikh themes live
   09-22 evening; architecture next); a keep gesture that files today's
   painting in the vault's baithak; yesterday's painting one swipe away.
F. Settings and the edges. The health dot; settings one tap away; a
   version line; then on his word a widget (App Group, extension target),
   notifications (an APNs key, his hands), Siri.

## The ledger (newest first)

- 2026-09-23 · sprint 9 (a16489e): the study has three rooms. "The
  study" at the head is gone; chintan, darban and yaar are named there in
  small serif capitals, the open room in gilt with a hairline under it
  that slides to the next, a saffron mark on a voice the house says is not
  home. Each room keeps its own conversation on the device (chintan's in
  the file it always had, the others beside it), a word goes to the room's
  voice (`to` on `/v1/say`), and a reply finds its room even if he has
  walked into another. An empty room says what the voice is for in the
  house's own line from `/v1/voices` ("The door: the day to day, what the
  house is doing, a quick word.") under a gilt hairline; the composer
  reads "A word for darban"; the thinking state is a gilt mark that
  breathes beside "darban is thinking". The room last open is kept. Seen
  in both modes against the real house: chintan's room with its
  conversation, darban's and yaar's empty. No new door (see.sh's
  `study@darban` opens a room).

- 2026-09-23 · sprint 8 (8d2e25d): the board on leaves by day. The one
  long plaque is gone; each shelf (Today, This week, Later) is named in
  gilt small capitals on the painting itself, and under it one leaf per
  day, the date lettered once at the leaf's head: Wednesday's call alone,
  Friday's four together, Monday's bill and Wednesday's hiring pool on
  leaves of their own, the picture showing between them. A thing opened
  keeps its Done inside its leaf. Seen in both modes against the real
  house, at rest and scrolled to the end. No new door; `POST /v1/done` is
  still the one written under sprint 6.

- 2026-09-22 · sprint 7 (c7241a3): the board ends cleanly. At rest the
  last thing on the plaque no longer stops mid-word on the tab bar
  ("Ogden DMV" half lettered); the foot of the list eases into the
  painting over 96 points and is clear for its last stretch, so the last
  leaf dissolves, and the end of the list carries an inset of the same
  height so it scrolls up whole, the plaque's foot closing above the
  tabs. This week now ends on Sunday (a Monday week), so Monday's
  Union Walk bill sits alone under a Later shelf, seen opened with its
  Done at the foot of the board (see.sh's `board@N` now scrolls to the
  thing it opens). The Study's foot takes the same eased fade, seen
  unharmed. Seen in both modes against the real house over three looks.
  The house side of `POST /v1/done` was steered first but lives in the
  chintan repo (`ghar/app.py`), which this sprint cannot reach; the door
  is still the one written under sprint 6, and the phone still says
  "The house cannot take this from the phone yet." until it is built.

- 2026-09-22 · sprint 6 (8f99774): the board by when things fall. The
  house's single "This week" heading in its own order (Wed, Mon, Fri) is
  gone; the app shelves the open things Today (and anything past), This
  week, Later, soonest first, the undated closing Later, so Friday's four
  sit together under one date and Monday's bill comes last. A thing
  opened on tap shows its whole why and, under it, a gilt hairline circle
  and DONE in small capitals; it lifts off only when the house says yes,
  and otherwise says in italic "The house cannot take this from the phone
  yet." or "The house did not answer; still open." Seen in both modes
  against the real house, shut and opened (see.sh now takes `board@N` to
  open the Nth thing). The door needed from the house, not yet there (404
  today): `POST /v1/done {"text": LINE}` where LINE is the task line after
  its checkbox exactly as `/v1/board` printed it (📅 date included); runs
  `ghar done` on it and answers 200 {"ok": true}; 404 or 405 reads as
  "no door yet", any other non-2xx as "did not answer".

- 2026-09-22 · sprint 5 (2d3354f): the canvas finished. Home's rings are
  named from `/v1/pulse` (hours, week, Fable in small serif capitals under
  each), and a tap on one says it in a line of italic ("18 percent of the
  five hours, fresh again 10:30 PM."), its name turning gilt; the
  cockpit's meters stay as the fallback when the door is quiet. The
  calendar leaves are re-cut: the weekday in gilt small capitals (saffron
  once the day comes), the day in bone serif, a gilt hairline on a faint
  lamp black, square corners like a mount. A long thing wraps to a second
  line instead of ending in dots. The study was seen for the first time
  with a conversation (a sample put on the simulator only): bone plaques
  and smoked glass both read cleanly over the painting in light and dark;
  no change needed. Seen in both modes against the real house. No new door.

- 2026-09-22 · sprint 4 (2477828): the canvas. The brown paper is gone
  from every screen and the asset catalog (Ground in bone and lamp black,
  Plaque, Ink in graphite and bone, the accent now old gold, Saffron kept
  for the single mark); the tab bar is transparent on the art, bone icons,
  the active one in gilt, labels in small serif capitals; the painting is
  fetched once and stands under all three tabs. The board keeps the top
  third of the picture, "Five things open." lettered over it, and the
  things on one plaque with a gilt hairline, each by its gist with the
  reasons small (the rest on tap) and the date lettered once per day,
  saffron once the day comes. The study stands on the painting too:
  chintan's words on plaques, his on smoked glass, a glass composer with a
  gilt send, the gear in the head, "The study is quiet." when empty. The
  dark sliver at the top edge is gone and Home's foot is one shade into
  the tab bar. Seen in both modes against the real house over three looks;
  the study's bubbles were not seen (no conversation on the simulator).
  No new door.

- 2026-09-22 · sprint 3 (8d9ae91): Home is the day's painting. The wall
  of monospaced text is gone; the house's painting fills the screen, the
  date in small serif capitals and the day's first sentence large over its
  foot, the dated things of the coming week on calendar leaves (one leaf
  per day, the gist of each thing beside it, saffron once the day comes),
  the meters as three rings with a green dot for nothing raised, and the
  museum label bottom right with the credit on tap. The house's long dashes
  are shown as hyphens. Seen in both modes against the real house; a thin
  dark sliver sits at the very top edge. No new door used; the tiles slice
  asks for `/v1/cockpit.json` (shape in the backlog).

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
