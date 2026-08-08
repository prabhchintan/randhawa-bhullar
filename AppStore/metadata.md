# Randhawa, App Store listing (v3.1)

Copy/paste these into App Store Connect. Everything here is truthful about the
app: location on-device, iCloud sync optional and private, no data reaches us.
The v2 copy this replaces is in git history; v1 is archived at
Archive/metadata-v1.md.

---

## Name (max 30)
Randhawa

## Subtitle (max 30, this one is exactly 30)
Your places, one dot at a time

## Promotional text (max 170, editable any time without review; this is 164)
Open Randhawa and a dot marks where you are. Now the map can also draw itself: turn on the trail, pick a pace, and your places fill in as you go. Off until you ask.

## Keywords (max 100, comma-separated; this is 96)
map,dots,places,travel,journal,diary,memories,notes,private,icloud,widget,location,trail,history

## Description (max 4000)
Randhawa draws the map of your life, one dot at a time.

Each time you open the app, it marks a dot where you are. That is all it takes. Slowly, the dots become something no one else could make: your places. Home glows densest. Familiar corners darken. Trips trail off the edge like sparks.

New in 3.1: the trail. If waiting for you to open the app leaves too many gaps, turn the trail on and Randhawa keeps marking dots as you go, at a pace you choose: whenever you move, hourly, every four hours, or only when you arrive somewhere and stay. It is off until you turn it on, and one tap forgets everything it gathered.

Memories, from 3.0: tap the plus button and write down what this place deserves to remember, with a photo if you like. Memories live as gold dots on your map. And if you also use Bhullar, our time app, the same memories resurface there on the day they become anniversaries. Randhawa gives them a place; Bhullar gives them a time.

Two ways to see your map:
• Map: your dots on a real map, deepening where you return
• Constellation: just your dots on black, an abstract shape only you can read

Add the widget and your map lives on your Home Screen, moments in orange, memories in gold, growing every time a dot lands.

Yours, even on your next phone:
• Turn on iCloud sync and your moments and memories are kept in your private iCloud, which we cannot read
• Get a new phone, sign in, and your map comes back
• No account to create. No password. Your Apple Account is the account.

Private by architecture, not by promise:
• With the trail off, which is how the app starts, location is read only while Randhawa is open and at no other time
• Turn the trail on and it uses only the low-power signals iOS gives a sleeping app, so it never runs continuously and never holds your phone awake
• Your data lives on your device and, only if you choose, in your own iCloud. We run no servers and can see none of it.
• No tracking. No analytics. No ads.
• Forget the trail, or erase everything everywhere, any time, with one tap

Randhawa cannot be rushed and cannot be faked. It simply gets better the longer you live with it. Open it wherever you go, and watch your map appear.

## What's New (paste from AppStore/whatsnew-3.1.md)

## App Review notes (Review Information → Notes)
Location is used for exactly one purpose in this app: placing dots on a
personal map that only the user can see. There is no other use, no third
party, and no transmission to us.

WHAT IS NEW IN 3.1, AND WHY THE APP NOW ASKS FOR "ALWAYS"

3.1 adds an optional feature called the trail. With it on, the app adds a dot
to the user's own map while the app is closed, so the map reflects where they
actually went rather than only the moments they happened to open the app. This
is the entire user-facing benefit and it is visible immediately: the dots
appear on the map inside the app.

How to review it: open the app, tap the "..." button in the top left, choose
"Trail: off". That single screen is the whole feature. It lists the cadences,
explains in its own footer that a cadence is a ceiling rather than a schedule,
offers "Forget the trail", and is the only place Always is ever requested.

Constraints we hold ourselves to, all verifiable in the binary and in the
source (the app is open source at github.com/prabhchintan/randhawa-bhullar):

1. Off by default, on every install and every update. The app never asks for
   Always until the user picks a cadence in that screen. A fresh install
   behaves exactly like 3.0.
2. No continuous location and NO UIBackgroundModes entry. The app uses only
   startMonitoringSignificantLocationChanges and startMonitoringVisits, the
   two low-power APIs that relaunch a terminated app on their own. It never
   asks the system to keep it running and never shows the blue status bar.
3. The chosen cadence is enforced as a minimum gap between saved dots. Nothing
   polls and nothing runs on a timer. A stationary user generates no dots.
4. "Forget the trail" deletes every dot the trail placed, on the device and in
   the user's iCloud, while keeping the dots the user placed by opening the
   app.
5. Location data is written to a file in the app's App Group container and, if
   and only if the user has turned on iCloud sync, mirrored to the user's own
   private CloudKit database. We run no servers and Apple gives developers no
   access to a private database, so we cannot read any of it.

The privacy label stays "Data Not Collected" for the same reason it did in
3.0: under the App Privacy Details definition, collection means transmitting
data off device in a way the developer can access. Nothing here is. The trail
increases how much the user records about themselves, on their own device, and
changes nothing about who can see it.

The hosted privacy policy at https://prabhchintan.com/randhawa/privacy has
been updated for this release and describes the trail in full, including that
it is opt-in and how to switch it off.

ALSO IN 3.1 (unchanged from 3.0 in substance)

Users can write short notes ("memories"), optionally with a photo chosen
through the out-of-process system Photos picker (no photo library permission
is requested). The app shares its data on-device, through an App Group and the
same private CloudKit container, with our companion app Bhullar (same
developer account), which is submitting version 2.1 alongside this one.

---

## App information
- Primary category: Lifestyle · Secondary category: Travel (unchanged)
- Age rating: 4+ (unchanged) · Price: Free (unchanged)

## URLs (unchanged, already live)
- Support URL: https://prabhchintan.com/randhawa/support
- Privacy Policy URL: https://prabhchintan.com/randhawa/privacy
- Marketing URL: https://prabhchintan.com/randhawa
- The hosted privacy and support pages were updated and deployed for 3.1
  (the trail: opt-in, how to switch it off, what "Forget the trail" does).
  Both live in the prabhchintan.com repo, never in this one.

## App Privacy ("nutrition label") answers
- Data collection: **No, we do not collect data from this app.**
  Location is processed on device. Optional sync stores data in the user's
  private CloudKit database, which the developer cannot access; under Apple's
  own definition on the App Privacy Details page that is not collection.
  Re-verify that page's wording at submission time.

## Screenshots (regenerated for 3.1 with swift scripts/makescreenshots_v2.swift)
- AppStore/screenshots/*.png (1284x2778, 6.7 inch iPhone) and
  AppStore/screenshots/ipad/*.png (2048x2732, 13 inch iPad), 5 shots each
- Order: 01-app (constellation hero), 02-open (a dot per open),
  03-trail (the 3.1 headline: a walked path plus the cadence card),
  04-memories (gold memory dots + note card), 05-privacy (private by
  architecture, optional iCloud)
- 02-open lost its old "never in the background" subtitle, which 3.1 makes
  untrue. Do not restore it.

## Export compliance
- ITSAppUsesNonExemptEncryption = NO is set in build settings; no question at
  upload. (MapKit and CloudKit HTTPS are exempt Apple-OS encryption.)

---

## Pre-submit checklist (v3.1)
- [x] CloudKit: no schema change in 3.1 (a moment's `source` is local only),
      so no Production deploy gates this release
- [x] Hosted privacy and support pages updated and deployed for the trail
- [x] Screenshots regenerated (5 iPhone + 5 iPad), old 03/04 names deleted
- [x] Build 3.1 (12) archived and uploaded to App Store Connect
- [ ] New version 3.1 created on the ASC distribution page
- [ ] Promo text, keywords, description, What's New updated
- [ ] Screenshots replaced (iPhone + iPad); note there are 5 now, not 4
- [ ] Privacy label re-confirmed: Data Not Collected. If Apple's App Privacy
      Details wording has changed, re-read it before answering; the trail is
      the first feature where the answer is worth re-deriving rather than
      repeating.
- [ ] Review notes pasted IN FULL. The Always justification is the part that
      decides this review.
- [ ] Age rating still 4+, price Free, availability unchanged
- [ ] Submit for review together with Bhullar 2.1
