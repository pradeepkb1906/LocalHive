import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/firebase_service.dart';
import '../services/geo.dart';
import '../theme.dart';

/// Live courier tracking. The delivery partner's phone publishes its GPS
/// position to the delivery job; this screen watches that document and moves
/// the courier's marker on the map, with distance and a rough ETA.
///
/// Used by the customer waiting for an order and by the store or truck owner
/// who wants to know where their order got to.
class TrackDeliveryScreen extends StatefulWidget {
  final String jobId;
  final String title;
  final String dropAddress;
  const TrackDeliveryScreen({
    super.key,
    required this.jobId,
    required this.title,
    required this.dropAddress,
  });

  @override
  State<TrackDeliveryScreen> createState() => _TrackDeliveryScreenState();
}

class _TrackDeliveryScreenState extends State<TrackDeliveryScreen> {
  final _map = MapController();
  LatLng? _drop;
  bool _geocoding = true;
  bool _followCourier = true;
  LatLng? _lastCentred;

  /// Typical door-to-door city driving speed, used for the ETA when the
  /// device is not reporting speed.
  static const _assumedKmh = 22.0;

  @override
  void initState() {
    super.initState();
    _geocodeDrop();
  }

  Future<void> _geocodeDrop() async {
    try {
      final resp = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(widget.dropAddress)}&format=json&limit=1'),
        headers: {'User-Agent': 'LocalHive/0.3 (localhive app)'},
      ).timeout(const Duration(seconds: 10));
      final list = jsonDecode(resp.body) as List;
      if (!mounted) return;
      setState(() {
        if (list.isNotEmpty) {
          final m = list.first as Map<String, dynamic>;
          _drop = LatLng(double.parse(m['lat']), double.parse(m['lon']));
        }
        _geocoding = false;
      });
    } catch (_) {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  double _km(LatLng a, LatLng b) =>
      distanceKm(a.latitude, a.longitude, b.latitude, b.longitude);

  String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 15) return 'just now';
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    return '${m ~/ 60}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track delivery'),
        actions: [
          IconButton(
            tooltip: _followCourier ? 'Following courier' : 'Follow courier',
            icon: Icon(
                _followCourier
                    ? CupertinoIcons.location_fill
                    : CupertinoIcons.location,
                size: 20),
            onPressed: () => setState(() => _followCourier = !_followCourier),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: FirebaseService.instance.deliveryJobStream(widget.jobId),
        builder: (context, snap) {
          final job = snap.data;
          final lat = (job?['courierLat'] as num?)?.toDouble();
          final lng = (job?['courierLng'] as num?)?.toDouble();
          final courier =
              (lat != null && lng != null) ? LatLng(lat, lng) : null;
          final status = (job?['status'] ?? '') as String;
          final stamp = (job?['courierAt'] as Timestamp?)?.toDate();
          final speed = (job?['courierSpeedMps'] as num?)?.toDouble() ?? 0;

          final distanceKm =
              (courier != null && _drop != null) ? _km(courier, _drop!) : null;
          // Prefer the courier's real speed; fall back to a city average.
          final kmh = speed > 1 ? speed * 3.6 : _assumedKmh;
          final etaMin = distanceKm == null
              ? null
              : math.max(1, (distanceKm / kmh * 60).round());

          if (_followCourier && courier != null && courier != _lastCentred) {
            _lastCentred = courier;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              // A courier position can arrive before the map has laid out —
              // reading the camera then throws, so keep the first frames quiet.
              try {
                _map.move(courier, _map.camera.zoom);
              } catch (_) {
                // The map centres on the courier via initialCenter anyway.
              }
            });
          }

          final centre = courier ?? _drop ?? const LatLng(40.7128, -74.0060);

          return Column(
            children: [
              Expanded(
                child: _geocoding
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        children: [
                          FlutterMap(
                            mapController: _map,
                            options: MapOptions(
                                initialCenter: centre, initialZoom: 14),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.localhive.localhive',
                              ),
                              if (courier != null && _drop != null)
                                PolylineLayer(polylines: [
                                  Polyline(
                                    points: [courier, _drop!],
                                    strokeWidth: 3,
                                    color:
                                        LhColors.blue.withValues(alpha: 0.55),
                                  ),
                                ]),
                              MarkerLayer(markers: [
                                if (_drop != null)
                                  Marker(
                                    point: _drop!,
                                    width: 150,
                                    height: 58,
                                    child: _Pin(
                                        label: 'Drop-off',
                                        color: const Color(0xFFFF3B30),
                                        icon: CupertinoIcons.location_solid),
                                  ),
                                if (courier != null)
                                  Marker(
                                    point: courier,
                                    width: 150,
                                    height: 58,
                                    child: _Pin(
                                        label: 'Your partner',
                                        color: LhColors.blue,
                                        icon: CupertinoIcons.car_detailed),
                                  ),
                              ]),
                              const RichAttributionWidget(attributions: [
                                TextSourceAttribution(
                                    '© OpenStreetMap contributors')
                              ]),
                            ],
                          ),
                          if (courier == null)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 16,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          CupertinoIcons
                                              .dot_radiowaves_left_right,
                                          color: LhColors.orange),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                            status == 'Delivered'
                                                ? 'This order was delivered. '
                                                    'Live location is no longer '
                                                    'shared.'
                                                : 'Waiting for your delivery '
                                                    'partner to start sharing '
                                                    'their location. It appears '
                                                    'here the moment they do.',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: LhColors.inkSecondary)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconTile(
                              icon: CupertinoIcons.cube_box_fill,
                              color: LhColors.orange,
                              size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    switch (status) {
                                      'Open' =>
                                        'Waiting for a delivery partner to accept',
                                      'Claimed' =>
                                        'Partner assigned — heading to pick up your order',
                                      'PickedUp' => 'On the way to you',
                                      'Delivered' => 'Delivered',
                                      _ => 'Preparing',
                                    },
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: LhColors.inkSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(
                                  value: distanceKm < 1
                                      ? '${(distanceKm * 1000).round()} m'
                                      : '${distanceKm.toStringAsFixed(1)} km',
                                  label: 'Away from you'),
                            ),
                            Container(
                                width: 0.5,
                                height: 34,
                                color: LhColors.hairline),
                            Expanded(
                              child: _Stat(
                                  value: '$etaMin min',
                                  label: 'Estimated arrival'),
                            ),
                          ],
                        ),
                      ],
                      if (stamp != null) ...[
                        const SizedBox(height: 10),
                        Text('Location updated ${_ago(stamp)}',
                            style: const TextStyle(
                                fontSize: 12, color: LhColors.inkSecondary)),
                      ],
                      const SizedBox(height: 6),
                      Text('Drop-off: ${widget.dropAddress}',
                          style: const TextStyle(
                              fontSize: 12.5, color: LhColors.inkSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Pin({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        Icon(icon, color: color, size: 26),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LhColors.navy)),
        Text(label,
            style:
                const TextStyle(fontSize: 11.5, color: LhColors.inkSecondary)),
      ],
    );
  }
}
