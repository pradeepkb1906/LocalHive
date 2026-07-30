import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Detects the user's city + US state via browser/device geolocation and
/// free OpenStreetMap reverse geocoding (no API key). Falls back to 'USA'.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  String label = 'USA';
  bool _requested = false;

  static const _stateAbbr = {
    'Alabama': 'AL',
    'Alaska': 'AK',
    'Arizona': 'AZ',
    'Arkansas': 'AR',
    'California': 'CA',
    'Colorado': 'CO',
    'Connecticut': 'CT',
    'Delaware': 'DE',
    'Florida': 'FL',
    'Georgia': 'GA',
    'Hawaii': 'HI',
    'Idaho': 'ID',
    'Illinois': 'IL',
    'Indiana': 'IN',
    'Iowa': 'IA',
    'Kansas': 'KS',
    'Kentucky': 'KY',
    'Louisiana': 'LA',
    'Maine': 'ME',
    'Maryland': 'MD',
    'Massachusetts': 'MA',
    'Michigan': 'MI',
    'Minnesota': 'MN',
    'Mississippi': 'MS',
    'Missouri': 'MO',
    'Montana': 'MT',
    'Nebraska': 'NE',
    'Nevada': 'NV',
    'New Hampshire': 'NH',
    'New Jersey': 'NJ',
    'New Mexico': 'NM',
    'New York': 'NY',
    'North Carolina': 'NC',
    'North Dakota': 'ND',
    'Ohio': 'OH',
    'Oklahoma': 'OK',
    'Oregon': 'OR',
    'Pennsylvania': 'PA',
    'Rhode Island': 'RI',
    'South Carolina': 'SC',
    'South Dakota': 'SD',
    'Tennessee': 'TN',
    'Texas': 'TX',
    'Utah': 'UT',
    'Vermont': 'VT',
    'Virginia': 'VA',
    'Washington': 'WA',
    'West Virginia': 'WV',
    'Wisconsin': 'WI',
    'Wyoming': 'WY',
    'District of Columbia': 'DC',
  };

  Future<void> detect() async {
    if (_requested) return;
    _requested = true;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _detectFromIp(); // laptops / denied permission: IP estimate
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low));
      // zoom=14 returns neighbourhood/suburb-level detail when available.
      final resp = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse'
            '?lat=${pos.latitude}&lon=${pos.longitude}&format=json&zoom=14'),
        headers: {'User-Agent': 'LocalHive/0.2 (localhive app)'},
      );
      if (resp.statusCode != 200) return;
      final addr =
          (jsonDecode(resp.body) as Map<String, dynamic>)['address'] ?? {};
      final area = (addr['suburb'] ??
          addr['neighbourhood'] ??
          addr['quarter'] ??
          addr['hamlet'] ??
          '') as String;
      final city = (addr['city'] ??
          addr['town'] ??
          addr['village'] ??
          addr['township'] ??
          addr['county'] ??
          '') as String;
      final state = (addr['state'] ?? '') as String;
      final abbr = _stateAbbr[state] ?? state;
      final parts = <String>[
        if (area.isNotEmpty && area != city) area,
        if (city.isNotEmpty) city,
        if (abbr.isNotEmpty) abbr,
      ];
      if (parts.isNotEmpty) label = parts.join(', ');
      notifyListeners();
    } catch (e) {
      debugPrint('Location detect failed: $e');
      await _detectFromIp();
    }
  }

  /// Coarse city-level location from the IP address — used on laptops or
  /// when GPS permission is denied. Free service, no API key.
  Future<void> _detectFromIp() async {
    try {
      final resp = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return;
      final d = jsonDecode(resp.body) as Map<String, dynamic>;
      final city = (d['city'] ?? '') as String;
      final region = (d['region_code'] ?? d['region'] ?? '') as String;
      if (city.isNotEmpty) {
        label = region.toString().isNotEmpty ? '$city, $region' : city;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('IP location failed: $e');
    }
  }
}
