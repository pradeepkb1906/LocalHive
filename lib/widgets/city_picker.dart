import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/ca_cities.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// Lets the customer say which California city they are shopping in.
///
/// Opened from the location chip on every screen. The list is California
/// only — LocalHive does not operate anywhere else, and offering cities it
/// cannot serve would be a promise the app cannot keep.
class CityPicker extends StatefulWidget {
  const CityPicker({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const CityPicker(),
      );

  @override
  State<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocationService.instance;
    final results = searchCaCities(_query);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        // A ceiling rather than a fixed height, and a Column that shrinks to
        // its children: the sheet then behaves whether it is handed a tall
        // parent or a tight one.
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose your city',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('LocalHive serves California.',
                  style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(CupertinoIcons.search, size: 18),
                  hintText: 'Search California cities',
                ),
              ),
              const SizedBox(height: 8),
              // Only offered when the device is genuinely in the state —
              // showing it to someone in Bengaluru would be a button that
              // cannot do what it says.
              if (loc.usingDeviceLocation)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconTile(
                      icon: CupertinoIcons.location_fill,
                      color: LhColors.blue,
                      size: 32),
                  title: const Text('Use my current location',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(loc.label,
                      style: const TextStyle(
                          fontSize: 12.5, color: LhColors.inkSecondary)),
                  onTap: () => Navigator.pop(context),
                ),
              Flexible(
                child: results.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'No California city by that name. '
                              'LocalHive only operates in California for now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: LhColors.inkSecondary)),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final c = results[i];
                          final selected =
                              c == loc.city && !loc.usingDeviceLocation;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(c.name,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? LhColors.navy
                                        : LhColors.ink)),
                            trailing: selected
                                ? const Icon(
                                    CupertinoIcons.checkmark_alt_circle_fill,
                                    size: 20,
                                    color: LhColors.navy)
                                : null,
                            onTap: () async {
                              await loc.setCity(c);
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
