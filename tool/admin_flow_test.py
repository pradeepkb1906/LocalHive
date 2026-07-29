#!/usr/bin/env python3
"""End-to-end test of the provider-application review flow.

Applicant submits → only admins can see the queue → admin approves →
listing goes live → applicant is notified. Runs against the live locked
database with real user tokens.
"""
import json
import os
import sys
import urllib.error
import urllib.request

import google.auth.transport.requests
from google.oauth2 import service_account

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = {}
for line in open(os.path.join(ROOT, ".secrets", "twilio.env")):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        ENV[k.strip()] = v.strip()
API_KEY = ENV["FIREBASE_API_KEY"]
FS = ("https://firestore.googleapis.com/v1/projects/localhivelocalhive"
      "/databases/(default)/documents")
RUNQ = ("https://firestore.googleapis.com/v1/projects/localhivelocalhive"
        "/databases/(default)/documents:runQuery")

results = []


def check(name, ok, detail=""):
    results.append(ok)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail and not ok else ""))


def http(method, url, body=None, token=None):
    h = {"Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        url, data=json.dumps(body).encode() if body is not None else None,
        headers=h, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def auth(email, password):
    st, d = http("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}",
                 {"email": email, "password": password, "returnSecureToken": True})
    if st != 200:
        st, d = http("POST", f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}",
                     {"email": email, "password": password, "returnSecureToken": True})
    assert st == 200, f"auth failed {email}: {d}"
    return d["localId"], d["idToken"]


def sv(v):
    return {"stringValue": str(v)} if not isinstance(v, bool) else {"booleanValue": v}


print("=== Provider application review flow ===\n")

admin_uid, admin = auth("admin@localhive.app", "admin@123")
app_uid, applicant = auth("applicant.e2e@localhive.test", "test123456")

# 1. Applicant creates a draft listing + application (what the wizard does)
st, listing = http("POST", f"{FS}/providers", {"fields": {
    "name": sv("E2E Test Kitchen"), "category": sv("food_truck"),
    "subtitle": sv("New on LocalHive"), "city": sv("Edison, NJ"),
    "rating": {"doubleValue": 5.0}, "reviews": {"integerValue": "0"},
    "hourlyRate": {"doubleValue": 0.0},
    "availableFrom": sv("10 AM"), "availableTo": sv("8 PM"),
    "verified": sv(False), "live": sv(False), "ownerId": sv(app_uid),
    "phone": sv("+918884498810"), "email": sv("applicant.e2e@localhive.test"),
}}, token=applicant)
check("applicant creates draft listing (live=false)", st == 200)
listing_id = listing.get("name", "").split("/")[-1]

st, _ = http("POST", f"{FS}/providers", {"fields": {
    "name": sv("Sneaky Self-Publish"), "category": sv("food_truck"),
    "live": sv(True), "ownerId": sv(app_uid),
}}, token=applicant)
check("rules: applicant CANNOT create an already-live listing", st == 403)

st, app_doc = http("POST", f"{FS}/provider_applications", {"fields": {
    "userId": sv(app_uid), "listingId": sv(listing_id),
    "type": sv("food_truck"), "businessName": sv("E2E Test Kitchen"),
    "city": sv("Edison, NJ"), "availableFrom": sv("10 AM"),
    "availableTo": sv("8 PM"),
    "applicantEmail": sv("applicant.e2e@localhive.test"),
    "applicantPhone": sv("+918884498810"), "status": sv("in_review"),
}}, token=applicant)
check("applicant submits application", st == 200)
app_id = app_doc.get("name", "").split("/")[-1]

# 2. Applicant cannot publish themselves, nor approve their own application
st, _ = http("PATCH", f"{FS}/providers/{listing_id}?updateMask.fieldPaths=live",
             {"fields": {"live": sv(True)}}, token=applicant)
check("rules: applicant CANNOT flip their listing live", st == 403)
st, _ = http("PATCH", f"{FS}/provider_applications/{app_id}?updateMask.fieldPaths=status",
             {"fields": {"status": sv("approved")}}, token=applicant)
check("rules: applicant CANNOT approve their own application", st == 403)

# 3. A random signed-in user cannot see the review queue
_, stranger = auth("stranger.e2e@localhive.test", "test123456")
st, _ = http("GET", f"{FS}/provider_applications/{app_id}", token=stranger)
check("rules: other users cannot read applications", st == 403)

# 4. Admin sees the queue
st, rows = http("POST", RUNQ, {"structuredQuery": {
    "from": [{"collectionId": "provider_applications"}]}}, token=admin)
found = any(r.get("document", {}).get("name", "").endswith(app_id)
            for r in (rows if isinstance(rows, list) else []))
check("admin can list the application queue", st == 200 and found)

# 5. Admin approves: publish listing + mark reviewed
st1, _ = http("PATCH",
              f"{FS}/providers/{listing_id}?updateMask.fieldPaths=live&updateMask.fieldPaths=verified",
              {"fields": {"live": sv(True), "verified": sv(True)}}, token=admin)
st2, _ = http("PATCH",
              f"{FS}/provider_applications/{app_id}?updateMask.fieldPaths=status&updateMask.fieldPaths=reviewedBy",
              {"fields": {"status": sv("approved"), "reviewedBy": sv(admin_uid)}},
              token=admin)
check("admin approves (publishes listing + marks reviewed)", st1 == 200 and st2 == 200)

# 6. The listing is now publicly visible
st, doc = http("GET", f"{FS}/providers/{listing_id}?key={API_KEY}")
live = doc.get("fields", {}).get("live", {}).get("booleanValue")
check("approved listing is public and live", st == 200 and live is True)

# 7. Applicant sees their approved status
st, doc = http("GET", f"{FS}/provider_applications/{app_id}", token=applicant)
status = doc.get("fields", {}).get("status", {}).get("stringValue")
check("applicant sees 'approved' on their application", status == "approved")

# 8. Approval notification reaches the queue
st, _ = http("POST", f"{FS}/notifications", {"fields": {
    "recipient": sv("applicant"), "phone": sv("+918884498810"),
    "email": sv("applicant.e2e@localhive.test"),
    "event": sv("application_reviewed"),
    "message": sv("LocalHive: your application for \"E2E Test Kitchen\" is "
                  "APPROVED! Your listing is live — customers can book you now."),
    "status": sv("pending"),
}}, token=admin)
check("approval notification queued for delivery", st == 200)

# cleanup: unpublish the test listing so it doesn't pollute the catalog
http("PATCH", f"{FS}/providers/{listing_id}?updateMask.fieldPaths=live",
     {"fields": {"live": sv(False)}}, token=admin)

print()
print(f"=== {sum(results)}/{len(results)} checks passed ===")
sys.exit(0 if all(results) else 1)
