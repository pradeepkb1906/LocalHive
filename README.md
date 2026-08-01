# LocalHive

**Order ahead from grocery shops in San Francisco — and earn a few dollars
carrying someone's shopping the last few blocks.**

🔗 **[Live app](https://pradeepkb1906.github.io/LocalHive/)** · one Flutter
codebase → web + Android · **$0/month to run**

---

## What it is

A marketplace for **California grocery shops**. Customers order ahead for
pickup or delivery. Shops manage orders. Neighbours with a free hour deliver
them.

Two things make it more than a directory:

**Every real grocery shop in California is already in it.** 4,719 of them,
from OpenStreetMap — name, street, phone, hours. A shop owner opening the app
finds their own shop before signing up for anything, which turns the pitch
from *imagine if you were here* into *you are already here; join and your
customers can order ahead.* Non-partners are labelled plainly: callable, not
orderable.

**Delivery is designed around the people who need it most.** A customer can
ask for **help to the door** — heavy bags, stairs, limited mobility — at no
cost to them. The courier is paid **$3 more** for it, out of the platform's
cut rather than the customer's bill, because the people most likely to need
help are the least able to pay more for it.

### Scope is deliberately small

One vertical, one state. Home services and food trucks were built and then
**deleted** — from the data and the code — to concentrate on the one that can
work. Using the app outside California is not degraded; it is refused, and the
app says why.

---

## Architecture

```
                 Flutter (web · Android) — one codebase
                                 │
        ┌────────────────┬───────┴────────┬──────────────────┐
        ▼                ▼                ▼                  ▼
   Firebase Auth    Cloud Firestore   Supabase (RO)    Cloudflare Worker
   email/password   SYSTEM OF RECORD   read standby     Groq key lives
                    orders · chat      + 4,719 shop      here, never in
                    listings · roles     directory       the client
                          │                                   │
                    security rules                       Groq (LLM + TTS)
                    (the boundary)                        Olivia's brain
```

Firestore is the **system of record**. Supabase is a **read-only standby** —
no batch sync, no write failover. During a Firestore outage the app browses
from the mirror and **refuses to take orders**, saying so, because a lagging
replica cannot serve current ones. Full reasoning and per-collection rules:
[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md).

---

## Security

**Audited line by line against the live project on 1 August 2026** — exploits
attempted with real accounts before and after each fix.

Four issues found and closed:

| Issue | Severity |
|---|---|
| Courier job board readable by **any** signed-in account, carrying every customer's street address — and, with the help flag, which homes held someone frail | **Critical** |
| A shop could create itself already `verified` with a 5.0 rating and 900 reviews | **High** |
| A failed order still told the customer their groceries were coming | **High** |
| Staff status read from a field users write themselves | Low |

The board now carries only shop, goods, fee and neighbourhood; the address
arrives with the booking once a courier is actually assigned, and claiming
requires admin approval into a collection no client can write.

**Four remain open and are documented, not hidden** — notification spoofing,
device-side OTP check, no rate limit on the AI proxy, shared demo passwords.
Each has a severity, a reason it is still open, and the fix:
[§6 of the spec](docs/REQUIREMENTS.md).

### Secrets

The Groq key is a Cloudflare Worker secret and **never** ships in a client
build. Every public deploy greps `build/web` for `gsk_`, `service_role`,
`sb_secret` and private keys before anything is pushed, and the deploy is
verified by sha256 — never by grepping for comment text, which release builds
strip. `lib/*_config.dart` files are gitignored; `.example.dart` templates are
committed.

The Firebase Web API key and the Supabase publishable key **are** in the
bundle. Both are public client identifiers by design, protected by security
rules and row-level security respectively.

---

## Running it

```bash
flutter pub get
cp lib/firebase_config.example.dart lib/firebase_config.dart   # fill in
cp lib/supabase_config.example.dart lib/supabase_config.dart   # optional
cp lib/olivia_config.example.dart  lib/olivia_config.dart      # optional
flutter run -d chrome
```

Without a config the app still runs — the mirror switches off and Olivia goes
quiet, rather than crashing.

```bash
flutter test        # 108 tests
flutter analyze     # clean
```

### Deploying

```bash
flutter build web --release --base-href /LocalHive/
python3 tool/deploy_rules.py             # Firestore rules
python3 tool/approve_courier.py --list   # approved delivery partners
```

---

## Cost

**$0/month.** Firebase Spark, Supabase free, Cloudflare Workers free, GitHub
Pages, OpenStreetMap. Every one of these **hard-stops at its quota rather than
billing** — no card is attached to any of them.

The only paths to a bill are enabling Firebase Blaze, or adding a payment
method to Groq before the proxy has a per-user rate limit. Store fees when you
publish: Google Play $25 once, Apple $99/year.

## Legal

No payment is taken in-app — the customer pays the shop directly, so there is
no PCI scope and no money transmission. The one exposure that genuinely
matters is **California worker classification (AB 5 / Prop 22)** for delivery
partners; get real advice before paying anyone.

Shop directory data © OpenStreetMap contributors, ODbL.

---

## Repo

```
lib/models/      data, feature flags, California cities
lib/screens/     one file per screen
lib/services/    Firebase, Supabase mirror, location, Olivia
lib/widgets/     shared UI (address field, city picker, location chip)
worker/          Cloudflare Worker — the Groq proxy
tool/            deploy, seed and audit scripts
docs/            requirements spec
test/            108 tests
firestore.rules  the actual security boundary
```

Personal project, not affiliated with any employer.
