#!/usr/bin/env python3
"""App Store Connect from the command line, for the Sunday loop.

Everything RELEASING.md used to do in a browser after the upload: create the
version, set the copy, replace the screenshots, write the review notes, attach
the build, submit. Plus the two feeds the loop reads: review status and the
analytics reports Apple gathers from users who opted in.

Auth is an App Store Connect API key (Team key, Admin) described by
~/.config/appstoreconnect/config.json:

    {"key_id": "...", "issuer_id": "...", "key_path": "/abs/AuthKey_....p8",
     "team_id": "7FWNAT83XU"}

Nothing here needs Xcode. PyJWT[crypto] is the only non-stdlib dependency.

Usage (all subcommands take --app <bundle id>):

    asc.py apps
    asc.py builds --app Prabhchintan.Randhawa
    asc.py status --app Prabhchintan.Randhawa
    asc.py release --app Prabhchintan.Randhawa --version 3.2 --build 13 \
        --metadata AppStore/metadata.md --whatsnew AppStore/whatsnew-3.2.md \
        --screenshots AppStore/screenshots [--submit]
    asc.py analytics --app Prabhchintan.Randhawa --out ~/loop/analytics
"""

import argparse
import gzip
import hashlib
import io
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
CONFIG_PATH = os.path.expanduser("~/.config/appstoreconnect/config.json")

# Screenshot folders in this repo map to these display types. iPhone shots are
# 1284x2778 (6.7 inch); iPad shots under ipad/ are 2048x2732 (13 inch).
DISPLAY_TYPES = {
    ".": "APP_IPHONE_67",
    "ipad": "APP_IPAD_PRO_3GEN_129",
}


class ASC:
    def __init__(self, config_path=CONFIG_PATH):
        with open(config_path) as handle:
            self.config = json.load(handle)
        with open(self.config["key_path"]) as handle:
            self.private_key = handle.read()
        self._token = None
        self._token_born = 0

    # -- transport ---------------------------------------------------------

    def token(self):
        # Apple caps token life at 20 minutes; refresh at 15.
        if self._token is None or time.time() - self._token_born > 15 * 60:
            now = int(time.time())
            self._token = jwt.encode(
                {"iss": self.config["issuer_id"], "iat": now, "exp": now + 19 * 60,
                 "aud": "appstoreconnect-v1"},
                self.private_key,
                algorithm="ES256",
                headers={"kid": self.config["key_id"], "typ": "JWT"},
            )
            self._token_born = time.time()
        return self._token

    def request(self, method, path, body=None, params=None, raw=False):
        url = path if path.startswith("http") else API + path
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params, doseq=True)
        data = None
        headers = {"Authorization": "Bearer " + self.token()}
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                payload = resp.read()
        except urllib.error.HTTPError as err:
            detail = err.read().decode(errors="replace")
            raise SystemExit(f"{method} {url}\nHTTP {err.code}\n{detail}") from None
        if raw:
            return payload
        return json.loads(payload) if payload else {}

    def get(self, path, **params):
        return self.request("GET", path, params=params or None)

    def get_all(self, path, **params):
        """Follows pagination, returns the concatenated data list."""
        out = []
        page = self.get(path, **params)
        while True:
            out.extend(page.get("data", []))
            nxt = page.get("links", {}).get("next")
            if not nxt:
                return out
            page = self.request("GET", nxt)

    def post(self, path, body):
        return self.request("POST", path, body)

    def patch(self, path, body):
        return self.request("PATCH", path, body)

    def delete(self, path):
        return self.request("DELETE", path)

    # -- lookups ---------------------------------------------------------

    def app(self, bundle_id):
        apps = self.get("/apps", **{"filter[bundleId]": bundle_id})["data"]
        if not apps:
            raise SystemExit(f"no app with bundle id {bundle_id}")
        return apps[0]

    def builds(self, app_id, limit=10):
        return self.get(
            "/builds",
            **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": limit,
               "include": "preReleaseVersion",
               "fields[builds]": "version,uploadedDate,processingState,expired,preReleaseVersion",
               "fields[preReleaseVersions]": "version"},
        )

    def versions(self, app_id, limit=5):
        return self.get(
            f"/apps/{app_id}/appStoreVersions",
            **{"filter[platform]": "IOS", "limit": limit,
               "fields[appStoreVersions]": "versionString,appVersionState,createdDate,releaseType"},
        )["data"]

    def version_named(self, app_id, version_string):
        for version in self.versions(app_id, limit=20):
            if version["attributes"]["versionString"] == version_string:
                return version
        return None

    def localization(self, version_id, locale="en-US"):
        for loc in self.get(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]:
            if loc["attributes"]["locale"] == locale:
                return loc
        raise SystemExit(f"no {locale} localization on version {version_id}")

    # -- release steps -----------------------------------------------------

    def ensure_version(self, app_id, version_string):
        existing = self.version_named(app_id, version_string)
        if existing:
            print(f"version {version_string} exists ({existing['attributes']['appVersionState']})")
            return existing
        created = self.post("/appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": version_string,
                           "releaseType": "AFTER_APPROVAL"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }})["data"]
        print(f"created version {version_string}")
        return created

    def set_copy(self, loc_id, copy):
        attributes = {k: v for k, v in copy.items() if v}
        self.patch(f"/appStoreVersionLocalizations/{loc_id}", {"data": {
            "type": "appStoreVersionLocalizations", "id": loc_id, "attributes": attributes,
        }})
        print("copy set: " + ", ".join(sorted(attributes)))

    def set_review_notes(self, version_id, notes, contact):
        detail = self.get(f"/appStoreVersions/{version_id}/appStoreReviewDetail").get("data")
        attributes = {"notes": notes, "demoAccountRequired": False}
        attributes.update(contact)
        if detail:
            self.patch(f"/appStoreReviewDetails/{detail['id']}", {"data": {
                "type": "appStoreReviewDetails", "id": detail["id"], "attributes": attributes,
            }})
        else:
            self.post("/appStoreReviewDetails", {"data": {
                "type": "appStoreReviewDetails", "attributes": attributes,
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}},
            }})
        print("review notes set")

    def attach_build(self, version_id, build_id):
        self.patch(f"/appStoreVersions/{version_id}/relationships/build",
                   {"data": {"type": "builds", "id": build_id}})
        print(f"build {build_id} attached")

    def find_build(self, app_id, version_string, build_number, wait_minutes=40):
        """The processed build for version_string (build_number), waiting for
        Apple's processing if it was uploaded moments ago."""
        deadline = time.time() + wait_minutes * 60
        while True:
            page = self.builds(app_id, limit=20)
            pre = {inc["id"]: inc["attributes"]["version"]
                   for inc in page.get("included", []) if inc["type"] == "preReleaseVersions"}
            for build in page["data"]:
                attrs = build["attributes"]
                pre_id = (build.get("relationships", {}).get("preReleaseVersion", {})
                          .get("data") or {}).get("id")
                if attrs["version"] != str(build_number) or pre.get(pre_id) != version_string:
                    continue
                if attrs["processingState"] == "VALID":
                    return build
                print(f"build {version_string} ({build_number}) is {attrs['processingState']}, waiting")
                break
            else:
                print(f"build {version_string} ({build_number}) not visible yet, waiting")
            if time.time() > deadline:
                raise SystemExit("gave up waiting for the build to process")
            time.sleep(60)

    def replace_screenshots(self, loc_id, folder):
        sets = {s["attributes"]["screenshotDisplayType"]: s
                for s in self.get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]}
        for sub, display_type in DISPLAY_TYPES.items():
            path = os.path.normpath(os.path.join(folder, sub))
            files = sorted(f for f in os.listdir(path) if f.lower().endswith(".png"))
            if not files:
                continue
            shot_set = sets.get(display_type)
            if shot_set is None:
                shot_set = self.post("/appScreenshotSets", {"data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {"appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}},
                }})["data"]
            set_id = shot_set["id"]
            for old in self.get_all(f"/appScreenshotSets/{set_id}/appScreenshots"):
                self.delete(f"/appScreenshots/{old['id']}")
            print(f"{display_type}: cleared, uploading {len(files)}")
            for name in files:
                self.upload_screenshot(set_id, os.path.join(path, name))
            self.wait_for_screenshots(set_id)

    def upload_screenshot(self, set_id, file_path):
        with open(file_path, "rb") as handle:
            data = handle.read()
        reservation = self.post("/appScreenshots", {"data": {
            "type": "appScreenshots",
            "attributes": {"fileName": os.path.basename(file_path), "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}},
        }})["data"]
        for op in reservation["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers=headers)
            with urllib.request.urlopen(req, timeout=300) as resp:
                resp.read()
        self.patch(f"/appScreenshots/{reservation['id']}", {"data": {
            "type": "appScreenshots", "id": reservation["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
        }})
        print(f"  uploaded {os.path.basename(file_path)}")

    def wait_for_screenshots(self, set_id, timeout=600):
        deadline = time.time() + timeout
        while time.time() < deadline:
            states = [s["attributes"]["assetDeliveryState"]["state"]
                      for s in self.get_all(f"/appScreenshotSets/{set_id}/appScreenshots")]
            if all(state == "COMPLETE" for state in states):
                return
            if any(state == "FAILED" for state in states):
                raise SystemExit(f"a screenshot failed processing in set {set_id}: {states}")
            time.sleep(5)
        raise SystemExit("screenshots did not finish processing in time")

    def submit(self, app_id, version_id):
        submission = self.post("/reviewSubmissions", {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }})["data"]
        self.post("/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
            },
        }})
        self.patch(f"/reviewSubmissions/{submission['id']}", {"data": {
            "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True},
        }})
        print(f"submitted for review ({submission['id']})")

    # -- feeds -------------------------------------------------------------

    def status(self, app_id):
        out = {"versions": [], "submissions": []}
        for version in self.versions(app_id, limit=4):
            attrs = version["attributes"]
            out["versions"].append({"version": attrs["versionString"], "state": attrs["appVersionState"],
                                    "created": attrs["createdDate"]})
        subs = self.get(f"/apps/{app_id}/reviewSubmissions",
                        **{"filter[platform]": "IOS", "limit": 5,
                           "fields[reviewSubmissions]": "state,submittedDate,platform"})["data"]
        for sub in subs:
            out["submissions"].append({"state": sub["attributes"]["state"],
                                       "submitted": sub["attributes"].get("submittedDate")})
        return out

    def analytics(self, app_id, out_dir, categories=("APP_USAGE", "APP_STORE_ENGAGEMENT", "PERFORMANCE")):
        """Ensures an ONGOING report request exists and downloads every daily
        instance not already on disk. Returns the list of new files."""
        requests = self.get(f"/apps/{app_id}/analyticsReportRequests",
                            **{"filter[accessType]": "ONGOING"})["data"]
        if requests:
            request = requests[0]
        else:
            request = self.post("/analyticsReportRequests", {"data": {
                "type": "analyticsReportRequests",
                "attributes": {"accessType": "ONGOING"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }})["data"]
            print("created ongoing analytics report request; data arrives within a few days")
        os.makedirs(out_dir, exist_ok=True)
        new_files = []
        for category in categories:
            reports = self.get_all(f"/analyticsReportRequests/{request['id']}/reports",
                                   **{"filter[category]": category})
            for report in reports:
                name = re.sub(r"[^A-Za-z0-9]+", "-", report["attributes"]["name"]).strip("-")
                instances = self.get_all(f"/analyticsReports/{report['id']}/instances",
                                         **{"filter[granularity]": "DAILY"})
                for instance in instances:
                    date = instance["attributes"]["processingDate"]
                    target = os.path.join(out_dir, f"{name}-{date}.csv")
                    if os.path.exists(target):
                        continue
                    segments = self.get_all(f"/analyticsReportInstances/{instance['id']}/segments")
                    with open(target, "w") as handle:
                        for segment in segments:
                            blob = self.request("GET", segment["attributes"]["url"], raw=True)
                            handle.write(gzip.decompress(blob).decode())
                    new_files.append(target)
        return new_files


# -- metadata files ------------------------------------------------------------

def sections(markdown):
    """Maps a metadata.md heading (its first word run, lower-cased) to the
    text under it. Headings look like '## Description (max 4000)'."""
    out = {}
    current = None
    for line in markdown.splitlines():
        if line.startswith("## "):
            title = re.sub(r"\(.*", "", line[3:]).strip().lower()
            current = title
            out[current] = []
        elif line.startswith("---") and current:
            current = None
        elif current is not None:
            out[current].append(line)
    return {k: "\n".join(v).strip() for k, v in out.items()}


def copy_from(metadata_path, whatsnew_path):
    with open(metadata_path) as handle:
        parts = sections(handle.read())
    with open(whatsnew_path) as handle:
        whats_new = handle.read().strip()
    notes = parts.get("app review notes", "")
    return {
        "promotionalText": parts.get("promotional text", ""),
        "keywords": parts.get("keywords", ""),
        "description": parts.get("description", ""),
        "whatsNew": whats_new,
    }, notes


# -- commands ------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("apps")

    p = sub.add_parser("builds")
    p.add_argument("--app", required=True)

    p = sub.add_parser("status")
    p.add_argument("--app", required=True)
    p.add_argument("--json", action="store_true")

    p = sub.add_parser("release")
    p.add_argument("--app", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--build", required=True, help="CURRENT_PROJECT_VERSION of the uploaded build")
    p.add_argument("--metadata", required=True)
    p.add_argument("--whatsnew", required=True)
    p.add_argument("--screenshots", help="folder with *.png and ipad/*.png; omit to keep the current sets")
    p.add_argument("--contact", default="~/.config/appstoreconnect/contact.json",
                   help="json with contactFirstName, contactLastName, contactEmail, contactPhone")
    p.add_argument("--submit", action="store_true")

    p = sub.add_parser("analytics")
    p.add_argument("--app", required=True)
    p.add_argument("--out", required=True)

    args = parser.parse_args(argv)
    asc = ASC()

    if args.command == "apps":
        for app in asc.get("/apps")["data"]:
            print(app["id"], app["attributes"]["bundleId"], app["attributes"]["name"])
        return

    app = asc.app(args.app)
    app_id = app["id"]

    if args.command == "builds":
        page = asc.builds(app_id)
        pre = {inc["id"]: inc["attributes"]["version"] for inc in page.get("included", [])}
        for build in page["data"]:
            attrs = build["attributes"]
            pre_id = (build["relationships"]["preReleaseVersion"]["data"] or {}).get("id")
            print(f"{pre.get(pre_id, '?')} ({attrs['version']})  {attrs['processingState']}  {attrs['uploadedDate']}")
        return

    if args.command == "status":
        report = asc.status(app_id)
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            for v in report["versions"]:
                print(f"{v['version']}  {v['state']}  created {v['created']}")
            for s in report["submissions"]:
                print(f"submission {s['state']}  {s['submitted']}")
        return

    if args.command == "analytics":
        new = asc.analytics(app_id, os.path.expanduser(args.out))
        print(f"{len(new)} new report files")
        for path in new:
            print("  " + path)
        return

    if args.command == "release":
        copy, notes = copy_from(args.metadata, args.whatsnew)
        contact = {}
        contact_path = os.path.expanduser(args.contact)
        if os.path.exists(contact_path):
            with open(contact_path) as handle:
                contact = json.load(handle)
        version = asc.ensure_version(app_id, args.version)
        loc = asc.localization(version["id"])
        asc.set_copy(loc["id"], copy)
        if notes:
            asc.set_review_notes(version["id"], notes, contact)
        if args.screenshots:
            asc.replace_screenshots(loc["id"], args.screenshots)
        build = asc.find_build(app_id, args.version, args.build)
        asc.attach_build(version["id"], build["id"])
        if args.submit:
            asc.submit(app_id, version["id"])
        else:
            print("ready; rerun with --submit to submit for review")


if __name__ == "__main__":
    main()
