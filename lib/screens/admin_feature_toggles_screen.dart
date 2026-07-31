import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/feature_flags.dart';
import '../services/firebase_service.dart';
import '../theme.dart';

/// Admin-only Feature Access console, shaped like the staff-permission
/// screens of Square and Shopify: a Roles tab sets the baseline for every
/// role, and a People tab picks one person and overrides individual features
/// just for them. Resolution everywhere is user override → role setting →
/// built-in default.
class AdminFeatureTogglesScreen extends StatelessWidget {
  const AdminFeatureTogglesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feature Access'),
          bottom: const TabBar(
            labelColor: LhColors.navy,
            indicatorColor: LhColors.navy,
            tabs: [
              Tab(text: 'Roles'),
              Tab(text: 'People'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_RolesTab(), _PeopleTab()],
        ),
      ),
    );
  }
}

// ---- Roles: the baseline every account of a role inherits. ----

class _RolesTab extends StatelessWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirebaseService.instance.featureFlagsStream(),
      builder: (context, snap) {
        final overrides = snap.data ?? const {};
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                  'The baseline for every account of a role. Switching a '
                  'feature off hides it across the app for everyone in that '
                  'role — except people given their own override on the '
                  'People tab. Admin accounts are never affected.',
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
                                fontSize: 12.5, color: LhColors.inkSecondary)),
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
          ],
        );
      },
    );
  }
}

// ---- People: pick one person, override just for them. ----

class _PeopleTab extends StatefulWidget {
  const _PeopleTab();

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  String _query = '';
  String _roleFilter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('customer', 'Customers'),
    ('provider', 'Business owners'),
    ('delivery', 'Delivery partners'),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.instance.adminUsersStream(),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        final q = _query.toLowerCase();
        final users = (snap.data ?? const [])
            .where((u) => u['role'] != 'admin')
            .where((u) =>
                _roleFilter == 'all' ||
                (u['role'] ?? 'customer') == _roleFilter)
            .where((u) =>
                q.isEmpty ||
                '${u['email'] ?? ''}'.toLowerCase().contains(q) ||
                '${u['name'] ?? ''}'.toLowerCase().contains(q))
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Pick a person to give them their own switches — their '
                  'overrides beat the role settings, for just that account.',
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: LhColors.inkSecondary)),
            ),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(CupertinoIcons.search,
                    color: LhColors.inkSecondary, size: 20),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (key, label) in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label:
                            Text(label, style: const TextStyle(fontSize: 12.5)),
                        selected: _roleFilter == key,
                        onSelected: (_) => setState(() => _roleFilter = key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('No matching users.',
                      style: TextStyle(
                          fontSize: 13.5, color: LhColors.inkSecondary)),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < users.length; i++) ...[
                      _UserRow(user: users[i]),
                      if (i != users.length - 1)
                        const Padding(
                            padding: EdgeInsets.only(left: 62),
                            child: Divider()),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final email = '${user['email'] ?? ''}';
    final name = '${user['name'] ?? ''}';
    final role = '${user['role'] ?? 'customer'}';
    final title = name.isNotEmpty
        ? name
        : email.isNotEmpty
            ? email
            : '${user['uid']}'.substring(0, 8);
    return ListTile(
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: LhColors.navy.withValues(alpha: 0.12),
        child: Text(title.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LhColors.navy)),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(
          [
            featureRoleLabels[role] ?? role,
            if (name.isNotEmpty && email.isNotEmpty) email,
          ].join(' · '),
          style: const TextStyle(fontSize: 12.5, color: LhColors.inkSecondary)),
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 18, color: LhColors.hairline),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserFeatureOverridesScreen(
            uid: '${user['uid']}',
            title: title,
            role: role,
          ),
        ),
      ),
    );
  }
}

/// One person's switches. Each switch shows the EFFECTIVE state (their
/// override if any, else the role setting); flipping one writes a personal
/// override, and the row is marked Custom until reset.
class UserFeatureOverridesScreen extends StatelessWidget {
  final String uid;
  final String title;
  final String role;

  const UserFeatureOverridesScreen({
    super.key,
    required this.uid,
    required this.title,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FirebaseService.instance.featureFlagsStream(),
        builder: (context, roleSnap) {
          final roleOverrides = roleSnap.data ?? const {};
          return StreamBuilder<Map<String, dynamic>>(
            stream: FirebaseService.instance.userFeatureOverridesStream(uid),
            builder: (context, userSnap) {
              final userOverrides = userSnap.data ?? const {};
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                        '${featureRoleLabels[role] ?? role} · switches show '
                        'what this person can use right now. Flipping one '
                        'sets an override for just this account; rows marked '
                        'Custom differ from the role settings.',
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: LhColors.inkSecondary)),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final f in appFeatures) ...[
                          SwitchListTile.adaptive(
                            value: featureEnabledFor(
                              roleOverrides: roleOverrides,
                              userOverrides: userOverrides,
                              role: role,
                              feature: f.key,
                            ),
                            activeColor: LhColors.green,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(f.label,
                                      style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (userOverrides[f.key] is bool) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: LhColors.indigo
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Custom',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: LhColors.indigo)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                                'Role setting: '
                                '${featureEnabledIn(roleOverrides, role, f.key) ? 'On' : 'Off'}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: LhColors.inkSecondary)),
                            onChanged: (v) async {
                              await FirebaseService.instance
                                  .setUserFeatureFlag(uid, f.key, v);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                      duration: const Duration(seconds: 2),
                                      content: Text(
                                          '${f.label} ${v ? 'enabled' : 'disabled'} '
                                          'for $title only.')));
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
                  const SizedBox(height: 16),
                  if (userOverrides.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseService.instance
                            .clearUserFeatureFlags(uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                                duration: const Duration(seconds: 2),
                                content: Text(
                                    'Overrides cleared — $title now follows '
                                    'the role settings.')));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                      icon:
                          const Icon(CupertinoIcons.arrow_uturn_left, size: 16),
                      label: const Text('Reset to role settings'),
                    ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('Changes apply live — no app update needed.',
                        style: TextStyle(
                            fontSize: 12, color: LhColors.inkSecondary)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
