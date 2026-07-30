#!/usr/bin/env python3
"""Put the demo accounts into a state where every persona has work to do.

Creates, as the demo customer:
  - a home-service booking waiting for Maria to accept
  - a food-truck pickup order waiting for the truck owner
  - a grocery delivery order, marked Ready, posted to the delivery board with
    the courier already partway along a route so the tracking map has data

Run:  python3 tool/seed_demo_scenario.py
"""
import json
import os
import random
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
PROJECT = "localhivelocalhive"
FS = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
      "/databases/(default)/documents")

# Set DEMO_PHONE to a number the Twilio trial can reach (a Verified Caller ID)
# to see the customer-side SMS/WhatsApp messages land during a demo. Left blank
# the flows still work; the dispatcher just logs "no valid phone on record".
DEMO_PHONE = os.environ.get("DEMO_PHONE", "")

DEMO = {
    "customer": ("demo@localhive.app", "demo@123"),
    "maria": ("maria@localhive.app", "maria@123"),
    "truck": ("truck@localhive.app", "truck@123"),
    "store": ("store@localhive.app", "store@123"),
    "delivery": ("delivery@localhive.app", "delivery@123"),
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


def sign_in(email, password):
    st, d = http("POST", "https://identitytoolkit.googleapis.com/v1/"
                 f"accounts:signInWithPassword?key={API_KEY}",
                 {"email": email, "password": password,
                  "returnSecureToken": True})
    if st != 200:
        sys.exit(f"could not sign in {email}: {d}")
    return d["idToken"], d["localId"]


def enc(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    return {"stringValue": str(v)}


def doc(fields):
    return {"fields": {k: enc(v) for k, v in fields.items()}}


def field(d, name):
    v = d.get("fields", {}).get(name, {})
    return next(iter(v.values()), None)


tokens = {k: sign_in(*v) for k, v in DEMO.items()}
cust, cust_uid = tokens["customer"]
print(f"demo customer uid: {cust_uid[:8]}…")


def owner_of(listing_id):
    """Find who owns a live listing so bookings denormalize correctly."""
    st, d = http("GET", f"{FS}/providers/{listing_id}", token=cust)
    return field(d, "ownerId") if st == 200 else None


# Pick one live listing per category from the real catalog.
st, d = http("GET", f"{FS}/providers?pageSize=300", token=cust)
picks = {}
for p in d.get("documents", []):
    if field(p, "live") is not True:
        continue
    cat = field(p, "category")
    if cat and cat not in picks:
        picks[cat] = {
            "id": p["name"].split("/")[-1],
            "name": field(p, "name"),
            "ownerId": field(p, "ownerId") or "",
        }
print("catalog picks:", {k: v["name"] for k, v in picks.items()})

created = []


def make_booking(cat, detail, amount, status, fulfillment, address="",
                 pickup_eta="", otp=""):
    p = picks.get(cat)
    if not p:
        print(f"  (skipped {cat} — no live listing)")
        return None
    st, d = http("POST", f"{FS}/bookings", doc({
        "userId": cust_uid,
        "providerId": p["id"],
        "providerOwnerId": p["ownerId"],
        "providerName": p["name"],
        "category": cat,
        "detail": detail,
        "status": status,
        "amount": amount,
        "address": address,
        "customerName": "Demo Customer",
        "customerPhone": DEMO_PHONE,
        "customerEmail": DEMO["customer"][0],
        "fulfillment": fulfillment,
        "pickupEta": pickup_eta,
        "otp": otp,
    }), token=cust)
    if st != 200:
        print(f"  FAILED {cat}: {d}")
        return None
    bid = d["name"].split("/")[-1]
    created.append((cat, p["name"], bid, status))
    print(f"  {cat}: {p['name']} → {status} ({bid[:8]}…)")
    return bid


print("\ncreating work for each persona:")
make_booking("home_service", "3-hour deep clean · Sat 10:00", 96.0,
             "Requested", "", address="45 Oak Tree Rd, Edison, NJ 08820")
make_booking("food_truck", "2 × Chicken Biryani", 27.5, "Placed", "pickup",
             pickup_eta="In 20 min")

otp = str(1000 + random.randint(0, 8999))
deliv_id = make_booking("indian_store", "Groceries · 6 items", 54.2, "Ready",
                        "delivery", address="120 Oak Tree Rd, Iselin, NJ 08830",
                        otp=otp)

# Post it to the delivery board as the store owner would, then have the
# delivery partner claim it and start moving.
if deliv_id:
    store, store_uid = tokens["store"]
    st, _ = http("POST", f"{FS}/delivery_jobs?documentId={deliv_id}", doc({
        "storeName": picks["indian_store"]["name"],
        "orderDetail": "Groceries · 6 items",
        "dropAddress": "120 Oak Tree Rd, Iselin, NJ 08830",
        "fee": 5.49,
        "status": "Open",
        "deliveryPersonId": "",
    }), token=cust)
    print(f"  delivery board: job posted ({'ok' if st == 200 else st})")

    part, part_uid = tokens["delivery"]
    st, _ = http("PATCH", f"{FS}/delivery_jobs/{deliv_id}"
                 "?updateMask.fieldPaths=deliveryPersonId"
                 "&updateMask.fieldPaths=status",
                 doc({"deliveryPersonId": part_uid, "status": "PickedUp"}),
                 token=part)
    print(f"  delivery board: partner claimed + picked up "
          f"({'ok' if st == 200 else st})")

    st, _ = http("PATCH", f"{FS}/bookings/{deliv_id}"
                 "?updateMask.fieldPaths=status",
                 doc({"status": "Out for delivery"}), token=part)
    print(f"  order: Out for delivery ({'ok' if st == 200 else st})")

    # Courier a few blocks away from the drop-off so the map has a live pin.
    st, _ = http("PATCH", f"{FS}/delivery_jobs/{deliv_id}"
                 "?updateMask.fieldPaths=courierLat"
                 "&updateMask.fieldPaths=courierLng"
                 "&updateMask.fieldPaths=courierSpeedMps",
                 doc({"courierLat": 40.5651, "courierLng": -74.3229,
                      "courierSpeedMps": 7.2}), token=part)
    print(f"  tracking: courier pin published ({'ok' if st == 200 else st})")
    print(f"\n  delivery OTP for this order: {otp}")

print("\nDone. Sign in with any demo account to see its work.")
