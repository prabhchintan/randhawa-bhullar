# Releasing

The end to end process for shipping both apps. Last run in full on
2026-07-25 (Randhawa 3.0 build 10, Bhullar 2.0 build 4), entirely from the
command line and a signed-in browser. The Xcode GUI is not part of the
process once the machine is set up.

## Prerequisites, once per machine

- Xcode installed, and signed into the Apple Account in Xcode Settings.
  Distribution signing is cloud managed by that session; no local
  distribution certificate is needed, and `-allowProvisioningUpdates`
  handles profiles and new capabilities from the command line.
- If `xcode-select -p` points at CommandLineTools, prefix every xcodebuild
  call with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- Browser sessions signed into App Store Connect and the CloudKit Console.
- `gh` authenticated, for tags and the repo.

## 1. Bump versions

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the project file of
each app being shipped. Each value appears once per configuration per
target, four places per project. Keep the version lines in the READMEs
honest.

## 2. Verify the builds

```
xcodebuild -project Randhawa.xcodeproj -scheme Randhawa \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Bhullar/Bhullar.xcodeproj -scheme Bhullar \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 3. Screenshots, when anything visible changed

Run from the repo root:

```
swift scripts/makescreenshots_v2.swift
swift Bhullar/scripts/makescreenshots.swift
```

Inspect the output. The store sets live in `AppStore/screenshots` and
`Bhullar/AppStore/screenshots`, iPhone 1284x2778 plus `ipad/` 2048x2732.
Update the shot lists in the metadata files if shots were added or
renamed.

## 4. CloudKit, only when the schema changed

The compatibility rules in [MemoryKit/README.md](MemoryKit/README.md)
govern. Any new or changed record type must exist in the Development
environment and be deployed to Production in the CloudKit Console
(container `iCloud.Prabhchintan.Randhawa`) before a build that writes it
reaches users. A store build pointed at an undeployed schema cannot sync
and fails quietly.

## 5. Archive and upload

```
xcodebuild -project Randhawa.xcodeproj -scheme Randhawa \
  -destination 'generic/platform=iOS' \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Randhawa X.Y (N).xcarchive" \
  -allowProvisioningUpdates archive
```

Same shape for Bhullar. Then export straight to App Store Connect with
this `exportOptions.plist`:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>7FWNAT83XU</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
```

```
xcodebuild -exportArchive -archivePath <the archive> \
  -exportOptionsPlist exportOptions.plist -allowProvisioningUpdates
```

Success prints `Upload succeeded`. Apple-side processing takes five to
thirty minutes before the build appears in App Store Connect.

## 6. App Store Connect

All copy is prewritten in `AppStore/metadata.md` and
`AppStore/whatsnew-<version>.md` (and the same under `Bhullar/`); the
character counts in those files are verified, so paste without editing.
Create the new version, fill promotional text, description, keywords, and
What's New, replace both screenshot sets, refresh the App Review notes,
attach the processed build, and submit. When a release spans both apps,
submit them together, since each release's copy references the other.

## 7. Tag and record

```
git tag -a randhawa-X.Y-bN -m "Randhawa X.Y (N) as submitted"
git tag -a bhullar-X.Y-bN -m "Bhullar X.Y (N) as submitted"
git push --tags
```

Move the shipped items out of the In review lanes in `ROADMAP.md`.

## 8. The site

If the data story changed at all, `randhawa_privacy.html` and
`randhawa_support.html` in the prabhchintan.com repo must be updated and
deployed no later than submission; the listings link to those pages and
review may read them.

## 9. After approval

Install the updates from the App Store, never from Xcode, so the update
arrives the way users see it, release notes included. If MemoryKit
changed, verify sync between two signed-in devices before celebrating.

## Non-negotiables

- The privacy label stays Data Not Collected, or the architecture and the
  copy change together, honestly.
- No em dashes anywhere: code, comments, docs, store copy.
- The story stays quiet. See The rule in [VISION.md](VISION.md).
