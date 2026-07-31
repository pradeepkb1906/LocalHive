import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/services/olivia/olivia_tools.dart';
import 'package:localhive/theme.dart';
import 'package:localhive/widgets/olivia/call_card.dart';

// The card Olivia shows after the customer agrees to a call: place, listed
// number, purpose — and a Call button the customer taps. LocalHive never
// dials by itself, so the card must say so.
void main() {
  const call = PendingCall(
    placeName: 'Taqueria El Sol',
    phone: '+1 732 555 0188',
    purpose: 'Book a table for 2 tonight',
  );

  testWidgets('shows place, number, purpose and fires callbacks',
      (tester) async {
    var called = false;
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [
          CallCard(
            call: call,
            onCall: () => called = true,
            onDismiss: () => dismissed = true,
          ),
        ]),
      ),
    ));

    expect(find.text('Taqueria El Sol'), findsOneWidget);
    expect(find.text('+1 732 555 0188'), findsOneWidget);
    expect(find.text('Book a table for 2 tonight'), findsOneWidget);
    // Honesty line: the customer places the call, not the app.
    expect(find.textContaining('you place the call'), findsOneWidget);

    await tester.tap(find.textContaining('Call Taqueria El Sol'));
    expect(called, isTrue);
    await tester.tap(find.text('Not now'));
    expect(dismissed, isTrue);
  });
}
