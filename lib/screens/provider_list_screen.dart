import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/data.dart';
import '../services/directions.dart';
import '../services/firebase_service.dart';
import '../services/geo.dart';
import '../services/location_service.dart';
import '../services/olivia/places_search.dart';
import '../services/supabase_mirror.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'catalog_screen.dart';
import 'nearby_map_screen.dart';

class ProviderListScreen extends StatefulWidget {
  final String category;
  final String title;
  const ProviderListScreen(
      {super.key, required this.category, required this.title});

  Color get _tint => LhColors.green;

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  final _places = PlacesSearch();
  List<NearbyPlace> _nearby = const [];
  bool _loadingNearby = true;

  String get category => widget.category;
  String get title => widget.title;
  Color get _tint => widget._tint;

  @override
  void initState() {
    super.initState();
    _loadNearby();
    // Changing city has to change the shops, or the picker is decoration.
    LocationService.instance.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    LocationService.instance.removeListener(_onLocationChanged);
    _places.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    final loc = LocationService.instance;
    if (loc.lat == _loadedForLat && loc.lng == _loadedForLng) return;
    _loadNearby();
  }

  // What the visible list was built for, so a label-only update (the
  // neighbourhood name arriving late) does not trigger a needless refetch.
  double? _loadedForLat;
  double? _loadedForLng;

  /// Real shops around the customer that have NOT partnered with LocalHive.
  /// Shown honestly as "not a partner" — you can call them or get directions,
  /// but you cannot order in the app. An empty marketplace is worse than a
  /// short one, and a fake listing is worse than both.
  Future<void> _loadNearby() async {
    final loc = LocationService.instance;
    if (!loc.hasPosition) await loc.detect();
    if (!loc.hasPosition) {
      if (mounted) setState(() => _loadingNearby = false);
      return;
    }
    _loadedForLat = loc.lat;
    _loadedForLng = loc.lng;
    if (mounted) setState(() => _loadingNearby = true);
    // The mirrored directory first: it is a real, curated snapshot of every
    // grocery shop in California, and it answers instantly. Overpass is the
    // fallback for when the directory is off or has nothing near this point
    // — a customer outside California, say.
    var results = (await SupabaseMirror.instance.nearbyStores(
          lat: loc.lat!,
          lng: loc.lng!,
          radiusKm: 8,
        ))
            ?.take(20)
            .map((s) => s.toPlace())
            .toList() ??
        const <NearbyPlace>[];
    if (results.isEmpty) {
      results = await _places.search(
        lat: loc.lat!,
        lng: loc.lng!,
        kind: _nearbyKind,
        radiusM: 8000,
        limit: 20,
      );
    }
    if (!mounted) return;
    setState(() {
      _nearby = results;
      _loadingNearby = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Live Firestore catalog; falls back to the bundled list while
    // loading or when offline so the screen is never empty.
    return StreamBuilder<List<Provider>>(
      stream: FirebaseService.instance.providersStream(category),
      builder: (context, snap) {
        // No invented fallback: if no real shop has signed up here yet, the
        // partner section is simply empty and the map section carries the
        // screen.
        final providers = snap.data ?? const <Provider>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              const LocationChip(),
            ],
          ),
          body: _list(providers),
        );
      },
    );
  }

  /// Which live-map category answers this screen's question when the partner
  /// list does not.
  String get _nearbyKind => 'groceries';

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: LhColors.inkSecondary)),
      );

  Widget _list(List<Provider> providers) {
    return Builder(
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Someone opening this from outside California is not lost — the
          // app only operates here. Say so, and point at the way to change
          // city, rather than showing San Francisco with no explanation.
          if (LocationService.instance.deviceOutsideServiceArea)
            Card(
              color: LhColors.blue.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.info_circle_fill,
                        size: 18, color: LhColors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'LocalHive serves California. Showing '
                          '${LocationService.instance.city.name} — tap the '
                          'location at the top to pick another city.',
                          style: const TextStyle(fontSize: 12.5, height: 1.3)),
                    ),
                  ],
                ),
              ),
            ),
          // When Firestore could not be read, this catalog came from the
          // read-only standby. Say so: browsing works, ordering does not.
          if (SupabaseMirror.instance.servingFromMirror)
            Card(
              color: LhColors.orange.withValues(alpha: 0.10),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.exclamationmark_triangle_fill,
                        size: 18, color: LhColors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Showing the standby catalog — ordering is '
                          'unavailable until the main service is back.',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ),
          if (providers.isNotEmpty) ...[
            _sectionLabel('Order in the app'),
            for (final p in providers) ...[
              _partnerCard(context, p),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 8),
          _sectionLabel('Also near you — not LocalHive partners'),
          if (_loadingNearby)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_nearby.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                  'Nothing else found nearby on the public map right now.',
                  style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                  'These shops have not joined LocalHive, so you cannot order '
                  'here in the app — call them or get directions.',
                  style:
                      TextStyle(fontSize: 12.5, color: LhColors.inkSecondary)),
            ),
            for (final n in _nearby) ...[
              _nearbyCard(context, n),
              const SizedBox(height: 8),
            ],
            // These shops come from OpenStreetMap, which is ODbL-licensed:
            // attribution is a condition of using the data, and the map
            // screens carry it already. This list renders the same data as
            // cards rather than pins, so it has to carry it too.
            if (_nearby.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4, bottom: 4),
                child: Text('Shop details © OpenStreetMap contributors',
                    style:
                        TextStyle(fontSize: 11, color: LhColors.inkSecondary)),
              ),
          ],
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(CupertinoIcons.map_pin_ellipse,
                  color: LhColors.blue),
              title: const Text('See them all on the map',
                  style:
                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => NearbyMapScreen(initialKind: _nearbyKind)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A shop on the public map that never signed up. Honest about what it is
  /// and what you can do with it.
  Widget _nearbyCard(BuildContext context, NearbyPlace n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(n.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Text(distanceLabel(n.km),
                    style: const TextStyle(
                        fontSize: 12.5, color: LhColors.inkSecondary)),
              ],
            ),
            if (n.address.isNotEmpty || n.area.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(n.address.isNotEmpty ? n.address : n.area,
                    style: const TextStyle(
                        fontSize: 12.5, color: LhColors.inkSecondary)),
              ),
            if (n.openingHours.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(n.openingHours,
                    style: const TextStyle(
                        fontSize: 12, color: LhColors.inkSecondary)),
              ),
            Row(
              children: [
                if (n.phone.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => openCallWithFallback(context,
                        name: n.name, phone: n.phone),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    icon: const Icon(CupertinoIcons.phone_fill, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 13)),
                  ),
                TextButton.icon(
                  onPressed: () => openDirectionsWithFallback(context,
                      lat: n.lat, lng: n.lng, address: n.name),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  icon:
                      const Icon(CupertinoIcons.arrow_turn_up_right, size: 14),
                  label:
                      const Text('Directions', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerCard(BuildContext context, Provider p) {
    return Builder(
      builder: (context) {
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        CatalogScreen(provider: p, items: storeCatalog))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _tint.withValues(alpha: 0.14),
                    child: Text(
                      p.name.substring(0, 1),
                      style: TextStyle(
                          color: _tint,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (p.verified) ...[
                              const SizedBox(width: 5),
                              const Icon(CupertinoIcons.checkmark_seal_fill,
                                  size: 15, color: LhColors.blue),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(p.subtitle,
                            style: const TextStyle(
                                color: LhColors.inkSecondary, fontSize: 13)),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            // A shop nobody has reviewed says so, rather than
                            // wearing a star rating it has not earned.
                            if (p.reviews == 0)
                              const Text('New',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: LhColors.blue))
                            else ...[
                              const Icon(CupertinoIcons.star_fill,
                                  size: 13, color: LhColors.amber),
                              const SizedBox(width: 3),
                              Text('${p.rating}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(' (${p.reviews})',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: LhColors.inkSecondary)),
                            ],
                            const SizedBox(width: 10),
                            const Icon(CupertinoIcons.location_solid,
                                size: 12, color: LhColors.inkSecondary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(p.city,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: LhColors.inkSecondary),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (p.hourlyRate > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$${p.hourlyRate.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: LhColors.ink)),
                        const Text('per hour',
                            style: TextStyle(
                                fontSize: 11, color: LhColors.inkSecondary)),
                      ],
                    )
                  else
                    const Icon(CupertinoIcons.chevron_right,
                        size: 18, color: LhColors.hairline),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
