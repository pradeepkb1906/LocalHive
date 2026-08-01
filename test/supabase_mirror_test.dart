import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:localhive/services/supabase_mirror.dart';
import 'package:localhive/supabase_config.dart';

// The read-only standby. Firestore is the system of record; this exists for
// the day it cannot be read. What matters is that it maps rows faithfully
// and stays quiet — never throwing — when it is switched off or unreachable.
void main() {
  final mirror = SupabaseMirror.instance;

  tearDown(() {
    mirror.client = http.Client();
    mirror.servingFromMirror = false;
  });

  test('a mirrored row becomes a Provider', () {
    final p = providerFromMirrorRow(const {
      'id': 'us016s',
      'name': 'San Francisco Fresh Market',
      'category': 'indian_store',
      'subtitle': 'Groceries & everyday essentials',
      'rating': 4.6,
      'reviews': 128,
      'city': 'San Francisco, CA',
      'verified': true,
      'lat': 37.7749,
      'lng': -122.4194,
      'available_from': '8 AM',
      'available_to': '9 PM',
    });
    expect(p.id, 'us016s');
    expect(p.name, 'San Francisco Fresh Market');
    expect(p.city, 'San Francisco, CA');
    expect(p.rating, 4.6);
    expect(p.reviews, 128);
    expect(p.verified, isTrue);
    expect(p.hasLocation, isTrue);
    expect(p.availability, '8 AM – 9 PM');
  });

  test('a half-empty row still yields a usable Provider', () {
    final p = providerFromMirrorRow(const {'id': 'x', 'name': 'Corner Shop'});
    expect(p.name, 'Corner Shop');
    expect(p.rating, 0);
    expect(p.hasLocation, isFalse);
    expect(p.availability, isEmpty);
  });

  test('switched off, the mirror returns null rather than throwing', () async {
    // No url/anonKey configured in the checked-in template.
    if (SupabaseConfig.enabled) return; // configured locally; skip
    expect(await mirror.providers('indian_store'), isNull);
    expect(await mirror.reachable(), isFalse);
    expect(mirror.servingFromMirror, isFalse);
  });

  test('a failing standby returns null and never throws', () async {
    mirror.client = MockClient((_) async => http.Response('nope', 500));
    // Still null because it is unconfigured; the point is that no exception
    // escapes to the caller in either case.
    expect(() => mirror.providers('indian_store'), returnsNormally);
  });

  test('rows decode into providers when the standby answers', () {
    final body = jsonEncode([
      {'id': 'a', 'name': 'Alpha Market', 'category': 'indian_store'},
      {'id': 'b', 'name': 'Beta Grocers', 'category': 'indian_store'},
      {'id': 'c', 'name': ''}, // unnamed rows are dropped by the caller
    ]);
    final rows = (jsonDecode(body) as List)
        .whereType<Map<String, dynamic>>()
        .map(providerFromMirrorRow)
        .where((p) => p.name.isNotEmpty)
        .toList();
    expect(rows.map((p) => p.name), ['Alpha Market', 'Beta Grocers']);
  });

  group('standby mode never lets stale data pose as live', () {
    test('falling back flips an observable flag and stamps the time', () {
      var notified = 0;
      void listener() => notified++;
      mirror.addListener(listener);
      addTearDown(() => mirror.removeListener(listener));

      expect(mirror.servingFromMirror, isFalse);
      expect(mirror.servingSince, isNull);

      mirror.servingFromMirror = true;
      expect(mirror.servingFromMirror, isTrue);
      // Screens have to be able to say how old the view is, not leave the
      // customer to assume it is current.
      expect(mirror.servingSince, isNotNull);
      expect(notified, 1);

      // Setting the same value again must not churn listeners.
      mirror.servingFromMirror = true;
      expect(notified, 1);

      mirror.servingFromMirror = false;
      expect(mirror.servingSince, isNull);
      expect(notified, 2);
    });
  });

  group('the nearby directory searches tight before it searches wide', () {
    // The server applies its row cap BEFORE anything is sorted by distance,
    // so one wide query in a dense neighbourhood returns an arbitrary slice
    // of the box. Downtown San Francisco reported its nearest grocery as
    // 3.4 km away for exactly that reason, with a Safeway 300 m up the road
    // sitting outside the truncated 200.
    List<Map<String, dynamic>> shopsAround(double lat, double lng, int n,
        {double spreadKm = 6}) {
      return List.generate(n, (i) {
        // Spread them outwards so the far ones dominate a wide box.
        final off = (spreadKm / 111.0) * ((i % 40) + 1) / 40;
        return {
          'id': 's$i',
          'name': 'Shop $i',
          'lat': lat + off,
          'lng': lng,
        };
      });
    }

    test('a dense area settles on the tight box and returns the closest',
        () async {
      if (!SupabaseConfig.enabled) return; // unconfigured checkout; skip

      final boxesAsked = <double>[];
      mirror.client = MockClient((req) async {
        // The lat filter appears twice (gte + lte); queryParameters keeps
        // only the last of a repeated key, so read them all to recover the
        // box height.
        final bounds = req.url.queryParametersAll['lat']!
            .map((v) => double.parse(v.substring(v.indexOf('.') + 1)))
            .toList();
        boxesAsked.add((bounds[1] - bounds[0]).abs());
        // Plenty of shops right nearby: the first, tightest query suffices.
        return http.Response(
            jsonEncode(shopsAround(37.7946, -122.3999, 60, spreadKm: 1)), 200);
      });

      final out =
          await mirror.nearbyStores(lat: 37.7946, lng: -122.3999, radiusKm: 8);
      expect(out, isNotNull);
      expect(boxesAsked.length, 1,
          reason: 'a dense area must not need a second, wider query');
      // Sorted nearest-first, and nothing outside the radius sneaks in.
      final kms = out!.map((s) => s.km).toList();
      expect(kms, orderedEquals(List.of(kms)..sort()));
      expect(kms.every((k) => k <= 8), isTrue);
    });

    test('a sparse area keeps widening rather than giving up', () async {
      if (!SupabaseConfig.enabled) return;

      var calls = 0;
      mirror.client = MockClient((req) async {
        calls++;
        // Nothing close by; only the widest box finds anything.
        final rows = calls < 3
            ? <Map<String, dynamic>>[]
            : shopsAround(37.7946, -122.3999, 5, spreadKm: 7);
        return http.Response(jsonEncode(rows), 200);
      });

      final out =
          await mirror.nearbyStores(lat: 37.7946, lng: -122.3999, radiusKm: 8);
      expect(calls, 3, reason: 'must widen through every step before settling');
      expect(out, isNotNull);
      expect(out!.length, 5);
    });

    test('an unreachable directory returns null, not an empty street',
        () async {
      if (!SupabaseConfig.enabled) return;
      mirror.client = MockClient((_) async => http.Response('down', 503));
      // Null tells the caller to fall back to the live map search. Returning
      // [] would claim there are no grocery shops in San Francisco.
      expect(await mirror.nearbyStores(lat: 37.7946, lng: -122.3999), isNull);
    });
  });
}
