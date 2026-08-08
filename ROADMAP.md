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
  database.
- In review: 3.1 adds `source` to a moment, so a dot the user placed by
  opening the app is distinguishable from one the trail placed. Local field
  only, deliberately absent from the CloudKit schema, so no Production
  deploy gates the release.
- The rule that outranks every item below: any change to the stored formats
  must remain readable by the previous shipped version of both apps, because
  users update the two apps at different times. The contract is documented
  in [MemoryKit/README.md](MemoryKit/README.md).

## Randhawa, space

- Shipped: 3.0. Memories on the map, optional iCloud sync, the Map widget
  as the one widget.
- In review: 3.1. The trail, off by default: dots that arrive while the app
  is closed, at a cadence the user picks, with a one tap "forget the trail"
  that takes back every dot it placed.
- Next: tap a memory dot on the map to open that memory directly; surface
  "on this day" in the map view, not only in the list.
- Considering: camera capture in the composer; iPad layouts that actually
  use the width.
- Watch: greedy clustering is roughly O(moments x clumps) and runs on the
  main thread when the map appears. Opening the app has always kept that
  number small. A year of trail dots will not, so the map will need either
  a spatial index or a background recluster before that becomes a hitch.

## Bhullar, time

- Shipped: 2.0. Memories in the grid, gold days, "on this day".
- In review: 2.1. Swipe to change scale, and a dot is now something you can
  open: tap one to see where you were during that span and what you kept.
  Place names come from Apple's geocoder, since Bhullar draws no map and a
  place has to arrive as a word.
- Next: gold memory dots in the widgets.
- Considering: a year picker to look at past years' grids; the minutes scale
  on Apple Watch someday.

## Both, eventually

- Say "open source" inside the apps and on the App Store pages, linking back
  to this repository
- Localization, starting with Punjabi
- A shared timeline view: every memory, place and time together (the closest
  the two apps will ever come to being one)

## Will not happen

- Accounts, passwords, or any sign-in of our own; the Apple Account is the
  account
- Analytics, tracking, or ads
- Servers of ours; sync lives in the user's private iCloud, which we cannot
  read
- Location read without the user having asked for it, in any release

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

So the promise is now narrower, and the narrower version is the one that
carries the weight:

- Off by default, and off after every update. The user turns it on, alone, in
  one screen that says exactly what it will do.
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
