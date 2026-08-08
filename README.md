# Randhawa & Bhullar

Two deliberately minimal iOS apps that share one idea: your life leaves a
shape, in space and in time, and both are worth keeping.

- **Randhawa** (this directory) maps your places: one dot each time you open
  it. [App Store](https://apps.apple.com/app/id6742061604)
- **Bhullar** ([`Bhullar/`](Bhullar/README.md)) telescopes your time: one
  grid of dots, from the months of the year to the minutes of today.
  [App Store](https://apps.apple.com/app/id6787122959)
- **MemoryKit** ([`MemoryKit/`](MemoryKit/)) is the shared layer: memories
  (a thought, a photo, a place, a time) made in either app and shown in
  both, synced only through the user's own private iCloud.

This is the complete source for both shipping apps, MIT licensed. The apps'
whole promise is privacy by architecture: no accounts, no analytics, no
servers of ours, and data we cannot read. Open code is the strongest form of
that promise. Don't take our word for it; read it. The plan lives in
[`ROADMAP.md`](ROADMAP.md).

## Randhawa (v3.1, space)

A deliberately minimal iOS app: each time you open it, it marks a dot where you
are. Over weeks and years, your places draw a map only you can read: dense
where your life happens, sparse where you've wandered.

New in 3.1, and off until you go and switch it on: **the trail**. Pick a
cadence and the map keeps drawing itself while the app is closed. It listens
only to the two low-power signals iOS offers a sleeping app, significant
location changes and visits, so the cadence you pick is a ceiling rather than a
schedule and standing still costs nothing. One tap forgets everything it
gathered. The argument for reversing a promise this file used to make is in
[`ROADMAP.md`](ROADMAP.md), under "The one we reversed".

Since 3.0 the dots can carry more than presence. Tap the plus button and pin a
memory to where you are: a thought, a photo, or both. Memories show as gold
dots on the map, and they flow into Bhullar (the sibling time app in
`Bhullar/`), where they resurface on the day they were made. Randhawa gives a
memory its place; Bhullar gives it its time.

Two ways to look at the same map:
- **Map mode**: your dots over a real (Apple Maps) basemap; repeat visits
  darken into blots, memories sit on top in gold.
- **Constellation mode**: no basemap at all, just the abstract shape of your
  places on black.

One widget: **Map**, an Apple Maps snapshot of your moments and memories that
updates whenever a dot lands. (The old Constellation widget was retired in
3.0; the constellation lives on inside the app.)

## Privacy, and the one honest change in 3.0

Through 2.x the promise was "nothing ever leaves your phone." That promise had
a cost: lose the phone, lose the map. 3.0 keeps the spirit and fixes the cost:

- By default, everything still lives only on the device.
- **iCloud sync is optional and off until the user turns it on.** When on,
  moments and memories are mirrored into the user's **private CloudKit
  database** in the container `iCloud.Prabhchintan.Randhawa`. That database
  belongs to the user's Apple Account: we cannot read it, we run no servers,
  and storage counts against the user's own iCloud space (these records are
  tiny). Sign into iCloud on a new phone and the map comes back.
- There is still no account system, no password, and no analytics. The user's
  Apple Account is the account; CloudKit ties records to it automatically.
- The App Store privacy label stays **"Data Not Collected"**: Apple's
  definition of collection is transmitting data off-device in a way the
  developer can access, and a private CloudKit database is not accessible to
  the developer. Re-verify that reading of the App Privacy Details page at
  submission time.

Location, as of 3.1, has two modes and the quiet one is the default. With the
trail off, which is how every install and every update starts, location is read
once per app open, When-In-Use, and never otherwise. Turn the trail on and the
app also asks for Always, then takes a fix when iOS wakes it for a significant
location change or a visit, no more often than the chosen cadence. There is no
location background mode and no continuous updates, so the app never holds the
system awake and never lights the status bar. Where the dots go does not change
at all: the same file, the same optional private CloudKit database, no servers
of ours. Reverse geocoding (naming a place, in either app) and map tiles go
through Apple's frameworks under Apple's privacy policy.

## What's inside

```
Randhawa.xcodeproj         Two targets: the app and its widget extension
MemoryKit/                 Shared by BOTH apps (this project and Bhullar):
  MomentStore.swift        Moment model, App Group persistence, geometry
                           (clustering + constellation projection), MomentSync
                           file ops used when iCloud records arrive
  MemoryModel.swift        Memory model + App Group persistence + photo files
  MemoryStore.swift        Observable store the app UIs bind to (app targets)
  CloudSync.swift          CKSyncEngine wrapper: private database, zone
                           "SpaceTime", record types Moment and Memory
  MemoryViews.swift        Composer sheet, memory list, detail view (shared UI)
Shared/
  ConstellationView.swift  One Canvas that draws the constellation
Randhawa/
  RandhawaApp.swift        App entry point
  ContentView.swift        Map/constellation screens, memory capture, sync
                           offer, erase, captions
  SpaceModel.swift         CoreLocation one-shot sampling + moment list
  Randhawa.entitlements    App Group + iCloud (CloudKit)
  Assets.xcassets          App icon (1024 square, no alpha) + accent color
RandhawaWidget/
  RandhawaWidget.swift     The Map widget (systemSmall/Medium/Large)
  RandhawaWidgetBundle.swift
  RandhawaWidget.entitlements   App Group only; the widget never syncs
  Info.plist               WidgetKit extension point
Archive/randhawa-time-v1/  The v1.0 year-grid sources (now living on in Bhullar)
```

Both apps and the widget share the moment and memory files through the App
Group `group.Prabhchintan.Randhawa`. The app reloads widget timelines whenever
data changes. Sampling rules: When-In-Use authorization only, one location fix
per foreground activation, activations within 60 seconds ignored.

Sync design in one paragraph: the JSON files in the App Group stay the source
of truth, and `CloudSync` (one instance per app process, only when the user
has sync on) mirrors them record by record with `CKSyncEngine`. Each app
fetches on foreground and lets the engine push queued changes on its own
schedule. Erase-all deletes the whole CloudKit zone, so wiping the map wipes
it everywhere. Conflicts are resolved by taking the server record as the new
base and reapplying local fields, which for this append-mostly data converges
immediately.

## Build & run

1. Open `Randhawa.xcodeproj` in **Xcode 16 or later**.
2. First build after 3.0: automatic signing must provision two capabilities
   for the app target, the **App Group** (`group.Prabhchintan.Randhawa`) and
   **iCloud (CloudKit)** with container `iCloud.Prabhchintan.Randhawa`. If
   signing complains, open each target's *Signing & Capabilities* tab once and
   let it refresh. The widget target needs only the App Group.
3. Select the **Randhawa** scheme and a device, then Run (Cmd-R). Grant
   location when asked; your first dot appears immediately.

Deployment target is **iOS 17.0** (CKSyncEngine needs 17). Version is **3.1
(build 11)** on both targets; this ships as an update to the existing App
Store record (Apple App ID 6742061604).

## CloudKit: one manual step before release

CloudKit schemas are created lazily in the **Development** environment the
first time the app saves records. Before shipping a release that writes a new
field, open the CloudKit Console for `iCloud.Prabhchintan.Randhawa`, confirm
the record types `Moment` and `Memory` exist with the fields the code writes,
and **deploy the schema to Production**. A store build pointed at an empty
Production schema cannot sync.

**3.1 does not need this step.** The one new field, a moment's `source`, is
local to the device file by design and is never written to CloudKit. The
schema is unchanged from 3.0.

## App Store notes

- Privacy label: **Data Not Collected** (see the privacy section above). The
  trail does not change this: it writes to the same on-device file and the
  same private CloudKit database, and neither is readable by us.
- Two location purpose strings are set in build settings,
  `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` for the per-open dot and
  `INFOPLIST_KEY_NSLocationAlwaysAndWhenInUseUsageDescription` for the trail.
  There is deliberately **no** `UIBackgroundModes` entry: significant-change
  and visit monitoring relaunch a terminated app without it, and adding it
  would invite a rejection for capability the app does not use.
- Photos are attached through the system Photos picker, which runs out of
  process and needs no permission string and no privacy declaration.
- Full listing copy lives in `AppStore/metadata.md`; release notes in
  `AppStore/whatsnew-3.1.md`.

## App icon

The icon is the brand mark (`apple-touch-icon.png` at the repo root, upscaled
to 1024 by 1024, opaque). An alternative constellation icon lives at
`Archive/constellation-icon.png` and can be regenerated with
`swift scripts/makeicon.swift`, which writes straight into the asset catalog.
Only run it if you want to switch back.
