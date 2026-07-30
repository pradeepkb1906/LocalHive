import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/data.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'booking_screen.dart';
import 'catalog_screen.dart';
import 'truck_map_screen.dart';

class ProviderListScreen extends StatelessWidget {
  final String category;
  final String title;
  const ProviderListScreen(
      {super.key, required this.category, required this.title});

  List<Provider> get _mock => switch (category) {
        'home_service' => homeServiceProviders,
        'indian_store' => indianStores,
        _ => foodTrucks,
      };

  Color get _tint => switch (category) {
        'home_service' => LhColors.indigo,
        'indian_store' => LhColors.green,
        _ => LhColors.orange,
      };

  @override
  Widget build(BuildContext context) {
    // Live Firestore catalog; falls back to the bundled list while
    // loading or when offline so the screen is never empty.
    return StreamBuilder<List<Provider>>(
      stream: FirebaseService.instance.providersStream(category),
      builder: (context, snap) {
        final providers =
            (snap.hasData && snap.data!.isNotEmpty) ? snap.data! : _mock;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (category == 'food_truck')
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TruckMapScreen(trucks: providers)),
                  ),
                  icon: const Icon(CupertinoIcons.map, size: 18),
                  label: const Text('Map'),
                ),
              const LocationChip(),
            ],
          ),
          body: _list(providers),
        );
      },
    );
  }

  Widget _list(List<Provider> providers) {
    return Builder(
      builder: (context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: providers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = providers[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (category == 'home_service') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BookingScreen(provider: p)));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CatalogScreen(
                              provider: p,
                              items: category == 'indian_store'
                                  ? storeCatalog
                                  : truckMenu)));
                }
              },
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
      ),
    );
  }
}

// (list body extracted so the StreamBuilder above can reuse it)
