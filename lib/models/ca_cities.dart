/// LocalHive serves California only.
///
/// The device's real position is useful when the customer is actually in the
/// state and useless everywhere else: a phone in Bengaluru or London would
/// otherwise anchor the whole app to a place with no grocery shops in the
/// directory and no partners to order from. So the service area is a hard
/// boundary — outside it the app falls back to a chosen California city
/// rather than showing an empty street or, worse, shops on another continent.
library;

/// One of the places a customer can put themselves.
class CaCity {
  final String name;
  final double lat;
  final double lng;

  const CaCity(this.name, this.lat, this.lng);

  /// How the chip and the pickers spell it.
  String get label => '$name, CA';

  @override
  bool operator ==(Object other) => other is CaCity && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Where a customer lands before they choose anything, and where the app
/// returns to when the device is outside the state. San Francisco, because
/// that is the city LocalHive actually operates in.
const defaultCaCity = CaCity('San Francisco', 37.7749, -122.4194);

/// California's outline, close enough to decide which of two experiences a
/// customer gets.
///
/// A plain rectangle will not do. The state's eastern border runs straight
/// south to Lake Tahoe and then cuts diagonally down to the Colorado River,
/// so a box wide enough to hold Needles also swallows Las Vegas — and a
/// customer in Las Vegas would be told they are in the service area and then
/// shown no shops at all, which is worse than being sent to San Francisco.
/// The diagonal is modelled as two segments; this decides a fallback, not
/// whether an address is deliverable, so a mile or two of slop is fine.
const caMinLat = 32.53; // Mexican border, south of San Diego
const caMaxLat = 42.00; // Oregon border
const caMinLng = -124.55; // Pacific, west of Cape Mendocino

// Where the border turns: Lake Tahoe, and the bend near Needles.
const _tahoeLat = 39.00;
const _tahoeLng = -120.00;
const _bendLat = 34.87;
const _bendLng = -114.57; // by Needles, which sits on the west bank
const _riverLng = -114.72; // where the river meets the Mexican border

/// The easternmost longitude that is still California at this latitude.
///
/// Two straight segments: north-south down to Lake Tahoe, then the diagonal
/// to the Colorado River, then the river's own slight drift south to Mexico.
/// Yuma and Winterhaven are five kilometres apart on opposite banks and no
/// two-segment model separates them — this errs towards excluding that strip,
/// which costs a village of a few hundred people a default city they can
/// change in one tap.
double caEastBoundAt(double lat) {
  if (lat >= _tahoeLat) return _tahoeLng;
  if (lat >= _bendLat) {
    final t = (_tahoeLat - lat) / (_tahoeLat - _bendLat);
    return _tahoeLng + t * (_bendLng - _tahoeLng);
  }
  final t = ((_bendLat - lat) / (_bendLat - caMinLat)).clamp(0.0, 1.0);
  return _bendLng + t * (_riverLng - _bendLng);
}

bool isInCalifornia(double lat, double lng) =>
    lat >= caMinLat &&
    lat <= caMaxLat &&
    lng >= caMinLng &&
    lng <= caEastBoundAt(lat);

/// The cities a customer can pick, roughly north to south so the list reads
/// like the state rather than like an alphabet. The Bay Area is dense at the
/// top because that is where the shops and the partners are.
const caCities = <CaCity>[
  CaCity('San Francisco', 37.7749, -122.4194),
  CaCity('Daly City', 37.6879, -122.4702),
  CaCity('South San Francisco', 37.6547, -122.4077),
  CaCity('Oakland', 37.8044, -122.2712),
  CaCity('Berkeley', 37.8715, -122.2730),
  CaCity('Richmond', 37.9358, -122.3477),
  CaCity('San Rafael', 37.9735, -122.5311),
  CaCity('Walnut Creek', 37.9101, -122.0652),
  CaCity('Concord', 37.9780, -122.0311),
  CaCity('Vallejo', 38.1041, -122.2566),
  CaCity('Napa', 38.2975, -122.2869),
  CaCity('Santa Rosa', 38.4404, -122.7141),
  CaCity('San Mateo', 37.5630, -122.3255),
  CaCity('Redwood City', 37.4852, -122.2364),
  CaCity('Palo Alto', 37.4419, -122.1430),
  CaCity('Mountain View', 37.3861, -122.0839),
  CaCity('Sunnyvale', 37.3688, -122.0363),
  CaCity('Santa Clara', 37.3541, -121.9552),
  CaCity('San Jose', 37.3382, -121.8863),
  CaCity('Fremont', 37.5485, -121.9886),
  CaCity('Hayward', 37.6688, -122.0808),
  CaCity('Santa Cruz', 36.9741, -122.0308),
  CaCity('Monterey', 36.6002, -121.8947),
  CaCity('Sacramento', 38.5816, -121.4944),
  CaCity('Stockton', 37.9577, -121.2908),
  CaCity('Modesto', 37.6391, -120.9969),
  CaCity('Fresno', 36.7378, -119.7871),
  CaCity('Bakersfield', 35.3733, -119.0187),
  CaCity('San Luis Obispo', 35.2828, -120.6596),
  CaCity('Santa Barbara', 34.4208, -119.6982),
  CaCity('Pasadena', 34.1478, -118.1445),
  CaCity('Los Angeles', 34.0522, -118.2437),
  CaCity('Santa Monica', 34.0195, -118.4912),
  CaCity('Long Beach', 33.7701, -118.1937),
  CaCity('Anaheim', 33.8366, -117.9143),
  CaCity('Irvine', 33.6846, -117.8265),
  CaCity('Riverside', 33.9806, -117.3755),
  CaCity('San Bernardino', 34.1083, -117.2898),
  CaCity('San Diego', 32.7157, -117.1611),
  CaCity('Chula Vista', 32.6401, -117.0842),
];

/// The listed city nearest to a point, for labelling a real GPS fix inside
/// the state. Straight-line distance is plenty — this picks a label, not a
/// route.
CaCity nearestCaCity(double lat, double lng) {
  var best = caCities.first;
  var bestScore = double.infinity;
  for (final c in caCities) {
    final dLat = c.lat - lat;
    // Longitude degrees are narrower this far north; weighting them keeps
    // an east-west neighbour from looking closer than it is.
    final dLng = (c.lng - lng) * 0.79;
    final score = dLat * dLat + dLng * dLng;
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best;
}

/// Find cities by name for the picker's search box.
List<CaCity> searchCaCities(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return caCities;
  final starts = <CaCity>[], contains = <CaCity>[];
  for (final c in caCities) {
    final n = c.name.toLowerCase();
    if (n.startsWith(q)) {
      starts.add(c);
    } else if (n.contains(q)) {
      contains.add(c);
    }
  }
  return [...starts, ...contains];
}
