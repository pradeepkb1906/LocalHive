import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'location_service.dart';

/// US address search and current-location lookup over free OpenStreetMap
/// services (Nominatim) — the same provider the location chip and Nearby map
/// already use, so no API key is involved.
class AddressSuggestion {
  /// Full formatted address, ready to drop into an address field.
  final String address;

  /// Shorter first line for the suggestion list (street or place name).
  final String title;

  const AddressSuggestion({required this.address, required this.title});
}

const _headers = {'User-Agent': 'LocalHive/0.3 (localhive app)'};

/// Builds "123 Main St, Edison, NJ 08820" from a Nominatim address object,
/// tolerating whichever pieces are missing.
String formatUsAddress(Map<String, dynamic> a, {String fallback = ''}) {
  final house = '${a['house_number'] ?? ''}';
  final road = '${a['road'] ?? a['pedestrian'] ?? a['footway'] ?? ''}';
  final city =
      '${a['city'] ?? a['town'] ?? a['village'] ?? a['township'] ?? a['hamlet'] ?? a['county'] ?? ''}';
  final state = '${a['state'] ?? ''}';
  final zip = '${a['postcode'] ?? ''}';
  final street = [house, road].where((s) => s.isNotEmpty).join(' ');
  final stateZip = [state, zip].where((s) => s.isNotEmpty).join(' ');
  final parts = [street, city, stateZip].where((s) => s.isNotEmpty).toList();
  return parts.isEmpty ? fallback : parts.join(', ');
}

/// Live address search, US-limited, at most 5 results. Returns [] on any
/// failure — the field just shows no suggestions rather than an error.
Future<List<AddressSuggestion>> searchUsAddresses(String query) async {
  if (query.trim().length < 3) return const [];
  try {
    final resp = await http
        .get(
          Uri.parse('https://nominatim.openstreetmap.org/search'
              '?q=${Uri.encodeComponent(query)}'
              '&countrycodes=us&format=jsonv2&addressdetails=1&limit=5'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return const [];
    final rows = jsonDecode(resp.body) as List;
    final seen = <String>{};
    final out = <AddressSuggestion>[];
    for (final r in rows.whereType<Map<String, dynamic>>()) {
      final addr = (r['address'] as Map?)?.cast<String, dynamic>() ?? const {};
      final formatted =
          formatUsAddress(addr, fallback: '${r['display_name'] ?? ''}');
      if (formatted.isEmpty || !seen.add(formatted)) continue;
      final title = '${r['name'] ?? ''}'.isNotEmpty
          ? '${r['name']}'
          : formatted.split(',').first;
      out.add(AddressSuggestion(address: formatted, title: title));
    }
    return out;
  } catch (e) {
    debugPrint('Address search failed: $e');
    return const [];
  }
}

/// The user's current position as a full street-level address ("where I am
/// standing right now"). Uses the GPS fix the location chip already obtained
/// (or triggers one), then reverse geocodes at house-number zoom. Null when
/// no position or lookup fails.
Future<String?> currentStreetAddress() async {
  final loc = LocationService.instance;
  if (!loc.hasPosition) await loc.detect();
  if (!loc.hasPosition) return null;
  try {
    final resp = await http
        .get(
          Uri.parse('https://nominatim.openstreetmap.org/reverse'
              '?lat=${loc.lat}&lon=${loc.lng}&format=jsonv2'
              '&addressdetails=1&zoom=18'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final d = jsonDecode(resp.body) as Map<String, dynamic>;
    final addr = (d['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final formatted =
        formatUsAddress(addr, fallback: '${d['display_name'] ?? ''}');
    return formatted.isEmpty ? null : formatted;
  } catch (e) {
    debugPrint('Reverse geocode failed: $e');
    return null;
  }
}
