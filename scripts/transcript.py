#!/usr/bin/env python3
"""Turns a `claude -p --output-format stream-json --verbose` stream into a
readable transcript: the assistant's words, each tool call with a trimmed
input, each tool result trimmed, and the final result. Reads stdin, writes
stdout. Anything that is not JSON passes through unchanged."""

import json
import sys

LIMIT = 600


def trim(text, limit=LIMIT):
    text = str(text)
    return text if len(text) <= limit else text[:limit] + f" ... [{len(text) - limit} more]"


for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        print(raw)
        continue
    kind = event.get("type")
    if kind == "assistant":
        for block in event.get("message", {}).get("content", []):
            if block.get("type") == "text" and block.get("text", "").strip():
                print("\n" + block["text"].strip())
            elif block.get("type") == "tool_use":
                inp = block.get("input", {})
                shown = inp.get("command") or inp.get("file_path") or inp.get("pattern") or json.dumps(inp)
                print(f"\n>>> {block.get('name')}: {trim(shown, 300)}")
    elif kind == "user":
        for block in event.get("message", {}).get("content", []):
            if isinstance(block, dict) and block.get("type") == "tool_result":
                content = block.get("content")
                if isinstance(content, list):
                    content = "\n".join(c.get("text", "") for c in content if isinstance(c, dict))
                if content:
                    print("    " + trim(content).replace("\n", "\n    "))
    elif kind == "result":
        print("\n=== result: " + str(event.get("subtype")) + f", {event.get('num_turns')} turns, "
              f"{round((event.get('duration_ms') or 0) / 60000, 1)} min, cost ${event.get('total_cost_usd', 0):.2f} ===")
        if event.get("result"):
            print(event["result"])
