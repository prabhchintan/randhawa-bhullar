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
  `{id, latitude, longitude, date}` with ISO 8601 dates. Append-mostly;
  moments never change once made.
- `memories.json`: envelope `{version, memories}`, each memory
  `{id, date, latitude?, longitude?, placeName?, text, photoFileName?}`.
- `MemoryPhotos/<memory-id>.jpg`: photo files, named by memory ID.

iCloud, only when the user turns sync on: container
`iCloud.Prabhchintan.Randhawa`, private database, zone `SpaceTime`.

- Record type `Moment` (`latitude` Double, `longitude` Double, `date`
  Date/Time), record name `moment-<uuid>`.
- Record type `Memory` (`date` Date/Time, `latitude` Double?, `longitude`
  Double?, `placeName` String?, `text` String, `photo` Asset), record name
  `memory-<uuid>`.

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
  (clustering, projection), and the file-level operations CloudSync uses.
  Widget-safe.
- `MemoryModel.swift`: Memory model, persistence, photo files, the
  "on this day" helper. Widget-safe.
- `MemoryStore.swift`: the observable store the app UIs bind to. App
  targets only.
- `CloudSync.swift`: CKSyncEngine wrapper for the private database. App
  targets only; widgets never sync.
- `MemoryViews.swift`: composer sheet, memory list, detail view, photo
  processing. App targets only.
