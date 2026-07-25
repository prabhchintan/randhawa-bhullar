# Randhawa: App Store listing

Copy/paste these into App Store Connect. Everything here is written to be
truthful about the app (no wallpaper claims, no data collection) so it sails
through review.

---

## Name (max 30)
Randhawa

## Subtitle (max 30)
The year, one dot at a time

## Promotional text (max 170, editable any time without review)
A quiet reminder of how much of the year is left. One dot for every day, right
on your Home and Lock Screen. No accounts, no tracking, just the year, at a
glance.

## Keywords (max 100, comma-separated)
year,progress,dot,dots,widget,countdown,days,calendar,motivation,time,2026,lockscreen,reminder,goal

## Description (max 4000)
Randhawa shows you the whole year as a grid of dots, one for every day. The days
that have passed are filled in; today glows; the rest wait quietly. It’s a simple,
honest way to feel how much of the year is left.

Add the widget and it lives where you’ll actually see it: your Home Screen and
your Lock Screen, updating itself every day.

• One dot for every day of the year
• Today is always highlighted
• Home Screen widgets: small, medium, and large
• Lock Screen widgets: circular, rectangular, and inline
• Updates automatically at midnight
• Adapts to leap years on its own

Deliberately minimal:
• No accounts. No sign-up.
• No tracking. No analytics. No ads.
• No data collected: everything is computed on your device from the date.

Randhawa does one thing and does it cleanly. Glance, take it in, get on with your
day.

## What's New (for v1.0)
First release. One dot for every day of the year, on your Home and Lock Screen.

---

## App information
- Primary category: Productivity
- Secondary category: Utilities
- Age rating: 4+ (answer "None" to every content question)
- Price: Free (suggested)

## URLs (host these on prabhchintan.com)
- Support URL: https://prabhchintan.com/randhawa/support
- Privacy Policy URL: https://prabhchintan.com/randhawa/privacy
- Marketing URL (optional): https://prabhchintan.com/randhawa

(HTML for the support and privacy pages is in AppStore/site/.)

## App Privacy ("nutrition label") answers
- Data collection: **No, we do not collect data from this app.**
  That's the entire questionnaire; Randhawa has no network code, no SDKs, no
  analytics, and stores nothing off-device.

## Screenshots
- AppStore/screenshots/*.png: 1320×2868 (6.9" iPhone). App Store Connect scales
  this size down for all smaller iPhones, so this one set is sufficient for
  iPhone. (If you later enable iPad, you'll need a 13" iPad set too.)

## Export compliance
- Uses non-exempt encryption? **No.** (The app makes no network connections and
  uses no encryption.) In Xcode you can set ITSAppUsesNonExemptEncryption = NO
  to skip the question on every upload; say the word and I'll add it to Info.

---

## Pre-submit checklist
- [ ] Set your Team on both targets (Signing & Capabilities)
- [ ] Confirm bundle IDs (com.randhawa.app + .RandhawaWidget) match App Store Connect
- [ ] Reserve the name "Randhawa" in App Store Connect
- [ ] Host privacy + support pages on prabhchintan.com
- [ ] Product → Archive → Distribute → App Store Connect
- [ ] Upload screenshots + paste copy above
- [ ] Fill App Privacy = Data Not Collected
- [ ] Age rating = 4+
- [ ] Submit for review
