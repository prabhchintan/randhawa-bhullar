# chintan, the private app

The maintainer's word, 2026-09-21, 21:22, on the study line: "yes let's build
chintan as an iOS app just for me." This is the brief. It binds the loop the
way LOOP.md binds it, and LOOP.md's section "chintan, the private app" is
the covenant this brief sits under.

## What it is

A third app in this repository, in `Chintan/` beside `Bhullar/`, with its
own project (`Chintan/Chintan.xcodeproj`, target Chintan, bundle
`Prabhchintan.Chintan`, display name `chintan`, lowercase like the name
itself). An audience of one: it ships to the maintainer's phone through
TestFlight internal testing and nowhere else. Never the App Store, never
external testers, never a store listing, screenshots, privacy label or
support page. It is the maintainer's door to chintan, the butler that runs
on his always-on home machine, carried in his pocket.

It does not use MemoryKit and never touches the memory formats or the
CloudKit schema. Randhawa and Bhullar keep their four refusals; this app
has a different nature (it talks to one server, the maintainer's own) and
its own rules below.

## The wall it talks to

The house serves a small JSON door on the maintainer's tailnet. The
address is typed once into the app's settings screen and kept in the
Keychain; it is not in this repository and the default is empty. Every
request is over plain HTTP on the tailnet (WireGuard is the wire), so the
app's Info.plist allows arbitrary loads and the brief is the reason: a
private app whose only host is the maintainer's own machine. There is no
token, no login and no account; the house checks the caller's tailnet
identity and answers only his devices.

    GET  /v1/health            {"ok": true, "house": "chintan", "time": "..."}
    GET  /v1/cockpit           {"text": "..."}   the house's one-screen view
    POST /v1/say {"text": ""}  {"id": "...", "reply": "..."}
                               waits up to 280 s; on 202 the reply is not
                               ready and GET /v1/say/ID fetches it later
    GET  /v1/say/ID            {"reply": "..."} or 202 while the house thinks

A reply is plain text, may run a few screens, and may take a minute or
more: chintan reads files, runs hands, sometimes launches research before
answering. The app shows that it is thinking and keeps the composer usable.

## The first build

Two screens, a tab each, SwiftUI, the same deployment target as Randhawa:

1. **The study.** A conversation with chintan. Messages in a list, his on
   the right, chintan's on the left, a composer at the bottom, send on
   return. Sending posts to `/v1/say`; the reply appears when it comes.
   The conversation is kept on the device (a JSON file in Application
   Support, newest last, trimmed to the last 500 turns), never synced.
2. **The jharokha.** `/v1/cockpit` as monospaced text, refreshed on open
   and by pull.

A settings screen (a gear) for the house address and a health check that
says "chintan is home" or what went wrong. Any failure to reach the house
is said plainly in the app's own words ("the house is not answering; are
you on the tailnet?") and never as a raw error.

Nothing else in the first build. No widgets, no notifications, no
background work, no Siri. Those are later rungs, on the maintainer's word.

## Rules

- Talks to one host, the one in its settings. No analytics, no crash
  reporting, no third-party code, no phone-home of any kind. Same house
  style as the other apps: no em dashes or en dashes anywhere.
- TestFlight internal testing only. Never `--submit`. Never external
  testers. A build expires ninety days after upload (Apple's rule, read
  from Apple's TestFlight overview 2026-09-21); the loop re-uploads before
  that and the report says when the current build expires.
- The maintainer's word on this app comes the same way as everything else:
  the inbox, or chintan through the post office. The loop widens nothing
  on its own.

## The pipeline

Build check, simulator, alongside the others:

    xcodebuild -project Chintan/Chintan.xcodeproj -target Chintan \
      -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build

Archive and upload exactly as RELEASING.md section 5, with the same
exportOptions and cloud signing, and stop there. Add the build line to
`.github/workflows/loop.yml` beside Bhullar's.

What the loop can do alone: register the bundle identifier if it is not yet
registered (`POST /v1/bundleIds` on the App Store Connect API; add the verb
to `scripts/asc.py`), build, archive, upload, and make sure the internal
group ("house", one tester, the maintainer) is set to receive builds
automatically. What it cannot: the app record itself in App Store Connect,
if the API refuses to create it. If the record is missing, build for the
simulator, commit, and say in the report exactly what the maintainer needs
to do (New App, iOS, name chintan, bundle Prabhchintan.Chintan, SKU
chintan, English US, no availability needed).

Done, for the first build: a TestFlight build on the maintainer's phone
that asks the house `/v1/health` and shows "chintan is home", and a first
message on the study tab answered by the house.

## The second lane (2026-09-22)

The maintainer's word, 12:56 on the study line: start on the iterations. So
the Swift for this app may come from the house itself (chintan, on his home
machine, pushed to main) as well as from the loop, and the Mac part is its
own job: `.github/workflows/chintan.yml` compiles, cloud-signs and uploads
one build with the build number set to the UTC minute (no project file
commit needed), by hand on a GitHub Mac or nightly on yantar, the
maintainer's MacBook, registered once with `scripts/yantar-runner.sh`. The
house door grew `GET /v1/board` ({"text": ...}, his to-dos as the house
prints them), and the app a third tab, the board, that shows them. The
rungs after it, on his word: marking a thing done from the phone,
notifications (needs an APNs key, his hands once), a widget. On 09-23 the
house added the guest book (VisitorsView.swift, `/v1/visitors`) and the
painting shelf (Gallery in Theme.swift, `/v1/paintings`).

The loop keeps its own run as before and, when it touches this app, reads
this section first so two hands do not write the same file the same night.
