import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';

/// Admin console: review provider applications. Approving publishes the
/// applicant's listing into the public catalog and texts them the news.
class AdminReviewScreen extends StatelessWidget {
  const AdminReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Applications'),
        actions: const [LocationChip()],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.instance.applicationsStream(),
        builder: (context, snap) {
          if (!snap.hasData && !snap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          final apps = snap.data ?? const [];
          final pending =
              apps.where((a) => a['status'] == 'in_review').toList();
          final decided =
              apps.where((a) => a['status'] != 'in_review').toList();
          if (apps.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.doc_text_search,
                        size: 44, color: LhColors.hairline),
                    SizedBox(height: 12),
                    Text('No applications yet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                        'When someone applies to offer services, sell groceries, '
                        'run a truck, or deliver, their application lands here '
                        'for your review.',
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
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(children: [
                          Text('${pending.length}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: LhColors.orange)),
                          const Text('Awaiting review',
                              style: TextStyle(
                                  fontSize: 12, color: LhColors.inkSecondary)),
                        ]),
                      ),
                      Container(
                          width: 0.5, height: 34, color: LhColors.hairline),
                      Expanded(
                        child: Column(children: [
                          Text('${decided.length}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: LhColors.green)),
                          const Text('Reviewed',
                              style: TextStyle(
                                  fontSize: 12, color: LhColors.inkSecondary)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final a in [...pending, ...decided]) ...[
                _ApplicationCard(app: a),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> app;
  const _ApplicationCard({required this.app});

  /// Applications written by older builds (or by seed scripts) can be missing
  /// fields. Read them as text that degrades to '' rather than the string
  /// "null", which is what a bare interpolation would put on screen.
  String _s(String key) {
    final v = app[key];
    return v == null ? '' : '$v';
  }

  String get _typeLabel =>
      switch (_s('type').isEmpty ? _s('category') : _s('type')) {
        'home_service' => 'Home services',
        'indian_store' => 'Store',
        'food_truck' => 'Food truck',
        'delivery' => 'Delivery partner',
        '' => 'Not specified',
        final other => other,
      };

  /// Display name for the business, never the string "null".
  String get _name =>
      _s('businessName').isEmpty ? 'this business' : _s('businessName');

  /// Applicant's contact line. Field names differ between the app's own
  /// submissions and older/seeded rows, so accept either.
  String get _contact {
    final email =
        _s('applicantEmail').isEmpty ? _s('email') : _s('applicantEmail');
    final phone =
        _s('applicantPhone').isEmpty ? _s('phone') : _s('applicantPhone');
    final name = _s('contactName');
    return [
      if (name.isNotEmpty) name,
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
    ].join(' · ');
  }

  (Color, String) get _statusChip => switch (app['status']) {
        'approved' => (LhColors.green, 'Approved'),
        'rejected' => (const Color(0xFFFF3B30), 'Rejected'),
        _ => (LhColors.orange, 'Awaiting review'),
      };

  Future<void> _approve(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(CupertinoIcons.checkmark_seal_fill,
            color: LhColors.green, size: 40),
        title: Text('Approve ${_name}?'),
        content: const Text(
            'This publishes their listing to the public catalog immediately '
            'and texts them the good news.\n\n'
            'Confirm you have verified their identity and, for home services, '
            'their background check.',
            style: TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: dialogButtonStyle(background: LhColors.green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve & Publish')),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseService.instance.approveApplication(app);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$_name approved — listing is live and the '
              'applicant has been notified.')));
    }
  }

  Future<void> _reject(BuildContext context) async {
    final noteCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(CupertinoIcons.xmark_seal_fill,
            color: Color(0xFFFF3B30), size: 40),
        title: Text('Decline ${_name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Give a clear reason — it is sent to the applicant so they '
                'can fix it and reapply.',
                style: TextStyle(fontSize: 13.5, color: LhColors.inkSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtl,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'e.g. ID document unreadable; please resubmit'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: dialogButtonStyle(background: const Color(0xFFFF3B30)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true) return;
    final note = noteCtl.text.trim().isEmpty
        ? 'Verification incomplete'
        : noteCtl.text.trim();
    await FirebaseService.instance.rejectApplication(app, note);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Declined — applicant notified.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusChip;
    final pending = app['status'] == 'in_review';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      _s('businessName').isEmpty
                          ? 'Unnamed business'
                          : _s('businessName'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row(CupertinoIcons.briefcase, _typeLabel),
            if (_s('city').isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(CupertinoIcons.location_solid, _s('city')),
            ],
            if (_s('availableFrom').isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(CupertinoIcons.time,
                  'Available ${_s('availableFrom')} – ${_s('availableTo')}'),
            ],
            if (_contact.isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(CupertinoIcons.person, _contact),
            ],
            if (_s('about').isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(CupertinoIcons.doc_text, _s('about')),
            ],
            if (_s('reviewNote').isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(
                  CupertinoIcons.chat_bubble_text, 'Note: ${_s('reviewNote')}'),
            ],
            if (pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _approve(context),
                      style: FilledButton.styleFrom(
                          backgroundColor: LhColors.green,
                          minimumSize: const Size.fromHeight(42)),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF3B30),
                          minimumSize: const Size.fromHeight(42)),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: LhColors.inkSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13.5, color: LhColors.ink))),
        ],
      );
}
