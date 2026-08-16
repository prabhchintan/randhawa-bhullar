# Roadmap

One repository, two apps, three lanes. Randhawa is space, Bhullar is time,
and MemoryKit is the substrate both of them read: the shared files, the
shared iCloud schema, the idea of a memory. The apps are free to drift apart
in look, feature, and pace. The substrate is not free to fork. (Why one
repository? See the note at the end.)

Work is tracked as GitHub issues labeled `randhawa`, `bhullar`, and
`memorykit`, with milestones per app release. This file is the readable
summary; the issues are the working truth. The names, the story behind
them, and the rule that keeps that story quiet live in
[VISION.md](VISION.md).

## MemoryKit, the substrate

- Shipped: first release. Memories (a thought, a photo, a place, a time),
  App Group storage, optional sync through the user's private CloudKit
  database. 3.1 added `source` to a moment (local only, absent from the
  CloudKit schema). 3.2 added the shared place-name cache, the export file,
  and camera capture in the composer.
- The rule that outranks every item below: any change to the stored formats
  must remain readable by the previous shipped version of both apps, because
  users update the two apps at different times. The contract is documented
  in [MemoryKit/README.md](MemoryKit/README.md).

## Randhawa, space

- Shipped: 3.0, memories on the map, optional iCloud sync, the Map widget as
  the one widget. 3.1, the trail as an opt-in. 3.2, the ink: the trail as the
  default way the map is made (see "The one we reversed, twice" below), the
  map redrawn as blots and threads with today in orange, the veil between map
  and constellation, blots and memories you can open, a place sheet that is
  the natural door to writing a memory, export of everything, and a widget
  drawn with the same ink.
- Next: whatever the loop learns (see [LOOP.md](LOOP.md)); "on this
  day" surfaced on the map, not only in the list.
- Considering: iPad layouts that actually use the width; a quiet way to show
  the year's shape over time.
- Resolved: clustering was O(moments x clumps) on the main thread; 3.1 gave
  it a grid index and 3.2 moved all drawing into a per-tile overlay renderer
  from data prepared once per change, so a year of trail dots costs what a
  week of opens used to.

## Bhullar, time

- Shipped: 2.0, memories in the grid, gold days, "on this day". 2.1, swipe
  to change scale and dots you can open, with place names from Apple's
  geocoder. 2.2, gold memory days in the widgets, the camera in the composer,
  and the shared place-name cache.
- Next: whatever the loop learns.
- Considering: a year picker to look at past years' grids; the minutes scale
  on Apple Watch someday.

## The loop's backlog

The loop (LOOP.md) chips through this list on its own, one small piece per
run, in this order unless a message from the maintainer says otherwise. Each
item is written so a session can tell when it is done.

1. **Watch the ink on real data.** Tune blot alpha, thread alpha and the
   thread gap against the maintainer's own map at street and city scale
   until threads read as movement, not as a web. Done when two consecutive
   weekly summaries have nothing to change.
2. **A note to the loop, from inside the apps.** Today a memory that begins
   with `@loop` is filed as a note to the loop by `scripts/mymap.py`, which
   costs no app change but leaves the note on the map as a memory. The
   proper version: a quiet "Write to the makers" entry in each app's menu
   that opens the system mail sheet, prefilled to
   loop@pulse.prabhchintan.com, so the app itself still sends nothing and
   "no servers of ours" stays literally true. Anyone can use it (the public
   half of the loop); the maintainer's own address is what the loop treats
   as its private inbox. Copy stays quiet, one menu line. Done when it ships
   in both apps and the maintainer's first note through it arrives.
3. **One voice for the mail.** The site's Pulse worker already writes to the
   maintainer about visitors; the loop now writes from the same worker in a
   different voice. Give them one template, one sender family and one
   cadence so the inbox reads as one system, and let the loop's summary
   carry the site's numbers on Sundays if that proves useful. Not before 1
   and 2.
4. **"On this day" on the map**, not only in the list (from the Randhawa
   lane below).
5. **Gold in Bhullar's Lock Screen accessories** and the year picker, from
   the Bhullar lane, when nothing above is open.

## Both, eventually

- Say "open source" inside the apps and on the App Store pages, linking back
  to this repository
- Localization, starting with Punjabi
- A shared timeline view: every memory, place and time together (the closest
  the two apps will ever come to being one)

## Will not happen

- Accounts, passwords, or any sign-in of our own; the Apple Account is the
  account
- Analytics, tracking, or ads. Apple's own opt-in App Store analytics and
  the maintainer's own map are the only signals the project reads (see
  [LOOP.md](LOOP.md)); nothing in the apps phones home.
- Servers of ours; sync lives in the user's private iCloud, which we cannot
  read
- Location read without the user's explicit permission, in any release

## The one we reversed

Through 3.0 this file said, flatly, that background location would never
happen: location was read once per open, while the app was open, and never
otherwise. 3.1 breaks that. The reversal is written down here rather than
quietly deleted, because a promise that disappears from a document is worth
less than one that is argued with.

The case against it was that a map you have to earn by opening the app is a
better object than a map that happens to you, and that the surest way never
to leak a location is never to read one. Both are still true. What changed is
that the second app makes the first argument weaker: once a dot in Bhullar can
be opened, the question it answers is "where was I during this hour", and a
map made only of app openings answers that only for the hours you happened to
reach for your phone. The gaps were not restraint, they were just gaps.

So the promise became narrower, and the narrower version is the one that
carries the weight. As 3.1 wrote it, the first line read "off by default, and
off after every update"; the second reversal, below, rewrote that line and
only that line:

- It asks before it listens. First launch says in plain words what the map
  will do, then iOS asks in its own words, and iOS asks a second time before
  background access becomes permanent. Nothing is monitored until the user
  has said yes, and one screen (or Location in Settings) turns it off, at
  once.
- No continuous location, ever. Only significant-change and visit monitoring,
  the two low-power APIs. No location background mode, so the app cannot ask
  the system to keep it running.
- The cadence is a ceiling, not a schedule. Nothing polls, nothing wakes on a
  timer, and standing still produces nothing.
- Whatever it gathers can be taken back. "Forget the trail" deletes every dot
  the trail placed, on the device and in iCloud, and leaves the ones the user
  placed by hand.
- It still goes nowhere. Same file, same private CloudKit database, same
  absence of servers of ours.

If a future release cannot honour all five, it should turn the trail off
rather than weaken the list.

## The one we reversed, twice

3.1 shipped the trail off by default. 3.2 (2026-08-16) makes it the default:
a new install asks for location once, from the intro, and if the answer is
yes the map starts drawing itself. Someone who granted While Using before
3.2 is shown one card and asked. The reason is the same one that argued for
the trail in the first place, followed to its end. A map made of app opens is
a worse object than a map made of days; the argument for the trail was that
the gaps were not restraint, only gaps. Once that is believed, keeping the
better map behind a menu nobody opens is not caution, it is a worse product
with a clear conscience. The consent is unchanged in kind: the same iOS
prompt, the same second prompt from iOS later, the same one screen to stop.
What changed is that the app now says up front what it is for, and stops
pretending its opening gesture is the whole of it.

The list above still holds, and "off by default" was replaced rather than
deleted so that this document keeps the shape of what was promised when.

## Why one repository

Newton kept space and time separate. Minkowski fused them. The current
picture pulls them apart again, but asymmetrically: space is structure, and
time is the process that updates the structure. Two kinds of thing, one
substrate. That is exactly the shape of this codebase: two apps with their
own identities, one substrate they both read live on the same device. Repos
that share a mutable data contract belong together, because the worst bug
these apps could ever ship is the two of them disagreeing about what a
memory is.

The split criteria, written down so this stays a decision and not inertia:
extract MemoryKit as a versioned Swift Package when it goes quiet for
several releases while the apps keep moving; split the app repos only if
either app grows a life of its own (separate maintainers, separate
community). Git can split a directory out with its full history in an
afternoon, so nothing is lost by waiting until the need is real.
