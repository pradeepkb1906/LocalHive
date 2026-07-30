import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/geo.dart';
import '../services/location_service.dart';
import '../services/olivia/places_search.dart';
import '../theme.dart';

/// Everything genuinely around the customer, on a map — whether or not it has
/// partnered with LocalHive.
///
/// The pins come from the public map (OpenStreetMap), the same live source
/// Olivia uses, so a customer in a city with no partners yet still sees the
/// real restaurants, stores, handyman trades, gas stations and EV chargers
/// near them. These places cannot take a LocalHive order — nobody at the other
/// end has an account — so each card offers directions instead, and says so.
class NearbyMapScreen extends StatefulWidget {
  /// Which chip starts selected — the empty state that opened this screen
  /// passes its own category so the map answers the question the customer
  /// actually had.
  final String initialKind;
  const NearbyMapScreen({super.key, this.initialKind = 'food'});

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final _map = MapController();
  final _places = PlacesSearch();

  /// Chip label, search kind, pin emoji.
  static const _kinds = [
    ('Restaurants', 'food', '🍽️'),
    ('Groceries', 'groceries', '🛒'),
    ('Handyman', 'handyman', '🔧'),
    ('Hardware', 'hardware_store', '🛠️'),
    ('Gas', 'gas_station', '⛽'),
    ('EV charging', 'ev_charging', '⚡'),
    ('Pharmacy', 'pharmacy', '💊'),
  ];

  late String _kind = widget.initialKind;
  List<NearbyPlace> _results = const [];
  bool _loading = true;
  bool _noLocation = false;
  NearbyPlace? _selected;

  LatLng? get _centre {
    final loc = LocationService.instance;
    if (loc.hasPosition) return LatLng(loc.lat!, loc.lng!);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _places.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var centre = _centre;
    if (centre == null) {
      // One more chance: the customer may not have granted location before.
      await LocationService.instance.detect();
      centre = _centre;
    }
    if (centre == null) {
      if (mounted) {
        setState(() {
          _noLocation = true;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _selected = null;
    });
    final results = await _places.search(
      lat: centre.latitude,
      lng: centre.longitude,
      kind: _kind,
      radiusM: 6000,
      limit: 25,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _openDirections(NearbyPlace p) async {
    // The universal maps URL: opens Google Maps where installed, the browser
    // otherwise, and Apple Maps offers to take over on iOS.
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${p.lat},${p.lng}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final centre = _centre ?? const LatLng(40.7128, -74.0060);

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby now')),
      body: Column(
        children: [
          // The honesty banner: these are not partners, and that matters.
          Container(
            width: double.infinity,
            color: LhColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: const Text(
              'Live from the public map — real places around you, including '
              'ones LocalHive has not partnered with yet. Ordering in-app '
              'is not available for these; use directions instead.',
              style: TextStyle(fontSize: 12.5, color: LhColors.inkSecondary),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (label, kind, emoji) in _kinds)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('$emoji $label'),
                      selected: _kind == kind,
                      onSelected: (_) {
                        setState(() => _kind = kind);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _noLocation
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Turn on location to see what is around you — the map '
                        'needs to know where "nearby" is.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14.5, color: LhColors.inkSecondary),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options:
                            MapOptions(initialCenter: centre, initialZoom: 13),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.localhive.localhive',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: centre,
                              width: 44,
                              height: 44,
                              child: const Icon(
                                  CupertinoIcons.person_crop_circle_fill,
                                  color: LhColors.blue,
                                  size: 30),
                            ),
                            for (final p in _results)
                              Marker(
                                point: LatLng(p.lat, p.lng),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selected = p),
                                  child: Text(
                                    _kinds
                                        .firstWhere((k) => k.$2 == _kind,
                                            orElse: () => _kinds.first)
                                        .$3,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                          ]),
                          const RichAttributionWidget(attributions: [
                            TextSourceAttribution(
                                '© OpenStreetMap contributors')
                          ]),
                        ],
                      ),
                      if (_loading)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x66FFFFFF),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      if (!_loading && _results.isEmpty)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 16,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                'Nothing of this kind is on the public map '
                                'within a few miles. Try another category.',
                                style: const TextStyle(
                                    fontSize: 13, color: LhColors.inkSecondary),
                              ),
                            ),
                          ),
                        ),
                      if (_selected != null)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _PlaceCard(
                            place: _selected!,
                            onDirections: () => _openDirections(_selected!),
                            onClose: () => setState(() => _selected = null),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final NearbyPlace place;
  final VoidCallback onDirections;
  final VoidCallback onClose;
  const _PlaceCard(
      {required this.place, required this.onDirections, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      place.kind,
                      if (place.cuisine.isNotEmpty) place.cuisine,
                      distanceLabel(place.km),
                      if (place.openingHours.isNotEmpty) place.openingHours,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: LhColors.inkSecondary),
                  ),
                  const SizedBox(height: 2),
                  const Text('Not a LocalHive partner yet — no in-app orders',
                      style: TextStyle(fontSize: 11.5, color: LhColors.orange)),
                ],
              ),
            ),
            SizedBox(
              height: 34,
              child: FilledButton.icon(
                onPressed: onDirections,
                style: compactButtonStyle(width: 120, height: 34),
                icon: const Icon(CupertinoIcons.arrow_turn_up_right, size: 14),
                label: const Text('Directions'),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(CupertinoIcons.xmark, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
