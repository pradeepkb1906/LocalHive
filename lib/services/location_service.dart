import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ca_cities.dart';

/// Where the app thinks the customer is standing.
///
/// LocalHive serves California only, so this is not a plain geolocator
/// wrapper: it is the service-area boundary. A real fix is used when it lands
/// inside the state and discarded when it does not. A phone in Bengaluru,
/// London or New York gets San Francisco rather than a screen full of shops
/// nobody here can deliver from — and the customer can pick any other
/// California city from the chip.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _cityKey = 'lh_ca_city';

  /// The city the customer is browsing. Always a California one.
  CaCity city = defaultCaCity;

  /// True when [lat]/[lng] came from the device rather than from the chosen
  /// city — so the app can rank by real distance instead of city centre.
  bool usingDeviceLocation = false;

  /// True when the device reported a position outside California. Screens use
  /// this to explain why they are showing San Francisco to someone who is
  /// demonstrably somewhere else, rather than looking broken.
  bool deviceOutsideServiceArea = false;

  String label = defaultCaCity.label;

  /// The user's coordinates once detected, so features like "food trucks near
  /// me" can rank by real distance rather than by the city label alone. Null
  /// until [detect] resolves a position; the IP fallback fills these in coarsely.
  double? lat = defaultCaCity.lat;
  double? lng = defaultCaCity.lng;

  bool get hasPosition => lat != null && lng != null;

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

  /// Restores the customer's chosen city, then tries the device.
  ///
  /// Order matters: the stored choice is applied first so the app has a
  /// sensible California position from the very first frame, and a slow or
  /// refused GPS prompt never leaves the screen empty.
  Future<void> detect() async {
    if (_requested) return;
    _requested = true;
    await _restoreCity();
    await _tryDevice();
  }

  /// Puts the customer in [c] and remembers it. Clears any device fix: they
  /// have said where they want to be, which outranks where the phone is.
  Future<void> setCity(CaCity c) async {
    city = c;
    lat = c.lat;
    lng = c.lng;
    label = c.label;
    usingDeviceLocation = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cityKey, c.name);
    } catch (e) {
      // A city that does not survive a restart is a small annoyance; a crash
      // on a storage failure is not.
      debugPrint('could not remember the city: $e');
    }
  }

  Future<void> _restoreCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_cityKey);
      if (saved == null) return;
      final match = caCities.where((c) => c.name == saved);
      if (match.isEmpty) return;
      city = match.first;
      lat = city.lat;
      lng = city.lng;
      label = city.label;
      notifyListeners();
    } catch (e) {
      debugPrint('could not read the saved city: $e');
    }
  }

  /// Uses the device position only if it is inside California.
  Future<void> _tryDevice() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _detectFromIp();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low));
      _applyIfInCalifornia(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('Location detect failed: $e');
      await _detectFromIp();
    }
  }

  /// Coarse city-level location from the IP address — laptops, or when GPS
  /// permission is refused. Free, no API key. Subject to the same boundary.
  Future<void> _detectFromIp() async {
    try {
      final resp = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return;
      final d = jsonDecode(resp.body) as Map<String, dynamic>;
      final dlat = (d['latitude'] as num?)?.toDouble();
      final dlng = (d['longitude'] as num?)?.toDouble();
      if (dlat == null || dlng == null) return;
      _applyIfInCalifornia(dlat, dlng);
    } catch (e) {
      debugPrint('IP location failed: $e');
    }
  }

  /// The boundary itself.
  ///
  /// Inside California the real position wins, because a customer in the
  /// Mission wants shops on their street and not the city centre. Outside it
  /// the position is discarded entirely and the chosen city stands — this is
  /// what makes a demo in Bengaluru show San Francisco.
  void _applyIfInCalifornia(double dlat, double dlng) {
    if (!isInCalifornia(dlat, dlng)) {
      deviceOutsideServiceArea = true;
      notifyListeners();
      return;
    }
    lat = dlat;
    lng = dlng;
    usingDeviceLocation = true;
    deviceOutsideServiceArea = false;
    city = nearestCaCity(dlat, dlng);
    label = city.label;
    notifyListeners();
    // The neighbourhood name is a nicety, so a failure here must not undo a
    // perfectly good position.
    unawaited(_refineLabel(dlat, dlng));
  }

  /// Replaces the city label with a neighbourhood one where OSM has it, so a
  /// customer in the Mission sees "Mission District, San Francisco, CA".
  Future<void> _refineLabel(double dlat, double dlng) async {
    try {
      final resp = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse'
            '?lat=$dlat&lon=$dlng&format=json&zoom=14'),
        headers: {'User-Agent': 'LocalHive/0.3 (localhive app)'},
      ).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return;
      final addr =
          (jsonDecode(resp.body) as Map<String, dynamic>)['address'] ?? {};
      final area = (addr['suburb'] ??
          addr['neighbourhood'] ??
          addr['quarter'] ??
          addr['hamlet'] ??
          '') as String;
      final town =
          (addr['city'] ?? addr['town'] ?? addr['village'] ?? '') as String;
      final state = (addr['state'] ?? '') as String;
      // Belt and braces: if the geocoder disagrees that this is California,
      // trust the geocoder and leave the label alone.
      if (state.isNotEmpty && _stateAbbr[state] != 'CA') return;
      final parts = <String>[
        if (area.isNotEmpty && area != town) area,
        if (town.isNotEmpty) town else city.name,
        'CA',
      ];
      label = parts.join(', ');
      notifyListeners();
    } catch (e) {
      debugPrint('label refine failed: $e');
    }
  }
}
