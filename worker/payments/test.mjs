// Pricing and webhook-signature tests for the payment worker.
//
// These two functions are where a bug is a financial loss rather than a bad
// screen: one decides what a customer is charged, the other decides whether
// a "you have been paid" message is genuine. Run: node worker/payments/test.mjs
import assert from 'node:assert';
import { priceOrder, verifyStripeSignature, timingSafeEqual } from './src/index.js';
import { createHmac } from 'node:crypto';

let passed = 0;
const test = (name, fn) => {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    console.error(`  ✗ ${name}\n    ${e.message}`);
    process.exitCode = 1;
  }
};
const atest = async (name, fn) => {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    console.error(`  ✗ ${name}\n    ${e.message}`);
    process.exitCode = 1;
  }
};

console.log('\npricing — the server decides what is charged, never the client');

test('a pickup order is subtotal plus the platform fee', () => {
  const p = priceOrder({
    fulfillment: 'pickup',
    items: [{ qty: 2, unitPrice: 3.5 }, { qty: 1, unitPrice: 10.0 }],
  });
  assert.equal(p.subtotal, 1700);       // $17.00
  assert.equal(p.platformFee, 204);     // 12% = $2.04
  assert.equal(p.delivery, 0);
  assert.equal(p.total, 1904);          // $19.04
  assert.equal(p.courierPay, 0);
});

test('a delivery order adds the delivery fee', () => {
  const p = priceOrder({
    fulfillment: 'delivery',
    items: [{ qty: 1, unitPrice: 10.0 }],
  });
  assert.equal(p.delivery, 499);
  assert.equal(p.total, 1000 + 120 + 499);
  assert.equal(p.courierPay, 499);
});

test('help to the door pays the courier more, and the customer no more', () => {
  const base = priceOrder({ fulfillment: 'delivery', items: [{ qty: 1, unitPrice: 10.0 }] });
  const helped = priceOrder({
    fulfillment: 'delivery', needsHelp: true, items: [{ qty: 1, unitPrice: 10.0 }],
  });
  // The whole point: the bill is identical.
  assert.equal(helped.total, base.total);
  assert.equal(helped.courierPay, base.courierPay + 300);
});

test('a client-supplied amount is ignored entirely', () => {
  const p = priceOrder({
    fulfillment: 'pickup',
    items: [{ qty: 1, unitPrice: 50.0 }],
    // Everything a hostile client might try to smuggle in:
    amount: 0.01, total: 1, amountCents: 1, platformFee: 0,
  });
  assert.equal(p.total, 5000 + 600);
});

test('rounding lands on whole cents', () => {
  // 3 x $0.07 = $0.21, fee 12% = 2.52c -> 3c. No fractional cents anywhere.
  const p = priceOrder({ fulfillment: 'pickup', items: [{ qty: 3, unitPrice: 0.07 }] });
  assert.equal(p.subtotal, 21);
  assert.equal(p.platformFee, 3);
  assert.equal(p.total, 24);
  assert.ok(Number.isInteger(p.total));
});

test('an empty order cannot be charged', () => {
  assert.ok(priceOrder({ fulfillment: 'pickup', items: [] }).error);
  assert.ok(priceOrder({ fulfillment: 'pickup' }).error);
});

test('nonsense quantities and prices are refused, not rounded away', () => {
  assert.ok(priceOrder({ items: [{ qty: -1, unitPrice: 5 }] }).error);
  assert.ok(priceOrder({ items: [{ qty: 1e6, unitPrice: 5 }] }).error);
  assert.ok(priceOrder({ items: [{ qty: 1, unitPrice: -5 }] }).error);
  assert.ok(priceOrder({ items: [{ qty: 'x', unitPrice: 5 }] }).error);
  assert.ok(priceOrder({ items: [{ qty: 1, unitPrice: 'free' }] }).error);
});

test('an implausibly large order is capped rather than charged', () => {
  assert.ok(priceOrder({ items: [{ qty: 99, unitPrice: 999 }] }).error);
});

console.log('\nwebhook signature — the only thing that says money arrived');

const SECRET = 'whsec_test_secret';
const sign = (body, ts) =>
  `t=${ts},v1=${createHmac('sha256', SECRET).update(`${ts}.${body}`).digest('hex')}`;

await atest('a genuine Stripe signature verifies', async () => {
  const now = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({ id: 'evt_1', type: 'checkout.session.completed' });
  assert.equal(await verifyStripeSignature(body, sign(body, now), SECRET, now), true);
});

await atest('a forged signature is rejected', async () => {
  const now = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({ id: 'evt_2' });
  assert.equal(
    await verifyStripeSignature(body, `t=${now},v1=${'0'.repeat(64)}`, SECRET, now), false);
});

await atest('a tampered body invalidates a real signature', async () => {
  const now = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({ id: 'evt_3', amount: 100 });
  const header = sign(body, now);
  const tampered = JSON.stringify({ id: 'evt_3', amount: 1 });
  assert.equal(await verifyStripeSignature(tampered, header, SECRET, now), false);
});

await atest('a captured event replayed hours later is stale', async () => {
  const then = Math.floor(Date.now() / 1000) - 3600;
  const body = JSON.stringify({ id: 'evt_4' });
  assert.equal(
    await verifyStripeSignature(body, sign(body, then), SECRET, Math.floor(Date.now() / 1000)),
    false);
});

await atest('the wrong secret does not verify', async () => {
  const now = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({ id: 'evt_5' });
  assert.equal(await verifyStripeSignature(body, sign(body, now), 'whsec_other', now), false);
});

await atest('a missing or malformed header is refused', async () => {
  const now = Math.floor(Date.now() / 1000);
  assert.equal(await verifyStripeSignature('{}', '', SECRET, now), false);
  assert.equal(await verifyStripeSignature('{}', 'garbage', SECRET, now), false);
  assert.equal(await verifyStripeSignature('{}', 't=abc,v1=zz', SECRET, now), false);
});

test('signature comparison is length-safe', () => {
  assert.equal(timingSafeEqual('abc', 'abc'), true);
  assert.equal(timingSafeEqual('abc', 'abd'), false);
  assert.equal(timingSafeEqual('abc', 'abcd'), false);
});

console.log(`\n${passed} assertions passed\n`);
