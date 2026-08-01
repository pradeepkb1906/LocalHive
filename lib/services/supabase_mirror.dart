import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/data.dart';
import 'geo.dart';
import 'olivia/places_search.dart';
import '../supabase_config.dart';

/// A read-only standby copy of the public store catalog, held in Supabase.
///
/// Firestore is the system of record: every write goes there and nothing is
/// written here from the app. This exists for the day Firestore cannot be
/// read — an outage, or the free tier's daily read quota running out, which
/// has already happened once and took the catalog down for a full day. When
/// that happens the app falls back to this mirror so customers can still see
/// which stores exist, their hours and their phone numbers. Ordering stays
/// unavailable, and the UI says so rather than pretending.
///
/// Deliberately plain HTTP against Supabase's REST endpoint rather than the
/// Supabase SDK: one fewer dependency, no extra weight in the web bundle,
/// and a standby path with fewer moving parts than the thing it is standing
/// in for.
class SupabaseMirror extends ChangeNotifier {
  SupabaseMirror._();
  static final SupabaseMirror instance = SupabaseMirror._();

  /// Overridable so tests never touch the network.
  @visibleForTesting
  http.Client client = http.Client();

  bool get enabled => SupabaseConfig.enabled;

  /// True once a read has actually fallen through to the mirror, so screens
  /// can tell the customer what they are looking at — and so the app can
  /// refuse to take orders it has no way to record.
  bool get servingFromMirror => _servingFromMirror;
  bool _servingFromMirror = false;

  /// When the app fell back, so the customer can be told how old this view
  /// is rather than being left to assume it is live.
  DateTime? servingSince;

  @visibleForTesting
  set servingFromMirror(bool v) {
    if (_servingFromMirror == v) return;
    _servingFromMirror = v;
    servingSince = v ? DateTime.now() : null;
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      };

  /// Live listings of [category] from the mirror, nearest-agnostic and
  /// ordered by name. Returns null when the mirror is switched off or itself
  /// unreachable — the caller then has nothing to show, which is the honest
  /// outcome when both backends are down.
  Future<List<Provider>?> providers(String category) async {
    if (!enabled) return null;
    try {
      final uri = Uri.parse('${SupabaseConfig.url}/rest/v1/providers'
          '?select=*&live=eq.true&category=eq.$category&order=name');
      final resp = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        debugPrint('Supabase mirror returned ${resp.statusCode}');
        return null;
      }
      final rows = jsonDecode(resp.body) as List;
      final list = rows
          .whereType<Map<String, dynamic>>()
          .map(providerFromMirrorRow)
          .where((p) => p.name.isNotEmpty)
          .toList();
      servingFromMirror = true;
      return list;
    } catch (e) {
      debugPrint('Supabase mirror unreachable: $e');
      return null;
    }
  }

  /// Real grocery shops around [lat]/[lng] that have NOT joined LocalHive,
  /// from the directory mirrored out of OpenStreetMap.
  ///
  /// Served from here rather than queried live so a sales demo does not
  /// depend on a third-party map API answering in the moment — and so the
  /// list appears instantly instead of after a round trip to Overpass.
  /// Returns null when the mirror is off or unreachable; the caller then
  /// falls back to the live map search.
  Future<List<NearbyStore>?> nearbyStores({
    required double lat,
    required double lng,
    double radiusKm = 8,
    int want = 20,
  }) async {
    if (!enabled) return null;
    // Widen from a tight box outwards rather than asking for the full radius
    // in one go. The row cap is applied by the server BEFORE anything is
    // sorted by distance, so a single wide query in a dense neighbourhood
    // returns an arbitrary 200 rows out of the box and silently drops the
    // shop across the street. Downtown San Francisco showed its nearest
    // grocery as 3.4 km away because of exactly that.
    for (final km in <double>[1.5, 4, radiusKm]) {
      if (km > radiusKm) break;
      final found = await _storesInBox(lat: lat, lng: lng, radiusKm: km);
      if (found == null) return null; // unreachable, not merely empty
      if (found.length >= want || km >= radiusKm) return found;
    }
    return const [];
  }

  Future<List<NearbyStore>?> _storesInBox({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final dLat = radiusKm / 111.0;
    final dLng = radiusKm / (111.0 * math.cos(lat * math.pi / 180).abs());
    try {
      final uri = Uri.parse('${SupabaseConfig.url}/rest/v1/nearby_stores'
          '?select=*'
          '&lat=gte.${(lat - dLat).toStringAsFixed(4)}'
          '&lat=lte.${(lat + dLat).toStringAsFixed(4)}'
          '&lng=gte.${(lng - dLng).toStringAsFixed(4)}'
          '&lng=lte.${(lng + dLng).toStringAsFixed(4)}'
          '&limit=200');
      final resp = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final rows = jsonDecode(resp.body) as List;
      final out = <NearbyStore>[];
      for (final r in rows.whereType<Map<String, dynamic>>()) {
        final slat = (r['lat'] as num?)?.toDouble();
        final slng = (r['lng'] as num?)?.toDouble();
        final name = '${r['name'] ?? ''}'.trim();
        if (slat == null || slng == null || name.isEmpty) continue;
        final km = distanceKm(lat, lng, slat, slng);
        if (km > radiusKm) continue;
        out.add(NearbyStore(
          name: name,
          kind: '${r['kind'] ?? 'Grocery'}',
          street: '${r['street'] ?? ''}',
          city: '${r['city'] ?? ''}',
          phone: '${r['phone'] ?? ''}',
          hours: '${r['hours'] ?? ''}',
          lat: slat,
          lng: slng,
          km: km,
        ));
      }
      out.sort((a, b) => a.km.compareTo(b.km));
      return out;
    } catch (e) {
      debugPrint('nearby_stores lookup failed: $e');
      return null;
    }
  }

  /// A quick liveness probe, for the System check screen.
  Future<bool> reachable() async {
    if (!enabled) return false;
    try {
      final uri = Uri.parse(
          '${SupabaseConfig.url}/rest/v1/providers?select=id&limit=1');
      final resp = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Maps one mirrored row onto the app's [Provider]. Column names match the
/// Firestore field names so the sync script is a straight copy.
Provider providerFromMirrorRow(Map<String, dynamic> m) => Provider(
      id: '${m['id'] ?? ''}',
      name: '${m['name'] ?? ''}',
      category: '${m['category'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      rating: (m['rating'] as num?)?.toDouble() ?? 0,
      reviews: (m['reviews'] as num?)?.toInt() ?? 0,
      hourlyRate: (m['hourly_rate'] as num?)?.toDouble() ?? 0,
      city: '${m['city'] ?? ''}',
      verified: m['verified'] == true,
      emoji: '${m['emoji'] ?? ''}',
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      availableFrom: '${m['available_from'] ?? ''}',
      availableTo: '${m['available_to'] ?? ''}',
    );

/// A real shop from the public map that has not joined LocalHive. Findable
/// and callable; not orderable, and the UI says so.
class NearbyStore {
  final String name;
  final String kind;
  final String street;
  final String city;
  final String phone;
  final String hours;
  final double lat;
  final double lng;
  final double km;

  const NearbyStore({
    required this.name,
    required this.lat,
    required this.lng,
    required this.km,
    this.kind = 'Grocery',
    this.street = '',
    this.city = '',
    this.phone = '',
    this.hours = '',
  });

  String get address => [street, city].where((s) => s.isNotEmpty).join(', ');

  /// The directory and the live map search feed the same cards, so a shop
  /// looks identical whether it came from here or from Overpass.
  NearbyPlace toPlace() => NearbyPlace(
        name: name,
        kind: kind,
        km: km,
        address: address,
        lat: lat,
        lng: lng,
        openingHours: hours,
        phone: phone,
      );
}
