#!/usr/bin/env python3
"""Make every live catalog listing owned by the matching demo account.

Without this, a customer can book a listing whose ownerId is empty or points at
a throwaway test account — the order is created but no business owner ever sees
it, so the flow dead-ends. Assigning owners per category means whichever
listing the customer taps, the corresponding demo owner login can act on it.

  home_service  -> maria@localhive.app
  indian_store  -> store@localhive.app
  food_truck    -> truck@localhive.app

Runs as admin@localhive.app, the only account the security rules let change a
listing's ownership.

Run:  python3 tool/assign_demo_owners.py
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

OWNER_FOR = {
    "home_service": "maria",
    "indian_store": "store",
    "food_truck": "truck",
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
    return d["idToken"], d["localId"]


def field(doc, key):
    v = doc.get("fields", {}).get(key, {})
    return next(iter(v.values()), None)


admin_tok, _ = sign_in("admin")
uids = {name: sign_in(name)[1] for name in set(OWNER_FOR.values())}
print("demo owner uids:", {k: v[:8] + "…" for k, v in uids.items()})

# Page through the whole collection — the nationwide seed pushed it well
# past one page, and an unpaginated read silently skips the rest.
docs = []
page = ""
while True:
    st, d = http("GET", f"{FS}/providers?pageSize=300&pageToken={page}",
                 token=admin_tok)
    if st != 200:
        sys.exit(f"cannot list providers: {d}")
    docs.extend(d.get("documents", []))
    page = d.get("nextPageToken", "")
    if not page:
        break
d = {"documents": docs}

changed = skipped = failed = 0
for p in d.get("documents", []):
    if field(p, "live") is not True:
        continue
    cat = field(p, "category")
    want = uids.get(OWNER_FOR.get(cat, ""))
    if not want:
        continue
    pid = p["name"].split("/")[-1]
    have = field(p, "ownerId") or ""
    if have == want:
        skipped += 1
        continue
    st, r = http("PATCH",
                 f"{FS}/providers/{pid}?updateMask.fieldPaths=ownerId",
                 {"fields": {"ownerId": {"stringValue": want}}},
                 token=admin_tok)
    if st == 200:
        changed += 1
        print(f"  {cat:13} {field(p, 'name'):28} -> "
              f"{OWNER_FOR[cat]}@localhive.app")
    else:
        failed += 1
        print(f"  FAILED {field(p, 'name')}: {st} {r}")

print(f"\n{changed} reassigned, {skipped} already correct, {failed} failed")
