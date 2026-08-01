/**
 * LocalHive payments.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * THE ONE RULE: card data never reaches this worker, the Flutter app, or
 * Firestore. Not the PAN, not the CVV, not the expiry. The customer types
 * their card into a page served by Stripe, on Stripe's domain, and we only
 * ever see an opaque session id and, later, a signed webhook saying it was
 * paid.
 *
 * That is not a stylistic preference. It is the difference between PCI DSS
 * SAQ A — a couple of dozen questions a small merchant can self-attest —
 * and SAQ D, which is hundreds of controls and, in practice, an auditor.
 * Every design choice below exists to keep the card out of scope. If a
 * future change makes this service touch a card number, the compliance
 * burden changes category, and that decision needs to be made deliberately
 * rather than discovered.
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Deploy:
 *   cd worker/payments
 *   npx wrangler secret put STRIPE_SECRET_KEY       # sk_live_... or sk_test_...
 *   npx wrangler secret put STRIPE_WEBHOOK_SECRET   # whsec_...
 *   npx wrangler secret put FIREBASE_API_KEY        # to verify caller tokens
 *   npx wrangler secret put FIREBASE_SA_JSON        # service account, to write Firestore
 *   npx wrangler deploy
 *
 * Routes:
 *   POST /pay/session   signed-in customer → a Stripe Checkout URL
 *   POST /pay/webhook   Stripe → us, signature-verified
 *   GET  /pay/health    liveness, no secrets echoed
 */

const ALLOWED_ORIGINS = [
  'https://pradeepkb1906.github.io',
  'http://localhost:8090',
  'http://127.0.0.1:8090',
];

const PROJECT_ID = 'localhivelocalhive';
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Platform commission, in basis points, so the arithmetic stays in integers.
const PLATFORM_FEE_BPS = 1200; // 12.00%

// What a delivery costs the customer, and what the courier is paid. Mirrors
// lib/models/data.dart — the app displays these, this service charges them,
// and a mismatch would mean charging a number the customer never saw.
const DELIVERY_FEE_CENTS = 499;
const COURIER_BASE_CENTS = 499;
const COURIER_HELP_BONUS_CENTS = 300;

// A single order can never legitimately be this large. A cap is the cheapest
// insurance against a pricing bug becoming a five-figure charge.
const MAX_ORDER_CENTS = 100000; // $1,000

function corsHeaders(origin) {
  const allow =
    origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function json(body, status, origin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      // This service handles money. Nothing it returns should ever be cached
      // by a browser, a proxy, or Cloudflare itself.
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...corsHeaders(origin),
    },
  });
}

/* ───────────────────────── caller identity ───────────────────────── */

/**
 * Confirms the caller is a signed-in LocalHive user and returns their uid.
 *
 * The uid is then used to prove the caller owns the order being paid for.
 * Without this, anyone could create a Checkout Session against someone
 * else's booking — harmless in itself, but it would leak the basket.
 */
async function verifyCaller(request, apiKey) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!token) return { ok: false, reason: 'missing token' };
  if (!apiKey) return { ok: false, reason: 'proxy misconfigured' };
  try {
    const r = await fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
        encodeURIComponent(apiKey),
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: token }),
      },
    );
    if (!r.ok) return { ok: false, reason: 'token rejected' };
    const info = await r.json();
    const u = info.users && info.users[0];
    if (!u || !u.localId) return { ok: false, reason: 'no user' };
    // An unverified email can still order — but it is recorded on the
    // payment, because chargeback disputes turn on who the buyer was.
    return { ok: true, uid: u.localId, email: u.email || '', emailVerified: !!u.emailVerified };
  } catch {
    return { ok: false, reason: 'verification failed' };
  }
}

/* ──────────────────── Firestore, as the service account ──────────────────── */

/**
 * Mints a Google access token from the service account, by signing a JWT
 * with Web Crypto. Cached in module scope for its lifetime, because minting
 * one costs a round trip and these workers handle bursts.
 */
let _tokenCache = { token: null, expiresAt: 0 };

async function googleAccessToken(env, now) {
  if (_tokenCache.token && now < _tokenCache.expiresAt - 60_000) {
    return _tokenCache.token;
  }
  const sa = JSON.parse(env.FIREBASE_SA_JSON);
  const iat = Math.floor(now / 1000);
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    exp: iat + 3600,
    iat,
  };
  const b64url = (obj) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const unsigned = `${b64url({ alg: 'RS256', typ: 'JWT' })}.${b64url(claim)}`;

  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')}`;

  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' +
      encodeURIComponent(jwt),
  });
  if (!r.ok) throw new Error('could not mint a service token');
  const t = await r.json();
  _tokenCache = { token: t.access_token, expiresAt: now + t.expires_in * 1000 };
  return t.access_token;
}

/** Unwraps Firestore's typed-value JSON into ordinary JavaScript. */
function plain(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) {
    if ('stringValue' in v) out[k] = v.stringValue;
    else if ('integerValue' in v) out[k] = parseInt(v.integerValue, 10);
    else if ('doubleValue' in v) out[k] = v.doubleValue;
    else if ('booleanValue' in v) out[k] = v.booleanValue;
    else if ('timestampValue' in v) out[k] = v.timestampValue;
    else if ('mapValue' in v) out[k] = plain(v.mapValue.fields);
    else if ('arrayValue' in v)
      out[k] = (v.arrayValue.values || []).map((e) =>
        e.mapValue ? plain(e.mapValue.fields) : Object.values(e)[0],
      );
  }
  return out;
}

async function getDoc(env, path, now) {
  const tok = await googleAccessToken(env, now);
  const r = await fetch(`${FS}/${path}`, {
    headers: { Authorization: `Bearer ${tok}` },
  });
  if (!r.ok) return null;
  const d = await r.json();
  return plain(d.fields);
}

async function patchDoc(env, path, fields, mask, now) {
  const tok = await googleAccessToken(env, now);
  const q = mask.map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const r = await fetch(`${FS}/${path}?${q}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  return r.ok;
}

/* ──────────────────────────── pricing ──────────────────────────── */

/**
 * Recomputes what this order costs, from the order itself.
 *
 * The client sends a booking id and nothing else about money. It never sends
 * an amount, and if it did this would ignore it. A checkout that trusts a
 * client-supplied total is the classic e-commerce hole: the page says
 * $84.20, the request says 1 cent, and the server charges 1 cent.
 *
 * Everything is integer cents. Money in floating point accumulates error —
 * 0.1 + 0.2 is famously not 0.3 — and "close enough" is not a thing that
 * exists on a card statement.
 */
function priceOrder(booking) {
  const lines = Array.isArray(booking.items) ? booking.items : [];
  if (lines.length === 0) return { error: 'this order has no items' };

  let subtotal = 0;
  for (const l of lines) {
    const qty = Number(l.qty);
    // unitPrice is stored in dollars on the booking; round to the nearest
    // cent once, here, rather than letting a fraction ride through.
    const unit = Math.round(Number(l.unitPrice) * 100);
    if (!Number.isFinite(qty) || !Number.isFinite(unit)) {
      return { error: 'this order has a malformed line' };
    }
    if (qty <= 0 || qty > 99) return { error: 'implausible quantity' };
    if (unit < 0 || unit > 100000) return { error: 'implausible unit price' };
    subtotal += qty * unit;
  }

  const isDelivery = booking.fulfillment === 'delivery';
  const delivery = isDelivery ? DELIVERY_FEE_CENTS : 0;
  const platformFee = Math.round((subtotal * PLATFORM_FEE_BPS) / 10000);
  const total = subtotal + platformFee + delivery;

  if (total <= 0) return { error: 'nothing to charge' };
  if (total > MAX_ORDER_CENTS) return { error: 'order exceeds the single-order limit' };

  // What the courier earns. Paid out of the platform's commission, not added
  // to the customer's bill — a customer who needs help to the door must not
  // pay more for needing it.
  const courierPay = isDelivery
    ? COURIER_BASE_CENTS + (booking.needsHelp ? COURIER_HELP_BONUS_CENTS : 0)
    : 0;

  return { subtotal, platformFee, delivery, total, courierPay };
}

/* ─────────────────── Stripe webhook signature ─────────────────── */

/** Constant-time compare, so a signature cannot be guessed a byte at a time. */
function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Verifies Stripe's `Stripe-Signature` header over the RAW body.
 *
 * This is the whole security model of the webhook: without it, anyone who
 * learns the URL can POST "this order was paid" and get goods for free. The
 * body must be the exact bytes Stripe sent — parsing and re-serialising
 * changes the signature and every event would fail.
 *
 * The timestamp check makes a captured-and-replayed event stale. Stripe's
 * own tolerance is five minutes.
 */
async function verifyStripeSignature(rawBody, header, secret, nowSeconds) {
  if (!header || !secret) return false;
  const parts = Object.fromEntries(
    header.split(',').map((p) => p.split('=').map((x) => x.trim())),
  );
  const t = parts.t;
  const v1 = parts.v1;
  if (!t || !v1) return false;

  const age = Math.abs(nowSeconds - parseInt(t, 10));
  if (!Number.isFinite(age) || age > 300) return false; // replay window

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${t}.${rawBody}`),
  );
  const expected = [...new Uint8Array(mac)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return timingSafeEqual(expected, v1);
}

/* ──────────────────────────── handlers ──────────────────────────── */

async function createSession(request, env, origin, now) {
  const caller = await verifyCaller(request, env.FIREBASE_API_KEY);
  if (!caller.ok) return json({ error: 'Sign-in required' }, 401, origin);

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Body must be JSON' }, 400, origin);
  }
  const bookingId = String(body.bookingId || '').trim();
  // Firestore ids are opaque; refuse anything that could be a path traversal
  // into another collection.
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(bookingId)) {
    return json({ error: 'bookingId is not valid' }, 400, origin);
  }

  const booking = await getDoc(env, `bookings/${bookingId}`, now);
  if (!booking) return json({ error: 'No such order' }, 404, origin);

  // The caller must own the order. Proved server-side against the stored
  // document, never against anything the client asserted.
  if (booking.userId !== caller.uid) {
    return json({ error: 'Not your order' }, 403, origin);
  }
  if (booking.paymentStatus === 'paid') {
    return json({ error: 'This order is already paid' }, 409, origin);
  }
  if (['Cancelled', 'Declined'].includes(booking.status)) {
    return json({ error: 'This order is no longer active' }, 409, origin);
  }

  const price = priceOrder(booking);
  if (price.error) return json({ error: price.error }, 400, origin);

  // Where the shop's money goes. A connected account means Stripe moves the
  // funds and is the money transmitter; without one, we would be taking
  // custody of other people's money, which is a licensing question rather
  // than an engineering one.
  const shopAccount = booking.stripeAccountId || '';

  const form = new URLSearchParams();
  form.set('mode', 'payment');
  form.set('client_reference_id', bookingId);
  form.set('customer_email', caller.email);
  form.set('success_url', `${ALLOWED_ORIGINS[0]}/LocalHive/#/orders?paid=1`);
  form.set('cancel_url', `${ALLOWED_ORIGINS[0]}/LocalHive/#/orders?cancelled=1`);
  form.set('line_items[0][price_data][currency]', 'usd');
  form.set('line_items[0][price_data][unit_amount]', String(price.total));
  form.set(
    'line_items[0][price_data][product_data][name]',
    `LocalHive order · ${String(booking.providerName || 'Grocery order').slice(0, 80)}`,
  );
  form.set('line_items[0][quantity]', '1');
  // Read back by the webhook. Kept small and non-personal: metadata is
  // visible in the Stripe dashboard and in exported reports.
  form.set('metadata[bookingId]', bookingId);
  form.set('metadata[uid]', caller.uid);
  form.set('metadata[courierPayCents]', String(price.courierPay));
  form.set('metadata[platformFeeCents]', String(price.platformFee));
  // Expire quickly: an abandoned session should not be payable tomorrow at
  // yesterday's price.
  form.set('expires_at', String(Math.floor(now / 1000) + 1800));

  if (shopAccount) {
    // Destination charge: the shop is paid, we keep the commission, and the
    // courier's fee comes out of that commission rather than the shop's
    // takings.
    const applicationFee = Math.max(0, price.platformFee + price.delivery);
    form.set('payment_intent_data[application_fee_amount]', String(applicationFee));
    form.set('payment_intent_data[transfer_data][destination]', shopAccount);
  }

  const r = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + env.STRIPE_SECRET_KEY,
      'Content-Type': 'application/x-www-form-urlencoded',
      // Same order, same session: a double-tap or a retried request must not
      // create two payable sessions for one basket.
      'Idempotency-Key': `booking_${bookingId}`,
      'Stripe-Version': '2024-06-20',
    },
    body: form.toString(),
  });
  const out = await r.json();
  if (!r.ok) {
    // Stripe's message can name internal details; log nothing, return little.
    console.log('stripe session failed', r.status, out.error && out.error.type);
    return json({ error: 'Could not start checkout' }, 502, origin);
  }

  // Record the intent. The booking is NOT marked paid here — only a signed
  // webhook may do that. A client that closes the tab mid-payment must not
  // leave an order that looks settled.
  await patchDoc(
    env,
    `bookings/${bookingId}`,
    {
      paymentStatus: { stringValue: 'pending' },
      paymentSessionId: { stringValue: out.id },
      amountCents: { integerValue: String(price.total) },
      currency: { stringValue: 'usd' },
    },
    ['paymentStatus', 'paymentSessionId', 'amountCents', 'currency'],
    now,
  );

  return json(
    { url: out.url, sessionId: out.id, amountCents: price.total, breakdown: price },
    200,
    origin,
  );
}

async function handleWebhook(request, env, origin, now) {
  // RAW body. Parsing first would change the bytes and break the signature.
  const raw = await request.text();
  const ok = await verifyStripeSignature(
    raw,
    request.headers.get('Stripe-Signature'),
    env.STRIPE_WEBHOOK_SECRET,
    Math.floor(now / 1000),
  );
  if (!ok) {
    // Deliberately terse: an attacker probing this endpoint learns nothing
    // about why their forgery failed.
    return json({ error: 'bad signature' }, 400, origin);
  }

  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    return json({ error: 'bad payload' }, 400, origin);
  }

  // Stripe retries, and retries can arrive out of order or more than once.
  // Recording the event id first makes the whole handler idempotent.
  const seen = await getDoc(env, `stripe_events/${event.id}`, now);
  if (seen) return json({ received: true, duplicate: true }, 200, origin);
  await patchDoc(
    env,
    `stripe_events/${event.id}`,
    {
      type: { stringValue: String(event.type) },
      receivedAt: { timestampValue: new Date(now).toISOString() },
    },
    ['type', 'receivedAt'],
    now,
  );

  if (event.type === 'checkout.session.completed') {
    const s = event.data.object;
    const bookingId = (s.metadata && s.metadata.bookingId) || s.client_reference_id;
    if (bookingId && s.payment_status === 'paid') {
      const booking = await getDoc(env, `bookings/${bookingId}`, now);
      // Charge what we asked for, and nothing else. If the amount that came
      // back does not match what this order was priced at, something is
      // wrong and a human should look rather than the goods being released.
      const expected = booking && Number(booking.amountCents);
      if (Number.isFinite(expected) && Number(s.amount_total) !== expected) {
        await patchDoc(
          env,
          `bookings/${bookingId}`,
          { paymentStatus: { stringValue: 'mismatch' } },
          ['paymentStatus'],
          now,
        );
        console.log('amount mismatch', bookingId);
        return json({ received: true, flagged: 'amount_mismatch' }, 200, origin);
      }
      await patchDoc(
        env,
        `bookings/${bookingId}`,
        {
          paymentStatus: { stringValue: 'paid' },
          paidAt: { timestampValue: new Date(now).toISOString() },
          paymentIntentId: { stringValue: String(s.payment_intent || '') },
          // Only ever the brand and last four, which Stripe classes as
          // non-sensitive and which a customer needs to recognise the charge.
          // The full number never exists anywhere in this system.
          cardBrand: { stringValue: String((s.payment_method_types || [])[0] || 'card') },
        },
        ['paymentStatus', 'paidAt', 'paymentIntentId', 'cardBrand'],
        now,
      );
    }
  }

  if (
    event.type === 'charge.refunded' ||
    event.type === 'charge.dispute.created'
  ) {
    const c = event.data.object;
    const bookingId = (c.metadata && c.metadata.bookingId) || '';
    if (bookingId) {
      await patchDoc(
        env,
        `bookings/${bookingId}`,
        {
          paymentStatus: {
            stringValue: event.type === 'charge.refunded' ? 'refunded' : 'disputed',
          },
        },
        ['paymentStatus'],
        now,
      );
    }
  }

  return json({ received: true }, 200, origin);
}

// Exported for the test suite. Pricing and signature verification are the
// two pieces where a mistake costs real money, so they are tested directly
// rather than only through a live request.
export { priceOrder, verifyStripeSignature, timingSafeEqual };

export default {
  async fetch(request, env) {
    const origin = request.headers.get('Origin');
    const url = new URL(request.url);
    const now = Date.now();

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (url.pathname === '/pay/health') {
      // Says whether it is configured, never what with.
      return json(
        {
          ok: true,
          stripe: !!env.STRIPE_SECRET_KEY,
          webhook: !!env.STRIPE_WEBHOOK_SECRET,
          firestore: !!env.FIREBASE_SA_JSON,
        },
        200,
        origin,
      );
    }
    if (request.method !== 'POST') {
      return json({ error: 'POST only' }, 405, origin);
    }
    if (!env.STRIPE_SECRET_KEY) {
      return json({ error: 'Payments are not configured' }, 503, origin);
    }

    try {
      if (url.pathname === '/pay/webhook') {
        return await handleWebhook(request, env, origin, now);
      }
      if (url.pathname === '/pay/session') {
        return await createSession(request, env, origin, now);
      }
    } catch (e) {
      // Never surface an exception message to a caller: they can carry stack
      // frames, ids and occasionally configuration.
      console.log('payment error', String(e && e.message).slice(0, 200));
      return json({ error: 'Payment service error' }, 500, origin);
    }

    return json({ error: 'Not found' }, 404, origin);
  },
};
