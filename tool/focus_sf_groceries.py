#!/usr/bin/env python3
"""Retire the nationwide seed and leave only San Francisco groceries live.

The 1,098 listings seeded across every US city were never real businesses:
nobody at those addresses agreed to be listed, and an order placed against
one goes nowhere. That is worse than an empty marketplace — it teaches the
first customer the app does not work.

This unpublishes every seeded listing (live: false, keeping the row so the
history is not lost) except grocery stores in San Francisco, which is the
one market and one vertical LocalHive is now focused on.

Run:  python3 tool/focus_sf_groceries.py [--dry-run]
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


def http(method, url, body=None, token=None, tries=6):
    """Firestore REST returns 429 under sustained load; back off and retry."""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    delay = 4
    for attempt in range(tries):
        req = urllib.request.Request(
            url, data=json.dumps(body).encode() if body is not None else None,
            headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            payload = json.loads(e.read().decode() or "{}")
            if e.code == 429 and attempt < tries - 1:
                time.sleep(delay)
                delay = min(delay * 2, 60)
                continue
            return e.code, payload
    return 429, {}


def sign_in(name):
    st, d = http("POST", "https://identitytoolkit.googleapis.com/v1/"
                 f"accounts:signInWithPassword?key={API_KEY}",
                 {"email": f"{name}@localhive.app", "password": f"{name}@123",
                  "returnSecureToken": True})
    if st != 200:
        sys.exit(f"cannot sign in {name}@localhive.app: {d}")
    return d["idToken"]


def field(doc, key):
    return next(iter(doc.get("fields", {}).get(key, {}).values()), None)


def is_sf(city):
    c = (city or "").lower()
    return "san francisco" in c or c.strip() in ("sf, ca", "sf")


admin = sign_in("admin")

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
print(f"{len(docs)} listings in the catalog")

kept = retired = failed = 0
for p in docs:
    pid = p["name"].split("/")[-1]
    live = field(p, "live")
    category = field(p, "category")
    city = field(p, "city")
    name = field(p, "name")
    # Keep live: San Francisco grocery stores only.
    keep = is_sf(city) and category == "indian_store"
    if keep:
        kept += 1
        if live is not True and not DRY:
            http("PATCH", f"{FS}/providers/{pid}?updateMask.fieldPaths=live",
                 {"fields": {"live": {"booleanValue": True}}}, token=admin)
        print(f"  KEEP  {name} — {city}")
        continue
    if live is not True:
        continue  # already unpublished, nothing to do
    if DRY:
        retired += 1
        continue
    st, r = http("PATCH", f"{FS}/providers/{pid}?updateMask.fieldPaths=live",
                 {"fields": {"live": {"booleanValue": False}}}, token=admin)
    if st == 200:
        retired += 1
        time.sleep(0.2)
    else:
        failed += 1
        print(f"  FAILED {name}: {st} {r}")

print(f"\n{kept} SF grocery listings live, {retired} retired, {failed} failed"
      f"{' (dry run — nothing written)' if DRY else ''}")
