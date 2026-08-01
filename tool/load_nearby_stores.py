#!/usr/bin/env python3
"""Load the real California grocery directory into Supabase.

These are NOT LocalHive partners. They are real shops taken from
OpenStreetMap's public data — name, street, phone, opening hours — so that a
customer opening the app in San Francisco sees the actual shops on their
street rather than an empty list, and so a shop owner being shown a demo sees
their own shop already on the map. The app labels them plainly as "not a
LocalHive partner": callable and findable, not orderable.

Source: OpenStreetMap via the Overpass API, ODbL-licensed. Rows were fetched
once into a local JSON file; this script only uploads them, so re-running it
never re-hammers Overpass.

Run:
    python3 tool/load_nearby_stores.py            # upload
    python3 tool/load_nearby_stores.py --check    # count what is there now

Auth: reads the publishable key from lib/supabase_config.dart, the same key
the app ships with. Uploading needs a temporary insert policy — see
tool/nearby_stores_load_policy.sql. Revoke it afterwards with the second half
of that file so the key is read-only again.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONFIG = os.path.join(ROOT, "lib", "supabase_config.dart")
ROWS = os.environ.get("NEARBY_ROWS", "/tmp/ca_rows.json")
BATCH = 500


def credentials():
    """Pull url + publishable key out of the app's own config."""
    if not os.path.exists(CONFIG):
        sys.exit(f"missing {CONFIG} — copy supabase_config.example.dart first")
    src = open(CONFIG).read()

    def field(name):
        m = re.search(rf"{name}\s*=\s*'([^']*)'", src)
        return m.group(1) if m else ""

    url, key = field("url"), field("anonKey")
    if not url or not key:
        sys.exit("supabase_config.dart has no url/anonKey — nothing to talk to")
    return url.rstrip("/"), key


def request(method, path, key, body=None, extra_headers=None):
    url_, api_key = path
    req = urllib.request.Request(url_, method=method)
    req.add_header("apikey", api_key)
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Content-Type", "application/json")
    for k, v in (extra_headers or {}).items():
        req.add_header(k, v)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data, timeout=60) as resp:
            return resp.status, resp.read().decode(), dict(resp.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400], dict(e.headers)
    except Exception as e:  # network-level
        return 0, str(e)[:200], {}


def count(base, key):
    status, body, headers = request(
        "GET",
        (f"{base}/rest/v1/nearby_stores?select=id&limit=1", key),
        key,
        extra_headers={"Prefer": "count=exact"},
    )
    if status != 200:
        return None, f"HTTP {status}: {body}"
    rng = headers.get("Content-Range", "")
    total = rng.split("/")[-1] if "/" in rng else "?"
    return total, None


def main():
    base, key = credentials()

    if "--check" in sys.argv:
        total, err = count(base, key)
        print(err or f"nearby_stores holds {total} rows")
        return

    if not os.path.exists(ROWS):
        sys.exit(f"missing {ROWS} — the fetched directory is not on disk")
    rows = json.load(open(ROWS))

    # Only the columns the table actually has; drop the Firestore-shaped ones.
    keep = ("id", "name", "street", "city", "phone", "hours", "lat", "lng")
    clean = []
    for r in rows:
        row = {k: r.get(k) for k in keep if r.get(k) not in (None, "")}
        if not row.get("name") or row.get("lat") is None:
            continue
        row["kind"] = r.get("subtitle") or "Grocery"
        clean.append(row)
    print(f"uploading {len(clean)} shops in batches of {BATCH}")

    sent = failed = 0
    for i in range(0, len(clean), BATCH):
        chunk = clean[i : i + BATCH]
        status, body, _ = request(
            "POST",
            # on_conflict + merge-duplicates makes a re-run idempotent
            (f"{base}/rest/v1/nearby_stores?on_conflict=id", key),
            key,
            body=chunk,
            extra_headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
        )
        if status in (200, 201, 204):
            sent += len(chunk)
            print(f"  {sent}/{len(clean)}")
        else:
            failed += len(chunk)
            print(f"  batch at {i} failed — HTTP {status}: {body}")
            if status in (401, 403):
                print(
                    "\nThe publishable key cannot insert. Run the first half of\n"
                    "tool/nearby_stores_load_policy.sql in the Supabase SQL editor,\n"
                    "then re-run this script."
                )
                break

    total, err = count(base, key)
    print(f"\ndone: {sent} uploaded, {failed} failed")
    if not err:
        print(f"nearby_stores now holds {total} rows")


if __name__ == "__main__":
    main()
