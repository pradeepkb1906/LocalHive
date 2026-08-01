import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/ca_cities.dart';
import 'package:localhive/services/location_service.dart';
import 'package:localhive/widgets/city_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// LocalHive serves California and nowhere else. A phone in Bengaluru, London
// or New York must land in San Francisco rather than anchoring the whole app
// to a place with no shops in the directory and no partners to order from.
// These tests pin the boundary itself, because it is invisible in normal use
// and only shows up when someone demonstrates the app from abroad.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the service-area boundary', () {
    test('California points are inside', () {
      expect(isInCalifornia(37.7749, -122.4194), isTrue); // San Francisco
      expect(isInCalifornia(34.0522, -118.2437), isTrue); // Los Angeles
      expect(isInCalifornia(32.7157, -117.1611), isTrue); // San Diego
      expect(isInCalifornia(41.7558, -124.2026), isTrue); // Crescent City
    });

    test('the rest of the world is outside', () {
      expect(isInCalifornia(12.9716, 77.5946), isFalse); // Bengaluru
      expect(isInCalifornia(51.5074, -0.1278), isFalse); // London
      expect(isInCalifornia(40.7128, -74.0060), isFalse); // New York
      expect(isInCalifornia(45.5152, -122.6784), isFalse); // Portland, OR
      expect(isInCalifornia(36.1699, -115.1398), isFalse); // Las Vegas, NV
      expect(isInCalifornia(39.5296, -119.8138), isFalse); // Reno, NV
      expect(isInCalifornia(33.4484, -112.0740), isFalse); // Phoenix, AZ
      expect(isInCalifornia(32.6927, -114.6277), isFalse); // Yuma, AZ
      // The sign on the longitude matters: mirroring San Francisco into the
      // eastern hemisphere must not sneak past the box.
      expect(isInCalifornia(37.7749, 122.4194), isFalse);
    });
  });

  group('the eastern border is a diagonal, not a wall', () {
    // A rectangle wide enough to hold Needles also holds Las Vegas. Getting
    // this wrong tells a customer in Nevada they are in the service area and
    // then shows them nothing — worse than sending them to San Francisco.
    test('California towns along the border stay inside', () {
      expect(isInCalifornia(34.8481, -114.6141), isTrue); // Needles
      expect(isInCalifornia(38.9399, -119.9772), isTrue); // South Lake Tahoe
      expect(isInCalifornia(34.8958, -117.0173), isTrue); // Barstow
    });

    test('the boundary moves east as it goes south', () {
      // Straight down to Tahoe, then cutting away towards the river.
      expect(caEastBoundAt(41.0), closeTo(-120.0, 0.01));
      expect(caEastBoundAt(39.0), closeTo(-120.0, 0.01));
      expect(caEastBoundAt(37.0), lessThan(-116.0));
      expect(caEastBoundAt(37.0), greaterThan(-120.0));
      expect(caEastBoundAt(33.0), lessThan(-114.6));
      expect(caEastBoundAt(caMinLat), closeTo(-114.72, 0.01));
    });
  });

  group('where a customer starts', () {
    test('San Francisco, before anyone chooses anything', () {
      expect(defaultCaCity.name, 'San Francisco');
      expect(defaultCaCity.label, 'San Francisco, CA');
      expect(isInCalifornia(defaultCaCity.lat, defaultCaCity.lng), isTrue);
    });

    test('the service never reports a position it does not have', () {
      // Seeded from the default city, so the very first frame can already
      // rank shops instead of rendering an empty screen.
      final loc = LocationService.instance;
      expect(loc.hasPosition, isTrue);
      expect(isInCalifornia(loc.lat!, loc.lng!), isTrue);
    });

    test('every listed city really is in California', () {
      expect(caCities, isNotEmpty);
      for (final c in caCities) {
        expect(isInCalifornia(c.lat, c.lng), isTrue,
            reason: '${c.name} is outside the service area');
        expect(c.label, endsWith(', CA'));
      }
    });

    test('no city is listed twice', () {
      final names = caCities.map((c) => c.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('choosing a city', () {
    test('moves the customer and is remembered', () async {
      final loc = LocationService.instance;
      final oakland = caCities.firstWhere((c) => c.name == 'Oakland');
      await loc.setCity(oakland);

      expect(loc.city, oakland);
      expect(loc.lat, oakland.lat);
      expect(loc.lng, oakland.lng);
      expect(loc.label, 'Oakland, CA');
      // A deliberate choice outranks whatever the device thinks.
      expect(loc.usingDeviceLocation, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lh_ca_city'), 'Oakland');

      await loc.setCity(defaultCaCity); // leave the singleton as we found it
    });

    test('nearest city labels a real fix inside the state', () {
      // Standing in the Mission.
      expect(nearestCaCity(37.7599, -122.4148).name, 'San Francisco');
      // Standing in downtown San Jose.
      expect(nearestCaCity(37.3382, -121.8863).name, 'San Jose');
      // Standing in Santa Monica.
      expect(nearestCaCity(34.0195, -118.4912).name, 'Santa Monica');
    });

    test('search finds cities by prefix first', () {
      final r = searchCaCities('san');
      expect(r, isNotEmpty);
      expect(r.first.name.toLowerCase(), startsWith('san'));
      expect(r.map((c) => c.name), contains('San Diego'));

      expect(searchCaCities('  '), hasLength(caCities.length));
      // Somewhere LocalHive does not serve returns nothing, rather than a
      // near-miss that implies it does.
      expect(searchCaCities('Bengaluru'), isEmpty);
      expect(searchCaCities('Portland'), isEmpty);
    });
  });

  group('the picker', () {
    // The sheet is three-quarters of the viewport; a default 800x600 test
    // surface clips the list and reports overflow instead of the assertion.

    // The sheet caps itself at three-quarters of the viewport, so a default
    // 800x600 surface leaves too little room for the list.
    Future<void> pumpPicker(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // Scaffold, because TextField and ListTile need a Material ancestor —
      // in the app that comes from showModalBottomSheet.
      await tester
          .pumpWidget(const MaterialApp(home: Scaffold(body: CityPicker())));
      await tester.pumpAndSettle();
    }

    testWidgets('offers California cities and says so', (tester) async {
      await pumpPicker(tester);
      expect(find.text('Choose your city'), findsOneWidget);
      expect(find.text('LocalHive serves California.'), findsOneWidget);
      expect(find.text('San Francisco'), findsOneWidget);
    });

    testWidgets('narrows as you type, and admits when it has nothing',
        (tester) async {
      await pumpPicker(tester);
      await tester.enterText(find.byType(TextField), 'oak');
      await tester.pumpAndSettle();
      expect(find.text('Oakland'), findsOneWidget);
      expect(find.text('San Diego'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Bengaluru');
      await tester.pumpAndSettle();
      expect(
          find.textContaining('only operates in California'), findsOneWidget);
    });
  });
}
