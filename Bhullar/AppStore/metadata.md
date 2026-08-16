# Bhullar, App Store listing (v2.2)

`scripts/asc.py release` reads the Promotional text, Keywords, Description and
App Review notes sections of this file; What's New comes from `whatsnew-2.2.md`.

---

## App record (unchanged)
- Name: **Bhullar** · Bundle ID: **Prabhchintan.Bhullar** · SKU: Prabhchintan.Bhullar
- Price: Free · Availability: all countries · Age rating: 4+ (all "None")

## Subtitle (max 30, this is 23)
Time, one dot at a time

## Promotional text (max 170, editable any time without review; this is 164)
The year in months, weeks, or days. Today in hours or minutes. One grid of dots; swipe to zoom, tap a dot to see where you were. Widgets glow gold on days you kept.

## Keywords (max 100, comma-separated; this is 96)
year,progress,dots,widget,countdown,days,weeks,months,hours,calendar,time,minimal,memories,diary

## Description (max 4000)
Bhullar is a telescope for time. One grid of dots, five zoom levels. Swipe the grid and the year becomes months, then weeks, then days; swipe again and you are looking at today, hour by hour, then minute by minute.

The unit you are in glows. The units that have passed fill in. The rest wait quietly. That is the whole app, and that is the point.

Dots you can open. Swiping is the zoom, which frees the tap to mean "this one". Tap any dot that has already happened and Bhullar tells you what that stretch of time held: where you were during it, and what you kept from it. The places come from Randhawa, our map app, whose map now draws itself; carry your phone and they fill in on their own. A dot still ahead of now says only "Not yet."

New in 2.2: the widgets glow gold on the days and hours that hold a memory, the same way the grid in the app does. The composer can take a photo with the camera, not only pick one. And places are named through one shared cache, so a place is the same word in Bhullar and in Randhawa.

Memories. Tap the plus button and write down what right now deserves to keep, with a photo if you like, from your library or the camera. Days that hold a memory glow gold in the grid, and when a memory's date comes around again it resurfaces under the grid: on this day. If you also use Randhawa, our map app, memories flow between the two: made in either, shown in both. Randhawa gives them a place; Bhullar gives them a time.

• 12 months, 52-odd weeks, 365-odd days, 24-odd hours, 1,440-odd minutes
• Swipe sideways to change scale; the app remembers where you left it
• Tap any elapsed dot to open it: the places and the memories from that span
• Three Home Screen widgets: Year in Dots, Day in Dots, and Dots at Any Scale, which you can set to months, weeks, days, or hours; gold where you kept a memory
• Lock Screen widgets in every size
• Updates itself: live while open, hourly for the day, at midnight for the year

Honest timekeeping:
• Leap years get 366 dots automatically
• On clock-change days, the day truthfully shows 23 or 25 hours, and 1,380 or 1,500 minutes
• Weeks follow your calendar settings

Deliberately minimal:
• No account to create. No sign-up. iCloud sync is optional and uses your own private iCloud, which we cannot read.
• No tracking. No analytics. No ads.
• The grid needs nothing: every dot is computed on your device from the date

Glance, take it in, get on with your day.

## What's New (from AppStore/whatsnew-2.2.md)

## App Review notes (Review Information → Notes)
Bhullar is the time-keeping sibling of our app Randhawa (Apple App ID
6742061604). The two share a design language and a memories feature: short
user-written notes, optionally with a photo chosen through the out-of-process
system Photos picker (no photo library permission is requested) or, new in
2.2, taken with the camera (NSCameraUsageDescription is present; the camera
is used only when the user taps "Take a photo", and the photo is stored with
the memory, not written to the photo library). Memories are stored on device
in an App Group shared by the two apps and, only if the user turns on iCloud sync, in the user's own
private CloudKit database. The developer runs no servers and cannot access
any user's data, so the privacy label remains "Data Not Collected". The time
grid itself stores nothing and is computed from the current date.

Tapping a dot opens that span of time and shows the places the user was
during it. Bhullar does not request location permission and records no
location of its own. It reads the moments Randhawa (Apple App ID 6742061604,
same developer) has already written to the App Group container the two apps
share, and turns their coordinates into place names with CLGeocoder, the same
Apple lookup both apps have always used to name a memory's place. Randhawa
3.2, submitted alongside this, is where those moments are gathered and where
all location permission lives.

NEW IN 2.2: the widgets read the shared memories file to colour the days and
hours that hold a memory, exactly as the app's grid already did. Nothing new
is stored and nothing leaves the device.

---

## URLs (shared with Randhawa, the company site covers both apps)
- Support URL: https://prabhchintan.com/randhawa/support
- Privacy Policy URL: https://prabhchintan.com/randhawa/privacy
- Marketing URL (optional): https://prabhchintan.com/randhawa

## App information
- Primary category: Productivity · Secondary: Utilities (unchanged)
- App Privacy: **Data Not Collected** (see review notes; re-verify Apple's
  App Privacy Details wording at submission)
- Export compliance: ITSAppUsesNonExemptEncryption = NO already in build
  settings (CloudKit HTTPS is exempt Apple-OS encryption)

## Screenshots (regenerated for 2.2 with swift Bhullar/scripts/makescreenshots.swift)
- Bhullar/AppStore/screenshots/*.png (1284x2778 iPhone) and ipad/ (2048x2732),
  6 shots each
- Order: 01-app (telescope hero), 02-scales (2x2 zoom levels), 03-open (the
  2.1 headline: a ringed dot and the sheet it opens), 04-widgets (three
  widgets), 05-memories (gold days + on-this-day pill), 06-privacy (no
  accounts, honest timekeeping)
- The "tap to zoom" captions became "swipe to zoom" in 2.1. Do not revert.

---

## Pre-submit checklist (v2.2)
- [x] CloudKit: no schema change in 2.2
- [x] Screenshots regenerated (6 iPhone + 6 iPad); captions unchanged, still true
- [ ] Build 2.2 (7) archived and uploaded to App Store Connect
- [ ] `scripts/asc.py release ... --submit` run together with Randhawa 3.2,
      not after. The dot sheet is empty of places without Randhawa, so a
      reviewer who sees this alone sees half a feature.
