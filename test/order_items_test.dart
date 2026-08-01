import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/data.dart';
import 'package:localhive/services/olivia/order_draft.dart';
import 'package:localhive/theme.dart';
import 'package:localhive/widgets/order_items_view.dart';

/// Until now a booking recorded only "Delivery order · 3 items", so nobody —
/// not the store packing it, not the customer, not the courier — could see what
/// was actually ordered. These cover the contents surviving the trip to
/// Firestore and back, and each audience seeing the right amount of it.
void main() {
  Booking order({
    List<OrderLine> items = const [],
    double amount = 0,
    String fulfillment = 'delivery',
  }) =>
      Booking('Patel Brothers', 'Delivery order', 'Placed', amount,
          items: items, fulfillment: fulfillment, category: 'indian_store');

  const biryani =
      OrderLine(name: 'Chicken Biryani', qty: 2, unitPrice: 12.99, emoji: '🍛');
  const naan = OrderLine(name: 'Garlic Naan', qty: 1, unitPrice: 3.50);

  group('order lines', () {
    test('survive the round trip through Firestore', () {
      const line = OrderLine(
          name: 'Toor Dal',
          qty: 3,
          unitPrice: 4.25,
          unit: '1 kg bag',
          emoji: '🫘');
      final back = OrderLine.fromMap(line.toMap());
      expect(back.name, line.name);
      expect(back.qty, line.qty);
      expect(back.unitPrice, line.unitPrice);
      expect(back.unit, line.unit);
      expect(back.emoji, line.emoji);
      expect(back.lineTotal, closeTo(12.75, 0.001));
    });

    test('read back sanely from a document missing fields', () {
      // Documents come from several app versions; half a line still tells the
      // person packing the order something useful.
      final line = OrderLine.fromMap({'name': 'Paneer'});
      expect(line.name, 'Paneer');
      expect(line.qty, 1, reason: 'a line with no quantity is one of them');
      expect(line.unitPrice, 0);
    });

    test('add up to a subtotal and a count', () {
      final b = order(items: [biryani, naan]);
      expect(b.itemsSubtotal, closeTo(29.48, 0.001));
      expect(b.itemCount, 3, reason: '2 biryani + 1 naan');
    });
  });

  group('amounts are payable figures', () {
    test('a 12% fee on an odd subtotal rounds to whole cents', () {
      // 2 × 14.99 + 6.49 + 4.49 = 40.96, +12% = 45.8752. That was being stored
      // as the price of an order — it displayed as $45.88 because every label
      // formats to two places, so it looked right while the recorded figure was
      // not an amount anyone could hand over.
      const subtotal = 40.96;
      expect(money(subtotal * (1 + platformFeePct)), 45.88);
    });

    test('rounds half up, and leaves exact amounts alone', () {
      expect(money(0.005), 0.01);
      expect(money(12.99), 12.99);
      expect(money(0), 0);
    });

    test('an order total reconciles with its lines', () {
      final b = order(items: [biryani, naan], amount: money(29.48 * 1.12));
      // What the card shows as fees is the difference between the two, so if the
      // total were stored unrounded this would drift by fractions of a cent.
      expect(b.amount - b.itemsSubtotal, closeTo(3.54, 0.005));
    });
  });

  group('Olivia carries her draft onto the booking', () {
    test('the confirmed order keeps every line she read out', () {
      final draft = OrderDraft(
        providerId: 's1',
        providerName: 'Patel Brothers',
        category: 'indian_store',
        lines: const [
          DraftLine(name: 'Chicken Biryani', qty: 2, unitPrice: 12.99),
          DraftLine(name: 'Garlic Naan', qty: 1, unitPrice: 3.50),
        ],
        fulfillment: 'delivery',
        address: '12 Oak Tree Road, Edison NJ',
      );
      final booking = draft.toBooking();

      expect(booking.items.length, 2);
      expect(booking.items.first.name, 'Chicken Biryani');
      expect(booking.items.first.qty, 2);
      expect(booking.items.first.unitPrice, 12.99);
      expect(booking.itemsSubtotal, closeTo(29.48, 0.001),
          reason: 'what the business sees must match what she said aloud');
    });
  });

  group('who sees what', () {
    Widget harness(Booking b, OrderAudience who) => MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderItemsView(booking: b, audience: who),
            ),
          ),
        );

    testWidgets('the business sees quantities and what to prepare', (t) async {
      await t.pumpWidget(harness(order(items: [biryani, naan], amount: 34.10),
          OrderAudience.business));
      await t.pumpAndSettle();

      expect(find.text('ORDER TO PREPARE'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      expect(find.textContaining('Chicken Biryani'), findsOneWidget);
      expect(find.textContaining('Garlic Naan'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.textContaining('Customer pays'), findsOneWidget);
    });

    testWidgets('the customer sees what they will pay', (t) async {
      await t.pumpWidget(harness(order(items: [biryani, naan], amount: 34.10),
          OrderAudience.customer));
      await t.pumpAndSettle();

      expect(find.text('WHAT YOU ORDERED'), findsOneWidget);
      expect(find.text('\$25.98'), findsOneWidget, reason: '2 × 12.99');
      expect(find.text('\$34.10'), findsOneWidget, reason: 'the agreed total');
      expect(find.textContaining('pay in person'), findsOneWidget,
          reason: 'payment is always manual, and the card must say so');
    });

    testWidgets('the courier sees the goods but never the prices', (t) async {
      await t.pumpWidget(harness(
          order(items: [biryani, naan], amount: 34.10), OrderAudience.courier));
      await t.pumpAndSettle();

      expect(find.text('WHAT YOU ARE CARRYING'), findsOneWidget);
      expect(find.textContaining('Chicken Biryani'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      // What the customer paid is between them and the business.
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('a home-service booking shows no order block', (t) async {
      // Hours of someone's time, not a list of goods.
      final visit = Booking('Maria G.', 'Tue 9:00 AM · 3 hrs', 'Requested', 94,
          category: 'home_service');
      await t.pumpWidget(harness(visit, OrderAudience.business));
      await t.pumpAndSettle();

      expect(find.byType(OrderItemsView), findsOneWidget);
      expect(find.text('ORDER TO PREPARE'), findsNothing);
    });

    testWidgets('a long grocery order collapses instead of taking the screen',
        (t) async {
      final many = [
        for (var i = 0; i < 9; i++)
          OrderLine(name: 'Item $i', qty: 1, unitPrice: 2.0),
      ];
      await t.pumpWidget(
          harness(order(items: many, amount: 20), OrderAudience.business));
      await t.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 8'), findsNothing);
      expect(find.text('Show all 5 more'), findsOneWidget);

      await t.tap(find.text('Show all 5 more'));
      await t.pumpAndSettle();
      expect(find.text('Item 8'), findsOneWidget);
    });
  });
}
