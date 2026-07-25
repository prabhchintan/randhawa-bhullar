# Bhullar, App Store listing (v2.0)

Copy/paste these into App Store Connect.

---

## App record (unchanged)
- Name: **Bhullar** · Bundle ID: **Prabhchintan.Bhullar** · SKU: Prabhchintan.Bhullar
- Price: Free · Availability: all countries · Age rating: 4+ (all "None")

## Subtitle (max 30, this is 23)
Time, one dot at a time

## Promotional text (max 170, editable any time without review; this is 160)
The year in months, weeks, or days. Today in hours or minutes. One grid of dots; tap to zoom. Now with memories: your notes resurface on the day they were made.

## Keywords (max 100, comma-separated; this is 90)
year,progress,dots,widget,countdown,days,weeks,months,hours,calendar,time,minimal,memories

## Description (max 4000)
Bhullar is a telescope for time. One grid of dots, five zoom levels. Tap the grid and the year becomes months, then weeks, then days; tap again and you are looking at today, hour by hour, then minute by minute.

The unit you are in glows. The units that have passed fill in. The rest wait quietly. That is the whole app, and that is the point.

New in 2.0: memories. Tap the plus button and write down what right now deserves to keep, with a photo if you like. Days that hold a memory glow gold in the grid, and when a memory's date comes around again it resurfaces under the grid: on this day. If you also use Randhawa, our map app, memories flow between the two: made in either, shown in both. Randhawa gives them a place; Bhullar gives them a time.

• 12 months, 52-odd weeks, 365-odd days, 24-odd hours, 1,440-odd minutes
• Tap anywhere on the dots to change scale; the app remembers where you left it
• Three Home Screen widgets: Year in Dots, Day in Dots, and Dots at Any Scale, which you can set to months, weeks, days, or hours
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

## What's New (paste from AppStore/whatsnew-2.0.md)

## App Review notes (Review Information → Notes)
Bhullar is the time-keeping sibling of our app Randhawa (Apple App ID
6742061604). The two share a design language and, since this release, a
memories feature: short user-written notes, optionally with a photo chosen
through the out-of-process system Photos picker (no photo library permission
is requested). Memories are stored on device in an App Group shared by the
two apps and, only if the user turns on iCloud sync, in the user's own
private CloudKit database. The developer runs no servers and cannot access
any user's data, so the privacy label remains "Data Not Collected". The time
grid itself stores nothing and is computed from the current date.

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

## Screenshots (regenerated for 2.0 with swift Bhullar/scripts/makescreenshots.swift)
- Bhullar/AppStore/screenshots/*.png (1284x2778 iPhone) and ipad/ (2048x2732),
  5 shots each
- Order: 01-app (telescope hero), 02-scales (2x2 zoom levels), 03-widgets
  (three widgets), 04-memories (gold days + on-this-day pill), 05-privacy
  (no accounts, honest timekeeping)

---

## Pre-submit checklist (v2.0)
- [ ] CloudKit schema deployed to Production (done once, shared with Randhawa)
- [ ] Xcode: iCloud capability provisioned on the app target (first build)
- [ ] Build 2.0 (4) uploaded from Xcode and processed
- [ ] New version 2.0 created on the ASC distribution page
- [ ] Promo text, keywords, description, What's New updated
- [ ] Screenshots updated (iPhone + iPad)
- [ ] Privacy label confirmed: Data Not Collected
- [ ] Review notes pasted
- [ ] Submit for review (with or right after Randhawa 3.0)
