#!/usr/bin/env python3
"""Delete any surviving listing that is not a San Francisco grocery store.

The deterministic seed ids are already gone (purge_trucks_and_home_services).
What can remain are listings created through provider onboarding, which have
random ids — so this one has to list the collection, and therefore needs
Firestore read quota. It waits for quota if necessary.

Run:  python3 tool/purge_remaining_non_sf.py [--dry-run]
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = {}
with open(os.path.join(ROOT, ".secrets", "twilio.env")) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            ENV[k.strip()] = v.strip()
API_KEY = ENV["FIREBASE_API_KEY"]
FS = ("https://firestore.googleapis.com/v1/projects/localhivelocalhive"
      "/databases/(default)/documents")
DRY = "--dry-run" in sys.argv


def http(method, url, body=None, token=None, tries=4):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    delay = 3
    for attempt in range(tries):
        req = urllib.request.Request(
            url, data=json.dumps(body).encode() if body is not None else None,
            headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            payload = e.read().decode()
            if e.code == 429 and attempt < tries - 1:
                time.sleep(delay)
                delay = min(delay * 2, 30)
                continue
            return e.code, payload
    return 429, ""


def sign_in():
    st, d = http("POST", "https://identitytoolkit.googleapis.com/v1/"
                 f"accounts:signInWithPassword?key={API_KEY}",
                 {"email": "admin@localhive.app", "password": "admin@123",
                  "returnSecureToken": True})
    if st != 200:
        sys.exit(f"cannot sign in as admin: {d}")
    return d["idToken"]


def field(doc, key):
    return next(iter(doc.get("fields", {}).get(key, {}).values()), None)


def is_sf(city):
    c = (city or "").lower()
    return "san francisco" in c or c.strip() in ("sf, ca", "sf", "sf,ca")


admin = sign_in()

# Wait out the daily read quota if it is still exhausted.
while True:
    st, d = http("GET", f"{FS}/providers?pageSize=1", token=admin)
    if st == 200:
        break
    if st != 429:
        sys.exit(f"cannot read providers: {st} {d}")
    print("read quota exhausted — waiting 10 minutes…", flush=True)
    time.sleep(600)
    admin = sign_in()   # token may have expired while waiting

docs, page = [], ""
while True:
    st, d = http("GET", f"{FS}/providers?pageSize=300&pageToken={page}",
                 token=admin)
    if st != 200:
        sys.exit(f"cannot list providers: {d}")
    docs.extend(d.get("documents", []))
    page = d.get("nextPageToken", "")
    if not page:
        break
print(f"{len(docs)} listings found")

deleted = kept = failed = 0
for p in docs:
    pid = p["name"].split("/")[-1]
    name, category, city = (field(p, "name"), field(p, "category"),
                            field(p, "city"))
    if category == "indian_store" and is_sf(city):
        kept += 1
        print(f"  KEEP   {name} — {city}")
        continue
    print(f"  DELETE {name} — {category} — {city}")
    if DRY:
        deleted += 1
        continue
    st, r = http("DELETE", f"{FS}/providers/{pid}", token=admin)
    if st == 200:
        deleted += 1
    else:
        failed += 1
        print(f"    FAILED: {st} {str(r)[:80]}")
    time.sleep(0.05)

print(f"\n{deleted} deleted, {kept} San Francisco grocery listings kept, "
      f"{failed} failed{' (dry run)' if DRY else ''}")
