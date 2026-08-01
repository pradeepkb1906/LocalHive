# LocalHive — Requirements Specification

**Version 0.4 · 1 August 2026 · Pre-revenue, pre-launch**

This describes what LocalHive actually does today, not what it might do. Where
something is deliberately absent, it says so and why. Anything marked
**GAP** is a known shortfall with real consequences, not a nice-to-have.

---

## 1. What this is

A marketplace connecting **grocery shops in California** with customers who
want to order ahead for pickup or delivery, and with neighbours willing to
carry the order the last few blocks.

**Scope is deliberately narrow.** Two earlier verticals — home services and
food trucks — were built, then deleted from both the data and the code. The
app serves one vertical in one state. Everything below assumes that.

### 1.1 Non-goals

| Not built | Why |
|---|---|
| In-app payment | The customer pays the shop directly. No card data, no PCI scope, no money transmission. |
| Ride-hailing / taxi | TNC regulation. Explicitly out of scope. |
| Operating outside California | No partners, no directory, no delivery coverage. Enforced in code (§4.1). |
| SMS / WhatsApp notification | Removed. Per-message cost dominated the infrastructure bill. In-app only. |
| Automated courier payouts | No money moves. Fees are recorded, not disbursed (§7.3). |

---

## 2. Actors

| Actor | Becomes one by | Can do |
|---|---|---|
| **Visitor** | Opening the app | Browse shops, see nearby groceries, call them, get directions |
| **Customer** | Signing up | Everything above, plus ordering, tracking, chat, Olivia |
| **Shop owner** | Applying, then admin approval | Manage a listing, receive and progress orders, post deliveries |
| **Delivery partner** | Applying, then **admin approval into `couriers`** | See the job board, claim, deliver against an OTP |
| **Platform admin** | Being added to `admins` by the service account only | Approve applications, control feature access |

**Admin is never self-service.** Membership lives in a collection no client
can write. The role field on a user's own profile is a display preference,
not a permission (§6.4).

---

## 3. Functional requirements

### 3.1 Discovery

- **FR-1** The store list shows LocalHive partners first, then real
  California grocery shops that have *not* joined, labelled plainly as
  non-partners with Call and Directions but no ordering.
- **FR-2** Non-partner shops come from a directory of **4,719 real California
  grocery shops** sourced from OpenStreetMap, mirrored into Supabase.
- **FR-3** The directory is searched from a tight box outwards (1.5 km → 4 km
  → 8 km), stopping when it has enough. *A single wide query returns an
  arbitrary slice, because the row cap is applied before distance sorting —
  downtown San Francisco reported its nearest grocery as 3.4 km away with a
  Safeway 300 m up the road.*
- **FR-4** If the directory is unreachable, fall back to a live OpenStreetMap
  search. If that fails too, show nothing rather than invent listings.

### 3.2 Ordering

- **FR-5** A customer builds a basket, chooses pickup (with an arrival ETA) or
  delivery (with an address), and places one order.
- **FR-6** Every order records what was ordered — item, quantity, unit price
  at time of order — so a later price change cannot alter what was agreed.
- **FR-7** A delivery order may request **help to the door** with an optional
  note. Free to the customer.
- **FR-8** Placing an order is idempotent under double-tap: the button
  disables and the call is awaited.
- **FR-9** An order that cannot be recorded must **not** be reported as
  placed. The optimistic row is withdrawn and the basket kept (§6.6).
- **FR-10** A customer may cancel while the order is still `Requested`.

### 3.3 Fulfilment

- **FR-11** Owner progresses: `Placed → Preparing → Ready →` pickup
  `Completed`, or delivery → posts a job to the board.
- **FR-12** The board shows shop, goods, fee, neighbourhood, and whether help
  is needed. **Never the street address, note, phone or OTP** (§6.1).
- **FR-13** Only an approved courier may claim. On claiming, the booking
  yields the address, note, phone and OTP.
- **FR-14** Delivery completes only against the customer's 4-digit OTP.
  **GAP:** verified client-side only (§6.5).
- **FR-15** While a job is active, the courier's position is shared so the
  customer can watch them approach.

### 3.4 Pay

- **FR-16** A plain run pays **$4.99**; one needing help to the door pays
  **$7.99**. Both derive from single constants that the recruiting page reads,
  so the promise cannot drift from the payout.
- **FR-17** The **$3.00** help premium comes out of the platform's 12% cut,
  never the customer's bill. *The people most likely to need help are the
  least able to pay more for it.*
- **FR-18** Earnings are read on demand, not streamed. *Every streamed
  document is a billed read; this is what exhausted the quota once.*

### 3.5 Olivia (voice assistant)

- **FR-19** Scope is grocery shops only. Anything else gets an explicit
  refusal, not a guess.
- **FR-20** She may search, look up shops, and **draft** an order. She cannot
  commit one — the confirmation card is the only write path.
- **FR-21** She never invents a phone number and offers a call only after the
  customer agrees.

### 3.6 Messaging

- **FR-22** 1:1 text between the two sides of an order, capped at 250 words
  per conversation, then a prompt to call. Messages are immutable.

---

## 4. Location

### 4.1 California is a boundary, not a default

- **FR-23** A device position inside California is used as-is.
- **FR-24** A position **outside** California is discarded. The app falls back
  to the chosen city, defaulting to San Francisco, and says why.
- **FR-25** The customer may pick any of 40 California cities; the choice
  persists.
- **FR-26** The boundary models California's real outline — south to Lake
  Tahoe, the diagonal, then the Colorado River. *A rectangle wide enough for
  Needles also contains Las Vegas and Reno.*

Every consumer — map, Olivia, delivery-address lookup — reads position through
one service, so all inherit this.

---

## 5. Data model

| Collection | Holds | Read | Write |
|---|---|---|---|
| `providers` | Public listings | Everyone | Owner (not `live`/`verified`/`rating`/`reviews`); admin |
| `bookings` | Orders + **PII + OTP** | Customer, shop owner, assigned courier | Creator; status-only updates |
| `delivery_jobs` | Board — **no PII** | Approved couriers, admin, own customer | Approved courier; `fee`/`userId` pinned |
| `couriers` | Approved partners | Self, admin | **Service account / admin only** |
| `admins` | Platform staff | Self | **Service account only** |
| `chats/{id}/messages` | 1:1 text | Participants | Participants; immutable |
| `users` | Role + prefs | Self, admin | Self |
| `config`, `user_feature_flags` | Feature access | Signed-in / self | Admin |
| `notifications` | In-app feed | Addressee | Any signed-in *(**GAP** §6.3)* |

**PII is split on purpose.** Name, phone, email, street address, delivery note
and OTP live on `bookings`, readable by the two parties and — only once
assigned — the courier. The board carries none of it.

---

## 6. Security posture

Verified against the live project with real accounts on 1 August 2026.

### 6.1 Fixed — courier board exposed every customer's address `CRITICAL`

`delivery_jobs` allowed `read: if signedIn()`, and carried `dropAddress`,
`deliveryNote` and `needsHelp`. **Confirmed by exploit:** a plain customer
account read every delivery in flight with full street addresses. Combined
with `needsHelp`, that identified which homes contained someone frail.

Fixed: read restricted to admin-approved couriers; address and note removed
from the board entirely; 14 stale jobs deleted. Re-tested: customer `403`,
approved courier `200`.

### 6.2 Fixed — a shop could certify itself `HIGH`

Create and update did not pin `verified`, `rating` or `reviews`. A listing
could be created already Verified, 5.0, 900 reviews; an admin flipping `live`
would publish it. Now pinned server-side, along with `ownerId` and courier
`fee`. Re-tested: `403`.

### 6.3 Open — anyone can write to anyone's notification feed `MEDIUM`

`notifications` allows `create: if signedIn()` with an arbitrary `userId`, so
a user can put arbitrary text in a stranger's feed — a phishing surface
("your order needs payment, call this number").

*Why it is still open:* the client writes these because Cloud Functions
require the Blaze plan. **Fix before real users:** move to a Function, or
restrict `userId` to a counterparty of a shared booking.

### 6.4 Fixed — admin was read from a self-writable field `LOW`

`users/{uid}.role` is user-writable; the app treated `role == 'admin'` as
staff. Rules were never fooled — they check `admins` — but the console was
shown and every action inside it failed. Now proved against `admins`.

### 6.5 Open — the delivery OTP is checked on the device `MEDIUM`

The courier's app fetches the expected OTP and compares locally. A modified
client can skip it. No money moves on this today, so impact is disputes, not
loss. **Fix before payouts:** verify server-side.

### 6.6 Fixed — a failed order still looked placed `HIGH`

The banner said ordering was unavailable on standby but nothing enforced it,
and a thrown write escaped past the rollback. A customer could be told their
groceries were coming when nothing was recorded. Now refused at the write
layer (covering Olivia too), with the optimistic row withdrawn on failure.

### 6.7 Open — no per-user rate limit on the AI proxy `MEDIUM (cost)`

The Groq key is correctly held as a Cloudflare Worker secret and never ships
in the client; the proxy verifies a Firebase ID token and pins the model and
`max_tokens`. But **any signed-in account may call it without limit**, the
request body is spread through (so unpinned parameters reach Groq), and
message content length is uncapped.

**Fix before launch:** per-uid rate limit, whitelist forwarded fields, cap
total prompt length.

### 6.8 Open — shared demo passwords `MEDIUM`

Three demo accounts with weak shared passwords are printed on the sign-in
screen. The admin card was removed (its password no longer appears anywhere
in the shipped bundle — verified by grepping the built JS). **Set
`kShowDemoAccounts = false` before the link circulates beyond controlled
demos.**

### 6.9 Housekeeping

Six test accounts (`*.test`), a typo account `dmin@localhive.app`, and dead
`truck_followers` rules should be removed.

### 6.10 Not vulnerable

- Groq key: Worker secret, never in the bundle. Every deploy greps for it.
- Firebase Web API key in the bundle: public by design, a project identifier.
- Supabase publishable key: browser key, select-only RLS. Verified: read
  `200`, insert `401`, update touches nothing.
- XSS: Flutter renders text, not HTML. User text is never markup.
- Prompt injection via shop names: Olivia has read-only tools and cannot
  commit an order.

---

## 7. Non-functional

### 7.1 Cost — target $0/month pre-revenue

Firebase Spark, Supabase free, Cloudflare Workers free, GitHub Pages free,
OpenStreetMap free. See §8.

### 7.2 Availability

Firestore is the system of record. Supabase is a **read-only standby** holding
the catalog and directory. On a Firestore outage the app browses from the
mirror and **refuses to take orders**, saying so. There is no write failover
and no batch sync — a lagging replica cannot serve current orders, and a
3-hour window is longer than an order's entire lifecycle.

### 7.3 Money

Nothing is charged, held or disbursed in-app. Delivery fees are recorded
against completed jobs; paying them is manual and outside the system.

### 7.4 Quality gates

108 tests, `flutter analyze` clean, every public deploy scanned for `gsk_`,
`service_role`, `sb_secret` and private keys, and verified by sha256 against
the built bundle — never by grepping for comment text, which release builds
strip.

---

## 8. Cost and legal exposure

### 8.1 What can bill you today

| Service | Plan | Charges when |
|---|---|---|
| Firebase | Spark | **Never.** Hard-stops at quota. Upgrading to Blaze removes the stop. |
| Supabase | Free | **Never.** Pauses at 500 MB / 5 GB egress. |
| Cloudflare Workers | Free | **Never.** 100k req/day then 429. |
| GitHub Pages | Free | Never (public repo). |
| Groq | Free tier | **Never**, but see §6.7 — add a card and it can. |
| OpenStreetMap | Free | Never. Fair-use policy applies. |
| Google Play | — | **$25 once** |
| Apple Developer | — | **$99/year** |

**Total today: $0.** The only way to a surprise bill is enabling Blaze or
adding a payment method to Groq before §6.7 is fixed.

### 8.2 Legal — what actually carries risk

**Low, because no money moves and there is no PCI scope.** The real exposures:

1. **Worker classification.** The recruiting page states independent-contractor
   status, no guaranteed jobs, no minimum shift. California's **AB 5 / ABC
   test** is strict, and Prop 22 covers app-based delivery *only* under
   specific conditions (earnings floor, healthcare stipend). **Get California
   employment advice before paying anyone.** This is the single largest legal
   risk in the product.
2. **CCPA/CPRA.** Applies at revenue or volume thresholds you are far below,
   but the privacy policy already promises no sale of data — keep that true.
3. **Data on vulnerable people.** `needsHelp` marks customers who are elderly
   or less mobile. §6.1 was exactly this risk realised. Treat it as sensitive
   forever; never put it next to an address on a shared surface.
4. **OpenStreetMap licence (ODbL).** 4,719 shops are ODbL data. **Attribution
   is required** — "© OpenStreetMap contributors" must be visible. **GAP:
   confirm this is displayed.**
5. **Listing non-partners.** Public business facts, standard practice for
   directories. Keep the not-a-partner label unambiguous and honour removal
   requests promptly.
6. **App stores.** Both require a working privacy policy URL and accurate data
   disclosure. Apple needs account deletion in-app if you offer account
   creation — **GAP: not built.**

**Nothing here is legal advice.** Item 1 warrants a real lawyer before the
first dollar is paid to a courier.

---

## 9. Before real customers

**Blocking:** fix §6.3 and §6.7; `kShowDemoAccounts = false`; server-side OTP
(§6.5) before payouts; OSM attribution (§8.2.4); account deletion (§8.2.6);
California worker-classification advice (§8.2.1).

**Then:** remove test accounts; per-user rate limits; move notifications to a
Function; automate the Supabase mirror sync.
