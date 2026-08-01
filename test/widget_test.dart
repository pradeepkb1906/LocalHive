import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localhive/main.dart';
import 'package:localhive/screens/home_screen.dart';
import 'package:localhive/screens/profile_screen.dart';
import 'package:localhive/screens/welcome_screen.dart';
import 'package:localhive/theme.dart';

/// The app's front door is now the sign-in screen (with the demo accounts),
/// so app-level pumps land there; the home-feed tests pump HomeShell directly,
/// which is what a signed-in customer sees.
Widget homeHarness() =>
    MaterialApp(theme: buildTheme(), home: const HomeShell());

void main() {
  testWidgets('the app opens on sign-in with the demo accounts listed',
      (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LocalHiveApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Signed out, the brand film greets first, with one way forward.
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Welcome to LocalHive'), findsOneWidget);
    // The demo personas are the way into the demo; they must be on this
    // screen, not hidden behind navigation.
    await tester.scrollUntilVisible(find.text('Customer'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Customer'), findsOneWidget);
  });
  testWidgets('home feed shows the live vertical, not the parked ones',
      (tester) async {
    // A phone-sized viewport; the home feed scrolls, so each card has to be
    // scrolled into view rather than assumed to be built.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(homeHarness());

    expect(find.text('LocalHive'), findsOneWidget);

    // LocalHive is focused on one vertical — SF groceries. Olivia and the
    // storefront that has real supply behind it are on the feed.
    for (final label in const ['Just talk to Olivia', 'Grocery Stores']) {
      await tester.scrollUntilVisible(
        find.text(label),
        150,
        // The screen has more than one Scrollable (the feed, plus the chips),
        // so the feed has to be named explicitly.
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget,
          reason: '$label should be on the home feed');
    }
    // The parked verticals are switched off by default and must not appear —
    // an entry that leads to an empty marketplace is worse than no entry.
    expect(find.text('Home Services'), findsNothing);
    expect(find.text('Food Trucks'), findsNothing);
  });

  testWidgets('Olivia is reachable from every tab', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(homeHarness());
    // The floating button persists across tabs, so it stays the dependable
    // entry point even once the home feed is scrolled away.
    expect(find.text('Ask Olivia'), findsOneWidget);
  });
}
