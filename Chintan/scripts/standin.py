"""A stand-in for the house's say door, for the eyes alone (see.sh study@hawa).

The eyes once said their word to the real hawa on every look, and hawa saw
the copies. Now a word said by the eyes reaches this instead: POST /v1/say
answers 202 with an id, GET /v1/say/ID answers 202 for six seconds, then a
reply. Every request is written to LOG, one line each, so a look can count
how many words reached the house. Anything else answers 404, and the app
falls back on what the phone holds.

It keeps a board too, of invented things (see.sh board@back): GET /v1/board
serves four, and once a file LOG.gone exists, three, the first taken as if
done elsewhere, so a look sees a thing leave the phone on its return.

    python3 -I standin.py PORT LOG
"""
import datetime
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = sys.argv[2]
born = {}


def board():
    day = datetime.date.today()
    on = lambda n: (day + datetime.timedelta(days=n)).isoformat()
    things = [
        f"- [ ] Return the library books, due back today \U0001F4C5 {on(0)}",
        f"- [ ] Water the ferns \U0001F4C5 {on(0)}",
        f"- [ ] Post the birthday card, so it lands by the weekend \U0001F4C5 {on(1)}",
        f"- [ ] Sharpen the kitchen knives \U0001F4C5 {on(9)}",
    ]
    if os.path.exists(LOG + ".gone"):
        things = things[1:]
    return "OPEN\n" + "\n".join(things) + "\n"


class Door(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def note(self, body=b""):
        with open(LOG, "a") as f:
            f.write(f"{time.time():.1f} {self.command} {self.path} {body.decode(errors='replace')}\n")

    def answer(self, code, obj):
        data = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self.note(body)
        if self.path == "/v1/say":
            sid = "standin-%d" % (len(born) + 1)
            born[sid] = time.time()
            return self.answer(202, {"id": sid})
        self.answer(404, {})

    def do_GET(self):
        self.note()
        if self.path == "/v1/board":
            return self.answer(200, {"text": board()})
        if self.path.startswith("/v1/say/"):
            sid = self.path.rsplit("/", 1)[1]
            if sid not in born:
                return self.answer(404, {})
            if time.time() - born[sid] < 6:
                return self.answer(202, {"id": sid})
            return self.answer(200, {"reply": "Gravity, mostly, and a buttered side that is heavier."})
        self.answer(404, {})


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Door).serve_forever()
