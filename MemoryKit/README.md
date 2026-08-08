# MemoryKit

The substrate both apps read. Randhawa shows this data in space, Bhullar
shows it in time, and everything here is shared, live, on the same device.
This directory is compiled into both app targets (and partly into the
Randhawa widget), not linked as a framework, so both apps always build from
the same commit.

## The contract

This is the part that must never fork. Both shipping apps, at whatever
versions users happen to have installed, read and write this exact shape.

On-device storage, in the App Group container `group.Prabhchintan.Randhawa`:

- `moments.json`: envelope `{version, moments}`, each moment
  `{id, latitude, longitude, date, source?}` with ISO 8601 dates. Moments
  never change once made. `source` is `"opened"` or `"trail"`, added in 3.1
  and absent everywhere else; a missing `source` reads as `"opened"`, which is
  what every pre-3.1 moment was. The envelope stays at version 1 on purpose:
  an old reader that ignores the field misses nothing it could act on.
- `memories.json`: envelope `{version, memories}`, each memory
  `{id, date, latitude?, longitude?, placeName?, text, photoFileName?}`.
- `MemoryPhotos/<memory-id>.jpg`: photo files, named by memory ID.

iCloud, only when the user turns sync on: container
`iCloud.Prabhchintan.Randhawa`, private database, zone `SpaceTime`.

- Record type `Moment` (`latitude` Double, `longitude` Double, `date`
  Date/Time), record name `moment-<uuid>`. `source` is deliberately not here.
  It is a local distinction, nothing downstream of sync needs it, and keeping
  it out means 3.1 ships without a CloudKit Production deploy standing between
  the build and the user. A moment fetched from iCloud therefore arrives with
  no source and reads as `"opened"`.
- Record type `Memory` (`date` Date/Time, `latitude` Double?, `longitude`
  Double?, `placeName` String?, `text` String, `photo` Asset), record name
  `memory-<uuid>`.

Shared settings, in the App Group defaults `group.Prabhchintan.Randhawa`:

- `cloudSyncEnabled` (Bool): whether the user turned iCloud sync on. Absent
  means never asked.
- `trailCadence` (String): one of `off`, `moves`, `quarterHour`, `hour`,
  `quarterDay`, `arrivals`. Absent or unrecognised means `off`, so a reader
  that does not know a future cadence fails closed rather than open. Only
  Randhawa acts on it; Bhullar reads it to word an empty state.

Compatibility rules:

1. Additive changes only. New fields must be optional or defaulted; never
   rename or repurpose an existing field.
2. Any change must remain readable by the previous shipped version of both
   apps, because users update the apps at different times.
3. Bump the envelope `version` only for changes that old readers must not
   misread, and keep a migration path when you do.
4. CloudKit schema changes must be deployed to Production in the CloudKit
   Console before any build that writes them reaches users.

## The files

- `MomentStore.swift`: Moment model, App Group persistence, geometry
  (clustering, projection), the trail cadence and its stored setting, and the
  file-level operations CloudSync uses. Widget-safe.
  - One caveat worth keeping in view: moments were append-only until 3.1, and
    "forget the trail" now deletes some. Deletions propagate through
    `momentDeleted`, but `uploadEverything` still re-sends whatever is on
    disk, so a device that was offline during a forget will restore its own
    copies the next time sync is switched on there. Erasing everything is
    still the only complete wipe.
- `MemoryModel.swift`: Memory model, persistence, photo files, the
  "on this day" helper. Widget-safe.
- `MemoryStore.swift`: the observable store the app UIs bind to. App
  targets only.
- `CloudSync.swift`: CKSyncEngine wrapper for the private database. App
  targets only; widgets never sync.
- `MemoryViews.swift`: composer sheet, memory list, detail view, photo
  processing. App targets only.
