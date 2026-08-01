#!/usr/bin/env python3
"""Keep the Supabase project awake.

Supabase pauses a free project after 7 days with no database activity, and a
paused project is unavailable until somebody logs into the dashboard and
manually resumes it. There are no backups on the free plan either, so a pause
is not something to discover during a demo in a grocery shop on Divisadero.

Any query that actually reaches Postgres resets the timer, so this runs a
trivial select. Cheap enough to run daily forever and stay inside the free
tier: one row, a few hundred bytes against a 5 GB monthly egress allowance.

Reads the project URL and the publishable key from lib/supabase_config.dart —
the same browser key the app ships with, which is safe here because the table
is select-only for that key.

Run:
    python3 tool/supabase_keepalive.py
"""

import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(os.path.dirname(HERE), "lib", "supabase_config.dart")
LOG = os.path.expanduser("~/Library/Logs/localhive-supabase-keepalive.log")


def log(msg):
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')}  {msg}"
    print(line)
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(line + "\n")
    except OSError:
        pass  # logging must never be the reason the ping fails


def main():
    if not os.path.exists(CONFIG):
        log("no supabase_config.dart — mirror not configured, nothing to ping")
        return 0
    src = open(CONFIG).read()
    url = (re.search(r"url\s*=\s*'([^']*)'", src) or [None, ""])[1].rstrip("/")
    key = (re.search(r"anonKey\s*=\s*'([^']*)'", src) or [None, ""])[1]
    if not url or not key:
        log("mirror switched off (empty url/key) — nothing to ping")
        return 0

    # A real select, not a HEAD on the gateway: the point is to touch Postgres.
    req = urllib.request.Request(f"{url}/rest/v1/providers?select=id&limit=1")
    req.add_header("apikey", key)
    req.add_header("Authorization", f"Bearer {key}")

    for attempt in (1, 2, 3):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                log(f"awake — HTTP {resp.status}")
                return 0
        except urllib.error.HTTPError as e:
            # 4xx means the request reached PostgREST, which is enough to
            # count as activity even if the query itself was rejected.
            log(f"reached the project but it answered HTTP {e.code}")
            return 0
        except Exception as e:
            log(f"attempt {attempt} failed: {type(e).__name__}: {e}")
            if attempt < 3:
                time.sleep(20)

    log("COULD NOT REACH SUPABASE — check the project is not already paused")
    return 1


if __name__ == "__main__":
    sys.exit(main())
