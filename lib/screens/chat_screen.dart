import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../models/feature_flags.dart';
import '../services/directions.dart';
import '../services/firebase_service.dart';
import '../theme.dart';

/// One conversation. Text only, deliberately short: the conversation as a
/// whole gets [chatWordCap] words; when they run out the composer locks and
/// the app hands over to a phone call — chat is for quick coordination, not
/// negotiation.
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String title;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.title,
  });

  /// Opens (or finds) the conversation with [otherUid] and navigates to it.
  static Future<void> open(
    BuildContext context, {
    required String otherUid,
    required String otherName,
    required String otherRole,
    String otherPhone = '',
  }) async {
    if (otherUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This booking predates messaging — no chat '
              'partner is recorded on it.')));
      return;
    }
    final id = await FirebaseService.instance.openChat(
      otherUid: otherUid,
      otherName: otherName,
      otherRole: otherRole,
      otherPhone: otherPhone,
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(chatId: id, otherUid: otherUid, title: otherName),
      ),
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  String get _myUid => FirebaseService.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok =
        await FirebaseService.instance.sendChatMessage(widget.chatId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _composer.clear();
      // Follow the new message down.
      await Future.delayed(const Duration(milliseconds: 300));
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That message would pass the 250-word limit — '
              'please place a call to continue.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FirebaseService.instance.chatDocStream(widget.chatId),
        builder: (context, chatSnap) {
          final chat = chatSnap.data ?? const {};
          final used = ((chat['wordCount'] ?? 0) as num).toInt();
          final remaining = (chatWordCap - used).clamp(0, chatWordCap);
          final phones =
              (chat['phones'] as Map?)?.cast<String, dynamic>() ?? const {};
          final otherPhone = '${phones[widget.otherUid] ?? ''}';
          final roles =
              (chat['roles'] as Map?)?.cast<String, dynamic>() ?? const {};
          final otherRole = '${roles[widget.otherUid] ?? ''}';
          return Column(
            children: [
              if (otherRole.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: LhColors.navy.withValues(alpha: 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(featureRoleLabels[otherRole] ?? otherRole,
                      style: const TextStyle(
                          fontSize: 12, color: LhColors.inkSecondary)),
                ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirebaseService.instance
                      .chatMessagesStream(widget.chatId),
                  builder: (context, snap) {
                    final msgs = snap.data ?? const [];
                    if (msgs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                              'Say hello — short and to the point. The whole '
                              'conversation has a 250-word budget; after '
                              'that, it\'s a phone call.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: LhColors.inkSecondary)),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (context, i) =>
                          _bubble(msgs[i], msgs[i]['senderId'] == _myUid),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: remaining <= 0
                    ? _callHandoff(otherPhone)
                    : _composerBar(remaining),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine ? LhColors.navy : LhColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          border: mine ? null : Border.all(color: LhColors.hairline),
        ),
        child: Text('${m['text'] ?? ''}',
            style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: mine ? Colors.white : LhColors.ink)),
      ),
    );
  }

  Widget _composerBar(int remaining) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: LhColors.surface,
        border: Border(top: BorderSide(color: LhColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Type a message'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero, backgroundColor: LhColors.navy),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(CupertinoIcons.paperplane_fill, size: 18),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text('$remaining words left in this conversation',
                style: const TextStyle(
                    fontSize: 11.5, color: LhColors.inkSecondary)),
          ),
        ],
      ),
    );
  }

  /// The end of the road for text: the word budget is spent, so the only way
  /// forward is a call.
  Widget _callHandoff(String phone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: LhColors.surface,
        border: Border(top: BorderSide(color: LhColors.hairline)),
      ),
      child: Column(
        children: [
          const Text(
              '250-word limit reached — you need to place a call to '
              'continue this conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => openCallWithFallback(context,
                  name: widget.title, phone: phone),
              style: FilledButton.styleFrom(
                  backgroundColor: LhColors.green,
                  minimumSize: const Size.fromHeight(44)),
              icon: const Icon(CupertinoIcons.phone_fill, size: 16),
              label: Text('Call ${widget.title}'),
            ),
          ],
        ],
      ),
    );
  }
}
