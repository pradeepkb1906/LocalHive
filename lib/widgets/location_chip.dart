import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'city_picker.dart';

/// Compact location pill shown on every screen, and the way into the city
/// picker.
///
/// LocalHive serves California only, so this always names a California city.
/// A device outside the state does not change it — the pill is tappable
/// precisely so someone opening the app from anywhere in the world can put
/// themselves on the right street.
class LocationChip extends StatelessWidget {
  const LocationChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocationService.instance..detect(),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => CityPicker.open(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            constraints: const BoxConstraints(maxWidth: 168),
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
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 3),
                // Signals the pill does something. Without it people read the
                // location as fixed and never find the picker.
                const Icon(CupertinoIcons.chevron_down,
                    size: 10, color: LhColors.inkSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
