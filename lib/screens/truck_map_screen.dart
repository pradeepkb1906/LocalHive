import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/data.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'catalog_screen.dart';

/// Live food-truck map — OpenStreetMap tiles via flutter_map (free, no API
/// key). Tapping a pin opens that truck's menu.
class TruckMapScreen extends StatelessWidget {
  final List<Provider> trucks;
  const TruckMapScreen({super.key, required this.trucks});

  @override
  Widget build(BuildContext context) {
    final located = trucks.where((t) => t.hasLocation).toList();
    final center = located.isEmpty
        ? const LatLng(40.5629, -74.3390) // Edison, NJ fallback
        : LatLng(
            located.map((t) => t.lat).reduce((a, b) => a + b) / located.length,
            located.map((t) => t.lng).reduce((a, b) => a + b) / located.length,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Food Trucks Near You'), actions: const [LocationChip()]),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.localhive.localhive',
          ),
          MarkerLayer(
            markers: [
              for (final t in located)
                Marker(
                  point: LatLng(t.lat, t.lng),
                  width: 160,
                  height: 64,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              CatalogScreen(provider: t, items: truckMenu)),
                    ),
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
                          child: Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(CupertinoIcons.location_solid,
                            color: LhColors.orange, size: 26),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}
