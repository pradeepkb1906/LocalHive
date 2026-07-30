import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/directions.dart';
import '../theme.dart';

/// In-app directions preview: shows the destination pinned on a real map
/// (OpenStreetMap, no API key) with one tap to hand off to Google/Apple Maps
/// for turn-by-turn navigation. Works in every browser — no popup blockers.
class DirectionsScreen extends StatefulWidget {
  final String title;
  final String address;
  final double lat;
  final double lng;
  const DirectionsScreen({
    super.key,
    required this.title,
    required this.address,
    this.lat = 0,
    this.lng = 0,
  });

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  LatLng? _point;
  String? _resolved;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.lat != 0 || widget.lng != 0) {
      _point = LatLng(widget.lat, widget.lng);
      _loading = false;
    } else {
      _geocode();
    }
  }

  /// Free OpenStreetMap forward geocoding — turns the street address into
  /// map coordinates so we can show the exact spot.
  Future<void> _geocode() async {
    try {
      final resp = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search'
            '?q=${Uri.encodeComponent(widget.address)}&format=json&limit=1'),
        headers: {'User-Agent': 'LocalHive/0.3 (localhive app)'},
      ).timeout(const Duration(seconds: 10));
      final list = jsonDecode(resp.body) as List;
      if (list.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'We could not pin this address on the map, but you can '
              'still open it in Google Maps below.';
        });
        return;
      }
      final m = list.first as Map<String, dynamic>;
      setState(() {
        _point = LatLng(double.parse(m['lat']), double.parse(m['lon']));
        _resolved = m['display_name'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Map preview unavailable — open in Google Maps below.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directions')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _point == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.map,
                                  size: 44, color: LhColors.hairline),
                              const SizedBox(height: 12),
                              Text(_error ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: LhColors.inkSecondary)),
                            ],
                          ),
                        ),
                      )
                    : FlutterMap(
                        options:
                            MapOptions(initialCenter: _point!, initialZoom: 15),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.localhive.localhive',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: _point!,
                              width: 180,
                              height: 62,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: LhColors.navy,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const Icon(CupertinoIcons.location_solid,
                                      color: Color(0xFFFF3B30), size: 28),
                                ],
                              ),
                            ),
                          ]),
                          const RichAttributionWidget(attributions: [
                            TextSourceAttribution(
                                '© OpenStreetMap contributors')
                          ]),
                        ],
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.location_solid,
                          size: 16, color: LhColors.inkSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.address,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600)),
                            if (_resolved != null)
                              Text(_resolved!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: LhColors.inkSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => openDirectionsWithFallback(context,
                        address: widget.address,
                        lat: widget.lat,
                        lng: widget.lng),
                    icon: const Icon(CupertinoIcons.arrow_turn_up_right,
                        size: 18),
                    label: const Text('Start Navigation in Google Maps'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
