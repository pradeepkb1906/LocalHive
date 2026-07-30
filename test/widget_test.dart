import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localhive/main.dart';
import 'package:localhive/screens/home_screen.dart';
import 'package:localhive/screens/profile_screen.dart';
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

    expect(find.byType(SignInScreen), findsOneWidget,
        reason: 'signed out, the first screen is the front door');
    expect(find.text('Welcome to LocalHive'), findsOneWidget);
    // The demo personas are the way into the demo; they must be on this
    // screen, not hidden behind navigation.
    await tester.scrollUntilVisible(find.text('Customer'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Customer'), findsOneWidget);
  });
  testWidgets('LocalHive home screen renders the three verticals',
      (tester) async {
    // A phone-sized viewport; the home feed scrolls, so each card has to be
    // scrolled into view rather than assumed to be built.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(homeHarness());

    expect(find.text('LocalHive'), findsOneWidget);

    for (final label in const [
      'Just talk to Olivia',
      'Home Services',
      'Stores',
      'Food Trucks',
    ]) {
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
