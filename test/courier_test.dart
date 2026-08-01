import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/data.dart';
import 'package:localhive/screens/become_courier_screen.dart';

// Delivery is the one role a neighbour can take on without owning a business,
// and the reason it exists is the customer who cannot carry their own shop.
// These tests pin the two things that must not quietly drift: what a partner
// is actually paid, and the fact that a request for help travels from the
// checkout box all the way to the person who has to do the carrying.
void main() {
  group('what a delivery partner earns', () {
    test('a plain doorstep run pays the base fee', () {
      expect(courierFeeFor(needsHelp: false), courierBaseFee);
    });

    test('a run that needs a hand to the door pays the bonus on top', () {
      expect(courierFeeFor(needsHelp: true), courierBaseFee + courierHelpBonus);
      // The bonus has to be worth the extra flight of stairs, or nobody
      // claims those jobs and the customers who need them most go unserved.
      expect(courierHelpBonus, greaterThanOrEqualTo(2.0));
    });
  });

  group('the request for help survives the trip to the job board', () {
    test('a booking carries the flag and the note', () {
      const b = Booking(
        'Bi-Rite Market',
        'Delivery order · 2 × Milk',
        'Placed',
        24.40,
        fulfillment: 'delivery',
        address: '550 Divisadero St, San Francisco, CA',
        needsHelp: true,
        deliveryNote: 'Ring twice, I am slow to the door.',
      );
      expect(b.needsHelp, isTrue);
      expect(b.deliveryNote, contains('slow to the door'));
      // The fee the job will be posted at follows from the booking, so the
      // two can never disagree.
      expect(courierFeeFor(needsHelp: b.needsHelp), 7.99);
    });

    test('an ordinary order asks for nothing extra and pays the base fee', () {
      const b = Booking('Corner Grocery', 'Delivery order', 'Placed', 12.0);
      expect(b.needsHelp, isFalse);
      expect(b.deliveryNote, isEmpty);
      expect(courierFeeFor(needsHelp: b.needsHelp), courierBaseFee);
    });
  });

  group('the recruiting page', () {
    // The page is a tall ListView, so a phone-sized test surface never builds
    // the copy below the fold. Give it room rather than scrolling in every
    // test.
    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first;
      view.physicalSize = const Size(1200, 4200);
      view.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    testWidgets('quotes the pay the code actually uses, not a hardcoded number',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BecomeCourierScreen()));
      await tester.pumpAndSettle();

      // If someone changes courierBaseFee without touching this page, the
      // page must follow — a recruiting promise that no longer matches the
      // payout is the worst kind of stale copy.
      expect(
          find.textContaining(courierBaseFee.toStringAsFixed(2)), findsWidgets);
      expect(
          find.textContaining(
              (courierBaseFee + courierHelpBonus).toStringAsFixed(2)),
          findsWidgets);
    });

    testWidgets('is honest that the work is contract work, not a job',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BecomeCourierScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('independent contractors'), findsOneWidget);
      expect(find.textContaining('does not guarantee a number of jobs'),
          findsOneWidget);
    });

    testWidgets('says the help bonus does not come out of the customer',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BecomeCourierScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('no cost to them'), findsOneWidget);
    });
  });
}
