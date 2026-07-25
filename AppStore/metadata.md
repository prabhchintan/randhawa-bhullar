# Randhawa, App Store listing (v3.0)

Copy/paste these into App Store Connect. Everything here is truthful about the
app: location on-device, iCloud sync optional and private, no data reaches us.
The v2 copy this replaces is in git history; v1 is archived at
Archive/metadata-v1.md.

---

## Name (max 30)
Randhawa

## Subtitle (max 30, this one is exactly 30)
Your places, one dot at a time

## Promotional text (max 170, editable any time without review; this is 160)
Open Randhawa and a dot marks where you are. Your places slowly draw a map only you can read. Now with memories you can pin to a place, and private iCloud sync.

## Keywords (max 100, comma-separated; this is 92)
map,dots,places,travel,journal,diary,memories,notes,private,icloud,widget,location,footprint

## Description (max 4000)
Randhawa draws the map of your life, one dot at a time.

Each time you open the app, it marks a dot where you are. That is all it takes. Slowly, the dots become something no one else could make: your places. Home glows densest. Familiar corners darken. Trips trail off the edge like sparks.

New in 3.0: memories. Tap the plus button and write down what this place deserves to remember, with a photo if you like. Memories live as gold dots on your map. And if you also use Bhullar, our time app, the same memories resurface there on the day they become anniversaries. Randhawa gives them a place; Bhullar gives them a time.

Two ways to see your map:
• Map: your dots on a real map, deepening where you return
• Constellation: just your dots on black, an abstract shape only you can read

Add the widget and your map lives on your Home Screen, moments in orange, memories in gold, growing every time a dot lands.

Yours, even on your next phone:
• Turn on iCloud sync and your moments and memories are kept in your private iCloud, which we cannot read
• Get a new phone, sign in, and your map comes back
• No account to create. No password. Your Apple Account is the account.

Private by architecture, not by promise:
• Location is read only while the app is open, never in the background
• Your data lives on your device and, only if you choose, in your own iCloud. We run no servers and can see none of it.
• No tracking. No analytics. No ads.
• Erase everything, everywhere, any time, with one tap

Randhawa cannot be rushed and cannot be faked. It simply gets better the longer you live with it. Open it wherever you go, and watch your map appear.

## What's New (paste from AppStore/whatsnew-3.0.md)

## App Review notes (Review Information → Notes)
Location is used for one purpose: when the user opens the app, one location
fix places a dot on their personal map. Location permission is When-In-Use
only and location is never read in the background.

New in 3.0: users can write short notes ("memories"), optionally with a photo
chosen through the out-of-process system Photos picker (no photo library
permission is requested). Users may optionally enable iCloud sync, which
stores their data in their own private CloudKit database; the developer has no
server and no access to any user's data. The privacy label remains "Data Not
Collected" per the App Privacy Details definition: data we cannot access is
not collected. The app also shares its data on-device, through an App Group
and the same private CloudKit container, with our companion app Bhullar
(same developer account).

---

## App information
- Primary category: Lifestyle · Secondary category: Travel (unchanged)
- Age rating: 4+ (unchanged) · Price: Free (unchanged)

## URLs (unchanged, already live)
- Support URL: https://prabhchintan.com/randhawa/support
- Privacy Policy URL: https://prabhchintan.com/randhawa/privacy
- Marketing URL: https://prabhchintan.com/randhawa
- NOTE: the hosted privacy page must mention optional iCloud sync before 3.0
  is submitted (memories, private CloudKit database, developer cannot read
  it). Update randhawa_privacy.html in the site repo and redeploy.

## App Privacy ("nutrition label") answers
- Data collection: **No, we do not collect data from this app.**
  Location is processed on device. Optional sync stores data in the user's
  private CloudKit database, which the developer cannot access; under Apple's
  own definition on the App Privacy Details page that is not collection.
  Re-verify that page's wording at submission time.

## Screenshots (regenerated for 3.0 with swift scripts/makescreenshots_v2.swift)
- AppStore/screenshots/*.png (1284x2778, 6.7 inch iPhone) and
  AppStore/screenshots/ipad/*.png (2048x2732, 13 inch iPad), 4 shots each
- Order: 01-app (constellation hero), 02-open (a dot per open),
  03-memories (gold memory dots + note card), 04-privacy (private by
  architecture, optional iCloud)

## Export compliance
- ITSAppUsesNonExemptEncryption = NO is set in build settings; no question at
  upload. (MapKit and CloudKit HTTPS are exempt Apple-OS encryption.)

---

## Pre-submit checklist (v3.0)
- [ ] CloudKit Console: record types Moment and Memory exist in Development;
      schema deployed to Production for iCloud.Prabhchintan.Randhawa
- [ ] Xcode: iCloud capability provisioned on the app target (first build)
- [ ] Build 3.0 (10) uploaded from Xcode and processed
- [ ] New version 3.0 created on the ASC distribution page
- [ ] Promo text, keywords, description, What's New updated
- [ ] Screenshots updated (iPhone + iPad)
- [ ] Privacy label confirmed: Data Not Collected
- [ ] Hosted privacy page updated for iCloud sync and memories
- [ ] Review notes pasted
- [ ] Age rating still 4+, price Free, availability unchanged
- [ ] Submit for review
