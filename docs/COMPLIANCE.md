# LocalHive — payments, compliance, and what is *not* covered

**1 August 2026 · pre-revenue · card payments built but switched off**

---

## Read this first

**No clean chit is given here, because none can honestly be given by the
person who wrote the code.**

- **PCI DSS** is attested by *you*, the merchant, on a Self-Assessment
  Questionnaire — or by a Qualified Security Assessor above certain volumes.
  A developer cannot certify it.
- **SOC 2** is an audit of an *organisation* by a licensed CPA firm. Type II
  requires 3–12 months of evidence that controls operated. Code is never
  "SOC 2 compliant"; a company is. LocalHive currently has no company, no
  policies, no onboarding/offboarding, no logging retention and no vendor
  register — so a Type II report today would fail on the organisational
  criteria long before anyone read the source.
- **AB 5 / Prop 22** is a legal determination about employment. It needs a
  California employment lawyer.

What *is* claimed below is narrower and checkable: the code is built so that
the smallest PCI questionnaire applies, and the technical controls a SOC 2
auditor would test are largely present. The organisational half is not.

---

## 1. PCI DSS — what was built, and what you must still do

### 1.1 The design decision

Card data never touches LocalHive. The customer is redirected to a page
**hosted by Stripe on Stripe's domain**, types the card there, and returns
with an order id. No PAN, CVV or expiry passes through the Flutter app, the
Cloudflare Workers, or Firestore — and none is stored anywhere.

This is what qualifies for **SAQ A**, the short questionnaire for merchants
who fully outsource card handling. The alternative — an in-app card form, even
one using Stripe's SDK — is SAQ A-EP or SAQ D: an order of magnitude more
controls, and in practice an assessor.

> **If anyone ever adds a card field to this app, the business changes PCI
> category.** That is a business decision, not a UI tweak.

### 1.2 Controls implemented

| Requirement | How |
|---|---|
| No cardholder data stored | Nothing to store — never received. `paymentIntentId` and the card *brand* only |
| No card data in logs | Errors log a type and a truncated message, never a body |
| Secrets not in source | Stripe keys are Worker secrets; `wrangler.toml` is committed and holds none |
| TLS everywhere | Cloudflare and Firestore are HTTPS-only |
| Authenticated checkout | Firebase ID token verified server-side; caller must own the order |
| **Amount computed server-side** | `priceOrder()` recomputes from the stored order and *ignores* any client amount |
| Webhook authenticity | HMAC-SHA256 over the raw body, constant-time compare, 5-minute replay window |
| Idempotency | `Idempotency-Key` per booking; every Stripe event id recorded before processing |
| Client cannot self-settle | Firestore rules forbid clients writing any payment field — **verified: 403** |
| No caching of money responses | `Cache-Control: no-store` |
| Order ceiling | **$600** hard refusal per order; **$200** soft threshold flags rather than blocks |
| Velocity limits | **$800 / 6 orders** per account per rolling 24h — the control that actually stops card testing, which a per-order cap alone does not |

### 1.3 What you must do — not doable in code

1. **Complete SAQ A** at your acquirer's portal or Stripe's dashboard. Annual.
2. **Never enable Stripe's in-app card element** without redoing this analysis.
3. **Keep Stripe's own PCI attestation** on file (they publish it).
4. **Quarterly ASV scan** — usually *not* required for SAQ A. Confirm with
   your acquirer.
5. **Written incident-response plan.** Required even for SAQ A.

---

## 2. Money movement — the part that is not really about code

You are about to run a **marketplace**: customers pay you, and you pay shops
and couriers. That is different from taking payment for your own goods.

- **Use Stripe Connect with destination charges** (as coded). Stripe becomes
  the entity moving funds. The `transfer_data[destination]` and
  `application_fee_amount` parameters are already wired.
- **Do not take custody yourself.** Collecting into your own account and
  paying shops later can constitute **money transmission**, which is licensed
  state by state. The coded design avoids this deliberately.
- **Tax reporting.** Stripe issues 1099-K to connected accounts at threshold.
  Couriers paid as contractors may need **1099-NEC** from you. Confirm who
  files what before the first payout.
- **Shops must onboard to Stripe Connect** (KYC/AML — Stripe's identity
  checks). Until a shop has a connected account, `stripeAccountId` is empty
  and the charge goes to the platform; **do not go live in that state** for
  real shops.

---

## 3. California and US law

| Area | Status |
|---|---|
| **AB 5 / Prop 22** — courier classification | ⚠️ **Unresolved. Get a lawyer.** Prop 22's carve-out requires an earnings floor, healthcare stipend and occupational accident insurance. Contract wording alone does not qualify you. **This is the largest single legal risk.** |
| **CCPA/CPRA** | Below thresholds today. Privacy policy already promises no sale of data — keep it true. Access/deletion rights needed at scale |
| **Account deletion** | ❌ Not built. **Apple rejects apps that create accounts without in-app deletion.** Also a CCPA expectation |
| **Sales tax** | Groceries are largely exempt in CA, but *prepared* food is not, and delivery fees may be taxable. **Marketplace facilitator rules may make you liable for collecting.** Get advice before charging cards |
| **ADA / accessibility** | Not audited. US retail apps have been litigated under ADA Title III |
| **Gift-card / stored value** | Not applicable — no balances held |
| **BIPA / biometrics** | Not applicable — voice is processed transiently, not stored as a template |
| **COPPA** | No under-13 targeting |

---

## 4. SOC 2 — an honest gap analysis

Mapped to the Trust Services Criteria. **Present** means the control exists;
it does not mean an auditor has tested it.

| Criterion | State |
|---|---|
| CC6.1 Logical access | **Present** — Firebase Auth, rules-enforced, admin membership service-account only |
| CC6.6 External threats | **Partial** — Cloudflare in front; **no WAF rules, no per-user rate limiting** |
| CC6.7 Data in transit | **Present** — TLS throughout |
| CC6.8 Malicious software | **Partial** — no dependency scanning in CI |
| CC7.2 Monitoring | ❌ **Absent** — no alerting, no SIEM, no log retention |
| CC7.3 Incident response | ❌ **Absent** — no written plan |
| CC8.1 Change management | **Partial** — git, 117 tests, no PR review (single developer), no CI gate |
| CC9.2 Vendor management | ❌ **Absent** — no vendor register or reviews |
| A1.2 Availability | **Partial** — Supabase read standby; no RTO/RPO, **no backups** (Supabase free retains none) |
| C1.1 Confidentiality | **Present** — PII segregated; job board carries none |
| P — Privacy | **Partial** — policy exists; **no deletion mechanism** |

**Verdict: not SOC 2 ready.** The absent items are organisational, and none
can be produced by writing code. Realistically 3–6 months and a compliance
platform (Vanta/Drata ≈ $10–20k/yr) plus an auditor (≈ $15–30k) — and it is
usually only worth starting when an enterprise customer demands it. You do not
need it to take payments from grocery shoppers.

---

## 5. Still-open technical findings

These stand from the 1 August audit and are **not** fixed by the payment work.
Two now matter more, because money is involved.

| # | Finding | Severity | Why it matters more now |
|---|---|---|---|
| 1 | ~~Any signed-in user can write to any user's notification feed~~ | ~~HIGH~~ **FIXED** | A notification may now only be addressed to the other party of an order the sender is on — proved against the booking. Verified: stranger 403, third party via a real order 403, genuine customer→shop 200 |
| 2 | Delivery OTP verified on the device | **HIGH** ↑ | Was a dispute. Once orders are prepaid it is **goods released without proof of handover** |
| 3 | No per-user rate limit on either Worker | MEDIUM | Cost, and now checkout-session spam |
| 4 | Shared demo passwords on the sign-in screen | **BLOCKER** | **Must be off before any real card is charged** |
| 5 | No dependency scanning / CI gate | MEDIUM | SOC 2 CC8.1 |
| 6 | No backups of Firestore | MEDIUM | Spark has no scheduled export |

**Do not switch payments on until 2 and 4 are done.**

---

## 5a. Why the order limits are two numbers

A single hard cap has to be either too low or too useless. Set at $200 it
refuses a weekly family shop — the USDA's 2026 plans put a family of four at
$229–$376 a week, and San Francisco runs above the national figures, so the
best customer on the platform hits a wall with a full basket. Set high enough
to serve that customer, it stops being a fraud control.

So there are two, plus a third that does the real work:

| Limit | Value | Behaviour |
|---|---|---|
| Soft review | $200 | Order proceeds, `largeOrder: true` recorded |
| Hard ceiling | $600 | Refused, with the limit named in the message |
| Daily total | $800 / 24h | Refused with `429` |
| Daily count | 6 orders / 24h | Refused with `429` |

The velocity limits matter more than the per-order cap. Someone testing a
stolen card does not place one $5,000 order; they place several small ones
under whatever ceiling exists. Capping the day is what makes that
unprofitable, and it is what stops a shop waking up to a morning of
chargebacks from one compromised account.

The velocity check **fails open** if Firestore cannot be queried. A database
hiccup should not stop an honest customer buying milk, and the per-order
ceiling still applies.

---

## 6. Going live with payments

Nothing below happens automatically — payments stay off until `baseUrl` is set.

1. Create the Stripe account; stay in **test mode**.
2. `cd worker/payments && npx wrangler secret put STRIPE_SECRET_KEY` (and
   `STRIPE_WEBHOOK_SECRET`, `FIREBASE_API_KEY`, `FIREBASE_SA_JSON`), then
   `npx wrangler deploy`.
3. Point a Stripe webhook at `/pay/webhook` for `checkout.session.completed`,
   `charge.refunded`, `charge.dispute.created`.
4. Put the Worker URL in `lib/payment_config.dart`.
5. Test with Stripe's test cards, including **4000 0000 0000 0002** (declined)
   and a forced dispute.
6. Fix findings 1, 2 and 4 above.
7. Onboard shops to Stripe Connect.
8. Complete SAQ A. Write the incident-response plan.
9. Get the AB 5 / Prop 22 advice **before paying any courier**.
10. Only then switch to live keys.

**Never paste a live Stripe secret key into a chat, a commit, or a file.**
It goes into `wrangler secret put` and nowhere else.
