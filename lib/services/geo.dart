import 'dart:math' as math;

/// Great-circle distance in kilometres between two coordinates.
///
/// Used both for courier-to-drop-off on the tracking map and for ranking
/// businesses by how close they are to the customer.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = lat1 * math.pi / 180;
  final b = lat2 * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a) * math.cos(b) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

/// Distance rendered the way a person would say it — "400 m", "1.2 km".
String distanceLabel(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// Rough arrival estimate in whole minutes. Falls back to a typical city
/// driving speed when the device is not reporting a usable speed.
int etaMinutes(double km, {double speedMps = 0, double assumedKmh = 22}) {
  final kmh = speedMps > 1 ? speedMps * 3.6 : assumedKmh;
  return math.max(1, (km / kmh * 60).round());
}

/// Parses a free-form availability string like "9 AM", "9:30 AM" or "18:00"
/// into minutes past midnight. Returns null when it cannot be understood —
/// callers should treat that as "no stated hours" rather than "closed".
int? parseTimeOfDay(String raw) {
  final s = raw.trim().toUpperCase();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?$').firstMatch(s);
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2) ?? '0');
  final meridiem = m.group(3);
  if (hour > 23 || minute > 59) return null;
  if (meridiem == 'PM' && hour != 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

/// Whether `now` falls inside a business's stated availability window.
///
/// Returns true when the window is missing or unparseable: most listings have
/// no hours recorded yet, and claiming they are closed would be worse than
/// saying nothing. Windows that wrap past midnight are handled.
bool isOpenAt(String availableFrom, String availableTo, DateTime now) {
  final from = parseTimeOfDay(availableFrom);
  final to = parseTimeOfDay(availableTo);
  if (from == null || to == null) return true;
  final minutes = now.hour * 60 + now.minute;
  if (from == to) return true;
  return from < to
      ? minutes >= from && minutes <= to
      : minutes >= from || minutes <= to; // e.g. 6 PM – 2 AM
}
