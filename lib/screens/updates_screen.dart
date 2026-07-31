import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme.dart';

/// Order and booking updates, delivered inside the app.
///
/// These used to go out as SMS and WhatsApp messages at roughly a cent each,
/// which at any real volume cost more than the entire rest of the platform.
/// In the app they cost nothing and arrive instantly.
class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Updates')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.instance.myNotificationsStream(),
        builder: (context, snap) {
          if (!snap.hasData && !snap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.bell,
                        size: 44, color: LhColors.hairline),
                    SizedBox(height: 12),
                    Text('No updates yet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Order and booking updates land here as they happen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: LhColors.inkSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      _row(rows[i]),
                      if (i != rows.length - 1)
                        const Padding(
                            padding: EdgeInsets.only(left: 60),
                            child: Divider()),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Map<String, dynamic> n) {
    final unread = n['read'] != true;
    final event = '${n['event'] ?? ''}';
    final (icon, tint) = switch (event) {
      'booking_accepted' || 'order_ready' => (
          CupertinoIcons.checkmark_seal_fill,
          LhColors.green
        ),
      'booking_declined' => (CupertinoIcons.xmark_seal_fill, LhColors.orange),
      'order_delivered' || 'booking_completed' => (
          CupertinoIcons.bag_fill_badge_plus,
          LhColors.green
        ),
      _ => (CupertinoIcons.bell_fill, LhColors.blue),
    };
    return ListTile(
      leading: IconTile(icon: icon, color: tint, size: 32),
      title: Text('${n['message'] ?? ''}',
          style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
      subtitle: Text(_when(n['createdAt']),
          style: const TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
      trailing: unread
          ? const Icon(CupertinoIcons.circle_fill,
              size: 9, color: LhColors.blue)
          : null,
      onTap: unread && '${n['id'] ?? ''}'.isNotEmpty
          ? () => FirebaseService.instance.markNotificationRead('${n['id']}')
          : null,
    );
  }

  String _when(Object? ts) {
    if (ts is! Timestamp) return '';
    final t = ts.toDate().toLocal();
    final now = DateTime.now();
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final time = '$h12:${t.minute.toString().padLeft(2, '0')} '
        '${t.hour < 12 ? 'AM' : 'PM'}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return 'Today $time';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[t.month - 1]} ${t.day}, $time';
  }
}
