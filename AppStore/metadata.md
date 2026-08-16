# Randhawa, App Store listing (v3.2)

`scripts/asc.py release` reads the Promotional text, Keywords, Description and
App Review notes sections of this file and pushes them to App Store Connect;
What's New comes from `whatsnew-3.2.md`. Everything here is truthful about
the app: location on-device, iCloud sync optional and private, no data
reaches us. The v3.1 copy this replaces is in git history; v1 is archived at
Archive/metadata-v1.md.

---

## Name (max 30)
Randhawa

## Subtitle (max 30, this one is exactly 30)
Your places, one dot at a time

## Promotional text (max 170, editable any time without review; this is 163)
Carry your phone and Randhawa draws the map of your life: a dot where you go, a line where you moved, darker where you return. Private by architecture. Now in ink.

## Keywords (max 100, comma-separated; this is 96)
map,dots,places,travel,journal,diary,memories,notes,private,icloud,widget,location,trail,history

## Description (max 4000)
Randhawa draws the map of your life, one dot at a time.

Carry your phone and the map draws itself. Each time your phone notices you have gone somewhere, Randhawa marks a dot there and draws the line from the last one. Slowly, the ink becomes something no one else could make: your places. Home darkens into a blot. The roads you take every day darken too. Trips trail off the edge like sparks. Open the app and it marks a dot where you are, the way it always has.

New in 3.2: the ink. The map is redrawn as blots where you stayed and threads where you moved, all translucent, so repetition is what darkens. Today is drawn on top in orange, the live line over everything before it. Tap a blot and Randhawa tells you what the place is called, how often you were there and what you kept there. Slide the sparkles button and the map fades under the ink until only the constellation is left, on a real projection you can still zoom.

Memories: tap the plus button, or open a place, and write down what it deserves to remember, with a photo from your library or straight from the camera. Memories live as gold dots on your map. And if you also use Bhullar, our time app, the same memories resurface there on the day they become anniversaries. Randhawa gives them a place; Bhullar gives them a time.

Add the widget and your map lives on your Home Screen, drawn with the same ink, growing every time a dot lands.

Yours, even on your next phone:
• Turn on iCloud sync and your moments and memories are kept in your private iCloud, which we cannot read
• Get a new phone, sign in, and your map comes back
• Export your map as one file whenever you like; it is yours
• No account to create. No password. Your Apple Account is the account.

Private by architecture, not by promise:
• The map draws itself only after you say yes to iOS's own location prompt, and iOS asks again before background access becomes permanent
• It listens only for the low-power signals iOS gives a sleeping app when you have actually moved, so it never runs continuously and never keeps your phone awake
• Answer While Using only, and Randhawa falls back to a dot each time you open it
• Your data lives on your device and, only if you choose, in your own iCloud. We run no servers and can see none of it.
• No tracking. No analytics. No ads.
• Forget the trail, or erase everything everywhere, any time, with one tap

Randhawa cannot be rushed and cannot be faked. It simply gets better the longer you live with it. Carry it wherever you go, and watch your map appear.

## What's New (from AppStore/whatsnew-3.2.md)

## App Review notes (Review Information → Notes)
Location is used for exactly one purpose in this app: placing dots on a
personal map that only the user can see. There is no other use, no third
party, and no transmission to us.

WHAT CHANGED IN 3.2, AND WHY THE APP ASKS FOR "ALWAYS" AT THE INTRO

3.1 introduced an optional feature called the trail: with it on, the app adds
a dot to the user's own map while the app is closed, using only the two
low-power Core Location APIs that can wake a sleeping app. In 3.1 it was off
until the user found it in a menu. In 3.2 it is the default way the map is
made. The intro screen says so in plain words, and tapping Begin calls
requestAlwaysAuthorization once. iOS shows its ordinary prompt; if the user
allows, iOS grants provisional Always and later asks the user on its own
whether to keep allowing background access. If the user answers While Using
only, at either point, the app falls back to placing a dot each time it is
opened, exactly as 3.0 did.

How to review it: the intro explains it, the iOS prompt asks, and the "..."
menu top left has "Trail: on/off", one screen that lists the cadences,
explains in its own footer that a cadence is a ceiling rather than a schedule,
offers "Forget the trail", and links to Settings if Always is not granted.

Constraints we hold ourselves to, all verifiable in the binary and in the
source (the app is open source at github.com/prabhchintan/randhawa-bhullar):

1. It asks before it listens: our words on the intro, then iOS's prompt, then
   iOS's second prompt. Nothing is monitored until the user has said yes, and
   one screen (or Location in Settings) turns it off immediately.
2. No continuous location and NO UIBackgroundModes entry. The app uses only
   startMonitoringSignificantLocationChanges and startMonitoringVisits. It
   never asks the system to keep it running and never shows the blue status
   bar.
3. The chosen cadence is enforced as a minimum gap between saved dots. Nothing
   polls and nothing runs on a timer. A stationary user generates no dots.
4. "Forget the trail" deletes every dot the trail placed, on the device and in
   the user's iCloud, while keeping the dots the user placed by opening the
   app.
5. Location data is written to a file in the app's App Group container and, if
   and only if the user has turned on iCloud sync, mirrored to the user's own
   private CloudKit database. We run no servers and Apple gives developers no
   access to a private database, so we cannot read any of it. "Export your
   map" in the menu writes the same data to a single JSON file the user can
   share; it goes only where the user sends it.

The privacy label stays "Data Not Collected" for the same reason it did in
3.0 and 3.1: under the App Privacy Details definition, collection means
transmitting data off device in a way the developer can access. Nothing here
is.

The hosted privacy policy at https://prabhchintan.com/randhawa/privacy has
been updated for this release and describes the default-on trail, the two iOS
prompts, and how to switch it off.

ALSO IN 3.2

The map is drawn as translucent ink (blots and lines) over a muted Apple Maps
basemap; there is a slider between the map and a plain black background.
Tapping a blot opens a sheet naming the place with CLGeocoder, the same Apple
lookup used since 3.0 to name a memory's place. Users can write short notes
("memories"), optionally with a photo chosen through the out-of-process
system Photos picker or taken with the camera (NSCameraUsageDescription is
present; the camera is used only when the user taps "Take a photo", and the
photo is stored with the memory, not written to the photo library). The app
shares its data on-device, through an App Group and the same private
CloudKit container, with our companion app Bhullar (same developer), which is
submitting version 2.2 alongside this one.

---

## App information
- Primary category: Lifestyle · Secondary category: Travel (unchanged)
- Age rating: 4+ (unchanged) · Price: Free (unchanged)

## URLs (unchanged, already live)
- Support URL: https://prabhchintan.com/randhawa/support
- Privacy Policy URL: https://prabhchintan.com/randhawa/privacy
- Marketing URL: https://prabhchintan.com/randhawa
- The hosted privacy and support pages were updated and deployed for 3.2
  (the trail as the default, the two iOS prompts, the export). Both live in
  the prabhchintan.com repo, never in this one.

## App Privacy ("nutrition label") answers
- Data collection: **No, we do not collect data from this app.**
  Location is processed on device. Optional sync stores data in the user's
  private CloudKit database, which the developer cannot access; under Apple's
  own definition on the App Privacy Details page that is not collection.
  Re-verify that page's wording at submission time.

## Screenshots (regenerated for 3.2 with swift scripts/makescreenshots_v2.swift)
- AppStore/screenshots/*.png (1284x2778, 6.7 inch iPhone) and
  AppStore/screenshots/ipad/*.png (2048x2732, 13 inch iPad), 5 shots each
- Order: 01-app (constellation hero), 02-open (a dot per open, still true),
  03-trail (the map draws itself: a walked path plus the cadence card),
  04-memories (gold memory dots + note card), 05-privacy (private by
  architecture, optional iCloud)
- 03-trail lost "Off until you do" in 3.2, which is no longer how it starts.
  Do not restore it.

## Export compliance
- ITSAppUsesNonExemptEncryption = NO is set in build settings; no question at
  upload. (MapKit and CloudKit HTTPS are exempt Apple-OS encryption.)

---

## Pre-submit checklist (v3.2)
- [x] CloudKit: no schema change in 3.2, so no Production deploy gates this
- [x] Hosted privacy and support pages updated and deployed for the default
      trail, the two prompts, the camera and the export
- [x] Screenshots regenerated (5 iPhone + 5 iPad)
- [ ] Build 3.2 (14) archived and uploaded to App Store Connect
- [ ] `scripts/asc.py release ... --submit` run for Randhawa, then Bhullar,
      in the same sitting
