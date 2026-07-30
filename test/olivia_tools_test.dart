import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/data.dart';
import 'package:localhive/services/geo.dart';
import 'package:localhive/services/olivia/order_draft.dart';

/// Olivia's money maths and the safety property that matters most: a draft is
/// only ever a proposal. If these drift, customers get charged the wrong
/// amount or an order goes through without anyone confirming it.
void main() {
  group('order draft totals', () {
    OrderDraft foodOrder({
      String fulfillment = 'pickup',
      String address = '',
      List<DraftLine>? lines,
    }) =>
        OrderDraft(
          kind: 'order',
          providerId: 'ft1',
          providerName: 'Bombay Street Eats',
          category: 'food_truck',
          fulfillment: fulfillment,
          address: address,
          pickupEta: fulfillment == 'pickup' ? 'In 30 min' : '',
          lines: lines ??
              const [
                DraftLine(name: 'Chicken Biryani', qty: 2, unitPrice: 12.99),
              ],
        );

    test('applies the 12% platform fee to a pickup order', () {
      final d = foodOrder();
      expect(d.subtotal, closeTo(25.98, 0.001));
      expect(d.platformFee, closeTo(25.98 * platformFeePct, 0.001));
      expect(d.deliveryCharge, 0);
      expect(d.total, closeTo(25.98 * 1.12, 0.001));
    });

    test('adds the delivery fee on top of the platform fee', () {
      final d = foodOrder(
          fulfillment: 'delivery', address: '120 Oak Tree Rd, Iselin, NJ');
      expect(d.deliveryCharge, OrderDraft.deliveryFee);
      expect(d.total, closeTo(25.98 * 1.12 + 4.99, 0.001));
    });

    test('sums mixed line items', () {
      final d = foodOrder(lines: const [
        DraftLine(name: 'Chicken Biryani', qty: 2, unitPrice: 12.99),
        DraftLine(name: 'Masala Chai', qty: 3, unitPrice: 2.50),
      ]);
      expect(d.subtotal, closeTo(25.98 + 7.50, 0.001));
      expect(d.itemCount, 5);
    });

    test('prices a home service by the hour', () {
      const d = OrderDraft(
        kind: 'home_service',
        providerId: 'hs1',
        providerName: 'Maria G.',
        category: 'home_service',
        hours: 3,
        hourlyRate: 28,
        dayLabel: 'Tomorrow',
        slot: '10:00 AM',
        address: '45 Oak Tree Rd, Edison, NJ',
      );
      expect(d.subtotal, closeTo(84, 0.001));
      expect(d.total, closeTo(84 * 1.12, 0.001));
      expect(d.deliveryCharge, 0);
    });
  });

  group('a draft refuses to be confirmed while incomplete', () {
    test('delivery without an address is blocked', () {
      const d = OrderDraft(
        kind: 'order',
        providerId: 'ft1',
        providerName: 'Bombay Street Eats',
        category: 'food_truck',
        fulfillment: 'delivery',
        lines: [DraftLine(name: 'Vada Pav', qty: 1, unitPrice: 4.50)],
      );
      expect(d.isReady, isFalse);
      expect(d.blockers.first, contains('address'));
    });

    test('an order with no items is blocked', () {
      const d = OrderDraft(
        kind: 'order',
        providerId: 'ft1',
        providerName: 'Bombay Street Eats',
        category: 'food_truck',
        fulfillment: 'pickup',
      );
      expect(d.isReady, isFalse);
    });

    test('a complete pickup order is ready', () {
      const d = OrderDraft(
        kind: 'order',
        providerId: 'ft1',
        providerName: 'Bombay Street Eats',
        category: 'food_truck',
        fulfillment: 'pickup',
        pickupEta: 'In 30 min',
        lines: [DraftLine(name: 'Vada Pav', qty: 1, unitPrice: 4.50)],
      );
      expect(d.isReady, isTrue);
    });
  });

  group('the booking a draft produces', () {
    test('records the actual items, not just a count', () {
      const d = OrderDraft(
        kind: 'order',
        providerId: 'ft1',
        providerName: 'Bombay Street Eats',
        category: 'food_truck',
        fulfillment: 'pickup',
        pickupEta: 'In 30 min',
        lines: [
          DraftLine(name: 'Chicken Biryani', qty: 2, unitPrice: 12.99),
          DraftLine(name: 'Masala Chai', qty: 1, unitPrice: 2.50),
        ],
      );
      final b = d.toBooking();
      expect(b.detail, contains('2 × Chicken Biryani'));
      expect(b.detail, contains('1 × Masala Chai'));
      expect(b.status, 'Placed');
      expect(b.providerId, 'ft1');
      expect(b.fulfillment, 'pickup');
    });

    test('a home service is Requested, with no fulfillment', () {
      const d = OrderDraft(
        kind: 'home_service',
        providerId: 'hs1',
        providerName: 'Maria G.',
        category: 'home_service',
        hours: 3,
        hourlyRate: 28,
        dayLabel: 'Tomorrow',
        slot: '10:00 AM',
        address: '45 Oak Tree Rd, Edison, NJ',
      );
      final b = d.toBooking();
      expect(b.status, 'Requested');
      expect(b.fulfillment, isEmpty);
      expect(b.detail, contains('Tomorrow'));
      expect(b.detail, contains('3 hrs'));
    });

    test('never claims a payment was taken', () {
      final json = OrderDraft(
        kind: 'order',
        providerId: 'ft1',
        providerName: 'Bombay Street Eats',
        category: 'food_truck',
        fulfillment: 'pickup',
        pickupEta: 'In 30 min',
        lines: const [DraftLine(name: 'Vada Pav', qty: 1, unitPrice: 4.50)],
      ).toJson();
      expect(json['payment'].toString().toLowerCase(), contains('in person'));
      // The model must understand a draft is not an order.
      expect(json['note'].toString().toLowerCase(), contains('draft'));
    });
  });

  group('opening hours', () {
    test('a listing with no stated hours counts as open', () {
      expect(isOpenAt('', '', DateTime(2026, 7, 30, 3)), isTrue);
    });

    test('a normal daytime window', () {
      expect(isOpenAt('9 AM', '6 PM', DateTime(2026, 7, 30, 12)), isTrue);
      expect(isOpenAt('9 AM', '6 PM', DateTime(2026, 7, 30, 7)), isFalse);
      expect(isOpenAt('9 AM', '6 PM', DateTime(2026, 7, 30, 22)), isFalse);
    });

    test('a window that runs past midnight', () {
      expect(isOpenAt('6 PM', '2 AM', DateTime(2026, 7, 30, 23)), isTrue);
      expect(isOpenAt('6 PM', '2 AM', DateTime(2026, 7, 30, 1)), isTrue);
      expect(isOpenAt('6 PM', '2 AM', DateTime(2026, 7, 30, 10)), isFalse);
    });

    test('unparseable hours do not close a business', () {
      expect(isOpenAt('whenever', 'late', DateTime(2026, 7, 30, 12)), isTrue);
    });
  });

  group('distance', () {
    test('measures a known short hop', () {
      // Bombay Street Eats to Hyderabad House, both in the seed data.
      final km = distanceKm(40.5629, -74.3390, 40.5754, -74.3223);
      expect(km, greaterThan(1.5));
      expect(km, lessThan(2.5));
    });

    test('reads out in metres below a kilometre', () {
      expect(distanceLabel(0.4), '400 m');
      expect(distanceLabel(2.35), '2.4 km');
    });
  });
}
