import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../geo.dart';

/// A real place found on the public map, anywhere in the world.
///
/// These are NOT LocalHive businesses. Olivia can tell the customer about them
/// and point them there, but no order can be placed — nobody at the other end
/// has a LocalHive account to receive it.
class NearbyPlace {
  final String name;
  final String kind;
  final String cuisine;
  final String area;
  final double lat;
  final double lng;
  final double km;
  final String openingHours;
  final String phone;

  const NearbyPlace({
    required this.name,
    required this.kind,
    required this.km,
    this.cuisine = '',
    this.area = '',
    this.lat = 0,
    this.lng = 0,
    this.openingHours = '',
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        if (cuisine.isNotEmpty) 'serves': cuisine,
        if (area.isNotEmpty) 'street': area,
        'distance': distanceLabel(km),
        if (openingHours.isNotEmpty) 'hours': openingHours,
        if (phone.isNotEmpty) 'phone': phone,
      };
}

/// Looks up real places around a coordinate using OpenStreetMap's Overpass
/// API — free, no key, and it covers the whole world, which matters because
/// LocalHive's own listings are only in New Jersey.
class PlacesSearch {
  PlacesSearch({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  /// OSM tag filters per kind of place a customer might ask about.
  /// Raw strings: the trailing `$` anchors belong to the OSM regex, not to
  /// Dart interpolation.
  static const _filters = <String, String>{
    'food':
        r'node["amenity"~"^(restaurant|fast_food|cafe|food_court|ice_cream)$"]',
    'street_food': r'node["amenity"~"^(fast_food|food_court)$"]',
    'groceries':
        r'node["shop"~"^(supermarket|convenience|greengrocer|general|deli)$"]',
    'hotel': r'node["tourism"~"^(hotel|guest_house|hostel)$"]',
    'pharmacy': r'node["amenity"="pharmacy"]',
  };

  static List<String> get kinds => _filters.keys.toList();

  /// Real places near [lat],[lng]. Returns an empty list rather than throwing:
  /// a failed map lookup should never break the conversation.
  Future<List<NearbyPlace>> search({
    required double lat,
    required double lng,
    required String kind,
    String? query,
    int radiusM = 3000,
    int limit = 12,
  }) async {
    final filter = _filters[kind] ?? _filters['food']!;
    // `out center` gives coordinates for ways as well as nodes.
    final ql = '[out:json][timeout:20];'
        '($filter(around:$radiusM,$lat,$lng););'
        'out center 60;';

    http.Response resp;
    try {
      resp = await _http.post(Uri.parse(_endpoint), body: ql, headers: {
        'User-Agent': 'LocalHive/0.3 (localhive app)'
      }).timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Nearby places lookup failed: $e');
      return const [];
    }
    if (resp.statusCode != 200) {
      debugPrint('Overpass returned ${resp.statusCode}');
      return const [];
    }

    final List elements;
    try {
      elements = (jsonDecode(resp.body) as Map<String, dynamic>)['elements']
              as List? ??
          const [];
    } catch (e) {
      debugPrint('Could not parse Overpass response: $e');
      return const [];
    }

    final wanted = (query ?? '').toLowerCase().trim();
    final terms =
        wanted.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();

    final places = <NearbyPlace>[];
    for (final raw in elements) {
      final e = raw as Map<String, dynamic>;
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = ((tags['name'] ?? '') as String).trim();
      // An unnamed point on a map is no use to someone deciding where to eat.
      if (name.isEmpty) continue;

      final plat = (e['lat'] as num?)?.toDouble() ??
          ((e['center'] as Map?)?['lat'] as num?)?.toDouble();
      final plng = (e['lon'] as num?)?.toDouble() ??
          ((e['center'] as Map?)?['lon'] as num?)?.toDouble();
      if (plat == null || plng == null) continue;

      final cuisine =
          ((tags['cuisine'] ?? '') as String).replaceAll('_', ' ').trim();
      final street = [
        (tags['addr:housenumber'] ?? '') as String,
        (tags['addr:street'] ?? '') as String,
      ].where((s) => s.isNotEmpty).join(' ');

      if (terms.isNotEmpty) {
        final hay = '$name $cuisine ${tags['amenity'] ?? ''} '
                '${tags['shop'] ?? ''}'
            .toLowerCase();
        if (!terms.any(hay.contains)) continue;
      }

      places.add(NearbyPlace(
        name: name,
        kind: ((tags['amenity'] ?? tags['shop'] ?? tags['tourism'] ?? 'place')
                as String)
            .replaceAll('_', ' '),
        cuisine: cuisine,
        area: street,
        lat: plat,
        lng: plng,
        km: distanceKm(lat, lng, plat, plng),
        openingHours: ((tags['opening_hours'] ?? '') as String).trim(),
        phone:
            ((tags['phone'] ?? tags['contact:phone'] ?? '') as String).trim(),
      ));
    }

    places.sort((a, b) => a.km.compareTo(b.km));
    return places.take(limit).toList();
  }

  void dispose() => _http.close();
}
