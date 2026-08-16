#!/usr/bin/env python3
"""The maintainer's own map, pulled from his private CloudKit database.

This is the one dataset the Sunday loop can study without the apps ever
phoning home: the maintainer's own moments and memories, read with a cktool
user token that belongs to his iCloud account and nobody else's. It writes to
~/Library/Application Support/randhawa-loop/map/, never into the repository,
because it is location data.

Needs, once: `xcrun cktool save-token --type user --method file` with the user
token from the CloudKit Console (account menu, Settings, Tokens), and the
recordName QUERYABLE index on Moment and Memory deployed to Production
(done 2026-08-16).

A memory whose text begins with "@loop" (any case, optional colon) is a note
to the loop written from inside the app: `--inbox DIR` files each new one
under DIR as inbox/<stamp>-memory<id>.md, remembering which ids were already
delivered in DIR/.memories-seen. The memory itself is left untouched.

Usage:
    mymap.py                 pull everything and print a summary
    mymap.py --summary       summary of what is already on disk, no network
    mymap.py --inbox DIR     also file @loop memories into DIR
"""

import argparse
import json
import math
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

TEAM = "7FWNAT83XU"
CONTAINER = "iCloud.Prabhchintan.Randhawa"
OUT_DIR = os.path.expanduser("~/Library/Application Support/randhawa-loop/map")


def query(record_type):
    """Every record of a type in the production private database."""
    records = []
    token = None
    while True:
        cmd = ["xcrun", "cktool", "query-records", "--team-id", TEAM, "--container-id", CONTAINER,
               "--environment", "production", "--database-type", "private", "--zone-name", "SpaceTime",
               "--record-type", record_type, "--limit", "200"]
        if token:
            cmd += ["--continuation-token", token]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise SystemExit(f"cktool failed: {result.stderr.strip() or result.stdout.strip()}")
        page = json.loads(result.stdout)
        records.extend(page.get("records", []))
        token = page.get("continuationToken")
        if not token:
            return records


def moment_from(record):
    fields = record["fields"]
    return {
        "id": record["recordName"].removeprefix("moment-"),
        "latitude": fields["latitude"]["value"],
        "longitude": fields["longitude"]["value"],
        "date": fields["date"]["value"],
    }


def memory_from(record):
    fields = record["fields"]
    def value(name):
        return fields.get(name, {}).get("value")
    return {
        "id": record["recordName"].removeprefix("memory-"),
        "date": value("date"),
        "latitude": value("latitude"),
        "longitude": value("longitude"),
        "placeName": value("placeName"),
        "text": value("text") or "",
        "hasPhoto": "photo" in fields,
    }


def pull():
    os.makedirs(OUT_DIR, exist_ok=True)
    moments = sorted((moment_from(r) for r in query("Moment")), key=lambda m: m["date"])
    memories = sorted((memory_from(r) for r in query("Memory")), key=lambda m: m["date"] or "")
    with open(os.path.join(OUT_DIR, "moments.json"), "w") as handle:
        json.dump({"pulledAt": datetime.now(timezone.utc).isoformat(), "moments": moments}, handle, indent=1)
    with open(os.path.join(OUT_DIR, "memories.json"), "w") as handle:
        json.dump({"pulledAt": datetime.now(timezone.utc).isoformat(), "memories": memories}, handle, indent=1)
    return moments, memories


def load():
    with open(os.path.join(OUT_DIR, "moments.json")) as handle:
        moments = json.load(handle)["moments"]
    with open(os.path.join(OUT_DIR, "memories.json")) as handle:
        memories = json.load(handle)["memories"]
    return moments, memories


def meters(a, b):
    mid = math.radians((a["latitude"] + b["latitude"]) / 2)
    dlat = (b["latitude"] - a["latitude"]) * 111_320
    dlon = (b["longitude"] - a["longitude"]) * 111_320 * math.cos(mid)
    return math.hypot(dlat, dlon)


def summary(moments, memories, days=7):
    """What the loop wants to know each Sunday, as plain lines."""
    now = datetime.now(timezone.utc)
    lines = []
    parse = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
    stamps = [parse(m["date"]) for m in moments]
    lines.append(f"{len(moments)} moments, {len(memories)} memories on iCloud")
    if stamps:
        lines.append(f"first {stamps[0].date()}, last {stamps[-1].isoformat(timespec='minutes')}")
    recent = [m for m, t in zip(moments, stamps) if now - t <= timedelta(days=days)]
    lines.append(f"last {days} days: {len(recent)} moments")
    per_day = Counter(parse(m["date"]).astimezone().date().isoformat() for m in recent)
    for day in sorted(per_day):
        lines.append(f"  {day}: {per_day[day]}")
    # Gaps: the longest silences in the last week, which say whether the trail
    # is alive or whether the phone sat still.
    if len(recent) > 1:
        gaps = []
        for a, b in zip(recent, recent[1:]):
            gaps.append((parse(b["date"]) - parse(a["date"]), a["date"], b["date"]))
        gaps.sort(reverse=True)
        lines.append("longest gaps: " + "; ".join(f"{g[0]} ({g[1][:16]})" for g in gaps[:3]))
        moved = sum(1 for a, b in zip(recent, recent[1:]) if meters(a, b) > 150)
        lines.append(f"pairs more than 150 m apart: {moved} of {len(recent) - 1}")
    # Distinct places, cheaply: 150 m grid cells.
    cells = {(round(m["latitude"] * 600), round(m["longitude"] * 600)) for m in moments}
    lines.append(f"roughly {len(cells)} distinct places (150 m cells)")
    recent_memories = [m for m in memories if m["date"] and now - parse(m["date"]) <= timedelta(days=days)]
    lines.append(f"memories in the last {days} days: {len(recent_memories)}")
    return "\n".join(lines)


NOTE_PREFIX = re.compile(r"^\s*@loop\b:?\s*", re.IGNORECASE)


def file_notes(memories, inbox_dir):
    """Writes each not-yet-delivered @loop memory as an inbox file. Returns
    the paths written."""
    os.makedirs(inbox_dir, exist_ok=True)
    seen_path = os.path.join(inbox_dir, ".memories-seen")
    seen = set()
    if os.path.exists(seen_path):
        with open(seen_path) as handle:
            seen = {line.strip() for line in handle if line.strip()}
    written = []
    for memory in memories:
        text = memory.get("text") or ""
        if not NOTE_PREFIX.match(text) or memory["id"] in seen:
            continue
        body = NOTE_PREFIX.sub("", text, count=1).strip()
        stamp = re.sub(r"[^0-9T]", "", memory.get("date") or "")[:13] + "Z"
        path = os.path.join(inbox_dir, f"{stamp}-memory{memory['id'][:8]}.md")
        with open(path, "w") as handle:
            handle.write("# From inside the app\n\n")
            handle.write(f"A memory written in {'Randhawa' if memory.get('latitude') is not None else 'Bhullar'} at {memory.get('date')}\n\n")
            handle.write(body + "\n")
        seen.add(memory["id"])
        written.append(path)
    with open(seen_path, "w") as handle:
        handle.write("\n".join(sorted(seen)) + ("\n" if seen else ""))
    return written


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--summary", action="store_true", help="summarise what is on disk, do not pull")
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--inbox", default=None, help="file @loop memories into this directory")
    args = parser.parse_args(argv)
    moments, memories = load() if args.summary else pull()
    print(summary(moments, memories, days=args.days))
    if args.inbox:
        written = file_notes(memories, args.inbox)
        print(f"notes from inside the app: {len(written)} new")


if __name__ == "__main__":
    main()
