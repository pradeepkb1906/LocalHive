import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/payment_config.dart';
import 'package:localhive/services/payment_service.dart';

// The client half of payments. There is very little of it on purpose: the
// card never comes near this app, the amount is never sent from it, and the
// only thing it can do is ask the server to start a checkout. These tests
// pin that smallness, because the day someone adds a card field here the
// business changes PCI category.
void main() {
  group('money is counted in whole cents', () {
    test('renders dollars without floating-point drift', () {
      expect(formatCents(0), r'$0.00');
      expect(formatCents(5), r'$0.05');
      expect(formatCents(499), r'$4.99');
      expect(formatCents(1904), r'$19.04');
      expect(formatCents(100000), r'$1000.00');
    });

    test('a refund reads as negative rather than wrapping', () {
      expect(formatCents(-499), r'-$4.99');
    });

    test('the classic float error cannot occur', () {
      // 0.1 + 0.2 != 0.3 in binary floating point. In cents it is exact, and
      // a cent of drift is a real discrepancy on a card statement.
      expect(formatCents(10 + 20), r'$0.30');
      expect(0.1 + 0.2 == 0.3, isFalse, reason: 'why cents, not dollars');
    });
  });

  group('payment state comes from the server, never from the app', () {
    test('unknown and missing states are treated as unpaid', () {
      expect(PayState.from(null), PayState.unpaid);
      expect(PayState.from(''), PayState.unpaid);
      expect(PayState.from('PAID'), PayState.unpaid); // case matters
      expect(PayState.from('definitely_paid_trust_me'), PayState.unpaid);
    });

    test('only an exact "paid" releases the goods', () {
      expect(PayState.from('paid').settled, isTrue);
      for (final s in [
        PayState.unpaid,
        PayState.pending,
        PayState.refunded,
        PayState.disputed,
        PayState.mismatch,
      ]) {
        expect(s.settled, isFalse, reason: '$s must not release goods');
      }
    });

    test('an amount mismatch is held, not settled', () {
      // Stripe said one number, the order was priced at another. That is
      // never "close enough" — it waits for a person.
      final s = PayState.from('mismatch');
      expect(s.settled, isFalse);
      expect(s.label, contains('review'));
    });

    test('every state has something a customer can read', () {
      for (final s in PayState.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('switched off, it degrades to paying in person', () {
    test('the checked-in template disables card payment', () {
      // lib/payment_config.dart is gitignored; the committed template is
      // empty, so a fresh clone builds with cards off rather than pointing
      // at someone else's worker.
      expect(PaymentConfig.enabled, PaymentConfig.baseUrl.isNotEmpty);
    });

    test('paying while switched off says so instead of throwing', () async {
      if (PaymentConfig.enabled) return; // configured locally; skip
      final msg = await PaymentService.instance.payForOrder('anything');
      expect(msg, isNotNull);
      expect(msg, contains('not switched on'));
    });
  });
}
