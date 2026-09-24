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
- Left out, by name (the Opus 5.5 playbook, 2026-09-23: with no direction the
  model falls back on a few default styles, and a list of named patterns
  works where "avoid a generic look" does not): brown or beige anywhere,
  card grids and drop-shadow cards, pill-shaped buttons, numbered 01 / 02 /
  03 section labels, italic accent words inside headings, monospace labels,
  gradients as decoration, stock grouped-list grey, emoji as icons, badges
  and counters, progress bars where a ring or a bar of ink would do, and
  any strip that cuts the painting edge to edge. When a look shows a new
  default nobody asked for, add it here and re-cut.
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
round's time), `/v1/paintings` (the shelf: today's first then the days ahead, each with an id and
its `image` path; `/v1/paintings/ID.jpg` is the picture at the phone's size; the
phone keeps the whole shelf, since 09-23), `/v1/visitors` (the site's visitors as
people, newest last seen first; `/v1/visitors/VID` is one person with `visitList`,
each visit's `steps` as page and seconds; since 09-23), `/v1/say` and `/v1/say/ID` (the conversation; since 09-22 evening `POST
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

## The eyes, deeper (Prab, 2026-09-23 02:55, the study line)

His word, at three in the morning: swiping between screens and the general
UX "seems janky"; the icon needs the polish the app now has; the deeper UX
is haptics and touch to reveal ("the thing itself can be extremely short and
aesthetic until pressed, at which point the user gets haptic feedback and a
bubble showing more details"); and above all "we will need a much better
way of doing this than screenshots ... question the underlying meta layer
and how to improve it, then the actual thing itself." So the loop grows
eyes for motion, feel and the lived experience, in this order:

1. **The walk** (`scripts/walk.sh`, an XCUITest target `ChintanWalk`): a
   scripted walk through the app that swipes between tabs, scrolls each
   shelf, opens a leaf, presses and holds what reveals, types a word in a
   room, turns the phone dark, and photographs every state it passes
   through, not just the three resting tabs. `xcrun simctl io recordVideo`
   runs under it so the transitions exist as a film; the job keeps the film
   and a contact sheet of frames (every 250 ms across each transition) that
   the hand and the fresh eyes can read. see.sh stays for the quick look.
2. **The numbers Apple uses**: hitches. Instruments' Animation Hitches
   template through `xctrace record` over the walk, exported to one line
   per screen: hitch time ratio in ms per second. Apple's own bar: under 5
   is good, over 10 is a visible jank. A sprint that touches motion prints
   the before and after ratios in its ledger line; the review reads them.
   Add `XCTOSSignpostMetric` scroll and animation metrics to the walk when
   the hitch export is in.
3. **The audit**: `XCUIApplication.performAccessibilityAudit()` (iOS 17)
   on every screen in the walk: contrast, dynamic type, hit targets,
   element descriptions. Its findings are a list, not a picture, and each
   one is a real defect a person would feel. Zero findings is the bar.
4. **His phone, the only judge of feel**: haptics and the weight of a
   gesture cannot be seen in a simulator. Two doors close the loop. (a)
   MetricKit: the app subscribes to `MXMetricManager` and posts each daily
   payload to `POST /v1/metrics` on the house door (launch times, hang
   rate, scroll hitch ratios, from the device itself; the house files them
   and the review reads the trend). (b) His word from inside the app: a
   long press on the museum label anywhere opens "a word for the house", a
   one-line composer; what he types goes to `POST /v1/word {"screen": ...,
   "text": ...}` and becomes the next sprint's steer, logged, so the lived
   experience is the signal and he never has to open Telegram to say "this
   swipe is janky".
5. **The rubric widens**: the fresh-eyes review reads the film's frames,
   the hitch ratios, the audit list and his words alongside the stills,
   and judges motion (does a transition feel like one continuous surface),
   feel (does a press answer, does a reveal breathe), and the walk's
   honesty (does every state it passes look designed).

The likely cause of the jank tonight, for the hand to confirm with the
numbers before touching it: each tab draws its own copy of the painting, so
a swipe decodes and lays out a full-screen image again; the fix is one
painting layer under all tabs (decoded once, cached, `.drawingGroup()` or a
prerendered UIImage at screen scale), the tabs as content over it, and a
page-style swipe between them with the standard iOS spring. The HIG is the
standard for the rest: the system tab bar's gestures and timings, standard
spring animations (`.snappy`, `.smooth`), `.sensoryFeedback` (iOS 17) for
haptics with the system's own kinds (selection on a tab, impact soft on a
reveal, success on done), a reveal as a plaque that grows from the thing
pressed with `matchedGeometryEffect`, never a modal.

## The roadmap, in chunks (2026-09-22 19:44; each chunk is a few sprints)

Take them in order; a sprint takes the next slice of the open chunk. The
chunk is done when the fresh-eyes review says so against the look above.

0. The eyes, deeper (next, before more polish): the walk with its film and
   contact sheet (built, sprint 10: `bash Chintan/scripts/see.sh --walk
   /tmp/see/walk` until the sprint job's tool list names walk.sh itself),
   the hitch numbers (built, sprint 11: the walk prints them; Instruments
   has no hitches on the simulator, so the app meters its own frames),
   the audit (built, sprint 12: `see.sh --walk --audit OUT` runs it alone;
   the contrast findings waived by name, sprint 13; the largest text
   seen and fixed, sprint 14, `see.sh --large`; left: the unnamed
   full-screen element, and the label's and bubbles' dynamic type
   readings, see the ledger); the house builds
   `/v1/metrics` and `/v1/word` (live 09-23 03:30); the app's MetricKit
   subscriber and the long-press "a word for the house" come with chunk G.
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
   word (the composer above the keyboard, and the keyboard put away by a
   drag, seen in the walk, sprint 10).
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
G. Feel. Haptics on every gesture that deserves one (`.sensoryFeedback`,
   system kinds only); touch to reveal everywhere a thing is short: a leaf,
   a meter, a label, a room name grows a plaque with the detail on a press
   and hold, with a soft impact, and folds back; the swipe between tabs as
   one continuous surface over one painting; the long-press "a word for
   the house"; the MetricKit subscriber. Judged by the walk's film and the
   hitch numbers, and by him. Slice 1 built (sprint 13): one painting
   under paged tabs, a swipe between them, the selection haptic on each
   arrival. Left in slice 1: tab taps and first visits under 10 ms/s.
   Slice 2 begun (sprint 15): touch to reveal on Home's rings, with the
   soft impact. A thing on Home held, sprint 16 (ThingPlaque). Next: the
   same on a room name and the label (RingPlaque and ThingPlaque are the
   pattern), then the word for the house, MetricKit.
H. The guest book (Prab, 2026-09-23 07:15, his word: "a running list of
   actual humans who visited, where from, and if I want I can click on it
   and it shows me details of where all they went and how much time they
   spent on which page"; a panel beside the three tabs, not a fourth; "we
   can remove it if it doesn't hit"). Built by the house 09-23 morning:
   `Visitors` lettered at the head of Home opens a sheet on glass over the
   painting; one leaf per person (place, network and kind of line, visits,
   pages, time, returning), shelves This week, This month, Earlier; a leaf
   opens the person: the device, languages, the proxy tell, then each
   visit as a leaf with its pages in order and the seconds on each, and
   any link followed out. The data behind it was put through the wringer
   the same morning: 1,120 sessions since May, 43 percent bots and 7
   percent datacenters (left out), 146 plausible people, 86 distinct;
   only a quarter carry the deep client signals, so the person's line
   leans on city, network kind, pages and time, which are always there.
   Next slices: a mark on Home when someone new has come since he last
   looked; the site's own page names instead of paths.
E2. The shelf (Prab, 2026-09-23 07:15: "toggle to the next art ... some
   dozen or so artworks that remain downloaded for offline use, easily one
   of my favorite features"). Built by the house 09-23 morning: the house
   pre-picks fourteen days (chintan-painting.timer 04:30, `ghar painting
   fill`), the Gallery keeps the whole shelf on the phone (pictures in
   Caches/paintings, the list in shelf.json), opens on the phone's own
   copy before the house answers, and "next" under the museum label turns
   to the next painting with a soft tick; his choice holds for the day.
   Next slices: a swipe on the picture as the turn; yesterday's one turn
   back; the keep gesture (E).
F. Settings and the edges. The health dot; settings one tap away; a
   version line; then on his word a widget (App Group, extension target),
   notifications (an APNs key, his hands), Siri.

## The ledger (newest first)

- 2026-09-23 · sprint 16 (862de91): a thing on Home, held. Home's things
  were only their gist ("Call Ogden Clinic"); the why lived a swipe away
  on the Board. Now a thing pressed and held grows a plaque just above the
  leaves, the whole width of the wall, over the day's line and the
  painting (`.snappy`, scale up from its foot and fade): the day in gilt
  capitals, in words ("Friday, September 25"; saffron and "Today, ..."
  once the day has come), the thing in the serif, and every reason the
  house wrote in the body, twelve lines at most. The thing held turns
  gilt; a soft impact as it grows, none as it folds; let go and it folds
  back. First look had the plaque pinned inside the day's own row, the
  width of the text and under the later leaves and the rings, which
  lettered through it; now it hangs from the foot of the day's line, so
  nothing draws over it. Seen in both modes, Wednesday's call and Friday's
  script held (`see.sh OUT jharokha@t0`, the Nth thing held; `jharokha@N`
  still holds the Nth ring). The walk does not yet hold a thing on Home,
  so no hitch numbers; the ring's reveal was 50.2 ms/s last sprint and
  this plaque is built the same way. No new door.

- 2026-09-23 · sprint 15 (77388ec, b5f45dd): a ring held, and Home's
  foot. A ring on Home, pressed and held, now grows a small opaque plaque
  just above the rings, out of the ring pressed (`.snappy`, scale and
  fade): the ring larger with its number inside ("21"), the window's own
  name from `/v1/pulse` in gilt capitals ("The five hours"), and when it
  comes back in italic ("Fresh again 8:50 AM"); the house's words only
  where they say more than the ring and the name. The held ring's name
  turns gilt; a soft impact as it grows, none as it folds; let go and it
  folds back. The tap still says the line in italic, as before. First look
  had the plaque sitting on the rings and the leaves ghosting through its
  97 percent; now it stands clear and whole, and narrower, so it never
  touches the label. Home takes the Board's foot (`Theme.foot`, 96 points
  of fade and the list's end clear of it): at rest the wall sits a little
  higher, and at the largest text the last thing dissolves above the bar
  instead of running under it (seen, "for the next" fading out). The walk
  found a jolt from sprint 14: a tap on the museum label opened the credit,
  whose long line made the label too wide for the rings' row, so the whole
  wall jumped up with the rings thrown under the label, crossing the
  leaves mid-flight; the shape is now chosen by text size (the label under
  the rings only at the accessibility sizes), and the film shows the rings
  still and the credit opening in place. Seen in both modes, held and at
  rest; the film's hold-ring sheet shows the plaque grow across one 250 ms
  frame and gone on release. The hitch numbers, before then after (ms/s):
  first visits 35.8 to 28.5, tab taps 42.1 to 42.6, swipe 62.0 to 57.5
  (the Mac's frames; neither was touched), board scroll 15.7 and study
  scroll 6.1 after (they did not log before); reveal, new, 50.2 over three
  holds with 4 hitches, worst 113 ms, likely the plaque's first build and
  its shadow; next, keep the plaque built and hidden, or draw its shadow
  once. The audit: 22 to 14; Home's label and next no longer read
  "partially unsupported" (the ViewThatFits was what it measured). Left:
  the full-screen unnamed element, and two study bubbles. The walk and the
  hitch meter now hold a ring. No new door.

- 2026-09-23 · sprint 14 (c384cc0): the largest text, seen and fixed.
  The audit's "partially unsupported" readings sent the eyes to the phone's
  largest text size (`see.sh --large OUT`, which sets it, looks, and sets
  it back), and there the app came apart: Home's rings and museum label
  sat side by side wider than the phone, so the whole page widened, its
  things ran off the right edge ("Call Huntzinge") and its lines lettered
  over the Board next door, with the Study's "CHIN" showing at the Board's
  right edge; the study's rooms ran off screen; the bar's names grew
  until they crowded. Now each page is clipped at its sides only (the
  shade still runs under the clock and the bar; a plain clip left seams,
  seen and undone), Home's label steps under the rings when the two cannot
  share a line and every thing on Home wraps, the rings stop growing at
  the first large size, the study's three rooms slide under the thumb when
  they do not fit, and the bar holds the system tab bar's size with the
  large content viewer on a press and hold, as iOS does. Seen at the
  largest size in both modes on all three pages, and at the normal size
  unchanged. The audit now writes each finding's long word and the
  element's frame. The audit: 42 to 20; the bar's and rings' names waived
  by name (held at a size by design). Left: the unnamed element is the
  full screen (0,0 402x874, type other) on every screen, and naming the
  pager did not clear it (tried, undone); next, suspect the hosting view
  or the painting's lamp black ground. Home's label and next and two
  study bubbles still read "partially", though the large pictures show
  them growing; likely they grow past the visible part of a scroll, not
  yet proven. No hitch numbers (nothing that moves was touched). No new
  door.

- 2026-09-23 · the house, by hand (the guest book and the shelf; chunks H
  and E2): Home gains "Visitors" at the head of the wall, a sheet on glass
  with the site's people as leaves and each person's visits told page by
  page; and "next" under the label, the shelf of fourteen paintings kept
  on the phone for offline and a tap to turn. House side: `/v1/paintings`,
  `/v1/paintings/ID.jpg`, `/v1/visitors`, `/v1/visitors/VID`; the worker's
  chintan wing gained `GET /chintan/pulse`. Seen: screens run 35866934353,
  Home in both modes, Visitors at the head, next under the label; shipped to
  TestFlight from yantar as build 202609231327 at 07:29.

- 2026-09-23 · sprint 13 (e23be7f, 5c4a924): one painting, a swipe that
  goes somewhere. The system TabView is gone: the painting is drawn once
  under the whole app and Home, the Board and the Study are pages over it
  (a paged horizontal scroll, all three built at launch, only the page in
  view read out). A thumb's swipe slides to the next page and the picture
  stays still behind it; a tap on the bar glides there (`.snappy`); each
  arrival ticks the selection haptic. The bar is our own, lettered on the
  art as before (bone, the open one in gilt and filled, names in small
  serif capitals that now grow with text size), and steps aside only
  under a keyboard tall enough to cover it. Each screen keeps only its own
  shade. Home's label is three clean lines, title, artist, year ("Frieze
  of Dancers / Edgar Degas / c. 1895"); "French, 1834-1917" waits with
  the credit, on tap. Seen in both modes, at rest, swiped and in the
  film: Home to the Board across one 250 ms frame, the painting unmoved;
  Study to Home glides past the Board in about 500 ms. The walk's notes
  now read Home, Board, Study where before a swipe went nowhere. The hitch
  numbers, sprint 11 then now (ms/s): first visits 50.3 to 32.5, tab taps
  38.5 to 32.2 (worst 49 to 29 ms), swipe 0.0 (it did nothing) to 11.9,
  board scroll 19.2 to 16.4, study scroll 16.5 to 4.5. Under 10 for the
  study only; not yet the steer's bar. A first try with every page in the
  accessibility tree was worse (tabs 56): the walk's own taps snapshot
  that tree on the main thread, so the pages off screen are now hidden
  from it. Next suspects for the taps and first visits: the plaques'
  shadows and the faded-edge masks rendered off screen while a page
  moves (try `.compositingGroup()` on each page, or shadows drawn once as
  an image). The audit: the contrast readings are waived by name in
  `ChintanAudit.waiver` (they sample the painting, not the plaque; the
  pictures say clean), with the board's two-line reasons, each kept with
  its reason in audit-waived.tsv (91). Left open, 42: the bar's names and
  "What does tomorrow hold?" read "Dynamic Type partially unsupported",
  and one unnamed element ("Element has no description", type other,
  probably the pager itself) on every screen; next, read
  `detailedDescription` for both. No new door.

- 2026-09-23 · sprint 12 (8e2605a): the audit, and what it found fixed.
  `ChintanAudit` (in the walk target) runs Apple's
  `performAccessibilityAudit` on Home, the Board, the Board with a leaf
  open, the study and darban's room, once light and once dark (walk.sh sets
  the look, `AUDIT_LOOK`); each finding is a line in audit.tsv (screen,
  look, kind, element, word) and walk.sh prints them; `see.sh --walk
  --audit OUT` runs the audit alone in about three minutes. Before: 110
  findings. Fixed and seen in both modes: Home's museum label read "Edgar
  Degas (French, 1834-1917), c..." and now wraps whole; the weekday on
  Home's leaves, the rings' names and the board's due marks were fixed
  11 point type or set in caption2 and did not grow with the phone's text
  size (now caption, a point larger, grows); the raised mark was a 7
  point dot and now carries a 44 point target; the board's reasons went
  from 60 to 72 percent ink and the gilt in light a touch deeper (4.4 to
  5 against bone); a plaque's shadow fell from its letters too and now
  falls from the plaque alone; darban's empty room has a pool of shade
  under its line. After: 74, and every dynamic type, hit region and
  Home clipping finding is gone. Left: the rest are contrast findings that
  do not match the pictures (bone on lamp black at about 15 to 1 reads
  "failed"), on the Board and the study's bubbles, plus Home's lines over
  the picture; the fade mask is not the cause (tried with it off, same
  list). Next: read `detailedDescription` and the element's own
  screenshot to see what the audit samples, then fix or waive each by
  name. The board's reasons cut at two lines ("Text clipped") are the
  design, the rest on tap. No new door.

- 2026-09-23 · sprint 11 (20098ee): the hitch numbers, and the tab tap
  unstalled. The simulator cannot give Apple's hitches: XCTest's scroll
  metrics return only durations there, and Instruments says "Hitches is
  not supported on this platform". So the app, launched with `--hitches`
  (the walk only, never the phone), times its own frames with a display
  link and writes each frame that lands more than half a frame late;
  `ChintanHitches` (in the walk target, run after the film) logs a window
  per gesture, and walk.sh prints the hitch time ratio in ms per s for
  each. These are the Mac's frames, so read them before against after.
  Before: first visits 60.6 ms/s (worst 132 ms), tab taps 63.8 (worst
  122), swipe 9.4, board scroll 17.0 (worst 25), study scroll 29.3 (worst
  117). Every tap between tabs stalled about a tenth of a second: each tab
  decoded and scaled the full scan of the painting again. Now the painting
  is decoded once, off the main thread, at the size the screen fills with
  it (`byPreparingThumbnail`), and it looks as sharp as before in both
  modes. After: first visits 50.3 (worst 133), tab taps 38.5 (worst 49),
  swipe 0.0, board scroll 19.2 (worst 31), study scroll 16.5 (worst 29).
  Still over 10 on a tab tap and on first visits; the next suspects are the
  three copies of the painting and its shades (one layer under all tabs,
  chunk G) and the Board's first fetch (its bare frame is still in the
  film at +500 ms). The audit is next in chunk 0. No new door.

- 2026-09-23 · sprint 10 (8f573b6): the walk, and the keyboard let go.
  The eyes: `ChintanWalk`, an XCUITest target (in the scheme's tests only,
  never the archive), walks the app while `simctl io recordVideo` films
  it: Home's ring and label, a press and hold, a swipe from Home and from
  the Board, the shelves scrolled, a leaf opened and held, the study's
  three rooms, a word typed and taken back unsent, the phone turned dark
  mid-walk (walk.sh flips it on the walk's mark), Home and the Board in
  dark. It photographs 21 states and logs every gesture with the clock;
  `scripts/frames.swift` (AVFoundation, no ffmpeg on yantar) cuts one
  contact sheet per gesture, a frame every 250 ms from just before to
  1.75 s after. The job's tool list allows only see.sh, so `see.sh --walk
  OUT` hands over to walk.sh; the job may name walk.sh directly later.
  What the film says about the swipe: it does nothing. The tabs are the
  system TabView, which has no swipe; a swipe left or right on Home or the
  Board leaves the tab where it was (the walk's notes: selected Home,
  Board, Board) and nothing on screen moves. A tap on a tab is a hard cut
  inside one 250 ms frame. The painting does not visibly reload on a
  return visit (the same picture, the same place, no flash, in light and
  dark). The one frame between states is the Board's first visit: at
  +500 ms the painting stands bare and brighter (its own ground, the shade
  not yet on), "The board" lettered, the plaques missing and Home's line
  ghosting through, then the board lands; that is the Board fetching its
  list on first appearance, not the painting. So the jank he feels is
  most likely the swipe that goes nowhere plus the hard cut; the fix
  (chunk G) is a paged swipe over one painting layer. Press and hold
  reveals nothing anywhere yet (chunk G). The walk found a real defect:
  once the study's keyboard was up nothing put it away (the keyboard
  covers the tabs, and the conversation did not dismiss it), so the only
  way out was to send a word. Now a drag down the conversation takes the
  keyboard down with the thumb, as Messages does, seen in the film across
  about a second. The composer does sit above the keyboard (seen), so C's
  "composer above the keyboard" is done. No hitch numbers yet (next
  sprint). No new door.

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

- 2026-09-23 · 06:43, his word on the study line: "Great job with the app
  chintan, we can take away the email to do workflow now as in remove it
  entirely." The board tab is now the only place his to-dos show; the day
  card by mail and its HEY week board are retired on the house side (BUTLER
  37), the job desk's ready postings arrive as dated lines with the Apply
  link, and the night roll at 20:58 still clears the list to tomorrow.

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
