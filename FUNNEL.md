# The funnel

From the private app to the public pair. Since 2026-09-30, on the
maintainer's word from the study: chintan, the private app in `Chintan/`,
is the workshop where ideas are tried on one person first; Randhawa and
Bhullar are where the ones that hold up go to live, sanitized, for
everyone. This file is the ledger of that passage and the rules of it.
One read before an idea moves, one line when it does.

## The shape

Three apps, one repository, two lanes.

- **The workshop lane**: chintan, built by sprints on yantar (the
  maintainer's Mac, `.github/workflows/sprint.yml`, brief in
  `Chintan/SPRINT-BRIEF.md`, memory in `Chintan/SPRINT.md`), shipped by
  TestFlight to one phone. It may talk to the maintainer's house and know
  his day. It is where a thing is tried.
- **The public lane**: Randhawa and Bhullar, built by the loop on a
  GitHub-hosted Mac (`LOOP.md`, `loop/SESSION.md`), released through the
  shipping gate, carried by strangers. The four refusals hold: no
  accounts, no tracking, no servers, no noise.
- **The funnel** between them is this ledger plus two hands: the sprint
  names what a stranger would want (a candidate), chintan cuts it for
  everyone (a cut) and files it to the loop's inbox through the
  authenticated door (`ghar funnel file`), and the loop builds it under
  its own covenant and ships it when a release is earned. Nothing crosses
  by copying files from `Chintan/` into the public targets; every crossing
  is rewritten for a person who has no server and never will.

## What crosses, what never does

An idea crosses when it is a way of seeing, arranging, moving or reading
that a stranger's own data can carry: a layout, a gesture, a type
discipline, a grouping, a quiet line, a tool that lets the loop see its
own work. It crosses as the public app's own feature, in its own voice,
against its own data (the map, the grid, the memories), and it goes
through the loop like anything else.

Never crosses:

- The house door and anything that needs a server: paintings served
  from home, the board, the voices, the visitors, the pulse, the word
  posts. The public apps make no network call of their own, ever.
- The maintainer's data and the senses that gather it: HealthKit,
  CoreMotion, Always location, Wi-Fi names, the opened-apps intent,
  MetricKit uploads. Randhawa's trail keeps its five constraints and
  nothing joins them.
- Hidden switches: launch arguments, test hooks, staged looks. The
  public apps have no `CommandLine.arguments` behaviour at all.
- Anything on the maintainer's list in `LOOP.md`, What waits for the
  maintainer: a new permission string, a stored format, a CloudKit
  record, a promise, a price, a name. Those cross only on his own word,
  written in the cut and repeated in the inbox note.

## The quiet check

`scripts/quiet.py` runs on every push and pull request (`build.yml`), in
the sprint before it commits, and on the house before anything is filed.
It fails on: a private address or the house's port anywhere; a house
door path (`/v1/`) or `CHINTAN_HOUSE` outside `Chintan/`; networking,
HealthKit, CoreMotion, NetworkExtension, MetricKit or arbitrary loads in a
public target; a launch-argument switch in a public target; a new
permission or background mode key in a public plist that the previous
commit did not have; an em or en dash anywhere. What it cannot know, the
maintainer's own life, is checked on the house with a private word list
(`ghar funnel check`), never published here. The rule the list enforces
is in words in `Chintan/SPRINT-BRIEF.md`: the ledger says what the app
does and how it looks, never what the maintainer's life contains.

## The passage of one idea

1. **Candidate.** A sprint ends its ledger line with `Funnel:` and one
   sentence naming the thing a stranger would want, in the public apps'
   terms, no house words. chintan copies it under Candidates below.
2. **Cut.** chintan writes the cut: which app, what it becomes for
   everyone, what it touches (files, formats, permissions), which of the
   maintainer's list it needs, and the one honest What's New sentence it
   would earn. A cut that needs his word waits for it, in this file, with
   the date he gave it.
3. **Filed.** `ghar funnel file N` posts the cut to the loop's inbox
   through the authenticated door, marks the row Filed with the date. The
   loop treats it as a note from chintan (inside scope, the maintainer's
   newer word wins). The scheduled run picks it up; `--wake` starts one.
4. **On main.** The loop builds it, runs the quiet check, commits, and
   writes the row's status in its report; chintan marks it On main with
   the commit.
5. **Shipped.** It rides the next earned release. The row gets the
   version. A row that the loop declined or narrowed says why, in one
   line, and stays.

## Candidates

Named by a sprint or by the house, not yet cut. One line each.

- a reminder's note that ends on a whole word, and the next few days named by their weekday even across a weekend. (sprint 60, 2026-10-07)
- a quiet mark on the opening screen when something new has arrived since you last looked, so a returning person sees at a glance that there is something to open. (sprint 55, 2026-10-07)

- a line at the foot of settings naming the version and the day it was built, so someone writing in about a problem can say which one they have. (sprint 54, 2026-10-01)

- Eyes for the pair: a `scripts/see.sh` for Randhawa and Bhullar like
  `Chintan/scripts/see.sh` (simulator, every screen, light and dark, the
  largest text, a VoiceOver audit), so the loop sees its work before and
  after. (house, 2026-09-30, from sprints 40 to 53)
- The largest text and VoiceOver discipline from sprints 52 and 53: no
  blank elements on a page, layouts that swap at accessibility sizes,
  marks that grow with the words. (house, 2026-09-30)
- The one line for the day: a sentence on Bhullar's grid that changes
  with the date and what the grid holds (a gold day, a first memory, a
  quiet stretch), from the day's own data only. (house, 2026-09-30)
- The museum label: the plaque typography and the small exact caption
  under a memory's photo in both apps. (house, 2026-09-30)
- Alone mode: a tap that clears every control from the map or the grid
  and a tap that brings them back, from chintan's painting alone.
  (house, 2026-09-30)
- Reminders in Bhullar, the board's Today, This week, Later grouping and
  done means gone, as local notifications from a `reminders.json` beside
  the other files. Needs his word: a new permission and a new CloudKit
  record. The spec is in the house. (house, 2026-08-29, restated
  2026-09-30)

## Cuts

Written for the loop, waiting to be filed or waiting on his word.

### 1. Eyes for the pair

Both apps. A `scripts/see.sh` at the repo root that builds Randhawa and
Bhullar for the simulator, boots one iPhone, launches each app to each of
its screens (Randhawa: the map, a memory, the trail screen, the menu;
Bhullar: each of the five scales, a memory day, the menu) in light and
dark and once at the largest accessibility text, screenshots each to a
folder, and runs an XCUITest `performAccessibilityAudit` on every screen
in light and dark, printing the issues by screen. No launch arguments in
the apps: the walk drives the real UI by accessibility identifiers, which
the apps gain where they have none (identifiers are not behaviour). A new
UI test target per project, compiled only for the walk. Nothing in the
shipped binaries changes except identifiers. The loop's session reads the
pictures before deciding and after building. What's New: none, this is
the loop's own sight; it rides along. Touches: `scripts/see.sh`, two UI
test targets, identifiers in views, `loop/SESSION.md` steps 1 and 4.
Needs his word: no.

### 2. The largest text and VoiceOver

Both apps. With the eyes from cut 1, walk every screen at the largest
accessibility size and with the audit on, and fix what they show: pages
or overlays that VoiceOver reads as blank, labels that clip or overlap,
tap targets under 44 points, controls without names, layouts that should
swap from a row to a column at accessibility sizes (`AnyLayout`), marks
that should scale with the words (`ScaledMetric`). What's New, honest
and earned: "Reads better at every text size and with VoiceOver."
Touches: views only. Needs his word: no.

## Filed

(empty)

## On main

- 1. Eyes for the pair, on main 2026-09-30 (ee73f55): `scripts/see.sh`,
  `Walk/`, the RandhawaWalk and BhullarWalk schemes. Narrowed in one
  place: Bhullar has no menu, and its envelope leaves for Mail, so its walk
  photographs the list of memories instead.
- 2. The largest text and VoiceOver, filed 2026-10-01, first pass on main
  2026-10-07 (8db4479, eb308d7, 8269081, cfb6bb1, b4eceb3, 54bb0e9).
  Bhullar's day line stacks instead of truncating and its hint wraps clear
  of the plus; the corner controls keep their glyph in the circle inside a
  44 point target, with names and the large content viewer; the
  percentage and the intro title scale; the offer cards and the intro
  scroll rather than cut off; the composer's photo buttons stack; a
  memory reads from the leading edge. The audit went from 209 findings to
  186, hit regions from 16 to 2 (both Apple Maps' Legal). Narrowed: the
  composer still truncates at the largest text, because inside a scroll
  view its field would not take focus; contrast is left alone, since the
  tertiary hints are the apps' quiet voice and the cut did not name it.

## Shipped

(empty)
