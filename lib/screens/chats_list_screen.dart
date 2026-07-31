import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/feature_flags.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import 'chat_screen.dart';

/// Every conversation the signed-in user is part of, newest activity first.
class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseService.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.instance.myChatsStream(),
        builder: (context, snap) {
          if (!snap.hasData && !snap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snap.data ?? const [];
          if (chats.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.chat_bubble_2,
                        size: 44, color: LhColors.hairline),
                    SizedBox(height: 12),
                    Text('No messages yet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                        'Open a booking or order and tap Message to start a '
                        'conversation with the other side.',
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
                    for (var i = 0; i < chats.length; i++) ...[
                      _row(context, chats[i], myUid),
                      if (i != chats.length - 1)
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
      ),
    );
  }

  Widget _row(BuildContext context, Map<String, dynamic> chat, String myUid) {
    final participants =
        ((chat['participants'] as List?) ?? const []).cast<String>();
    final otherUid = participants.firstWhere((u) => u != myUid,
        orElse: () => participants.isEmpty ? '' : participants.first);
    final names = (chat['names'] as Map?)?.cast<String, dynamic>() ?? const {};
    final roles = (chat['roles'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = '${names[otherUid] ?? 'Member'}';
    final role = '${roles[otherUid] ?? ''}';
    final last = '${chat['lastMessage'] ?? ''}';
    final mineLast = chat['lastSenderId'] == myUid;
    return ListTile(
      leading: CircleAvatar(
        radius: 17,
        backgroundColor: LhColors.navy.withValues(alpha: 0.12),
        child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LhColors.navy)),
      ),
      title: Text(name,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(
          [
            if (role.isNotEmpty) featureRoleLabels[role] ?? role,
            if (last.isNotEmpty) '${mineLast ? 'You: ' : ''}$last',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, color: LhColors.inkSecondary)),
      trailing: const Icon(CupertinoIcons.chevron_right,
          size: 18, color: LhColors.hairline),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
              chatId: '${chat['id']}', otherUid: otherUid, title: name),
        ),
      ),
    );
  }
}
