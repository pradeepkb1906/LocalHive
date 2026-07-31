import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/screens/help_support_screen.dart';
import 'package:localhive/screens/legal_screen.dart';
import 'package:localhive/theme.dart';

// The About pages: they must render at phone width and actually contain the
// standard-marketplace language — payment in person, independent businesses,
// no sale of personal information.
void main() {
  Widget wrap(Widget child) => MaterialApp(theme: buildTheme(), home: child);

  testWidgets('Terms of Service renders with the marketplace essentials',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const LegalScreen(
      title: 'Terms of Service',
      lastUpdated: legalLastUpdated,
      sections: termsOfServiceSections,
    )));
    expect(find.text('Terms of Service'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('independent third parties'), 300);
    expect(find.textContaining('independent third parties'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('pay the business directly'), 300);
    expect(find.textContaining('pay the business directly'), findsOneWidget);
    // The essentials must exist in the document text itself, not just on
    // whichever screenful the test happens to scroll through.
    final allTerms = termsOfServiceSections.map((s) => s.body).join('\n');
    expect(allTerms, contains('12% platform fee'));
    expect(allTerms, contains('AS IS'));
    expect(allTerms, contains('State of New Jersey'));
  });

  testWidgets('Privacy Policy renders and promises no data sales',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const LegalScreen(
      title: 'Privacy Policy',
      lastUpdated: legalLastUpdated,
      sections: privacyPolicySections,
    )));
    expect(find.text('Privacy Policy'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.textContaining('never sell your personal information'), 300);
    expect(find.textContaining('never sell your personal information'),
        findsOneWidget);
    final allPrivacy = privacyPolicySections.map((s) => s.body).join('\n');
    expect(allPrivacy, contains('Microphone and voice'));
    expect(allPrivacy, contains('under 13'));
    expect(allPrivacy, contains('privacy@localhive.app'));
  });

  testWidgets('Help & Support renders FAQs and expands an answer',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const HelpSupportScreen()));
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Where is my order?'), findsOneWidget);
    await tester.tap(find.text('Where is my order?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open the Bookings tab'), findsOneWidget);
    // The way to reach a human is on the page.
    await tester.scrollUntilVisible(
        find.textContaining('support@localhive.app'), 200);
    expect(find.textContaining('support@localhive.app'), findsOneWidget);
  });
}
