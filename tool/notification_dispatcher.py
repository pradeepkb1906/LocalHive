#!/usr/bin/env python3
"""LocalHive notification dispatcher.

Drains the Firestore `notifications` outbox (status == 'pending') and sends
SMS via the Twilio REST API. Marks each doc 'sent' or 'failed' with details.
Email channel is skipped until an email provider (Brevo/Resend) is added.

Credentials are read from .secrets/twilio.env (gitignored) — never from
source code or chat. Run from the project root:

  python3 tool/notification_dispatcher.py            # one pass
  python3 tool/notification_dispatcher.py --loop     # poll every 30 s
  python3 tool/notification_dispatcher.py --dry-run  # show, don't send
"""
import base64
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

PROJECT = "localhivelocalhive"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

SECRETS = os.path.join(os.path.dirname(__file__), "..", ".secrets", "twilio.env")


def _read_env():
    vals = {}
    try:
        with open(SECRETS) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    vals[k.strip()] = v.strip()
    except FileNotFoundError:
        sys.exit(f"Secrets file not found: {SECRETS}")
    return vals


API_KEY = _read_env().get("FIREBASE_API_KEY", "")
if not API_KEY:
    sys.exit("FIREBASE_API_KEY missing from .secrets/twilio.env")


def load_secrets():
    creds = _read_env()
    sid = creds.get("TWILIO_ACCOUNT_SID", "")
    tok = creds.get("TWILIO_AUTH_TOKEN", "")
    frm = creds.get("TWILIO_FROM_NUMBER", "")
    if "PASTE" in sid or "PASTE" in tok or "XXXX" in frm or not sid:
        sys.exit("Fill in .secrets/twilio.env first (SID, token, from-number).")
    return sid, tok, frm


def normalize_us(phone: str) -> str | None:
    digits = re.sub(r"[^0-9+]", "", phone or "")
    if digits.startswith("+"):
        return digits
    if len(digits) == 10:
        return "+1" + digits
    if len(digits) == 11 and digits.startswith("1"):
        return "+" + digits
    return None


def fs_get(path, params=""):
    with urllib.request.urlopen(f"{FS}/{path}?key={API_KEY}{params}") as r:
        return json.loads(r.read().decode())


def fs_patch(doc_path, fields):
    mask = "&".join(f"updateMask.fieldPaths={k}" for k in fields)
    body = {"fields": {k: {"stringValue": v} for k, v in fields.items()}}
    req = urllib.request.Request(
        f"https://firestore.googleapis.com/v1/{doc_path}?{mask}&key={API_KEY}",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="PATCH",
    )
    urllib.request.urlopen(req).read()


def send_sms(sid, tok, frm, to, body):
    url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json"
    data = urllib.parse.urlencode({"From": frm, "To": to, "Body": body}).encode()
    req = urllib.request.Request(url, data=data)
    auth = base64.b64encode(f"{sid}:{tok}".encode()).decode()
    req.add_header("Authorization", f"Basic {auth}")
    try:
        with urllib.request.urlopen(req) as r:
            resp = json.loads(r.read().decode())
            return True, resp.get("sid", "")
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read().decode()).get("message", str(e))
        except Exception:
            err = str(e)
        return False, err


def one_pass(dry: bool):
    sid = tok = frm = None
    if not dry:
        sid, tok, frm = load_secrets()
    docs = fs_get("notifications", "&pageSize=100").get("documents", [])
    pending = [
        d for d in docs
        if d["fields"].get("status", {}).get("stringValue") == "pending"
    ]
    print(f"{len(pending)} pending notification(s)")
    for d in pending:
        f = d["fields"]
        msg = f.get("message", {}).get("stringValue", "")
        phone = f.get("phone", {}).get("stringValue", "")
        recipient = f.get("recipient", {}).get("stringValue", "?")
        to = normalize_us(phone)
        label = f"[{f.get('event',{}).get('stringValue','?')} → {recipient}]"
        if not to:
            print(f"{label} SKIP — no valid US phone on record")
            if not dry:
                fs_patch(d["name"], {"status": "failed", "error": "no valid phone"})
            continue
        if dry:
            print(f"{label} DRY-RUN would text {to}: {msg[:70]}…")
            continue
        ok, info = send_sms(sid, tok, frm, to, msg)
        if ok:
            print(f"{label} SENT to {to} (sid {info})")
            fs_patch(d["name"], {"status": "sent", "twilioSid": info})
        else:
            print(f"{label} FAILED: {info}")
            fs_patch(d["name"], {"status": "failed", "error": info[:400]})


if __name__ == "__main__":
    loop = "--loop" in sys.argv
    dry = "--dry-run" in sys.argv
    while True:
        one_pass(dry)
        if not loop:
            break
        time.sleep(30)
