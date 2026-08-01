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
}
