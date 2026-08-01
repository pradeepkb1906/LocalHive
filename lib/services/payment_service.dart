import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../payment_config.dart';
import 'firebase_service.dart';

/// Taking payment for an order.
///
/// This class deliberately has no card fields, no card widget, and no way to
/// accept a card number. The customer is sent to a page hosted by Stripe, on
/// Stripe's domain, and comes back with nothing but an order id. The card is
/// never typed into LocalHive, never travels through LocalHive's servers and
/// is never stored anywhere in this system.
///
/// That is what keeps LocalHive inside PCI DSS SAQ A — the short
/// self-assessment for merchants who fully outsource card handling — instead
/// of SAQ D, which is a different order of magnitude of obligation. Adding an
/// in-app card form would move the whole business into that second category,
/// so it is a decision to be taken deliberately, not a UI convenience.
///
/// The amount is NOT sent from here. The server recomputes it from the stored
/// order. A checkout that trusts a client-supplied total is the oldest hole in
/// e-commerce: the screen says $84.20, the request says one cent.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  @visibleForTesting
  http.Client client = http.Client();

  bool get enabled => PaymentConfig.enabled;

  /// Starts checkout for [bookingId] and hands the customer to Stripe.
  ///
  /// Returns null on success (the browser has navigated away) or a message
  /// to show if it could not start. Never throws: a customer at a checkout
  /// screen needs a sentence they can act on, not a stack trace.
  Future<String?> payForOrder(String bookingId) async {
    if (!enabled) return 'Card payment is not switched on yet.';

    final token = await FirebaseService.instance.currentUser?.getIdToken();
    if (token == null) return 'Please sign in again to pay.';

    try {
      final resp = await client
          .post(
            Uri.parse('${PaymentConfig.baseUrl}/pay/session'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            // The order id and nothing else. No amount, no items, no prices —
            // the server already has all of that and does not ask us.
            body: jsonEncode({'bookingId': bookingId}),
          )
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode != 200) {
        return switch (resp.statusCode) {
          401 => 'Please sign in again to pay.',
          403 => 'That order belongs to a different account.',
          409 => '${body['error'] ?? 'This order can no longer be paid.'}',
          _ => 'Could not start checkout. Please try again.',
        };
      }

      final url = '${body['url'] ?? ''}';
      if (url.isEmpty) return 'Could not start checkout. Please try again.';

      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return ok ? null : 'Could not open the payment page.';
    } catch (e) {
      // The message is never surfaced: it can carry URLs and ids.
      debugPrint('checkout failed: $e');
      return 'Could not reach the payment service. Please try again.';
    }
  }
}

/// Where an order stands with money.
///
/// Only ever set by the payment worker after Stripe has told it, over a
/// signed webhook, what actually happened. Nothing the app does moves an
/// order into [paid].
enum PayState {
  /// No card payment attempted — the customer pays the shop in person.
  unpaid,

  /// Checkout started; Stripe has not confirmed yet.
  pending,

  /// Stripe confirmed the money. The only state that releases goods.
  paid,

  /// Paid, then refunded.
  refunded,

  /// The cardholder disputed the charge. A human deals with this.
  disputed,

  /// Stripe reported an amount that did not match what the order was priced
  /// at. Never treated as paid — it is held for a person to look at.
  mismatch;

  static PayState from(String? raw) => switch (raw) {
        'pending' => PayState.pending,
        'paid' => PayState.paid,
        'refunded' => PayState.refunded,
        'disputed' => PayState.disputed,
        'mismatch' => PayState.mismatch,
        _ => PayState.unpaid,
      };

  /// Whether the shop should hand the goods over.
  bool get settled => this == PayState.paid;

  String get label => switch (this) {
        PayState.unpaid => 'Pay in person',
        PayState.pending => 'Payment in progress',
        PayState.paid => 'Paid',
        PayState.refunded => 'Refunded',
        PayState.disputed => 'Payment disputed',
        PayState.mismatch => 'Payment held for review',
      };
}

/// Renders integer cents as dollars.
///
/// Money is carried as whole cents everywhere it is computed. Floating point
/// accumulates error — 0.1 + 0.2 is not 0.3 — and a rounding drift that is
/// invisible in a total is a real discrepancy on a card statement and in a
/// shop's books.
String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final a = cents.abs();
  return '$sign\$${(a ~/ 100)}.${(a % 100).toString().padLeft(2, '0')}';
}
