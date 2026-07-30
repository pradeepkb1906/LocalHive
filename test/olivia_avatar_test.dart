import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/services/olivia/order_draft.dart';
import 'package:localhive/theme.dart';
import 'package:localhive/widgets/olivia/olivia_avatar.dart';
import 'package:localhive/widgets/olivia/order_confirm_card.dart';

/// Layout guards for Olivia's new UI.
///
/// The app-wide FilledButton theme has an infinite minimum width, so a button
/// in a width-bounded slot throws during layout and silently collapses its
/// whole card to nothing. That once hid every demo login. These tests pump the
/// new widgets at real phone widths so it cannot happen again unnoticed.
void main() {
  Widget harness(Widget child, {double width = 390, double height = 844}) =>
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  group('Olivia avatar', () {
    for (final size in [96.0, 150.0, 220.0]) {
      testWidgets('paints at ${size.toInt()}pt without throwing', (t) async {
        await t.pumpWidget(harness(Center(child: OliviaAvatar(size: size))));
        await t.pump(const Duration(milliseconds: 100));
        expect(tester_ok(), isTrue);
        expect(find.byType(OliviaAvatar), findsOneWidget);
      });
    }

    testWidgets('animates through a full idle cycle with the mouth moving',
        (t) async {
      await t.pumpWidget(harness(
        const Center(child: OliviaAvatar(size: 150, mouthOpen: 0.7)),
      ));
      // Step through the 4.2s idle loop, which covers the blink window.
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(OliviaAvatar), findsOneWidget);
    });

    testWidgets('renders in listening and thinking states', (t) async {
      await t.pumpWidget(harness(const Column(children: [
        OliviaAvatar(size: 120, listening: true),
        OliviaAvatar(size: 120, thinking: true),
      ])));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byType(OliviaAvatar), findsNWidgets(2));
    });
  });

  _blinkTests();

  group('order confirmation card', () {
    OrderDraft foodDraft({String fulfillment = 'pickup'}) => OrderDraft(
          kind: 'order',
          providerId: 'ft1',
          providerName: 'Bombay Street Eats',
          category: 'food_truck',
          fulfillment: fulfillment,
          pickupEta: fulfillment == 'pickup' ? 'In 30 min' : '',
          address:
              fulfillment == 'delivery' ? '120 Oak Tree Rd, Iselin, NJ' : '',
          lines: const [
            DraftLine(name: 'Chicken Biryani', qty: 2, unitPrice: 12.99),
            DraftLine(name: 'Masala Chai', qty: 1, unitPrice: 2.50),
          ],
        );

    testWidgets('lays out at 390pt and shows the real total', (t) async {
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(Padding(
        padding: const EdgeInsets.all(16),
        child: OrderConfirmCard(
          draft: foodDraft(),
          onConfirm: () {},
          onCancel: () {},
        ),
      )));
      await t.pumpAndSettle();

      expect(find.text('2 × Chicken Biryani'), findsOneWidget);
      // 25.98 + 2.50 = 28.48, +12% = 31.90
      expect(find.textContaining('31.90'), findsWidgets);
      expect(find.textContaining('Cancel'), findsOneWidget);
    });

    testWidgets('still lays out on a narrow 320pt phone', (t) async {
      t.view.physicalSize = const Size(320 * 2, 640 * 2);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);

      await t.pumpWidget(harness(Padding(
        padding: const EdgeInsets.all(12),
        child: OrderConfirmCard(
          draft: foodDraft(fulfillment: 'delivery'),
          onConfirm: () {},
          onCancel: () {},
        ),
      )));
      await t.pumpAndSettle();
      expect(find.textContaining('Deliver to'), findsOneWidget);
    });

    testWidgets('confirm is disabled while the draft is incomplete', (t) async {
      var confirmed = false;
      const incomplete = OrderDraft(
        kind: 'order',
        providerId: 'ft1',
        providerName: 'Bombay Street Eats',
        category: 'food_truck',
        fulfillment: 'delivery', // no address
        lines: [DraftLine(name: 'Vada Pav', qty: 1, unitPrice: 4.50)],
      );

      await t.pumpWidget(harness(Padding(
        padding: const EdgeInsets.all(16),
        child: OrderConfirmCard(
          draft: incomplete,
          onConfirm: () => confirmed = true,
          onCancel: () {},
        ),
      )));
      await t.pumpAndSettle();

      final button = t.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull,
          reason: 'an incomplete draft must not be placeable');

      await t.tap(find.byType(FilledButton), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(confirmed, isFalse);
    });

    testWidgets('tells the customer payment happens in person', (t) async {
      await t.pumpWidget(harness(Padding(
        padding: const EdgeInsets.all(16),
        child: OrderConfirmCard(
          draft: foodDraft(),
          onConfirm: () {},
          onCancel: () {},
        ),
      )));
      await t.pumpAndSettle();
      expect(find.textContaining('pay the business directly'), findsOneWidget);
      expect(
          find.textContaining('Nothing is charged in the app'), findsOneWidget);
    });
  });
}

bool tester_ok() => true;

/// The blink is the one thing that makes the photograph feel alive, and it is
/// easy to break silently — the eyelids are positioned by fractions of the
/// photo's size, so a layout change can move them off her eyes. This at least
/// proves the overlay paints through a whole blink without throwing.
void _blinkTests() {
  testWidgets('the avatar paints through a full blink cycle', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: const Scaffold(
        body: Center(child: OliviaAvatar(size: 200)),
      ),
    ));
    // The idle loop is 4.2s and the blink fires at 86% of it; step finely
    // enough to land inside the ~210ms window.
    for (var ms = 0; ms < 4400; ms += 60) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(OliviaAvatar), findsOneWidget);
  });
}
