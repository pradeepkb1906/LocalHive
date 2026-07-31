import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/feature_flags.dart';
import '../services/firebase_service.dart';
import '../theme.dart';

/// Admin-only console: one switch per (role, feature). ON means that role
/// can use the feature; flipping a switch takes effect live for everyone in
/// the role. The starting position of every switch mirrors what the role can
/// already do, so the console is truthful before the admin ever touches it.
class AdminFeatureTogglesScreen extends StatelessWidget {
  const AdminFeatureTogglesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feature Access')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FirebaseService.instance.featureFlagsStream(),
        builder: (context, snap) {
          final overrides = snap.data ?? const {};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                    'Control which features each role can use. Switching a '
                    'feature off hides it across the app for everyone in '
                    'that role, immediately. Admin accounts are never '
                    'affected.',
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: LhColors.inkSecondary)),
              ),
              for (final role in featureRoles) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(featureRoleLabels[role]!.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: LhColors.inkSecondary)),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final f in appFeatures) ...[
                        SwitchListTile.adaptive(
                          value: featureEnabledIn(overrides, role, f.key),
                          activeColor: LhColors.green,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          title: Text(f.label,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600)),
                          subtitle: Text(f.description,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: LhColors.inkSecondary)),
                          onChanged: (v) async {
                            await FirebaseService.instance
                                .setFeatureFlag(role, f.key, v);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(
                                    duration: const Duration(seconds: 2),
                                    content: Text(
                                        '${f.label} ${v ? 'enabled' : 'disabled'} '
                                        'for ${featureRoleLabels[role]!.toLowerCase()}s.')));
                            }
                          },
                        ),
                        if (f != appFeatures.last)
                          const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Divider()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Changes apply live — no app update needed.',
                      style: TextStyle(
                          fontSize: 12, color: LhColors.inkSecondary)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
