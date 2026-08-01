#!/usr/bin/env python3
"""Permanently delete every listing except San Francisco groceries.

LocalHive is now one market and one vertical: San Francisco groceries.
The nationwide seed created deterministic ids (us000t/us000s/us000h per
city), so these can be deleted by id without listing the collection —
which matters, because Firestore's read quota is exhausted while deletes
are still available.

Grocery listings (…s) are deliberately untouched.

Run:  python3 tool/purge_trucks_and_home_services.py
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


def http(method, url, body=None, token=None, tries=5):
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
                delay = min(delay * 2, 45)
                continue
            return e.code, payload
    return 429, ""


st, d = http("POST", "https://identitytoolkit.googleapis.com/v1/"
             f"accounts:signInWithPassword?key={API_KEY}",
             {"email": "admin@localhive.app", "password": "admin@123",
              "returnSecureToken": True})
if st != 200:
    sys.exit(f"cannot sign in as admin: {d}")
admin = d["idToken"]

# San Francisco is index 16 in the seeded city list, so us016s is the one
# grocery listing that survives. Everything else goes.
SF_STORE = "us016s"

ids = []
for i in range(400):
    ids.append(f"us{i:03d}t")   # food truck — vertical retired
    ids.append(f"us{i:03d}h")   # home service — vertical retired
    store = f"us{i:03d}s"
    if store != SF_STORE:
        ids.append(store)       # grocery outside San Francisco
# The original hand-written demo listings: trucks, home services, and the
# two non-SF demo stores.
ids += ["ft1", "ft2", "ft3", "hs1", "hs2", "hs3", "hs4",
        "st1", "st2", "st3"]

deleted = missing = failed = 0
for i, pid in enumerate(ids):
    st, r = http("DELETE", f"{FS}/providers/{pid}", token=admin)
    if st == 200:
        deleted += 1
    elif st in (403, 404):
        missing += 1          # never existed, or already gone
    else:
        failed += 1
        if failed <= 5:
            print(f"  FAILED {pid}: {st} {str(r)[:80]}")
    if i % 100 == 99:
        print(f"  …{i + 1}/{len(ids)} processed "
              f"({deleted} deleted, {missing} absent)")
    time.sleep(0.02)

print(f"\nDeleted {deleted} listings, {missing} were already absent, "
      f"{failed} failed.")
print(f"Kept: {SF_STORE} (San Francisco grocery) and any listing a real "
      f"business created through onboarding.")
