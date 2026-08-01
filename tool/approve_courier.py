#!/usr/bin/env python3
"""Approve a delivery partner, and clear stale jobs from retired verticals.

Claiming a delivery job unlocks a stranger's name, phone, home address and
handover code, so the job board is limited to couriers listed in the
`couriers` collection. That collection is writable only by the service
account (and admins), never by the app — otherwise "approval" would be
self-service and the gate would mean nothing.

Usage:
    python3 tool/approve_courier.py <email> [<email> ...]
    python3 tool/approve_courier.py --list
    python3 tool/approve_courier.py --purge-stale-jobs
"""
import json
import os
import sys

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SA = os.path.join(ROOT, ".secrets", "service_account.json")
PROJECT = "localhivelocalhive"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"


def token():
    creds = service_account.Credentials.from_service_account_file(
        SA, scopes=["https://www.googleapis.com/auth/datastore",
                    "https://www.googleapis.com/auth/firebase"])
    creds.refresh(google.auth.transport.requests.Request())
    return creds.token


def uid_for(email, tok):
    """Look the account up by email.

    accounts:query, not accounts:lookup — lookup is the client-facing endpoint
    that resolves an ID token, and it does not accept an email from a service
    account.
    """
    r = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts:query",
        headers={"Authorization": f"Bearer {tok}"},
        json={"limit": "500"}, timeout=30)
    for u in r.json().get("userInfo", []):
        if u.get("email", "").lower() == email.lower():
            return u["localId"]
    return None


def main():
    tok = token()
    H = {"Authorization": f"Bearer {tok}"}

    if "--list" in sys.argv:
        r = requests.get(f"{BASE}/couriers?pageSize=100", headers=H, timeout=30)
        docs = r.json().get("documents", [])
        print(f"{len(docs)} approved courier(s)")
        for d in docs:
            f = d.get("fields", {})
            print(f"  {d['name'].split('/')[-1]}  "
                  f"{f.get('email', {}).get('stringValue', '')}")
        return

    if "--purge-stale-jobs" in sys.argv:
        # Jobs left over from the food-truck and home-service verticals still
        # carry a real drop address; they belong to nothing now.
        r = requests.get(f"{BASE}/delivery_jobs?pageSize=300", headers=H, timeout=60)
        docs = r.json().get("documents", [])
        killed = 0
        for d in docs:
            f = d.get("fields", {})
            if "dropAddress" in f or "deliveryNote" in f:
                requests.delete(f"https://firestore.googleapis.com/v1/{d['name']}",
                                headers=H, timeout=30)
                killed += 1
                print(f"  deleted {d['name'].split('/')[-1]} "
                      f"({f.get('storeName', {}).get('stringValue', '?')})")
        print(f"{killed} stale job(s) carrying a raw address removed, "
              f"{len(docs) - killed} kept")
        return

    emails = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not emails:
        sys.exit(__doc__)
    for email in emails:
        uid = uid_for(email, tok)
        if not uid:
            print(f"  {email}: no such account")
            continue
        r = requests.patch(
            f"{BASE}/couriers/{uid}", headers=H, timeout=30,
            json={"fields": {
                "email": {"stringValue": email},
                "approvedBy": {"stringValue": "service-account"},
                "approvedAt": {"timestampValue":
                               __import__("datetime").datetime.now(
                                   __import__("datetime").timezone.utc)
                               .strftime("%Y-%m-%dT%H:%M:%SZ")},
            }})
        print(f"  {email} ({uid[:8]}…): "
              f"{'approved' if r.status_code == 200 else r.text[:120]}")


if __name__ == "__main__":
    main()
