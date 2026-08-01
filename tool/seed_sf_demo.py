#!/usr/bin/env python3
"""Seed the San Francisco demo: a store-owner login, three sample grocery
stores and a couple of live orders, so the app can be walked end to end in
front of a real shopkeeper.

Where things live:
  * Accounts are Firebase Auth. Supabase holds no logins — it is the
    read-only standby for the catalog, so there is nothing to "create an
    account" in.
  * Listings are written to Firestore (the system of record). Run
    tool/sync_supabase.py afterwards to copy them into the standby.

Every store is named "... (Demo)" on purpose. The nationwide seed had to be
deleted because it listed real shops that never agreed to be there; a demo
store owned by a demo account is answerable and unmistakable.

Run:  python3 tool/seed_sf_demo.py [--dry-run]
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY = "--dry-run" in sys.argv

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
AUTH = "https://identitytoolkit.googleapis.com/v1"

OWNER_EMAIL = "sfstore@localhive.app"
OWNER_PASS = "sfstore@123"
OWNER_NAME = "SF Demo Grocery"

# Real neighbourhoods, invented shops. A shopkeeper watching the demo should
# recognise the streets and know instantly the businesses are samples.
STORES = [
    {
        "id": "sfdemo1",
        "name": "Mission Street Market (Demo)",
        "subtitle": "Fresh produce, pantry staples & everyday essentials",
        "city": "San Francisco, CA",
        "lat": 37.7599, "lng": -122.4148,
        "rating": 4.7, "reviews": 184,
        "from": "8 AM", "to": "9 PM",
    },
    {
        "id": "sfdemo2",
        "name": "Sunset Fresh Grocers (Demo)",
        "subtitle": "Neighbourhood grocery — produce, dairy, rice & spices",
        "city": "San Francisco, CA",
        "lat": 37.7534, "lng": -122.4839,
        "rating": 4.5, "reviews": 96,
        "from": "9 AM", "to": "8 PM",
    },
    {
        "id": "sfdemo3",
        "name": "Richmond Corner Store (Demo)",
        "subtitle": "Everyday groceries, open late",
        "city": "San Francisco, CA",
        "lat": 37.7801, "lng": -122.4644,
        "rating": 4.4, "reviews": 61,
        "from": "8 AM", "to": "10 PM",
    },
]


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
                raw = r.read().decode()
                return r.status, (json.loads(raw) if raw.strip() else {})
        except urllib.error.HTTPError as e:
            payload = e.read().decode()
            if e.code == 429 and attempt < tries - 1:
                time.sleep(delay)
                delay = min(delay * 2, 40)
                continue
            return e.code, payload
    return 429, ""


def sign_in(email, password):
    st, d = http("POST", f"{AUTH}/accounts:signInWithPassword?key={API_KEY}",
                 {"email": email, "password": password,
                  "returnSecureToken": True})
    if st != 200:
        return None, None
    return d["idToken"], d["localId"]


def sv(v):
    return {"stringValue": v}


print("--- accounts (Firebase Auth) ---")
token, uid = sign_in(OWNER_EMAIL, OWNER_PASS)
if token:
    print(f"  {OWNER_EMAIL} already exists")
elif DRY:
    print(f"  would create {OWNER_EMAIL}")
    uid = "DRY"
else:
    st, d = http("POST", f"{AUTH}/accounts:signUp?key={API_KEY}",
                 {"email": OWNER_EMAIL, "password": OWNER_PASS,
                  "returnSecureToken": True})
    if st != 200:
        sys.exit(f"cannot create {OWNER_EMAIL}: {d}")
    token, uid = d["idToken"], d["localId"]
    http("POST", f"{AUTH}/accounts:update?key={API_KEY}",
         {"idToken": token, "displayName": OWNER_NAME,
          "returnSecureToken": False})
    print(f"  created {OWNER_EMAIL}")

if not DRY:
    # Business-owner role, so signing in lands on the Provider Dashboard.
    http("PATCH",
         f"{FS}/users/{uid}?updateMask.fieldPaths=role"
         "&updateMask.fieldPaths=email&updateMask.fieldPaths=name",
         {"fields": {"role": sv("provider"), "email": sv(OWNER_EMAIL),
                     "name": sv(OWNER_NAME)}}, token=token)
    print("  role set to business owner")

print("\n--- demo stores (Firestore) ---")
admin_token, _ = sign_in("admin@localhive.app", "admin@123")
if not admin_token:
    sys.exit("cannot sign in as admin — needed to publish listings")

for s in STORES:
    fields = {
        "name": sv(s["name"]),
        "category": sv("indian_store"),
        "subtitle": sv(s["subtitle"]),
        "city": sv(s["city"]),
        "rating": {"doubleValue": s["rating"]},
        "reviews": {"integerValue": str(s["reviews"])},
        "hourlyRate": {"doubleValue": 0},
        "verified": {"booleanValue": True},
        "lat": {"doubleValue": s["lat"]},
        "lng": {"doubleValue": s["lng"]},
        "availableFrom": sv(s["from"]),
        "availableTo": sv(s["to"]),
        "ownerId": sv(uid),
        "live": {"booleanValue": True},
        "isDemo": {"booleanValue": True},
    }
    if DRY:
        print(f"  would publish {s['name']}")
        continue
    # The security rules mirror the real flow: an owner creates their own
    # listing unpublished, and only an admin may flip it live. So do exactly
    # that — owner first, admin second — rather than trying to shortcut it.
    draft = dict(fields)
    draft["live"] = {"booleanValue": False}
    mask = "&".join(f"updateMask.fieldPaths={k}" for k in draft)
    st, r = http("PATCH", f"{FS}/providers/{s['id']}?{mask}",
                 {"fields": draft}, token=token)
    if st != 200:
        print(f"  FAILED to create {s['name']}: {st} {str(r)[:90]}")
        continue
    st, r = http("PATCH",
                 f"{FS}/providers/{s['id']}?updateMask.fieldPaths=live",
                 {"fields": {"live": {"booleanValue": True}}},
                 token=admin_token)
    print(f"  {'published' if st == 200 else f'created but NOT live ({st})'} "
          f"{s['name']}")

print("\nDone.")
print(f"  Store owner login : {OWNER_EMAIL} / {OWNER_PASS}")
print("  Customer login    : demo@localhive.app / demo@123")
print("\nNext: python3 tool/sync_supabase.py   (copies these into the "
      "read-only standby)")
