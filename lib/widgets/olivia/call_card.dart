import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/olivia/olivia_tools.dart';
import '../../theme.dart';

/// The call the customer agreed to, as a card: place, number, why — and one
/// green Call button that opens the dialer. Olivia sets it up; the customer
/// places the call. Mirrors the look of the order confirmation card.
class CallCard extends StatelessWidget {
  final PendingCall call;
  final VoidCallback onCall;
  final VoidCallback onDismiss;

  const CallCard({
    super.key,
    required this.call,
    required this.onCall,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: LhColors.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LhColors.green.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(
                    icon: CupertinoIcons.phone_fill,
                    color: LhColors.green,
                    size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(call.placeName,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(call.phone,
                          style: const TextStyle(
                              fontSize: 13.5, color: LhColors.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            if (call.purpose.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(call.purpose,
                  style: const TextStyle(
                      fontSize: 13.5, color: LhColors.inkSecondary)),
            ],
            const SizedBox(height: 8),
            const Text(
                'Number from the public map listing. Tapping Call opens your '
                'phone dialer — you place the call.',
                style: TextStyle(fontSize: 12, color: LhColors.inkSecondary)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onCall,
                    style: FilledButton.styleFrom(
                        backgroundColor: LhColors.green,
                        minimumSize: const Size(0, 44)),
                    icon: const Icon(CupertinoIcons.phone_fill, size: 16),
                    label: Text('Call ${call.placeName}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
