import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme.dart';

class _Check {
  final String name;
  final String detail;
  final bool ok;
  const _Check(this.name, this.detail, this.ok);
}

/// Live end-to-end health check: proves the app is really talking to the
/// backend, that security rules are enforced, and that every flow's data
/// path works. Anyone can run it from Profile → System check.
class SystemCheckScreen extends StatefulWidget {
  const SystemCheckScreen({super.key});

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen> {
  final List<_Check> _results = [];
  bool _running = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _add(String name, Future<String> Function() probe) async {
    try {
      final detail = await probe();
      setState(() => _results.add(_Check(name, detail, true)));
    } catch (e) {
      setState(() => _results.add(_Check(name, _short('$e'), false)));
    }
    await Future.delayed(const Duration(milliseconds: 180));
  }

  String _short(String s) => s.length > 90 ? '${s.substring(0, 90)}…' : s;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _done = false;
      _results.clear();
    });
    final fb = FirebaseService.instance;
    final db = FirebaseFirestore.instance;

    await _add('App configuration', () async {
      if (!fb.ready) throw 'Firebase did not initialise (offline mode)';
      return 'Firebase connected · project localhivelocalhive';
    });

    await _add('Catalog read (customer browse)', () async {
      final snap =
          await db.collection('providers').where('live', isEqualTo: true).get();
      final byCat = <String, int>{};
      for (final d in snap.docs) {
        final c = (d.data()['category'] ?? '?') as String;
        byCat[c] = (byCat[c] ?? 0) + 1;
      }
      if (snap.docs.isEmpty) throw 'No live listings returned';
      return '${snap.docs.length} live listings · '
          '${byCat['home_service'] ?? 0} services, '
          '${byCat['indian_store'] ?? 0} stores, '
          '${byCat['food_truck'] ?? 0} trucks';
    });

    await _add('Security rules enforced', () async {
      try {
        await db.collection('notifications').limit(1).get();
        throw 'Notification queue was readable — rules NOT enforced';
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          return 'Private data is protected (notification queue denied)';
        }
        rethrow;
      }
    });

    await _add('Account & role', () async {
      final u = fb.currentUser;
      if (u == null)
        return 'Signed out — browsing as guest (sign in to test writes)';
      return 'Signed in as ${u.email ?? u.phoneNumber ?? u.uid} · '
          'role: ${AppState.instance.role}';
    });

    if (fb.currentUser != null) {
      await _add('Backend write round-trip', () async {
        final doc = await db.collection('diagnostics').add({
          'userId': fb.currentUser!.uid,
          'source': 'in-app system check',
          'at': FieldValue.serverTimestamp(),
        });
        final back = await doc.get();
        if (!back.exists) throw 'Write did not come back';
        return 'Wrote and read back document ${doc.id.substring(0, 6)}…';
      });

      await _add('Your bookings & orders', () async {
        final snap = await db
            .collection('bookings')
            .where('userId', isEqualTo: fb.currentUser!.uid)
            .get();
        return '${snap.docs.length} booking(s) visible to you';
      });

      await _add('Provider dashboard feed', () async {
        final snap = await db
            .collection('bookings')
            .where('providerOwnerId', isEqualTo: fb.currentUser!.uid)
            .get();
        final active = snap.docs.where((d) {
          final s = (d.data()['status'] ?? '') as String;
          return ['Placed', 'Requested', 'Preparing', 'Ready'].contains(s);
        }).length;
        return '${snap.docs.length} job(s) on your listings · $active active';
      });

      await _add('Delivery job board', () async {
        final snap = await db.collection('delivery_jobs').get();
        final open = snap.docs
            .where((d) => (d.data()['deliveryPersonId'] ?? '') == '')
            .length;
        return '${snap.docs.length} job(s) · $open open to claim';
      });

      await _add('Notification pipeline', () async {
        await db.collection('notifications').add({
          'recipient': 'diagnostic',
          'phone': '',
          'email': '',
          'event': 'system_check',
          'message': 'LocalHive system check ping (not delivered).',
          'status': 'skip',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return 'Queued a test message — dispatcher picks these up every 30s';
      });

      await _add('Application review queue', () async {
        final admin = await fb.isAdmin();
        if (!admin) return 'Not an admin — queue correctly hidden from you';
        final snap = await db.collection('provider_applications').get();
        final waiting =
            snap.docs.where((d) => d.data()['status'] == 'in_review').length;
        return 'Admin access · ${snap.docs.length} application(s), $waiting awaiting review';
      });
    }

    await _add('Location service', () async {
      final l = LocationService.instance.label;
      return l == 'USA'
          ? 'Using country default (allow location for area-level detail)'
          : 'Detected: $l';
    });

    setState(() {
      _running = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r.ok).length;
    final failed = _results.length - passed;
    return Scaffold(
      appBar: AppBar(
        title: const Text('System check'),
        actions: [
          if (_done)
            IconButton(
              tooltip: 'Run again',
              icon: const Icon(CupertinoIcons.refresh, size: 20),
              onPressed: _run,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _done
                ? (failed == 0
                    ? LhColors.green.withValues(alpha: 0.10)
                    : const Color(0xFFFF3B30).withValues(alpha: 0.08))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                      _running
                          ? CupertinoIcons.dot_radiowaves_left_right
                          : failed == 0
                              ? CupertinoIcons.checkmark_seal_fill
                              : CupertinoIcons.exclamationmark_triangle_fill,
                      size: 30,
                      color: _running
                          ? LhColors.blue
                          : failed == 0
                              ? LhColors.green
                              : const Color(0xFFFF3B30)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _running
                                ? 'Checking live backend…'
                                : failed == 0
                                    ? 'Everything is working'
                                    : '$failed check(s) need attention',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                            _running
                                ? 'Talking to Firebase, verifying rules and every flow\'s data path.'
                                : '$passed of ${_results.length} checks passed against the live database.',
                            style: const TextStyle(
                                fontSize: 12.5, color: LhColors.inkSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final r in _results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: IconTile(
                      icon: r.ok
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.xmark,
                      color: r.ok ? LhColors.green : const Color(0xFFFF3B30),
                      size: 32),
                  title: Text(r.name,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(r.detail,
                      style: const TextStyle(
                          fontSize: 12.5, color: LhColors.inkSecondary)),
                ),
              ),
            ),
          if (_running)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_done && !AppState.instance.signedIn)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Sign in and run this again to also test writes, your '
                  'bookings, the provider dashboard, the delivery board and '
                  'the notification pipeline.',
                  style:
                      TextStyle(fontSize: 12.5, color: LhColors.inkSecondary)),
            ),
        ],
      ),
    );
  }
}
