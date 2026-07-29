import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// Compact 🇺🇸 location pill shown on every screen. Uses device GPS /
/// browser geolocation with OSM reverse-geocoding; falls back to 'USA'
/// when permission is denied.
class LocationChip extends StatelessWidget {
  const LocationChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocationService.instance..detect(),
      builder: (context, _) => Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: LhColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LhColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🇺🇸', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                LocationService.instance.label,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
