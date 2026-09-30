#!/usr/bin/env python3
"""The quiet check (FUNNEL.md, 2026-09-30).

What the public repository may never carry, checked by machine on every
push and pull request, in the sprint before it commits, and on the house
before anything is filed to the loop:

  anywhere      a private address, the house's port, a tailnet name, an
                em or en dash
  public lanes  (Randhawa/, RandhawaWidget/, Bhullar/, MemoryKit/, Shared/,
                Maproom/) a house door path or CHINTAN_HOUSE; networking,
                HealthKit, CoreMotion, NetworkExtension, MetricKit or
                arbitrary loads; a launch-argument switch; a permission,
                background mode or entitlement key the previous commit
                did not have (those wait for the maintainer, LOOP.md)

What it cannot know, the maintainer's own life, is a private word list the
house keeps and passes with --words; the list is never in this repository.

  python3 scripts/quiet.py            the whole tree
  python3 scripts/quiet.py --diff     only files changed against HEAD (or
                                      staged, when the tree is dirty)
  python3 scripts/quiet.py --words F  also fail on any word in F, one per
                                      line, case-insensitive, anywhere

Exit 1 on any hit, each printed as path:line: reason. QUIET_ALLOW_PLIST=1
lets a plist or entitlement change through (the maintainer's own word,
used once, on the commit that carries it).
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBLIC = ("Randhawa/", "RandhawaWidget/", "Bhullar/", "MemoryKit/", "Shared/", "Maproom/")
TEXT = (".swift", ".md", ".py", ".sh", ".yml", ".yaml", ".plist", ".entitlements",
        ".json", ".txt", ".html", ".css", ".js", ".pbxproj", ".xcscheme", ".strings")
SKIP_DIRS = {".git", "DerivedData", "build", ".build", "__pycache__", "xcuserdata"}

ANYWHERE = [
    (re.compile(r"\b100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d{1,3}\.\d{1,3}\b"), "a tailnet address"),
    (re.compile(r"\b(?:10|192\.168)\.\d{1,3}\.\d{1,3}(?:\.\d{1,3})?\b"), "a private address"),
    (re.compile(r"\.ts\.net\b"), "a tailnet name"),
    (re.compile(r"(?<![\w.])8082(?![\w.])"), "the house's port"),
    (re.compile("[–—]"), "an em or en dash"),
]

PUBLIC_ONLY = [
    (re.compile(r"/v1/"), "a house door path in a public lane"),
    (re.compile(r"CHINTAN_HOUSE"), "the house's address variable in a public lane"),
    (re.compile(r"\bimport\s+(HealthKit|CoreMotion|NetworkExtension|MetricKit|Network)\b"), "a sense the public apps never use"),
    (re.compile(r"\bURLSession\b|\bURLRequest\b|\bNWConnection\b"), "networking in a public lane"),
    (re.compile(r"NSAllowsArbitraryLoads"), "arbitrary loads in a public lane"),
    (re.compile(r"CommandLine\.arguments|processInfo\.arguments"), "a launch-argument switch in a public lane"),
]

# Keys in a public plist or entitlements file that wait for the maintainer.
WATCHED_KEY = re.compile(r"<key>(NS\w*UsageDescription|UIBackgroundModes|NSAppTransportSecurity|"
                         r"BGTaskSchedulerPermittedIdentifiers|com\.apple\.developer\.[\w.-]+|"
                         r"com\.apple\.security\.[\w.-]+)</key>")


def files_all():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.endswith(".xcarchive")]
        for f in filenames:
            if f.endswith(TEXT):
                yield os.path.relpath(os.path.join(dirpath, f), ROOT)


def files_diff():
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True).stdout
    if dirty.strip():
        out = subprocess.run(["git", "diff", "--name-only", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout
        out += subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT, capture_output=True, text=True).stdout
    else:
        out = subprocess.run(["git", "diff", "--name-only", "HEAD~1", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout
    for line in out.splitlines():
        p = line.strip()
        if p and p.endswith(TEXT) and os.path.exists(os.path.join(ROOT, p)):
            yield p


def previous(path):
    r = subprocess.run(["git", "show", f"HEAD:{path}"], cwd=ROOT, capture_output=True, text=True)
    if r.returncode == 0:
        return r.stdout
    r = subprocess.run(["git", "show", f"HEAD~1:{path}"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def check(path, words):
    hits = []
    full = os.path.join(ROOT, path)
    try:
        text = open(full, encoding="utf-8", errors="replace").read()
    except OSError:
        return hits
    public = path.startswith(PUBLIC)
    rules = ANYWHERE + (PUBLIC_ONLY if public else [])
    if path.startswith("Maproom/"):
        # A command line tool on the maintainer's Mac: arguments are its door.
        rules = [r for r in rules if "launch-argument" not in r[1]]
    for n, line in enumerate(text.splitlines(), 1):
        for rx, why in rules:
            if rx.search(line):
                hits.append((path, n, why))
        for w in words:
            if w.search(line):
                hits.append((path, n, "a word from the house's list"))
    if public and path.endswith((".plist", ".entitlements")) and not os.environ.get("QUIET_ALLOW_PLIST"):
        before = set(WATCHED_KEY.findall(previous(path)))
        for n, line in enumerate(text.splitlines(), 1):
            m = WATCHED_KEY.search(line)
            if m and m.group(1) not in before:
                hits.append((path, n, f"a new key that waits for the maintainer: {m.group(1)}"))
    return hits


def main(argv):
    diff = "--diff" in argv
    words = []
    if "--words" in argv:
        wf = argv[argv.index("--words") + 1]
        for line in open(wf, encoding="utf-8"):
            w = line.strip()
            if w and not w.startswith("#"):
                # Whole words: "DIA" must not fire on "media".
                pat = re.escape(w)
                if re.match(r"\w", w):
                    pat = r"\b" + pat
                if re.search(r"\w$", w):
                    pat = pat + r"\b"
                words.append(re.compile(pat, re.IGNORECASE))
    paths = list(files_diff() if diff else files_all())
    hits = []
    for p in paths:
        if p == "scripts/quiet.py":
            continue
        hits.extend(check(p, words))
    for path, n, why in hits:
        # Never echo the matching text: a word from the house's list is
        # itself the thing kept quiet. The line number is enough.
        print(f"{path}:{n}: {why}")
    if hits:
        print(f"quiet: {len(hits)} hit(s) in {len(paths)} file(s)")
        return 1
    print(f"quiet: clean, {len(paths)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
