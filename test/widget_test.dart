import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localhive/main.dart';

void main() {
  testWidgets('LocalHive home screen renders the three verticals',
      (tester) async {
    // A phone-sized viewport; the home feed scrolls, so each card has to be
    // scrolled into view rather than assumed to be built.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LocalHiveApp());

    expect(find.text('LocalHive'), findsOneWidget);

    for (final label in const [
      'Just talk to Olivia',
      'Home Services',
      'Indian Stores',
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

    await tester.pumpWidget(const LocalHiveApp());
    // The floating button persists across tabs, so it stays the dependable
    // entry point even once the home feed is scrolled away.
    expect(find.text('Ask Olivia'), findsOneWidget);
  });
}
