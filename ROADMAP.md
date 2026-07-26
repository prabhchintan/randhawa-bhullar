# Roadmap

One repository, two apps, three lanes. Randhawa is space, Bhullar is time,
and MemoryKit is the substrate both of them read: the shared files, the
shared iCloud schema, the idea of a memory. The apps are free to drift apart
in look, feature, and pace. The substrate is not free to fork. (Why one
repository? See the note at the end.)

Work is tracked as GitHub issues labeled `randhawa`, `bhullar`, and
`memorykit`, with milestones per app release. This file is the readable
summary; the issues are the working truth.

## MemoryKit, the substrate

- In review: first release. Memories (a thought, a photo, a place, a time),
  App Group storage, optional sync through the user's private CloudKit
  database.
- The rule that outranks every item below: any change to the stored formats
  must remain readable by the previous shipped version of both apps, because
  users update the two apps at different times. The contract is documented
  in [MemoryKit/README.md](MemoryKit/README.md).

## Randhawa, space

- In review: 3.0. Memories on the map, optional iCloud sync, the Map widget
  as the one widget.
- Next: tap a memory dot on the map to open that memory directly; surface
  "on this day" in the map view, not only in the list.
- Considering: camera capture in the composer; iPad layouts that actually
  use the width.

## Bhullar, time

- In review: 2.0. Memories in the grid, gold days, "on this day".
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
- Background location; location is read once per open, while the app is
  open, and never otherwise

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
