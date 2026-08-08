# Working in this repository

GitHub is the source of truth. Pull before working, commit and push when
done, and tag releases as described in RELEASING.md.

This repository lives at ~/Desktop/prabhchintan.com/Randhawa. It sits inside
the website repository's folder for convenience and is ignored by it; the two
are separate repositories with separate remotes, and neither should ever be
committed into the other.

Read before changing anything, in this order:

1. MemoryKit/README.md: the shared data contract. Its compatibility rules
   outrank every feature request.
2. ROADMAP.md: the three lanes (MemoryKit, Randhawa, Bhullar) and why this
   is one repository.
3. VISION.md: the voice, and the rule that the names story stays quiet.
4. RELEASING.md: the end to end ship process.

Build checks, from the repo root. The DEVELOPER_DIR prefix is kept because
xcode-select still points at CommandLineTools (whose Swift is 5.3 from 2020);
~/.zshrc exports the same variable, so interactive shells are already correct
and the prefix is only insurance for shells that skip the profile:

    xcodebuild -project Randhawa.xcodeproj -target Randhawa \
      -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
    xcodebuild -project Bhullar/Bhullar.xcodeproj -target Bhullar \
      -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build

House style:

- No em dashes or en dashes anywhere: code, comments, docs, store copy.
- Match the existing comment voice: short, declarative, no filler.
- Copy changes must keep the privacy claims literally true.
- Do not install development builds on the maintainer's devices; releases
  are verified through App Store updates.
- Widget targets compile only the widget safe MemoryKit files
  (MomentStore.swift, MemoryModel.swift); check target membership before
  adding types to shared files. Bhullar's widget compiles TimeScale.swift and
  DotGrid.swift but neither MemoryKit file, so nothing in those two may
  mention Moment or Memory.
- The trail (background location, Randhawa 3.1) ships under five constraints
  written down in ROADMAP.md under "The one we reversed". Any change that
  cannot honour all five should turn the trail off instead.
- The apps' public privacy and support pages are not in this repo; they
  live in the maintainer's website repo and are served at
  prabhchintan.com/randhawa/privacy and /randhawa/support.
