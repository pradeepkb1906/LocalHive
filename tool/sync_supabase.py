#!/usr/bin/env python3
"""Copy the live store catalog from Firestore into the Supabase standby.

Firestore stays the system of record; this is a one-way push so the app has
something to read when Firestore cannot be read at all. Run it after any
catalog change — approving a store, editing hours — or on a schedule.

Needs, in .secrets/supabase.env:
    SUPABASE_URL=https://xxxx.supabase.co
    SUPABASE_SERVICE_KEY=<the service_role key, NOT the anon key>

The service_role key bypasses row level security, which is why it lives in
.secrets/ (gitignored) and never goes anywhere near the app bundle.

Run:  python3 tool/sync_supabase.py [--dry-run]
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY = "--dry-run" in sys.argv


def load_env(path, required):
    env = {}
    full = os.path.join(ROOT, ".secrets", path)
    if not os.path.exists(full):
        sys.exit(f"missing {full} — see the docstring in this file")
    with open(full) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    for key in required:
        if not env.get(key):
            sys.exit(f"{path} is missing {key}")
    return env


fb = load_env("twilio.env", ["FIREBASE_API_KEY"])
sb = load_env("supabase.env", ["SUPABASE_URL", "SUPABASE_SERVICE_KEY"])
FS = ("https://firestore.googleapis.com/v1/projects/localhivelocalhive"
      "/databases/(default)/documents")


def http(method, url, body=None, headers=None, tries=4):
    headers = dict(headers or {})
    headers.setdefault("Content-Type", "application/json")
    delay = 3
    for attempt in range(tries):
        req = urllib.request.Request(
            url, data=json.dumps(body).encode() if body is not None else None,
            headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read().decode()
                return r.status, (json.loads(raw) if raw.strip() else {})
        except urllib.error.HTTPError as e:
            payload = e.read().decode()
            if e.code == 429 and attempt < tries - 1:
                time.sleep(delay)
                delay = min(delay * 2, 30)
                continue
            return e.code, payload
    return 429, ""


st, d = http("POST", "https://identitytoolkit.googleapis.com/v1/"
             f"accounts:signInWithPassword?key={fb['FIREBASE_API_KEY']}",
             {"email": "admin@localhive.app", "password": "admin@123",
              "returnSecureToken": True})
if st != 200:
    sys.exit(f"cannot sign in to Firebase as admin: {d}")
admin = d["idToken"]


def field(doc, key, default=None):
    return next(iter(doc.get("fields", {}).get(key, {}).values()), default)


docs, page = [], ""
while True:
    st, d = http("GET", f"{FS}/providers?pageSize=300&pageToken={page}",
                 headers={"Authorization": f"Bearer {admin}"})
    if st != 200:
        sys.exit(f"cannot read the Firestore catalog: {st} {d}")
    docs.extend(d.get("documents", []))
    page = d.get("nextPageToken", "")
    if not page:
        break

rows = []
for p in docs:
    if field(p, "live") is not True:
        continue
    rows.append({
        "id": p["name"].split("/")[-1],
        "name": field(p, "name", "") or "",
        "category": field(p, "category", "") or "",
        "subtitle": field(p, "subtitle", "") or "",
        "rating": float(field(p, "rating", 0) or 0),
        "reviews": int(field(p, "reviews", 0) or 0),
        "hourly_rate": float(field(p, "hourlyRate", 0) or 0),
        "city": field(p, "city", "") or "",
        "verified": field(p, "verified", False) is True,
        "emoji": field(p, "emoji", "") or "",
        "lat": float(field(p, "lat", 0) or 0),
        "lng": float(field(p, "lng", 0) or 0),
        "available_from": field(p, "availableFrom", "") or "",
        "available_to": field(p, "availableTo", "") or "",
        "live": True,
    })

print(f"{len(docs)} listings in Firestore, {len(rows)} live to mirror")
for r in rows:
    print(f"  {r['name']} — {r['category']} — {r['city']}")

if DRY:
    print("\ndry run — nothing written to Supabase")
    sys.exit(0)

if not rows:
    print("\nnothing live to mirror; leaving the standby untouched so it "
          "keeps serving the last good catalog")
    sys.exit(0)

st, r = http(
    "POST", f"{sb['SUPABASE_URL']}/rest/v1/providers?on_conflict=id", rows,
    headers={
        "apikey": sb["SUPABASE_SERVICE_KEY"],
        "Authorization": f"Bearer {sb['SUPABASE_SERVICE_KEY']}",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    })
if st not in (200, 201, 204):
    sys.exit(f"Supabase upsert failed: {st} {str(r)[:300]}")
print(f"\nmirrored {len(rows)} listings into Supabase")
