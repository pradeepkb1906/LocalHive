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


SA_FILE = os.path.join(os.path.dirname(SECRETS), "service_account.json")


_CREDS = None


def _fs_headers():
    """OAuth headers from the service account — the dispatcher acts as the
    trusted server and bypasses security rules. Auto-refreshes the token
    so --loop mode survives past the 1-hour token lifetime."""
    global _CREDS
    import google.auth.transport.requests
    from google.oauth2 import service_account
    if _CREDS is None:
        _CREDS = service_account.Credentials.from_service_account_file(
            SA_FILE, scopes=["https://www.googleapis.com/auth/datastore"])
    if not _CREDS.valid:
        _CREDS.refresh(google.auth.transport.requests.Request())
    return {"Authorization": f"Bearer {_CREDS.token}",
            "Content-Type": "application/json"}


def load_secrets():
    """Returns (account_sid, basic_auth_user, basic_auth_pass, from_number).

    Prefers an API key pair (SK sid + secret); falls back to auth token."""
    creds = _read_env()
    acct = creds.get("TWILIO_ACCOUNT_SID", "")
    key_sid = creds.get("TWILIO_API_KEY_SID", "")
    key_secret = creds.get("TWILIO_API_KEY_SECRET", "")
    tok = creds.get("TWILIO_AUTH_TOKEN", "")
    frm = creds.get("TWILIO_FROM_NUMBER", "")
    if "PASTE" in acct or "XXXX" in frm or not acct:
        sys.exit("Fill in .secrets/twilio.env first (account SID, API key, from-number).")
    wa_from = creds.get("TWILIO_WHATSAPP_FROM", "")
    if key_sid and key_secret and "PASTE" not in key_sid and "PASTE" not in key_secret:
        return acct, key_sid, key_secret, frm, wa_from
    if tok and "PASTE" not in tok:
        return acct, acct, tok, frm, wa_from
    sys.exit("Add a Twilio API key (SID + secret) to .secrets/twilio.env.")


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
    req = urllib.request.Request(f"{FS}/{path}?{params.lstrip('&')}",
                                 headers=_fs_headers())
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode())


def fs_patch(doc_path, fields):
    mask = "&".join(f"updateMask.fieldPaths={k}" for k in fields)
    body = {"fields": {k: {"stringValue": v} for k, v in fields.items()}}
    req = urllib.request.Request(
        f"https://firestore.googleapis.com/v1/{doc_path}?{mask}",
        data=json.dumps(body).encode(),
        headers=_fs_headers(),
        method="PATCH",
    )
    urllib.request.urlopen(req).read()


def send_sms(acct, user, secret, frm, to, body):
    url = f"https://api.twilio.com/2010-04-01/Accounts/{acct}/Messages.json"
    data = urllib.parse.urlencode({"From": frm, "To": to, "Body": body}).encode()
    req = urllib.request.Request(url, data=data)
    auth = base64.b64encode(f"{user}:{secret}".encode()).decode()
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
    acct = user = secret = frm = wa_from = None
    if not dry:
        acct, user, secret, frm, wa_from = load_secrets()
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
        # WhatsApp-first (cheaper, no 10DLC); SMS fallback if it fails
        # (e.g. recipient hasn't joined the sandbox / has no WhatsApp).
        if wa_from:
            ok, info = send_sms(acct, user, secret, wa_from, f"whatsapp:{to}", msg)
            if ok:
                print(f"{label} SENT via WhatsApp to {to} (sid {info})")
                fs_patch(d["name"], {"status": "sent", "channelUsed": "whatsapp",
                                     "twilioSid": info})
                continue
            print(f"{label} WhatsApp failed ({info[:80]}) — falling back to SMS")
        ok, info = send_sms(acct, user, secret, frm, to, msg)
        if ok:
            print(f"{label} SENT via SMS to {to} (sid {info})")
            fs_patch(d["name"], {"status": "sent", "channelUsed": "sms",
                                 "twilioSid": info})
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
