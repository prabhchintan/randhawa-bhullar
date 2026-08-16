# Releasing

The end to end process for shipping both apps. Last run in full on
2026-08-16 (Randhawa 3.2 build 13, Bhullar 2.2 build 7), entirely from the
command line: no browser and no Xcode GUI once the machine is set up. This is
also what the Sunday loop runs unattended; see [LOOP.md](LOOP.md).

## Prerequisites, once per machine

- Xcode installed. `xcode-select -p` must point at
  `/Applications/Xcode.app/Contents/Developer`, not CommandLineTools. Fixed on
  this machine 2026-08-08; on a fresh one run
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. Check with
  `swift --version`: anything reporting 5.x means the wrong toolchain is active
  and builds will reject modern syntax.
- An App Store Connect API key (Team key, Admin) described by
  `~/.config/appstoreconnect/config.json` (`key_id`, `issuer_id`, `key_path`,
  `team_id`), plus `contact.json` beside it with the App Review contact
  fields. `scripts/asc.py` reads both. Distribution signing is cloud managed;
  `-allowProvisioningUpdates` with the key handles profiles and capabilities.
- `pip3 install "PyJWT[crypto]"`, the one dependency of `scripts/asc.py`.
- `gh` authenticated, for tags and the repo.
- A CloudKit Console session, only for the rare release that changes the
  schema (step 4).

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

Set the key once per shell:

```
KEY=(-authenticationKeyPath "$HOME/.config/appstoreconnect/AuthKey_35DM9PC8S8.p8" \
     -authenticationKeyID 35DM9PC8S8 \
     -authenticationKeyIssuerID f0637e77-d15f-4807-a0e3-0c35531b3b7d)
xcodebuild -project Randhawa.xcodeproj -scheme Randhawa \
  -destination 'generic/platform=iOS' \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Randhawa X.Y (N).xcarchive" \
  -allowProvisioningUpdates "${KEY[@]}" archive
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
  -exportOptionsPlist exportOptions.plist -allowProvisioningUpdates "${KEY[@]}"
```

Success prints `Upload succeeded`. Apple-side processing takes five to
thirty minutes before the build appears in App Store Connect;
`scripts/asc.py release` waits for it.

## 6. App Store Connect, from the terminal

All copy lives in `AppStore/metadata.md` and `AppStore/whatsnew-<version>.md`
(and the same under `Bhullar/`). `scripts/asc.py` reads the Promotional
text, Keywords, Description and App Review notes sections straight out of
metadata.md, so the file is the listing:

```
python3 scripts/asc.py release --app Prabhchintan.Randhawa \
  --version X.Y --build N \
  --metadata AppStore/metadata.md --whatsnew AppStore/whatsnew-X.Y.md \
  --screenshots AppStore/screenshots --submit
python3 scripts/asc.py release --app Prabhchintan.Bhullar \
  --version X.Y --build N \
  --metadata Bhullar/AppStore/metadata.md --whatsnew Bhullar/AppStore/whatsnew-X.Y.md \
  --screenshots Bhullar/AppStore/screenshots --submit
```

That creates the version if needed, sets the copy, replaces both screenshot
sets (omit `--screenshots` to keep the current ones), writes the review notes,
waits for the build to finish processing, attaches it, and submits for review
with automatic release. Without `--submit` it stops one step short.
`asc.py status --app ...` reads back the version and submission states. When
a release spans both apps, submit them together, since each release's copy
references the other. App Privacy is app-level and stays Data Not Collected;
it is not touched by the script and should not need to be.

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

## 10. Every Sunday

The loop in [LOOP.md](LOOP.md) runs steps 1 to 8 unattended for whatever it
decided to ship that week, and writes a report. Read the report.

## Non-negotiables

- The privacy label stays Data Not Collected, or the architecture and the
  copy change together, honestly.
- No em dashes anywhere: code, comments, docs, store copy.
- The story stays quiet. See The rule in [VISION.md](VISION.md).
