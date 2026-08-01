import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/demo_accounts.dart';
import 'package:localhive/theme.dart';

/// Regression guard for the sign-in screen's demo account list.
///
/// The app-wide FilledButton theme uses an infinite minimum width, so putting a
/// default-styled button in a width-bounded slot throws during layout and the
/// whole card silently collapses to zero height. That once made every demo
/// login invisible. These tests pump the same widgets at phone width and fail
/// on any layout exception.
void main() {
  Widget harness(Widget child) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: child),
      );

  Widget demoCard(DemoAccount a) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconTile(icon: a.icon, color: a.color, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.label),
                    Text(a.description),
                    Text('${a.email}  ·  ${a.password}'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 66,
                height: 34,
                child: FilledButton(
                  onPressed: () {},
                  style: compactButtonStyle(),
                  child: const Text('Use'),
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('every demo account card lays out at phone width', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(harness(ListView(
      padding: const EdgeInsets.all(20),
      children: [for (final a in demoAccounts) demoCard(a)],
    )));
    await t.pumpAndSettle();

    for (final a in demoAccounts) {
      await t.scrollUntilVisible(find.text(a.label), 120);
      expect(find.text(a.label), findsOneWidget,
          reason: '${a.label} card did not render');
      expect(
          find.descendant(
              of: find.ancestor(
                  of: find.text(a.label), matching: find.byType(Card)),
              matching: find.text('Use')),
          findsOneWidget,
          reason: '${a.label} card has no Use button');
    }
  });

  testWidgets('a demo card still lays out on a narrow 320pt phone', (t) async {
    t.view.physicalSize = const Size(320 * 2, 640 * 2);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(harness(ListView(
      padding: const EdgeInsets.all(20),
      children: [demoCard(demoAccounts.first)],
    )));
    await t.pumpAndSettle();
    expect(find.text('Use'), findsOneWidget);
  });

  test('demo accounts cover every persona the app still supports', () {
    // Customer, SF store owner, delivery partner, admin. The food-truck and
    // home-service logins went with their verticals.
    expect(demoAccounts.length, 4);
    for (final a in demoAccounts) {
      expect(a.email, contains('@'));
      expect(a.password.length, greaterThanOrEqualTo(6));
    }
    // The store owner is the account a shopkeeper is shown, so it has to be
    // on the list and near the top.
    final emails = demoAccounts.map((a) => a.email).toList();
    expect(emails, contains('sfstore@localhive.app'));
    expect(emails.indexOf('sfstore@localhive.app'), lessThan(2));
    // Retired personas must not linger as dead logins.
    expect(emails, isNot(contains('maria@localhive.app')));
    expect(emails, isNot(contains('truck@localhive.app')));
  });
}
