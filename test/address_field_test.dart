import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/services/address_search.dart';
import 'package:localhive/theme.dart';
import 'package:localhive/widgets/address_field.dart';

// The map-style address input: live suggestions while typing, tap to fill,
// and a use-my-location button that drops in the current street address.
// Lookups are injected so nothing here touches the network.
void main() {
  const suggestions = [
    AddressSuggestion(
        address: '42 Oak Tree Rd, Edison, NJ 08820', title: '42 Oak Tree Rd'),
    AddressSuggestion(
        address: '44 Oak Tree Rd, Edison, NJ 08820', title: '44 Oak Tree Rd'),
  ];

  Widget wrap(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
          body:
              ListView(padding: const EdgeInsets.all(16), children: [child])));

  testWidgets('typing shows suggestions and tapping one fills the field',
      (tester) async {
    final controller = TextEditingController();
    final queries = <String>[];
    await tester.pumpWidget(wrap(AddressField(
      controller: controller,
      hintText: 'Street address, city, state',
      search: (q) async {
        queries.add(q);
        return suggestions;
      },
      locate: () async => null,
    )));

    await tester.enterText(find.byType(TextField), '42 oak');
    // Debounce: no lookup until the pause elapses.
    await tester.pump(const Duration(milliseconds: 200));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(queries, ['42 oak']);
    expect(find.text('42 Oak Tree Rd'), findsOneWidget);

    await tester.tap(find.text('44 Oak Tree Rd'));
    await tester.pumpAndSettle();
    expect(controller.text, '44 Oak Tree Rd, Edison, NJ 08820');
    // The list closes after picking.
    expect(find.text('42 Oak Tree Rd'), findsNothing);
  });

  testWidgets('use-my-location fills the current street address',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(wrap(AddressField(
      controller: controller,
      hintText: 'Street address, city, state',
      search: (_) async => const [],
      locate: () async => '1 Main St, Iselin, NJ 08830',
    )));

    await tester.tap(find.byTooltip('Use my current location'));
    await tester.pumpAndSettle();
    expect(controller.text, '1 Main St, Iselin, NJ 08830');
    expect(
        find.textContaining('Filled in your current address'), findsOneWidget);
  });

  testWidgets('a failed location lookup explains itself instead of hanging',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(wrap(AddressField(
      controller: controller,
      hintText: 'Street address, city, state',
      search: (_) async => const [],
      locate: () async => null,
    )));

    await tester.tap(find.byTooltip('Use my current location'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(find.textContaining('Could not read your location'), findsOneWidget);
  });

  test('formatUsAddress composes what exists and skips what is missing', () {
    expect(
        formatUsAddress(const {
          'house_number': '42',
          'road': 'Oak Tree Rd',
          'city': 'Edison',
          'state': 'New Jersey',
          'postcode': '08820',
        }),
        '42 Oak Tree Rd, Edison, New Jersey 08820');
    expect(formatUsAddress(const {'city': 'Edison', 'state': 'New Jersey'}),
        'Edison, New Jersey');
    expect(formatUsAddress(const {}, fallback: 'somewhere'), 'somewhere');
  });
}
