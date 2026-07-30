#!/usr/bin/env python3
"""Backfill coordinates and opening hours onto live LocalHive listings.

tool/seed_providers.py never wrote lat/lng/availableFrom/availableTo, so every
Firestore listing sits at 0,0 with no stated hours. That makes "food trucks
near me" and "open now" meaningless — Olivia cannot rank by distance and cannot
tell whether anywhere is open.

This fills them in around Edison / Iselin, NJ, matching the coordinates the
built-in demo catalog already uses.

Runs as admin@localhive.app, the only account the rules let update listings.

Run:  python3 tool/seed_provider_geo.py
"""
import json
import os
import sys
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

# Known spots, by listing id where we have one from the demo catalog.
BY_ID = {
    "ft1": (40.5629, -74.3390, "11 AM", "9 PM"),
    "ft2": (40.5754, -74.3223, "11 AM", "10 PM"),
    "ft3": (40.5478, -74.3355, "12 PM", "8 PM"),
}

# Fallback spread around Oak Tree Road, Edison, so listings without a known
# location still land somewhere plausible and distinct rather than at 0,0.
AREA = [
    (40.5512, -74.3301),
    (40.5687, -74.3412),
    (40.5601, -74.3155),
    (40.5772, -74.3488),
    (40.5445, -74.3238),
    (40.5834, -74.3301),
    (40.5566, -74.3520),
]

HOURS_BY_CATEGORY = {
    "home_service": ("8 AM", "6 PM"),
    "indian_store": ("9 AM", "9 PM"),
    "food_truck": ("11 AM", "9 PM"),
}


def http(method, url, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        url, data=json.dumps(body).encode() if body is not None else None,
        headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def sign_in(name):
    st, d = http("POST", "https://identitytoolkit.googleapis.com/v1/"
                 f"accounts:signInWithPassword?key={API_KEY}",
                 {"email": f"{name}@localhive.app", "password": f"{name}@123",
                  "returnSecureToken": True})
    if st != 200:
        sys.exit(f"cannot sign in {name}@localhive.app: {d}")
    return d["idToken"]


def field(doc, key):
    v = doc.get("fields", {}).get(key, {})
    return next(iter(v.values()), None)


token = sign_in("admin")
st, d = http("GET", f"{FS}/providers?pageSize=300", token=token)
if st != 200:
    sys.exit(f"cannot list providers: {d}")

changed = skipped = failed = 0
spare = list(AREA)

for doc in d.get("documents", []):
    if field(doc, "live") is not True:
        continue
    pid = doc["name"].split("/")[-1]
    category = field(doc, "category") or ""
    name = field(doc, "name") or pid

    have_lat = float(field(doc, "lat") or 0)
    have_from = field(doc, "availableFrom") or ""
    if have_lat != 0 and have_from:
        skipped += 1
        continue

    if pid in BY_ID:
        lat, lng, opens, closes = BY_ID[pid]
    else:
        lat, lng = spare.pop(0) if spare else AREA[0]
        if not spare:
            spare = list(AREA)
        opens, closes = HOURS_BY_CATEGORY.get(category, ("9 AM", "6 PM"))

    st, r = http(
        "PATCH",
        f"{FS}/providers/{pid}"
        "?updateMask.fieldPaths=lat"
        "&updateMask.fieldPaths=lng"
        "&updateMask.fieldPaths=availableFrom"
        "&updateMask.fieldPaths=availableTo",
        {"fields": {
            "lat": {"doubleValue": lat},
            "lng": {"doubleValue": lng},
            "availableFrom": {"stringValue": opens},
            "availableTo": {"stringValue": closes},
        }},
        token=token)
    if st == 200:
        changed += 1
        print(f"  {category:13} {name:28} {lat:.4f},{lng:.4f}  {opens}–{closes}")
    else:
        failed += 1
        print(f"  FAILED {name}: {st} {r}")

print(f"\n{changed} updated, {skipped} already had geo, {failed} failed")
