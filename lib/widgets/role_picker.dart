import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// Airbnb-style account-type chooser, shown after sign-up and from Profile.
Future<void> showRolePicker(BuildContext context, {bool dismissible = true}) {
  const roles = [
    (
      'customer',
      CupertinoIcons.person_fill,
      LhColors.blue,
      'Customer',
      'Book services, order from stores & trucks'
    ),
    (
      'provider',
      CupertinoIcons.briefcase_fill,
      LhColors.indigo,
      'Business owner',
      'Home services, store, or food truck — manage your orders'
    ),
    (
      'delivery',
      CupertinoIcons.cube_box_fill,
      LhColors.orange,
      'Delivery partner',
      'Students & gig workers — claim and deliver orders'
    ),
  ];
  return showModalBottomSheet(
    context: context,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: LhColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('How will you use LocalHive?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('You can switch anytime from your Profile.',
                style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
            const SizedBox(height: 14),
            for (final r in roles)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: AppState.instance.role == r.$1
                            ? LhColors.blue
                            : LhColors.hairline,
                        width: AppState.instance.role == r.$1 ? 2 : 0.5),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: IconTile(icon: r.$2, color: r.$3),
                    title: Text(r.$4,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    subtitle: Text(r.$5,
                        style: const TextStyle(
                            fontSize: 13, color: LhColors.inkSecondary)),
                    onTap: () {
                      AppState.instance.setRole(r.$1);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
