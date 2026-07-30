import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'firebase_service.dart';

/// Publishes the delivery partner's GPS position to Firestore while they have
/// a delivery in progress, so the customer and the business can watch the
/// courier move on a map.
///
/// The beacon only runs while there is at least one active job: it starts the
/// device's position stream on the first active job and shuts it down when the
/// last one is delivered, so an idle partner's battery and location are left
/// alone.
class CourierBeacon extends ChangeNotifier {
  CourierBeacon._();
  static final CourierBeacon instance = CourierBeacon._();

  /// Publish at most this often, however chatty the GPS is.
  static const _minInterval = Duration(seconds: 10);

  StreamSubscription<Position>? _sub;
  final Set<String> _jobs = {};
  DateTime? _lastPush;

  /// True while the device is sharing its position.
  bool get sharing => _sub != null;

  /// The last position we published — shown back to the partner so they can
  /// see that sharing is really working.
  Position? lastPosition;
  String? lastError;

  /// Called by the delivery screen whenever the partner's job list changes.
  /// Idempotent: safe to call on every rebuild.
  void syncActiveJobs(Iterable<String> jobIds) {
    final next = jobIds.toSet();
    if (setEquals(next, _jobs)) return;
    _jobs
      ..clear()
      ..addAll(next);
    if (_jobs.isEmpty) {
      _stop();
    } else {
      _start();
    }
    notifyListeners();
  }

  Future<void> _start() async {
    if (_sub != null) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        lastError = 'Location permission is off, so the customer cannot see '
            'you on the map. Enable location for LocalHive to share your '
            'progress.';
        notifyListeners();
        return;
      }
      lastError = null;
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // metres
        ),
      ).listen(_onPosition, onError: (e) {
        lastError = 'Could not read your location: $e';
        notifyListeners();
      });
      notifyListeners();
      // Publish immediately so the map is populated before the courier moves.
      final now = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      _onPosition(now, force: true);
    } catch (e) {
      lastError = 'Location unavailable: $e';
      notifyListeners();
    }
  }

  void _onPosition(Position p, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastPush != null &&
        now.difference(_lastPush!) < _minInterval) {
      return;
    }
    _lastPush = now;
    lastPosition = p;
    for (final jobId in _jobs) {
      FirebaseService.instance.publishCourierPosition(
          jobId, p.latitude, p.longitude,
          speedMps: p.speed.isFinite && p.speed > 0 ? p.speed : 0);
    }
    notifyListeners();
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _lastPush = null;
  }

  /// Called on sign-out.
  void reset() {
    _jobs.clear();
    _stop();
    lastPosition = null;
    lastError = null;
    notifyListeners();
  }
}
