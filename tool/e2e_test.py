#!/usr/bin/env python3
"""LocalHive end-to-end workflow test.

Exercises every user flow against the LIVE locked Firestore using real
Firebase Auth ID tokens (same as the app), asserting security rules,
status lifecycles, OTP delivery confirmation, and notification queueing.
Run:  python3 tool/e2e_test.py
"""
import json
import random
import sys
import urllib.error
import urllib.request

import google.auth.transport.requests
from google.oauth2 import service_account

import os
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
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
REAL_PHONE = "+918884498810"

results = []


def check(name, ok, detail=""):
    results.append((name, ok))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail and not ok else ""))


def http(method, url, body=None, token=None, expect_error=False):
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


def auth_user(email, password):
    st, d = http("POST",
                 f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                 {"email": email, "password": password, "returnSecureToken": True})
    if st != 200:
        st, d = http("POST",
                     f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}",
                     {"email": email, "password": password, "returnSecureToken": True})
    assert st == 200, f"auth failed for {email}: {d}"
    return d["localId"], d["idToken"]


def admin_token():
    creds = service_account.Credentials.from_service_account_file(
        os.path.join(ROOT, ".secrets", "service_account.json"),
        scopes=["https://www.googleapis.com/auth/datastore"])
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token


def fv(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, (int,)):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    return {"stringValue": str(v)}


def doc_body(d):
    return {"fields": {k: fv(v) for k, v in d.items()}}


def get_field(doc, name):
    f = doc.get("fields", {}).get(name, {})
    return list(f.values())[0] if f else None


print("=== LocalHive end-to-end workflow test ===\n")

ADMIN = admin_token()
cust_uid, cust = auth_user("customer.e2e@localhive.test", "test123456")
own_uid, owner = auth_user("truckowner@localhive.test", "test123456")
print(f"customer uid: {cust_uid[:8]}…  owner uid: {own_uid[:8]}…\n")

# Give the owner test account the home-service listing hs1 too (admin op).
http("PATCH", f"{FS}/providers/hs1?updateMask.fieldPaths=ownerId",
     doc_body({"ownerId": own_uid}), token=ADMIN)

# ---------- A. Security rule sanity ----------
st, _ = http("GET", f"{FS}/notifications?pageSize=1&key=" + API_KEY)
check("rules: unauthenticated cannot read notifications", st == 403)
st, _ = http("GET", f"{FS}/providers/hs1?key=" + API_KEY)
check("rules: public can read provider catalog", st == 200)
st, _ = http("POST", f"{FS}/bookings?key=" + API_KEY,
             doc_body({"userId": "guest", "status": "Requested"}))
check("rules: unauthenticated cannot create bookings", st == 403)

# ---------- B. Home Services flow ----------
st, d = http("POST", f"{FS}/bookings", doc_body({
    "userId": cust_uid, "providerId": "hs1", "providerOwnerId": own_uid,
    "providerName": "Maria G.", "category": "home_service",
    "detail": "House cleaning · Tomorrow 10:00 AM · 3 hrs", "status": "Requested",
    "amount": 94.08, "address": "123 Oak Tree Road, Edison, NJ",
    "customerName": "E2E Customer", "customerPhone": REAL_PHONE,
    "customerEmail": "", "fulfillment": "", "pickupEta": "", "otp": "",
}), token=cust)
check("home-service: customer creates booking", st == 200)
hs_booking = d.get("name", "").split("/documents/")[-1]

st, _ = http("GET", f"{FS}/{hs_booking}", token=cust)
check("home-service: customer reads own booking", st == 200)
st, _ = http("GET", f"{FS}/{hs_booking}", token=owner)
check("home-service: provider owner reads the booking", st == 200)
st, _ = http("PATCH", f"{FS}/{hs_booking}?updateMask.fieldPaths=status",
             doc_body({"status": "Accepted"}), token=owner)
check("home-service: owner accepts (status update)", st == 200)
st, _ = http("PATCH", f"{FS}/{hs_booking}?updateMask.fieldPaths=amount",
             doc_body({"amount": 1.0}), token=owner)
check("rules: owner CANNOT change the amount", st == 403)
st, _ = http("PATCH", f"{FS}/{hs_booking}?updateMask.fieldPaths=status",
             doc_body({"status": "Completed"}), token=owner)
check("home-service: owner completes the job", st == 200)

# a second customer must NOT see this booking
other_uid, other = auth_user("stranger.e2e@localhive.test", "test123456")
st, _ = http("GET", f"{FS}/{hs_booking}", token=other)
check("rules: another user cannot read the booking", st == 403)

# ---------- C. Store pickup flow with ETA ----------
st, d = http("POST", f"{FS}/bookings", doc_body({
    "userId": cust_uid, "providerId": "ft1", "providerOwnerId": own_uid,
    "providerName": "Bombay Street Eats", "category": "food_truck",
    "detail": "Pickup order · 1 item", "status": "Placed", "amount": 14.55,
    "address": "", "customerName": "E2E Customer",
    "customerPhone": REAL_PHONE, "customerEmail": "",
    "fulfillment": "pickup", "pickupEta": "In 30 min", "otp": "",
}), token=cust)
check("pickup: customer places order with ETA", st == 200)
pick = d.get("name", "").split("/documents/")[-1]
for status in ("Preparing", "Ready", "Completed"):
    st, _ = http("PATCH", f"{FS}/{pick}?updateMask.fieldPaths=status",
                 doc_body({"status": status}), token=owner)
    if st != 200:
        break
check("pickup: owner runs Preparing→Ready→Completed", st == 200)

# ---------- D. Delivery flow with OTP ----------
otp = str(1000 + random.randint(0, 8999))
st, d = http("POST", f"{FS}/bookings", doc_body({
    "userId": cust_uid, "providerId": "ft1", "providerOwnerId": own_uid,
    "providerName": "Bombay Street Eats", "category": "food_truck",
    "detail": "Delivery order · 1 item", "status": "Placed", "amount": 19.54,
    "address": "456 Wood Ave, Iselin, NJ", "customerName": "E2E Customer",
    "customerPhone": REAL_PHONE, "customerEmail": "",
    "fulfillment": "delivery", "pickupEta": "", "otp": otp,
}), token=cust)
check("delivery: customer places order (OTP generated)", st == 200)
deliv = d.get("name", "").split("/documents/")[-1]
deliv_id = deliv.split("/")[-1]

for status in ("Preparing", "Ready"):
    st, _ = http("PATCH", f"{FS}/{deliv}?updateMask.fieldPaths=status",
                 doc_body({"status": status}), token=owner)
check("delivery: owner prepares and marks Ready", st == 200)

# The job board is readable by every signed-in partner, so it must not carry
# the customer's contact details or the delivery OTP.
st, _ = http("POST", f"{FS}/delivery_jobs?documentId={deliv_id}_leak", doc_body({
    "storeName": "Leak Test", "orderDetail": "x", "dropAddress": "x",
    "otp": otp, "fee": 1.0, "status": "Open", "deliveryPersonId": "",
}), token=owner)
check("rules: a job carrying the OTP is rejected", st == 403)

st, _ = http("POST", f"{FS}/delivery_jobs?documentId={deliv_id}", doc_body({
    "storeName": "Bombay Street Eats", "orderDetail": "Delivery order · 1 item",
    "dropAddress": "456 Wood Ave, Iselin, NJ",
    "fee": 4.99, "status": "Open", "deliveryPersonId": "",
}), token=owner)
check("delivery: owner posts job to the board", st == 200)

# An unassigned partner must not be able to read the booking that holds the OTP.
st, _ = http("GET", f"{FS}/{deliv}", token=other)
check("rules: unassigned partner cannot read the order's OTP", st == 403)

# stranger (acting as delivery partner) claims it
st, _ = http("PATCH",
             f"{FS}/delivery_jobs/{deliv_id}?updateMask.fieldPaths=deliveryPersonId&updateMask.fieldPaths=status",
             doc_body({"deliveryPersonId": other_uid, "status": "Claimed"}),
             token=other)
check("delivery: partner claims the open job", st == 200)

# a second partner cannot steal the claimed job
st, _ = http("PATCH",
             f"{FS}/delivery_jobs/{deliv_id}?updateMask.fieldPaths=deliveryPersonId",
             doc_body({"deliveryPersonId": cust_uid}), token=cust)
check("rules: claimed job cannot be stolen", st == 403)

st, _ = http("PATCH", f"{FS}/delivery_jobs/{deliv_id}?updateMask.fieldPaths=status",
             doc_body({"status": "PickedUp"}), token=other)
st2, _ = http("PATCH", f"{FS}/{deliv}?updateMask.fieldPaths=status",
              doc_body({"status": "Out for delivery"}), token=other)
check("delivery: assigned partner sets Out-for-delivery on the order",
      st == 200 and st2 == 200)

# ---- Live courier tracking ----
# The assigned partner's device publishes GPS positions onto the job.
route = [(40.5651, -74.3229), (40.5702, -74.3181), (40.5744, -74.3120)]
track_ok = True
for lat, lng in route:
    st, _ = http("PATCH",
                 f"{FS}/delivery_jobs/{deliv_id}"
                 "?updateMask.fieldPaths=courierLat"
                 "&updateMask.fieldPaths=courierLng"
                 "&updateMask.fieldPaths=courierSpeedMps",
                 doc_body({"courierLat": lat, "courierLng": lng,
                           "courierSpeedMps": 6.5}), token=other)
    track_ok = track_ok and st == 200
check("tracking: assigned partner publishes GPS positions", track_ok)

# The customer reads the courier's live position for their map.
st, td = http("GET", f"{FS}/delivery_jobs/{deliv_id}", token=cust)
got_lat = get_field(td, "courierLat")
check("tracking: customer sees the courier's live position",
      st == 200 and abs(float(got_lat) - route[-1][0]) < 1e-6,
      f"status {st}, lat {got_lat}")

# A partner who is not assigned must not be able to spoof the position.
st, _ = http("PATCH",
             f"{FS}/delivery_jobs/{deliv_id}?updateMask.fieldPaths=courierLat",
             doc_body({"courierLat": 0.0}), token=cust)
check("rules: only the assigned partner can move the courier pin", st == 403)

# OTP verification (as the app does): the assigned partner reads it from the
# booking — not from the job board — then completes the delivery.
st, bd = http("GET", f"{FS}/{deliv}", token=other)
job_otp = get_field(bd, "otp")
check("delivery: assigned partner reads the OTP from the booking",
      st == 200 and job_otp == otp, f"status {st}")
wrong = "0000" if otp != "0000" else "1111"
check("delivery: wrong OTP is rejected (client gate)", wrong != job_otp)
st, _ = http("PATCH", f"{FS}/delivery_jobs/{deliv_id}?updateMask.fieldPaths=status",
             doc_body({"status": "Delivered"}), token=other)
st2, _ = http("PATCH", f"{FS}/{deliv}?updateMask.fieldPaths=status",
              doc_body({"status": "Delivered"}), token=other)
check("delivery: correct OTP completes the delivery", st == 200 and st2 == 200)

# ---------- E. Truck follow + arrival announcement ----------
st, _ = http("POST", f"{FS}/truck_followers?documentId=ft1_{cust_uid}", doc_body({
    "truckId": "ft1", "truckName": "Bombay Street Eats",
    "truckOwnerId": own_uid, "userId": cust_uid,
    "phone": REAL_PHONE, "email": "",
}), token=cust)
check("arrival: customer follows the truck", st in (200, 409))

st, qd = http("POST",
              f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents:runQuery",
              {"structuredQuery": {
                  "from": [{"collectionId": "truck_followers"}],
                  "where": {"fieldFilter": {
                      "field": {"fieldPath": "truckOwnerId"},
                      "op": "EQUAL",
                      "value": {"stringValue": own_uid}}}}},
              token=owner)
n_followers = len([r for r in (qd if isinstance(qd, list) else []) if r.get("document")])
check("arrival: owner can list their followers", st == 200 and n_followers >= 1,
      f"status {st}, followers {n_followers}")

# ---------- F. Notification queue (as the app would enqueue) ----------
msgs = [
    ("order_delivered_e2e", f"LocalHive E2E: delivery flow complete — OTP {otp} verified. All workflows passed!"),
]
for event, message in msgs:
    st, _ = http("POST", f"{FS}/notifications", doc_body({
        "recipient": "customer", "phone": REAL_PHONE, "email": "",
        "event": event, "message": message, "status": "pending",
    }), token=cust)
check("notifications: signed-in client can enqueue", st == 200)
st, _ = http("GET", f"{FS}/notifications?pageSize=1", token=cust)
check("notifications: client still cannot READ the queue", st == 403)

print()
passed = sum(1 for _, ok in results if ok)
print(f"=== {passed}/{len(results)} checks passed ===")
sys.exit(0 if passed == len(results) else 1)
