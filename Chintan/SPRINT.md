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

The maintainer's word, 2026-09-23 20:05 (the study line), on the app as it
stands: "Art work is an absolute home run"; the day's line ("quiet evening")
"absolute chef's kiss"; "board study and visitors are amazing"; "incredible
stuff on this app". Weights (BUTLER 31): the painting-first Home, the one
line for the day, and the three rooms are the behaviours to keep. And his
ideas, which set chunks I to L below: Home "should only worry about today"
and be "the most calming place to be", an overview of the day and the date
and a line that changes with what is going on and where he is (the house
now learns home and work from the phone's fixes, POST /v1/location, and the
line says "quiet evening at home"); the titles of the actions "as minimally
descriptive as they can be while carrying the highest information density";
the art library "seemingly infinite" (the house: a third museum, Chicago,
and a seen ledger so nothing returns within a year) and every picture
covering the entire screen, never "weirdly re sized or cropped" (the house
now composes each picture for the phone's frame the way his example shows:
cropped to fill from a little above the middle, never letterboxed; the app
shows it edge to edge with its own dimming, no crop of its own);
the usage circles kept but "placed neatly below", the art given the room;
the app icon "classy like the app now"; the Board's week broken by day and
"later for the rest of them combined"; and the app made by the latest
models on the house's latest refinements, biased to high effort unless the
meters are low (the sprint workflow carries `effort`, from the gear).

The shape to grow into (three tabs, in this order; the fourth, the House,
was built in sprint 21 and cut on his word of 2026-09-24 04:46: the rings
on Home already give him the house's pulse, so a tab for it had no point):

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
round's time), `/v1/icon.png?seed=B` (the build's icon, since 09-24),
`/v1/paintings` (the shelf: today's first then the days ahead, each with an id and
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
   line, the thinking mark breathing. The composer above the keyboard, and
   the keyboard put away by a drag, seen in the walk (sprint 10). Time
   stamps and retry on a failed word built (sprint 22). C is whole on the
   app side; left, a reply the house finished while the app was closed
   (the id of a 202 is not kept, so today it reads as unanswered).
D. The house. CUT (his word, 2026-09-24 04:46, seeing the fourth tab:
   "I don't understand the point of the house vs the home, the speedometer
   circles on the home tab already give me highlights of the usage so I
   don't see the point of the house tab, remove"). Sprint 21 had built it
   (the voices as marks, the meters as bars, the last round); the house
   took it out the same hour, with the `/v1/household` door it had asked
   for, never built. The household's state stays the rings on Home and
   darban's word at the door; the system is felt, not displayed. Do not
   rebuild a house tab, a status page or a dashboard under any name.
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
   arrival. The stall on every turn of a page found and gone (sprint 21);
   with no test hand, a turn is 7.6 ms/s. Left in slice 1: the walk's own
   numbers are now mostly the test hand reading the accessibility tree;
   read them against the no-hand lines, and first visits (28.6) next.
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
I. Home is today (Prab, 2026-09-23 20:05; next after the open slice). One
   screen, the calmest place in the app: the painting; the date and the
   day's line from the house (its first sentence now says where he is when
   the phone has said: at home, at work, out); today's things only, each
   title cut to the fewest words that carry the most (the consequence and
   the hour in the title itself when they matter, "Caremark, call, before
   5" not "Call Caremark about the Zepbound prior authorization"); the
   meters as small rings placed neatly below, together, never floating on
   the art; the week and everything later leaves Home for the Board. The
   sprint measures Home by how much painting is visible with nothing
   pressed, and by the label reading in one breath. Built (sprint 17):
   today and past only, each thing in the phone's own cut ("Caremark,
   call") with its hour apart in gilt, the rings and the label under a
   gilt hairline. Since 2026-09-24 (his word at 03:56) the rings, the
   hairline and the label stand on the bar itself, a foot below the scroll,
   so the day's lines sit lower and the painting has the height of the
   screen. Left, the house's: `GET /v1/titles` (shape in the
   ledger), whose cuts the app already prefers to its own; the place in
   the day's line (from the cockpit, as now).
J. The Board by day. This week broken by day, one gilt date per leaf as
   now, Later for the rest combined (one shelf, undated things and the
   weeks beyond, sorted by date); the title rule of I applies everywhere.
   The title rule built on the Board and in Home's held plaque (sprint 18,
   both prefer `/v1/titles`); the shelves and the Study's rooms stand on a
   smoked mount (`.mount()`) against a bright picture. The days built
   (sprint 19): Today, Tomorrow, then each weekday left through Sunday on a
   shelf of its own, Later for the rest; the date mark only where the
   shelf's name is not the day (Later, a thing past). J is whole.
K. The picture edge to edge. Every picture from the house is already the
   phone's frame (1179 by 2556). The composition since 2026-09-24 (his word
   at 03:56, seeing Portrait of an Officer drawn out tall on Home: keep
   "the original aspect ratio and somehow make it edge to edge", with
   "reflections on all sides"): the work whole at the frame's width, never
   stretched, never cropped, sitting high (three tenths of the free height
   above it), and the frame filled to its edges with the work's own
   reflection on every open side, as in a mirrored case, the reflection
   softened and dimmed and darker toward the edge so the work reads as the
   work. The scan's border (a black line, a mount, a miniature's page) is
   trimmed by the house before composing. Only works at least 1.25 tall for
   their width are picked, so the mirror never outweighs the work. Each
   record carries `fit` (the composition's name, "mirror") and its picture
   path carries it too (`/v1/paintings/ID.mirror.jpg`), so a recut picture
   is a new key and a new URL to the phone and its caches; the app keys its
   kept pictures by id and fit. The app shows the picture edge to edge with
   scaledToFill and no offset of its own, keeps its scrim, and keeps its 4
   percent trim (it now cuts only the mirror's edge). Before 09-24 the
   composer cropped from a little above the middle, and a bug in it (the
   height forced up to the frame's) stretched every work shorter than the
   frame; the ledger of sprint 17 had named the officer. Three museums, a
   seen ledger, no repeat within a year.
L. Where he is. CoreLocation with significant-change monitoring (the
   phone wakes the app a handful of times a day, near free on battery), the
   When In Use then Always permission asked in the house's own words on the
   Settings tab, never at launch; each fix posted to `POST /v1/location`
   {"lat","lon","acc","at"} and forgotten by the app; the reply names the
   place (home, work, out) for the app's own use. The house never sends a
   coordinate anywhere and learns the places from the hours alone. App side
   built (sprint 20): "Where you are" on the Settings sheet, the phone's
   choice kept apart from the permission, a fresh fix on opening the app at
   most every 15 minutes, the place last named shown there. Left: seen on
   his phone (the simulator's eyes never post), and the place on Home
   itself once the house's day's line carries it.
M. The icon. Built by the house 2026-09-24 05:04 on his word ("as classy
   as the app is now ... I did the concept, the colors just feel cheap ...
   how crazy is it for the app icon itself to change as works of art
   randomized to fit this frame, and have it be different every time with
   new builds, so it's never constant"). His jharokha kept as the concept,
   the saffron and paper gone: the pointed arch as a gilt hairline frame
   with a gilt sill on lamp black, and through the arch a work of art,
   cropped close and high (the face), from the shelf. A phone cannot change
   its own icon quietly (an alternate icon rings a system alert every
   time), so the icon is cut per build: `GET /v1/icon.png?seed=BUILD` on
   the house (painting.py `icon`, the work chosen by the build number from
   the shelf's forty or so), fetched by ship.sh before the archive, the
   checked-in icon (a Velázquez) standing when the house is out of reach.
   Every build, nightly or a sprint's, carries a new work; the icon on his
   phone changes as often as TestFlight installs. makeicon.swift retired.
   Left: seen in the home screen grid on his phone beside Apple's own; the
   dark and tinted variants (iOS 18) if he wants them; a title on the
   TestFlight card is Apple's, not ours.
F. Settings and the edges. The health dot; settings one tap away; a
   version line; then on his word a widget (App Group, extension target),
   notifications (an APNs key, his hands), Siri. His steer (2026-09-24):
   when Settings is next touched, its actions should look pressable (not
   bare gilt words) and its wall should stand on the painting like every
   other surface, not on plain bone or lamp black.

## The ledger (newest first)

- 2026-09-24 · by the house, on his word at 05:04 (the TestFlight card with
  the saffron jharokha: an icon as classy as the app, his concept kept, the
  colours re-cut, and a different work of art in it on every build). Chunk
  M built as it says: painting.py `icon` composes 1024 square, lamp black,
  the arch in gilt (frame and sill), the work through the opening cropped
  to 86 percent of its width and high, where a face sits; `ghar painting
  icon [--seed S | --id ID] [--out P]`; the door `/v1/icon.png?seed=B`;
  ship.sh fetches it with the build number as the seed, so one build has
  one work and the next another, and keeps the checked-in icon when the
  house does not answer; both ship steps carry CHINTAN_HOUSE. Seen on a
  contact sheet of six (Velázquez, El Greco, a Kangra nayika, a Mandi lady
  with doves, the British officer, Shirlaw) in the phone's rounded square
  on a dark ground, sent to him. The checked-in icon is the Velázquez.
- 2026-09-24 · sprint 22 (b1470bb): the study tells the hour, and a word
  that went unanswered says so. Each run of the conversation carries its
  day and time in gilt small capitals on a small mount, centred over the
  first word, and again wherever an hour has passed or the day has turned
  ("Today 4:54 AM", "Yesterday 9:10 PM", "Tuesday 9:01 PM", then "Sep 12
  7:41 PM" past a week). A word of his with nothing after it, and the
  house not thinking on it, is unanswered: under it, on a mount at the
  right, "The house did not answer." in italic (or the plain reason, "The
  house is not answering. Are you on the tailnet?", "No house address
  yet. Add it in Settings.") and Try again in gilt small capitals in a
  square hairline frame, which sends the same word once more where it
  stands, no copy of it added. It is read from the conversation itself, so
  it holds after the app was closed mid-wait. The old wifi line over the
  composer is gone. Seen in both modes: chintan's room ("Tuesday 9:01 PM"
  over the sample), darban's staged on the simulator only with a word
  answered two hours ago and one unanswered (two stamps, the mark). At the
  largest text the first look broke "Try again" mid-word ("AGAI / N");
  now at the accessibility sizes the button stands under the words, whole.
  Retry was not tapped against the real house (it would send darban a
  real word). The hitch numbers, before then after, same machine, same
  hour, median of three (ms/s): study scroll 4.7 to 6.2 (runs 4.7 7.7 1.8,
  then 4.9 7.9 6.2, within the meter's spread, under 10); untouched, board
  scroll 14.9 to 13.8, tabs 30.8 to 33.6, swipe 19.6 to 19.4, first visits
  35.0 to 41.5, no hand 6.5 to 7.8. The Mac read higher than sprint 21 on
  every line today (first visits 23.8 then), so read these against each
  other, not against the older lines. No new door. Seen and not the app's:
  the house's Adoration of the Christ Child still carries a hard line near
  the top and a dark band from about three quarters down (sprint 21's
  note, K's refit, the house's to check).

- 2026-09-24 · by the house, on his word at 04:46 (a photo of Home with the
  day's lines circled and an arrow down: "This could move down"; and the
  House tab: "remove"). The lines: sprint 21's patch had meant them lower,
  and its NOTE said the pictures showed them lower, but its own Home shot
  (and his phone) had them hanging mid-painting with a third of the wall
  empty beneath: the scroll's content was a frame with a minimum height and
  no alignment, so SwiftUI centred the day inside it. Now the frame is
  aligned to its foot and the day stands just above the hairline, the
  painting whole above it. A slip of the eyes, in the house's ledger. The
  House tab: cut whole (the case, the view, the Household door in the
  client, the project file, the walk's and see.sh's tab lists); chunk D
  closed as CUT. Committed from chintan on the study line and shipped by
  hand through the chintan job on yantar, no sprint.

- 2026-09-24 · sprint 21 (813d73c, 45752e2): the stall on a turn found,
  and the House opens. The hitches first, on the steer. The frame log
  showed the cost was not in the slide: every change of page, tap or
  swipe, lost one frame of 20 to 40 ms at the moment it began, then slid
  clean. Taking suspects out one build at a time (Instruments needs a
  permission this run cannot give): the haptic, no; the bar, no; empty
  pages, gone; the Board alone and Home alone, clean; the Study alone,
  the whole stall, even on a turn from Home to the Board far from it. In
  the Study, the header and the composer: the three rooms sat in a
  ViewThatFits, which laid them out twice on every turn of any page. Now
  they are measured only at the large text sizes (seen: unchanged at
  normal size, and still sliding under the thumb at the largest); the
  composer's growing field costs a little and stays. The meter grew a
  second reading: `walk.sh --hitches OUT [RUNS]` runs the hitches alone
  RUNS times and prints the median, and after the test's walk the app,
  launched plainly with `--self-walk`, turns its own pages as a tap does,
  with no test hand reading its accessibility tree (hiding that tree's
  pages from the hand sent every number up, the scrolls to about 32:
  the hand's reading is a large share of the old numbers, and a phone
  never pays it). Before then after, median of three (ms/s): swipe 57.3
  to 11.4, tabs 40.5 to 27.2, first visits 34.5 to 23.8, reveal 36.2 to
  34.5, board scroll 11.8 to 12.0, study scroll 3.1 to 3.1; with no hand,
  tabs 37.4 to 7.7 and Home to the Board 25.4 to 0.0, resting 0.0. Then
  the House, the fourth tab ("building.columns", lettered like the
  rest): the painting above, "The house" and a line ("All three home.";
  "darban is not home."; "The round failed." once hands report) over the
  shade, and on leaves: the voices as three names on one leaf, each
  beside a mark (gilt home, saffron not), the meters as bars of ink
  (gilt, saffron past three quarters) with the hour each comes back in
  gilt capitals, and "Last round Wed 9:08 PM" in italic under them. The
  first look gave each voice its line from `/v1/voices` and pushed the
  meters under the bar; the lines are the Study's, so the voices became
  marks and the whole page reads above the bar. With four pages, median
  of three: no hand unchanged (tabs 7.6, neighbours 0.0), so the page
  costs nothing of its own; with the hand, tabs 35.2 and swipe 18.9, the
  hand reading one more page's tree. Seen in both modes and at the
  largest text (the voices stand one under another). Two things seen
  and not the app's: once in dark, Home's museum label was missing for
  one shot and back in the next; and between 4:23 and 4:30 the house
  began serving The Adoration of the Christ Child composed whole, with a
  hard line near the top and a darkened band from about two thirds down,
  which is letterboxing that K forbids (the house's refit, to check). The
  door the House needs: `GET /v1/household` returning {"hands": [{"name":
  "the round", "last": ISO 8601, "next": ISO 8601 or null, "state":
  "ok"|"late"|"failed"|"off", "line": "what it does, a few words" or
  null}], "doctor": {"ok": true, "words": ["one line per finding"]}};
  404 or 405 reads as no door and the page shows voices and meters alone.
  The pulse's `tended` is now read (it was served, unused).
- 2026-09-24 · by the house, on his word at 03:56 (a photo of Home, Portrait
  of an Officer stretched tall): the picture is never stretched again, and
  the foot stands on the bar. House side: the composer's crop branch forced
  every work shorter than the frame up to the frame's height (the ledger of
  sprint 17 had named the officer); the composition is now the work whole at
  the frame's width in a mirrored ground, its own reflection on every open
  side, softened and dimmed, darker toward the edge, the scan's border
  trimmed first (K above); records carry `fit` and the picture path carries
  it, so the phone fetches every picture again; the shelf refitted. App side:
  `Painting.fit` in the key, so the kept pictures are let go; Home's rings,
  hairline and label leave the scroll for a foot below it, standing on the
  bar, and the day's lines sit lower with a shorter fade. The door's session
  that wrote this cannot push, so the patch went to yantar as the steer of
  the next sprint, which applied it, looked, and shipped (its own line
  follows above). The shelf on the house was refitted the same hour.

- 2026-09-24 · sprint 20 (39d7d82): where he is (L), and Settings on the
  wall. The Settings sheet (the gear in the Study) was the stock grey
  grouped list, which the look leaves out by name; now it is a wall on bone
  or lamp black: "The house" and "Where you are" in gilt small capitals over
  a hairline, the address on a line of its own with Save beside it, "Is it
  home?" under it with the answer in italic, every action lettered in small
  serif capitals, no cards. "Where you are" says in one note what it does
  and that only the house hears it; "Tell the house" asks the phone for
  location while open, then "Tell it always" for always (the phone's own
  prompt, in the house's words); from then on significant-change monitoring
  wakes the app when he has moved, and each opening of the app asks for one
  fix at most every 15 minutes. Each fix goes to `POST /v1/location`
  {"lat","lon","acc","at"} (at in ISO 8601) and is forgotten; once on, the
  room shows the place the house last named in the serif with its hour in
  gilt ("At home 2:46 AM"), "The house hears a few times a day." in italic,
  "Stop telling" in quiet ink, and the note shrinks to its promise. Refused
  in the phone's Settings, the room says so and opens them. The house
  address is now readable after the first unlock, since a wake for a move
  mostly comes with the phone locked (the address kept before is moved over
  when he says yes). Seen in both modes at rest (`see.sh OUT settings`) and
  on (`settings@on`: location granted, a place heard, then reset); the
  first look showed the tailnet address in plain view, so the eyes now
  photograph it redacted; the tabs unchanged. The simulator never posts a
  fix (the app launched with `--house` never monitors). No hitch numbers
  (nothing that moves was touched). The door, as the app reads it: 200
  {"ok": true, "place": "home"|"work"|"out"|null}; 404 or 405 reads as no
  door yet and nothing is shown as heard. Not probed from this run (the
  sprint's tools do not reach the house), so the first real fix from his
  phone is the check.

- 2026-09-24 · sprint 19 (a14f19a): the week by day. The Board's "This
  week" shelf is gone; each day left in the week is a shelf of its own,
  named on its mount the way Today is: "Tomorrow" for the next day, then
  the weekday by name ("Saturday", "Sunday"), and Later for everything
  beyond Sunday and the undated, combined and soonest first. Where the
  shelf's name is the day, the leaf no longer letters the date at its
  right ("Thu Sep 24" under Today, "Fri Sep 25" under Tomorrow), so the
  title and its reasons take the whole width: the calcium scan's "1:30
  PM" now sits beside its title on one line where it wrapped under it.
  Later keeps a gilt date on each leaf, and a thing whose day has passed
  keeps its saffron one under Today. Seen in both modes at rest, with a
  leaf opened under Tomorrow, and scrolled to Later with a leaf opened.
  No hitch numbers (nothing that moves was touched). No new door.

- 2026-09-24 · sprint 18 (f6ce14a): names that hold, and one name for a
  thing. Over The Adoration of the Christ Child, the Board's "This week"
  was lettered straight across the angels' bright faces and could not be
  read, and the Study's "darban" and "yaar" went into the cherubs. Now
  each shelf name stands on a small mount of smoked glass (ultra thin
  material with lamp black, square cornered like a wall label, its edge
  on the leaves' edge), and the three rooms share one mount, its edge on
  the bubbles'; the picture still shows through. The Board names each
  thing by Home's cut ("Caremark, call" where it read "Call Caremark"),
  the house's `/v1/titles` first when it answers, the hour in gilt small
  capitals after the last word ("Testosterone draw 3 of 3 8 AM"); first
  look had a long title split around its hour ("Coronary artery 1:30 PM /
  calcium scan"), then cut to "1:30..."; now the hour wraps whole under
  it. Home's held plaque names the thing by the same cut. Seen in both
  modes at rest, a leaf opened, a thing held on Home, and in the walk's
  film (the mounts ride with the shelves through the scroll; the rule
  slides to darban with the names legible throughout). The hitch numbers,
  before then after (ms/s): reveal 44.0 to 28.1, first visits 35.4 to
  32.2, tab taps 51.4 to 46.1, swipe 54.5 to 53.8, board scroll 16.3 to
  5.2 (the shelf names' text shadows are gone, the likely cause), study
  scroll 1.5 to 1.5. The audit: 14 to 11, the 10 unnamed full-screen
  elements left and one study bubble's "partially unsupported"; the
  bubbles' readings came and went between the two runs with no change to
  the study's bubbles, so they are the audit's noise, not this sprint's
  fix. No new door; `/v1/titles` (sprint 17's shape) now serves the Board
  as well as Home.

- 2026-09-24 · sprint 17 (3359a41, ac61086): Home is today. The week's
  calendar leaves are gone from Home; it holds only what is due today or
  already past, each in its fewest words in the serif, the thing before
  the deed and no articles ("Caremark, call" where it read "Call
  Caremark" on a leaf), the first hour the house wrote set apart in gilt
  small capitals ("8 AM", "before 5 PM"), and "since Tue" in saffron for a
  thing whose day has passed. Under the thing a gilt hairline, and under it
  the rings together beside the label, top-aligned, the foot of the wall.
  With nothing pressed the date now starts about 110 points lower, so
  more of the painting shows; held, the thing still grows its plaque with
  the whole why. Seen in both modes, held, and at the largest text (the
  title wraps, the rings stay together, the label scrolls up out of the
  foot as before). The week and later are the Board's (J, next). K: the
  app's 1.04 trim was taken off and the pictures showed why it exists:
  measured on the shelf, the Met's scans carry a 1 pixel black line and
  the frame's lip to about 24 pixels on each side (The Adoration of the
  Christ Child showed dark strips down both sides), miniatures carry their
  page to about 40 pixels (A Lady Gazing at Doves), so the trim is back,
  named for the scan's edge. The app now fetches again any kept picture
  not 1179 by 2556 (every picture on today's shelf already is). No hitch
  numbers (nothing that moves was touched). Doors needed from the house:
  (1) `GET /v1/titles` returning {"titles": [{"line": LINE, "title":
  "Caremark, call", "hour": "before 5 PM" or null}]}, LINE the task line
  after its checkbox exactly as `/v1/board` prints it; the app prefers
  these to its own cut and cuts its own on a 404 (today it is 404). (2)
  `ghar painting refit` trims the scan's border (uniform rows and columns
  at each edge) before composing, so the app's trim can go. (3) Portrait
  of an Officer (met-435792) looks stretched tall on the shelf, the
  locket's oval and the face drawn out, against K's "never stretched":
  the house to check its ratio gate, and for the small grey Met scans.

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
