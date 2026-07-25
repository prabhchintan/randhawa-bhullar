# Bhullar (v2.0, time)

A deliberately minimal iOS app: a telescope for time. One grid of dots, five
zoom levels; tap the grid to cycle:

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

## Data and privacy

The grid itself still needs nothing: every dot is computed from the current
date. Memories are the only stored data, and they live in the App Group
container (`group.Prabhchintan.Randhawa`) both apps share. **iCloud sync is
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
  DotGrid.swift            One Canvas that draws the dots (now with gold
                           highlights for units holding memories)
Bhullar/
  BhullarApp.swift         App entry point
  ContentView.swift        Full-screen grid, tap to zoom, memories, captions
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
2. First build after 2.0: automatic signing must provision the **App Group**
   and **iCloud (CloudKit)** capabilities on the app target. If it complains,
   open *Signing & Capabilities* once and let it refresh. The widget target
   needs only the App Group.
3. Select the **Bhullar** scheme and a simulator or device, then Run (Cmd-R).
4. Widgets: long-press the Home or Lock Screen, tap plus, search "Bhullar";
   there are three, so several scales can sit on the Home Screen at once.

Deployment target is **iOS 17.0**. Bundle IDs `Prabhchintan.Bhullar` /
`Prabhchintan.Bhullar.BhullarWidget`, team preset, version **2.0 (build 4)**.

## CloudKit: one manual step before release

The CloudKit schema (record types `Moment` and `Memory` in container
`iCloud.Prabhchintan.Randhawa`) is created lazily in the Development
environment on first use. Deploy it to Production in the CloudKit Console
before shipping either app's update. If Randhawa 3.0 ships first and already
deployed the schema, this is done.

## App Store notes

- Ship this 2.0 alongside (or right after) Randhawa 3.0, since the two
  advertise each other's memories feature.
- Privacy label: **Data Not Collected** (see above).
- Listing copy lives in `AppStore/metadata.md`; release notes in
  `AppStore/whatsnew-2.0.md`.

## Regenerating the app icon

The 24-dot icon is produced by `scripts/makeicon.swift`. Re-run with
`swift scripts/makeicon.swift`; it writes a 1024 by 1024 opaque PNG straight
into the asset catalog.
