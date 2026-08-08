# Bhullar (v2.1, time)

A deliberately minimal iOS app: a telescope for time. One grid of dots, five
zoom levels; swipe the grid sideways to move between them:

- **12 months** of the year
- **52-odd weeks** of the year
- **365-odd days** of the year (the original Randhawa v1 view, which lives
  here now)
- **24-odd hours** of today
- **1,440-odd minutes** of today

Elapsed units fill in, the current unit glows orange, and the caption reads
"Day 183 of 365 · 182 left".

Since 2.0 the grid can hold more than progress. Tap the plus button and write
a memory down; the day (or hour, or month) it belongs to turns a soft gold in
the grid, and when its date comes around again it resurfaces under the caption
as "on this day". Memories are shared with Randhawa, the sibling map app one
directory up: made in either app, shown in both. Randhawa gives a memory its
place; Bhullar gives it its time.

New in 2.1, a dot is something you can open. Swiping is the zoom now, which
frees the tap to mean "this one": tap any elapsed dot and Bhullar answers what
that span of time held, where you were during it and what you kept from it.
Places arrive as words, not as a map, since Bhullar draws no maps; consecutive
moments within about 150 metres are folded into one stay and named through
Apple's geocoder. Turn on Randhawa's trail and these fill in on their own.
A dot still ahead of now says only "Not yet."

Only memories light a dot gold, never places. Somewhere you merely were is not
the same as something you chose to keep, and a grid that glowed for every day
you left the house would say nothing at all.

## Data and privacy

The grid itself still needs nothing: every dot is computed from the current
date. Memories are the only stored data, and they live in the App Group
container (`group.Prabhchintan.Randhawa`) both apps share. Bhullar stores no
location of its own and asks for no location permission; opening a dot reads
the moments Randhawa already wrote to that shared container. Naming a place
sends its coordinate to Apple's geocoder, the same lookup Randhawa has always
made when a memory is saved, cached in memory for the life of the process. **iCloud sync is
optional and off by default**; when the user turns it on (in either app, the
switch is shared), memories and Randhawa's moments are mirrored into the
user's private CloudKit database in `iCloud.Prabhchintan.Randhawa`. We cannot
read that database, we run no servers, and there is no account system: the
user's Apple Account is the account. Privacy label stays **"Data Not
Collected"**; re-verify Apple's App Privacy Details wording at submission.

## What's inside

```
Bhullar.xcodeproj          Two targets: the app and its widget extension
../MemoryKit/              Shared with the Randhawa project (referenced by
                           relative path): Memory + Moment models, App Group
                           persistence, CloudSync (CKSyncEngine), shared UI
Shared/
  TimeScale.swift          Pure date math for all five scales
  DotGrid.swift            One Canvas that draws the dots (gold highlights
                           for units holding memories, and cell-based hit
                           testing so a dot can be tapped at any scale)
Bhullar/
  BhullarApp.swift         App entry point
  ContentView.swift        Full-screen grid, swipe to zoom, tap a dot to
                           open it, memories, captions
  Bhullar.entitlements     App Group + iCloud (CloudKit)
  Assets.xcassets          App icon (1024 square, no alpha) + accent color
BhullarWidget/
  BhullarWidget.swift      Three widgets: Day in Dots, Year in Dots, and the
                           configurable Dots at Any Scale
  BhullarWidgetBundle.swift
  BhullarWidget.entitlements    App Group only; widgets never sync
  Info.plist               WidgetKit extension point
```

Both targets compile the two `Shared/` files, so the app and widgets always
draw time identically. The app target also compiles `../MemoryKit`.

One honest detail: on daylight-saving days `TimeScale` counts real elapsed
hours between midnights, so the day shows 23 or 25 dots (and 1,380 or 1,500
minutes). `Calendar`'s `range(of: .hour, in: .day)` always claims 24, verified
by test, so the day scales do their own midnight-to-midnight arithmetic.

## Build & run

1. Open `Bhullar.xcodeproj` in **Xcode 16 or later**. Keep the folder layout:
   the project references `../MemoryKit`, so Bhullar must stay next to it
   inside the Randhawa directory.
2. First build after 2.0 (already done, kept for a fresh machine): automatic signing must provision the **App Group**
   and **iCloud (CloudKit)** capabilities on the app target. If it complains,
   open *Signing & Capabilities* once and let it refresh. The widget target
   needs only the App Group.
3. Select the **Bhullar** scheme and a simulator or device, then Run (Cmd-R).
4. Widgets: long-press the Home or Lock Screen, tap plus, search "Bhullar";
   there are three, so several scales can sit on the Home Screen at once.

Deployment target is **iOS 17.0**. Bundle IDs `Prabhchintan.Bhullar` /
`Prabhchintan.Bhullar.BhullarWidget`, team preset, version **2.1 (build 5)**.

## CloudKit: one manual step before release

The CloudKit schema (record types `Moment` and `Memory` in container
`iCloud.Prabhchintan.Randhawa`) is created lazily in the Development
environment on first use. Deploy it to Production in the CloudKit Console
before shipping any release that writes a new field. 2.1 writes none, so the
schema is unchanged from 2.0 and this step does not gate it.

## App Store notes

- Ship this 2.1 alongside Randhawa 3.1. They are one feature split across two
  apps: Randhawa's trail gathers the places, and this is where they are read
  back. Shipping either alone leaves half of it unexplained.
- Privacy label: **Data Not Collected** (see above).
- Listing copy lives in `AppStore/metadata.md`; release notes in
  `AppStore/whatsnew-2.1.md`.

## Regenerating the app icon

The 24-dot icon is produced by `scripts/makeicon.swift`. Re-run with
`swift scripts/makeicon.swift`; it writes a 1024 by 1024 opaque PNG straight
into the asset catalog.
