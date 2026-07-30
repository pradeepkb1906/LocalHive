import 'package:flutter_test/flutter_test.dart';

import 'package:localhive/main.dart';

void main() {
  testWidgets('LocalHive home screen renders the three verticals',
      (tester) async {
    await tester.pumpWidget(const LocalHiveApp());

    expect(find.text('LocalHive'), findsOneWidget);
    expect(find.text('Home Services'), findsOneWidget);
    expect(find.text('Indian Stores'), findsOneWidget);
    expect(find.text('Food Trucks'), findsOneWidget);
  });
}
